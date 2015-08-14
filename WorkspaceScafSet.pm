###########################################################################
# WorkspaceScafSet.pm
# $Id: WorkspaceScafSet.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
###########################################################################
package WorkspaceScafSet;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use Archive::Zip;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use POSIX qw(ceil floor);
use ChartUtil;
use InnerTable;
use WebConfig;
use WebUtil;
use MetaUtil;
use HashUtil;
use MetaGeneTable;
use TabHTML;
use Workspace;
use WorkspaceUtil;
use MerFsUtil;
use PhyloUtil;
use OracleUtil;
use QueryUtil;
use GenerateArtemisFile;
use HistogramUtil;

$| = 1;

my $section              = "WorkspaceScafSet";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $img_internal         = $env->{img_internal};
my $img_er               = $env->{img_er};
my $img_ken              = $env->{img_ken};
my $tmp_dir              = $env->{tmp_dir};
my $workspace_dir        = $env->{workspace_dir};
my $public_nologin_site  = $env->{public_nologin_site};
my $YUI                  = $env->{yui_dir_28};

my $cog_base_url       = $env->{cog_base_url};
my $pfam_base_url      = $env->{pfam_base_url};
my $tigrfam_base_url   = $env->{tigrfam_base_url};
my $enzyme_base_url    = $env->{enzyme_base_url};
my $kegg_orthology_url = $env->{kegg_orthology_url};

my $web_data_dir      = $env->{web_data_dir};
my $mer_data_dir      = $env->{mer_data_dir};
my $taxon_lin_fna_dir = $env->{taxon_lin_fna_dir};
my $cgi_tmp_dir       = $env->{cgi_tmp_dir};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

my $enable_workspace = $env->{enable_workspace};
my $in_file          = $env->{in_file};

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

# user's sub folder names
my $FUNC_FOLDER = "function";
my $SCAF_FOLDER = "scaffold";

my $filename_size      = 25;
my $filename_len       = 60;
my $max_workspace_view = 10000;
my $max_profile_select = 50;

my $nvl          = getNvl();
my $unknown      = "Unknown";
my $contact_oid;

my $ownerFilesetDelim = "|";
my $ownerFilesetDelim_message = "::::";

#########################################################################
# dispatch
#########################################################################
sub dispatch {
    return if ( !$enable_workspace );
    return if ( !$user_restricted_site );

    my $page = param("page");

    my $sid = getContactOid();
    $contact_oid = $sid;
    return if ( $sid == 0 ||  $sid < 1 || $sid eq '901');

    # check to see user's folder has been created
    Workspace::initialize();

    if ( !$page && paramMatch("wpload") ) {
        $page = "load";
    } elsif ( !$page && paramMatch("delete") ) {
        $page = "delete";
    }

    if ( $page eq "view" ) {
        Workspace::viewFile();
    } elsif ( $page eq "delete" ) {
        Workspace::deleteFile();
    } elsif ( $page eq "load" ) {
        Workspace::readFile();
    } elsif ( $page eq "showDetail" ) {
        printScafSetDetail();
    } elsif ( paramMatch("viewScafSetGenomes") ne ""
        || $page eq "viewScafSetGenomes" )
    {
        viewScafGenomes(1);
    } elsif ( paramMatch("viewScafGenomes") ne ""
        || $page eq "viewScafGenomes" )
    {
        viewScafGenomes(0);
    } elsif ( paramMatch("showScafGenes") ne ""
        || $page eq "showScafGenes" )
    {
        showScafGenes();
    } elsif ( $page eq "showScafSetFuncProfile"
        || paramMatch("showScafSetFuncProfile") )
    {
        my $profile_type = param('ws_profile_type');
        if ( $profile_type eq 'func_category' ) {
            my $functype = param('functype');

            if (   $functype eq 'COG_Category'
                || $functype eq 'COG_Pathway'
                || $functype eq 'KEGG_Category_EC'
                || $functype eq 'KEGG_Category_KO'
                || $functype eq 'KEGG_Pathway_EC'
                || $functype eq 'KEGG_Pathway_KO'
                || $functype eq 'Pfam_Category'
                || $functype eq 'TIGRfam_Role' )
            {
                showScafFuncCategoryProfile(1);
            } else {
                showScafFunctionProfile(1);
            }
        } else {
            showScafFuncSetProfile(1);
        }
    } elsif ( $page eq "showScafFuncProfile"
        || paramMatch("showScafFuncProfile") )
    {
        my $profile_type = param('ws_profile_type');
        if ( $profile_type eq 'func_category' ) {
            my $functype = param('functype');

            if (   $functype eq 'COG_Category'
                || $functype eq 'COG_Pathway'
                || $functype eq 'KEGG_Category_EC'
                || $functype eq 'KEGG_Category_KO'
                || $functype eq 'KEGG_Pathway_EC'
                || $functype eq 'KEGG_Pathway_KO'
                || $functype eq 'Pfam_Category'
                || $functype eq 'TIGRfam_Role' )
            {
                showScafFuncCategoryProfile(0);
            } else {
                showScafFunctionProfile(0);
            }
        } else {
            showScafFuncSetProfile(0);
        }
    } elsif ( $page eq "profileGeneList" || paramMatch("profileGeneList") ) {
        Workspace::showProfileGeneList();
    } elsif ( $page eq "scafProfileGeneList"
        || paramMatch("scafProfileGeneList") )
    {
        showScafProfileGeneList();
    } elsif ( $page eq "scafCateProfileGeneList"
        || paramMatch("scafCateProfileGeneList") )
    {
        showScafCateProfileGeneList();
    } elsif ( $page eq "showOneScafSetHistogram"
        || paramMatch("showOneScafSetHistogram") )
    {
        printScafHistogram(1);
    } elsif ( $page eq "showScafSetHistogram"
        || paramMatch("showScafSetHistogram") )
    {
        printScafHistogram(1);
    } elsif ( $page eq "showScaffoldHistogram"
        || paramMatch("showScaffoldHistogram") )
    {
        printScafHistogram(0);
    } elsif ( $page eq "scaffoldGeneCount"
        || $page =~ /^scaffoldGeneCount/
        || paramMatch("scaffoldGeneCount") )
    {
        printHistogramScaffolds( 'gene_count' );
    } elsif ( $page eq "scaffoldSeqLength"
        || paramMatch("scaffoldSeqLength") )
    {
        printHistogramScaffolds( 'seq_length' );
    } elsif ( $page eq "scaffoldGCPercent"
        || paramMatch("scaffoldGCPercent") ne "")
    {
        printHistogramScaffolds( 'gc_percent' );
    } elsif ( $page eq "scaffoldReadDepth"
        || paramMatch("scaffoldReadDepth") )
    {
        printHistogramScaffolds( 'read_depth' );
    } elsif ( $page eq "editScaffoldSets" 
	|| paramMatch("editScaffoldSets") ne "" ) {
    	editScaffoldSets();
    } elsif ( $page eq "showScafSetKmer"
        || paramMatch("showScafSetKmer") )
    {
        printScafKmer(1);
    } elsif ( $page eq "showScafKmer"
        || paramMatch("showScafKmer") )
    {
        printScafKmer(0);
    } elsif ( paramMatch("scaffoldSetPhyloDist") ) {
        timeout( 60 * $merfs_timeout_mins );
        printScafPhyloDist(1);
    } elsif ( paramMatch("selectedScafPhyloDist") ) {
        timeout( 60 * $merfs_timeout_mins );
        printScafPhyloDist(0);
    } elsif ( $page eq "ir_class" 
        || $page eq "ir_order" 
        || $page eq "family" 
        || $page eq "genus" 
        || $page eq "species" ) {
        printScafTaxonomyPhyloDist( $page );
    } elsif ( $page eq "taxonomyMetagHits" ) {
        printScafTaxonomyMetagHits();
    } elsif ( paramMatch("submitFuncProfile") ne ""
        || $page eq "submitFuncProfile" )
    {
        Workspace::submitFuncProfile($SCAF_FOLDER);
    } elsif ( paramMatch("submitHistogram") ne ""
        || $page eq "submitHistogram" )
    {
        submitJob('Histogram');
    } elsif ( paramMatch("submitKmer") ne ""
        || $page eq "submitKmer" )
    {
        submitJob('Kmer');
    } elsif ( paramMatch("submitPhyloDist") ne ""
        || $page eq "submitPhyloDist" )
    {
        submitJob('Phylo Distribution');
    } elsif ( paramMatch("submitSaveFuncGene") ne ""
        || $page eq "submitSaveFuncGene" )
    {
        Workspace::submitSaveFuncGene($SCAF_FOLDER);
    } else {
        printScafSetMainForm();
    }
}

############################################################################
# printScafSetMainForm
############################################################################
sub printScafSetMainForm {
    my ($text) = @_;

    my $folder = $SCAF_FOLDER;

    my $sid = getContactOid();
    opendir( DIR, "$workspace_dir/$sid/$folder" )
      or webDie("failed to open folder list");
    my @files = readdir(DIR);
    closedir(DIR);

    print "<h1>My Workspace - Scaffold Sets</h1>";

    print qq{
        <script type="text/javascript" src="$base_url/Workspace.js" >
        </script>
    };

    print $text;

    printMainForm();

#print qq{
#    <form method="post" action="main.cgi" enctype="multipart/form-data" name="mainForm" accept-charset="UTF-8">
#};

    my $super_user_flag = getSuperUser();

    TabHTML::printTabAPILinks("scafsetTab");
    my @tabIndex = ( "#scafsettab1", "#scafsettab2", "#scafsettab3", 
		     "#scafsettab4", "#scafsettab5", "#scafsettab6",
		     "#scafsettab7", "#scafsettab8");
    my @tabNames = ( "Scaffold Sets", "Import & Export", "Genomes & Genes", 
		     "Function Profile", "Histogram", "Kmer Analysis",
		     "Phylogenetic Distribution", "Set Operation"
    );
    TabHTML::printTabDiv( "scafsetTab", \@tabIndex, \@tabNames );

    print "<div id='scafsettab1'>";
    WorkspaceUtil::printShareMainTable
	( $section_cgi, $section, $workspace_dir, $sid, $folder, @files );
    print hiddenVar( "directory", "$folder" );
    print "</div>\n";

    print "<div id='scafsettab2'>";
    # Import/Export
    Workspace::printImportExport($folder);

    print "<h2>Data Export</h2>\n";
    GenerateArtemisFile::printDataExportHint($folder);
    my $extra_text = "";
    my $grpCnt = WorkspaceUtil::getContactImgGroupCnt();
    if ( $grpCnt > 0 ) {
	$extra_text = "<u>your own</u>";
    }
    print "<p>You may export data from $extra_text selected scaffold set(s).\n";
    print "<p>\n";

    ## enter email address
    GenerateArtemisFile::printEmailInputTable( $sid, $folder );

    my $name = "_section_Workspace_exportScaffoldFasta_noHeader";
    print submit(
        -name    => $name,
        -value   => 'Fasta Nucleic Acid File',
        -class   => 'meddefbutton',
        -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button $name']); return checkSets('$folder');"
    );
    print nbsp(1);
    $name = "_section_Workspace_exportScaffoldData_noHeader";
    print submit(
        -name    => $name,
        -value   => 'Scaffold Data in Excel',
        -class   => 'medbutton',
        -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button $name']); return checkSets('$folder');"
    );
    print "</div>\n";

    print "<div id='scafsettab3'>";
    print "<h2>View Genomes</h2>";
    print "<p>You can view genomes of scaffolds in the selected scaffold set(s).<br/>";
    print "<br/>";
    print submit(
        -name    => '_section_WorkspaceScafSet_viewScafSetGenomes',
        -value   => 'View Genomes',
        -class   => 'smbutton',
        -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button $name']); return checkSetsIncludingShare('$folder');"
    );
    WorkspaceUtil::printSaveScaffoldSetGenomesAlternativeToWorkspace('filename,share_filename');
    WorkspaceUtil::printSaveScaffoldSetGenesAlternativeToWorkspace('filename,share_filename');
    print "</div>\n";

    print "<div id='scafsettab4'>";
    print "<h2>Scaffold Set Function Profile</h2>\n";
    printHint("Limit the number of scaffolds and/or number of functions to avoid timeout. If you have a large number of scaffolds and/or functions, please submit a computation job instead.");

    #my $jgi_user = Workspace::getIsJgiUser($sid);
    Workspace::printUseFunctionsInSet($sid);
    Workspace::printUseAllFunctionTypes();
    HtmlUtil::printMetaDataTypeChoice();

    # submit button
    print "<p>\n";
    print submit(
        -name    => "_section_WorkspaceScafSet_showScafSetFuncProfile",
        -value   => "Scaffold Set Function Profile",
        -class   => "meddefbutton",
        -onClick => "return checkSetsIncludingShare('$folder');"
    );

    require WorkspaceJob;
    my ($genomeFuncSets_ref, $genomeBlastSets_ref, $genomePairwiseANISets_ref, $geneFuncSets_ref, 
        $scafFuncSets_ref, $scafHistSets_ref, $scafKmerSets_ref, $scafPhyloSets_ref, $funcScafSearchSets_ref, 
        $genomeSaveFuncGeneSets_ref, $geneSaveFuncGeneSets_ref, $scafSaveFuncGeneSets_ref)
        = WorkspaceJob::getExistingJobSets();
    
    Workspace::printSubmitComputation( $sid, $folder, 'func_profile', 
        '_section_WorkspaceScafSet_submitFuncProfile', '', $scafFuncSets_ref );

    print "</div>\n";

    print "<div id='scafsettab5'>";
    print "<h2>Histogram</h2>";
    my $grpCnt = WorkspaceUtil::getContactImgGroupCnt();
    if ( $grpCnt > 0 ) { 
	print "<p><b>This is a scaffold set editing function, and therefore only applies to your own datasets.</b>";
    }
    print "<p>You may compare selected scaffold sets by: ";
    print "     <select name='histogram_type' class='img' size='1'>\n";
    print "        <option value='gene_count'>Gene Count</option>\n";
    print "        <option value='seq_length'>Sequence Length</option>\n";
    print "        <option value='gc_percent'>GC Content</option>\n";
    print "        <option value='read_depth'>Read Depth</option>\n";
    print "     </select>";
    print "</p>\n";
    print "<p>\n";
    HtmlUtil::printMetaDataTypeChoice('_h', '', '', 1);
    print "</p>";

    my $name = "_section_${section}_showScafSetHistogram"; 
    print submit( 
        -name  => $name, 
        -value => 'Show Scaffold Set Histogram', 
        -class => 'meddefbutton',
        -onClick => "return checkSetsIncludingShare('$folder');"
    ); 

    Workspace::printSubmitComputation( $sid, $folder, 'histogram',
        '_section_WorkspaceScafSet_submitHistogram', '', $scafHistSets_ref );
    
    print "</div>\n";

    print "<div id='scaffoldcarttab6'>";
    # Kmer Tool
    print "<h2>Scaffold Consistency Check</h2>";
    print "<p>You may analyze selected scaffold sets for purity "
        . "using Kmer Frequency Analysis.";
    print "</p>\n";
    print "<p>\n";
    HtmlUtil::printMetaDataTypeChoice('_k', '', 1, 1);
    print "</p>\n";
    $name = "_section_${section}_showScafSetKmer"; 
    print submit(
        -name    => $name,
        -value   => 'Kmer Frequency Analysis',
        -class   => 'lgdefbutton',
        -onClick => "return checkSetsIncludingShare('$folder');"
    );

    require Kmer;
    my $tableStr = Kmer::getKmerSettingTableStr(1);
    Workspace::printSubmitComputation( $sid, $folder, 'kmer', 
        '_section_WorkspaceScafSet_submitKmer', $tableStr, $scafKmerSets_ref );
    
    print "</div>";  # end scaffoldcarttab5

    print "<div id='scafsettab7'>";
    printHint(
        "Limit the numbers of scaffolds and sets to avoid timeout. If you have a large number of scaffolds, please submit a computation job instead."
    );
    PhyloUtil::printPhylogeneticDistributionSection(1);
    Workspace::printSubmitComputation( $sid, $folder, 'phylo', 
        '_section_WorkspaceScafSet_submitPhyloDist', '', $scafPhyloSets_ref );
    print "</div>\n";

    print "<div id='scafsettab8'>";
    Workspace::printSetOperation( $folder, $sid );
    Workspace::printBreakLargeSet($sid, $folder);
    print "</div>\n";

    TabHTML::printTabDivEnd();
    print end_form();
}

sub printDetailForSets {
    my ($set2scfs_href, $set2shareSetName_href, $showall) = @_;
    $showall = 1 if $showall eq "";

    my %sets = %$set2scfs_href;
    if (scalar keys %sets == 1) {
    	foreach my $scaf_set (keys %sets) {
    	    my @scaffold_oids = @{$sets{ $scaf_set }};
    	    printScafSetDetail($scaf_set, "scaffold", \@scaffold_oids);
    	}
    	return;
    }

    print "<h1>My Workspace - Scaffold Sets - Edit Scaffold Sets</h1>";

    use TabHTML;
    TabHTML::printTabAPILinks("scafsetsTab");

    my @keys = sort keys %sets;
    my $idx = 1;
    my @tabIndex;
    my @tabNames;
    foreach my $scaf_set (@keys) {
    	push @tabIndex, "#sstab".$idx;
    	my $shareSetName = $scaf_set;
    	if ( $set2shareSetName_href && $set2shareSetName_href->{$scaf_set} ) {
            $shareSetName = $set2shareSetName_href->{$scaf_set};    	    
    	}
    	push @tabNames, $shareSetName;
    	$idx++;
    }
    TabHTML::printTabDiv("scafsetsTab", \@tabIndex, \@tabNames);

    my $idx = 1;
    foreach my $scaf_set (@keys) {
        my $shareSetName = $scaf_set;
        if ( $set2shareSetName_href && $set2shareSetName_href->{$scaf_set} ) {
            $shareSetName = $set2shareSetName_href->{$scaf_set};            
        }

    	print "<div id='scaftab$idx'>";
    	my @scaffold_oids = @{$sets{ $scaf_set }};
    
    	if ($showall) {
    	    printScafSetDetail
    		($scaf_set, "scaffold", \@scaffold_oids, 0);
    	} else {
    	    my $url0 = "$main_cgi?section=WorkspaceScafSet"
    		. "&page=showDetail&filename=$scaf_set&folder=scaffold";
    	    my $link = alink($url0, $shareSetName, "_blank");
    	    print "<p><u>File Name</u>: $link<br/>";
    	    if ( $shareSetName eq $scaf_set && $scaf_set ) { #own scafset
                my $hint = "Click on <u>Remove Selected and Resave</u> to remove the selected scaffolds from this scaffold set and resave the set to the workspace.";
                printHint($hint);
    	    }
    	    print "</p>";
    	    
            my ($owner, $set_name) = WorkspaceUtil::splitOwnerFileset( '', $scaf_set );
    	    my $tblname = "scafSet_"."$set_name";
    	    print start_form(-id     => "$tblname"."_frm",
    			     -name   => "mainForm",
    			     -action => "$main_cgi" );
    	    HistogramUtil::printSelectedScaffoldsTable
    		(\@scaffold_oids, $scaf_set);
    	    print end_form();
    	}
    
    	print "</div>"; # end sstab
    	$idx++;
    }

    TabHTML::printTabDivEnd();
}

###############################################################################
# printScafSetDetail
###############################################################################
sub printScafSetDetail {
    my ($filename0, $folder0, $selected_scfs_aref, $show_title) = @_;
    $show_title = 1 if $show_title eq "";

    my $filename = param("filename");
    my $folder   = param("folder");
    $filename = $filename0 if $filename eq "";
    $folder = $folder0 if $folder eq "";

    my $sid = WebUtil::getContactOid();
    my $owner = param("owner");
    my $owner_name = "";

    if ( !$owner || $owner eq "" ) {
    	# scaffold sets from 3D applet (Kmer):
    	my ($c_id, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $filename );
    	if ( $x ) {
            $owner = $c_id;
    	    $filename = $x;
    	}
    }

    if ( $owner && $owner != $sid ) {
	## not my own data set
	## check permission
	my $can_view = 0;
	my %share_h = WorkspaceUtil::getShareFromGroups($folder);
	for my $k (keys %share_h) {
	    my ($c_oid, $data_set_name) = WorkspaceUtil::splitOwnerFileset( $sid, $k );
	    my ($g_id, $g_name, $c_name) = split(/\t/, $share_h{$k});

	    if ( $c_oid == $owner && $data_set_name eq $filename ) {
    		$can_view = 1;
    		$owner_name = $c_name;
    		last;
	    }
	}

	if ( ! $can_view ) {
	    print "<h1>My Workspace - Scaffold Sets - Individual Scaffold Set</h1>";
	    print "<p><u>File Name</u>: " . escapeHTML($filename) . "</p>";
	    webError("Scaffold set does not exist.");
	    return;
	}
    }

    my %selected_scfs;
    foreach my $i (@$selected_scfs_aref) {
    	$selected_scfs{ $i } = 1;
    }

    my $tblname = "scafSet_"."$filename";
    print start_form(-id     => "$tblname"."_frm",
		     -name   => "mainForm",
		     -action => "$main_cgi" );

    my $super_user_flag = getSuperUser();

    if ($show_title) {
    print "<h1>My Workspace - Scaffold Sets - Individual Scaffold Set</h1>";
    print "<p><u>File Name</u>: " . escapeHTML($filename) . "</p>";
    } else {
	my $url0 = "$main_cgi?section=WorkspaceScafSet"
	    . "&page=showDetail&filename=$filename&folder=scaffold";
	my $link = alink($url0, $filename, "_blank");
	print "<p><u>File Name</u>: <i>$link</i></p>";
    }
    if ( $owner_name ) {
	print "<p><u>Owner</u>: <i>$owner_name</i></p>";
    }

    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder",    $folder );
    print hiddenVar( "filename",  $filename );

    # check filename
    if ( $filename eq "" ) {
        webError("Cannot read file.");
        return;
    }

    WebUtil::checkFileName($filename);

    # this also untaints the name
    $filename = WebUtil::validFileName($filename);
    my $select_id_name = "scaffold_oid";
    my $full_path_name = "$workspace_dir/$sid/$folder/$filename";
    if ( $owner ) {
	$full_path_name = "$workspace_dir/$owner/$folder/$filename";
    }
    if ( ! (-e $full_path_name) ) {
	webError("Scaffold set does not exist.");
	return;
    }

    my %names;
    my @db_ids;

    my $row   = 0;
    my $trunc = 0;
    my $res   = newReadFileHandle($full_path_name);
    if ( ! $res ) {
	webError("Scaffold set does not exist.");
	return;
    }

    while ( my $id = $res->getline() ) {
        # set a limit so that it won't crash web browser
        if ( $row >= $max_workspace_view ) {
            $trunc = 1;
            last;
        }
        chomp $id;
        next if ( $id eq "" );

        $names{$id} = 0;
        if ( isInt($id) ) {
            push @db_ids, ($id);
        }
        $row++;
    }
    close $res;

    print "<p>\n";

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('s.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');

    my %taxons_in_file;
    if ($in_file) {
        %taxons_in_file = MerFsUtil::getTaxonsInFile($dbh);
    }

    my %taxon_name_h;
    my %taxon_h;
    if ( scalar(@db_ids) > 0 ) {
        my $db_str = OracleUtil::getNumberIdsInClause( $dbh,@db_ids );
        my $sql = qq{
            select s.scaffold_oid, s.scaffold_name, s.taxon 
            from scaffold s 
            where s.scaffold_oid in ($db_str) 
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id2, $name2, $t_oid ) = $cur->fetchrow();
            last if !$id2;
            if ( !$name2 ) {
                $name2 = "hypothetical protein";
            }
            $names{$id2} = $name2;
            if ($t_oid) {
                $taxon_h{$id2} = $t_oid;
            }
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $db_str =~ /gtt_num_id/i );
    }

    my $sid = getContactOid();
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    my $it = new InnerTable( 1, "$tblname"."$$", "$tblname", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Scaffold ID",   "char asc", "left" );
    $it->addColSpec( "Scaffold Name", "char asc", "left" );
    $it->addColSpec( "Genome ID",   "number asc", "right" );
    $it->addColSpec( "Genome Name", "char asc", "left" );

    my @keys = ( keys %names );
    my $can_select = 0;
    for my $id (@keys) {
        my $r;
        my $url;

        my ( $taxon3, $type3, $id3 ) = split( / /, $id );
        if ( ( $type3 eq 'assembled' || $type3 eq 'unassembled' )
            && $taxons_in_file{$taxon3} )
        {
            $taxon_h{$id} = $taxon3;
            if ( !$names{$id} ) {
                my @val = split( / /, $id );
                $names{$id} = $val[-1];
            }
        }

        if ( $names{$id} ) {
            $can_select++;
	    my $chk = "checked";
	    $chk = "" if (scalar keys %selected_scfs > 0
			  && !$selected_scfs{ $id });
            $r = $sd . "<input type='checkbox' name='$select_id_name' value='$id' $chk /> \t";

            # determine URL
            my $display_id;
            my ( $t1, $d1, $g1 ) = split( / /, $id );
            if ( !$g1 && isInt($t1) ) {
                $display_id = $id;
                $url = "$main_cgi?section=ScaffoldCart"
		     . "&page=scaffoldDetail&scaffold_oid=$t1";
            } else {
                $display_id = $g1;
                $url = "$main_cgi?section=MetaDetail&page=metaScaffoldDetail"
		     . "&taxon_oid=$t1&scaffold_oid=$g1&data_type=$d1";
            }

            if ($url) {
                $r .= $id . $sd . alink( $url, $display_id ) . "\t";
            } else {
                $r .= $id . $sd . $id . "\t";
            }
            $r .= $names{$id} . $sd . $names{$id} . "\t";

            if ( $taxon_h{$id} ) {
                my $t_oid     = $taxon_h{$id};
                $r .= $t_oid . $sd . $t_oid . "\t";

                my $taxon_url = "$main_cgi?section=TaxonDetail"
		    . "&page=taxonDetail&taxon_oid=$t_oid";
                if ( $taxons_in_file{$t_oid} ) {
                    $taxon_url = "$main_cgi?section=MetaDetail"
			. "&page=metaDetail&taxon_oid=$t_oid&";
                }
                my $taxon_name;
                if ( $taxon_name_h{$t_oid} ) {
                    $taxon_name = $taxon_name_h{$t_oid};
                } else {
                    $taxon_name = taxonOid2Name( $dbh, $t_oid );
                    $taxon_name_h{$t_oid} = $taxon_name;
                }

                $r .= $t_oid . $sd
		    . "<a href=\"$taxon_url\" >" . $taxon_name . "</a> \t";
            } else {
                $r .= "-" . $sd . "-" . "\t";
            }
        } else {
            # not in database
            $r = $sd . " \t" 
                . $id . $sd . $id . "\t" 
		        . "(not in this database)" . $sd . "(not in this database)" . "\t";
            $r .= $sd . "\t";
            $r .= "-" . $sd . "-" . "\t";
        }

        $it->addRow($r);
    }

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    if ( $row > 10 ) {
        WebUtil::printScaffoldCartFooterInLineWithToggle($tblname);
        #WebUtil::printScaffoldCartFooterInLine($tblname);
	#print nbsp(1);

	if ( $owner && $owner != $sid ) {
	    ## don't allow delete
	}
	else {
	    print submit(
		-name    => "_section_Workspace_removeAndSaveScaffolds",
		-value   => "Remove Selected and Resave",
		-class   => "medbutton",
		-onclick => "return checkSets('$folder');"
		);
	}
    }

    $it->printOuterTable(1);

    my $load_msg = "Loaded $row";
    if ( $can_select <= 0 ) {
        $load_msg .= "; none in this database.";
    } elsif ( $can_select < $row ) {
        $load_msg .= "; only $can_select selectable.";
    } else {
        $load_msg .= ".";
    }
    if ($trunc) {
        $load_msg .= " (additional rows truncated)";
    }
    $load_msg = "Loaded" if !$show_title;

    WebUtil::printScaffoldCartFooterInLineWithToggle($tblname);
    #WebUtil::printScaffoldCartFooterInLine($tblname);
    #print nbsp(1);
    if ( $owner && $owner != $sid ) {
	## don't allow delete
    }
    else {
	print submit(
	    -name    => "_section_Workspace_removeAndSaveScaffolds",
	    -value   => "Remove Selected and Resave",
	    -class   => "medbutton",
	    -onclick => "return checkSets('$folder');"
	    );
    }
    
    printStatusLine( $load_msg, 2 );
    if ( $can_select <= 0 ) {
        print end_form();
        return;
    }

    WorkspaceUtil::printSaveScaffoldToWorkspace($select_id_name);

    print end_form();
}

############################################################################
# viewScafGenomes
############################################################################
sub viewScafGenomes {
    my ($isSet) = @_;

    my $sid = getContactOid();
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printMainForm();
    my $dbh = dbLogin();

    my $folder = param('directory');
    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder",    $folder );

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);
    if ( scalar(@all_files) == 0 ) {
        webError("No scaffold sets are selected.");
        return;
    }

    my @scaffold_oids = param('scaffold_oid');
    #print "scaffold_oids @scaffold_oids<br/>\n";

    my ( $displayIds_ref, $db_oids_ref, $fs_oids_ref );
    if ($isSet) {
        ( $displayIds_ref, $db_oids_ref, $fs_oids_ref ) =
	       WorkspaceUtil::catalogOidsFromFile2( $sid, $workspace_dir, $SCAF_FOLDER, @all_files );

        print "<h1>Genomes of Selected Scaffold Sets</h1>\n";
        WorkspaceUtil::printSelectedInfo2( $dbh, 'scaffold set', @all_files );
    } else {

        # individual scaffolds
        if ( scalar(@scaffold_oids) == 0 ) {
            webError("No scaffolds are selected.");
            return;
        }

        ( $displayIds_ref, $db_oids_ref, $fs_oids_ref ) = WorkspaceUtil::catalogOids(@scaffold_oids);

        print "<h1>Genomes of Selected Scaffolds</h1>\n";
        WorkspaceUtil::printSelectedInfo( 'scaffold', @$displayIds_ref );

        my $y;
        for $y (@scaffold_oids) {
            print hiddenVar( "scaffold_oid", $y );
        }
    }

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();
    print "<p>Retrieving genome information from database data ...<br/>\n";

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my %taxon_info_h;

    if ( scalar(@$db_oids_ref) > 0 ) {
        my $oid_list_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_oids_ref );                
        my $sql = QueryUtil::getScaffoldTaxonDataSql( $oid_list_str, $rclause, $imgClause );
        QueryUtil::executeTaxonDataSql( $dbh, $sql, \%taxon_info_h );
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $oid_list_str =~ /gtt_num_id/i );
    }

    # now process file scaffolds
    if ( scalar(@$fs_oids_ref) > 0 ) {
        my %fs_taxons;
        for my $fs_scaf_oid (@$fs_oids_ref) {
            my ( $taxon_oid, $data_type, $scaffold_oid ) = split( / /, $fs_scaf_oid );
            if ( $data_type ne 'assembled' ) {
                next;
            }
            $fs_taxons{$taxon_oid} = 1;
        }
        my @metaTaxons = keys %fs_taxons;
        my $taxon_oid_list = OracleUtil::getNumberIdsInClause( $dbh, @metaTaxons );                
        my $sql = QueryUtil::getTaxonDataSql( $taxon_oid_list, $rclause, $imgClause );
        QueryUtil::executeTaxonDataSql( $dbh, $sql, \%taxon_info_h );
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $taxon_oid_list =~ /gtt_num_id/i );
    }

    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    my $select_id_name = "taxon_filter_oid";

    my $it = new InnerTable( 1, "scafTaxon$$", "scafTaxon", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Domain",      "char asc", "left" );
    $it->addColSpec( "Status",      "char asc", "left" );
    $it->addColSpec( "Genome ID", "number asc", "right" );
    $it->addColSpec( "Genome Name", "char asc", "left" );
    my $sd = $it->getSdDelim();

    my $taxon_cnt = 0;
    for my $taxon_oid ( keys %taxon_info_h ) {
        my $r   = $sd . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my ( $domain, $seq_status, $taxon_name ) = split( /\t/, $taxon_info_h{$taxon_oid} );
        $r .= $domain . $sd . $domain . "\t";
        $r .= $seq_status . $sd . $seq_status . "\t";
        $r .= $taxon_oid . $sd . $taxon_oid . "\t";
        $r .= $taxon_name . $sd . alink( $url, $taxon_name ) . "\t";

        $it->addRow($r);
        $taxon_cnt++;
    }

    printStatusLine( "$taxon_cnt genome(s) loaded", 2 );

    if ( !$taxon_cnt ) {
        print end_form();
        return;
    }

    $it->printOuterTable(1);

    print "<p>\n";
    WebUtil::printGenomeCartFooter();
    print "<p>\n";

    if ( $taxon_cnt > 0 ) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

    print end_form();
    return;
}

############################################################################
# showScafGenes
############################################################################
sub showScafGenes {
    printMainForm();

    my $folder    = param('directory');
    my @filenames = param('filename');

    my @scaffold_oids = param('scaffold_oid');
    if ( scalar(@scaffold_oids) == 0 ) {
        webError("No scaffolds have been selected.");
        return;
    }
    if ( scalar(@scaffold_oids) > 1000 ) {
        webError("Please select no more than 1000 scaffolds.");
        return;
    }

    my ( $scaffoldDisplayIds_ref, $db_scaffolds_ref, $fs_scaffolds_ref ) = WorkspaceUtil::catalogOids(@scaffold_oids);

    print "<h1>Genes of Selected Scaffolds</h1>\n";
    print "Selected scaffold(s): <i>@$scaffoldDisplayIds_ref</i><br/>\n";
    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder",    $folder );
    for my $filename (@filenames) {
        print hiddenVar( "filename", $filename );
    }
    for my $scaffold_oid (@scaffold_oids) {
        print hiddenVar( "scaffold_oid", $scaffold_oid );
    }

    my @db_scaffolds = @$db_scaffolds_ref;
    my @fs_scaffolds = @$fs_scaffolds_ref;

    my $sid = getContactOid();
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();
    print "<p>Retrieving genome information from database ...<br/>\n";

    my $dbh = dbLogin();

    my %taxon_info_h;
    my $sql = QueryUtil::getAllTaxonDataSql();
    QueryUtil::executeTaxonDataSql( $dbh, $sql, \%taxon_info_h );

    my $select_id_name = "gene_oid";

    my $it = new InnerTable( 1, "scafTaxon$$", "scafTaxon", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",     "char asc", "left" );
    $it->addColSpec( "Gene Name",   "char asc", "left" );
    $it->addColSpec( "Scaffold",    "char asc", "left" );
    $it->addColSpec( "Genome ID", "number asc", "right" );
    $it->addColSpec( "Genome Name", "char asc", "left" );
    my $sd = $it->getSdDelim();

    my $gene_cnt = 0;
    my $trunc    = 0;

    # select db genes
    if ( scalar(@db_scaffolds) > 0 ) {
        print "<p>Retrieving gene information from database ...\n";
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my $db_scaffold_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @db_scaffolds );
        $sql = qq{
            select g.gene_oid, g.gene_display_name, g.taxon, g.scaffold 
            from gene g 
            where g.scaffold in ($db_scaffold_oid_str)
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $gid, $gene_name, $tid, $scaf_id ) = $cur->fetchrow();
            last if !$gid;

            if ( $gene_cnt >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }

            $gene_cnt++;
            my $r = "";
            $r = $sd . "<input type='checkbox' name='$select_id_name' value='$gid' checked /> \t";
            my $url = "$main_cgi?section=GeneDetail" 
                . "&page=geneDetail&gene_oid=$gid";
            $r .= $gid . $sd . alink( $url, $gid ) . "\t";
            $r .= $gene_name . $sd . $gene_name . "\t";

            my $s_url = "$main_cgi?section=ScaffoldCart" 
                . "&page=scaffoldDetail&scaffold_oid=$scaf_id";
            $r .= $scaf_id . $sd . alink( $s_url, $scaf_id ) . "\t";

            $r .= $tid . $sd . $tid . "\t";
            my $t_url = "$main_cgi?section=TaxonDetail" 
                . "&page=taxonDetail&taxon_oid=$tid";
            my ( $domain, $seq_status, $taxon_name ) = split( /\t/, $taxon_info_h{$tid} );
            $r .= $tid . $sd . alink( $t_url, $taxon_name ) . "\t";
            $it->addRow($r);
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $db_scaffold_oid_str =~ /gtt_num_id/i );
    }

    #$dbh->disconnect();

    if ( !$trunc && scalar(@fs_scaffolds) > 0 ) {
        print "<p>Retrieving metagenome gene information ...\n";
        my $i = 0;
        for my $scaffold_oid (@fs_scaffolds) {
            print ".";
            $i++;
            if ( ( $i % 180 ) == 0 ) {
                print "<br/>\n";
            }

            my ( $t2, $d2, $s2 ) = split( / /, $scaffold_oid );
            my @genes_on_s = MetaUtil::getScaffoldGenes( $t2, 'assembled', $s2 );
            for my $g (@genes_on_s) {
                my ( $gid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id, $source )
                  = split( /\t/, $g );

                if ( $gene_cnt >= $maxGeneListResults ) {
                    $trunc = 1;
                    last;
                }

                $gene_cnt++;
                my $r            = "";
                my $workspace_id = "$t2 $d2 $gid";
                $r = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' checked /> \t";
                my $url =
                  "$main_cgi?section=MetaGeneDetail" . "&page=metaGeneDetail&gene_oid=$gid" . "&taxon_oid=$t2&data_type=$d2";
                $r .= $workspace_id . $sd . alink( $url, $gid ) . "\t";
                my ( $gene_prod_name, $prod_src ) = MetaUtil::getGeneProdNameSource( $gid, $t2, $d2 );
                $r .= $gene_prod_name . $sd . $gene_prod_name . "\t";
                my $s_url =
                  "$main_cgi?section=MetaDetail&page=metaScaffoldDetail" . "&taxon_oid=$t2&scaffold_oid=$s2&data_type=$d2";
                $r .= $s2 . $sd . alink( $s_url, $s2 ) . "\t";
                my $t_url = "$main_cgi?section=MetaDetail" . "&page=metaDetail&taxon_oid=$t2";
                my ( $domain, $seq_status, $taxon_name ) = split( /\t/, $taxon_info_h{$t2} );
                $r .= $t2 . $sd . alink( $t_url, $taxon_name ) . "\t";
                $it->addRow($r);
            }
        }
    }

    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    if ($trunc) {
        printMessage("<font color='red'>There are too many genes -- only $gene_cnt genes are listed.</font>");
    }

    $it->printOuterTable(1);

    print "<p>\n";
    WebUtil::printButtonFooter();

    WorkspaceUtil::printSaveAndExpandTabsForGenes( $select_id_name, '', "_section_Workspace_saveScaffoldGenes" );

    print end_form();
    return;
}

#############################################################################
# showScafFuncSetProfile - show scaffold function profile for selected files
#                       and function set
#############################################################################
sub showScafFuncSetProfile {
    my ($isSet) = @_;

    my $sid = getContactOid();

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    my $dbh = dbLogin();

    my $folder = param("directory");
    print hiddenVar( "directory", "$folder" );

    my $func_set_name = param('func_set_name');
    #print "func_set_name $func_set_name<br/>\n";
    if ( ! $func_set_name ) {
        webError("Please select a function set.\n");
        return;
    }
    my ( $func_set_owner, $func_set ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $func_set_name, $ownerFilesetDelim, $FUNC_FOLDER );
    my $share_func_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $func_set_owner, $func_set, $sid );

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);

    # scaffolds
    my $fileFullname = param('filename');
    #print "fileFullname $fileFullname<br/>\n";
    my @scaffold_oids = param('scaffold_oid');
    #print "scaffold_oids @scaffold_oids<br/>\n";
    for my $y (@scaffold_oids) {
        print hiddenVar( "scaffold_oid", $y );
    }

    my $data_type = param('data_type');
    print hiddenVar( "data_type", $data_type ) if ($data_type);

    if ($isSet) {
        validateScaffoldSelection( $isSet, @all_files );
        print "<h1>Scaffold Set Function Profile ($share_func_set_name)</h1>\n";
        print "<p>Profile is based on scaffold set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected scaffold set(s): ";
    	WorkspaceUtil::printShareSetName($dbh, $sid, @all_files);
    	print "<br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    } else {
        validateScaffoldSelection( $isSet, @scaffold_oids );
        my ( $scaffoldDisplayIds_ref, $db_scaffolds_ref, $fs_scaffolds_ref ) 
            = WorkspaceUtil::catalogOids(@scaffold_oids);
        print "<h1>Scaffold Function Profile ($share_func_set_name)</h1>\n";
        print
"<p>Profile is based on individual scaffolds in scaffold set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected scaffold(s): <i>@$scaffoldDisplayIds_ref</i><br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }

    # read all function ids in the function set
    WebUtil::checkFileName($func_set);

    # this also untaints the name
    my $func_filename = WebUtil::validFileName($func_set);

    my @func_ids;
    my $res = newReadFileHandle("$workspace_dir/$func_set_owner/$FUNC_FOLDER/$func_filename");
    while ( my $id = $res->getline() ) {
        chomp $id;
        next if ( $id eq "" );
        push @func_ids, ($id);
    }
    close $res;

    my %func_names = QueryUtil::fetchFuncIdAndName( $dbh, \@func_ids );

    timeout( 60 * $merfs_timeout_mins );
    my $start_time  = time();
    my $timeout_msg = "";

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    my %scafOrset_cnt_h;
    if ($isSet) {
        for my $x2 (@all_files) {
    	    my ($c_oid, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
    	    if ( ! $c_oid || ! $x ) {
        		next;
    	    }

            print "<p>Processing scaffold set $x ...\n";
            my $fullname = "$workspace_dir/$c_oid/$folder/$x";
            my %func2genes_h = countScafFuncGene( $dbh, $fullname, '', \@func_ids, $data_type );
            #print "showScafFuncSetProfile() func2genes_h:<br/>\n";
            #print Dumper(\%func2genes_h);
            #print "<br/>\n";
            my %func2count_h;
            foreach my $func_id (keys %func2genes_h) {
                my $genes_href = $func2genes_h{$func_id};
                my $gene_count = scalar( keys %$genes_href );
                $func2count_h{$func_id} = $gene_count;
            }
            #my %func2count_h = countScafFuncGene_old( $dbh, $fullname, '', \@func_ids, $data_type );
            $scafOrset_cnt_h{$x2} = \%func2count_h;
            #print Dumper(\%func2count_h);
            #print "showScafFuncSetProfile() filename $x retrieved count <br/>\n";
        }
    }
    else {
        #todo
    }

    my $total_cnt = 0;
    my %funcId2scafOrset2cnt_h;    
    for my $func_id (@func_ids) {
        if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 )
        {
            $timeout_msg =
                "Process takes too long to run "
              . "-- stopped at $func_id. "
              . "Only partial result is displayed.";
            last;
        }

        print "Processing function $func_id ...<br/>\n";
        my %scafOrset2cnt_h;
        if ($isSet) {
            for my $x2 (@all_files) {
        		my ($c_oid, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
        		if ( ! $c_oid || ! $x ) {
        		    next;
        		}

                my $cnt = 0;
                if ( $scafOrset_cnt_h{$x2} ) {
                    my $func_cnt_href = $scafOrset_cnt_h{$x2};
                    if ( $func_cnt_href->{$func_id} ) {
                        $cnt = $func_cnt_href->{$func_id};
                        #print "showScafFuncSetProfile() filename $x $func_id cnt: $cnt<br/>\n";
                    }
                }
                else {
                    #should not be used
                    my $fullname = "$workspace_dir/$c_oid/$folder/$x";
                    $cnt = outputScafFuncGene( $dbh, $func_id, $fullname, "", $data_type );
                }
                $scafOrset2cnt_h{$x2} = $cnt;
                $total_cnt += $cnt;
            }    # end for x2
        }
        else {    
            for my $scaffold_oid (@scaffold_oids) {
                my $cnt = 0;
                my $func_cnt_href = $scafOrset_cnt_h{$scaffold_oid};
                if ($func_cnt_href) {
                    $cnt = $func_cnt_href->{$func_id};
                }
                else {
                    #should not be used
                    $cnt = outputScafFuncGene( $dbh, $func_id, $fileFullname, $scaffold_oid, $data_type );
                }
                $scafOrset2cnt_h{$scaffold_oid} = $cnt;
                $total_cnt += $cnt;
            }    # end for scaffold_oid
        }
        $funcId2scafOrset2cnt_h{$func_id} = \%scafOrset2cnt_h;
    }

    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    if ( !$total_cnt ) {
        print "<p><b>No genes are associated with selected function set.</b>\n";
        print end_form();
        return;
    }

    if ($timeout_msg) {
        printMessage("<font color='red'>Warning: $timeout_msg</font>");
    }

    my $it = new InnerTable( 1, "scafFuncSet$$", "scafFuncSet", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Function ID",   "char asc", "left" );
    $it->addColSpec( "Function Name", "char asc", "left" );
    if ($isSet) {
        for my $x (@all_files) {
	    my $x_name = WorkspaceUtil::getShareSetName($dbh, $x, $sid);
	    my ($n1, $n2) = split(/ /, $x_name, 2);
	    if ( $n2 ) {
		$x_name = $n1 . "<br/>" . $n2;
	    }
            $it->addColSpec( $x_name, "number asc", "right" );
        }
    } else {
        my ( $db_scafs_ref, $file_scafs_ref ) = MerFsUtil::splitDbAndMetaOids(@scaffold_oids);        
        if ( scalar(@$db_scafs_ref) > 0 ) {
            my %oid2name_h = QueryUtil::fetchScaffoldNameHash( $dbh, @$db_scafs_ref );
            for my $oid (@$db_scafs_ref) {
                my $scaf_name = $oid2name_h{$oid};
                $it->addColSpec( $scaf_name, "number asc", "right", "" );
            }
        }
        if ( scalar(@$file_scafs_ref) > 0 ) {
            for my $scaffold_oid (@$file_scafs_ref) {
                my $col_name = join("<br/>", split(/ /, $scaffold_oid));
                $it->addColSpec( $col_name, "number asc", "right");
            }
        }
    }

    my $row_cnt = 0;
    for my $func_id (@func_ids) {
        my $r = $sd . "<input type='checkbox' name='func_id' value='$func_id' />\t";
        $r .= $func_id . $sd . $func_id . "\t";
        $r .= $func_names{$func_id} . $sd . $func_names{$func_id} . "\t";

        my $scafOrset2cnt_href = $funcId2scafOrset2cnt_h{$func_id};
        if ($isSet) {
            for my $x (@all_files) {
                my $cnt = $scafOrset2cnt_href->{$x};

                if ($cnt) {
                    my $url = "$section_cgi&page=scafProfileGeneList&directory=$folder" 
                        . "&share_input_file=$x&func_id=$func_id";
                    $url .= "&data_type=$data_type" if ( $data_type );
                    $url = alink( $url, $cnt );
                    $r .= $cnt . $sd . $url . "\t";
                } else {
                    $r .= "0" . $sd . "0\t";
                }
            }
        } else {
            for my $scaffold_oid (@scaffold_oids) {
                my $cnt = $scafOrset2cnt_href->{$scaffold_oid};
                if ($cnt) {
                    my $url =
                        "$section_cgi&page=scafProfileGeneList&directory=$folder"
                      . "&scaffold_oid=$scaffold_oid"
                      . "&input_file=$fileFullname&func_id=$func_id";
                    $url .= "&data_type=$data_type" if ( $data_type );
                    $url = alink( $url, $cnt );
                    $r .= $cnt . $sd . $url . "\t";
                } else {
                    $r .= "0" . $sd . "0\t";
                }
            }
        }
        $it->addRow($r);
        $row_cnt++;
    }    # end for func_id

    WebUtil::printFuncCartFooter() if ( $row_cnt > 10 );
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();
    WorkspaceUtil::printFuncGeneSaveToWorkspace( $SCAF_FOLDER, $isSet );

    require WorkspaceJob;
    my ($genomeFuncSets_ref, $genomeBlastSets_ref, $genomePairwiseANISets_ref, $geneFuncSets_ref, 
        $scafFuncSets_ref, $scafHistSets_ref, $scafKmerSets_ref, $scafPhyloSets_ref, $funcScafSearchSets_ref, 
        $genomeSaveFuncGeneSets_ref, $geneSaveFuncGeneSets_ref, $scafSaveFuncGeneSets_ref)
        = WorkspaceJob::getExistingJobSets();
    
    Workspace::printSubmitComputation( $sid, $folder, 'save_func_gene', 
        '_section_WorkspaceScafSet_submitSaveFuncGene', '', $scafSaveFuncGeneSets_ref );


    print end_form();
    printStatusLine( "Loaded", 2 );
}

#############################################################################
# validateScaffoldSelection
#############################################################################
sub validateScaffoldSelection {
    my ( $isSet, @scaffoldCols ) = @_;

    my $scaffoldDescription;
    if ( $isSet ) {
        $scaffoldDescription = "scaffold sets";
    }
    else {
        $scaffoldDescription = "scaffolds";            
    }
    if ( scalar( @scaffoldCols ) == 0 ) {
        webError("No $scaffoldDescription are selected.");
        return;
    }
    if ( scalar( @scaffoldCols ) > $max_profile_select ) {
        webError("Please limit your selection of $scaffoldDescription to no more than $max_profile_select.\n");
        return;
    }

}

##############################################################################
# outputScafFuncGenes - output genes in scaffold with func_id
#
# input_file: read scaffold oids from this file
# input_scaffold: only this scaffold
#
# only return count and no output if $res is not defined
##############################################################################
sub outputScafFuncGene {
    my ( $dbh, $func_id, $input_file, $input_scaffold, $data_type ) = @_;

    my %taxon_datatype_h;
    my @db_scaffolds = ();

    if ($input_scaffold) {
        # just one scaffold
        if ( WebUtil::isInt($input_scaffold) ) {
            push @db_scaffolds, ($input_scaffold);
        }
        else {
            processGenesForMetaScaf( $input_scaffold, \%taxon_datatype_h, $data_type );
        }

    } else {

        # read scaffold set
        open( FH, "$input_file" )
          or webError("File size - file error $input_file");

        while ( my $line = <FH> ) {
            chomp($line);
            if ( WebUtil::isInt($line) ) {
                push @db_scaffolds, ($line);
            }
            else {
                processGenesForMetaScaf( $line, \%taxon_datatype_h, $data_type );
            }
        }    # end while line
        close FH;
    }

    my $gene_count = 0;

    # database
    if ( scalar(@db_scaffolds) > 0 ) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @db_scaffolds );
        my ( $sql, @bindList ) =
          WorkspaceQueryUtil::getDbScaffoldFuncGeneSql( $func_id, $scaf_str, $rclause, $imgClause );
        #print "outputScafFuncGene() \$sql: $sql<br/>\n";
        #print "outputScafFuncGene() \@bindList: @bindList<br/>\n";

        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $func_id2, $t_id, $gene_name ) = $cur->fetchrow();
            last if ( !$gene_oid );
            #print "scaffold $scaffold_oid $gene_oid<br/>\n";
            $gene_count++;
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $scaf_str =~ /gtt_num_id/i );
    }

    # file
    for my $key ( keys %taxon_datatype_h ) {
        my $genes_href = $taxon_datatype_h{$key};
        if ( !$genes_href ) {
            print "<p>no genes in taxon_dataype $key\n";
            next;
        }

        my ( $taxon_oid, $data_type ) = split( / /, $key );
        my @func_genes = MetaUtil::getTaxonFuncMetaGenes( $taxon_oid, $data_type, $func_id );
        for my $gene_oid (@func_genes) {
            if ( $genes_href->{$gene_oid} ) {
                #my $workspace_id = "$taxon_oid $data_type $gene_oid";
                $gene_count++;
            }
        }
    }

    return $gene_count;
}

##############################################################################
# countScafFuncGene - count genes in scaffold with functions
#
# input_file: read scaffold oids from this file
# input_scaffold: only this scaffold
#
##############################################################################
sub countScafFuncGene {
    my ( $dbh, $input_file, $input_scaffold, $func_aref, $data_type ) = @_;

    #print "<p>counting scaffold gene functions ...\n";

    my @db_scaffolds;
    my @meta_scaffolds;

    if ($input_scaffold) {
        # just one scaffold
        if ( WebUtil::isInt($input_scaffold) ) {
            push @db_scaffolds, ($input_scaffold);
        }
        else {
            push @meta_scaffolds, ($input_scaffold);
        }
    } else {
        # read scaffold set
        #print "<p>Reading scaffold set ...\n";
        open( FH, "$input_file" )
          or webError("File size - file error $input_file");

        while ( my $line = <FH> ) {
            chomp($line);
            if ( WebUtil::isInt($line) ) {
                push(@db_scaffolds, $line);
            }
            else {
                push @meta_scaffolds, ($line);
            }
        }    # end while line
        close FH;
    }

    my @func_groups = QueryUtil::groupFuncIdsIntoOneArray( $func_aref );
    my %func2genes_sum_h;

    if ( scalar(@db_scaffolds) > 0 ) {
        my %scaf_func2genes_h; 
        countDbScafFuncGene( $dbh, \@db_scaffolds, \@func_groups, \%scaf_func2genes_h );
        #print "countScafFuncGene() db scaf_func2genes_h:<br/>\n";
        #print Dumper(\%scaf_func2genes_h)."<br/>\n";
        foreach my $scaf_id ( keys %scaf_func2genes_h ) {
            my $func2genes_href = $scaf_func2genes_h{$scaf_id};
            if ( $func2genes_href ) {
                foreach my $func_id ( keys %$func2genes_href ){
                    my $genes_href = $func2genes_href->{$func_id};
                    if ( $genes_href ) {
                        my $genes_sum_href = $func2genes_sum_h{$func_id};
                        if ( ! $genes_sum_href ) {
                            my %genes_sum_h;
                            $genes_sum_href = \%genes_sum_h;
                            $func2genes_sum_h{$func_id} = $genes_sum_href;
                        }
                        foreach my $gene_oid ( keys %$genes_href ) {
                            $genes_sum_href->{$gene_oid} = 1;
                        }
                    }
                }
            }
        }
    }
    
    my %taxon_scaffolds = MetaUtil::getOrganizedTaxonScaffolds( @meta_scaffolds );
    for my $key ( keys %taxon_scaffolds ) {
        my ( $taxon_oid, $d2 ) = split( / /, $key );
        if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
            && ($d2 ne $data_type) ) {
                next;
        }
        print "Computing $key scaffolds ...<br/>\n";

        $taxon_oid = sanitizeInt($taxon_oid);
        my $oid_ref = $taxon_scaffolds{$key};
        if ( $oid_ref && scalar(@$oid_ref) > 0 ) {
            my %scaffolds_h;
            WebUtil::arrayRef2HashRef( $oid_ref, \%scaffolds_h, 1 );
            my %scaf_func2genes_h;
            countMetaTaxonScafFuncGene( $dbh, $taxon_oid, $d2, \@func_groups, \%scaf_func2genes_h, '', \%scaffolds_h );
            #print "countScafFuncGene() meta scaf_func2genes_h:<br/>\n";
            #print Dumper(\%scaf_func2genes_h)."<br/>\n";
            foreach my $scaf_id ( keys %scaf_func2genes_h ) {
                my $func2genes_href = $scaf_func2genes_h{$scaf_id};
                if ( $func2genes_href ) {
                    foreach my $func_id ( keys %$func2genes_href ){
                        my $genes_href = $func2genes_href->{$func_id};
                        if ( $genes_href ) {
                            my $genes_sum_href = $func2genes_sum_h{$func_id};
                            if ( ! $genes_sum_href ) {
                                my %genes_sum_h;
                                $genes_sum_href = \%genes_sum_h;
                                $func2genes_sum_h{$func_id} = $genes_sum_href;
                            }
                            foreach my $gene_oid ( keys %$genes_href ) {
                                $genes_sum_href->{$gene_oid} = 1;
                            }
                        }
                    }
                }
            }
        }
    }

    return %func2genes_sum_h;
}

sub countScafFuncGene_old {
    my ( $dbh, $input_file, $input_scaffold, $func_aref, $data_type ) = @_;

    #print "<p>counting scaffold gene functions ...\n";

    my %taxon_datatype_h;
    my @db_scaffolds;

    if ($input_scaffold) {
        # just one scaffold
        if ( WebUtil::isInt($input_scaffold) ) {
            push @db_scaffolds, ($input_scaffold);
        }
        else {
            processGenesForMetaScaf( $input_scaffold, \%taxon_datatype_h, $data_type );
        }

    } else {

        # read scaffold set
        #print "<p>Reading scaffold set ...\n";
        open( FH, "$input_file" )
          or webError("File size - file error $input_file");

        while ( my $line = <FH> ) {
            chomp($line);
            if ( WebUtil::isInt($line) ) {
                push(@db_scaffolds, $line);
            }
            else {
                processGenesForMetaScaf( $line, \%taxon_datatype_h, $data_type );
            }

        }    # end while line
        close FH;
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my %func2count_h;
    for my $func_id (@$func_aref) {
        print "<p>Processing function $func_id ...\n";
        my $gene_count = 0;

        # database
        if ( scalar(@db_scaffolds) > 0 ) {
            my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @db_scaffolds );
            my ( $sql, @bindList ) =
              WorkspaceQueryUtil::getDbScaffoldFuncGeneSql( $func_id, $scaf_str, $rclause, $imgClause );
            #print "countScafFuncGene() sql: $sql<br/>\n";
            if ( $sql ) {
                my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
                for ( ; ; ) {
                    my ( $gene_oid, $func_id2, $t_id, $gene_name ) = $cur->fetchrow();
                    last if ( !$gene_oid );
                    #print "countScafFuncGene() retrieved $gene_oid, $func_id2, $t_id, $gene_name<br/>\n";
                    $gene_count++;
                }
                $cur->finish();                
            }
            OracleUtil::truncTable( $dbh, "gtt_num_id" )
              if ( $scaf_str =~ /gtt_num_id/i );
        }

        # file
        for my $key ( keys %taxon_datatype_h ) {
            my $genes_href = $taxon_datatype_h{$key};
            if ( !$genes_href ) {
                print "<p>no genes in taxon_dataype $key\n";
                next;
            }

            my ( $taxon_oid, $d2 ) = split( / /, $key );
            my @func_genes = MetaUtil::getTaxonFuncMetaGenes( $taxon_oid, $2, $func_id );
            for my $gene_oid (@func_genes) {
                if ( $genes_href->{$gene_oid} ) {
                    $gene_count++;
                }
            }
        }

        $func2count_h{$func_id} = $gene_count;
        #print "countScafFuncGene() $func_id added count $gene_count<br/>\n";
    }

    return %func2count_h;
}

sub processGenesForMetaScaf {
    my ( $meta_scaffold, $taxon_datatype_href, $data_type ) = @_;

    my ($taxon_oid, $d2, $scaffold_oid) = split( / /, $meta_scaffold );
    if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
        && ($d2 ne $data_type) ) {
            return;
    }
    my $key = "$taxon_oid $d2";

    # get genes on this scaffold
    my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $d2, $scaffold_oid );
    for my $s2 (@genes_on_s) {
        my (
            $gene_oid,  $locus_type, $locus_tag, $gene_display_name, $start_coord,
            $end_coord, $strand,     $seq_id,    $source
          )
          = split( /\t/, $s2 );

        my $workspace_id = "$taxon_oid $d2 $gene_oid";
        if ( $taxon_datatype_href->{$key} ) {
            my $h_ref = $taxon_datatype_href->{$key};
            $h_ref->{$gene_oid} = 1;
        } else {
            my %hash2;
            $hash2{$gene_oid} = 1;
            $taxon_datatype_href->{$key}  = \%hash2;
        }
    }

}


##############################################################################
# countMetaTaxonScafFuncGene - count genes in scaffold with functions
##############################################################################
sub countMetaTaxonScafFuncGene {
    my ( $dbh, $taxon_oid, $data_type, $func_groups_ref, 
        $scaf_func2genes_href, $taxon_scaffolds_href, $limiting_scaffolds_href ) = @_;

    my %genes_h;
    my %taxon_genes;
    my @func_groups = @$func_groups_ref;

    my $cnt = 0;
    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        foreach my $func_ids_ref (@func_groups) {
            my $func_id0 = @$func_ids_ref[0];
            my $func_tag = MetaUtil::getFuncTagFromFuncId( $func_id0 );
            if ( !$func_tag ) {
                print "<p>Unknown function ID $func_id0\n";
                next;
            }
            #print "countMetaTaxonScafFuncGene() taxon_oid=$taxon_oid, t2=$t2, func_tag=$func_tag, func_ids_ref=@$func_ids_ref<br/>\n";
            
            my ( $metacyc2ec_href, $ec2metacyc_href );
            if ( $func_id0 =~ /MetaCyc\:/i ) {
                ( $metacyc2ec_href, $ec2metacyc_href ) = QueryUtil::fetchMetaCyc2EcHash( $dbh, $func_ids_ref );
                my @ec_ids = keys %$ec2metacyc_href;
                $func_ids_ref = \@ec_ids;
                #print "countMetaTaxonScafFuncGene() metacyc func_ids_ref=@$func_ids_ref<br/>\n";
            }
                                
            print "Computing $taxon_oid $t2 funcs genes<br/>\n";
            my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, $func_tag, $func_ids_ref ); 
            #print "countMetaTaxonScafFuncGene() func_genes:<br/>\n";
            #print Dumper(\%func_genes);
            #print "<br/>\n";
            for my $func2 ( @$func_ids_ref ) {
                my @func_genes = split( /\t/, $func_genes{$func2} );

                my @func2s;
                if ( $func_id0 =~ /MetaCyc/i ) {
                    my $metacyc_ids_ref = $ec2metacyc_href->{$func2};
                    @func2s = @$metacyc_ids_ref;
                }
                else {
                    @func2s = ( $func2 );
                }

                foreach my $func_id ( @func2s ) {
                    $func_id = WorkspaceQueryUtil::addBackFuncIdPrefix( $func_id0, $func_id );
                    for my $gene_oid (@func_genes) {
                        my $workspace_id = "$taxon_oid $t2 $gene_oid";
                        if ( $genes_h{$workspace_id} ) {
                            my $funcs_ref = $genes_h{$workspace_id};
                            push( @$funcs_ref, $func_id );
                        } else {
                            my @func_ids = ($func_id);
                            $genes_h{$workspace_id} = \@func_ids;
                        }
    
                        my $key = "$taxon_oid $t2";
                        if ( $taxon_genes{$key} ) {
                            my $oid_ref = $taxon_genes{$key};
                            push( @$oid_ref, $gene_oid );
                        } else {
                            my @oid = ($gene_oid);
                            $taxon_genes{$key} = \@oid;
                        }
                        
                        $cnt++;
                        if ( ( $cnt % 500 ) == 0 ) {
                            print ".";
                        }
                    }
                }
            }
        }
    }
    #print "countMetaTaxonScafFuncGene() genes_h:<br/>\n";
    #print Dumper(\%genes_h);
    #print "<br/>\n";

    my %gene_info_h;
    if ( scalar( keys %genes_h ) > 0 ) {
        MetaUtil::getAllMetaGeneInfo( \%genes_h, '', \%gene_info_h, '', \%taxon_genes, 1, 0, 1 );
        #print "countMetaTaxonScafFuncGene() called " . currDateTime() . "<br/>\n";
        #print Dumper(\%scaf_id_h);
    }

    for my $workspace_id ( keys %gene_info_h ) {
        my ( $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaf_id, $tid2, $dtype2 )
              = split( /\t/, $gene_info_h{$workspace_id} );
        my ( $taxon, $t2, $gene_oid ) = split( / /, $workspace_id );
        if ( ! $scaf_id ) {
            next;
        }
        if ( $limiting_scaffolds_href && defined($limiting_scaffolds_href) ) {
            next if ( ! $limiting_scaffolds_href->{$scaf_id} );
        }
        
        my $scaf_workspace_id = "$taxon $t2 $scaf_id";
        if ( $taxon_scaffolds_href && defined($taxon_scaffolds_href) ) {
            my $scaffolds_href = $taxon_scaffolds_href->{$taxon};
            if ( $scaffolds_href ) {
                $scaffolds_href->{$scaf_workspace_id} = 1;
            }
            else {
                my %scaffolds_h;
                $scaffolds_h{$scaf_workspace_id} = 1;
                $taxon_scaffolds_href->{$taxon} = \%scaffolds_h;
            }
        }
                  
        my $funcs_ref = $genes_h{$workspace_id};
        foreach my $func_id ( @$funcs_ref ) {
            my $func2genes_href = $scaf_func2genes_href->{$scaf_workspace_id};
            if ( $func2genes_href ) {
                my $genes_href = $func2genes_href->{$func_id};
                if ( $genes_href ) {
                    $genes_href->{$gene_oid} = 1;
                }
                else {
                    my %gene_ids_h;
                    $gene_ids_h{$gene_oid} = 1;
                    $func2genes_href->{$func_id} = \%gene_ids_h;
                }
                #print "countMetaTaxonScafFuncGene() $scaf_workspace_id, $func_id added<br/>\n";                                    
            }
            else {
                my %gene_ids_h;
                $gene_ids_h{$gene_oid} = 1;
                my %func2genes_h;
                $func2genes_h{$func_id} = \%gene_ids_h;
                $scaf_func2genes_href->{$scaf_workspace_id} = \%func2genes_h;
                #print "countMetaTaxonScafFuncGene() $scaf_workspace_id, $func_id new<br/>\n";
            }
        }
    }
    
}

##############################################################################
# countDbScafFuncGene - count genes in each scaffold with functions
##############################################################################
sub countDbScafFuncGene {
    my ( $dbh, $input_scaffolds, $func_groups_ref, $scaf_func2genes_href ) = @_;

    #print "<p>counting scaffold gene functions ...\n";

    my @db_scaffolds;
    if ( $input_scaffolds ) {
        foreach my $input_scaffold (@$input_scaffolds) {
            # just one scaffold
            if ( WebUtil::isInt($input_scaffold) ) {
                push @db_scaffolds, ($input_scaffold);
            }            
        }
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    if ( scalar(@db_scaffolds) > 0 ) {
        my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @db_scaffolds );
        foreach my $func_ids_ref (@$func_groups_ref) {
            execDbScafsFuncsGenes( $dbh, $scaf_func2genes_href, $func_ids_ref, $scaf_str, $rclause, $imgClause );
        }
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $scaf_str =~ /gtt_num_id/i );
    }
    #print "countDbScafFuncGene() scaf_func2genes_href<br/>\n";
    #print Dumper($scaf_func2genes_href)."<br/>\n";
}

sub execDbScafsFuncsGenes {
    my ( $dbh, $scaf_func2genes_href, $func_ids_ref, $scaf_str, $rclause, $imgClause ) = @_;

    my $func_id0 = @$func_ids_ref[0];

    #print "execDbScafsFuncsGenes() func_type=$func_type, func_ids_ref: @$func_ids_ref<br/>\n";
    my ( $sql, @bindList ) =
      WorkspaceQueryUtil::getDbScaffoldFuncsGenesSql( $dbh, $func_ids_ref, $scaf_str, $rclause, $imgClause );
    #print "execDbScafsFuncsGenes() sql: $sql<br/>\n";
    if ( $sql ) {
        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $scaf_id, $func_id, $t_id, $gene_name ) = $cur->fetchrow();
            last if ( !$gene_oid );
            $func_id = WorkspaceQueryUtil::addBackFuncIdPrefix( $func_id0, $func_id );
            #print "execDbScafsFuncsGenes() retrieved $gene_oid, $scaf_id, $func_id, $t_id, $gene_name<br/>\n";
            
            my $func2genes_href = $scaf_func2genes_href->{$scaf_id};
            if ( $func2genes_href ) {
                my $genes_href = $func2genes_href->{$func_id};
                if ( $genes_href ) {
                    $genes_href->{$gene_oid} = 1;
                }
                else {
                    my %genes_h;
                    $genes_h{$gene_oid} = 1;
                    $func2genes_href->{$func_id} = \%genes_h;
                }
                #print "execDbScafsFuncsGenes() $scaf_id, $func_id added<br/>\n";                                    
            }
            else {
                my %genes_h;
                $genes_h{$gene_oid} = 1;
                my %func2genes_h;
                $func2genes_h{$func_id} = \%genes_h;
                $scaf_func2genes_href->{$scaf_id} = \%func2genes_h;
                #print "execDbScafsFuncsGenes() $scaf_id, $func_id new<br/>\n";
            }
        }
        $cur->finish();                
    }
    #print "execDbScafsFuncsGenes() scaf_func2count_href<br/>\n";
    #print Dumper($scaf_func2genes_href)."<br/>\n";
    
}

###############################################################################
# showScafProfileGeneList - show all genes in a file with selected function
###############################################################################
sub showScafProfileGeneList {
    my $sid = getContactOid();

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $folder = param('directory');
    print hiddenVar( "directory", "$folder" ) if ( $folder );
    $folder = $SCAF_FOLDER;

    my $func_id = param('func_id');
    print hiddenVar( "func_id", $func_id );

    my $dbh = dbLogin();

    my $input_file = param('input_file');
    if ( !$input_file ) {
        $input_file = param('share_input_file');
    }
    my ($owner, $x) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $input_file, $ownerFilesetDelim, $SCAF_FOLDER );
    my $share_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $owner, $x, $sid );
    print hiddenVar( "input_file", $input_file );

    my $scaffold_oid = param('scaffold_oid');
    print hiddenVar( "scaffold_oid", $scaffold_oid ) if ($scaffold_oid);

    my $data_type = param('data_type');
    print hiddenVar( "data_type", $data_type ) if ($data_type);

    if ($scaffold_oid) {
        print "<h1>Scaffold Function Profile Gene List</h1>\n";
    } else {
        print "<h1>Scaffold Set Function Profile Gene List</h1>\n";
    }
    print "<p>";
    print "Function: $func_id";
    my $func_name = Workspace::getMetaFuncName($func_id);
    if ( $func_name ) {
       print " (" . $func_name . ")";
    }
    print "<br/>\n";
    print "Scaffold Set: $share_set_name<br/>\n" if ( $share_set_name );
    if ($scaffold_oid) {
        if ( WebUtil::isInt($scaffold_oid) ) {
            print "Scaffold: $scaffold_oid<br/>\n";
        }
        else {
            my ( $t_oid, $d2, $scaf_oid ) = split( / /, $scaffold_oid );
            print "Scaffold: $scaf_oid<br/>\n";
        }
    }
    HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
    print "</p>";

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    print "<p>\n";
    my $trunc = 0;

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    my %taxon_datatype_h;
    my @db_scaffolds;

    if ( $scaffold_oid ) {
        if ( WebUtil::isInt($scaffold_oid) ) {
            push @db_scaffolds, ($scaffold_oid);            
        }
        else {
            processGenesForMetaScaf( $scaffold_oid, \%taxon_datatype_h, $data_type );            
        }
    }
    
    print "<p>Processing $input_file ...<br/>\n";
    open( FH, "$workspace_dir/$owner/$folder/$x" )
      or webError("File size - file error $input_file");

    while ( my $line = <FH> ) {
        #print "WorkspaceScafSet::showScafProfileGeneList line: $line<br/>\n";
        chomp($line);
        if ( $scaffold_oid && $line ne $scaffold_oid ) {
            next;
        }

        if ( WebUtil::isInt($line) ) {
            push @db_scaffolds, ($line);
        }
        else {
            processGenesForMetaScaf( $line, \%taxon_datatype_h, $data_type );
        }
    }    # end while line
    close FH;
    print "<br/>\n";
    
    my $select_id_name = "gene_oid";

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",     "char asc", "left" );
    $it->addColSpec( "Function ID", "char asc", "left" );
    my $sd = $it->getSdDelim();

    # database
    my $gene_count = 0;
    if ( scalar(@db_scaffolds) > 0 ) {
        print "Retriving information from database ...<br/>\n";
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @db_scaffolds );
        my ( $sql, @bindList ) =
          WorkspaceQueryUtil::getDbScaffoldFuncGeneSql( $func_id, $scaf_str, $rclause, $imgClause );
        #print "showScafProfileGeneList() sql: $sql<br/>\n";
        #print "showScafProfileGeneList() bindList: @bindList<br/>\n";

        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $func_id2, $t_id, $gene_name ) = $cur->fetchrow();
            last if ( !$gene_oid );

            my $r;
            my $workspace_id = $gene_oid;
            $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
            my $url = "$main_cgi?section=GeneDetail";
            $url .= "&page=geneDetail&gene_oid=$gene_oid";
            $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
            $r   .= $func_id . $sd . $func_id . "\t";
            $it->addRow($r);

            $gene_count++;
            if ( $gene_count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $scaf_str =~ /gtt_num_id/i );

    }
    print "<br/>\n";

    # file
    print "<p>Preparing results ...<br/>\n";
    for my $key ( keys %taxon_datatype_h ) {
        my $h_ref = $taxon_datatype_h{$key};
        if ( !$h_ref ) {
            next;
        }

        my ( $taxon_oid, $data_type ) = split( / /, $key );
        my @func_genes = MetaUtil::getTaxonFuncMetaGenes( $taxon_oid, $data_type, $func_id );

        for my $gene_oid (@func_genes) {

            #print "WorkspaceScafSet::showScafProfileGeneList gene_oid: $gene_oid<br/>\n";
            if ( $h_ref->{$gene_oid} ) {
                my $r;
                my $workspace_id = "$taxon_oid $data_type $gene_oid";
                $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                my $url = "$main_cgi?section=MetaGeneDetail";
                $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid" 
                    . "&data_type=$data_type&gene_oid=$gene_oid";
                $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                $r   .= $func_id . $sd . $func_id . "\t";
                $it->addRow($r);

                $gene_count++;
                if ( ( $gene_count % 10 ) == 0 ) {
                    print ".";
                }
                if ( ( $gene_count % 1800 ) == 0 ) {
                    print "<br/>";
                }
                if ( $gene_count >= $maxGeneListResults ) {
                    $trunc = 1;
                    last;
                }
            }
        }
    }

    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
    }

    if ( $gene_count == 0 ) {
        print "<p><b>No genes have been found.</b>\n";
        print end_form();
        return;
    }

    $it->printOuterTable(1);

    WebUtil::printGeneCartFooter();
    print "<br/><br/>";

    if ($scaffold_oid) {
        WorkspaceUtil::printSaveAndExpandTabsForGenes( $select_id_name, '', '', '', 1 );
    } else {
        WorkspaceUtil::printSaveAndExpandTabsForGenes( $select_id_name );
    }

    print end_form();
}

###############################################################################
# showScafCateProfileGeneList - show all genes in a file with selected function
###############################################################################
sub showScafCateProfileGeneList {

    printMainForm();

    my $sid = getContactOid();

    my $folder = param('directory');
    print hiddenVar( "directory", "$folder" );

    my $func_id = param('func_id');
    print hiddenVar( "func_id",    $func_id );

    my $dbh = dbLogin();

    my $input_file = param('input_file');
    if ( !$input_file ) {
        $input_file = param('share_input_file');
    }
    my ($owner, $x) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $input_file, $ownerFilesetDelim, $SCAF_FOLDER );
    my $share_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $owner, $x, $sid );
    print hiddenVar( "input_file", $input_file );

    my $scaffold_oid = param('scaffold_oid');
    if ($scaffold_oid) {
        print "<h1>Scaffold Function Category Profile Gene List</h1>\n";
    } else {
        print "<h1>Scaffold Set Function Category Profile Gene List</h1>\n";
    }

    print "<p>";
    print "Function: $func_id<br/>\n";
    print "Scaffold Set: $share_set_name<br/>\n" if ();
    if ($scaffold_oid) {
        print "Scaffold: $scaffold_oid<br/>\n";
    }
    print "</p>";

    my $func_name = Workspace::getMetaFuncName($func_id);
    print "<h4>$func_name</h4>\n";

    printStatusLine( "Loading ...", 1 );

    my $sid = getContactOid();
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    print "<p>\n";
    my $trunc = 0;

    my %taxon_datatype_h;
    undef %taxon_datatype_h;
    my $folder = $SCAF_FOLDER;

    my @db_scaffolds = ();

    print "<p>Processing $input_file ...<br/>\n";

    open( FH, "$workspace_dir/$owner/$folder/$x" )
      or webError("File size - file error $input_file");

    my $line_no = 0;
    while ( my $line = <FH> ) {
        chomp($line);
        if ( $scaffold_oid && $line ne $scaffold_oid ) {
            next;
        }

        $line_no++;
        if ( ( $line_no % 100 ) == 0 ) {
            print ".";
        }
        if ( ( $line_no % 18000 ) == 0 ) {
            print "<br/>";
        }

        my $taxon_oid;
        my $data_type;
        my $scaffold_oid;
        my $key;
        if ( WebUtil::isInt($line) ) {
            $scaffold_oid = $line;
            $data_type    = "database";
            $key = $data_type;
            push @db_scaffolds, ($scaffold_oid);
            next;
        }
        else {
            ($taxon_oid, $data_type, $scaffold_oid)  = split( / /, $line );
            $key = "$taxon_oid $data_type";
        }

        # get genes on this scaffold
        my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );

        for my $s2 (@genes_on_s) {
            my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id,
                $source ) = split( /\t/, $s2 );
            my $workspace_id = "$taxon_oid $data_type $gene_oid";

            if ( $taxon_datatype_h{$key} ) {
                my $h_ref = $taxon_datatype_h{$key};
                $h_ref->{$gene_oid} = 1;
            } else {
                my %hash2;
                undef %hash2;
                $hash2{$gene_oid} = 1;
                $taxon_datatype_h{$key}  = \%hash2;
            }
        }    # end for s2
    }    # end while line
    close FH;
    print "<br/>\n";

    my $select_id_name = "gene_oid";

    my $gene_count = 0;

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",     "char asc", "left" );
    $it->addColSpec( "Function ID", "char asc", "left" );
    my $sd = $it->getSdDelim();

    # database
    if ( scalar(@db_scaffolds) > 0 ) {
        print "<p>Retrieving information from database ...<br/>\n";

        my $dbh       = dbLogin();
        my $rclause   = WebUtil::urClause('f.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('f.taxon');
        my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @db_scaffolds );

        my $sql   = "";
        my $db_id = $func_id;
        if ( $func_id =~ /COG\_Category/i ) {
            my ( $id1, $id2 ) = split( /\:/, $func_id );
            if ($id2) {
                $db_id = $id2;
                $sql   = qq{
                    select distinct f.gene_oid, cf.functions
                    from gene_cog_groups f, cog_functions cf
                    where f.cog = cf.cog_id
                    and cf.functions = ?
                    and f.scaffold in ( $scaf_str )
                    $rclause
                    $imgClause
                };
            }
        } elsif ( $func_id =~ /COG\_Pathway/i ) {
            my ( $id1, $id2 ) = split( /\:/, $func_id );
            if ($id2) {
                $db_id = $id2;
                $sql   = qq{
                    select distinct f.gene_oid, cpcm.cog_pathway_oid
                    from gene_cog_groups f, cog_pathway_cog_members cpcm
                    where f.cog = cpcm.cog_members
                    and cpcm.cog_pathway_oid = ?
                    and f.scaffold in ( $scaf_str )
                    $rclause
                    $imgClause
                };
            }
        } elsif ( $func_id =~ /COG/i ) {
            $sql = qq{
                select distinct f.gene_oid, f.cog 
                from gene_cog_groups f
                where f.cog = ?
                and f.scaffold in ( $scaf_str )
                $rclause
                $imgClause
            };
        } elsif ( $func_id =~ /KEGG\_Category\_EC/i ) {
            my ( $id1, $id2 ) = split( /\:/, $func_id );
            if ($id2) {
                $db_id = $id2;
                $sql   = qq{                                                                           
                    select distinct f.gene_oid, kp3.min_pid
                    from gene_ko_enzymes f, ko_term_enzymes kt, image_roi_ko_terms rk, 
                    image_roi ir, kegg_pathway kp,
                     (select kp2.category category, min(kp2.pathway_oid) min_pid
                      from kegg_pathway kp2
                      where kp2.category is not null
                      group by kp2.category) kp3
                    where f.enzymes = kt.enzymes
                     and kt.ko_id = rk.ko_terms
                     and rk.roi_id = ir.roi_id
                     and ir.pathway = kp.pathway_oid
                     and kp.category is not null 
                     and kp.category = kp3.category
                     and kp3.min_pid = ?
                     and f.scaffold in ( $scaf_str )
                    $rclause
                    $imgClause
                };
            }
        } elsif ( $func_id =~ /KEGG\_Category\_KO/i ) {
            my ( $id1, $id2 ) = split( /\:/, $func_id );
            if ($id2) {
                $db_id = $id2;
                $sql   = qq{                                                                           
                    select distinct f.gene_oid, kp3.min_pid
                     from gene_ko_terms f, image_roi_ko_terms rk,
                     image_roi ir, kegg_pathway kp,
                     (select kp2.category category, min(kp2.pathway_oid) min_pid
                      from kegg_pathway kp2
                      where kp2.category is not null
                      group by kp2.category) kp3
                    where f.ko_terms = rk.ko_terms
                     and rk.roi_id = ir.roi_id
                     and ir.pathway = kp.pathway_oid
                     and kp.category is not null 
                     and kp.category = kp3.category
                     and kp3.min_pid = ?
                     and f.scaffold in ( $scaf_str )
                    $rclause
                    $imgClause
                };
            }
        } elsif ( $func_id =~ /KEGG\_Pathway\_EC/i ) {
            my ( $id1, $id2 ) = split( /\:/, $func_id );
            if ($id2) {
                $db_id = $id2;
                $sql   = qq{
                    select distinct f.gene_oid, ir.pathway
                    from gene_ko_enzymes f, ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir
                    where f.enzymes = kt.enzymes
                     and kt.ko_id = rk.ko_terms
                     and rk.roi_id = ir.roi_id
                     and ir.pathway = ?
                     and f.scaffold in ( $scaf_str )
                    $rclause
                    $imgClause
                };
            }
        } elsif ( $func_id =~ /KEGG\_Pathway\_KO/i ) {
            my ( $id1, $id2 ) = split( /\:/, $func_id );
            if ($id2) {
                $db_id = $id2;
                $sql   = qq{                                                                           
                    select distinct f.gene_oid, ir.pathway
                    from gene_ko_terms f, image_roi_ko_terms rk, image_roi ir
                    where f.ko_terms = rk.ko_terms
                     and rk.roi_id = ir.roi_id
                     and ir.pathway = ?
                     and f.scaffold in ( $scaf_str )
                    $rclause
                    $imgClause
                };
            }
        } elsif ( $func_id =~ /Pfam\_Category/i ) {
            my ( $id1, $id2 ) = split( /\:/, $func_id );
            if ($id2) {
                $db_id = $id2;
                $sql   = qq{
                    select distinct f.gene_oid, pfc.functions
                    from gene_pfam_families f, pfam_family_cogs pfc
                    where f.pfam_family = pfc.ext_accession
                    and pfc.functions = ?
                    and f.scaffold in ( $scaf_str )
                    $rclause
                    $imgClause
                };
            }
        } elsif ( $func_id =~ /pfam/i ) {
            $sql = qq{
                select distinct f.gene_oid, f.pfam_family
                from gene_pfam_families f
                where f.pfam_family = ?
                and f.scaffold in ( $scaf_str )
                $rclause
                $imgClause
            };
        } elsif ( $func_id =~ /TIGRfam\_Role/i ) {
            my ( $id1, $id2 ) = split( /\:/, $func_id );
            if ($id2) {
                $db_id = $id2;
                $sql   = qq{
                    select distinct f.gene_oid, tr.roles
                    from gene_tigrfams f, tigrfam_roles tr
                    where tr.ext_accession = f.ext_accession
                    and tr.roles = ?
                    and f.scaffold in ( $scaf_str )
                    $rclause
                    $imgClause
                };
            }
        } elsif ( $func_id =~ /TIGR/i ) {
            $sql = qq{
                select distinct f.gene_oid, f.ext_accession 
                from gene_tigrfams f
                where f.ext_accession = ?
                and f.scaffold in ( $scaf_str )
                $rclause
                $imgClause
            };
        } elsif ( $func_id =~ /KO/i ) {
            $sql = qq{
                select distinct f.gene_oid, f.ko_terms 
                from gene_ko_terms f
                where f.ko_terms = ?
                and f.scaffold in ( $scaf_str )
                $rclause
                $imgClause
            };
        } elsif ( $func_id =~ /EC/i ) {
            $sql = qq{
                select distinct f.gene_oid, f.enzymes 
                from gene_ko_enzymes f
                where f.enzymes = ?
                and f.scaffold in ( $scaf_str )
                $rclause
                $imgClause
            };
        }

        if ( $sql && $db_id ) {
            my $cur = execSql( $dbh, $sql, $verbose, $db_id );
            for ( ; ; ) {
                my ( $gene_oid, $func_id2 ) = $cur->fetchrow();
                last if ( !$gene_oid );

                my $r;
                my $workspace_id = $gene_oid;
                $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                my $url = "$main_cgi?section=GeneDetail";
                $url .= "&page=geneDetail&gene_oid=$gene_oid";
                $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                $r   .= $func_id . $sd . $func_id . "\t";
                $it->addRow($r);

                $gene_count++;
                if ( $gene_count >= $maxGeneListResults ) {
                    $trunc = 1;
                    last;
                }
            }
            $cur->finish();
        }
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $scaf_str =~ /gtt_num_id/i );

    }
    print "<br/>\n";

    # file
    print "<p>Preparing results ...<br/>\n";
    for my $key ( keys %taxon_datatype_h ) {
        my $h_ref = $taxon_datatype_h{$key};
        if ( !$h_ref ) {
            next;
        }

        my ( $taxon_oid, $data_type ) = split( / /, $key );
        my @func_genes = MetaUtil::getTaxonFuncMetaGenes( $taxon_oid, $data_type, $func_id );

        for my $gene_oid (@func_genes) {
            if ( $h_ref->{$gene_oid} ) {
                my $r;
                my $workspace_id = "$taxon_oid $data_type $gene_oid";
                $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                my $url = "$main_cgi?section=MetaGeneDetail";
                $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid" . "&data_type=$data_type&gene_oid=$gene_oid";
                $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                $r   .= $func_id . $sd . $func_id . "\t";
                $it->addRow($r);

                $gene_count++;
                if ( $gene_count >= $maxGeneListResults ) {
                    $trunc = 1;
                    last;
                }
            }
        }
    }

    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
    }

    if ($gene_count) {
        $it->printOuterTable(1);

        WebUtil::printGeneCartFooter();

        MetaGeneTable::printMetaGeneTableSelect();

        # add to gene cart
        WorkspaceUtil::printSaveGeneToWorkspace_withAllGeneCart($select_id_name);
    }

    print end_form();
}

#############################################################################
# showScafFunctionProfile - show scaffold function profile 
#                           for selected function type
# needs to be merged with showScafFuncCategoryProfile
#############################################################################
sub showScafFunctionProfile {
    my ($isSet) = @_;

    my $sid = getContactOid();

    printMainForm();
    my $dbh = dbLogin();

    my $folder   = param("directory");
    print hiddenVar( "directory", "$folder" );

    my $functype = param('functype');
    print hiddenVar( "functype", "$functype" );

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);

    my $fileFullname = param('filename');
    #print "fileFullname $fileFullname<br/>\n";
    my @scaffold_oids = param('scaffold_oid');
    #print "scaffold_oids @scaffold_oids<br/>\n";
    for my $y (@scaffold_oids) {
        print hiddenVar( "scaffold_oid", $y );
    }

    my $data_type = param('data_type');
    print hiddenVar( "data_type", $data_type ) if ($data_type);

    if ($isSet) {
        validateScaffoldSelection( $isSet, @all_files );
        print "<h1>Scaffold Set Function Profile ($functype)</h1>\n";
        print "<p>Profile is based on scaffold set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected scaffold set(s): ";
	WorkspaceUtil::printShareSetName($dbh, $sid, @all_files);
	print "<br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    } else {
        validateScaffoldSelection( $isSet, @scaffold_oids );
        my ( $scaffoldDisplayIds_ref, $db_scaffolds_ref, $fs_scaffolds_ref ) = WorkspaceUtil::catalogOids(@scaffold_oids);
        print "<h1>Scaffold Function Profile ($functype)</h1>\n";
        print
"<p>Profile is based on individual scaffolds in scaffold set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected scaffold(s): <i>@$scaffoldDisplayIds_ref</i><br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }

    my $trunc = 0;

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    my @all_funcs = Workspace::getAllFuncIds($dbh, $functype);
    if ( scalar(@all_funcs) == 0 ) {
        print "<p>No functions associated with function type $functype\n";
        return;
    }
    
    my $func_tag = MetaUtil::getFuncTagFromFuncType( $functype );
    if ( !$func_tag ) {
        print "<p>Unknown function type $functype\n";
        return;
    }

    my %gene_func_list;
    my %file_scaf_hash;

    my @db_scaffolds;
    my %fs_scaffolds;

    my $start_time  = time();
    my $timeout_msg = "";

    # decide which zip files are needed
    # gene_func_list stores all genes on scaffolds (files) that need to be counted
    # file_scaf_hash stores file -> scaffold_oid
    for my $x2 (@all_files) {
    	my ($c_oid, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
    	if ( ! $c_oid || ! $x ) {
    	    next;
    	}

        if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 ) {
            $timeout_msg =
                "Process takes too long to run "
              . "-- stopped at $x. "
              . "Only partial counts are displayed.";
            last;
        }

        print "<p>Pre-processing workspace file $x ...\n";
        open( FH, "$workspace_dir/$c_oid/$folder/$x" )
          or webError("File size - file error $x");

        while ( my $line = <FH> ) {
            chomp($line);

            if ( $file_scaf_hash{$x2} ) {
                my $h_ref = $file_scaf_hash{$x2};
                $h_ref->{$line} = 1;
            } else {
                my %hash2;
                $hash2{$line} = 1;
                $file_scaf_hash{$x2} = \%hash2;
            }

            if ( isInt($line) ) {
                push @db_scaffolds, ($line);
            } else {
                if ( $fs_scaffolds{$line} ) {
                    # already processed
                    next;
                } else {
                    $fs_scaffolds{$line} = 1;
                }

                my ( $taxon_oid, $d2, $scaffold_oid ) = split( / /, $line );
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
                    && ($d2 ne $data_type) ) {
                        next;
                }

                # get genes on this scaffold
                my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $d2, $scaffold_oid );
                $fs_scaffolds{$line} = \@genes_on_s;

                if ( scalar(@genes_on_s) > 100 ) {
    
                    # long scaffold
                    my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $d2, $func_tag );    
                    if ( scalar( keys %func_genes ) > 0 ) {
                        for my $func_id (@all_funcs) {
                            if ( $func_genes{$func_id} ) {
                                my @recs = split( /\t/, $func_genes{$func_id} );
                                for my $gid2 (@recs) {
                                    my $workspace_id = "$taxon_oid $d2 $gid2";
                                    if ( $gene_func_list{$workspace_id} ) {
                                        $gene_func_list{$workspace_id} .= " " . $func_id;
                                    } else {
                                        $gene_func_list{$workspace_id} = $func_id;
                                    }
                                }
                            }
                        }
    
                    } 
                } else {
    
                    # loop through each gene to get functions
                    for my $s2 (@genes_on_s) {
                        my (
                            $gene_oid,  $locus_type, $locus_tag, $gene_display_name, $start_coord,
                            $end_coord, $strand,     $seq_id,    $source
                          )
                          = split( /\t/, $s2 );
    
                        my $workspace_id = "$taxon_oid $d2 $gene_oid";
                        my @gene_funcs   = ();
                        if ( $functype eq 'COG' ) {
                            @gene_funcs = MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, $data_type );
                        } elsif ( $functype eq 'Pfam' ) {
                            @gene_funcs = MetaUtil::getGenePfamId( $gene_oid, $taxon_oid, $data_type );
                        } elsif ( $functype eq 'TIGRfam' ) {
                            @gene_funcs = MetaUtil::getGeneTIGRfamId( $gene_oid, $taxon_oid, $data_type );
                        } elsif ( $functype eq 'KO' ) {
                            @gene_funcs = MetaUtil::getGeneKoId( $gene_oid, $taxon_oid, $data_type );
                        } elsif ( $functype eq 'Enzymes' ) {
                            @gene_funcs = MetaUtil::getGeneEc( $gene_oid, $taxon_oid, $data_type );
                        }
    
                        if ( scalar(@gene_funcs) > 0 ) {
                            $gene_func_list{$workspace_id} = join( " ", @gene_funcs );
                        }
                    }    # end for s2
                }

            }
            
        }    # end while FH
        close FH;
    }    #end for x
    print "\n";

    # store all func_id that has count
    my %func_key_hash;

    # store "func_id scaffold_oid" -> count
    my %func_scaf_hash;

    # database
    # we query database to get count for (func_id scaffold_oid) pair
    if ( scalar(@db_scaffolds) > 0 && !$timeout_msg ) {
        print "<p>Query database ...\n";

        my $dbh       = dbLogin();
        my $rclause   = WebUtil::urClause('f.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('f.taxon');
        my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @db_scaffolds );

        my ( $sql ) =
          WorkspaceQueryUtil::getDbScaffoldFuncCategoryGeneSql( $functype, $scaf_str, $rclause, $imgClause );
        #print "showScafFunctionProfile() sql=$sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $s_oid, $func_id ) = $cur->fetchrow();
            last if ( !$gene_oid );

            if ( $s_oid && $func_id ) {
                my $k2 = "$func_id $s_oid";
                if ( !( defined $func_scaf_hash{$k2} ) ) {
                    $func_scaf_hash{$k2} = 1;
                } else {
                    $func_scaf_hash{$k2} += 1;
                }
            }

            if ( !defined $func_key_hash{$func_id} ) {
                $func_key_hash{$func_id} = 1;
            }
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $scaf_str =~ /gtt_num_id/i );
    }

    # file
    for my $x2 (@all_files) {
        if ( $trunc || $timeout_msg ) {
            last;
        }

    	my ($c_oid, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
    	if ( ! $c_oid || ! $x ) {
    	    next;
    	}
        print "<p>Processing workspace scaffold set $x ...\n";
        open( FH, "$workspace_dir/$c_oid/$folder/$x" )
          or webError("File size - file error $x");

        my $count = 0;
        while ( my $line = <FH> ) {
            chomp($line);

            if ( isInt($line) ) {
                next;
            } else {
                my ( $taxon_oid, $d2, $scaffold_oid ) = split( / /, $line );
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
                    && ($d2 ne $data_type) ) {
                        next;
                }

                # get genes on this scaffold
                my @genes_on_s;
                my $genes_on_s_ref = $fs_scaffolds{$line};
                if ( $genes_on_s_ref ) {
                    @genes_on_s = @$genes_on_s_ref;
                } else {
                    @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $d2, $scaffold_oid );
                }

                for my $s2 (@genes_on_s) {
                    my (
                        $gene_oid,  $locus_type, $locus_tag, $gene_display_name, $start_coord,
                        $end_coord, $strand,     $seq_id,    $source
                      )
                      = split( /\t/, $s2 );
                    my $workspace_id = "$taxon_oid $d2 $gene_oid";

                    if ( $gene_func_list{$workspace_id} ) {

                        # gene has function(s)
                        my @funcs = split( / /, $gene_func_list{$workspace_id} );
                        for my $func_id ( ( sort @funcs ) ) {
                            my $k2 = "$func_id $line";
                            if ( !( defined $func_scaf_hash{$k2} ) ) {
                                $func_scaf_hash{$k2} = 1;
                            } else {
                                $func_scaf_hash{$k2} += 1;
                            }

                            if ( !defined $func_key_hash{$func_id} ) {
                                $func_key_hash{$func_id} = 1;
                            }
                        }
                    }
                }
            }

            $count++;
            if ( ( $count % 10000 ) == 0 ) {
                print "<p>$count rows processed ...\n";
                if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 ) {
                    $timeout_msg =
                        "Process takes too long to run "
                      . "-- stopped at $x line no: $count. "
                      . "Only partial counts are displayed.";
                    last;
                }
            }
        }
        close FH;
    }    # end for x

    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    my @keys = ( keys %func_key_hash );
    if ( scalar(@keys) == 0 ) {
        print "<p>No genes in the selected scaffold sets have this function types.\n";
        print end_form();
        return;
    }
    my %func_names = QueryUtil::fetchFuncIdAndName( $dbh, \@keys );

    # print result
    my $it = new InnerTable( 1, "scafFunc$$", "scafFunc", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Function ID",   "char asc", "left" );
    $it->addColSpec( "Function Name", "char asc", "left" );

    if ($isSet) {
        for my $x (@all_files) {
	    my $x_name = WorkspaceUtil::getShareSetName($dbh, $x, $sid);
	    my ($n1, $n2) = split(/ /, $x_name, 2);
	    if ( $n2 ) {
		$x_name = $n1 . "<br/>" . $n2;
	    }
            $it->addColSpec( $x_name, "number asc", "right" );
        }
    } else {
        my ( $db_scafs_ref, $file_scafs_ref ) = MerFsUtil::splitDbAndMetaOids(@scaffold_oids);
        if ( scalar(@$db_scafs_ref) > 0 ) {
            my %oid2name_h = QueryUtil::fetchScaffoldNameHash( $dbh, @$db_scafs_ref );
            for my $oid (@$db_scafs_ref) {
                my $scaf_name = $oid2name_h{$oid};
                $it->addColSpec( $scaf_name, "number asc", "right" );
            }
        }
        if ( scalar(@$file_scafs_ref) > 0 ) {
            for my $scaffold_oid (@$file_scafs_ref) {
                my $col_name = join("<br/>", split(/ /, $scaffold_oid));
                $it->addColSpec( $col_name, "number asc", "right");
            }
        }
    }

    my $prev_key = "";
    for my $k ( ( sort @keys ) ) {
        if ( $k eq $prev_key ) {
            next;
        }

        my $r = $sd . "<input type='checkbox' name='func_id' value='$k' />\t";
        $r .= $k . $sd . $k . "\t";
        $r .= $func_names{$k} . $sd . $func_names{$k} . "\t";

        for my $x (@all_files) {
            my $cnt2  = 0;
            my $h_ref = $file_scaf_hash{$x};
            for my $k2 ( keys %$h_ref ) {
                my $k3   = "$k $k2";
                my $cnt3 = $func_scaf_hash{$k3};
                if ($isSet) {
                    if ($cnt3) {
                        $cnt2 += $cnt3;
                    }
                } else {

                    # individual scaffold
                    if ($cnt3) {
                        my $url =
                            "$section_cgi&page=scafProfileGeneList&directory=$folder"
                          . "&scaffold_oid=$k2"
                          . "&share_input_file=$x&func_id=$k";
                        $url .= "&data_type=$data_type" if ( $data_type );
                        $r .= $cnt3 . $sd . alink( $url, $cnt3 ) . "\t";
                    } else {
                        $r .= "0" . $sd . "0\t";
                    }
                }
            }

            if ( !$isSet ) {
                next;
            }

            if ($cnt2) {
                my $url = "$section_cgi&page=scafProfileGeneList&directory=$folder" 
                    . "&share_input_file=$x&func_id=$k";
                $url .= "&data_type=$data_type" if ( $data_type );
                $r .= $cnt2 . $sd . alink( $url, $cnt2 ) . "\t";
            } else {
                $r .= "0" . $sd . "0\t";
            }
        }
        $it->addRow($r);

        $prev_key = $k;
    }

    if ($timeout_msg) {
        printMessage("<font color='red'>Warning: $timeout_msg</font>");
    }

    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    #    print "<p><font color='red'>Need to add buttons to save functions or save genes.</font>\n";
    WorkspaceUtil::printFuncGeneSaveToWorkspace( $SCAF_FOLDER, $isSet );
    print end_form();
}

#############################################################################
# showScafFuncCategoryProfile - show scaffold function profile
#                               for selected function category
# for COG Category, COG Pathway, etc.
#############################################################################
sub showScafFuncCategoryProfile {
    my ($isSet) = @_;

    my $sid = getContactOid();

    printMainForm();
    my $dbh = dbLogin();

    my $folder   = param("directory");
    print hiddenVar( "directory", "$folder" );

    my $functype = param('functype');
    print hiddenVar( "functype", "$functype" );

    #print "<p>*** $functype\n";
    #return;

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);

    my $fileFullname = param('filename');
    #print "fileFullname $fileFullname<br/>\n";
    my @scaffold_oids = param('scaffold_oid');
    #print "scaffold_oids @scaffold_oids<br/>\n";
    for my $y (@scaffold_oids) {
        print hiddenVar( "scaffold_oid", $y );
    }

    my $data_type = param('data_type');
    print hiddenVar( "data_type", $data_type ) if ($data_type);

    if ($isSet) {
        validateScaffoldSelection( $isSet, @all_files );
        print "<h1>Scaffold Set Function Category Profile ($functype)</h1>\n";
        print "<p>Profile is based on scaffold set(s).  Counts in the data table are gene counts.<br/>\n";

        print "Selected scaffold set(s): ";
    	WorkspaceUtil::printShareSetName($dbh, $sid, @all_files);
    	print "<br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    } else {
        validateScaffoldSelection( $isSet, @scaffold_oids );
        print "<h1>Scaffold Function Category Profile ($functype)</h1>\n";
        print
"<p>Profile is based on individual scaffolds in scaffold set(s).  Counts in the data table are gene counts.<br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }

    my $trunc = 0;

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    # get all function IDs and names
    my %func_names = QueryUtil::getFuncTypeNames($dbh, $functype);
    my @func_ids   = sort ( keys %func_names );
    if ( scalar(@func_ids) == 0 ) {
        printEndWorkingDiv();
        webError("Incorrect function type.\n");
        return;
    }
    #print "showScafFuncCategoryProfile() func_names: <br/>\n";
    #print Dumper(\%func_names);
    #print "<br/>\n";

    # need func_id to category mapping
    my %funcId_category_h = QueryUtil::getFunc2Category( $dbh, $functype );
    my @all_funcs = keys %funcId_category_h;
    if ( scalar(@all_funcs) == 0 ) {
        print "<p>No functions associated with function type $functype\n";
        return;
    }
    #print "showScafFuncCategoryProfile() funcId_category_h: <br/>\n";
    #print Dumper(\%funcId_category_h);
    #print "<br/>\n";
    
    my $func_tag = MetaUtil::getFuncTagFromFuncType( $functype );
    if ( !$func_tag ) {
        print "<p>Unknown function type $functype\n";
        return;
    }

    my $start_time  = time();
    my $timeout_msg = "";

    my %gene_func_list;
    my %file_scaf_hash;
    
    my @db_scaffolds;
    my %fs_scaffolds;

    # decide which zip files are needed
    # gene_func_list stores all genes on scaffolds (files) that need to be counted
    # file_scaf_hash stores file -> scaffold_oid
    for my $x2 (@all_files) {
    	my ($c_oid, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
    	if ( ! $c_oid || ! $x ) {
    	    next;
    	}

        if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 ) {
            $timeout_msg =
                "Process takes too long to run "
              . "-- stopped at $x2. "
              . "Only partial counts are displayed.";
            last;
        }

        print "<p>Pre-processing workspace file $x2 ...\n";
        open( FH, "$workspace_dir/$c_oid/$folder/$x" )
          or webError("File size - file error $x2");

        while ( my $line = <FH> ) {
            chomp($line);

            if ( $file_scaf_hash{$x2} ) {
                my $h_ref = $file_scaf_hash{$x2};
                $h_ref->{$line} = 1;
            } else {
                my %hash2;
                $hash2{$line} = 1;
                $file_scaf_hash{$x2} = \%hash2;
            }

            if ( isInt($line) ) {
                push @db_scaffolds, ($line);
            } else {
                if ( $fs_scaffolds{$line} ) {
                    # already processed
                    next;
                } else {
                    $fs_scaffolds{$line} = 1;
                }

                my ( $taxon_oid, $d2, $scaffold_oid ) = split( / /, $line );
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
                    && ($d2 ne $data_type) ) {
                        next;
                }

                # get genes on this scaffold
                my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $d2, $scaffold_oid );
                $fs_scaffolds{$line} = \@genes_on_s;

                if ( scalar(@genes_on_s) > 100 ) {
    
                    # long scaffold
                    my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $d2, $func_tag );
                    if ( scalar( keys %func_genes ) > 0 ) {
                        for my $func_id (@all_funcs) {
                            if ( $func_genes{$func_id} ) {
                                my @recs = split( /\t/, $func_genes{$func_id} );
                                for my $gid2 (@recs) {
                                    my $workspace_id = "$taxon_oid $d2 $gid2";
                                    if ( $gene_func_list{$workspace_id} ) {
                                        $gene_func_list{$workspace_id} .= " " . $func_id;
                                    } else {
                                        $gene_func_list{$workspace_id} = $func_id;
                                    }
                                }
                            }
                        }
                    } 
                } else {
    
                    # loop through each gene to get functions
                    for my $s2 (@genes_on_s) {
                        my (
                            $gene_oid,  $locus_type, $locus_tag, $gene_display_name, $start_coord,
                            $end_coord, $strand,     $seq_id,    $source
                          )
                          = split( /\t/, $s2 );
    
                        my $workspace_id = "$taxon_oid $d2 $gene_oid";
                        my @gene_funcs   = ();
                        if ( $functype =~ /COG/i ) {
                            @gene_funcs = MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, $data_type );
                        } elsif ( $functype =~ /Pfam/i ) {
                            @gene_funcs = MetaUtil::getGenePfamId( $gene_oid, $taxon_oid, $data_type );
                        } elsif ( $functype =~ /TIGRfam/i ) {
                            @gene_funcs = MetaUtil::getGeneTIGRfamId( $gene_oid, $taxon_oid, $data_type );
                        } elsif ( $functype =~ /KO/i ) {
                            @gene_funcs = MetaUtil::getGeneKoId( $gene_oid, $taxon_oid, $data_type );
                        } elsif ( $functype =~ /Enzymes/i || $functype =~ /EC/i ) {
                            @gene_funcs = MetaUtil::getGeneEc( $gene_oid, $taxon_oid, $data_type );
                        }
    
                        if ( scalar(@gene_funcs) > 0 ) {
                            $gene_func_list{$workspace_id} = join( " ", @gene_funcs );
                        }
                    }    # end for s2
                }
            }
        }    # end while FH
        close FH;
    }    #end for x
    print "\n";

    # store all func_id that has count
    my %func_key_hash;

    # store "func_id scaffold_oid" -> count
    my %func_scaf_hash;

    # database
    # we query database to get count for (func_id scaffold_oid) pair
    if ( scalar(@db_scaffolds) > 0 && !$timeout_msg ) {
        print "<p>Query database ...\n";

        my $rclause   = WebUtil::urClause('f.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('f.taxon');
        my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @db_scaffolds );

        my ( $sql ) =
          WorkspaceQueryUtil::getDbScaffoldFuncCategoryGeneSql( $functype, $scaf_str, $rclause, $imgClause );
        print "showScafFuncCategoryProfile() sql=$sql<br/>\n";
        if ( $sql ) {
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $gene_oid, $s_oid, $func_id ) = $cur->fetchrow();
                last if ( !$gene_oid );

                if ( $s_oid && $func_id ) {
                    my $k2 = "$func_id $s_oid";
                    if ( !( defined $func_scaf_hash{$k2} ) ) {
                        $func_scaf_hash{$k2} = 1;
                    } else {
                        $func_scaf_hash{$k2} += 1;
                    }
                }

                if ( !defined $func_key_hash{$func_id} ) {
                    $func_key_hash{$func_id} = 1;
                }
            }
            $cur->finish();
        }
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $scaf_str =~ /gtt_num_id/i );
    }

    print "<p>Processing FS ...\n";

    # file
    for my $x2 (@all_files) {
        if ( $trunc || $timeout_msg ) {
            last;
        }

    	my ($c_oid, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
    	if ( ! $c_oid || ! $x ) {
    	    next;
    	}

        print "<p>Processing workspace scaffold set $x ...\n";
        open( FH, "$workspace_dir/$c_oid/$folder/$x" )
          or webError("File size - file error $x");

        my $count = 0;
        while ( my $line = <FH> ) {
            chomp($line);

            if ( isInt($line) ) {
                next;
            } else {

                my ( $taxon_oid, $d2, $scaffold_oid ) = split( / /, $line );
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
                    && ($d2 ne $data_type) ) {
                        next;
                }

                # get genes on this scaffold
                my @genes_on_s;
                my $genes_on_s_ref = $fs_scaffolds{$line};
                if ( $genes_on_s_ref ) {
                    @genes_on_s = @$genes_on_s_ref;
                } else {
                    @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $d2, $scaffold_oid );
                }

                for my $s2 (@genes_on_s) {
                    my (
                        $gene_oid,  $locus_type, $locus_tag, $gene_display_name, $start_coord,
                        $end_coord, $strand,     $seq_id,    $source
                      )
                      = split( /\t/, $s2 );
                    my $workspace_id = "$taxon_oid $d2 $gene_oid";

                    if ( $gene_func_list{$workspace_id} ) {

                        # gene has function(s)
                        my @funcs;
                        for my $f2 ( split( / /, $gene_func_list{$workspace_id} ) ) {
                            if ( $funcId_category_h{$f2} ) {
                                my $cateIds_href = $funcId_category_h{$f2};
                                @funcs = keys %$cateIds_href;
                            }
                        }

                        for my $func_id ( ( sort @funcs ) ) {
                            my $k2 = "$func_id $line";
                            if ( !( defined $func_scaf_hash{$k2} ) ) {
                                $func_scaf_hash{$k2} = 1;
                            } else {
                                $func_scaf_hash{$k2} += 1;
                            }

                            if ( !defined $func_key_hash{$func_id} ) {
                                $func_key_hash{$func_id} = 1;
                            }
                        }
                    }
                }

            }
            
            $count++;
            if ( ( $count % 10000 ) == 0 ) {
                print "<p>$count rows processed ...\n";
                if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 ) {
                    $timeout_msg =
                        "Process takes too long to run "
                      . "-- stopped at $x line no: $count. "
                      . "Only partial counts are displayed.";
                    last;
                }
            }
        }
        close FH;
    }    # end for x

    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    my @keys = ( keys %func_key_hash );
    if ( scalar(@keys) == 0 ) {
        print "<p>No genes in the selected scaffold sets have this function types.\n";
        print end_form();
        return;
    }

    # print result
    my $it = new InnerTable( 1, "scafFunc$$", "scafFunc", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Function ID",   "char asc", "left" );
    $it->addColSpec( "Function Name", "char asc", "left" );

    for my $x (@all_files) {
        if ($isSet) {
    	    my $x_name = WorkspaceUtil::getShareSetName($dbh, $x, $sid);
    	    my ($n1, $n2) = split(/ /, $x_name, 2);
    	    if ( $n2 ) {
        		$x_name = $n1 . "<br/>" . $n2;
    	    }
            $it->addColSpec( $x_name, "number asc", "right" );
        } else {
            my $h_ref = $file_scaf_hash{$x};
            my @scaffold_oids = keys %$h_ref;
            my ( $db_scafs_ref, $file_scafs_ref ) = MerFsUtil::splitDbAndMetaOids(@scaffold_oids);
            if ( scalar(@$db_scafs_ref) > 0 ) {
                my %oid2name_h = QueryUtil::fetchScaffoldNameHash( $dbh, @$db_scafs_ref );
                for my $oid (@$db_scafs_ref) {
                    my $scaf_name = $oid2name_h{$oid};
                    $it->addColSpec( $scaf_name, "number asc", "right" );
                }
            }
            if ( scalar(@$file_scafs_ref) > 0 ) {
                for my $scaffold_oid (@$file_scafs_ref) {
                    my $col_name = join("<br/>", split(/ /, $scaffold_oid));
                    $it->addColSpec( $col_name, "number asc", "right");
                }
            }
        }
    }

    my $prev_key = "";
    for my $k ( ( sort @keys ) ) {
        if ( $k eq $prev_key ) {
            next;
        }

        if ( !$func_names{$k} ) {
            next;
        }

        my $select_id = $functype . ':' . $k;
        my $r = $sd . "<input type='checkbox' name='func_id' value='$select_id' />\t";
        $r .= $k . $sd . $k . "\t";
        $r .= $func_names{$k} . $sd . $func_names{$k} . "\t";

        for my $x (@all_files) {
            my $cnt2  = 0;
            my $h_ref = $file_scaf_hash{$x};
            for my $k2 ( keys %$h_ref ) {
                my $k3   = "$k $k2";
                my $cnt3 = $func_scaf_hash{$k3};
                if ($isSet) {
                    if ($cnt3) {
                        $cnt2 += $cnt3;
                    }
                } else {

                    # individual scaffold
                    if ($cnt3) {
                        my $url =
                            "$section_cgi&page=scafCateProfileGeneList"
                          . "&scaffold_oid=$k2"
                          . "&share_input_file=$x&func_id="
                          . $functype . ':'
                          . $k;
                        $url .= "&data_type=$data_type" if ( $data_type );
                        $r .= $cnt3 . $sd . alink( $url, $cnt3 ) . "\t";
                    } else {
                        $r .= "0" . $sd . "0\t";
                    }
                }
            }

            if ( !$isSet ) {
                next;
            }

            if ($cnt2) {
                my $url = "$section_cgi&page=scafCateProfileGeneList" 
                    . "&share_input_file=$x&func_id=" . $functype . ':' . $k;
                $url .= "&data_type=$data_type" if ( $data_type );
                $r .= $cnt2 . $sd . alink( $url, $cnt2 ) . "\t";
            } else {
                $r .= "0" . $sd . "0\t";
            }
        }
        $it->addRow($r);

        $prev_key = $k;
    }
    $it->printOuterTable(1);

    WebUtil::printButtonFooter();

    if ( Workspace::isSimpleFuncType($functype) ) {
        WorkspaceUtil::printFuncGeneSaveToWorkspace( $SCAF_FOLDER, $isSet );
    } elsif ( Workspace::isComplicatedFuncCategory($functype) ) {
        WorkspaceUtil::printExtFuncGeneSaveToWorkspace();
    }

    print end_form();
}

#############################################################################
# printScafHistogram
#############################################################################
sub printScafHistogram {
    my ( $isSet ) = @_;

    printMainForm();

    my $folder = $SCAF_FOLDER;

    my $h_type = param('histogram_type');
    if ( $isSet ) {
        print hiddenVar( "isSet", $isSet );
    }

    my $sid = getContactOid();
    #if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
    #    print "<p>*** time1: " . currDateTime() . "\n";
    #}

    my $data_type = param('data_type_h');
    print hiddenVar( "data_type", $data_type );

    if ( $isSet ) {
        my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);
        if ( scalar(@all_files) == 0 ) {
            webError("No scaffold sets are selected.");
            return;
        }

        my $dbh = dbLogin();

        my @scaffold_oids;
        my %filename2scaffolds;
        my %filename2shareSetName;
        
        foreach my $file_set_name (@all_files) {
            my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $file_set_name, $ownerFilesetDelim, $folder );
            open( FH, "$workspace_dir/$owner/$folder/$x" )
              or webError("File size - file error $x");

            my @oids;
            while ( my $line = <FH> ) {
                chomp($line);
                WebUtil::strTrim($line);
                push(@oids, $line);
            }
            close FH;
            push(@scaffold_oids, @oids);
            $filename2scaffolds{$file_set_name} = \@oids;

            my $shareSetName = WorkspaceUtil::fetchShareSetName($dbh, $owner, $x, $sid);
            $filename2shareSetName{$file_set_name} = $shareSetName;
        }

    	HistogramUtil::printScafSetHistogram
    	    ( $h_type, \@scaffold_oids, $data_type, \%filename2scaffolds, \%filename2shareSetName );
        
    } else {
        my @scaffold_oids = param('scaffold_oid');
        if ( scalar(@scaffold_oids) == 0 ) {
            webError("No scaffolds have been selected. Please select scaffolds for histogram.");
            return;
        }
        foreach my $scaffold_oid (@scaffold_oids) {
            print hiddenVar( 'scaffold_oid', $scaffold_oid );
        }
        my $x = param('filename');
        HistogramUtil::printScaffoldHistogram
	       ( $h_type, \@scaffold_oids, $data_type, $x );
    }

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    print end_form();
}

sub editScaffoldSets {

    my $dbh = dbLogin();
    my $sid = getContactOid();
    my $folder = $SCAF_FOLDER;

    my $h_type = param("type");
    my @scaf_set_names = param("scaf_set_name");

    my %set2scfs;
    my %set2shareSetName;
    foreach my $scaf_set (@scaf_set_names) {	
    	my @allscaffold_oids;
        my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $scaf_set, $ownerFilesetDelim, $folder );
    	open( FH, "$workspace_dir/$owner/$folder/$x" )
    	    or webError("File size - file error $scaf_set");
	    
    	my %scaf_h;
        while ( my $line = <FH> ) {
            chomp($line);
            $scaf_h{$line} = 1;
        }
        close FH;
        @allscaffold_oids = keys %scaf_h;
    
    	my @ranges = param("range");
    	my ($lower, $upper);
    
    	# First, get the scaffolds for the selected ranges for each set,
    	# then, call printDetailForSets
    	my @selected;
    	foreach my $range (@ranges) {
    	    ($lower, $upper) = split( " to ", $range );
    	    my $selected_aref = HistogramUtil::getHistogramScaffoldList
    		(\@allscaffold_oids, $h_type, $lower, $upper, $scaf_set);
    	    push @selected, @$selected_aref if scalar @$selected_aref > 0;
    	}
    	$set2scfs{ $scaf_set } = \@selected;

        my $shareSetName = WorkspaceUtil::fetchShareSetName($dbh, $owner, $x, $sid);    	
        $set2shareSetName{ $scaf_set } = $shareSetName;
    }

    printDetailForSets(\%set2scfs, \%set2shareSetName, 0);
}

############################################################################
# printHistogramScaffolds
############################################################################
sub printHistogramScaffolds {
    my ( $h_type ) = @_;

    my $sid = getContactOid();
    my $isSet  = param('isSet');
    print hiddenVar( "isSet", $isSet );

    my @filenames = param('input_file');
    for my $x (@filenames) {
        print hiddenVar( "input_file", $x );
    }

    my $scaf_set_name = param('scaf_set_name');
    if ($isSet) {
    	if ( !$scaf_set_name && scalar(@filenames) > 0 ) {
    	    $scaf_set_name = $filenames[0];
    	}
    	if ( !$scaf_set_name ) {
    	    # see if the link comes from the bar chart:
    	    $scaf_set_name = param('series');
    	    if ( !$scaf_set_name ) {
        		webError("No scaffold set has been selected.");
        		return;
    	    }
    	}
    }

    my $data_type = param('data_type');
    print hiddenVar( "data_type", $data_type ) if ($data_type);

    my $tblname = "scafSet_"."$scaf_set_name";
    print start_form(-id     => "$tblname"."_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi" );

    my $folder = $SCAF_FOLDER;
    my @scaffold_oids;
    my $scaf_set_share_name = $scaf_set_name;
    if ($isSet) {
        my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $scaf_set_name, $ownerFilesetDelim, $folder );
        open( FH, "$workspace_dir/$owner/$folder/$x" )
          or webError("File size - file error $scaf_set_name");

        my %scaf_h;
        while ( my $line = <FH> ) {
            chomp($line);
            $scaf_h{$line} = 1;
        }
        close FH;
        @scaffold_oids = keys %scaf_h;
        
        my $dbh = dbLogin();
        my $shareSetName = WorkspaceUtil::fetchShareSetName($dbh, $owner, $x, $sid);
        $scaf_set_share_name = $shareSetName;
    } else {
        @scaffold_oids = param('scaffold_oid');
        foreach my $scaffold_oid (@scaffold_oids) {
            print hiddenVar( 'scaffold_oid', $scaffold_oid );
        }
    }

    my ( $lower, $upper );
    my $range = param('range');
    if ( $range ) {
        ( $lower, $upper ) = split( /\:/, $range );        
    }
    else {
    	# if the link is from the bar chart:
    	$range = param('category');
    	if ( !$range ) {
    	    $lower = param('lower');
    	    $upper = param('upper');        
    	} else {
    	    ( $lower, $upper ) = split( " to ", $range );        
    	}
    }

    HistogramUtil::printHistogramScaffoldList
	( \@scaffold_oids, $h_type, $lower, $upper, $data_type,
	  $scaf_set_name, $scaf_set_share_name );
    print end_form();
}

############################################################################
# printScafKmer
############################################################################
sub printScafKmer {
    my ($isSet) = @_;

    my $sid = getContactOid();
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    my $folder = $SCAF_FOLDER;

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);
    if ( scalar(@all_files) == 0 ) {
        webError("No scaffold sets are selected.");
        return;
    }

    my $data_type = param('data_type_k');
    print hiddenVar( "data_type", $data_type );
    if ( $include_metagenomes ) {
        if ( ! $data_type ) {
            $data_type = 'assembled';
        }
        if ( $data_type ne 'assembled' ) {
            webError("Only assembled MER_FS scaffold is supported in Kmer.");
            return;
        }
    }

    my $dbh = dbLogin();

    my %set2scafs;
    my %set2shareSetName;
    my @scaffold_oids;
    my $ignoreSettings;
    if ($isSet) {
        
        foreach my $x2 (@all_files) {
    	    my ($c_oid, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
    	    if ( ! $c_oid || ! $x ) {
        		next;
    	    }

            open( FH, "$workspace_dir/$c_oid/$folder/$x" )
		      or webError("File size - file error $x");

            my %scaf_h;
            while ( my $line = <FH> ) {
                chomp($line);

                if ( isInt($line) ) {
                    #database
                } else {
                    my ( $taxon_oid, $d2, $scaffold_oid ) = split( / /, $line );
                    if ( ( $data_type eq 'assembled' ) && ($d2 ne $data_type) ) {
                            next;
                    }
                }
                $scaf_h{$line} = 1;
            }
            close FH;

            my @scaf_oids = keys %scaf_h;
            push(@scaffold_oids, @scaf_oids);
            $set2scafs{$x2} = \@scaf_oids;

            my $share_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $c_oid, $x, $sid );
            $set2shareSetName{$x2} = $share_set_name;
        }
        $ignoreSettings = 1;

    } else {
        my @s_oids = param('scaffold_oid');
        if ( scalar(@s_oids) == 0 ) {
            webError("No scaffolds have been selected. Please select scaffolds for Kmer.");
            return;
        }
        my %scaf_h;
        for my $scaffold_oid (@s_oids) {
            if ( isInt($scaffold_oid) ) {
                #database
            } else {
                my ( $taxon_oid, $d2, $scaf_oid ) = split( / /, $scaffold_oid );
                if ( ( $data_type eq 'assembled' ) && ($d2 ne $data_type) ) {
                        next;
                }
            }
            $scaf_h{$scaffold_oid} = 1;            
        }
        my @scaf_oids = keys %scaf_h;
        push(@scaffold_oids, @scaf_oids);
        my $x = param('filename');
        $set2scafs{$x} = \@scaf_oids;
    }

    if ( scalar(@scaffold_oids) == 0 ) {
        webError("Only assembled MER_FS scaffold is supported in Kmer.");
        return;
    }

    require Kmer;
    Kmer::kmerPlotScaf( \@scaffold_oids, \%set2scafs, \%set2shareSetName, $isSet, $ignoreSettings );

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

}

############################################################################
# printScafPhyloDist
# print scaffolds or scaffold sets phylo distribution
############################################################################
sub printScafPhyloDist {
    my ( $isSet, $isSingleScafDetail ) = @_;
    #print "printScafPhyloDist() isSet=$isSet, isSingleScafDetail=$isSingleScafDetail<br/>\n";

    my $sid = getContactOid();
    if ( blankStr($sid) ) {
        webError("Your login has expired.");
        return;
    }

    my $folder = $SCAF_FOLDER;
    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);
    my $data_type = param('data_type_p');

    my @scaffold_oids;
    if ($isSet) {
        # use selected scaffold sets
        if ( scalar(@all_files) == 0 ) {
            webError("Select at least one scaffold set for phylogenetic distribution.");
            return;
        }

        # get all scaffold ids
        my %scaffolds;
        for my $x2 (@all_files) {
    	    my ($c_oid, $input_file) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
    	    if ( ! $c_oid || ! $input_file ) {
        		next;
    	    }

            #print "Reading scaffold set $input_file ...<br/>\n";

            #my $full_path = "$workspace_dir/$c_oid/$folder/" . $input_file;
            open( FH, "$workspace_dir/$c_oid/$folder/$input_file" )
              or webError("File size - file error $input_file");

            while ( my $line = <FH> ) {
                chomp($line);
                WebUtil::strTrim($line);
                $scaffolds{$line} = 1;
            }            
            close FH;
        }
        @scaffold_oids = sort(keys %scaffolds);
    } else {

        # use selected scaffold oids
        my @scaf_oids = param('scaffold_oid');
        if ( scalar(@scaf_oids) == 0 ) {
            printEndWorkingDiv();
            webError("No scaffolds have been selected.");
            return;
        }
        @scaffold_oids = sort(@scaf_oids);
    }

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    my ( $scaffolds_href, $orgCount_href, $genomeHitStats_href,
        $stats30_href, $stats60_href, $stats90_href, 
        $totalGeneCount, $totalCopyCount, 
        $remainCount30, $remainCount60, $remainCount90, 
        $remainCopy30, $remainCopy60, $remainCopy90 ) 
        = processScafPhyloDist( \@scaffold_oids, $data_type );
        
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    viewScafPhyloDist( $isSet, $isSingleScafDetail, $data_type,
        $scaffolds_href, $orgCount_href, $genomeHitStats_href, 
        $stats30_href, $stats60_href, $stats90_href, 
        $totalGeneCount, $totalCopyCount, 
        $remainCount30, $remainCount60, $remainCount90, 
        $remainCopy30, $remainCopy60, $remainCopy90 );

}

sub processScafPhyloDist {
    my ( $scaffolds_ref, $data_type ) = @_;

    my $start_time  = time();
    my $timeout_msg;

    printStartWorkingDiv();
    
    print "Retrieving scaffold information ...<br/>\n";
    my $dbh = dbLogin();
    
    my ( $intOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@$scaffolds_ref);

    my %scaffolds_h;
    my @db_scaffolds;
    my %db_metaTaxon2scaffolds;
    my %file_metaTaxon2scaffolds;
    
    if ( scalar(@$intOids_ref) > 0 ) {
        my $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @$intOids_ref );
        my $sql3         = qq{
            select s.scaffold_oid, s.taxon, t.genome_type, t.in_file
            from scaffold s, taxon t 
            where s.taxon = t.taxon_oid 
            and s.scaffold_oid in ($oids_str)
        };
        #print "processScafPhyloDist() sql3: $sql3<br/>\n";

        my $cur3 = execSql( $dbh, $sql3, $verbose );
        for ( ; ; ) {
            my ( $scaf_id2, $tid2, $genome_type, $in_file ) = $cur3->fetchrow();
            last if !$scaf_id2;

            if ( $genome_type eq 'metagenome' && $in_file eq 'No' ) {
                if ($tid2) {
                    # metagenome in Oracle, but phylo dist in SQLite
                    my $t_scafs_ref = $db_metaTaxon2scaffolds{$tid2};
                    if ($t_scafs_ref) {
                        push( @$t_scafs_ref, $scaf_id2 );
                    } else {
                        my @t_scafs = ($scaf_id2);
                        $db_metaTaxon2scaffolds{$tid2} = \@t_scafs;
                    }
                    $scaffolds_h{"$tid2 database $scaf_id2"} = $tid2;
                }
            } else {
                push( @db_scaffolds, $scaf_id2 );
                $scaffolds_h{$scaf_id2} = 1;
                #print "processScafPhyloDist() add scaf_id2: $scaf_id2<br/>\n";
            }
        }
        $cur3->finish();
    }

    if ( scalar(@$metaOids_ref) > 0 ) {
        for my $k (@$metaOids_ref) {
            #print "processScafPhyloDist() metaOids: $k<br/>\n";
            my ( $t, $d2, $scaf ) = split( / /, $k );
            if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
                && ($d2 ne $data_type) ) {
                    next;
            }
            my $taxon_data_type  = "$t $d2";
            my $t_type_scafs_ref = $file_metaTaxon2scaffolds{$taxon_data_type};
            if ( $t_type_scafs_ref ne '' ) {
                push( @$t_type_scafs_ref, $scaf );
            } else {
                my @t_type_scafs = ($scaf);
                $file_metaTaxon2scaffolds{$taxon_data_type} = \@t_type_scafs;
            }
            $scaffolds_h{$k} = 2;
        }
    }

    my $totalGeneCount = 0;
    my $totalCopyCount = 0;
    my $remainCount30  = 0;
    my $remainCount60  = 0;
    my $remainCount90  = 0;
    my $remainCopy30   = 0;
    my $remainCopy60   = 0;
    my $remainCopy90   = 0;
    my $ct30           = 0;
    my $ct60           = 0;
    my $ct90           = 0;
    my $dt30           = 0;
    my $dt60           = 0;
    my $dt90           = 0;
    my %stats30;
    my %stats60;
    my %stats90;
    my %scafHitStats;

    # database scaffolds
    if ( scalar(@db_scaffolds) > 0 ) {
        my $scafGeneCount = getScafGeneCount( $dbh, \@db_scaffolds );
        my $scafGeneCopy = getScafGeneCopy( $dbh, \@db_scaffolds );
        if ( $scafGeneCopy < $scafGeneCount ) {
            $scafGeneCopy = $scafGeneCount;
        }
        $totalGeneCount += $scafGeneCount;
        $totalCopyCount += $scafGeneCopy;
        #print "processScafPhyloDist() db scafGeneCount=$scafGeneCount, scafGeneCopy=$scafGeneCopy<br/>\n";

        my ( $c30, $c60, $c90, $d30, $d60, $d90 ) = loadScaffoldStats_db( 
            $dbh, $contact_oid, \@db_scaffolds, 
            \%stats30, \%stats60, \%stats90, \%scafHitStats );
        #my ( $c30, $d30 ) = loadScaffoldStats_db_old( $dbh, \@db_scaffolds, 30, \%stats30 );
        #my ( $c60, $d60 ) = loadScaffoldStats_db_old( $dbh, \@db_scaffolds, 60, \%stats60 );
        #my ( $c90, $d90 ) = loadScaffoldStats_db_old( $dbh, \@db_scaffolds, 90, \%stats90 );
        #loadScaffoldHitStats( $dbh, \@db_scaffolds, \%scafHitStats );
        #print "processScafPhyloDist() db c30=$c30, c60=$c60, c90=$c90, d30=$d30, d60=$d60, d90=$d90<br/>\n";

        $ct30 += $c30;
        $ct60 += $c60;
        $ct90 += $c90;
        $remainCount30 += ( $scafGeneCount - $c30 - $c60 - $c90 );
        $remainCount60 += ( $scafGeneCount - $c60 - $c90 );
        $remainCount90 += ( $scafGeneCount - $c90 );

        $dt30 += $d30;
        $dt60 += $d60;
        $dt90 += $d90;
        $remainCopy30 += ( $scafGeneCopy - $d30 - $d60 - $d90 );
        $remainCopy60 += ( $scafGeneCopy - $d60 - $d90 );
        $remainCopy90 += ( $scafGeneCopy - $d90 );
    }

    if ( scalar(keys %db_metaTaxon2scaffolds) > 0 || scalar(keys %file_metaTaxon2scaffolds) > 0 ) {
        my $taxon_href = PhyloUtil::getTaxonTaxonomy( $dbh );

        for my $taxon_oid ( keys %db_metaTaxon2scaffolds ) {
            if ( !$taxon_href->{$taxon_oid} ) {
                next;
            }

            if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 300 ) {
                $timeout_msg = "Process takes too long to run.";
                last;
            }

            my $taxonGeneCount = 0;
            my $taxonCopyCount = 0;
            my $t_scafs_ref    = $db_metaTaxon2scaffolds{$taxon_oid};
            if ( $t_scafs_ref ne '' && scalar(@$t_scafs_ref) > 0 ) {
                my %genes_on_scaffolds = getScaffoldGenesForDbScaffolds( $dbh, $t_scafs_ref );
                my %depth_on_scaffolds = getScaffoldDepthForDbScaffolds( $dbh, $t_scafs_ref );
            
                for my $scaf (@$t_scafs_ref) {
                    my $genes_on_s_ref = $genes_on_scaffolds{$scaf};
                    my $scaf_depth = $depth_on_scaffolds{$scaf};

                    my $scaffold_gene_cnt  = 0;
                    my $scaffold_gene_copy = 0;
                    for my $g2 (@$genes_on_s_ref) {
                        my (
                            $gid,       $locus_type, $locus_tag, $gene_display_name, $start_coord,
                            $end_coord, $strand,     $seq_id,    $source
                          )
                          = split( /\t/, $g2 );
                        if ( $locus_type eq 'CDS' ) {
                            $scaffold_gene_cnt++;
                            $scaffold_gene_copy += $scaf_depth;
                        }
                    }
                    if ( $scaffold_gene_copy < $scaffold_gene_cnt ) {
                        $scaffold_gene_copy = $scaffold_gene_cnt;
                    }

                    $taxonGeneCount += $scaffold_gene_cnt;
                    $totalGeneCount += $scaffold_gene_cnt;
                    $taxonCopyCount += $scaffold_gene_copy;
                    $totalCopyCount += $scaffold_gene_copy;
                }
                #print "processScafPhyloDist() taxon_oid=$taxon_oid db meta taxonGeneCount=$taxonGeneCount, taxonCopyCount=$taxonCopyCount<br/>\n";

                # get distribution
                print "<p>Loading taxon $taxon_oid scaffold stats ...<br/>\n";
                my ( $c30, $c60, $c90, $d30, $d60, $d90 );
                my $phylo_name = MetaUtil::getPhyloDistTaxonDir($taxon_oid) . "/assembled.profile.txt";
                if ( -e $phylo_name ) {
                    ( $c30, $c60, $c90, $d30, $d60, $d90 ) = loadScaffoldStats_sdb(
                        $taxon_oid, 'assembled', $t_scafs_ref, \%genes_on_scaffolds, 0,
                        $taxon_href,  \%stats30,    \%stats60,            \%stats90,
                        \%scafHitStats
                    );
                }
                #print "processScafPhyloDist() taxon_oid=$taxon_oid db meta c30= $c30, c60=$c60, c90=$c90, d30=$d30, d60=$d60, d90=$d90<br/>\n";

                $ct30 += $c30;
                $ct60 += $c60;
                $ct90 += $c90;
                $remainCount30 += ( $taxonGeneCount - $c30 - $c60 - $c90 );
                $remainCount60 += ( $taxonGeneCount - $c60 - $c90 );
                $remainCount90 += ( $taxonGeneCount - $c90 );
                #print "processScafPhyloDist() taxon_oid=$taxon_oid db meta remainCount30=$remainCount30, remainCount60=$remainCount60, remainCount90=$remainCount90<br/>\n";
    
                $dt30 += $d30;
                $dt60 += $d60;
                $dt90 += $d90;
                $remainCopy30 += ( $taxonCopyCount - $d30 - $d60 - $d90 );
                $remainCopy60 += ( $taxonCopyCount - $d60 - $d90 );
                $remainCopy90 += ( $taxonCopyCount - $d90 );
                #print "processScafPhyloDist() taxon_oid=$taxon_oid db meta remainCopy30=$remainCopy30, remainCopy60=$remainCopy60, remainCopy90=$remainCopy90<br/>\n";
            }
        }

        #print "processScafPhyloDist() " . (keys %file_metaTaxon2scaffolds) . "<br/>\n";
        for my $t_data_type ( keys %file_metaTaxon2scaffolds ) {
            my ( $taxon_oid, $data_type ) = split( / /, $t_data_type );
            if ( !$taxon_href->{$taxon_oid} ) {
                next;
            }

            if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 300 ) {
                $timeout_msg = "Process takes too long to run.";
                last;
            }

            my $taxonGeneCount = 0;
            my $taxonCopyCount = 0;
            my $t_scafs_ref    = $file_metaTaxon2scaffolds{$t_data_type};
            if ( $t_scafs_ref ne '' && scalar(@$t_scafs_ref) > 0 ) {
                my %genes_on_scaffolds = MetaUtil::getScaffoldGenesForTaxonScaffolds( $taxon_oid, $data_type, $t_scafs_ref, 1 );
                #print "processScafPhyloDist() genes_on_scaffolds<br/>\n";
                #print Dumper(\%genes_on_scaffolds);
                #print "<br/>\n";

                my %depth_on_scaffolds = MetaUtil::getScaffoldDepthForTaxonScaffolds( $taxon_oid, $data_type, $t_scafs_ref, 1 );
                #print "processScafPhyloDist() depth_on_scaffolds<br/>\n";
                #print Dumper(\%depth_on_scaffolds);
                #print "<br/>\n";

                for my $scaf (@$t_scafs_ref) {
                    my $workspace_id   = "$taxon_oid $data_type $scaf";
                    my $genes_on_s_ref = $genes_on_scaffolds{$workspace_id};
                    my $scaf_depth     = $depth_on_scaffolds{$workspace_id};

                    my $scaffold_gene_cnt  = 0;
                    my $scaffold_gene_copy = 0;
                    for my $g2 (@$genes_on_s_ref) {
                        my (
                            $gid,       $locus_type, $locus_tag, $gene_display_name, $start_coord,
                            $end_coord, $strand,     $seq_id,    $source
                          )
                          = split( /\t/, $g2 );
                        if ( $locus_type eq 'CDS' ) {
                            $scaffold_gene_cnt++;
                            $scaffold_gene_copy += $scaf_depth;
                        }
                    }
                    if ( $scaffold_gene_copy < $scaffold_gene_cnt ) {
                        $scaffold_gene_copy = $scaffold_gene_cnt;
                    }
                    #print "processScafPhyloDist() scaf=$scaf file scaffold_gene_cnt=$scaffold_gene_cnt scaffold_gene_copy=$scaffold_gene_copy<br/>\n";

                    $taxonGeneCount += $scaffold_gene_cnt;
                    $totalGeneCount += $scaffold_gene_cnt;
                    $taxonCopyCount += $scaffold_gene_copy;
                    $totalCopyCount += $scaffold_gene_copy;
                }
                #print "processScafPhyloDist() taxon=$t_data_type file taxonGeneCount=$taxonGeneCount, taxonCopyCount=$taxonCopyCount<br/>\n";

                # get distribution
                print "<p>Loading taxon $taxon_oid scaffold stats ...<br/>\n";
                my ( $c30, $c60, $c90, $d30, $d60, $d90 );
                my $file_name = "assembled.profile.txt";
                if ( $data_type eq '' ) {
                    $file_name = "unassembled.profile.txt";
                }
                my $phylo_name = MetaUtil::getPhyloDistTaxonDir($taxon_oid) . "/" . $file_name;
                if ( -e $phylo_name ) {
                  
                    ( $c30, $c60, $c90, $d30, $d60, $d90 ) = loadScaffoldStats_sdb(
                        $taxon_oid, $data_type, $t_scafs_ref, \%genes_on_scaffolds, 1,
                        $taxon_href,  \%stats30,  \%stats60, \%stats90,
                        \%scafHitStats
                    );
                }
                #print "processScafPhyloDist() taxon=$t_data_type file c30=$c30, c60=$c60, c90=$c90, d30=$d30, d60=$d60, d90=$d90<br/>\n";

                $ct30 += $c30;
                $ct60 += $c60;
                $ct90 += $c90;
                $remainCount30 += ( $taxonGeneCount - $c30 - $c60 - $c90 );
                $remainCount60 += ( $taxonGeneCount - $c60 - $c90 );
                $remainCount90 += ( $taxonGeneCount - $c90 );
                #print "processScafPhyloDist() taxon_oid=$t_data_type file remainCount30=$remainCount30, remainCount60=$remainCount60, remainCount90=$remainCount90<br/>\n";
    
                $dt30 += $d30;
                $dt60 += $d60;
                $dt90 += $d90;
                $remainCopy30 += ( $taxonCopyCount - $d30 - $d60 - $d90 );
                $remainCopy60 += ( $taxonCopyCount - $d60 - $d90 );
                $remainCopy90 += ( $taxonCopyCount - $d90 );
                #print "processScafPhyloDist() taxon_oid=$t_data_type file remainCopy30=$remainCopy30, remainCopy60=$remainCopy60, remainCopy90=$remainCopy90<br/>\n";
            }
        }

    }
    
    if ( $timeout_msg ) {
        printEndWorkingDiv();
        printMessage($timeout_msg);
        return;
    }

    if ( $ct30 + $ct60 + $ct90 == 0 && $dt30 + $dt60 + $dt90 == 0 ) {
        printEndWorkingDiv();
        printMessage("No phylogenetic distribution has been computed here.");
        printStatusLine( "Loaded.", 2 );
        return;
    }

    print "Loading genome hits ...<br/>\n";
    
    my %genomeHitStats;
    for my $k ( keys %scafHitStats ) {
        my ( $domain, $phylum, $t ) = split( /\t/, $k );
        my $k2 = "$domain\t$phylum";
        if ( $genomeHitStats{$k2} ) {
            $genomeHitStats{$k2} += 1;
        } else {
            $genomeHitStats{$k2} = 1;
        }
    }

    my %orgCount;
    PhyloUtil::loadPhylumOrgCount( $dbh, \%orgCount );

    printEndWorkingDiv();

    return (\%scaffolds_h, \%orgCount, \%genomeHitStats, 
        \%stats30, \%stats60, \%stats90, 
        $totalGeneCount, $totalCopyCount, 
        $remainCount30, $remainCount60, $remainCount90, 
        $remainCopy30, $remainCopy60, $remainCopy90);

}

############################################################################
# getScafGeneCount
############################################################################
sub getScafGeneCount {
    my ( $dbh, $scaffold_ref ) = @_;

    if ( scalar(@$scaffold_ref) == 0 ) {
        return 0;
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffold_ref );
    my $sql = qq{
        select count(*)
        from gene g 
        where g.scaffold in ( $scaf_str )
        and g.obsolete_flag = 'No' 
        and g.locus_type = 'CDS' 
        $rclause
        $imgClause
        and g.taxon in (select t.taxon_oid from taxon t where t.obsolete_flag = 'No') 
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($totalCount) = $cur->fetchrow();
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $scaf_str =~ /gtt_num_id/i );

    return $totalCount;
}

############################################################################
# getScafGeneCopy
############################################################################
sub getScafGeneCopy {
    my ( $dbh, $scaffold_ref ) = @_;

    if ( scalar(@$scaffold_ref) == 0 ) {
        return 0;
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffold_ref );
    my $sql = qq{
        select sum(g.est_copy)
        from gene g 
        where g.scaffold in ( $scaf_str )
        and g.obsolete_flag = 'No' 
        and g.locus_type = 'CDS' 
        $rclause
        $imgClause
        and g.taxon in (select t.taxon_oid from taxon t where t.obsolete_flag = 'No') 
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($totalCopy) = $cur->fetchrow();
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $scaf_str =~ /gtt_num_id/i );

    return $totalCopy;
}

############################################################################
# loadScaffoldStats_db
# scaffold phylo distribution stats (db version)
############################################################################
sub loadScaffoldStats_db {
    my ( $dbh, $contact_oid, $scaffold_ref, 
        $stats30_href, $stats60_href, $stats90_href, $hitStats_href ) = @_;

    if ( scalar(@$scaffold_ref) == 0 ) {
        return 0;
    }

    print "<p>Rerieving scaffold information from database ...<br/>\n";

    my $rclause   = WebUtil::urClause('dt.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('dt.taxon_oid');

    my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffold_ref );
    my $sql = qq{
        select t.domain, t.phylum, t.ir_class, t.ir_order, t.family, t.genus, t.species,
            g.gene_oid, g.gene_display_name, g.est_copy, 
            dt.percent_identity, dt.homolog, dt.homolog_taxon
        from dt_phylum_dist_genes dt, gene g, taxon t
        where dt.homolog_taxon = t.taxon_oid
        and dt.gene_oid = g.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.scaffold in ( $scaf_str )
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my $cnt30  = 0;
    my $cnt60  = 0;
    my $cnt90  = 0;
    my $copy30 = 0;
    my $copy60 = 0;
    my $copy90 = 0;
    my %homo_taxons;
    for ( ; ; ) {
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
            $gene_oid, $gene_prod_name, $est_copy, 
            $percent_identity, $homolog, $homo_taxon ) = $cur->fetchrow();
        last if !$gene_oid;

        $hitStats_href->{"$domain\t$phylum\t$homo_taxon"} = 1;

        my $key = "$domain\t$phylum";
        if ( $percent_identity >= 90 ) {
            my ( $i1, $i2, $i3 ) = split( /\t/, $stats90_href->{$key} );
            if ($i1) {
                $i1++;
            } else {
                $i1 = 1;
            }
            if ($i3) {
                $i3 += $est_copy;
            } else {
                $i3 = $est_copy;
            }
            $stats90_href->{$key} = "$i1\t$i2\t$i3";
            $homo_taxons{ $key . "\t90\t$homo_taxon" } = 1;
            $cnt90++;
            $copy90 += $est_copy;
        } elsif ( $percent_identity >= 60 ) {
            my ( $i1, $i2, $i3 ) = split( /\t/, $stats60_href->{$key} );
            if ($i1) {
                $i1++;
            } else {
                $i1 = 1;
            }
            if ($i3) {
                $i3 += $est_copy;
            } else {
                $i3 = $est_copy;
            }
            $stats60_href->{$key} = "$i1\t$i2\t$i3";
            $homo_taxons{ $key . "\t60\t$homo_taxon" } = 1;
            $cnt60++;
            $copy60 += $est_copy;
        } elsif ( $percent_identity >= 30 ) {
            my ( $i1, $i2, $i3 ) = split( /\t/, $stats30_href->{$key} );
            if ($i1) {
                $i1++;
            } else {
                $i1 = 1;
            }
            if ($i3) {
                $i3 += $est_copy;
            } else {
                $i3 = $est_copy;
            }
            $stats30_href->{$key} = "$i1\t$i2\t$i3";
            $homo_taxons{ $key . "\t30\t$homo_taxon" } = 1;
            $cnt30++;
            $copy30 += $est_copy;
        }
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $scaf_str =~ /gtt_num_id/i );

    # get homolog taxon count
    print "Getting homolog genome count ...\n";
    for my $k ( keys %homo_taxons ) {
        my ( $domain, $phylum, $perc, $h_taxon ) = split( /\t/, $k );
        my $key = "$domain\t$phylum";
        if ( $perc eq '30' ) {
            if ( $stats30_href->{$key} ) {
                my ( $cnt1, $cnt2, $cnt3 ) = split( /\t/, $stats30_href->{$key} );
                $cnt2++;
                $stats30_href->{$key} = "$cnt1\t$cnt2\t$cnt3";
            }
        } elsif ( $perc eq '60' ) {
            if ( $stats60_href->{$key} ) {
                my ( $cnt1, $cnt2, $cnt3 ) = split( /\t/, $stats60_href->{$key} );
                $cnt2++;
                $stats60_href->{$key} = "$cnt1\t$cnt2\t$cnt3";
            }
        } elsif ( $perc eq '90' ) {
            if ( $stats90_href->{$key} ) {
                my ( $cnt1, $cnt2, $cnt3 ) = split( /\t/, $stats90_href->{$key} );
                $cnt2++;
                $stats90_href->{$key} = "$cnt1\t$cnt2\t$cnt3";
            }
        }
    }

    return ( $cnt30, $cnt60, $cnt90, $copy30, $copy60, $copy90 );
}

sub loadScaffoldStats_db_old {
    my ( $dbh, $scaffold_ref, $percent_identity, $stats_href ) = @_;

    if ( scalar(@$scaffold_ref) == 0 ) {
        return 0;
    }

    my $identityClause = "";
    if ( $percent_identity == 30 ) {
        $identityClause = "and percent_identity >= 30 and percent_identity < 60";
    } elsif ( $percent_identity == 60 ) {
        $identityClause = "and percent_identity >= 60 and percent_identity < 90";
    } else {
        # 90 %cog_counts
        $identityClause = "and percent_identity >= 90 ";
    }

    print "<p>Rerieving scaffold information from database ...<br/>\n";

    my $rclause   = WebUtil::urClause('dt.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('dt.taxon_oid');

    my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffold_ref );
    my $sql = qq{
        select t.domain, t.phylum,
            count(distinct dt.gene_oid ), count(distinct dt.homolog_taxon),
            sum(g.est_copy)
        from dt_phylum_dist_genes dt, gene g, taxon t
        where dt.homolog_taxon = t.taxon_oid
        and dt.gene_oid = g.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.scaffold in ( $scaf_str )
        $identityClause
        $rclause
        $imgClause
        group by t.domain, t.phylum
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my $totalCount   = 0;
    my $totalEstCopy = 0;
    for ( ; ; ) {
        my ( $domain, $phylum,
            $cnt, $cnt_taxon, $est_copies ) = $cur->fetchrow();
        last if !$domain;

        $totalCount   += $cnt;
        $totalEstCopy += $est_copies;
        my $c1 = 0;
        my $c2 = 0;
        my $c3 = 0;
        my $k2 = "$domain\t$phylum";
        if ( $stats_href->{$k2} ) {
            ( $c1, $c2, $c3 ) = split( /\t/, $stats_href->{$k2} );
        }
        $c1 += $cnt;
        $c2 += $cnt_taxon;
        $c3 += $est_copies;
        $stats_href->{$k2} = "$c1\t$c2\t$c3";
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $scaf_str =~ /gtt_num_id/i );

    return ( $totalCount, $totalEstCopy );
}

############################################################################
# loadScaffoldHitStats
############################################################################
sub loadScaffoldHitStats {
    my ( $dbh, $scaffold_ref, $stats_href ) = @_;

    if ( scalar(@$scaffold_ref) == 0 ) {
        return 0;
    }

    my $rclause   = WebUtil::urClause('dt.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('dt.taxon_oid');

    my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffold_ref );
    my $sql = qq{
        select dt.domain, dt.phylum, dt.homolog_taxon
        from dt_phylum_dist_genes dt, scaffold s
        where dt.taxon_oid = s.taxon
        and s.scaffold_oid in ( $scaf_str )
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $domain, $phylum, $homo_taxon ) = $cur->fetchrow();
        last if !$domain;
        my $r = "";
        $r .= "$domain\t";
        $r .= "$phylum\t";
        $r .= "$homo_taxon";
        $stats_href->{$r} = 1;
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $scaf_str =~ /gtt_num_id/i );

}

############################################################################
# loadScaffoldStats_sdb
# scaffold phylo distribution stats (SQLite version)
############################################################################
sub loadScaffoldStats_sdb {
    my (
        $taxon_oid, $data_type, $scaffold_ref, 
        $genes_on_scaffolds_href, $isTaxonInFile, $taxon_href,
        $stats30_href, $stats60_href, $stats90_href, 
        $hitStats_href
      )
      = @_;

    if ( scalar(@$scaffold_ref) == 0 ) {
        return ( 0, 0, 0, 0, 0, 0 );
    }

    my $dbh = dbLogin();
    if ( $isTaxonInFile eq '' ) {
        $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
    }

    # save all genes on scaffold_ref
    my %genes;
    for my $scaffold_oid (@$scaffold_ref) {
        my @genes_on_s = ();
        if ( $genes_on_scaffolds_href ne '' ) {
            my $genes_on_s_ref = $genes_on_scaffolds_href->{$scaffold_oid};
            if ( $genes_on_s_ref ne '' ) {
                @genes_on_s = @$genes_on_s_ref;
            }
        }
        if ( scalar(@genes_on_s) <= 0 ) {
            if ( $isTaxonInFile ) {
                @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );
            } else {
                @genes_on_s = getDbScaffoldGenes( $dbh, $scaffold_oid );
            }
        }

        for my $s2 (@genes_on_s) {
            my ( $gid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id, $source ) =
              split( /\t/, $s2 );
            if ( $genes{$gid} ) {
                # already there
            } else {
                $genes{$gid} = 1;
            }
        }
    }

    print "<p>Rerieving taxon phylogeny ...\n";

    my $cnt30  = 0;
    my $cnt60  = 0;
    my $cnt90  = 0;
    my $copy30 = 0;
    my $copy60 = 0;
    my $copy90 = 0;
    my %homo_taxons;
    $taxon_oid = sanitizeInt($taxon_oid);

    for my $p2 ( 30, 60, 90 ) {
        print "<p>Checking percent identity: $p2 ($taxon_oid)\n";

        my $sdb_name = MetaUtil::getPhyloDistTaxonDir($taxon_oid) . "/" . $data_type . "." . $p2 . ".sdb";
        if ( !( -e $sdb_name ) ) {
            next;
        }

        my $dbh2 = WebUtil::sdbLogin($sdb_name)
          or next;


 my @a = keys %genes;
 my $str = join("','", @a);
 $str = "'" . $str . "'";

        my $sql2 = MetaUtil::getPhyloDistSingleGeneSql();
        $sql2 = qq{
              select gene_oid, perc, homolog, homo_taxon, est_copy 
        from phylo_dist 
        where gene_oid in ($str)
        };
        
        my $sth2 = $dbh2->prepare($sql2);
        
 
webLog("$sql2 \n" );
        #for my $gene_oid ( keys %genes ) {
#webLog("gene id: $gene_oid\n");
print ".";            
 
            #$sth2->execute($gene_oid);
            $sth2->execute();
          for(;;) {
            my ( $gene_oid2, $gene_perc, $homolog_gene, $homo_taxon, $copies ) 
                = $sth2->fetchrow_array();
            #$sth2->finish();
            last if(!$gene_oid2);
            if ( !$taxon_href->{$homo_taxon} ) {
                # no access to taxon
                next;
            }

            my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $tname ) 
                = split( /\t/, $taxon_href->{$homo_taxon} );

            $hitStats_href->{"$domain\t$phylum\t$homo_taxon"} = 1;

            my $key = "$domain\t$phylum";
            if ( $p2 == 30 ) {
                my ( $i1, $i2, $i3 ) = split( /\t/, $stats30_href->{$key} );
                if ($i1) {
                    $i1++;
                } else {
                    $i1 = 1;
                }
                if ($i3) {
                    $i3 += $copies;
                } else {
                    $i3 = $copies;
                }
                $stats30_href->{$key} = "$i1\t$i2\t$i3";
                $homo_taxons{ $key . "\t30\t$homo_taxon" } = 1;
                $cnt30++;
                $copy30 += $copies;
            } elsif ( $p2 == 60 ) {
                my ( $i1, $i2, $i3 ) = split( /\t/, $stats60_href->{$key} );
                if ($i1) {
                    $i1++;
                } else {
                    $i1 = 1;
                }
                if ($i3) {
                    $i3 += $copies;
                } else {
                    $i3 = $copies;
                }
                $stats60_href->{$key} = "$i1\t$i2\t$i3";
                $homo_taxons{ $key . "\t60\t$homo_taxon" } = 1;
                $cnt60++;
                $copy60 += $copies;
            } elsif ( $p2 == 90 ) {
                my ( $i1, $i2, $i3 ) = split( /\t/, $stats90_href->{$key} );
                if ($i1) {
                    $i1++;
                } else {
                    $i1 = 1;
                }
                if ($i3) {
                    $i3 += $copies;
                } else {
                    $i3 = $copies;
                }
                $stats90_href->{$key} = "$i1\t$i2\t$i3";
                $homo_taxons{ $key . "\t90\t$homo_taxon" } = 1;
                $cnt90++;
                $copy90 += $copies;
            }
        }
print "\n";           
        $dbh2->disconnect();
    }    # end for p2


    # get homolog taxon count
    print "<p>Getting homolog genome count ...<br/>\n";
    for my $k ( keys %homo_taxons ) {
        my ( $domain, $phylum, $perc, $h_taxon ) = split( /\t/, $k );
        my $key = "$domain\t$phylum";
        if ( $perc eq '30' ) {
            if ( $stats30_href->{$key} ) {
                my ( $cnt1, $cnt2, $cnt3 ) = split( /\t/, $stats30_href->{$key} );
                $cnt2++;
                $stats30_href->{$key} = "$cnt1\t$cnt2\t$cnt3";
            }
        } elsif ( $perc eq '60' ) {
            if ( $stats60_href->{$key} ) {
                my ( $cnt1, $cnt2, $cnt3 ) = split( /\t/, $stats60_href->{$key} );
                $cnt2++;
                $stats60_href->{$key} = "$cnt1\t$cnt2\t$cnt3";
            }
        } elsif ( $perc eq '90' ) {
            if ( $stats90_href->{$key} ) {
                my ( $cnt1, $cnt2, $cnt3 ) = split( /\t/, $stats90_href->{$key} );
                $cnt2++;
                $stats90_href->{$key} = "$cnt1\t$cnt2\t$cnt3";
            }
        }
    }

    return ( $cnt30, $cnt60, $cnt90, $copy30, $copy60, $copy90 );
}

sub viewScafPhyloDist {
    my ( $isSet, $isSingleScafDetail, $data_type, 
        $scaffolds_href, $orgCount_href, $genomeHitStats_href, 
        $stats30_href, $stats60_href, $stats90_href, 
        $totalGeneCount, $totalCopyCount, 
        $remainCount30, $remainCount60, $remainCount90,
        $remainCopy30, $remainCopy60, $remainCopy90 ) = @_;

    printMainForm();
    print hiddenVar( 'job_name', '' );

    viewScafPhyloDistWithoutMainForm( $isSet, $isSingleScafDetail, $data_type, 
        $scaffolds_href, $orgCount_href, $genomeHitStats_href, 
        $stats30_href, $stats60_href, $stats90_href, 
        $totalGeneCount, $totalCopyCount, 
        $remainCount30, $remainCount60, $remainCount90,
        $remainCopy30, $remainCopy60, $remainCopy90 );
        
    print end_form();    
    printStatusLine( "Loaded.", 2 );

}

sub viewScafPhyloDistWithoutMainForm {
    my ( $isSet, $isSingleScafDetail, $data_type, 
        $scaffolds_href, $orgCount_href, $genomeHitStats_href, 
        $stats30_href, $stats60_href, $stats90_href, 
        $totalGeneCount, $totalCopyCount, 
        $remainCount30, $remainCount60, $remainCount90,
        $remainCopy30, $remainCopy60, $remainCopy90, $job_name ) = @_;

    Workspace::printJS();

    for my $k ( keys %$scaffolds_href ) {
        if ( $scaffolds_href->{$k} == 1 ) {
            print hiddenVar( "db_scaffold", $k );
        } else {
            print hiddenVar( "file_scaffold", $k );
        }
    }

    print hiddenVar( "isSet",            $isSet ) if ($isSet);
    print hiddenVar( "isSingleScafDetail", $isSingleScafDetail ) if ($isSingleScafDetail);
    print hiddenVar( "section",          $section );
    print hiddenVar( "page",             "" );
    print hiddenVar( "domain",           "" );
    print hiddenVar( "phylum",           "" );
    print hiddenVar( "ir_class",         "" );
    print hiddenVar( "ir_order",         "" );
    print hiddenVar( "family",           "" );
    print hiddenVar( "genus",            "" );
    print hiddenVar( "species",          "" );
    print hiddenVar( "percent_identity", "" );         # perc
    print hiddenVar( "perc",             "" );
    print hiddenVar( "percent",          "" );
    print hiddenVar( "data_type", $data_type );

    my $xcopy = param("xcopy");
    print hiddenVar( "xcopy", $xcopy );

    my $inScaffoldMsg = PhyloUtil::getInScaffoldMsg( $isSet, $isSingleScafDetail );
    print "<h1>Phylogenetic Distribution of Genes in $inScaffoldMsg</h1>\n";
    printScafPhyloDistScaffoldLink( $isSet, $isSingleScafDetail, $scaffolds_href, $data_type );
    
    print "<p style='width: 950px;'>\n";
    PhyloUtil::printPhyloDistMessage();
    print "</p>\n";

    use TabHTML;
    TabHTML::printTabAPILinks("phylodistTab", 1);
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("phylodistTab");
        </script>
    }; 

    my @tabIndex;
    my @tabNames; 
    if ( $xcopy eq 'gene_count' || $xcopy eq 'est_copy' ) {
        @tabIndex = ( "#phylodisttab1" );
        my $xcopyText = PhyloUtil::getXcopyText( $xcopy );
        @tabNames = ( $xcopyText );
    }
    else {
        @tabIndex = ( "#phylodisttab1",  "#phylodisttab2" );
        @tabNames = ( PhyloUtil::getXcopyText('gene_count'), PhyloUtil::getXcopyText('est_copy') );        
    }
    TabHTML::printTabDiv("phylodistTab", \@tabIndex, \@tabNames);
    
    if ( $xcopy eq 'gene_count' || $xcopy eq 'est_copy' ) {
        print "<div id='phylodisttab1'>";
        viewScafPhyloDistTable( $isSet, $isSingleScafDetail, $data_type, $xcopy, 
            $scaffolds_href, $orgCount_href, $genomeHitStats_href,
            $stats30_href, $stats60_href, $stats90_href, 
            $totalGeneCount, $totalCopyCount, 
            $remainCount30, $remainCount60, $remainCount90, 
            $remainCopy30, $remainCopy60, $remainCopy90, $job_name );
        print "</div>"; # end of phylodisttab1        

    }
    else {
        print "<div id='phylodisttab1'>";
        viewScafPhyloDistTable( $isSet, $isSingleScafDetail, $data_type, 'gene_count', 
            $scaffolds_href, $orgCount_href, $genomeHitStats_href,
            $stats30_href, $stats60_href, $stats90_href, 
            $totalGeneCount, $totalCopyCount, 
            $remainCount30, $remainCount60, $remainCount90, 
            $remainCopy30, $remainCopy60, $remainCopy90, $job_name );
        print "</div>"; # end of phylodisttab1        
        
        print "<div id='phylodisttab2'>";
        viewScafPhyloDistTable( $isSet, $isSingleScafDetail, $data_type, 'est_copy', 
            $scaffolds_href, $orgCount_href, $genomeHitStats_href,
            $stats30_href, $stats60_href, $stats90_href, 
            $totalGeneCount, $totalCopyCount, 
            $remainCount30, $remainCount60, $remainCount90, 
            $remainCopy30, $remainCopy60, $remainCopy90, $job_name );
        print "</div>"; # end phylodisttab2
    }

    TabHTML::printTabDivEnd();
}

sub printScafPhyloDistScaffoldLink {
    my ( $isSet, $isSingleScafDetail, $scaffolds_href, $data_type ) = @_;

    my $scaffoldsCnt = scalar( keys %$scaffolds_href );
    if ($isSingleScafDetail && $scaffoldsCnt >0) {
        my $scaffold_link;
        my @keys = keys %$scaffolds_href;
        my $scaffold_id = $keys[0];
        my $isMeta;
        if ( $scaffolds_href->{$scaffold_id} == 1 ) {
            my $scaffold_url = "$main_cgi?section=ScaffoldCart"
             . "&page=scaffoldDetail&scaffold_oid=$scaffold_id";
            $scaffold_link = alink( $scaffold_url, $scaffold_id );
        } else {
            my $scaffold_url;
            my ( $toid, $data_type, $scaf_id ) = split( / /, $scaffold_id );
            if ( $data_type eq 'database' ) {
                $scaffold_url = "$main_cgi?section=ScaffoldCart"
                 . "&page=scaffoldDetail&scaffold_oid=$scaf_id";
                 $isMeta = 1;
            }
            else {
                $scaffold_url = "$main_cgi?section=MetaDetail"
                  . "&page=metaScaffoldDetail&scaffold_oid=$scaf_id"
                  . "&taxon_oid=$toid&data_type=$data_type";                
            }
            $scaffold_link = alink( $scaffold_url, $scaf_id );
        }
        print "<p style='width: 950px;'>\n";
        print "Scaffold: " . $scaffold_link . "<br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 ) if ( $isMeta );
        print "</p>\n";
    } else {
        if ($isSet) {
            print "<p style='width: 950px;'>\n";
            print "$scaffoldsCnt Scaffolds in Selected Scaffold Sets<br/>\n";
            HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
            print "</p>\n";
        } else {
            print "<p style='width: 950px;'>\n";
            print "$scaffoldsCnt Selected Scaffolds<br/>\n";
            HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
            print "</p>\n";
        }
    }

}

sub processScafPhyloDistScaffoldLink {
    my ( $isSet, $isSingleScafDetail, $db_scaffolds_ref, $file_scaffolds_ref, $data_type ) = @_;

    my %scaffold_h;
    for my $scaf_id ( @$db_scaffolds_ref ) {
        $scaffold_h{$scaf_id} = 1;
    }
    for my $scaf_id ( @$file_scaffolds_ref ) {
        $scaffold_h{$scaf_id} = 2;
    }
    printScafPhyloDistScaffoldLink( $isSet, $isSingleScafDetail, \%scaffold_h, $data_type ); 
    
}


sub viewScafPhyloDistTable {
    my ( $isSet, $isSingleScafDetail, $data_type, $xcopy, 
        $scaffolds_href, $orgCount_href, $genomeHitStats_href,
        $stats30_href, $stats60_href, $stats90_href, 
        $totalGeneCount, $totalCopyCount, 
        $remainCount30, $remainCount60, $remainCount90,
        $remainCopy30, $remainCopy60, $remainCopy90, $job_name ) = @_;

    my $xcopyText = PhyloUtil::getXcopyText( $xcopy );
    print "<h2>Distribution of Best Blast Hits ($xcopyText)</h2>";

    print "<p>\n";
    print domainLetterNote();
    print "</p>\n";

    my $str = PhyloUtil::getPhyloDistHintText( 1, 1, $xcopyText, $totalGeneCount );
    printHint($str);
    print "<br/>";

    my $total_count = $totalGeneCount;
    if ( $xcopy eq 'est_copy' ) {
        $total_count = $totalCopyCount;
    }

    my @pcId = ( 30, 60, 90 );
    my %toolTip = (
        "30%"  => "30% to 59%",
        "60%"  => "60% to 89%",
        "90%"  => "90% and above",
    );

    # Define a new static table
    my $sit = new StaticInnerTable();
    $sit->addColSpec("D"); # Domain
    $sit->addColSpec("Phylum");
    $sit->addColSpec("No. Of Genomes", "", "right");
    for my $pc ( @pcId ) {
        $sit->addColSpec("No. Of Hits ${pc}%", "", "right", "", $toolTip{"${pc}%"});
        $sit->addColSpec("Histogram ${pc}%");
    }

    my @domainPhylum = sort( keys(%$stats30_href) );
    foreach my $k ( keys %$stats90_href ) {
        if ( !exists( $stats60_href->{$k} ) ) {
            webLog("WARNING: 90% $k does not exist in 60% list\n");
            $stats60_href->{$k} = "";
            if ( !exists( $stats30_href->{$k} ) ) {
                push @domainPhylum, ($k);
            }
        }
        if ( !exists( $stats30_href->{$k} ) ) {
            webLog("WARNING: 90% $k does not exist in 30% list\n");
            $stats30_href->{$k} = "";
            push @domainPhylum, ($k);
        }
    }
    foreach my $k ( keys %$stats60_href ) {
        if ( !exists( $stats30_href->{$k} ) ) {
            webLog("WARNING: 60% $k does not exist in 30% list\n");
            $stats30_href->{$k} = "";
            push @domainPhylum, ($k);
        }
    }

    my $sectionToUse = getSectionToUse( $isSet, $isSingleScafDetail );

    for my $dpc (@domainPhylum) {
        my $orgcnt = $orgCount_href->{$dpc};

        my ( $domain, $phylum ) = split( /\t/, $dpc );
        if ( !$orgcnt && $domain =~ /Virus/ ) {
            my $phylum2 = $phylum;
            $phylum2 =~ s/\_no/\, no/;
            $phylum2 =~ s/\_/ /g;
            my $dpc2 = "$domain\t$phylum2";
            $orgcnt = $orgCount_href->{$dpc2};
        }

        my $r = $stats30_href->{$dpc};
        my ( $noHits30, $genomCnt30, $copy30 ) = split( /\t/, $r );

        my $rec60 = $stats60_href->{$dpc};
        my ( $noHits60, $genomCnt60, $copy60 ) = split( /\t/, $rec60 );

        my $rec90 = $stats90_href->{$dpc};
        my ( $noHits90, $genomCnt90, $copy90 ) = split( /\t/, $rec90 );

        if ( $xcopy eq 'est_copy' ) {
            $noHits30 = $copy30;
            $noHits60 = $copy60;
            $noHits90 = $copy90;
        }

        # total number if distinct genomes hits 30, 60 90
        my $genomCntHit = $genomeHitStats_href->{$dpc};

        my $row;

        ## domain
        $row .= substr( $domain, 0, 1 ) . "\t";

        ## phylum 
        my $phylumDisplay = $phylum;
        if ( $domain =~ /Virus/ ) {
            $phylumDisplay =~ s/\_no/, no/;
            $phylumDisplay =~ s/\_/ /g;
        }
        $phylumDisplay = escHtml($phylumDisplay);
        
        # make url for family page
        my $familyUrl = "javascript:mySubmit1('$sectionToUse', 'ir_class', '$domain', '$phylum', '', '', '', '', '', '', '$xcopy', '$job_name', '$data_type')";
        $row .= qq{
            <a href="$familyUrl" >$phylumDisplay</a>
        };
        $row .= "\t";

        ## no of genomes
        $row .= "$orgcnt ($genomCntHit)\t";

        # hits columns
        my $i = 0;
        for my $pc ( @pcId ) {
            my $cnt;
            my $genomCnt;
            if ( $pc == 30  ) {
                $cnt = $noHits30;
                $genomCnt = $genomCnt30;
            }
            elsif ( $pc == 60  ) {
                $cnt = $noHits60;
                $genomCnt = $genomCnt60;
            }
            elsif ( $pc == 90  ) {
                $cnt = $noHits90;
                $genomCnt = $genomCnt90;
            }

            if ($cnt) {
                my $noHitsUrl =
                  "javascript:mySubmit1('$sectionToUse', 'taxonomyMetagHits', '$domain', '$phylum', '', '', '', '', '', '$pc', '$xcopy', '$job_name', '$data_type')";
                $row .= qq{
                    <a href="$noHitsUrl">$cnt</a> ($genomCnt)
                };
            }
            else {
                $row .= nbsp(1);
            }
            $row .= "\t";
                    
            if ($total_count) {
                my $maxLen = (scalar(@pcId) - $i) * 100;
                $row .= histogramBar( $cnt / $total_count, $maxLen );
            }
            else {
                $row .= "-";
            }
            $row .= "\t";

            $i++;
        }
        $sit->addRow($row);
    }

    my $remainCnt30;
    my $remainCnt60;
    my $remainCnt90;
    if ( $xcopy eq 'est_copy' ) {
        $remainCnt30 = $remainCopy30;
        $remainCnt60 = $remainCopy60;
        $remainCnt90 = $remainCopy90;            
    }
    else {
        $remainCnt30 = $remainCount30;
        $remainCnt60 = $remainCount60;
        $remainCnt90 = $remainCount90;            
    }

    if ( $remainCnt30 || $remainCnt60 || $remainCnt90 ) {
        # unassigned data
        my $row .= "-\t";
        $row .= "Unassigned\t";
        $row .= "-\t";
        
        my $i = 0;
        for my $pc (@pcId) { # (30, 60, 90)    
            my $remainCnt;
            if ( $pc == 30  ) {
                $remainCnt = $remainCnt30;
            }
            elsif ( $pc == 60  ) {
                $remainCnt = $remainCnt60;
            }
            elsif ( $pc == 90  ) {
                $remainCnt = $remainCnt90;
            }

            if ($remainCnt) {
                $row .= "$remainCnt";
            }
            else {
                $row .= nbsp(1);
            }
            $row .= "\t";

            if ($total_count) {
                my $maxLen = (scalar(@pcId) - $i) * 100;
                $row .= histogramBar( $remainCnt / $total_count, $maxLen );
            }
            else {
                $row .= "-";
            }
            $row .= "\t";

            $i++;
        }
        $sit->addRow($row);        
    }

    $sit->printTable();
}

sub getSectionToUse {
    my ( $isSet, $isSingleScafDetail ) = @_;

    my $sectionToUse;
    if ($isSingleScafDetail) {
        $sectionToUse = 'ScaffoldCart';
    } else {
        if ($isSet) {
            $sectionToUse = $section;
        } else {
            $sectionToUse = 'ScaffoldCart';
        }
    }
    
    return $sectionToUse;
}

############################################################################
# printScafTaxonomyPhyloDist
# print scaffold sets phylo distribution
############################################################################
sub printScafTaxonomyPhyloDist {
    my ($taxonomy) = @_;
    
    my $taxonomy_uc = ucfirst($taxonomy);
    if ( $taxonomy eq 'ir_class' ) {
        $taxonomy_uc = 'Class';
    }
    elsif ( $taxonomy eq 'ir_order' ) {
        $taxonomy_uc = 'Order';
    }
    
    my $sid = getContactOid();
    if ( blankStr($sid) ) {
        webError("Your login has expired.");
        return;
    }

    my $isSet    = param("isSet");
    my $isSingleScafDetail = param("isSingleScafDetail");
    my @db_scaffolds   = param("db_scaffold");
    my @file_scaffolds = param("file_scaffold");

    if ( scalar(@db_scaffolds) == 0 && scalar(@file_scaffolds) == 0 ) {
        webError("Select at least one scaffold set for phylogenetic distribution.");
        return;
    }

    my $domain   = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family   = param("family");
    my $genus    = param("genus");
    my $xcopy    = param("xcopy");
    my $data_type = param('data_type');

    printStatusLine( "Loading ...", 1 );

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    my ($distinctTaxonomy_href, $stats30_href, $stats60_href, $stats90_href, $count30, $count60, $count90)
        = processScafTaxonomyPhyloDist( \@db_scaffolds, \@file_scaffolds, $xcopy, $data_type,
            $taxonomy, $domain, $phylum, $ir_class, $ir_order, $family, $genus );

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    printMainForm();
    Workspace::printJS();

    my $job_name = param('job_name');
    if ( $job_name ) {
        WebUtil::checkFileName($job_name);
        # this also untaints the name
        $job_name = WebUtil::validFileName($job_name);
        print "<h1>Computation Job: $job_name</h1>\n";
    }
    print hiddenVar( 'job_name', $job_name );        

    print hiddenVar( "isSet",            $isSet ) if ($isSet);
    print hiddenVar( "isSingleScafDetail", $isSingleScafDetail ) if ($isSingleScafDetail);
    print hiddenVar( "section",          $section );
    print hiddenVar( "page",             "" );
    print hiddenVar( "domain",           "" );
    print hiddenVar( "phylum",           "" );
    print hiddenVar( "ir_class",         "" );
    print hiddenVar( "ir_order",         "" );
    print hiddenVar( "family",           "" );
    print hiddenVar( "genus",            "" );
    print hiddenVar( "species",          "" );
    print hiddenVar( "percent_identity", "" );         # perc
    print hiddenVar( "perc",             "" );
    print hiddenVar( "percent",          "" );
    print hiddenVar( "xcopy",            $xcopy );
    print hiddenVar( "data_type",        $data_type );

    for my $f1 (@db_scaffolds) {
        print hiddenVar( "db_scaffold", $f1 );
    }
    for my $f2 (@file_scaffolds) {
        print hiddenVar( "file_scaffold", $f2 );
    }

    my $inScaffoldMsg = PhyloUtil::getInScaffoldMsg( $isSet, $isSingleScafDetail );
    my $xcopyText = PhyloUtil::getXcopyText( $xcopy );
    print "<h1>$taxonomy_uc Statistics in $inScaffoldMsg ($xcopyText)</h1>\n";
    if ( $domain =~ /Virus/ ) {
        my $phylum2 = $phylum;
        $phylum2 =~ s/\_no/\, no/;
        $phylum2 =~ s/\_/ /g;
        PhyloUtil::printPhyloTitle( $domain, $phylum2, $ir_class, $ir_order, $family, $genus );
    } else {
        PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family, $genus );
    }
    processScafPhyloDistScaffoldLink( $isSet, $isSingleScafDetail, \@db_scaffolds, \@file_scaffolds, $data_type );

    my @pc = ( 30, 60, 90 );
    my %toolTip = (
        "30%"  => "30% to 59%",
        "60%"  => "60% to 89%",
        "90%"  => "90% and above",
    );
    
    # Define a new static table
    my $sit = new StaticInnerTable();
    $sit->addColSpec($taxonomy_uc);
    for my $pc ( @pc ) {
        $sit->addColSpec("No. Of Hits ${pc}%", "", "right", "", $toolTip{"${pc}%"});
        $sit->addColSpec("Histogram ${pc}%");
    }

    my $sectionToUse = getSectionToUse( $isSet, $isSingleScafDetail );
    
    foreach my $key ( sort keys %$distinctTaxonomy_href ) {
        #print "printScafTaxonomyPhyloDist() key=$key<br/>\n";

        my $row;
        if ( $taxonomy eq 'species' ) {     
            $row .= "$key";
        }
        else {
            my $url;
            if ( $taxonomy eq 'ir_class' ) {
                $url =
                  "javascript:mySubmit1('$sectionToUse', 'ir_order', '$domain', '$phylum', '$key', '', '', '', '', '', '$xcopy', '$job_name', '$data_type')";
            }
            elsif ( $taxonomy eq 'ir_order' ) {
                $url =
                  "javascript:mySubmit1('$sectionToUse', 'family', '$domain', '$phylum', '$ir_class', '$key', '', '', '', '', '$xcopy', '$job_name', '$data_type')";
            }
            elsif ( $taxonomy eq 'family' ) {
                $url =
                  "javascript:mySubmit1('$sectionToUse', 'genus', '$domain', '$phylum', '$ir_class', '$ir_order', '$key', '', '', '', '$xcopy', '$job_name', '$data_type')";
            }
            elsif ( $taxonomy eq 'genus' ) {
                $url =
                  "javascript:mySubmit1('$sectionToUse', 'species', '$domain', '$phylum', '$ir_class', '$ir_order', '$family', '$key', '', '', '$xcopy', '$job_name', '$data_type')";
            }
            
            $row .= qq{
                <a href="$url">$key</a>
            };            
        }
        $row .= "\t";

        # hits columns
        my $i = 0;
        for my $pc ( @pc ) {
            my $aref_pc;
            my $count_pc;
            if ( $pc == 30  ) {
                $aref_pc = $stats30_href->{$key};
                $count_pc = $count30;
            }
            elsif ( $pc == 60  ) {
                $aref_pc = $stats60_href->{$key};
                $count_pc = $count60;                
            }
            elsif ( $pc == 90  ) {
                $aref_pc = $stats90_href->{$key};                
                $count_pc = $count90;
            }

            if ( defined($aref_pc) ) {
                my $cnt = 0;
                if ( $xcopy eq 'est_copy' ) {
                    $cnt = 0;
                    for my $a1 (@$aref_pc) {
                        my @v = split( /\t/, $a1 );
                        $cnt += $v[-1];
                        #print "printScafTaxonomyPhyloDist() a1=$a1, cnt=$cnt<br/>\n";
                    }
                }
                else {
                    $cnt = $#$aref_pc + 1;                    
                }
    
                if ($cnt) {
                    my $tmpurl;
                    if ( $taxonomy eq 'ir_class' ) {
                        $tmpurl =
        "javascript:mySubmit1('$sectionToUse', 'taxonomyMetagHits', '$domain', '$phylum', '$key', '', '', '', '', '$pc', '$xcopy', '$job_name', '$data_type')";
                    }
                    elsif ( $taxonomy eq 'ir_order' ) {
                        $tmpurl =
        "javascript:mySubmit1('$sectionToUse', 'taxonomyMetagHits', '$domain', '$phylum', '$ir_class', '$key', '', '', '', '$pc', '$xcopy', '$job_name', '$data_type')";
                    }
                    elsif ( $taxonomy eq 'family' ) {
                        $tmpurl =
        "javascript:mySubmit1('$sectionToUse', 'taxonomyMetagHits', '$domain', '$phylum', '$ir_class', '$ir_order', '$key', '', '', '$pc', '$xcopy', '$job_name', '$data_type')";
                    }
                    elsif ( $taxonomy eq 'genus' ) {
                        $tmpurl =
            "javascript:mySubmit1('$sectionToUse', 'taxonomyMetagHits', '$domain', '$phylum', '$ir_class', '$ir_order', '$family', '$key', '', '$pc', '$xcopy', '$job_name', '$data_type')";
                    }
                    elsif ( $taxonomy eq 'species' ) {
                        $tmpurl =
            "javascript:mySubmit1('$sectionToUse', 'taxonomyMetagHits', '$domain', '$phylum', '$ir_class', '$ir_order', '$family', '$genus', '$key', '$pc', '$xcopy', '$job_name', '$data_type')";
                    }
                    
                    $row .= qq{
                        <a href="$tmpurl">$cnt</a>
                    };
                }
                else {
                    $row .= nbsp(1);
                }
                $row .= "\t";
    
    
                if ($count_pc) {
                    my $maxLen = (scalar(@pc) - $i) * 100;
                    $row .= histogramBar( $cnt / $count_pc, $maxLen );
                } else {
                    $row .= "-";
                }
                $row .= "\t";
                
            } else {
                $row .= "-\t";
                $row .= nbsp(1) . "\t";
            }
            $i++;
        }
        
        $sit->addRow($row);
    }
    $sit->printTable();
    
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

sub processScafTaxonomyPhyloDist {
    my ( $db_scaffolds_ref, $file_scaffolds_ref, $xcopy, $data_type,
        $taxonomy, $domain, $phylum, $ir_class, $ir_order, $family, $genus ) = @_;


    printStartWorkingDiv();

    print "<p>\n";

    my $dbh = dbLogin();

    my %distinctTaxonomy;
    my %stats30;
    my %stats60;
    my %stats90;
    my $count30 = 0;
    my $count60 = 0;
    my $count90 = 0;

    # db scaffolds
    if ( scalar(@$db_scaffolds_ref) > 0 ) {
        print "Querying database ...<br/>\n";
        
        my $taxonomyClause;
        my @binds;
        
        if ( $domain ) {
            $taxonomyClause .= " and t.domain = ? ";            
            push( @binds, $domain );
        }
        
        if ( $phylum ) {
            $taxonomyClause .= " and t.phylum = ? ";            
            push( @binds, $phylum );
        }
        
        if ( $ir_class ) {
            $taxonomyClause .= " and t.ir_class = ? ";
            push( @binds, $ir_class );
        }
        elsif ( !defined($ir_class) || $ir_class eq "" ) {
            if ( $taxonomy eq 'ir_order' 
                || $taxonomy eq 'family' 
                || $taxonomy eq 'genus' 
                || $taxonomy eq 'species' ) {
                $taxonomyClause .= " and t.ir_class is null ";                
            }
        }
        if ( $ir_order ) {
            $taxonomyClause .= " and t.ir_order = ? ";
            push( @binds, $ir_order );
        }
        elsif ( !defined($ir_order) || $ir_order eq "" ) {
            if ( $taxonomy eq 'family' 
                || $taxonomy eq 'genus' 
                || $taxonomy eq 'species' ) {
                $taxonomyClause .= " and t.ir_order is null ";                
            }
        }
        if ( $family ) {
            $taxonomyClause .= " and t.family = ? ";
            push( @binds, $family );
        }
        elsif ( !defined($family) || $family eq "" ) {
            if ( $taxonomy eq 'genus' 
                || $taxonomy eq 'species' ) {
                $taxonomyClause .= " and t.family is null ";                
            }
        }
        if ( $genus ) {
            $taxonomyClause .= " and t.genus = ? ";
            push( @binds, $genus );
        }
        elsif ( !defined($genus) || $genus eq "" ) {
            if ( $taxonomy eq 'species') {
                $taxonomyClause .= " and t.genus is null ";                
            }
        } 

        my $rclause   = WebUtil::urClause('dt.taxon_oid');
        my $imgClause = WebUtil::imgClauseNoTaxon('dt.taxon_oid');

        my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_scaffolds_ref );
        my $sql = qq{
            select distinct dt.gene_oid, dt.taxon_oid, dt.percent_identity, 
            $nvl(t.$taxonomy, '$unknown'), g.est_copy
            from dt_phylum_dist_genes dt, taxon t, gene g
            where dt.homolog_taxon = t.taxon_oid 
            and dt.gene_oid = g.gene_oid
            and g.locus_type = 'CDS'
            and g.obsolete_flag = 'No'
            and g.scaffold in ( $scaf_str )
            $taxonomyClause 
            $rclause
            $imgClause
        };
        #print "processScafTaxonomyPhyloDist() sql=$sql<br/>\n";
        #print "processScafTaxonomyPhyloDist() binds=@binds<br/>\n";

        my $cur = execSql( $dbh, $sql, $verbose, @binds );

        for ( ; ; ) {
            my ( $gene_oid, $taxon, $percent, $sublevel, $gene_copy ) = $cur->fetchrow();
            last if !$gene_oid;

            my $cnt0 = 1;
            if ( $xcopy eq 'est_copy' && $gene_copy ) {
                $cnt0 = $gene_copy;
            }

            my $key   = "$sublevel";
            my $value = "$taxon\t$gene_oid\t$percent\t$cnt0";

            if ( !exists( $distinctTaxonomy{$key} ) ) {
                $distinctTaxonomy{$key} = "";
            }

            if ( $percent >= 90 ) {
                $count90 += $cnt0;
                if ( exists( $stats90{$key} ) ) {
                    my $aref = $stats90{$key};
                    push( @$aref, $value );
                } else {
                    my @a = ("$value");
                    $stats90{$key} = \@a;
                }
            } elsif ( $percent >= 60 ) {
                $count60 += $cnt0;
                if ( exists( $stats60{$key} ) ) {
                    my $aref = $stats60{$key};
                    push( @$aref, $value );
                } else {
                    my @a = ("$value");
                    $stats60{$key} = \@a;
                }
            } elsif ( $percent >= 30 ) {
                $count30 += $cnt0;
                if ( exists( $stats30{$key} ) ) {
                    my $aref = $stats30{$key};
                    push( @$aref, $value );
                } else {
                    my @a = ("$value");
                    $stats30{$key} = \@a;
                }
            }
        }    # end for
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $scaf_str =~ /gtt_num_id/i );
          
    }    # end for scaffold_oid


    # file scaffolds
    if ( scalar(@$file_scaffolds_ref) > 0 ) {
        print "Querying file ...<br/>\n";
        
        # get all genes on selected scaffolds
        my %taxon_genes;
        print "Checking genes on scaffolds ...<br/>\n";
        my $cnt2 = 0;
        for my $s2 (@$file_scaffolds_ref) {
            $cnt2++;
            if ( ( $cnt2 % 10 ) == 0 ) {
                print ".";
            }
            if ( ( $cnt2 % 1800 ) == 0 ) {
                print "<br/>";
            }

            my ( $taxon_oid, $d2, $scaffold_oid ) = split( / /, $s2 );
            my @genes_on_s = ();
            if ( $d2 eq 'database' ) {
                @genes_on_s = getDbScaffoldGenes( $dbh, $scaffold_oid );
            } else {
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
                    && ($d2 ne $data_type) ) {
                        next;
                }
                @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $d2, $scaffold_oid );
            }

            my $str = "";
            for my $g2 (@genes_on_s) {
                my ( $gid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id, $source ) =
                  split( /\t/, $g2 );
                if ($str) {
                    $str .= "," . $gid;
                } else {
                    $str = $gid;
                }
            }

            if ( $taxon_genes{$taxon_oid} ) {
                $taxon_genes{$taxon_oid} .= "," . $str;
            } else {
                $taxon_genes{$taxon_oid} = $str;
            }
        }

        print "Rerieving taxon phylogeny ...<br/>\n";
        my $taxon_href = PhyloUtil::getTaxonTaxonomy( $dbh, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus );

        my %scaf_files;
        for my $s2 (@$file_scaffolds_ref) {
            my ( $taxon_oid, $d2, $scaffold_oid ) = split( / /, $s2 );
            $taxon_oid = sanitizeInt($taxon_oid);
            
            if ( $scaf_files{$taxon_oid} ) {
                # same file
                next;
            } else {
                my %gene_h;
                my @gs = split( /\,/, $taxon_genes{$taxon_oid} );
                for my $g3 (@gs) {
                    $gene_h{$g3} = 1;
                }

                # percent
                for my $p2 ( 30, 60, 90 ) {
                    print "Percent identity $p2<br/>\n";
                    my $sdb_name =
                      MetaUtil::getPhyloDistTaxonDir($taxon_oid) . "/" . "assembled" . "." . $p2 . ".sdb";
                    if ( -e $sdb_name ) {
                        my $dbh2 = WebUtil::sdbLogin($sdb_name)
                          or next;

                        my $sql2 = MetaUtil::getPhyloDistSingleGeneSql();
                        my $sth2 = $dbh2->prepare($sql2);

                        for my $gene_oid ( keys %gene_h ) {
                            $sth2->execute($gene_oid);
                            my ( $gene_oid2, $gene_perc, $homolog_gene, $homo_taxon, $copies ) 
                                = $sth2->fetchrow_array();
                            $sth2->finish();

                            my $cnt0 = 1;
                            if ( $xcopy eq 'est_copy' && $copies ) {
                                $cnt0 = $copies;
                            }

                            if ( !$taxon_href->{$homo_taxon} ) {
                                # no access to genome
                                next;
                            }

                            my ( $domain2, $phylum2, $ir_class2, $ir_order2, $family2, $genus2, $species2, $tname ) =
                              split( /\t/, $taxon_href->{$homo_taxon} );

                            my $key;
                            if ( $taxonomy eq 'ir_class' ) {
                                if ( $domain2 ne $domain 
                                    || $phylum2 ne $phylum ) {
                                    next;
                                }
                                $key = "$ir_class2";
                            }
                            elsif ( $taxonomy eq 'ir_order' ) {
                                if ( $domain2 ne $domain 
                                    || $phylum2 ne $phylum 
                                    || $ir_class2 ne $ir_class ) {
                                    next;
                                }
                                $key = "$ir_order2";
                            }
                            elsif ( $taxonomy eq 'family' ) {
                                if ( $domain2 ne $domain 
                                    || $phylum2 ne $phylum 
                                    || $ir_class2 ne $ir_class 
                                    || $ir_order2 ne $ir_order ) {
                                    next;
                                }
                                $key = "$family2";
                            }
                            elsif ( $taxonomy eq 'genus' ) {
                                if ( $domain2 ne $domain 
                                    || $phylum2 ne $phylum 
                                    || $ir_class2 ne $ir_class 
                                    || $ir_order2 ne $ir_order
                                    || $family2 ne $family ) {
                                    next;
                                }
                                $key = "$genus2";
                            }
                            elsif ( $taxonomy eq 'species' ) {
                                if ( $domain2 ne $domain 
                                    || $phylum2 ne $phylum 
                                    || $ir_class2 ne $ir_class 
                                    || $ir_order2 ne $ir_order
                                    || $family2 ne $family
                                    || $genus2 ne $genus ) {
                                    next;
                                }
                                $key = "$species2";
                            }
                            my $value = "$taxon_oid\t$gene_oid2\t$gene_perc\t$cnt0";

                            if ( !exists( $distinctTaxonomy{$key} ) ) {
                                $distinctTaxonomy{$key} = "";
                            }

                            if ( $p2 == 30 ) {
                                $count30 += $cnt0;
                                if ( exists( $stats30{$key} ) ) {
                                    my $aref = $stats30{$key};
                                    push @$aref, ("$value");
                                } else {
                                    my @a = ("$value");
                                    $stats30{$key} = \@a;
                                }
                            } elsif ( $p2 == 60 ) {
                                $count60 += $cnt0;
                                if ( exists( $stats60{$key} ) ) {
                                    my $aref = $stats60{$key};
                                    push( @$aref, $value );
                                } else {
                                    my @a = ("$value");
                                    $stats60{$key} = \@a;
                                }
                            } elsif ( $p2 == 90 ) {
                                $count90 += $cnt0;
                                if ( exists( $stats90{$key} ) ) {
                                    my $aref = $stats90{$key};
                                    push( @$aref, $value );
                                } else {
                                    my @a = ("$value");
                                    $stats90{$key} = \@a;
                                }
                            }
                        }
                        $dbh2->disconnect();
                        $scaf_files{$taxon_oid} = 1;
                    }                
                }

                $scaf_files{$taxon_oid} = 1;
            }
        }
    }
    
    printEndWorkingDiv();

    return (\%distinctTaxonomy, \%stats30, \%stats60, \%stats90, $count30, $count60, $count90);
}

############################################################################
# printScafTaxonomyMetagHits
# print genes in scaffold sets phylo distribution
############################################################################
sub printScafTaxonomyMetagHits {

    my $sid = getContactOid();
    if ( blankStr($sid) ) {
        webError("Your login has expired.");
        return;
    }

    my $isSet    = param("isSet");
    my $isSingleScafDetail = param("isSingleScafDetail");    
    my @db_scaffolds = param("db_scaffold");
    #print "printScafTaxonomyMetagHits() db_scaffolds: @db_scaffolds<br/>\n";
    my @file_scaffolds = param("file_scaffold");
    #print "printScafTaxonomyMetagHits() file_scaffolds: @file_scaffolds<br/>\n";

    if ( scalar(@db_scaffolds) == 0 && scalar(@file_scaffolds) == 0 ) {
        webError("Select at least one scaffold set for phylogenetic distribution.");
        return;
    }

    printStatusLine( "Loading ...", 1 );

    printMainForm();
    Workspace::printJS();

    my $job_name = param('job_name');
    if ( $job_name ) {
        WebUtil::checkFileName($job_name);
        # this also untaints the name
        $job_name = WebUtil::validFileName($job_name);
        print "<h1>Computation Job: $job_name</h1>\n";
        print hiddenVar( 'job_name', $job_name );        
    }

    my $domain   = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family   = param("family");
    my $genus    = param("genus");
    my $species  = param("species");

    my $percent  = param("percent");
    $percent = param("percent_identity") if ( $percent eq "" );
    my $plus     = param("plus");

    my $data_type = param('data_type');
    
    print hiddenVar( "isSet",            $isSet ) if ($isSet);
    print hiddenVar( "isSingleScafDetail", $isSingleScafDetail ) if ($isSingleScafDetail);
    print hiddenVar( "section",          "" );
    print hiddenVar( "page",             "" );
    print hiddenVar( "domain",           "" );
    print hiddenVar( "phylum",           "" );
    print hiddenVar( "ir_class",         "" );
    print hiddenVar( "family",           "" );
    print hiddenVar( "genus",            "" );
    print hiddenVar( "species",          "" );
    print hiddenVar( "percent_identity", "" );    # perc
    print hiddenVar( "perc",             "" );
    print hiddenVar( "percent",          "" );
    print hiddenVar( "data_type",        $data_type ) if ($data_type);

    print "<h1>\n";
    if ($plus) {
        print "Best Hits at $percent\+% Identity\n";
    } else {
        print "Best Hits at $percent% Identity\n";
    }
    print "</h1>\n";
    PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    processScafPhyloDistScaffoldLink( $isSet, $isSingleScafDetail, \@db_scaffolds, \@file_scaffolds, $data_type );
    
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    print "<p>\n";

    my $select_id_name = "gene_oid";

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    my $trunc = 0;
    my $count = 0;

    my $it = new InnerTable( 1, "MetagFamilyHits$$", "MetagFamilyHits", 1 );
    my $sd = $it->getSdDelim();                                                # sort delimiter

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",         "char asc",    "left" );
    $it->addColSpec( "Name",            "char asc",    "left" );
    $it->addColSpec( "Percent",         "number desc", "right" );
    $it->addColSpec( "Homolog Gene",    "number desc", "right" );
    $it->addColSpec( "Homolog Genome",  "char desc",   "left" );
    $it->addColSpec( "Homolog Class",   "char asc",    "left" );
    $it->addColSpec( "Homolog Order",   "char asc",    "left" );
    $it->addColSpec( "Homolog Family",  "char asc",    "left" );
    $it->addColSpec( "Homolog Genus",   "char asc",    "left" );
    $it->addColSpec( "Homolog Species", "char asc",    "left" );
    $it->addColSpec( "Estimated Copies", "number desc", "right" );

    my $dbh = dbLogin();

    # db scaffolds
    if ( scalar(@db_scaffolds) > 0 ) {
        print "Querying database ...<br/>\n";

        my $pclause = PhyloUtil::getPercentClause( $percent, $plus );

        my $taxonomyClause;
        my @binds;
        
        if ( $domain ) {
            $taxonomyClause .= " and t.domain = ? ";            
            push( @binds, $domain );
        }
        
        if ( $phylum ) {
            $taxonomyClause .= " and t.phylum = ? ";            
            push( @binds, $phylum );
        }
        
        if ( $ir_class ) {
            if ( $ir_class eq $unknown ) {
                $taxonomyClause .= " and t.ir_class is null ";
            } elsif ( $family eq "*" ) {
                $taxonomyClause .= "";
            } else {
                $taxonomyClause .= " and t.ir_class = ? ";
                push( @binds, $ir_class );
            }
        }
    
        if ( $ir_order ) {
            if ( $ir_order eq $unknown ) {
                $taxonomyClause .= " and t.ir_order is null ";
            } elsif ( $family eq "*" ) {
                $taxonomyClause .= "";
            } else {
                $taxonomyClause .= " and t.ir_order = ? ";
                push( @binds, $ir_order );
            }
        }

        if ( $family ) {
            if ( $family eq $unknown ) {
                $taxonomyClause .= " and t.family is null ";
            } elsif ( $family eq "*" ) {
                $taxonomyClause .= "";
            } else {
                $taxonomyClause .= " and t.family = ? ";
                push( @binds, $family );
            }
        }
    
        if ( $genus ) {
            if ( $genus eq $unknown ) {
                $taxonomyClause .= " and t.genus is null ";
            } elsif ( $genus eq "*" ) {
                $taxonomyClause .= "";
            } else {
                $taxonomyClause .= " and t.genus = ? ";
                push( @binds, $genus );
            }
        }
    
        if ( $species ) {
            if ( $species eq $unknown ) {
                $taxonomyClause .= " and t.species is null ";
            } elsif ( $species eq "*" ) {
                $taxonomyClause .= "";
            } else {
                $taxonomyClause .= " and t.species = ? ";
                push( @binds, $species );
            }
        }

        my $rclause   = WebUtil::urClause('dt.taxon_oid');
        my $imgClause = WebUtil::imgClauseNoTaxon('dt.taxon_oid');

        my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @db_scaffolds );
        my $sql = qq{ 
            select g.gene_oid, g.gene_display_name, g.est_copy,
                dt.taxon_oid, dt2.taxon_display_name, dt.percent_identity, 
                dt.homolog, dt.homolog_taxon, t.taxon_display_name, 
                $nvl(t.ir_class, '$unknown'), 
                $nvl(t.ir_order, '$unknown'), 
                $nvl(t.family, '$unknown'), 
                $nvl(t.genus, '$unknown'), 
                $nvl(t.species, '$unknown') 
            from dt_phylum_dist_genes dt, gene g, taxon t, taxon dt2
            where dt.taxon_oid = dt2.taxon_oid 
            and dt.homolog_taxon = t.taxon_oid 
            and dt.gene_oid = g.gene_oid
            and g.scaffold in ( $scaf_str )
            $pclause
            $taxonomyClause
            $rclause
            $imgClause
        };
        #print "printScafTaxonomyMetagHits() SQL: $sql<br/>\n";
        #print "printScafTaxonomyMetagHits() binds: @binds<br/>\n";

        my $cur = execSql( $dbh, $sql, $verbose, @binds );
        for ( ; ; ) {
            my ( $gene_oid, $gene_name, $copies, $taxon, $taxon_name, $perc_identity, 
                $homolog_gene, $homo_taxon, $homo_taxon_name, 
                $ir_class2, $ir_order2, $family2, $genus2, $species2 ) 
                = $cur->fetchrow();
            last if !$gene_oid;

            my $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$gene_oid' />" . "\t";

            my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
            $url = alink( $url, $gene_oid );
            $r .= $gene_oid . $sd . $url . "\t";

            if ($taxon_name) {
                $gene_name .= " [" . $taxon_name . "]";
            }
            $gene_name = escHtml($gene_name);
            $r .= $gene_name . $sd . $gene_name . "\t";

            $perc_identity = sprintf( "%.2f", $perc_identity );
            $r .= $perc_identity . $sd . $perc_identity . "\t";

            my $url2 = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$homolog_gene";
            $url2 = alink( $url2, $homolog_gene );
            $r .= $homolog_gene . $sd . $url2 . "\t";

            my $url3 =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$homo_taxon";
            $r .= $homo_taxon_name . $sd . alink( $url3, $homo_taxon_name ) . "\t";
            
            $r .= $ir_class2 . $sd . $ir_class2 . "\t";
            $r .= $ir_order2 . $sd . $ir_order2 . "\t";
            $r .= $family2 . $sd . $family2 . "\t";
            $r .= $genus2 . $sd . $genus2 . "\t";
            $r .= $species2 . $sd . $species2 . "\t";

            if ( !$copies ) {
                $copies = 1;
            }
            $r .= $copies . $sd . $copies . "\t";

            $it->addRow($r);

            $count++;
            if ( $count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }    # end for
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $scaf_str =~ /gtt_num_id/i );
                  
    }    # end for scaffold_oid

    # file scaffolds
    if ( scalar(@file_scaffolds) > 0 ) {
        print "Querying file ...<br/>\n";

        # get all genes on selected scaffolds
        print "Checking genes on scaffolds ...<br/>\n";
        my %taxon_genes;
        for my $s2 (@file_scaffolds) {
            my ( $taxon_oid, $d2, $scaffold_oid ) = split( / /, $s2 );
            my @genes_on_s;
            if ( $d2 eq 'database' ) {
                @genes_on_s = getDbScaffoldGenes( $dbh, $scaffold_oid );
            } else {
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
                    && ($d2 ne $data_type) ) {
                        next;
                }
                @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $d2, $scaffold_oid );
            }
            my $str = "";
            for my $g2 (@genes_on_s) {
                my ( $gid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id, $source ) =
                  split( /\t/, $g2 );
    
                if ($str) {
                    $str .= "," . $gid;
                } else {
                    $str = $gid;
                }
            }

            if ( $taxon_genes{$taxon_oid} ) {
                $taxon_genes{$taxon_oid} .= "," . $str;
            } else {
                $taxon_genes{$taxon_oid} = $str;
            }
        }

        # get taxon list
        my $taxon_href = PhyloUtil::getTaxonTaxonomy( $dbh, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

        my $rclause1   = WebUtil::urClause('t');
        my $imgClause1 = WebUtil::imgClause('t');

        my %scaf_files;
        my %taxon_names;
        for my $s2 (@file_scaffolds) {
            my ( $taxon_oid, $d2, $scaffold_oid ) = split( / /, $s2 );
            $taxon_oid = sanitizeInt($taxon_oid);

            if ( $scaf_files{$taxon_oid} ) {
                # same file
                next;
            } else {
                my %gene_h;
                my @gs = split( /\,/, $taxon_genes{$taxon_oid} );
                for my $g3 (@gs) {
                    $gene_h{$g3} = 1;
                }

                my $full_dir_name =
                  MetaUtil::getPhyloDistTaxonDir($taxon_oid) . "/" . "assembled" . "." . $percent . ".sdb";
                #print "printScafTaxonomyMetagHits() full_dir_name: $full_dir_name<br/>\n";
                if ( -e $full_dir_name ) {

                    # use SQLite
                    my $dbh2 = WebUtil::sdbLogin($full_dir_name)
                      or next;

                    my $pclause = MetaUtil::getPercentClause( $percent, $plus );

                    my @toid_list = keys %$taxon_href;
                    my $sql2 = MetaUtil::getPhyloDistHomoTaxonsSql( @toid_list );
                    $sql2 .= " $pclause";
                    my $sth2 = $dbh2->prepare($sql2);
                    $sth2->execute();

                    for ( ; ; ) {
                        my ( $gene_oid, $perc_identity, $homolog_gene, $homo_taxon, $copies ) 
                            = $sth2->fetchrow_array();
                        last if !$gene_oid;

                        if ( !$gene_h{$gene_oid} ) {
                            # not selected
                            next;
                        }

                        if ( !$taxon_href->{$homo_taxon} ) {
                            # no access to genome
                            next;
                        }

                        my ( $domain2, $phylum2, $ir_class2, $ir_order2, $family2, $genus2, $species2, $homo_taxon_name ) =
                          split( /\t/, $taxon_href->{$homo_taxon} );
                        if ( $domain && $domain2 ne $domain ) {
                            next;
                        }
                        if ( $phylum && $phylum2 ne $phylum ) {
                            next;
                        }
                        if ( $ir_class && $ir_class2 ne $ir_class ) {
                            next;
                        }
                        if ( $ir_order && $ir_order2 ne $ir_order ) {
                            next;
                        }
                        if ( $family && $family2 ne $family ) {
                            next;
                        }
                        if ( $genus && $genus2 ne $genus ) {
                            next;
                        }
                        if ( $species && $species2 ne $species ) {
                            next;
                        }

                        my $workspace_id = "$taxon_oid assembled $gene_oid";
                        my $gene_name    = $gene_oid;
                        my $url          =
                            "$main_cgi?section=MetaGeneDetail"
                          . "&page=metaGeneDetail&gene_oid=$gene_oid"
                          . "&taxon_oid=$taxon_oid&data_type=assembled";
                        if ( $d2 eq 'database' ) {
                            $workspace_id = $gene_oid;
                            $url          = "$main_cgi?section=GeneDetail" 
                                . "&page=geneDetail&gene_oid=$gene_oid";
                            $gene_name    = geneOid2Name( $dbh, $gene_oid );
                        } else {
                            my $name_src;
                            ( $gene_name, $name_src ) 
                                = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $d2 );
                        }
                        if ( !$gene_name ) {
                            $gene_name = 'hypothetical protein';
                        }

                        my $r .= $sd . "<input type='checkbox' name='$select_id_name' " 
                            . "value='$workspace_id' />" . "\t";

                        $url = alink( $url, $gene_oid );
                        $r .= $workspace_id . $sd . $url . "\t";

                        my $taxon_name = "";
                        if ( $taxon_names{$taxon_oid} ) {
                            $taxon_name = $taxon_names{$taxon_oid};
                        } else {
                            # get taxon name from database
                            my $dbh3 = dbLogin();
                            $taxon_name = QueryUtil::fetchSingleTaxonNvlName( $dbh3, $taxon_oid, $rclause1, $imgClause1 );
                        }

                        if ($taxon_name) {
                            $gene_name .= " [" . $taxon_name . "]";
                        }
                        $gene_name = escHtml($gene_name);
                        $r .= $gene_name . $sd . $gene_name . "\t";
                        $perc_identity = sprintf( "%.2f", $perc_identity );
                        $r .= $perc_identity . $sd . $perc_identity . "\t";

                        my $url2 = "$main_cgi?section=GeneDetail" 
                            . "&page=geneDetail&gene_oid=$homolog_gene";
                        $url2 = alink( $url2, $homolog_gene );
                        $r .= $homolog_gene . $sd . $url2 . "\t";

                        my $url3 =
                            "$main_cgi?section=TaxonDetail"
                          . "&page=taxonDetail&taxon_oid=$homo_taxon";
                        $r .= $homo_taxon_name . $sd . alink( $url3, $homo_taxon_name ) . "\t";
                                    
                        $r .= $ir_class2 . $sd . $ir_class2 . "\t";
                        $r .= $ir_order2 . $sd . $ir_order2 . "\t";
                        $r .= $family2 . $sd . $family2 . "\t";
                        $r .= $genus2 . $sd . $genus2 . "\t";
                        $r .= $species2 . $sd . $species2 . "\t";

                        if ( !$copies ) {
                            $copies = 1;
                        }
                        $r .= $copies . $sd . $copies . "\t";

                        $it->addRow($r);

                        $count++;
                        if ( $count >= $maxGeneListResults ) {
                            $trunc = 1;
                            last;
                        }
                    }
                    $sth2->finish();
                    $dbh2->disconnect();
                    $scaf_files{$taxon_oid} = 1;
                } else {
                    print "printScafTaxonomyMetagHits() missing full_dir_name: $full_dir_name<br/>\n";
                }
                
                $scaf_files{$taxon_oid} = 1;
            }
        }
    }

    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved", 2 );
    }

    if ( !$count ) {
        print "<h6>No genes found.</h6>\n";
        print end_form();
        return;
    }

    $it->printOuterTable(1);

    if ( $count > 0 ) {
        WebUtil::printGeneCartFooter();
        MetaGeneTable::printMetaGeneTableSelect();
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    print end_form();
}

######################################################################
# getDbScaffoldGenes
######################################################################
sub getDbScaffoldGenes {
    my ( $dbh, $scaffold_oid ) = @_;
    my @genes_on_s = ();

    my $sql2 = qq{
        select gene_oid, locus_type, locus_tag, gene_display_name, 
            start_coord, end_coord, strand, scaffold, img_product_source 
        from gene 
        where scaffold = ?
    };

    #print "getDbScaffoldGenes() sql2: $sql2<br/>\n";
    #print "getDbScaffoldGenes() $scaffold_oid: $scaffold_oid<br/>\n";
    my $cur2 = execSql( $dbh, $sql2, $verbose, $scaffold_oid );
    for ( ; ; ) {
        my ( $gid2, @rest ) = $cur2->fetchrow();
        last if !$gid2;
        my $line = $gid2 . "\t" . join( "\t", @rest );
        push @genes_on_s, ($line);
    }
    $cur2->finish();

    return @genes_on_s;
}

sub getScaffoldGenesForDbScaffolds {
    my ( $dbh, $scaffolds_ref ) = @_;

    my %genes_on_scaffolds;

    my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffolds_ref );
    my $sql2    = qq{
        select gene_oid, locus_type, locus_tag, gene_display_name, 
            start_coord, end_coord, strand, scaffold, img_product_source 
        from gene 
        where scaffold in ($oid_str)
    };

    #print "getScaffoldGenesForDbScaffolds() sql2: $sql2<br/>\n";
    my $cur2 = execSql( $dbh, $sql2, $verbose );
    for ( ; ; ) {
        my ( $gid2, @rest ) = $cur2->fetchrow();
        last if !$gid2;
        my $scaffold = $rest[6];
        my $line     = $gid2 . "\t" . join( "\t", @rest );

        my $genes_on_s_ref = $genes_on_scaffolds{$scaffold};
        if ($genes_on_s_ref) {
            push( @$genes_on_s_ref, $line );
        } else {
            my @genes_on_s = ($line);
            $genes_on_scaffolds{$scaffold} = \@genes_on_s;
        }
    }
    $cur2->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $oid_str =~ /gtt_num_id/i );

    return %genes_on_scaffolds;
}

######################################################################
# getDbScaffoldDepth
######################################################################
sub getDbScaffoldDepth {
    my ( $dbh, $scaffold_oid ) = @_;

    my $sql2    = "select read_depth from scaffold where scaffold_oid = ?";
    my $cur2    = execSql( $dbh, $sql2, $verbose, $scaffold_oid );
    my ($depth) = $cur2->fetchrow();
    $cur2->finish();

    if ( !$depth ) {
        $depth = 1;
    }
    return $depth;
}

sub getScaffoldDepthForDbScaffolds {
    my ( $dbh, $scaffolds_ref ) = @_;

    my %depth_on_scaffolds;

    my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffolds_ref );
    my $sql2    = qq{
        select scaffold_oid, read_depth
        from scaffold 
        where scaffold_oid in ($oid_str)
    };
    my $cur2 = execSql( $dbh, $sql2, $verbose );
    my ($depth) = $cur2->fetchrow();
    for ( ; ; ) {
        my ( $scaffold, $depth ) = $cur2->fetchrow();
        last if !$scaffold;

        if ( !$depth ) {
            $depth = 1;
        }
        $depth_on_scaffolds{$scaffold} = $depth;
    }
    $cur2->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $oid_str =~ /gtt_num_id/i );

    return %depth_on_scaffolds;
}

######################################################################
# computeStats
######################################################################
sub computeStats {
    my ($val_aref) = @_;

    my %stats_h;
    my $count = scalar(@$val_aref);
    $stats_h{'count'} = $count;

    if ( $count == 0 ) {
        $stats_h{'sum'}    = 0;
        $stats_h{'mean'}   = 0;
        $stats_h{'median'} = 0;
        $stats_h{'stddev'} = 0;
        return %stats_h;
    }

    my @sortRecs = sort { $a <=> $b } (@$val_aref);
    my $m1       = ceil( $count / 2 );
    my $m2       = floor( $count / 2 );
    if ( $m1 == $m2 ) {
        $stats_h{'median'} = $sortRecs[$m1];
    } else {
        $stats_h{'median'} = ( $sortRecs[$m1] + $sortRecs[$m2] ) / 2;
    }

    my $sum = 0;
    for my $v (@sortRecs) {
        $sum += $v;
    }
    $stats_h{'sum'} = $sum;
    my $mean = $sum / $count;
    $stats_h{'mean'} = sprintf( "%.2f", $mean );

    # standard deviation
    my $sum2 = 0;
    for my $v (@sortRecs) {
        my $diff2 = $v - $mean;
        $sum2 += ( $diff2 * $diff2 );
    }
    my $stddev = sqrt( $sum2 / $count );
    $stats_h{'stddev'} = sprintf( "%.2f", $stddev );

    return %stats_h;
}

sub getScaffoldInfoSql {
    my ( $scaf_str, $rclause, $imgClause ) = @_;

    my $sql = qq{
        select s.scaffold_oid, s.taxon, ss.seq_length,
        s.mol_topology, ss.count_total_gene, ss.gc_percent,
        s.read_depth
        from scaffold s, scaffold_stats ss
        where s.scaffold_oid = ss.scaffold_oid
        and s.scaffold_oid in ( $scaf_str )
        $rclause
        $imgClause
    };

    #print "getScaffoldInfoSql sql: $sql<br/>\n";

    return $sql;
}

#####################################################################
# submitJob
#####################################################################
sub submitJob {
    my ($jobPrefix) = @_;

    printMainForm();

    my $lcJobPrefix;
    if ( $jobPrefix =~ /phylo/i ) {
        $lcJobPrefix = 'phylo';
    }
    else {
        $lcJobPrefix = lc($jobPrefix);
    }
    #print "submitJob() job=$jobPrefix, lcJob=$lcJobPrefix<br/>\n";

    my $data_type;
    if ( $lcJobPrefix eq 'histogram' ) {
        $data_type = param('data_type_h');
    }
    elsif ( $lcJobPrefix eq 'kmer' ) {
        $data_type = param('data_type_k');
        if ( $include_metagenomes ) {
            if ( ! $data_type ) {
                $data_type = 'assembled';
            }
            if ( $data_type ne 'assembled' ) {
                webError("Only assembled MER_FS scaffold is supported in Kmer.");
                return;
            }
        }
    }
    elsif ( $lcJobPrefix eq 'phylo' ) {
        $data_type = param('data_type_p');
    }

    my $d_type;
    if ( $lcJobPrefix eq 'histogram' ) {
        $d_type = param('histogram_type');
        if ( ! $d_type ) {
            $d_type = 'gene_count';        
        }
    } 
    elsif ( $lcJobPrefix eq 'kmer' ) {
        require Kmer;
        my $outputPrefix = Kmer::findKmerSettings();
        #print "submitJob() outputPrefix=$outputPrefix, maidenRun=$maidenRun<br/>\n";
        $d_type = $outputPrefix;
    } 

    print "<h2>Computation Job Submission ($jobPrefix)</h2>\n";

    my $dbh = dbLogin();
    my $sid = WebUtil::getContactOid();
    $sid = sanitizeInt($sid);

    my $folder = $SCAF_FOLDER;
    my $set_names;
    my $share_set_names;
    my $set_names_message;

    my @all_files = WorkspaceUtil::getAllInputFiles($sid);
    for my $file_set_name (@all_files) {
        my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $file_set_name, $ownerFilesetDelim, $folder );
        $x = MetaUtil::sanitizeGeneId3($x);
        my $share_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $owner, $x, $sid );
        my $f2 = WorkspaceUtil::getOwnerFilesetName( $owner, $x, $ownerFilesetDelim_message, $sid );
        if ($set_names) {
            $set_names .= "," . $file_set_name;
            $share_set_names .= "," . $share_set_name;
            $set_names_message .= "," . $f2;
        } else {
            $set_names = $file_set_name;
            $share_set_names = $share_set_name;
            $set_names_message = $f2;
        }
    }
    if ( !$set_names ) {
        webError("Please select at least one scaffold set.");
        return;
    }    

    print "<p>Scaffold Set(s): $share_set_names<br/>\n";
    HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );

    if ( $d_type ) {
        if ( $lcJobPrefix eq 'kmer' ) {
            require Kmer;
            my $text = Kmer::getKmerSettingDisplay( $d_type );
            print "Kmer Settings: $text<br/>\n";
        }
        else {
            print "Display Type: $d_type<br/>\n";
        }
    }

    my $sid = getContactOid();
    $sid = sanitizeInt($sid);

    my $output_name = Workspace::validJobSetNameToSaveOrReplace( $lcJobPrefix );
    my $job_file_dir = Workspace::getJobFileDirReady( $sid, $output_name );

    ## output info file
    my $info_file = "$job_file_dir/info.txt";
    my $info_fs   = newWriteFileHandle($info_file);
    print $info_fs "Scaffold $jobPrefix\n";
    print $info_fs "--scaffold $share_set_names\n";
    print $info_fs "--datatype $data_type\n" if ( $data_type );
    print $info_fs "--dtype $d_type\n" if ( $d_type );
    print $info_fs currDateTime() . "\n";
    close $info_fs;

    #old code that uses .py files, keep it as reference
    #if ( $env->{client_py_exe} ) {
    #    $ENV{'PATH'} .= $env->{client_path};
    #    my @cmd = (
    #        "client_wrapper.sh", "--program", "scafPhyloDist", "--contact", "$sid", "--output",
    #        "$output_name",      "--scafset", "$scaf_set_names"
    #    );
    #
    #    printStartWorkingDiv();
    #    print "<p>cmd: " . join( " ", @cmd ) . "<p>\n";
    #
    #    WebUtil::unsetEnvPath();
    #    my $st = system( $env->{client_py_exe}, @cmd );
    #    printEndWorkingDiv();
    #
    #    if ($st) {
    #        print "<p><font color='red'>Error Code: $st</font>\n";
    #    } else {
    #        print "<p>Job is submitted successfully.\n";
    #    }
    #
    #    if ($st) {
    #        # print error file
    #        my $info_file = "$job_file_dir/error.txt";
    #        my $info_fs   = newWriteFileHandle($info_file);
    #        print $info_fs "$st\n";
    #        print $info_fs currDateTime() . "\n";
    #        close $info_fs;
    #    }
    #
    #    WebUtil::resetEnvPath();
    #} else {
    #    print "<p>Cannot find client_wrapper.sh\n";
    #}

    my $queue_dir = $env->{workspace_queue_dir};
    #print "submitJob() queue_dir=$queue_dir<br/>\n";
    my $queue_filename;
    if ( $lcJobPrefix eq 'histogram' ) {
        $queue_filename = $sid . '_scafHistogram_' . $output_name;
    } 
    elsif ( $lcJobPrefix eq 'kmer' ) {
        $queue_filename = $sid . '_scafKmer_' . $output_name;
    } 
    elsif ( $lcJobPrefix eq 'phylo' ) {
        $queue_filename = $sid . '_scafPhyloDist_' . $output_name;
    }
    #print "submitJob() queue_filename=$queue_filename<br/>\n";
    my $wfh = newWriteFileHandle( $queue_dir . $queue_filename );

    if ( $lcJobPrefix eq 'histogram' ) {
        print $wfh "--program=scafHistogram\n";
    } 
    elsif ( $lcJobPrefix eq 'kmer' ) {
        print $wfh "--program=scafKmer\n";
    } 
    elsif ( $lcJobPrefix eq 'phylo' ) {
        print $wfh "--program=scafPhyloDist\n";
    }
    print $wfh "--contact=$sid\n";
    print $wfh "--output=$output_name\n";
    print $wfh "--scafset=$set_names_message\n";
    print $wfh "--datatype=$data_type\n" if ( $data_type );
    print $wfh "--dtype=$d_type\n" if ( $d_type );
    close $wfh;
    
    Workspace::rsync($sid);
    print "<p>Job is submitted successfully.\n";

    print end_form();
}

1;
