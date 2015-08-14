###########################################################################
# WorkspaceGeneSet.pm
# $Id: WorkspaceGeneSet.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
###########################################################################
package WorkspaceGeneSet; 

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
use LWP; 
use HTTP::Request::Common qw( POST ); 
use ChartUtil; 
use InnerTable; 
use WebConfig; 
use WebUtil; 
use GenomeListFilter;
use GenerateArtemisFile;
use MetaUtil; 
use HashUtil; 
use MetaGeneTable; 
use TabHTML;
use Workspace;
use WorkspaceUtil;
use WorkspaceQueryUtil;
use MerFsUtil;
use OracleUtil;
use QueryUtil;
use SequenceExportUtil;
use FunctionAlignmentUtil;
 
$| = 1; 
 
my $section              = "WorkspaceGeneSet"; 
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

my $avagz_batch_dir = $env->{ avagz_batch_dir }; 
my $genomePair_zfiles_dir = $env->{ genomePair_zfiles_dir };

my $include_bbh_lite     = $env->{include_bbh_lite}; 
my $bbh_files_dir        = $env->{bbh_files_dir}; 
my $bbh_zfiles_dir        = $env->{bbh_zfiles_dir};

my $blast_server_url        = $env->{blast_server_url}; 
my $img_lid_blastdb         = $env->{img_lid_blastdb}; 
my $img_iso_blastdb         = $env->{img_iso_blastdb}; 
my $lite_homologs_url       = $env->{lite_homologs_url}; 
my $use_app_lite_homologs   = $env->{use_app_lite_homologs}; 
my $img_hmms_serGiDb        = $env->{img_hmms_serGiDb}; 
my $img_hmms_singletonsGiDb = $env->{img_hmms_singletonsDb};
my $user_restricted_site    = $env->{user_restricted_site};
my $formatdb_bin            = $env->{formatdb_bin};

my $cog_base_url       = $env->{cog_base_url};
my $pfam_base_url      = $env->{pfam_base_url};
my $tigrfam_base_url   = $env->{tigrfam_base_url};
my $enzyme_base_url    = $env->{enzyme_base_url};
my $kegg_orthology_url = $env->{kegg_orthology_url};
 
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
if ( ! $merfs_timeout_mins ) { 
    $merfs_timeout_mins = 60; 
} 
 
# user's sub folder names                                                             
my $GENE_FOLDER   = "gene"; 
my $FUNC_FOLDER   = "function"; 

my $filename_size      = 25; 
my $filename_len       = 60; 
my $max_workspace_view = 10000; 
my $max_profile_select = 50;
my $maxProfileOccurIds    = 100;
my $maxGeneProfileIds    = 100;
my $max_genome_selections = 1000; 

my $NUM_OF_BANDS = 8; 
my $maxScaffolds = 10;
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
 
    Workspace::initialize();

    if ( !$page && paramMatch("wpload")) {
        $page = "load";
    } 
    elsif (!$page && paramMatch("delete")) {
        $page = "delete"; 
    } 

    if ( $page eq "view" ) {
	    Workspace::viewFile();
    }
    elsif ( $page eq "delete" ) { 
        Workspace::deleteFile(); 
    }
    elsif ( $page eq "load" ) {
        Workspace::readFile();
    }
    elsif ($page eq "showDetail"  ) {
        printGeneSetDetail(); 
    }
    elsif ( paramMatch("exportSelectedGeneFasta") ne "" ||
           $page eq "exportselectedGeneFasta" ) {
        exportSelectedGeneFasta();
    }
    elsif ( paramMatch("exportSelectedGeneAA") ne "" ||
           $page eq "exportselectedGeneAA" ) {
        exportSelectedGeneAA();
    }
    elsif( paramMatch( "viewGeneSetGenomes" ) ne "" ||
           $page eq "viewGeneSetGenomes" ) { 
        viewGeneGenomes(1); 
    }
    elsif( paramMatch( "viewGeneGenomes" ) ne "" ||
           $page eq "viewGeneGenomes" ) {
	    viewGeneGenomes(0);
    }
    elsif( paramMatch( "viewGeneSetScaffolds" ) ne "" ||
           $page eq "viewGeneSetScaffolds" ) { 
        viewGeneScaffolds(1); 
    }
    elsif( paramMatch( "viewGeneScaffolds" ) ne "" ||
           $page eq "viewGeneScaffolds" ) {
	    viewGeneScaffolds(0);
    }
    elsif ( $page eq "showSetFuncProfile" || 
	    paramMatch("showSetFuncProfile") ) { 
        my $profile_type = param('ws_profile_type'); 
        if ( $profile_type eq 'func_category' ) { 
            showGeneFuncCateProfile(1);
	    }
        else { 
            showGeneFuncSetProfile(1); 
        }
    }
    elsif ( $page eq "showGeneFuncProfile" || 
	    paramMatch("showGeneFuncProfile") ) { 
        my $profile_type = param('ws_profile_type'); 
        if ( $profile_type eq 'func_category' ) { 
            showGeneFuncCateProfile(0);
	    }
        else { 
            showGeneFuncSetProfile(0); 
        }
    }
    elsif ( $page eq "profileGeneList" || 
	    paramMatch("profileGeneList") ) {
	    Workspace::showProfileGeneList(); 
    }
    elsif( paramMatch( "geneProfile_s" ) ne "" ||
           $page eq "geneProfile_s" ) {
	    printGeneProfile();
    }
    elsif( paramMatch( "geneProfile_t" ) ne "" ||
           $page eq "geneProfile_t" ) {
	    printGeneProfileTranspose();
    }
    elsif( paramMatch( "geneProfilerGenes" ) ne "" ||
           $page eq "geneProfilerGenes" ) {
    	printGeneProfilerGenes();
    }
    elsif ( paramMatch("geneOccurProfiles") ne "" ) {
        printPhyloOccurProfiles_otf(); 
    }
    elsif( paramMatch( "geneChrViewerSelect" ) ne "" ||
           $page eq "geneChrViewerSelect" ) {
    	printGeneChrViewerSelection();
    }
    elsif( paramMatch( "chromViewerSelect" ) ne "" ||
           $page eq "chromViewerSelect" ) {
    	printChromosomeViewerSelection();
    }
    elsif( paramMatch( "drawChromMap" ) ne "" ||
           $page eq "drawChromMap" ) {
    	printChromosomeMap();
    }
    elsif( paramMatch( "submitFuncProfile" ) ne "" ||
           $page eq "submitFuncProfile" ) {
	    Workspace::submitFuncProfile($GENE_FOLDER);
    }
    elsif( paramMatch( "viewProteinDomain" ) ne "" ||
           $page eq "viewProteinDomain" ) {
    	printViewProteinDomain();
    }
    elsif( paramMatch( "listProteinDomainResult" ) ne "" ||
           $page eq "listProteinDomainResult" ) {
    	printListProteinDomainResult();
    }
    else {
    	printGeneSetMainForm();
    }
}


############################################################################
# printGeneSetMainForm
############################################################################
sub printGeneSetMainForm {
    my ($text) = @_;

    my $folder = $GENE_FOLDER;

    my $sid = getContactOid();

    opendir( DIR, "$workspace_dir/$sid/$folder" ) 
        or webDie("failed to open folder list");
    my @files = readdir(DIR);
    closedir(DIR); 

    print "<h1>My Workspace - Gene Sets</h1>"; 

    print qq{
        <script type="text/javascript" src="$base_url/Workspace.js" >
        </script>
    }; 
 
    print $text; 
 
    printMainForm(); 

    printHint("Select one or more gene sets to perform gene set analysis. Click on the gene set count to view and analyze genes in a particular gene set.");
    print "<br/>";

    my $super_user_flag = getSuperUser(); 

    TabHTML::printTabAPILinks("genesetTab");
    #block 'Chromosome Map'
    #my @tabIndex = ( "#genesettab1", "#genesettab2", "#genesettab3", "#genesettab4", "#genesettab5", "#genesettab6" );
    my @tabIndex = ( "#genesettab1", "#genesettab2", "#genesettab3", "#genesettab4", "#genesettab5" );
    #my @tabNames = ( "Gene Sets", "Import & Export", "Genomes & Scaffolds", "Function Profile", "Chromosome Map", "Set Operation" );
    my @tabNames = ( "Gene Sets", "Import & Export", "Genomes & Scaffolds", "Function Profile", "Set Operation" );
    TabHTML::printTabDiv("genesetTab", \@tabIndex, \@tabNames);

    print "<div id='genesettab1'>";
    WorkspaceUtil::printShareMainTable($section_cgi, $section, $workspace_dir, $sid, $folder, @files);
    print hiddenVar( "directory", "$folder" );
    print "</div>\n";

    print "<div id='genesettab2'>";
    # Import/Export
    Workspace::printImportExport($folder);

    print "<h2>Data Export</h2>\n"; 
    GenerateArtemisFile::printDataExportHint($folder);
    print "<p>You may export data for selected gene set(s).\n"; 
    print "<p>\n";

    ## enter email address
    GenerateArtemisFile::printEmailInputTable($sid, $folder);
 
    my $name = "_section_Workspace_exportGeneFasta_noHeader";
    print submit( 
        -name  => $name, 
        -value => 'Fasta Nucleic Acid File', 
        -class => 'meddefbutton',
        -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button $name']); return checkSets('$folder');"
    );
 
    print nbsp(1); 
    $name = "_section_Workspace_exportGeneAA_noHeader"; 
    print submit( 
        -name  => $name, 
        -value => 'Fasta Amino Acid File', 
        -class => 'meddefbutton',
        -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button $name']); return checkSets('$folder');"
    );
    print nbsp(1); 
    
    print "</div>\n";

    print "<div id='genesettab3'>";
    printHint("Only scaffolds of <b>assembled</b> genes will be displayed or saved.");

    print "<h2>View Genomes or Scaffolds</h2>"; 
    print "<p>You can view genomes or scaffolds of genes in the selected gene set(s).<br/>"; 
    print "<br/>";
    print submit( 
        -name  => '_section_WorkspaceGeneSet_viewGeneSetGenomes', 
        -value => 'View Genomes', 
        -class => 'smbutton',
        -onClick => "return checkSetsIncludingShare('$folder');"
    );
    print nbsp(2);
    print submit( 
        -name  => '_section_WorkspaceGeneSet_viewGeneSetScaffolds', 
        -value => 'View Scaffolds', 
        -class => 'smbutton',
        -onClick => "return checkSetsIncludingShare('$folder');"
    );

#    print "<h2>Save Scaffolds to Workspace</h2>\n"; 
#    print "<p>You may save scaffolds of selected gene set(s) to the workspace.<br/>"; 
#        print "(<b>Note:</b> " 
#            . "Only scaffolds of <b>assembled</b> genes will be saved.)\n"; 
#    print "<p>File name:<br/>\n"; 
#        print "<input type='text' " 
#            . "size='$filename_size' maxLength='$filename_len' " 
#            . "name='gene_scaf_filename' " 
#            . "title='All special characters will be removed and spaces converted to _ ' />\n"; 
#    print "<br/>";
#    print "<input class='medbutton' type='submit' "
#            . "name='_section_Workspace_saveGeneScaffolds' "
#            . "value='Save Scaffolds to Workspace' />\n";

    print nbsp(1);
    WorkspaceUtil::printSaveGeneSetGenomesAlternativeToWorkspace('filename,share_filename');
    WorkspaceUtil::printSaveGeneSetScaffoldsAlternativeToWorkspace('filename,share_filename');

    print "</div>\n";

    print "<div id='genesettab4'>";
    print "<h2>Gene Set Function Profile</h2>\n"; 
    my $jgi_user = Workspace::getIsJgiUser($sid);
    printHint("Limit number of gene sets and/or number of functions to avoid timeout. If you have large numbers of genes and/or functions, submit a computation job instead."); 

    Workspace::printUseFunctionsInSet($sid);    
    Workspace::printUseAllFunctionTypes();
    HtmlUtil::printMetaDataTypeChoice();
 
    # submit button
    print "<p>\n"; 
    print submit( 
        -name  => "_section_WorkspaceGeneSet_showSetFuncProfile", 
        -value => "Gene Set Function Profile",
        -class => "medbutton",
        -onClick => "return checkSetsIncludingShare('$folder');"             
    );

    require WorkspaceJob;
    my ($genomeFuncSets_ref, $genomeBlastSets_ref, $genomePairwiseANISets_ref, $geneFuncSets_ref, 
        $scafFuncSets_ref, $scafHistSets_ref, $scafKmerSets_ref, $scafPhyloSets_ref, $funcScafSearchSets_ref, 
        $genomeSaveFuncGeneSets_ref, $geneSaveFuncGeneSets_ref, $scafSaveFuncGeneSets_ref)
        = WorkspaceJob::getExistingJobSets();

    Workspace::printSubmitComputation($sid, $folder, 'func_profile', 
        '_section_WorkspaceGeneSet_submitFuncProfile', '', $geneFuncSets_ref );
    
    print "</div>\n";

=pod
    # chromosome map
    print "<div id='genesettab5'>";
    print "<h2>Chromosome Map</h2>" ; 
    print "<p>You may select gene sets to view " .
        "against an the entire chromosome. " .
	"Only assembled genes will be displayed.</p>\n"; 
 
    my $name = "_section_${section}_chromViewerSelect"; 
    print submit( 
          -name  => $name, 
          -value => "Chromosome Map", 
          -class => "medbutton" 
	); 
    printHint( 
        qq{
        - Maps from maximum of $maxScaffolds scaffolds can be drawn.<br/> 
        - Selected gene sets are projected on inner circles
          of the circular diagram.<br/> 
        - Initially genes are assigned to circles based on gene sets.
          <br/>
        - User will be prompted in the next page to assign genes to 
          different circles.<br/> 
        } 
	); 
    print "</div>\n";
=cut

    print "<div id='genesettab5'>";
    Workspace::printSetOperation($folder, $sid);    
    Workspace::printBreakLargeSet($sid, $folder);
    print "</div>\n";

    TabHTML::printTabDivEnd();

    print end_form();

}


###############################################################################
# printGeneSetDetail
###############################################################################
sub printGeneSetDetail { 
    my $filename = param("filename"); 
    my $folder   = param("folder"); 
 
    printMainForm(); 
 
    my $sid = getContactOid();
    my $dir_id = $sid;
    my $owner = param("owner"); 
    my $owner_name = ""; 
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
		$dir_id = $owner;
                last; 
            } 
        } 

        if ( ! $can_view ) { 
            print "<h1>My Workspace - Gene Sets - Individual Gene Set</h1>"; 
            print "<p><u>File Name</u>: " . escapeHTML($filename) . "</p>";
            webError("Gene set does not exist.");
            return; 
        }
    } 

    print "<h1>My Workspace - Gene Sets - Individual Gene Set</h1>"; 
    print "<h2>Set Name: <i>" . escapeHTML($filename) . "</i></h2>\n"; 
    if ( $owner_name ) {
        print "<p><u>Owner</u>: <i>$owner_name</i></p>"; 
    } 

    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder",   $folder ); 
    print hiddenVar( "filename", $filename ); 

    # check filename
    if ( $filename eq "" ) { 
        webError("Cannot read file.");
        return;
    }
 
    WebUtil::checkFileName($filename);
    $filename = WebUtil::validFileName($filename);

    my $full_path_name = "$workspace_dir/$sid/$folder/$filename"; 
    if ( $owner ) {
        $full_path_name = "$workspace_dir/$owner/$folder/$filename";
    } 
    if ( ! (-e $full_path_name) ) { 
        webError("Gene set does not exist."); 
        return;
    } 

    # this also untaints the name
    my $select_id_name = "gene_oid";

    if ( $sid == 312 ) {
    	print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    my $dbh = dbLogin(); 
    my ($taxon2name_href, $taxons_in_file_href) 
        = QueryUtil::fetchAllTaxonsOidAndNameFile($dbh);

    my %gene2toid;
    my %tags;
    my %names; 
    my $trunc = getGeneSetGeneNames($dir_id, $filename, \%gene2toid, \%tags, 
        \%names, $taxon2name_href, $maxGeneListResults, 1);
    printEndWorkingDiv(); 

    if ( $sid == 312 ) {
    	print "<p>*** time2: " . currDateTime() . "\n";
    	print "<p>genes: " . scalar(keys %gene2toid) . ", names: " .
    	    scalar(keys %names) . "\n";
    }

    if ($trunc) { 
    	WebUtil::printMessage("There are too many genes. Only $maxGeneListResults genes are displayed.");
    	print "<p>\n";
    } 

=pod
    TabHTML::printTabAPILinks("genesetTab"); 
    my @tabIndex = ( "#genesettab1", "#genesettab2", "#genesettab3", "#genesettab4", "#genesettab5", "#genesettab6", "#genesettab7", "#genesettab8", "#genesettab9" );
    my @tabNames = ( "Genes", "Save", "Expand Display", "Genomes & Scaffolds", "Profiles", "Chromosome Map", "Sequence Alignment", "Gene Neighborhood", "Set Operation" );
    TabHTML::printTabDiv("genesetTab", \@tabIndex, \@tabNames);
=cut

    print "<div id='genesettab1'>";

#    printHint("Gene names of large gene sets are not displayed. Use 'Expand Display' tab option to view detailed gene information.");

    my $it = new InnerTable( 1, "geneSet$$", "geneSet", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "char asc", "left" );
    $it->addColSpec( "Locus tag",   "char asc", "left" );
    $it->addColSpec( "Gene Product Name", "char asc", "left" ); 
    $it->addColSpec( "Genome ID", "char asc", "left" ); 
    $it->addColSpec( "Genome Name", "char asc", "left" ); 
    my $sd = $it->getSdDelim(); 

    my $row   = 0;
    my %taxon_h;
    my $can_select = 0; 
    for my $id (keys %gene2toid) { 
        my $r; 
        my $url; 

        # determine URL and validation of id
        my $display_id;
        my $notInDatabase;
        my ( $t1, $d1, $g1 ) = split( / /, $id );
        if ( !$g1 && isInt($t1) && isInt($id) ) {
            $display_id = $id;
            $url = "$main_cgi?section=GeneDetail"
                . "&page=geneDetail&gene_oid=$t1";
            if ( ! $names{$id} ) { 
                $notInDatabase = 1;
            }                
        }
        else {
            $display_id = $g1; 
            $url = "$main_cgi?section=MetaGeneDetail"
                . "&page=metaGeneDetail&taxon_oid=$t1" 
                . "&data_type=$d1&gene_oid=$g1";
        } 

        if ( $notInDatabase ) { 
            # not in database
            $r = $sd . " \t" . $id . $sd . $id . "\t" . "(not in this database)"
                . $sd . "(not in this database)" . "\t";
            $r .= "-" . $sd . "-" . "\t";
        } 
        else { 
            $can_select++; 
            $r = $sd . "<input type='checkbox' name='$select_id_name' value='$id' checked /> \t";
 
            # determine URL 
            my $display_id;
    	    my ( $t1, $d1, $g1 ) = split( / /, $id );
    	    if ( !$g1 && isInt($t1) ) {
    	        $display_id = $id;
        		$url = "$main_cgi?section=GeneDetail"
        		    . "&page=geneDetail&gene_oid=$t1";
    	    }
    	    else {
        		$display_id = $g1; 
        		$url = "$main_cgi?section=MetaGeneDetail"
        		    . "&page=metaGeneDetail&taxon_oid=$t1" 
        		    . "&data_type=$d1&gene_oid=$g1";
    	    } 

            if ($url) {
                $r .= $id . $sd . alink( $url, $display_id ) . "\t";
            } 
            else { 
                $r .= $id . $sd . $id . "\t";
            } 

            $r .= $tags{$id} . $sd . $tags{$id} . "\t";
 
            $r .= $names{$id} . $sd . $names{$id} . "\t";
 
    	    if ( $gene2toid{$id} ) { 
        		my $t_oid = $gene2toid{$id}; 
                $r .= $t_oid . $sd . $t_oid . "\t";

        		my $taxon_url = "$main_cgi?section=TaxonDetail" .
        		    "&page=taxonDetail&taxon_oid=$t_oid";
        		if ( $taxons_in_file_href->{$t_oid} ) {
        		    $taxon_url = "$main_cgi?section=MetaDetail" . 
        			"&page=metaDetail&taxon_oid=$t_oid&";
        		} 
        		my $taxon_name = $taxon2name_href->{$t_oid};
        		$r .= $t_oid . $sd . "<a href=\"$taxon_url\" >" . $taxon_name . "</a> \t";
    	    } 
    	    else {
                $r .= "-" . $sd . "-" . "\t";
        		$r .= "-" . $sd . "-" . "\t";
            }
    	}
 
        $it->addRow($r); 
        $row++;
    }
 
    if ($row > 10) {
        WebUtil::printGeneCartFooter();        
    }
 
    $it->printOuterTable(1);
  
    my $load_msg = "Loaded"; 
    if ( $can_select <= 0 ) { 
        $load_msg .= "; none in this database.";
    } 
    elsif ( $can_select < $row ) { 
        $load_msg .= "; only $can_select selectable.";
    } 
    else {
        $load_msg .= ".";
    } 
 
    printStatusLine( $load_msg, 2 );
    if ( $can_select <= 0 ) { 
        print end_form();
        return;
    }
    
    WebUtil::printGeneCartFooter(); 
    
    print "</div>\n";

    my $super_user_flag = getSuperUser(); 
    if ( $super_user_flag eq 'Yes' ) {
	print "<div id='geneprotein'>";
	print "<h2>Display Protein Domains of Selected Genes</h2>\n";
	print "<p><font color='red'>This feature is available for super users only.</font>\n";
	print "<p>Select 1 to $maxGeneProfileIds genes to view protein domains.<br/>\n";
	my $name = "_section_WorkspaceGeneSet_viewProteinDomain"; 
	print submit( 
            -name  => $name, 
            -value => 'View Protein Domains', 
            -class => 'meddefbutton' 
            ); 
	print "<br/>\n";
	print "</div>\n";
    }

    print "<div id='genesettab2'>";
    WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    print "</div>\n";

=pod
    print "<h2>Data Export</h2>\n"; 
    print "<p>You may export data for selected genes.\n"; 
    printHint("Export for large gene sets will be very slow.");
    print "<p>\n";

    #my $name = "_section_WorkspaceGeneSet_exportSelectedGeneAA_noHeader"; 
    my $name = "_section_WorkspaceGeneSet_exportSelectedGeneAA"; 
    print submit( 
            -name  => $name, 
            -value => 'Fasta Amino Acid File', 
            -class => 'meddefbutton' 
            ); 
    print "<br/>\n";
 
   #$name = "_section_WorkspaceGeneSet_exportSelectedGeneFasta_noHeader";
    $name = "_section_WorkspaceGeneSet_exportSelectedGeneFasta";
    print submit( 
            -name  => $name, 
            -value => 'Fasta Nucleic Acid File', 
            -class => 'meddefbutton' 
    ); 
    print nbsp(2); 
    print "<input type='text' size='3' name='up_stream' value='-0' />\n";
    print "bp upstream\n"; 
    print nbsp(2); 
    print "<input type='text' size='3' name='down_stream' value='+0' />\n";
    print "bp downstream\n"; 
    
    print "</div>\n";

    print "<div id='genesettab3'>";
    MetaGeneTable::printMetaGeneTableSelect(); 
    print "</div>\n";

    print "<div id='genesettab4'>";
    printHint("Only scaffolds of <b>assembled</b> genes will be displayed or saved.");

    print "<h2>View Genomes or Scaffolds</h2>"; 
    print "<p>You can view genomes or scaffolds of selected gene(s).<br/>"; 
    print "<br/>";
    print "<input class='smbutton' type='submit' "
	   . "name='_section_WorkspaceGeneSet_viewGeneGenomes' "
	   . "value='View Genomes' />\n";
    print nbsp(2);
    print "<input class='smbutton' type='submit' "
	   . "name='_section_WorkspaceGeneSet_viewGeneScaffolds' "
	   . "value='View Scaffolds' />\n";

    print nbsp(1);
    WorkspaceUtil::printSaveGeneGenomesAlternativeToWorkspace($select_id_name);
    WorkspaceUtil::printSaveGeneScaffoldsAlternativeToWorkspace($select_id_name);

    print "</div>\n";


    print "<div id='genesettab5'>";
    print "<h2>Gene Function Profile</h2>\n";
    printHint("Limit number of genes and/or number of functions to avoid timeout."); 
    Workspace::printUseFunctionsInSet($sid);    
    Workspace::printUseAllFunctionTypes();

    # submit button
    print "<p>\n"; 
    print submit( 
            -name  => "_section_WorkspaceGeneSet_showGeneFuncProfile", 
            -value => "View Function Profile",
            -class => "medbutton " 
    ); 

    print "<hr>\n";

    print "<h2>Gene Profile</h2>"; 
    GenomeListFilter::appendGenomeListFilter($dbh, '', 0, '', 'Yes', 'No');
 
    printHint( "- Hold down the control key (or command key in the case of Mac) " 
             . "to select multiple genomes.<br/>\n" 
             . "- Drag down list to select all genomes.<br/>\n" 
	       . "- More genome and gene selections result in slower query.\n" ); 
 
    print "<p>\n"; 
    print "View 1 to $maxGeneProfileIds selected protein coding genes against selected genomes "; 
    print "using unidirectional sequence similarities.<br/>\n"; 
    print "Use the <font color='blue'><u>Genome Filter</u></font> above to " 
        . "select 1 to $max_genome_selections genome(s).<br/>\n"; 
    print "You can change the default E-value and percent identity cutoff below.<br/>";
    print "</p>\n"; 
 
    my $name = "_section_${section}_geneProfile_s"; 
    print submit( 
                  -id    => "go1", 
                  -name  => $name, 
                  -value => "View Genes vs. Genomes", 
                  -class => "meddefbutton" 
	); 
    print nbsp(1); 
    my $name = "_section_${section}_geneProfile_t"; 
    print submit( 
                  -id    => "go2", 
                  -name  => $name, 
                  -value => "View Genomes vs. Genes", 
                  -class => "medbutton" 
	); 
    print nbsp(1); 
    print "<input id='reset' type='button' name='clearSelections' " 
	. "value='Reset' class='smbutton' />\n"; 
    print "<p>\n";

    WebUtil::printProfileBlastConstraints();

    print "<h2>Occurrence Profile</h2>";
    print "<p>\n"; 
    my $url = "$main_cgi?section=TaxonList&page=taxonListAlpha";
    my $link = alink( $url, "Genome Browser" );
    print "Show phylogenetic occurrence profile for selected genes. Please select no more than $maxProfileOccurIds genes.<br/>\n";
    print "You can change the default E-value and percent identity cutoff above.<br/>";

    print "</p>\n";

    my $name = "_section_${section}_geneOccurProfiles"; 
    print submit(
                  -name  => $name, 
                  -value => "View Phylogenetic Occurrence Profiles",
                  -class => 'lgbutton'
	); 

    print "</div>\n";

    print "<div id='genesettab6'>";
    print "<h2>Chromosome Map</h2>"; 
    print "<p>View selected genes " .
        "against an the entire chromosome. " .
	"Only assembled genes will be displayed.</p>\n"; 
 
    my $name = "_section_${section}_geneChrViewerSelect"; 
    print submit( 
                  -name  => $name, 
                  -value => "Chromosome Map", 
                  -class => "medbutton" 
	); 
    printHint( 
        qq{
        - Maps from maximum of $maxScaffolds scaffolds can be drawn.<br/> 
        - Selected gene sets are projected on inner circles
          of the circular diagram.<br/> 
        - Initially genes are assigned to circles based on gene sets.
          <br/>
        - User will be prompted in the next page to assign genes to 
          different circles.<br/> 
        } 
	); 
    print "</div>\n";

    print "<div id='genesettab7'>";
    print "<h2>Sequence Alignment</h2>"; 
    print "<p>You may select genes from the cart " 
        . "for sequence alignment with ClustalW.</p>"; 
    print "<p>\n"; 
    print "<input type='radio' name='alignment' value='amino' checked />\n"; 
    print "Protein<br/>\n"; 
    print "<input type='radio' name='alignment' value='nucleic' />\n"; 
    print "DNA\n"; 
    print nbsp(2); 
    print "<input type='text' size='3' " 
	. "name='align_up_stream' value='-0' />\n"; 
    print "bp upstream.\n"; 
    print nbsp(2); 
    print "<input type='text' size='3' " 
	. "name='align_down_stream' value='+0' />\n"; 
    print "bp downstream\n"; 
    print "<br/>\n"; 
    print "</p>\n"; 

    my $name = "_section_ClustalW_runClustalW"; 
    print submit(
                  -name  => $name,
                  -value => "Do Alignment", 
                  -class => 'smbutton' 
	); 
    print "</div>\n";

    print "<div id='genesettab8'>";
    print "<h2>Gene Neighborhood</h2>\n";
    print "<p>You may view the chromosomal neighborhood of each gene " 
        . "selected in the gene cart.</p>"; 
    print "<p>\n"; 
    print "<input type='radio' name='alignGenes' value='1' checked />" 
        . "5'-3' direction of each selected gene is left to right<br/>\n"; 
    print "<input type='radio' name='alignGenes' value='0' />" 
        . "5'-3' direction of plus strand is always left to right, on top"; 
    print "<br/>\n"; 
    print "</p>\n"; 
 
    my $name = "_section_GeneNeighborhood_selectedGeneNeighborhoods"; 
    print submit( 
                  -name  => $name, 
                  -value => "Show Neighborhoods", 
                  -class => 'smbutton' 
	); 
    print "</div>\n";

    print "<div id='genesettab9'>";
    Workspace::printSetOpSection($filename, $folder);
    print "</div>\n";

    TabHTML::printTabDivEnd();    
=cut

    print end_form(); 
} 


###########################################################################
# getGeneSetGeneNames
###########################################################################
sub getGeneSetGeneNames {
    my ($sid, $filename, $gene2toid_href, $locus_tag_href, $gene_name_href, $taxon_href,
	$max_count, $print_msg) = @_;

    if (-e "$workspace_dir/$sid/$GENE_FOLDER/$filename") {
    	WebUtil::checkFileName($filename); 
    }
    else {
    	return 0;
    }

    $filename = WebUtil::validFileName($filename);
    my @db_ids;
    my @meta_ids; 
    my %taxon_genes;

    my $row = 0;
    my $trunc = 0;
    my $res   = newReadFileHandle("$workspace_dir/$sid/$GENE_FOLDER/$filename");
    while ( my $id = $res->getline() ) {
        if ( $row >= $max_count ) {
	        $trunc = 1;
            last;
        }
 
        chomp $id; 
    	$id = WebUtil::strTrim($id);
        next if ( $id eq "" );
        next if ( ! WebUtil::hasAlphanumericChar($id) );
 
        if ( isInt($id) ) { 
            push(@db_ids, $id);
        } 
    	else {
            push(@meta_ids, $id);
    	    my ($t2, $d2, $g2) = split(/ /, $id);
    	    my $key = "$t2 $d2";
            if ( $taxon_genes{$key} ) {
                my $oid_ref = $taxon_genes{$key};
                push( @$oid_ref, $g2 );
            }
            else {
                my @oid = ($g2);
                $taxon_genes{$key} = \@oid;
            }
            $gene2toid_href->{$id} = $t2;
    	}
        $row++; 
    } 
    close $res;
 
    if ( scalar(@db_ids) > 0 ) { 
    	if ( $print_msg ) {
    	    print "<p>Retrieving gene product names from database ... <br/>\n";
    	}

    	my $dbh = dbLogin();
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @db_ids );
    	
        my $rclause = WebUtil::urClause('t');
        my $imgClause = WebUtil::imgClause('t');

        my $sql = qq{
            select g.gene_oid, g.locus_tag, g.gene_display_name, g.taxon, t.in_file 
            from gene g, taxon t 
            where g.taxon = t.taxon_oid 
            and g.gene_oid in ( $oid_str )
            $rclause
            $imgClause
        }; 

        my $cur = execSql( $dbh, $sql, $verbose );
        my $k = 0;
        for ( ; ; ) {
            my ( $id2, $locus_tag, $name2, $t_oid, $t_in_file ) = $cur->fetchrow();
            last if !$id2;

            if ( ! $name2 ) {
                $name2 = "hypothetical protein";
            }
            if ( $t_in_file eq 'Yes' ) {
                $gene2toid_href->{$id2} = $t_oid;
            }
            else {
                $gene_name_href->{$id2} = $name2;
                $locus_tag_href->{$id2} = $locus_tag;
                $gene2toid_href->{$id2} = $t_oid;
            }
        } 
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oid_str =~ /gtt_num_id/i );

    } 

    if ( scalar(@meta_ids) > 0 ) { 

        if ( $print_msg ) {
            print "<p>Retrieving gene product names from file system ... <br/>\n";
        }
        MetaUtil::getAllMetaGeneNames( $gene2toid_href, \@meta_ids, $gene_name_href, \%taxon_genes, 1 );

        if ( $print_msg ) {
            print "<p>Retrieving gene info from file system ... <br/>\n";
        }
        my %gene_info_h;
        MetaUtil::getAllMetaGeneInfo( $gene2toid_href, \@meta_ids, \%gene_info_h, '', \%taxon_genes, 1 );
        #print "getGeneSetGeneNames() getAllGeneInfo() called " . currDateTime() . "<br/>\n";
        #print Dumper(\%gene_info_h);
        #print "<br/>\n";

        for my $id (@meta_ids) {
            my ( $taxon3, $type3, $id3 ) = split( / /, $id );
            if ( exists( $gene_info_h{$id} ) ) {
                my ( $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold_oid, $tid2, $dtype2 )
                  = split( /\t/, $gene_info_h{$id} );
                $locus_tag_href->{$id} = $locus_tag;
            } else {
                $locus_tag_href->{$id} = $id3;
            }
        }

    }

    print "<p>$trunc genes retrieved.<br/>\n";
    return $trunc;
}

############################################################################
# exportSelectedGeneFasta
############################################################################
sub exportSelectedGeneFasta {
    my $sid = getContactOid();
    if ( blankStr($sid) ) {
        main::printAppHeader("AnaCart");
        webError("Your login has expired.");
        return;
    }

    my @gene_oids = param("gene_oid");

    my $page = param("page");
    my $folder = $GENE_FOLDER;

    if ( scalar(@gene_oids) == 0 ) {
        webError("Select at least one gene to export.");
        return;
    }

    timeout( 60 * $merfs_timeout_mins ); 

#    print "Content-type: text/plain\n";
#    print "Content-Disposition: inline;filename=exportFasta\n";
#    print "\n";

    print "<h1>Gene Export</h1>\n"; 
    my $up_stream = param('up_stream');
    my $down_stream = param('down_stream');
    my $up_stream_int   = sprintf( "%d", $up_stream ); 
    my $down_stream_int = sprintf( "%d", $down_stream ); 
    $up_stream   =~ s/\s+//g; 
    $down_stream =~ s/\s+//g; 

    if ( $up_stream_int > 0 || !isInt($up_stream) ) {
        webError("Expected negative integer for up stream."); 
    } 
    if ( $down_stream_int < 0 || !isInt($down_stream) ) { 
        webError("Expected positive integer for down stream."); 
    } 
 
    print "<font color='red'>Red</font> = start or stop codon, "; 
    print "<font color='green'>Green</font> " 
	. "= upstream or downstream padding.<br>\n"; 

    print "<pre>\n";

    # process database scaffolds first
    my $dbh   = dbLogin();
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    
    my $count = 0;
    for my $key ( sort @gene_oids ) {
        $count++;
    	my @v = split(/ /, $key);
    	if ( scalar(@v) == 1 && isInt($key) ) {

            my ( $seq, $gene_oid, $nameLine, $locus_type, $taxon_oid, $ext_accession,
                 $start_coord, $end_coord, $start_coord0, $end_coord0, $strand, 
                 $coordLines_ref, $path )
                = SequenceExportUtil::getGeneDnaSequence( $dbh, $key, $up_stream, $down_stream );

            if ( $seq ) {
                print ">$gene_oid $nameLine ($strand)strand\n";
                my $seq2 = wrapSeq($seq);
                #print "$seq2\n";
                $seq2 =~ s/\n//g;
                SequenceExportUtil::colorSequence($seq2, $locus_type, $strand, $start_coord0, $end_coord0,
                          $start_coord, $end_coord, $coordLines_ref);
            }
             	    
        }
        else {
            # file
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $key );
            my @vals = MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );
            my $j = 0;
            if ( scalar(@vals) > 7 ) {
                $j = 1;
            }
            my $locus_type        = $vals[$j];
            my $gene_display_name = $vals[ $j + 2 ];
            my $start_coord0       = $vals[ $j + 3 ];
            my $end_coord0         = $vals[ $j + 4 ];
            my $strand            = $vals[ $j + 5 ];
            my $scaffold_oid      = $vals[ $j + 6 ];

    	    my $seq =
    		MetaUtil::getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );
    
    	    my $start_coord = $start_coord0 + $up_stream; 
    	    $start_coord = 1 if $start_coord < 1; 
    	    my $end_coord = $end_coord0 + $down_stream;
    	    if ( $strand eq "-" ) {
        		$start_coord = $start_coord0 - $down_stream; 
        		$end_coord   = $end_coord0 - $up_stream;
    	    } 
    
    	    if ( $start_coord < 1 ) {
        		$start_coord = 1;
    	    }
    	    if ( $end_coord < 0 ) {
        		$end_coord = $end_coord0;
    	    }
    
    	    my $gene_seq = "";
    	    if ( $strand eq '-' ) {
        		$gene_seq = WebUtil::getSequence( $seq, $end_coord, $start_coord );
    	    }
    	    else {
        		$gene_seq = WebUtil::getSequence( $seq, $start_coord, $end_coord );
    	    }
    
    	    if ( !$gene_display_name ) {
        		my ($new_name, $source) = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
        		$gene_display_name = $new_name;
    	    }
    	    print ">$gene_oid $gene_display_name [$scaffold_oid] ($strand)strand\n";
            my $seq2 = WebUtil::wrapSeq($gene_seq);
    	    # print "$seq2\n";
    	    $seq2 =~ s/\n//g;
    	    SequenceExportUtil::colorSequence($seq2, $locus_type, $strand, $start_coord0, $end_coord0,
    			  $start_coord, $end_coord);
        }
    }  # end for my key
    #$dbh->disconnect();

    print "</pre>\n";
    print end_form();

#    exit 0;
}


############################################################################
# exportSelectedGeneAA: Amino Acid
############################################################################
sub exportSelectedGeneAA {
    my $sid = getContactOid();
    if ( blankStr($sid) ) {
        main::printAppHeader("AnaCart");
        webError("Your login has expired.");
        return;
    }

    my @gene_oids = param("gene_oid");

    my $page = param("page");
    my $folder = $GENE_FOLDER;

    if ( scalar(@gene_oids) == 0 ) {
        webError("Select at least one gene to export.");
        return;
    }

    timeout( 60 * $merfs_timeout_mins ); 

    my $tmpFile = "$cgi_tmp_dir/geneCart$$.fna";
    my $wfh = newWriteFileHandle( $tmpFile, "exportFasta" );

    # process database scaffolds first
    my $dbh    = dbLogin();
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    
    my $count  = 0;
    my $db_ids = "";
    my $db_cnt = 0;
    for my $key ( sort @gene_oids ) {
        $count++;
    	my @v = split(/ /, $key);
    	if ( scalar(@v) == 1 && isInt($key) ) {
                # database
    	    if ($db_ids) {
        		$db_ids .= ", " . $key;
    	    }
    	    else {
        		$db_ids = $key;
    	    }
    	    $db_cnt++;
    
    	    if ( $db_cnt >= 1000 ) {
                SequenceExportUtil::execExportGeneAA($dbh, $wfh, $db_ids, $rclause, $imgClause);
        
        		$db_ids = "";
        		$db_cnt = 0;
    	    }
    	}
        else {
            # file
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $key );
            my $seq = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
            if ($seq) {
                my $seq2 = WebUtil::wrapSeq($seq);
                my ( $new_name, $source ) = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
                print $wfh ">$gene_oid $new_name\n";
                print $wfh "$seq2\n";
            }
        }
    }  # end for my key

    if ( $db_cnt > 0 && $db_ids ) {
         SequenceExportUtil::execExportGeneAA($dbh, $wfh, $db_ids, $rclause, $imgClause);

        $db_ids = "";
        $db_cnt = 0;
    }

    close $wfh;
    #$dbh->disconnect();

    # download
#    my $sz = fileSize($tmpFile);
#    print "Content-type: text/plain\n";
#    print "Content-Disposition: inline;filename=exportFasta\n";
#    print "Content-length: $sz\n";
#    print "\n";

    print "<pre>\n";

    my $rfh = newReadFileHandle( $tmpFile, "downloadAAFile" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "$s\n";
    }
    close $rfh;
    wunlink($tmpFile);

    print "</pre>\n";
    print end_form();

#    exit 0;
}

############################################################################
# viewGeneGenomes
############################################################################
sub viewGeneGenomes {
    my ($isSet) = @_;

    my $sid = getContactOid();
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
	   print "<p>*** time1: " . currDateTime() . "\n";
    }

    printMainForm();
    my $dbh = dbLogin();

    my $folder = param('directory');
    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder",   $folder ); 

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);
    if ( scalar(@all_files) == 0 ) {
        webError("No gene sets have been selected.");
        return;
    }

    my @genes    = param("gene_oid");

    my ($displayIds_ref, $db_oids_ref, $fs_oids_ref);
    if ($isSet) {
        ($displayIds_ref, $db_oids_ref, $fs_oids_ref) = WorkspaceUtil::catalogOidsFromFile2($sid, $workspace_dir, $GENE_FOLDER, @all_files);

        print "<h1>Genomes of Selected Gene Sets</h1>\n";
        WorkspaceUtil::printSelectedInfo2( $dbh, 'gene set', @all_files );
    }
    else {
        # individual genes
        if ( scalar(@genes) == 0 ) {
            webError("No genes are selected.");
            return;
        }

        ($displayIds_ref, $db_oids_ref, $fs_oids_ref) = WorkspaceUtil::catalogOids(@genes);

        print "<h1>Genomes of Selected Genes</h1>\n";
        WorkspaceUtil::printSelectedInfo( 'gene', @$displayIds_ref );
        
        my $y;
        for $y (@genes) {
            print hiddenVar( "gene_oid", $y );
        }
    }

    printStatusLine( "Loading ...", 1 ); 
    printStartWorkingDiv();
    print "<p>Retrieving genome information from database data ...<br/>\n";

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    
    my %taxon_info_h;

    if (scalar(@$db_oids_ref) > 0) { 
        my $db_oid_cnt        = 0;
        my $oid_list_str = "";
        for my $db_oid (@$db_oids_ref) {
            if ($db_oid_cnt) {
                $oid_list_str .= ", " . $db_oid;
            }
            else {
                $oid_list_str = $db_oid;
            }

            $db_oid_cnt++;
            if ( $db_oid_cnt >= 1000 ) {
                my $sql = QueryUtil::getGeneTaxonDataSql($oid_list_str, $rclause, $imgClause);
                QueryUtil::executeTaxonDataSql( $dbh, $sql, \%taxon_info_h);

                # clear
                $db_oid_cnt = 0;
                $oid_list_str = "";
            }
        }

        # last one
        if ( $db_oid_cnt > 0 ) {
            my $sql = QueryUtil::getGeneTaxonDataSql($oid_list_str, $rclause, $imgClause);
            QueryUtil::executeTaxonDataSql( $dbh, $sql, \%taxon_info_h);
        }
        #print "after db_oids: ".(keys %taxon_info_h). "<br/>\n";
    }

    # now process file genes
    if (scalar(@$fs_oids_ref) > 0) {        
        my %fs_taxons;
        for my $fs_gene_oid (@$fs_oids_ref) {
            # file
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $fs_gene_oid );
            $fs_taxons{$taxon_oid} = 1;
        }        
        my @metaTaxons = keys %fs_taxons;
        if ( scalar(@metaTaxons) > 0 ) {
            my $taxon_oid_list = OracleUtil::getNumberIdsInClause( $dbh, @metaTaxons );                
            my $sql = QueryUtil::getTaxonDataSql($taxon_oid_list, $rclause, $imgClause);
            QueryUtil::executeTaxonDataSql( $dbh, $sql, \%taxon_info_h);
            OracleUtil::truncTable( $dbh, "gtt_num_id" )
              if ( $taxon_oid_list =~ /gtt_num_id/i );
        }
        
    }
        
    #$dbh->disconnect();

    printEndWorkingDiv();

    my $select_id_name = "taxon_filter_oid";

    my $it = new InnerTable( 1, "geneTaxon$$", "geneTaxon", 1 ); 
    $it->addColSpec("Select"); 
    $it->addColSpec( "Domain", "char asc", "left" );
    $it->addColSpec( "Status",    "char asc", "left" );
    $it->addColSpec( "Genome ID", "number asc", "right" );
    $it->addColSpec( "Genome Name", "char asc", "left" );
    my $sd = $it->getSdDelim();

    my $taxon_cnt = 0;
    for my $taxon_oid (keys %taxon_info_h) {
    
    	my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
    	my $url = "$main_cgi?section=TaxonDetail"
    	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    
    	my ($domain, $seq_status, $taxon_name) = split(/\t/, $taxon_info_h{$taxon_oid});
    	$r .= $domain . $sd . $domain . "\t";
    	$r .= $seq_status . $sd . $seq_status . "\t";
        $r .= $taxon_oid . $sd . $taxon_oid . "\t";
    	$r .= $taxon_name . $sd . alink($url, $taxon_name) . "\t";
    
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
# viewGeneScaffolds
############################################################################
sub viewGeneScaffolds {
    my ($isSet) = @_;

    my $sid = getContactOid();
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
	   print "<p>*** time1: " . currDateTime() . "\n";
    }
        
    printMainForm();
    my $dbh = dbLogin();
    
    my $folder = param('directory');
    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder",   $folder ); 

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);
    if ( scalar(@all_files) == 0 ) {
        webError("No gene sets have been selected.");
        return;
    }

    my @genes = param("gene_oid");

    my ($displayIds_ref, $db_oids_ref, $fs_oids_ref);
    if ($isSet) {
        ($displayIds_ref, $db_oids_ref, $fs_oids_ref) = WorkspaceUtil::catalogOidsFromFile2($sid, $workspace_dir, $GENE_FOLDER, @all_files);

        print "<h1>Scaffolds of Selected Gene Sets</h1>\n";
        WorkspaceUtil::printSelectedInfo2( $dbh, 'gene set', @all_files );
    }
    else {
        # individual genes
        if ( scalar(@genes) == 0 ) {
            webError("No genes are selected.");
            return;
        }

        ($displayIds_ref, $db_oids_ref, $fs_oids_ref) = WorkspaceUtil::catalogOids(@genes);

        print "<h1>Scaffolds of Selected Genes</h1>\n";
        WorkspaceUtil::printSelectedInfo( 'gene', @$displayIds_ref );
        
        my $y;
        for $y (@genes) {
            print hiddenVar( "gene_oid", $y );
        }
    }

    printStatusLine( "Loading ...", 1 ); 
    printStartWorkingDiv();
    print "<p>Retrieving genome information from database data ...<br/>\n";

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my %taxon_name_h;
    my %scaf_name_h;
    if (scalar(@$db_oids_ref) > 0) {
        my $db_oid_cnt        = 0;
        my $oid_list_str = "";
        for my $db_oid (@$db_oids_ref) {
            if ($db_oid_cnt) {
                $oid_list_str .= ", " . $db_oid;
            }
            else {
                $oid_list_str = $db_oid;
            }

            $db_oid_cnt++;
            if ( $db_oid_cnt >= 1000 ) {
                my $sql = getGeneScaffoldSql($rclause, $imgClause, $oid_list_str);
                executeScaffoldDataSql( $dbh, $sql, \%taxon_name_h, \%scaf_name_h);

                # clear
                $db_oid_cnt = 0;
                $oid_list_str = "";
            }
        }

        # last one
        if ( $db_oid_cnt > 0 ) {
            my $sql = getGeneScaffoldSql($rclause, $imgClause, $oid_list_str);
            executeScaffoldDataSql( $dbh, $sql, \%taxon_name_h, \%scaf_name_h);
        }
        #print "after db_oids: ".keys(%scaf_name_h). "<br/>\n";
    }

    # now process file genes
    if (scalar(@$fs_oids_ref) > 0) {
        my %taxon_oid_h;
        for my $fs_gene_oid (@$fs_oids_ref) {
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $fs_gene_oid );
            $taxon_oid_h{$taxon_oid} = 1; 
        }
        my @taxonOids = keys(%taxon_oid_h);
        my %meta_taxon_name_h = QueryUtil::fetchTaxonOid2NameHash($dbh, \@taxonOids);    
        for my $key (keys(%meta_taxon_name_h)) {
            $taxon_name_h{$key} = $meta_taxon_name_h{$key};
        }
                
        for my $fs_gene_oid (@$fs_oids_ref) {
            # file
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $fs_gene_oid );
            
    	    if ( $data_type eq 'unassembled' ) {
    		    next;
    	    }

            my $taxon_name = $taxon_name_h{$taxon_oid};
            if ($taxon_name) {
                my ($gene_oid2, $locus_type, $locus_tag, $gene_display_name,
    		        $start_coord, $end_coord, $strand, $scaf_name) 
    		        = MetaUtil::getGeneInfo($gene_oid, $taxon_oid, $data_type);
                
                my $ws_scaf_id = "$taxon_oid $data_type $scaf_name";
                $scaf_name_h{$ws_scaf_id} = "$scaf_name\t$taxon_oid\t$taxon_name";
                #print "scaf_name_h added with $ws_scaf_id<br/>\n";
            }
        }
        
    }
    #$dbh->disconnect();

    printEndWorkingDiv();

    my $select_id_name = "scaffold_oid";

    my $it = new InnerTable( 1, "geneTaxon$$", "geneTaxon", 1 ); 
    $it->addColSpec("Select"); 
    $it->addColSpec( "Scaffold ID", "char asc", "left" );
    $it->addColSpec( "Scaffold Name", "char asc", "left" );
    $it->addColSpec( "Genome ID", "number asc", "right" );
    $it->addColSpec( "Genome Name", "char asc", "left" );
    my $sd = $it->getSdDelim();

    my $scaf_cnt = 0;
    for my $scaffold_oid (keys %scaf_name_h) {
    	my ($scaf_name, $taxon_oid, $taxon_name) = split(/\t/, $scaf_name_h{$scaffold_oid});
    
    	my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$scaffold_oid' /> \t";
    	my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    
    	if ( isInt($scaffold_oid) ) {
    	    my $s_url = "$main_cgi?section=ScaffoldCart&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
    	    $r .= $scaffold_oid . $sd . alink($s_url, $scaffold_oid) . "\t";
    	}
    	else { 
    	    my ($t2, $d2, $s2) = split(/ /, $scaffold_oid);
    	    my $s_url = "$main_cgi?section=MetaDetail&page=metaScaffoldDetail&scaffold_oid=$s2&taxon_oid=$t2&data_type=$d2";
     	    $r .= $scaffold_oid . $sd . alink($s_url, $s2) . "\t";
    	} 
     
    	$r .= $scaf_name . $sd . $scaf_name . "\t";

        $r .= $taxon_oid . $sd . $taxon_oid . "\t";
    	$r .= $taxon_name . $sd . alink($url, $taxon_name) . "\t";
    
    	$it->addRow($r);
    	$scaf_cnt++;
    }

    printStatusLine( "$scaf_cnt scaffold(s) loaded", 2 ); 

    if ( !$scaf_cnt ) {
    	print "<p>No scaffolds.\n";
    	print end_form();
    	return;
    }

    $it->printOuterTable(1);

    print "<p>\n";
	WebUtil::printScaffoldCartFooter();
    print "<p>\n";

    if ( $scaf_cnt > 0 ) {
        WorkspaceUtil::printSaveScaffoldToWorkspace($select_id_name);
    }

    print end_form();
    return;
}

sub getGeneScaffoldSql {
    my ($rclause, $imgClause, $oid_list_str) = @_;
	
    my $sql = qq{
        select distinct s.scaffold_oid, s.scaffold_name, g.taxon, t.taxon_display_name 
	    from gene g, scaffold s, taxon t
	    where g.gene_oid in ($oid_list_str) 
	    and g.scaffold = s.scaffold_oid 
	    and g.taxon = t.taxon_oid 
        $rclause
        $imgClause
    };
    
    return $sql;
}

sub executeScaffoldDataSql {
    my ( $dbh, $sql, $taxon_name_h_ref, $scaf_name_h_ref) = @_;
    
    #print "executeScaffoldDataSql sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($scaf_oid, $scaf_name, $taxon_oid, $taxon_name) = $cur->fetchrow();
        last if ( !$scaf_oid );
        #print "scaf_oid: $scaf_oid, taxon_oid: $taxon_oid<br/>\n";
        
        $taxon_name_h_ref->{$taxon_oid} = $taxon_name;
        $scaf_name_h_ref->{$scaf_oid} = "$scaf_name\t$taxon_oid\t$taxon_name";
        #print "scaf_name_h added with $scaf_oid<br/>\n";
    }
    $cur->finish();
}

#############################################################################
# showGeneFuncCateProfile - show workspace function profile for selected files
#                       and function type
#############################################################################
sub showGeneFuncCateProfile {
    my ($isSet) = @_;

    my $sid = getContactOid();

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    my $dbh = dbLogin();

    my $folder    = param("directory");
    print hiddenVar( "directory", "$folder" );
    
    my $functype  = param('functype');

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);

    # genes
    my $fileFullname = param('filename');
    #print "fileFullname $fileFullname<br/>\n";
    my @gene_oids = param('gene_oid');
    for my $gene_oid ( @gene_oids ) {
        print hiddenVar("gene_oid", $gene_oid);
    }

    my $data_type = param('data_type');
    print hiddenVar( "data_type", $data_type ) if ($data_type);

    if ( $isSet ) {
        validateGeneSelection( $isSet, @all_files );
        print "<h1>Gene Set Function Profile ($functype)</h1>\n";
        print
"<p>Profile is based on gene set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected gene set(s): ";
    	WorkspaceUtil::printShareSetName($dbh, $sid, @all_files);
        print "<br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }
    else {
        validateGeneSelection( $isSet, @gene_oids );
        print "<h1>Gene Function Profile ($functype)</h1>\n";
        print
"<p>Profile is based on individual gene(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected gene(s): <i>@gene_oids</i><br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }

    timeout( 60 * $merfs_timeout_mins );
    my $start_time  = time();
    my $timeout_msg = "";

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    print "Retrieving function names ...<br/>\n";
    my %func_names;
    if ( Workspace::isSimpleFuncType($functype) ) {
        %func_names = QueryUtil::getFuncTypeNames($dbh, $functype);
    }

    my %func_cate_h;
    my %kegg_cate_h;

    print "<p>functype: $functype\n";
    if ( Workspace::isComplicatedFuncCategory($functype) ) {
        my $sql = getFuncSql($functype);
        #print "<p>showGeneFuncCateProfile() SQL: $sql\n";
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $cate_id, $cate_name, $f_id ) = $cur->fetchrow();
            last if !$cate_id;
            #print "<p>showGeneFuncCateProfile() cate_id=$cate_id, cate_name=$cate_name, f_id=$f_id\n";

            if ( !$func_names{$cate_id} ) {
                $func_names{$cate_id} = $cate_name;
            }

            if (   $functype eq 'KEGG_Category_EC'
                || $functype eq 'KEGG_Category_KO' )
            {
                if ( $cate_name && $cate_id && !$kegg_cate_h{$cate_name} ) {
                    $kegg_cate_h{$cate_name} = $cate_id;
                }
            }

            my $cate_ids_ref = $func_cate_h{$f_id};
            if ( $cate_ids_ref ) {
                push(@$cate_ids_ref, $cate_id);
            }
            else {
                my @cate_ids = ( $cate_id );
                $func_cate_h{$f_id} = \@cate_ids;
            }
        }
        $cur->finish();
    }

    my %funcId2geneOrset2cnt_h;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    if ($isSet) {
        for my $x2 (@all_files) {
    	    my ($c_id, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );

            if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 )
            {
                $timeout_msg =
                    "Process takes too long to run "
                  . "-- stopped at $x. "
                  . "Only partial result is displayed.";
                last;
            }
                
            print "Pre-processing workspace file $x2 ...<br/>\n";
            open( FH, "$workspace_dir/$c_id/$folder/$x" )
              or webError("File size - file error $x2");

            my @db_gene_oids;
            my @meta_gene_oids;
            my %taxon_dataype;
            my %metaGene_func_list;
            while ( my $line = <FH> ) {
                chomp($line);
                if ( isInt($line) ) {
                    push (@db_gene_oids, $line);
                } else {
                    my ( $taxon_oid, $d2, $g2 ) = split( / /, $line );
                    if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
                        && ($d2 ne $data_type) ) {
                            next;
                    }
                    push (@meta_gene_oids, $line);
                    $metaGene_func_list{$line} = ""; 
                    my $key = "$taxon_oid $d2";
                    if ( $taxon_dataype{$key} ) {
                        my $h_ref = $taxon_dataype{$key};
                        $h_ref->{$g2} = 1;
                    } else {
                        my %hash2;
                        $hash2{$g2} = 1;
                        $taxon_dataype{$key}  = \%hash2;
                    }
                }
            }    # end while FH

            my %func2cnt_h;

            if ( scalar(@db_gene_oids) > 0 ) {
                fetchFunc2CntForDbGenes( $dbh, $rclause, $imgClause,
                    $functype, \@db_gene_oids, \%func2cnt_h );
            }

            if ( scalar(@meta_gene_oids) > 0 ) {
                if ( scalar( keys %taxon_dataype) > 0 ) {
                    fetchFuncsForMetaGenes( $dbh, $functype, \%func_cate_h, \%taxon_dataype, \%metaGene_func_list );                
                }
                for my $line (@meta_gene_oids) {
                    if ( $metaGene_func_list{$line} ) {
                        # gene has this function
                        my $func_key_href = $metaGene_func_list{$line};
                        my @funcs = sort( keys %$func_key_href );
                        for my $func_id ( @funcs ) {
                            if ( $func2cnt_h{$func_id} ) {
                                $func2cnt_h{$func_id} += 1;
                            }
                            else {
                                $func2cnt_h{$func_id} = 1;                            
                            }
                        }
                    }
                }
            }    

            for my $func_id ( keys %func2cnt_h ) {
                my $cnt = $func2cnt_h{$func_id};
                if ( $funcId2geneOrset2cnt_h{$func_id} ) {
                    my $gene_hash_h = $funcId2geneOrset2cnt_h{$func_id};
                    $gene_hash_h->{$x2} = $cnt;
                }
                else {
                    my %gene_hash;
                    $gene_hash{$x2} = $cnt;
                    $funcId2geneOrset2cnt_h{$func_id} = \%gene_hash;
                }
            }

        }    #end for x2
    }
    else {
        
        my @db_gene_oids;
        my @meta_gene_oids;
        my %taxon_dataype;
        my %metaGene_func_list;
        for my $gene_oid (@gene_oids) {
            if ( isInt($gene_oid) ) {
                push(@db_gene_oids, $gene_oid );
                next;
            }
    
            my ($taxon_oid, $d2, $g2) = split(/ /, $gene_oid);
            if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
                && ($d2 ne $data_type) ) {
                    next;
            }    
            push (@meta_gene_oids, $gene_oid);
            $metaGene_func_list{$gene_oid} = ""; 
            my $key = "$taxon_oid $d2";
            if ( $taxon_dataype{$key} ) {
                my $h_ref = $taxon_dataype{$key};
                $h_ref->{$g2} = 1;
            } else {
                my %hash2;
                $hash2{$g2} = 1;
                $taxon_dataype{$key}  = \%hash2;
            }
        }

        # query database
        if ( scalar(@db_gene_oids) > 0 ) {
            fetchFuncsForDbGenes( $dbh, $rclause, $imgClause,
                $functype, \@db_gene_oids, \%funcId2geneOrset2cnt_h );
        }

        # MER-FS genes
        if ( scalar(@meta_gene_oids) > 0 ) {

            #for my $gene_oid (@meta_gene_oids) {
            #    my ($taxon_oid, $d2, $g2) = split(/ /, $gene_oid);
            #
            #    my @g_func = ();
            #    if ( $functype =~ /COG/i ) {
            #        @g_func = MetaUtil::getGeneCogId($g2, $taxon_oid, $d2);
            #    }
            #    elsif ( $functype =~ /Pfam/i ) {
            #        @g_func = MetaUtil::getGenePfamId($g2, $taxon_oid, $d2);
            #    }
            #    elsif ( $functype =~ /TIGR/i ) {
            #        @g_func = MetaUtil::getGeneTIGRfamId($g2, $taxon_oid, $d2);
            #    }
            #    elsif ( $functype =~ /KO/i ) {
            #        @g_func = MetaUtil::getGeneKoId($g2, $taxon_oid, $d2);
            #    }
            #    elsif ( $functype =~ /EC/i || $functype =~ /Enzyme/i ) {
            #        @g_func = MetaUtil::getGeneEc($g2, $taxon_oid, $d2);
            #    }
            #        
            #    if ( $functype eq 'COG_Category' ||
            #         $functype eq 'COG_Pathway' ||
            #         $functype eq 'KEGG_Category_EC' ||
            #         $functype eq 'KEGG_Category_KO' || 
            #         $functype eq 'KEGG_Pathway_EC' || 
            #         $functype eq 'KEGG_Pathway_KO' || 
            #         $functype eq 'Pfam_Category' || 
            #         $functype eq 'TIGRfam_Role' ) { 
            #        for my $f_id (@g_func) {
            #            my @cate_funcs = split(/ /, $func_cate_h{$f_id});
            #            for my $func_id ( @cate_funcs ) {
            #                if ( $funcId2geneOrset2cnt_h{$func_id} ) {
            #                    my $genes_href = $funcId2geneOrset2cnt_h{$func_id};
            #                    $genes_href->{$gene_oid} += 1;
            #                }
            #                else {
            #                    my %gene_hash;
            #                    $gene_hash{$gene_oid} = 1;
            #                    $funcId2geneOrset2cnt_h{$func_id} = \%gene_hash;
            #                }
            #            }
            #        }
            #    }
            #    else {
            #        for my $func_id ( @g_func ) {
            #            if ( $funcId2geneOrset2cnt_h{$func_id} ) {
            #                my $genes_href = $funcId2geneOrset2cnt_h{$func_id};
            #                $genes_href->{$gene_oid} = 1;
            #            }
            #            else {
            #                my %gene_hash;
            #                $gene_hash{$gene_oid} = 1;
            #                $funcId2geneOrset2cnt_h{$func_id} = \%gene_hash;
            #            }
            #        }
            #    }
            #}

            if ( scalar( keys %taxon_dataype) > 0 ) {
                fetchFuncsForMetaGenes( $functype, \%func_cate_h, \%taxon_dataype, \%metaGene_func_list );                
            }
            for my $gene_oid (@meta_gene_oids) {
                if ( $metaGene_func_list{$gene_oid} ) {
                    # gene has this function
                    my $func_key_href = $metaGene_func_list{$gene_oid};
                    my @funcs = sort( keys %$func_key_href );
                    for my $func_id ( @funcs ) {
                        if ( $funcId2geneOrset2cnt_h{$func_id} ) {
                            my $gene_hash_h = $funcId2geneOrset2cnt_h{$func_id};
                            $gene_hash_h->{$gene_oid} = 1;
                        }
                        else {
                            my %gene_hash;
                            $gene_hash{$gene_oid} = 1;
                            $funcId2geneOrset2cnt_h{$func_id} = \%gene_hash;
                        }
                    }
                }
            }
        }    
        #end for gene_oid
        
    }
    #print "showGeneSetFuncCateProfile() funcId2geneOrset2cnt_h:\n";
    #print Dumper(\%funcId2geneOrset2cnt_h);
    #print "<br/>\n";

    printEndWorkingDiv();


    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    my @func_ids = keys %funcId2geneOrset2cnt_h;
    #print "showGeneSetFuncCateProfile() func_ids=@func_ids<br/>\n";
    if ( scalar(@func_ids) == 0 ) {
        print "<p><b>No genes are associated with selected function type.</b>\n";
        print end_form();
        return;
    }

    if ($timeout_msg) {
        printMessage("<font color='red'>Warning: $timeout_msg</font>");
    }

    my $it = new InnerTable( 1, "WSFuncProfile$$", "WSFuncProfile", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    if ( Workspace::isSimpleFuncType($functype) ) {
        $it->addColSpec("Select");
    }
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
    }
    else {
        if ( scalar(@gene_oids) > 0 ) {
            for my $gene_oid (@gene_oids) {
                my $col_name = join("<br/>", split(/ /, $gene_oid));
                $it->addColSpec( $col_name, "number asc", "right");
            }
        }
    }

    my $has_data = 0;
    my $row_cnt = 0;
    for my $k ( sort(@func_ids) ) {
        my $geneOrset2cnt_href = $funcId2geneOrset2cnt_h{$k};
        
        my $new_k = $k;
        if ( Workspace::isComplicatedFuncCategory($functype) ) {
            $new_k = $functype . ":" . $k;
        }

        my $r;
        if ( Workspace::isSimpleFuncType($functype) ) {
            $r =
              $sd . "<input type='checkbox' name='func_id' value='$new_k' /> \t";
        }
        $r .= $k . $sd . $k . "\t";
        if ( $func_names{$k} ) {
            $r .= $func_names{$k} . $sd . $func_names{$k} . "\t";
        }
        else {
            $r .= $k . $sd . $k . "\t";
        }

        if ($isSet) {
            # genome sets
            for my $x2 (@all_files) {
                my $cnt = $geneOrset2cnt_href->{$x2};
                if ( $cnt ) {
                    my $url =
                        "$section_cgi&page=profileGeneList"
                      . "&input_file=$x2&func_id=$new_k";
                    $url .= "&data_type=$data_type" if ( $data_type );
                    $url = alink( $url, $cnt );
                    $r .= $cnt . $sd . $url . "\t";
                    $has_data = 1;
                }
                else {
                    $r .= "0" . $sd . "0\t";
                }
            }
        }
        else {
            for my $gene_oid (@gene_oids) {
                my $cnt = $geneOrset2cnt_href->{$gene_oid};
                if ( $cnt ) {
                    my $url = "";
                    if ( isInt($gene_oid) ) {
                        $url = "$main_cgi?section=GeneDetail"
                        . "&page=geneDetail&gene_oid=$gene_oid";
                    }
                    else {
                        my ($taxon_oid, $d2, $g2) = split(/ /, $gene_oid);
                        $url = "$main_cgi?section=MetaGeneDetail"
                        . "&page=metaGeneDetail&taxon_oid=$taxon_oid" 
                        . "&data_type=$d2&gene_oid=$g2";
                    } 
                    $url .= "&input_file=$fileFullname" if ( $fileFullname );
                    $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";
                    $has_data = 1;
                }
                else {
                    $r .= "0" . $sd . "0\t";
                }
            } # end for my gene_oid
        }

        $it->addRow($r);
        $row_cnt++;
    }

    if ( Workspace::isSimpleFuncType($functype) ) {
        if ( $has_data && $row_cnt > 10 ) {
            WebUtil::printFuncCartFooter();
        }
    }
    $it->printOuterTable(1);
    if ( Workspace::isSimpleFuncType($functype) ) {
        WebUtil::printFuncCartFooter();
    }

    if ( Workspace::isSimpleFuncType($functype) ) {
        WorkspaceUtil::printFuncGeneSaveToWorkspace();
    }
    elsif ( Workspace::isComplicatedFuncCategory($functype) ) {
        WorkspaceUtil::printExtFuncGeneSaveToWorkspace();
    }

    print end_form();
}

#############################################################################
# validateGeneSelection
#############################################################################
sub validateGeneSelection {
    my ( $isSet, @geneCols ) = @_;

    my $geneDescription;
    if ( $isSet ) {
        $geneDescription = "gene sets";
    }
    else {
        $geneDescription = "genes";            
    }
    if ( scalar( @geneCols ) == 0 ) {
        webError("No $geneDescription are selected.");
        return;
    }
    if ( scalar( @geneCols ) > $max_profile_select ) {
        webError("Please limit your selection of $geneDescription to no more than $max_profile_select.\n");
        return;
    }

}

sub getFuncSql {
    my ($functype) = @_;

	my $sql = "select f.function_code, f.definition, cf.cog_id from cog_function f, cog_functions cf where f.function_code = cf.functions";

	if ( $functype eq 'COG_Pathway' ) {
	    $sql = "select cp.cog_pathway_oid, cp.cog_pathway_name, cpcm.cog_members from cog_pathway cp, cog_pathway_cog_members cpcm where cp.cog_pathway_oid = cpcm.cog_pathway_oid";
	}
	elsif ( $functype eq 'Pfam_Category' ) {
	    $sql = "select distinct cf.function_code, cf.definition, pfc.ext_accession " .
		"from cog_function cf, pfam_family_cogs pfc " .
		"where cf.function_code = pfc.functions ";
	}
	elsif ( $functype eq 'KEGG_Category_EC' ) {
	    $sql = qq{
            select distinct kp3.min_pid, kp.category, kt.enzymes
            from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp, 
            (select kp2.category category, min(kp2.pathway_oid) min_pid
             from kegg_pathway kp2
             where kp2.category is not null
             group by kp2.category) kp3
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id 
            and ir.pathway = kp.pathway_oid
            and kp.category is not null
            and kp.category = kp3.category
        };
	}
	elsif ( $functype eq 'KEGG_Category_KO' ) {
	    $sql = qq{
            select distinct kp3.min_pid, kp.category, rk.ko_terms
            from kegg_pathway kp, image_roi_ko_terms rk, image_roi ir,
            (select kp2.category category, min(kp2.pathway_oid) min_pid
             from kegg_pathway kp2
             where kp2.category is not null
             group by kp2.category) kp3
            where rk.roi_id = ir.roi_id 
            and kp.pathway_oid = ir.pathway 
            and kp.category is not null
            and kp.category = kp3.category
        };
	}
	elsif ( $functype eq 'KEGG_Pathway_EC' ) {
        $sql = qq{
            select distinct kp.pathway_oid, kp.pathway_name, kt.enzymes 
            from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp
            where kt.ko_id = rk.ko_terms 
            and rk.roi_id = ir.roi_id 
            and ir.pathway = kp.pathway_oid
        };
	}
	elsif ( $functype eq 'KEGG_Pathway_KO' ) {
        $sql = qq{
            select distinct kp.pathway_oid, kp.pathway_name, rk.ko_terms 
            from kegg_pathway kp, image_roi_ko_terms rk, image_roi ir 
            where rk.roi_id = ir.roi_id 
            and kp.pathway_oid = ir.pathway
        };
	}
	elsif ( $functype eq 'TIGRfam_Role' ) {
        $sql = qq{
            select distinct t.role_id, t.main_role || ': ' || t.sub_role, tr.ext_accession
            from tigr_role t, tigrfam_roles tr
            where tr.roles = t.role_id and t.sub_role is not null 
            and t.sub_role != 'Other'
        };
	}

    return $sql;
}

sub fetchFuncsForDbGenes {
    my ($dbh, $rclause, $imgClause, $functype, $db_gene_oids_ref, $funcId2geneOrset2cnt_href) = @_;

    my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_gene_oids_ref );    
    my $sql = WorkspaceQueryUtil::getDbGeneFuncSql($functype, $oid_str, $rclause, $imgClause);
    #print "fetchFuncsForDbGenes() sql=$sql<br/>\n";
    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $func_id ) = $cur->fetchrow();
            last if ( !$gene_oid );
            print "fetchFuncsForDbGenes() gene_oid=$gene_oid, func_id=$func_id<br/>\n";
    
            if ( $gene_oid && $func_id ) {
                if ( $funcId2geneOrset2cnt_href->{$func_id} ) {
                    my $gene_hash_href = $funcId2geneOrset2cnt_href->{$func_id};
                    $gene_hash_href->{$gene_oid} = 1;
                }
                else {
                    my %gene_hash;
                    $gene_hash{$gene_oid} = 1;
                    $funcId2geneOrset2cnt_href->{$func_id} = \%gene_hash;
                }
            }
        }
        $cur->finish();
    }

}


sub fetchFunc2CntForDbGenes {
    my ($dbh, $rclause, $imgClause, $functype, $db_gene_oids_ref, $func2cnt_href) = @_;

    my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_gene_oids_ref );    
    my $sql = WorkspaceQueryUtil::getDbGeneFuncSql($functype, $oid_str, $rclause, $imgClause);
    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $func_id ) = $cur->fetchrow();
            last if ( !$gene_oid );

            if ( $gene_oid && $func_id ) {
                if ( !( defined $func2cnt_href->{$func_id} ) ) {
                    $func2cnt_href->{$func_id} = 0;
                }
                $func2cnt_href->{$func_id} += 1;
            }
        }
        $cur->finish();
    }
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $oid_str =~ /gtt_num_id/i );

}

sub fetchFuncsForMetaGenes {
    my ( $dbh, $functype, $func_cate_href, $taxon_datatype_href, $metaGene2funcs_href ) = @_;

    my $func_tag = MetaUtil::getFuncTagFromFuncType( $functype );
    if ( !$func_tag ) {
        print "<p>Unknown function type $functype\n";
        return;
    }

    # walk through taxon_dataype files
    for my $key (keys %$taxon_datatype_href) {
                
        my ( $taxon_oid, $t2 ) = split( / /, $key );
        $taxon_oid = sanitizeInt($taxon_oid);

        my $genes_href = $taxon_datatype_href->{$key};
        if ( !$genes_href ) {
            print "<p>no genes in taxon_dataype $key\n";
            next;
        }

        #use limiting genes to save time
        my %func_genes  = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, $func_tag, '', $genes_href );
        #my %func_genes  = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, $func_tag );
        if ( scalar( keys %func_genes ) > 0 ) {            
            print "Retrieving all functions ...<br/>\n";
            my @func_keys;
            if (   $functype eq 'COG_Category'
                || $functype eq 'COG_Pathway'
                || $functype eq 'Pfam_Category'
                || $functype eq 'KEGG_Category_EC'
                || $functype eq 'KEGG_Category_KO'
                || $functype eq 'KEGG_Pathway_EC'
                || $functype eq 'KEGG_Pathway_KO'
                || $functype eq 'TIGRfam_Role' )
            {
                @func_keys = ( keys %$func_cate_href );
            }
            else {
                @func_keys = Workspace::getAllFuncIds($dbh, $functype);
            }

            print "Retrieving function-genes ...<br/>\n";
            for my $k (@func_keys) {
                my @recs = split( /\t/, $func_genes{$k} );
                for my $gene_id (@recs) {
                    my $id3   = "$taxon_oid $t2 $gene_id";
                    my @new_k_array = ( $k );
                    if (   $functype eq 'COG_Category'
                        || $functype eq 'COG_Pathway'
                        || $functype eq 'Pfam_Category'
                        || $functype eq 'KEGG_Category_EC'
                        || $functype eq 'KEGG_Category_KO'
                        || $functype eq 'KEGG_Pathway_EC'
                        || $functype eq 'KEGG_Pathway_KO'
                        || $functype eq 'TIGRfam_Role' )
                    {
                        my $new_k_ref = $func_cate_href->{$k};
                        @new_k_array = @$new_k_ref;
                    }

                    if ( $metaGene2funcs_href && scalar(@new_k_array) > 0 ) {
                        for my $new_k ( @new_k_array ) {
                            if ( $metaGene2funcs_href->{$id3} ) {
                                my $func_key_href = $metaGene2funcs_href->{$id3};
                                $func_key_href->{$new_k} = 1;
                            }
                            else {
                                my %func_key_h;
                                $func_key_h{$new_k} = 1;
                                $metaGene2funcs_href->{$id3} = \%func_key_h;
                            }
                        }                        
                    }
                }
            }
        }
        else {
            # no longer use .zip file
            next;

            my $zip_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2;
            if ( $functype =~ /COG/i ) {
                $zip_name .= "/cog_genes.zip";
            }
            elsif ( $functype =~ /Pfam/i ) {
                $zip_name .= "/pfam_genes.zip";
            }
            elsif ( $functype =~ /TIGRfam/i ) {
                $zip_name .= "/tigr_genes.zip";
            }
            elsif ( $functype =~ /KO/i ) {
                $zip_name .= "/ko_genes.zip";
            }
            elsif ( $functype eq 'Enzymes' || $functype =~ /EC/i ) {
                $zip_name .= "/ec_genes.zip";
            }
            else {
                print "<p>Unknown function type $functype\n";
                return;
            }

            # use zip
            print "Walking through data file $zip_name ...<br/>\n";

            WebUtil::unsetEnvPath();
            my $fh1 =
              newCmdFileHandle( "/usr/bin/unzip -l $zip_name", 'FuncList' );
            if ( !$fh1 ) {
                WebUtil::resetEnvPath();
                next;
            }
            my $line_cnt  = 0;
            my @func_list = ();
            while ( my $line1 = $fh1->getline() ) {
                chomp($line1);
                if ( $functype =~ /COG/i ) {
                    if ( $line1 =~ /(COG[0-9]+)/ ) {
                        push @func_list, ($1);
                    }
                }
                elsif ( $functype =~ /Pfam/i ) {
                    if ( $line1 =~ /(pfam[0-9]+)/ ) {
                        push @func_list, ($1);
                    }
                }
                elsif ( $functype =~ /TIGRfam/i ) {
                    if ( $line1 =~ /(TIGR[0-9]+)/ ) {
                        push @func_list, ($1);
                    }
                }
                elsif ( $functype =~ /KO/i ) {
                    if ( $line1 =~ /(KO\:K[0-9]+)/ ) {
                        push @func_list, ($1);
                    }
                }
                elsif ( $functype eq 'Enzymes' || $functype =~ /EC/i ) {
                    if ( $line1 =~ /(EC\:[0-9\.\-]+)/ ) {
                        push @func_list, ($1);
                    }
                }
            }

            close $fh1;
            WebUtil::resetEnvPath();

            my $zip = Archive::Zip->new();
            $zip->read($zip_name);
            my @members = $zip->members();

            my $m_count = 0;
            for my $m (@members) {
                my $id1 = "";
                if ( $m_count < scalar(@func_list) ) {
                    $id1 = $func_list[$m_count];
                }
                $m_count++;

                my @lines = split( /\n/, $m->contents() );
                for my $line (@lines) {
                    my $id3 = $taxon_oid . ' ' . $t2 . ' ' . $line;
                    my @new_ids = ( $id1 );
                    if (   $functype eq 'COG_Category'
                        || $functype eq 'COG_Pathway'
                        || $functype eq 'Pfam_Category'
                        || $functype eq 'KEGG_Category_EC'
                        || $functype eq 'KEGG_Category_KO'
                        || $functype eq 'KEGG_Pathway_EC'
                        || $functype eq 'KEGG_Pathway_KO'
                        || $functype eq 'TIGRfam_Role' )
                    {
                        my $new_ids_ref = $func_cate_href->{$id1};
                        @new_ids = @$new_ids_ref;
                    }

                    if ( $metaGene2funcs_href && scalar(@new_ids) > 0 ) {
                        for my $new_id1 ( @new_ids ) {
                            if ( $metaGene2funcs_href->{$id3} ) {
                                my $func_key_href = $metaGene2funcs_href->{$id3};
                                $func_key_href->{$new_id1} = 1;
                            }
                            else {
                                my %func_key_h;
                                $func_key_h{$new_id1} = 1;
                                $metaGene2funcs_href->{$id3} = \%func_key_h;
                            }
                        }
                    }
                }    # end for line
            }    #end for m
        }    # end zip
    }    # end for z

}

#############################################################################
# showGeneFuncSetProfile - show workspace function profile for selected files
#                       and function set
#############################################################################
sub showGeneFuncSetProfile {
    my ($isSet) = @_;

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    my $dbh = dbLogin();

    my $sid = getContactOid();
    my $folder = param("directory");
    print hiddenVar( "directory", "$folder" );

    my $func_set_name = param('func_set_name');
    # read all function ids in the function set
    if ( ! $func_set_name ) {
        webError("Please select a function set.\n");
        return;
    }
    my ( $func_set_owner, $func_set ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $func_set_name, $ownerFilesetDelim, $FUNC_FOLDER );
    my $share_func_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $func_set_owner, $func_set, $sid );

    WebUtil::checkFileName($func_set);
    # this also untaints the name
    my $func_filename = WebUtil::validFileName($func_set);

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);

    # genes
    #my $fileFullname = param('filename');
    #print "fileFullname $fileFullname<br/>\n";
    my @gene_oids = param('gene_oid');
    for my $gene_oid (@gene_oids) {
        print hiddenVar('gene_oid', $gene_oid);
    }

    my $data_type = param('data_type');
    print hiddenVar( "data_type", $data_type ) if ($data_type);

    if ( $isSet ) {
        validateGeneSelection( $isSet, @all_files );
        print "<h1>Gene Set Function Profile ($share_func_set_name)</h1>\n";
        print
"<p>Profile is based on gene set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected gene set(s): ";
        WorkspaceUtil::printShareSetName($dbh, $sid, @all_files);
        print "<br/>\n"; 
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }
    else {
        validateGeneSelection( $isSet, @gene_oids );
        print "<h1>Gene Function Profile ($share_func_set_name)</h1>\n";
        print
"<p>Profile is based on individual genes in gene set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected gene(s): <i>@gene_oids</i><br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }

    timeout( 60 * $merfs_timeout_mins ); 
    my $start_time = time();
    my $timeout_msg = ""; 

    if ( $sid == 312 || $sid == 100546 ) {
        print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }

    printStartWorkingDiv();

    print "Retrieving function names ... <br/>\n";
    my @func_ids;
    my $res = newReadFileHandle("$workspace_dir/$func_set_owner/$FUNC_FOLDER/$func_filename");
    while ( my $id = $res->getline() ) {
        chomp $id;
        next if ( $id eq "" );
        push @func_ids, ($id);
    }
    close $res;

    my %func_names = QueryUtil::fetchFuncIdAndName( $dbh, \@func_ids );

    print "Computing function counts ... <br/>\n";
    my %geneOrset_cnt_h;
    my @func_groups = QueryUtil::groupFuncIdsIntoOneArray( \@func_ids );
    foreach my $func_ids_ref (@func_groups) {
        if ($isSet) {
            # gene sets
            for my $x2 (@all_files) { 
                my($c_id, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 ); 
                my $fullname = "$workspace_dir/$c_id/$folder/$x";
                my %func2count_h = getGeneFuncSetCount( $dbh, $func_ids_ref, $fullname, '', $data_type );
                my $geneOrset_func2count_href = $geneOrset_cnt_h{$x2};
                if ( $geneOrset_func2count_href ) {
                    foreach my $func_id ( keys %func2count_h ) {
                        $geneOrset_func2count_href->{$func_id} = $func2count_h{$func_id};
                    }
                }
                else {
                    $geneOrset_cnt_h{$x2} = \%func2count_h;                    
                }
            }
        }
        else {
            # genes
            for my $gene_oid (@gene_oids) {
                my %func2count_h = getGeneFuncSetCount( $dbh, $func_ids_ref, '', $gene_oid, $data_type );
                my $geneOrset_func2count_href = $geneOrset_cnt_h{$gene_oid};
                if ( $geneOrset_func2count_href ) {
                    foreach my $func_id ( keys %func2count_h ) {
                        $geneOrset_func2count_href->{$func_id} = $func2count_h{$func_id};
                    }
                }
                else {
                    $geneOrset_cnt_h{$gene_oid} = \%func2count_h;
                }
            }
        }
    }

    my $total_cnt = 0;
    my %funcId2geneOrset2cnt_h;
    for my $func_id (@func_ids) {
        if ( (($merfs_timeout_mins * 60) - (time() - $start_time)) < 200 ) {
            $timeout_msg = "Process takes too long to run " .
                "-- stopped at $func_id. " .
                "Only partial result is displayed.";
            last;
        } 

        print "Processing $func_id ...<br/>\n";
        my %geneOrset2cnt_h;
        if ($isSet) {
            for my $x2 (@all_files) {
                my $cnt = 0;
                my $func_cnt_href = $geneOrset_cnt_h{$x2};
                if ($func_cnt_href) {
                    $cnt = $func_cnt_href->{$func_id};
                }
                else {
                    #should not be used
                    my($c_id, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
                    my $fullname = "$workspace_dir/$c_id/$folder/$x";
                    my %gene_h;
                    $cnt = Workspace::outputFuncGene( "", $dbh, $func_id, $folder, $fullname, $data_type, \%gene_h );
                    #print "call Workspace::outputFuncGene() done<br/>\n";
                }
                $geneOrset2cnt_h{$x2} = $cnt;
                $total_cnt += $cnt;
            }    # end for x2
        }
        else {    
            for my $gene_oid (@gene_oids) {
                my $cnt = 0;
                my $func_cnt_href = $geneOrset_cnt_h{$gene_oid};
                if ($func_cnt_href) {
                    $cnt = $func_cnt_href->{$func_id};
                }
                else {
                    #should not be used
                    $cnt = getGeneFuncCount( $dbh, $func_id, $gene_oid, $data_type );
                }
                $geneOrset2cnt_h{$gene_oid} = $cnt;
                $total_cnt += $cnt;
            }    # end for taxon_oid
        }
        $funcId2geneOrset2cnt_h{$func_id} = \%geneOrset2cnt_h;
    }
    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 100546 ) {
        print "<p>*** end time: " . currDateTime() . "<br/>\n";
    }

    if ( !$total_cnt ) {
        print
          "<h6>No genes are associated with selected functions.</h6>\n";
        print end_form();
        return;
    }

    if ($timeout_msg) {
        printMessage("<font color='red'>Warning: $timeout_msg</font>");
    }

    my $it = new InnerTable( 1, "WSFuncSetProfile$$", "WSSetFuncProfile", 1 );
    my $sd = $it->getSdDelim(); # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Function ID",   "char asc", "left" );
    $it->addColSpec( "Function Name", "char asc", "left" );
    if ( $isSet ) {
        for my $x (@all_files) {
            my $x_name = WorkspaceUtil::getShareSetName($dbh, $x, $sid);
            my ($n1, $n2) = split(/ /, $x_name, 2);
            if ( $n2 ) { 
                $x_name = $n1 . "<br/>" . $n2; 
            }
            $it->addColSpec( $x_name, "number asc", "right" );
        }
    }
    else {
        # individual genes 
        if ( scalar(@gene_oids) > 0 ) { 
            for my $gene_oid ( @gene_oids ) {
                my $col_name = join("<br/>", split(/ /, $gene_oid));
                $it->addColSpec( $col_name, "number asc", "right");
            }
        } 
    }

    my $row_cnt = 0;
    for my $func_id (@func_ids) {

        my $r = $sd . "<input type='checkbox' name='func_id' value='$func_id' />" . " \t";
        $r .= $func_id . $sd . $func_id . "\t";
        $r .= $func_names{$func_id} . $sd . $func_names{$func_id} . "\t";

        my $geneOrset2cnt_href = $funcId2geneOrset2cnt_h{$func_id};
        if ( $isSet ) {
            my $has_cnt = 0;
            for my $x2 (@all_files) {
                my $cnt = $geneOrset2cnt_href->{$x2};
                if ($cnt) {
                    my $url = "$section_cgi&page=profileGeneList"
                    . "&input_file=$x2&func_id=$func_id";
                    $url .= "&data_type=$data_type" if ( $data_type );
                    $url = alink( $url, $cnt );
                    $r .= $cnt . $sd . $url . "\t";
                    $has_cnt = 1;
                }
                else {
                    $r .= "0" . $sd . "0\t";
                }
            }

            #if ( $has_cnt ) {
            #    $r = $sd . "<input type='checkbox' name='func_id' value='$func_id' />" . " \t" . $r;
            #}
            #else {
            #    $r = $sd . " \t" . $r;
            #}
        }
        else {
            my $has_cnt = 0;
            for my $gene_oid ( @gene_oids ) {
                my $cnt = $geneOrset2cnt_href->{$gene_oid};        
                if ($cnt) {
                    my $url;
                    if ( WebUtil::isInt($gene_oid) ) {
                        $url = "$main_cgi?section=GeneDetail"
                            . "&page=geneDetail&gene_oid=$gene_oid";
                    }
                    else {
                        my ($taxon_oid, $data_type, $g2) = split(/ /, $gene_oid);
                        $url = "$main_cgi?section=MetaGeneDetail"
                            . "&page=metaGeneDetail&taxon_oid=$taxon_oid" 
                            . "&data_type=$data_type&gene_oid=$g2";
                    } 
                    $url = alink( $url, $cnt );
                    $r .= $cnt . $sd . $url . "\t";
                    $has_cnt = 1;
                }
                else {
                    $r .= "0" . $sd . "0\t";
                }
            }   # end for $gene_oid
    
            #if ( $has_cnt ) {
            #    $r = $sd . "<input type='checkbox' name='func_id' value='$func_id' />" . " \t" . $r;
            #}
            #else {
            #    $r = $sd . " \t" . $r;
            #}
        }
        $it->addRow($r);
        $row_cnt++;
    }

    WebUtil::printFuncCartFooter() if ( $row_cnt > 10 );
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    WorkspaceUtil::printFuncGeneSaveToWorkspace();

    print end_form();
    printStatusLine( "Loaded", 2 );
}

##############################################################################
# findDbAndMetaGenes
##############################################################################
sub findDbAndMetaGenes {
    my ( $input_file, $input_gene ) = @_;
    
    my @genes;
    if ( $input_gene ) {
        # only this gene
        push(@genes, $input_gene);
    }
    else {
        # from file
        open( FH, "$input_file" )
          or webError("File size - file error $input_file");
        while ( my $line = <FH> ) {
            chomp($line);
            push(@genes, $line);
        }
        close FH;
    }

    my ( $db_genes_ref, $file_genes_ref ) = MerFsUtil::splitDbAndMetaOids(@genes);
    return ( $db_genes_ref, $file_genes_ref );
}


sub getGeneFuncCount {
    my ( $dbh, $func_id, $gene_oid, $data_type, $rclause, $imgClause ) = @_;

    my $cnt = 0;
    if ( WebUtil::isInt($gene_oid) ) {
        # database
        my ($sql, @bindList) = WorkspaceQueryUtil::getDbGeneFuncCountSql($func_id, $gene_oid, $rclause, $imgClause);
        if ( $sql ) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            ($cnt) = $cur->fetchrow();
            $cur->finish();
        }
    }
    else {
        # MER-FS
        my ($taxon_oid, $data_type, $g2) = split(/ /, $gene_oid);
        my @g_func;
        if ( $func_id =~ /COG/i ) {
            @g_func = MetaUtil::getGeneCogId($g2, $taxon_oid, $data_type);
        }
        elsif ( $func_id =~ /pfam/i ) {
            @g_func = MetaUtil::getGenePfamId($g2, $taxon_oid, $data_type);
        }
        elsif ( $func_id =~ /TIGR/i ) {
            @g_func = MetaUtil::getGeneTIGRfamId($g2, $taxon_oid, $data_type);
        }
        elsif ( $func_id =~ /KO/i ) {
            @g_func = MetaUtil::getGeneKoId($g2, $taxon_oid, $data_type);
        }
        elsif ( $func_id =~ /EC/i ) {
            @g_func = MetaUtil::getGeneEc($g2, $taxon_oid, $data_type);
        }
        elsif ( $func_id =~ /^MetaCyc/i ) { 
            my ($id1, $id2) = split(/\:/, $func_id); 
            my @ecs = MetaUtil::getGeneEc($g2, $taxon_oid, $data_type); 
        
            # get MetaCyc enzymes
            my @metaCycEcs = fetchMetaCyc2Ec( $dbh, $id2 );
            for my $ec2 (@metaCycEcs) {
                if ( WebUtil::inArray($ec2, @ecs) ) {
                    @g_func = ( $func_id );
                    last;
                }                
            }
        }
        
        if ( WebUtil::inArray($func_id, @g_func) ) {
            $cnt = 1;
        }
    }        


    return $cnt;
}

sub getGeneFuncSetCount {
    my ( $dbh, $func_ids_ref, $input_file, $input_gene, $data_type ) = @_;

    my @func_ids = @$func_ids_ref;

    my ($db_genes_ref, $file_genes_ref) 
        = findDbAndMetaGenes( $input_file, $input_gene );
    #print "getGeneFuncSetCount() db_genes_ref=@$db_genes_ref<br/>\n";
    #print "getGeneFuncSetCount() file_genes_ref=@$file_genes_ref<br/>\n";

    my %func2count_h;
    my $func_id = $func_ids[0];
    
    # database
    if ( scalar(@$db_genes_ref) > 0 ) {
        my $rclause = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $gene_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_genes_ref );
        
        my ( $sql, @bindList ) = WorkspaceQueryUtil::getDbGeneFuncsCountSql(
            $dbh, \@func_ids, $gene_str, $rclause, $imgClause);
        #print "getGeneFuncSetCount() sql=$sql<br/>\n";
        if ( $sql ) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $func, $cnt1 ) = $cur->fetchrow();
                last if !$func;
                
                $func = WorkspaceQueryUtil::addBackFuncIdPrefix( $func_id, $func );
                if ( $func2count_h{$func} ) {
                    $func2count_h{$func} += $cnt1;
                }
                else {
                    $func2count_h{$func} = $cnt1;
                }
            }
            $cur->finish();
        }

        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $gene_str =~ /gtt_num_id/i );        
    }

    # file
    if ( scalar(@$file_genes_ref) > 0 ) {
        my $func_tag = MetaUtil::getFuncTagFromFuncId( $func_id );
        if ( !$func_tag ) {
            print "<p>Unknown function ID $func_id\n";
            next;
        }

        my ( $metacyc2ec_href, $ec2metacyc_href );
        if ( $func_id =~ /MetaCyc\:/i ) {
            ( $metacyc2ec_href, $ec2metacyc_href ) = QueryUtil::fetchMetaCyc2EcHash( $dbh, \@func_ids );
            my @ec_ids = keys %$ec2metacyc_href;
            @func_ids = @ec_ids;
        }
                                
        my %taxon_datatype_h;
        for my $line (@$file_genes_ref) {           
            my ($taxon_oid, $d2, $gene_oid)  = split( / /, $line );
            if ( ($data_type eq 'assembled' || $data_type eq 'unassembled') 
                && ($d2 ne $data_type) ) {
                    next;
            }
            if ( $d2 eq 'assembled' || $d2 eq 'unassembled' ) {
                my $key = "$taxon_oid $d2";
                if ( $taxon_datatype_h{$key} ) {
                    my $genes_href = $taxon_datatype_h{$key};
                    $genes_href->{$gene_oid} = 1;
                } else {
                    my %hash2;
                    $hash2{$gene_oid} = 1;
                    $taxon_datatype_h{$key} = \%hash2;
                }
            }
        }   # end while line

        for my $key ( keys %taxon_datatype_h ) {
            my $genes_href = $taxon_datatype_h{$key};
            if ( !$genes_href ) {
                print "<p>no genes in taxon_dataype $key\n";
                next;
            }
    
            my ( $taxon_oid, $d2 ) = split( / /, $key );
            my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $d2, $func_tag, \@func_ids, $genes_href );
            #print "getGeneFuncSetCount() func_genes:<br/>\n";
            #print Dumper(\%func_genes);
            #print "<br/>\n";
            if ( scalar( keys %func_genes ) > 0 ) {
                for my $func2 (keys %func_genes) {
                    my @func_genes = split( /\t/, $func_genes{$func2} );

                    my @func2s;
                    if ( $func_id =~ /MetaCyc/i ) {
                        my $metacyc_ids_ref = $ec2metacyc_href->{$func2};
                        @func2s = @$metacyc_ids_ref;
                    }
                    else {
                        @func2s = ( $func2 );
                    }
                    #print "getGeneFuncSetCount() func2s=@func2s<br/>\n";

                    foreach my $func ( @func2s ) {
                        $func = WorkspaceQueryUtil::addBackFuncIdPrefix( $func_id, $func );
                        #print "getGeneFuncSetCount() func=$func func_genes=@func_genes<br/>\n";
                        for my $func_gene ( @func_genes ) {
                            if ( $genes_href && $genes_href->{$func_gene} ) {
                                if ( $func2count_h{$func} ) {
                                    $func2count_h{$func} += 1;
                                }
                                else {
                                    $func2count_h{$func} = 1;
                                }
                            }
                        }
                    }
                }
            }

        }

    }
    #print "getGeneFuncSetCount() func2count_h:<br/>\n";
    #print Dumper(\%func2count_h);
    #print "<br/>\n";

    return %func2count_h;
}


############################################################################
# printPhyloOccurProfiles - Print phylogenetic occurrence profiles.
############################################################################
sub printPhyloOccurProfiles { 
    my @gene_oids = param("gene_oid"); 
    my $nGenes    = @gene_oids; 
    if ( $nGenes == 0 ) { 
        webError("Please select at least one gene."); 
    } 
    if ( $nGenes > $maxProfileOccurIds ) { 
        webError("Please select no more than $maxProfileOccurIds genes."); 
    }

    printMainForm();

    my @db_ids = ();
    my %fs_ids;
    my %fs_taxons;
    for my $gene_oid ( @gene_oids ) {
    	if ( isInt($gene_oid) ) {
    	    push @db_ids, ( $gene_oid );
    	}
    	else {
    	    $fs_ids{$gene_oid} = 1;
    	    my ($t2, $d2, $g2) = split(/ /, $gene_oid);
    	    $fs_taxons{"$t2 $d2"} = 1;
    	}
    }

    printStatusLine( "Loading ...", 1 ); 

    printStartWorkingDiv();

    my $dbh = dbLogin(); 
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    print "Retriving gene information ...<br/>\n";
 
    ### Load ID information
    my $cnt = 0;
    my $gene_oid_str = "";
    my @badGenes; 
    my %gene_name_h;
    my @idRecs;
    my %idRecsHash; 
    for my $gene_oid ( @db_ids ) {
    	$cnt++;
    	if ( $gene_oid_str ) {
    	    $gene_oid_str .= ", " . $gene_oid;
    	}
    	else {
    	    $gene_oid_str = $gene_oid;
    	}
    	print ".";
    	if ( ($cnt % 180) == 0 ) {
    	    print "<br/>\n";
    	}
    
    	if ( (($cnt % 1000) == 0 || $cnt >= scalar(@db_ids)) && $gene_oid_str ) {
    	    my $sql = qq{
                select g.gene_oid, g.gene_display_name, g.taxon, g.locus_type
                from gene g 
                where g.gene_oid in( $gene_oid_str )
                $rclause
                $imgClause
                order by g.gene_oid
            }; 
    	    my $cur = execSql( $dbh, $sql, $verbose );
    
    	    for ( ; ; ) { 
        		my ( $gene_oid, $gene_display_name, $taxon, $locus_type ) =
        		    $cur->fetchrow();
        		last if !$gene_oid;
        		if ( $locus_type ne "CDS" ) { 
        		    push( @badGenes, $gene_oid ); 
        		    next; 
        		} 
        		my %taxons; 
        		$taxons{$taxon} = 1;
        		my $rh = { 
                   id   => $gene_oid,
                   name => $gene_display_name,
                   url  => "$main_cgi?section=GeneDetail" 
                     . "&page=geneDetail&gene_oid=$gene_oid",
                   taxonOidHash => \%taxons, 
        		}; 
        		push( @idRecs, $rh );
        		$idRecsHash{$gene_oid} = $rh;
    	    } 
    	    $cur->finish(); 

    	    if ( scalar(@badGenes) > 0 ) {
        		#$dbh->disconnect(); 
        		my $s = join( ',', @badGenes ); 
        		printEndWorkingDiv();
        		webError("Select only protein coding genes. " 
        			    . "The following RNA genes were found: $s." ); 
        		return; 
    	    } 
    
    	    # reset
    	    $gene_oid_str = "";
    	}
    }   # end for my gene_oid

    ### MER-FS gene info
    for my $gene_oid ( keys %fs_ids ) {
    	$cnt++;
    	print ".";
    	if ( ($cnt % 180) == 0 ) {
    	    print "<br/>\n";
    	}

    	my ($taxon_oid, $data_type, $g2) = split(/ /, $gene_oid);
    	my ($gene_oid2, $locus_type, $locus_tag, $gene_display_name,
    	    $start_coord, $end_coord, $strand, $scaffold_oid) =
    		MetaUtil::getGeneInfo($g2, $taxon_oid, $data_type);
    	if ( $locus_type ne "CDS" ) { 
    	    push( @badGenes, $gene_oid ); 
    	    next; 
    	} 
    	my ($gene_prod_name, $prod_src) = 
    	    MetaUtil::getGeneProdNameSource($g2, $taxon_oid, $data_type);
    	if ( $gene_prod_name ) {
    	    $gene_display_name = $gene_prod_name;
    	}
    
    	my %taxons; 
    	$taxons{$taxon_oid} = 1;
    	my $rh = { 
    	    id   => $g2,
    	    name => $gene_display_name,
    	    url  => "$main_cgi?section=MetaGeneDetail" 
    		. "&page=metaGeneDetail&gene_oid=$g2",
    		taxonOidHash => \%taxons, 
    	}; 
    	push( @idRecs, $rh );
    	$idRecsHash{$gene_oid} = $rh;
    }
    if ( scalar(@badGenes) > 0 ) {
    	#$dbh->disconnect(); 
    	my $s = join( ',', @badGenes ); 
    	printEndWorkingDiv();
    	webError(   "Select only protein coding genes. " 
    		    . "The following RNA genes were found: $s." ); 
    	return; 
    } 
    print "<br/>\n";

    ### Load taxonomic hits information 
    print "Retrieving gene hit information ... <br/>\n";
    $cnt = 0;
    if ( $include_bbh_lite && $bbh_zfiles_dir ne "" ) { 
        WebUtil::unsetEnvPath(); 
        for my $gene_oid (@db_ids) { 
    	    $cnt++;
    	    print ".";
    	    if ( ($cnt % 180) == 0 ) {
        		print "<br/>\n";
    	    }

            my @recs = getBBHLiteRows($gene_oid); 
            for my $r (@recs) { 
                my ( 
                     $qid,       $sid,   $percIdent, $alen, 
                     $nMisMatch, $nGaps, $qstart,    $qend, 
                     $sstart,    $send,  $evalue,    $bitScore 
                  ) 
		    = split( /\t/, $r ); 
                my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid ); 
                my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid ); 
                my $rh = $idRecsHash{$gene_oid}; 
                if ( !defined($rh) ) { 
                    webDie(   "printPhyloOccurProfiles: " 
			      . "cannot find '$gene_oid'\n" ); 
                } 
                my $taxonOidHash = $rh->{taxonOidHash};
                $taxonOidHash->{$staxon} = 1;
            } 
        } 
        WebUtil::resetEnvPath(); 
    }
    #$dbh->disconnect(); 
    print "<br/>\n";

    ### MER-FS hits
    $cnt = 0;
    my @keys = (keys %fs_taxons);
    for my $key ( @keys ) {
    	my ($taxon, $data_type) = split(/ /, $key);
    	for my $percent (30, 60, 90) {
    	    print "Processing gene hits for $taxon $data_type $percent \% data ...<br/>\n";
    	    $taxon = sanitizeInt($taxon);
    	    my $file_name = $mer_data_dir . "/" . $taxon . "/";
    	    if ( $data_type eq 'assembled' ) {
        		$file_name .= "assembled/phyloGene" . $percent . ".zip";
    	    }
    	    else {
        		$file_name .= "unassembled/phyloGene" . $percent . ".zip";
    	    }
    	    if ( ! (-e $file_name) ) {
        		next;
    	    }
    
    	    WebUtil::unsetEnvPath();
    	    my $fh = newCmdFileHandle
    		( "/usr/bin/unzip -p $file_name ", 'geneHits' );
     	    if ( !$fh ) {
        		next; 
    	    }
    	    my $line;
    	    my $line_no = 0;
    	    while ( $line = $fh->getline() ) {
        		my ($gid2, $pc2, $homo2, $fa2, $ge2, $sp2, $staxon, $v2) =
        		    split(/\t/, $line);
        		$line_no++;
        		if ( ($line_no % 20) == 0 ) {
        		    print ".";
        		}
        		if ( ($line_no % 3600) == 0 ) {
        		    print ".";
        		}
        
        		my $gene_oid = "$taxon $data_type $gid2";
        		if ( $fs_ids{$gene_oid} ) {
        		    # selected
        		    my $rh = $idRecsHash{$gene_oid}; 
        		    if ( !defined($rh) ) { 
            			webDie(   "printPhyloOccurProfiles: " 
            				  . "cannot find '$gene_oid'\n" ); 
        		    } 
        		    my $taxonOidHash = $rh->{taxonOidHash};
        		    $taxonOidHash->{$staxon} = 1;
        		}
    	    }
    	    print "<br/>\n";
    	    close $fh;
    	    WebUtil::resetEnvPath(); 
    	}
    }

    printEndWorkingDiv();

    ## Print it out as an alignment.
    require PhyloOccur; 
    my $s = "Profiles are based on bidirectional best hit orthologs.<br/>\n";
    $s .= "A dot '.' means there are no bidirectional best hit orthologs \n";
    $s .= "for the genome.<br/>\n"; 
    PhyloOccur::printAlignment( '', \@idRecs, $s ); 
 
    printStatusLine( "Loaded.", 2 ); 

    print end_form();
} 


############################################################################
# printGeneProfile
#
# (no MER-FS genomes, no Bins)
############################################################################
sub printGeneProfile {
    my $folder = param('directory');
    my $filename = param('filename');
    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder",   $folder ); 
    print hiddenVar( "filename", $filename ); 

    my @gene_oids = param('gene_oid');
    if ( scalar(@gene_oids) == 0 ) {
    	webError("No genes have been selected.");
    	return;
    }
    if ( scalar(@gene_oids) > $maxGeneProfileIds ) {
    	webError("Too many genes. Please select no more than $maxGeneProfileIds genes.");
    	return;
    }

    my %taxon_oids;
    my @profileTaxonOids = param("genomeFilterSelections" );
    for my $id1 ( @profileTaxonOids ) {
    	if ( ! isInt($id1) ) {
    	    next;
    	}
    	$taxon_oids{$id1} = 1;
    }

    if ( scalar(keys %taxon_oids) == 0 ) {
    	webError("No genomes have been selected.");
    	return;
    }

    printMainForm();
    print "<h1>Gene Profile</h1>\n";

    my $sid = getContactOid();
    if ( $sid == 312 ) {
    	print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStatusLine( "Loading ...", 1 ); 
    printStartWorkingDiv();

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my %db_gene_h;
    my %db_gene_taxon_h;
    my %db_gene_name_h;
    for my $gene_oid ( @gene_oids ) {
	if ( isInt($gene_oid) ) {
	    my ($gene_display_name, $gene_taxon_oid) 
	       = QueryUtil::fetchSingleGeneNameAndTaxon($dbh, $gene_oid, "hypothetical protein", $rclause, $imgClause);
	    if ( ! $gene_taxon_oid ) {
    		next;
	    }

	    $db_gene_taxon_h{$gene_taxon_oid} = 1;
	    $db_gene_h{$gene_oid} = $gene_taxon_oid;
	    $db_gene_name_h{$gene_oid} = $gene_display_name;
	}
    }

    my $maxEvalue = param('maxEvalue');
    my $minPercIdent = param('minPercIdent');
    my $validTaxons_str = join(",", @profileTaxonOids);

    print "<p>Checking genome profile data ...<br/>\n";

    my %cells;
    my $cnt0 = 0;
    for my $gene_taxon_oid (keys %db_gene_taxon_h) {
	$cnt0++;
#	print ".";
#	if ( ($cnt0 % 180) == 0 ) {
#	    print "<br/>\n";
#	}

	for my $taxon_oid (keys %taxon_oids) {
	    # find pairwise comparison file
	    my $gzPath = "$genomePair_zfiles_dir/$gene_taxon_oid/" .
		"$gene_taxon_oid-$taxon_oid.m8.txt.gz"; 
	    my $zipPath = "$genomePair_zfiles_dir/$gene_taxon_oid.zip";
	    my $rfh; 
	    WebUtil::unsetEnvPath( ); 
	    if( -e $zipPath ) { 
                print "Using precomputed file for $taxon_oid ...<br/>\n";
		$rfh = newUnzipFileHandle( $zipPath,
					   "$gene_taxon_oid-$taxon_oid", "processResults" );
	    } 
	    elsif( -e $gzPath ) {
                print "Using precomputed file for $taxon_oid ...<br/>\n";
		$rfh = newReadGzFileHandle( $gzPath, "processResults" ); 
	    } 
	    else {
		# cannot find files. blast on-the-fly
                print "Using blast on the fly for $taxon_oid ...<br/>\n";
		for my $gene_oid (keys %db_gene_h) {
		    if ( $db_gene_h{$gene_oid} == $gene_taxon_oid ) {
                        print "processing gene $gene_oid ...<br/>\n";
			my @hits = getGeneHits_otf($gene_oid, $maxEvalue, $minPercIdent, 
						   $gene_oid, $taxon_oid);
                        print "getting " . scalar(@hits) . " hit(s).<br/>\n";
			my $k  = "$gene_oid-$taxon_oid";
			$cells{ $k } = join(' ', @hits);
		    }
		}
		next;
	    }

	    my $j = 0;
	    while( my $s = $rfh->getline( ) ) {
		chomp $s; 
		my( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
		    $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
			split( /\t/, $s ); 
		my ($q_gene_oid, $q_taxon_oid, $q_val) = split(/\_/, $qid);
		my ($s_gene_oid, $s_taxon_oid, $s_val) = split(/\_/, $sid);

		if ( ! $db_gene_h{$q_gene_oid} ) {
		    # gene not selected
		    next;
		}

		if ( $evalue > $maxEvalue ) {
		    next;
		}
		if ( $percIdent < $minPercIdent ) {
		    next;
		}

		my $k  = "$q_gene_oid-$taxon_oid";
		$cells{ $k } .= "$s_gene_oid "; 
	    }  # end while getline

	    $rfh->close( );
	    WebUtil::resetEnvPath( );
	}
    }
    print"<br/>\n";

    my @recs = ();
    $cnt0 = 0;
    print "<p>Retrieving gene profile information ...<br/>\n";
    for my $gene_oid( @gene_oids ) { 
	$cnt0++;
	print ".";
	if ( ($cnt0 % 90) == 0 ) {
	    print "<br/>\n";
	}
	my $r = "$gene_oid\t";

	if ( isInt($gene_oid) ) {
	    # DB
	    print ".";
	    my $gene_display_name = $db_gene_name_h{$gene_oid};
	    $r .= "$gene_display_name\t"; 

	    for my $taxonBin( @profileTaxonOids ) {
    		my $k = "$gene_oid-$taxonBin"; 
    		my $v = $cells{ $k }; 
    		chop $v; 
    		my @a = split( / /, $v ); 
    		my $cnt = @a; 
    		$r .= "$cnt\t"; 
	    } 
	}
	else {
	    # MER-FS
	    my ($t2, $d2, $g2) = split(/ /, $gene_oid);
	    my ( $gene_name, $source ) = MetaUtil::getGeneProdNameSource( $g2, $t2, $d2 );
	    if ( ! $gene_name ) {
    		$gene_name = "hypothetical protein";
	    }
	    $r .= "$gene_name\t"; 
	    for my $taxon_oid (keys %taxon_oids) {
    		my @hits = getGeneHits_otf($gene_oid, $maxEvalue, $minPercIdent, 
    					   $cnt0, $taxon_oid);
    		my $cnt = scalar(@hits);
    		if ( $cnt ) {
    		    $r .= "$cnt\t"; 
    		}
    		else {
    		    $r .= "0\t"; 
    		}
	    }
	}

	push( @recs, $r ); 
    }

    printEndWorkingDiv();
    printStatusLine( "Loaded", 2 ); 

    if ( $sid == 312 ) {
	print "<p>*** time2: " . currDateTime() . "\n";
    }

    my $it = new InnerTable( 1, "GeneProfile$$", "GeneProfile", 0 ); 
    my $sd = $it->getSdDelim();    # sort delimiter
 
    ## Header
    $it->addColSpec( "Gene ID", "asc" ); 
    $it->addColSpec( "Gene Product Name", "asc" ); 
 
    for my $taxon_oid ( @profileTaxonOids ) {
    	my $abbrName; 
    	my $taxon_name = taxonOid2Name($dbh, $taxon_oid);
    	$abbrName = WebUtil::abbrColName( $taxon_oid, $taxon_name, 1 ); 
    	$it->addColSpec( $abbrName, "desc", "right", "", $taxon_name ); 
    } 

    #$dbh->disconnect();

    ## Rows
    # YUI tables look better with more vertical padding:
    my $yui_tables = 1;
    my $vPadding = ($yui_tables) ? 4 : 0; 
    my $vPadding = 0;
    for my $r( @recs ) { 
	my $row; 
	my @fields = split( /\t/, $r ); 

	my $val = $fields[ 0 ]; 
	my ($t2, $d2, $g2) = split(/ /, $val);
	my $gene_oid = $g2;
	if ( ! $gene_oid && isInt($val) ) {
	    $gene_oid = $val;
	    $t2 = $db_gene_h{$gene_oid};
	    $d2 = 'database';
	    $g2 = $gene_oid;
	}

	my $url = "$main_cgi?section=GeneDetail" . 
	    "&page=geneDetail&gene_oid=$val"; 
	if ( $d2 ne 'database' ) {
	    $url = "$main_cgi?section=MetaGeneDetail" . 
		"&page=metaGeneDetail&gene_oid=$g2" .
		"&taxon_oid=$t2&data_type=$d2";
	}
	$row .= $g2 . $sd . alink( $url, $g2 ) . "\t"; 

	if ( scalar(@fields) > 1 ) {
	    $val = $fields[ 1 ];
	}
	else {
	    $val = "hypothetical protein";
	}
	$row .= $val . $sd . escHtml( $val ) . "\t"; 

	my $j = 2;
	for my $taxon_oid ( @profileTaxonOids ) {
	    if ( scalar(@fields) > $j ) {
		$val = $fields[ $j ]; 
	    }
	    else {
		$val = 0;
	    }

	    my $color = val2Color( $val );
	    $row .= $val . $sd; 
	    if( $val == 0 || ! $val ) { 
		$row .= "<span style='padding:${vPadding}px 10px;'>";
		$row .= "0</span>\t"; 
	    } 
	    else { 
		my $url = "$section_cgi&page=geneProfilerGenes";
		$url .= "&gene_oid=$gene_oid";
		$url .= "&taxon_oid=$t2&data_type=$d2";
		$url .= "&taxonBin=$taxon_oid"; 
		$url .= "&maxEvalue=$maxEvalue&minPercIdent=$minPercIdent";

		$row .= "<span style='background-color:$color;padding:${vPadding}px 10px;'>";
		$row .= alink( $url, $val );
		$row .= "</span>\t";
	    } 
	    $j++;
        }

        $it->addRow($row); 
    } 

    $it->printOuterTable(1); 

    print end_form();
}


############################################################################
# printGeneProfileTranspose
#
# (no MER-FS genomes, no Bins)
############################################################################
sub printGeneProfileTranspose {
    my $folder = param('directory');
    my $filename = param('filename');
    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder",   $folder ); 
    print hiddenVar( "filename", $filename ); 

    my @gene_oids = param('gene_oid');
    if ( scalar(@gene_oids) == 0 ) {
	webError("No genes have been selected.");
	return;
    }
    if ( scalar(@gene_oids) > $maxGeneProfileIds ) {
	webError("Too many genes. Please select no more than $maxGeneProfileIds genes.");
	return;
    }

    my @taxonOids = param("genomeFilterSelections" );
    if ( scalar(@taxonOids) <= 0 ) {
    	webError("No genomes have been seelected.");
    	return;
    }
			    
    printMainForm();
    print "<h1>Gene Profile</h1>\n";

    my $sid = getContactOid();
    if ( $sid == 312 ) {
	print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStatusLine( "Loading ...", 1 ); 
    printStartWorkingDiv();

    print "<p>Retrieving genome information from database ...<br/>\n";
    my $dbh = dbLogin();

    my %taxon_name_h = QueryUtil::fetchTaxonOid2NameHash($dbh, \@taxonOids);    
    my @profileTaxonOids = (keys %taxon_name_h);

    if ( scalar(@profileTaxonOids) == 0 ) {
    	webError("No genomes have been selected.");
    	return;
    }

    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my %db_gene_h;
    my %db_gene_taxon_h;
    my %db_gene_name_h;
    for my $gene_oid ( @gene_oids ) {
    	if ( isInt($gene_oid) ) {
    	    my ($gene_display_name, $gene_taxon_oid) 
    	       = QueryUtil::fetchSingleGeneNameAndTaxon($dbh, $gene_oid, '', $rclause, $imgClause);
    	    if ( ! $gene_taxon_oid ) {
        		next;
    	    }
    
    	    $db_gene_taxon_h{$gene_taxon_oid} = 1;
    	    $db_gene_h{$gene_oid} = $gene_taxon_oid;
    	    $db_gene_name_h{$gene_oid} = $gene_display_name;
    	}
    }

    my $maxEvalue = param('maxEvalue');
    my $minPercIdent = param('minPercIdent');
    my $validTaxons_str = join(",", @profileTaxonOids);

    print "<p>Checking genome profile data ...<br/>\n";

    my %cells;
    my $cnt0 = 0;
    for my $gene_taxon_oid (keys %db_gene_taxon_h) {
	$cnt0++;
#	print ".";
#	if ( ($cnt0 % 180) == 0 ) {
#	    print "<br/>\n";
#	}

	for my $taxon_oid (@profileTaxonOids) {
	    # find pairwise comparison file
	    my $gzPath = "$genomePair_zfiles_dir/$gene_taxon_oid/" .
		"$gene_taxon_oid-$taxon_oid.m8.txt.gz"; 
	    my $zipPath = "$genomePair_zfiles_dir/$gene_taxon_oid.zip";
	    my $rfh; 
	    WebUtil::unsetEnvPath( ); 
	    if( -e $zipPath ) { 
                print "Using precomputed file for $taxon_oid ...<br/>\n";
		$rfh = newUnzipFileHandle( $zipPath,
					   "$gene_taxon_oid-$taxon_oid", "processResults" );
	    } 
	    elsif( -e $gzPath ) {
                print "Using precomputed file for $taxon_oid ...<br/>\n";
		$rfh = newReadGzFileHandle( $gzPath, "processResults" ); 
	    } 
	    else {
		# cannot find files. blast on-the-fly
                print "Using blast on the fly for $taxon_oid ...<br/>\n";
		for my $gene_oid (keys %db_gene_h) {
		    print "processing gene $gene_oid ...<br/>\n";
		    if ( $db_gene_h{$gene_oid} == $gene_taxon_oid ) {
			my @hits = getGeneHits_otf($gene_oid, $maxEvalue, $minPercIdent, 
						   $gene_oid, $taxon_oid);
                        print "getting " . scalar(@hits) . " hit(s).<br/>\n";
			my $k  = "$gene_oid-$taxon_oid";
			$cells{ $k } = join(' ', @hits);
		    }
		}
		next;
	    }

	    my $j = 0;
	    while( my $s = $rfh->getline( ) ) {
		chomp $s; 
		my( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
		    $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
			split( /\t/, $s ); 
		my ($q_gene_oid, $q_taxon_oid, $q_val) = split(/\_/, $qid);
		my ($s_gene_oid, $s_taxon_oid, $s_val) = split(/\_/, $sid);

		if ( ! $db_gene_h{$q_gene_oid} ) {
		    # gene not selected
		    next;
		}

		if ( $evalue > $maxEvalue ) {
		    next;
		}
		if ( $percIdent < $minPercIdent ) {
		    next;
		}

		my $k  = "$q_gene_oid-$taxon_oid";
		$cells{ $k } .= "$s_gene_oid "; 
	    }  # end while getline

	    $rfh->close( );
	    WebUtil::resetEnvPath( );
	}
    }
    print"<br/>\n";

    my @recs = ();
    $cnt0 = 0;
    print "<p>Retrieving gene profile information ...<br/>\n";
    for my $taxonBin( @profileTaxonOids ) {
	my $r = "$taxonBin\t";
	for my $gene_oid( @gene_oids ) { 
	    $cnt0++;
	    print ".";
	    if ( ($cnt0 % 90) == 0 ) {
		print "<br/>\n";
	    }

	    if ( isInt($gene_oid) ) {
		# DB
		print ".";
		my $k = "$gene_oid-$taxonBin"; 
		my $v = $cells{ $k }; 
		chop $v; 
		my @a = split( / /, $v ); 
		my $cnt = @a; 
		$r .= "$cnt\t"; 
	    } 
	    else {
		# MER-FS
		my @hits = getGeneHits_otf($gene_oid, $maxEvalue, $minPercIdent, 
					   $cnt0, $taxonBin);
		my $cnt = scalar(@hits);
		if ( $cnt ) {
		    $r .= "$cnt\t"; 
		}
		else {
		    $r .= "0\t"; 
		}
	    }
	}   # end for gene_oid

	push( @recs, $r ); 
    }   # end for taxonBin

    printEndWorkingDiv();
    printStatusLine( "Loaded", 2 ); 

    if ( $sid == 312 ) {
	print "<p>*** time2: " . currDateTime() . "\n";
    }

    my $it = new InnerTable( 1, "GeneProfile$$", "GeneProfile", 0 ); 
    my $sd = $it->getSdDelim();    # sort delimiter
 
    ## Header
    $it->addColSpec( "Genome Name", "asc" ); 
    for my $gene_oid( @gene_oids ) { 
	my $gene_display_name = "";
	if ( isInt($gene_oid) ) {
	    $gene_display_name = $db_gene_name_h{$gene_oid};
	}
	else {
	    my ($t2, $d2, $g2) = split(/ /, $gene_oid);
	    my ( $gene_name, $source ) = MetaUtil::getGeneProdNameSource( $g2, $t2, $d2 );
	    $gene_display_name = $gene_name;
	}
	if ( ! $gene_display_name ) {
	    $gene_display_name = "hypothetical protein";
	}
	my $disp_oid = join("<br/>", split(/ /, $gene_oid));
	$it->addColSpec( $disp_oid, "number desc", "right", "",
			 $gene_display_name );
    }

    ## Rows
    # YUI tables look better with more vertical padding:
    my $yui_tables = 1;
    my $vPadding = ($yui_tables) ? 4 : 0; 
    my $vPadding = 0;
    for my $r( @recs ) { 
	my $row; 
	my @fields = split( /\t/, $r ); 

	my $taxon_oid = $fields[ 0 ]; 
	my $url = "$main_cgi?section=TaxonDetail" . 
	    "&page=taxonDetail&taxon_oid=$taxon_oid"; 
	my $taxon_name = $taxon_name_h{$taxon_oid};
	if ( ! $taxon_name ) {
	    next;
	}
	$taxon_name = escHtml($taxon_name);
	$row .= $taxon_name . $sd . alink( $url, $taxon_name ) . "\t"; 

	my $val;
	my $j = 1;
	for my $gene_oid ( @gene_oids ) {
	    my ($t2, $d2, $g2) = split(/ /, $gene_oid);
	    if ( ! $d2 ) {
		$t2 = $db_gene_h{$gene_oid};
		$d2 = 'database';
		$g2 = $gene_oid;
	    }

	    if ( scalar(@fields) > $j ) {
		$val = $fields[ $j ]; 
	    }
	    else {
		$val = 0;
	    }

	    my $color = val2Color( $val );
	    $row .= $val . $sd; 
	    if( $val == 0 || ! $val ) { 
		$row .= "<span style='padding:${vPadding}px 10px;'>";
		$row .= "0</span>\t"; 
	    } 
	    else { 
		my $url = "$section_cgi&page=geneProfilerGenes";
		$url .= "&gene_oid=$g2";
		$url .= "&taxon_oid=$t2&data_type=$d2";
		$url .= "&taxonBin=$taxon_oid"; 
		$url .= "&maxEvalue=$maxEvalue&minPercIdent=$minPercIdent";

		$row .= "<span style='background-color:$color;padding:${vPadding}px 10px;'>";
		$row .= alink( $url, $val );
		$row .= "</span>\t";
	    } 
	    $j++;
        }

        $it->addRow($row); 
    } 

    $it->printOuterTable(1); 

    print end_form();
}


############################################################################
# val2Color - Map value to color.
############################################################################
sub val2Color { 
    my( $val ) = @_; 
    my $color = "white"; 
    if( $val >= 1 && $val <= 4 ) {
	$color = "bisque";
    } 
    if( $val >= 5 ) { 
	$color = "yellow"; 
    } 
    return $color; 
} 


############################################################################
# printGeneProfilerGenes
############################################################################
sub printGeneProfilerGenes {
    printMainForm();
    print "<h1>Genes in Gene Profile</h1>\n";

    my $taxonBin = param('taxonBin');
    my $gene_oid = param('gene_oid');
    my $gene_taxon_oid = param('taxon_oid');
    my $data_type = param('data_type');
    my $maxEvalue = param('maxEvalue');
    my $minPercIdent = param('minPercIdent');

    $taxonBin = sanitizeInt($taxonBin);
    $gene_taxon_oid = sanitizeInt($gene_taxon_oid);

    my $it = new InnerTable( 1, "GeneProfile$$", "GeneProfile", 0 ); 
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select"); 
    $it->addColSpec( "Gene ID", "asc" ); 
    $it->addColSpec( "Locus Tag", "asc" ); 
    $it->addColSpec( "Gene Product Name", "asc" ); 

    my $select_id_name = "gene_oid";

    # find pairwise comparison file
#    my $gzPath = "$avagz_batch_dir/$gene_taxon_oid/" .
    my $gzPath = "$genomePair_zfiles_dir/$gene_taxon_oid/" .
	"$gene_taxon_oid-$taxonBin.m8.txt.gz"; 
    my $zipPath = "$genomePair_zfiles_dir/$gene_taxon_oid.zip";
    my $rfh; 
    WebUtil::unsetEnvPath( ); 
    my @hits = ();
    my $cnt = 0;

    if( -e $zipPath ) { 
    	$rfh = newUnzipFileHandle( $zipPath,
				   "$gene_taxon_oid-$taxonBin", "processResults" );
    } 
    elsif( -e $gzPath ) {
    	$rfh = newReadGzFileHandle( $gzPath, "processResults" ); 
    } 
    else {
    	# cannot find files. blast on-the-fly
    	if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
    	    my $workspace_id = "$gene_taxon_oid $data_type $gene_oid";
    	    @hits = getGeneHits_otf($workspace_id, $maxEvalue, $minPercIdent, 
    				    1000, $taxonBin);
    	}
    	else {
    	    @hits = getGeneHits_otf($gene_oid, $maxEvalue, $minPercIdent, 
    				    $gene_oid, $taxonBin);
    	}
    }

    if ( $rfh ) {
    	while( my $s = $rfh->getline( ) ) {
    	    chomp $s; 
    	    my( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
    		$qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
    		    split( /\t/, $s ); 
    	    my ($q_gene_oid, $q_taxon_oid, $q_val) = split(/\_/, $qid);
    	    my ($s_gene_oid, $s_taxon_oid, $s_val) = split(/\_/, $sid);
    
    	    if ( $q_gene_oid ne $gene_oid ) {
        		# same gene
        		next;
    	    }
    
    	    if ( $s_taxon_oid ne $taxonBin ) {
        		next;
    	    }
    
    	    if ( $evalue > $maxEvalue ) {
        		next;
    	    }
    	    if ( $percIdent < $minPercIdent ) {
        		next;
    	    }
    
    	    push @hits, ( $s_gene_oid );
    	}
    	$rfh->close( );
    }
    WebUtil::resetEnvPath( );

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    for my $g2 ( @hits ) {
        my ($locus_tag, $gene_name)
	       = QueryUtil::fetchSingleGeneNameAndLocusTag($dbh, $g2, "hypothetical protein", $rclause, $imgClause);

    	my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$g2' /> \t"; 
    	my $url = "$main_cgi?section=GeneDetail"
    	    . "&page=geneDetail&gene_oid=$g2";
    	$r .= $gene_oid . $sd . alink($url, $g2) . "\t";
    	$r .= $locus_tag . $sd . $locus_tag . "\t";
    	$r .= $gene_name . $sd . $gene_name;
        $it->addRow($r);
    	$cnt++;
    }

    #$dbh->disconnect();

    if ( ! $cnt ) {
    	print "<p>No genes found.\n";
    	print end_form();
    	return;
    }

    $it->printOuterTable(1);

    WebUtil::printButtonFooter();

    if ( $cnt > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect(); 
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    print end_form();
}



############################################################################
# printPhyloOccurProfiles_otf - Print phylogenetic occurrence profiles.
# (blast on-the-fly)
############################################################################
sub printPhyloOccurProfiles_otf { 
    my @gene_oids = param("gene_oid"); 
    my $nGenes    = @gene_oids; 
    if ( $nGenes == 0 ) { 
        webError("Please select at least one gene."); 
    } 
    if ( $nGenes > $maxProfileOccurIds ) { 
        webError("Please select no more than $maxProfileOccurIds genes."); 
    }

    my $maxEvalue = param('maxEvalue');
    my $minPercIdent = param('minPercIdent');

    printMainForm();

    my $sid = getContactOid();

    if ( $sid == 312 ) {
    	print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();
    my $cnt = 0;
    my @badGenes; 
    my @idRecs;
    my %idRecsHash; 

    print "Blast on-the-fly ...<br/>\n";
    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my %validTaxons = WebUtil::getAllTaxonsHashed($dbh); 
    
    for my $gene_oid ( @gene_oids ) {
    	$cnt++;
    	print ".";
    	if ( ($cnt % 90) == 0 ) {
    	    print "<br/>\n";
    	}

    	my ($taxon_oid, $data_type, $g2, $url);
    	my $blast_gene_oid = $gene_oid;
    	my $seq = "";
    	my $locus_type;
    	my $gene_display_name;
    	if ( isInt($gene_oid) ) {
    	    # DB gene
    	    ($locus_type, $gene_display_name, $seq) 
    	        = QueryUtil::fetchSingleGeneNameLocusTypeAAseq($dbh, $gene_oid, $rclause, $imgClause);
    	    if ( $locus_type ne 'CDS' ) {
        		push @badGenes, ( $gene_oid );
    	    }
    	    $g2 = $gene_oid;
    	    $data_type = 'database';
    	    $url = "$main_cgi?section=GeneDetail" .
    		"&page=geneDetail&gene_oid=$gene_oid";
    	}
    	else {
    	    ($taxon_oid, $data_type, $g2) = split(/ /, $gene_oid);
    	    $blast_gene_oid = $cnt;    # need to fake gene_oid to avoid perl error
    	    my ($gene_oid2, $locus_type, $locus_tag, $gene_name,
    		    $start_coord, $end_coord, $strand, $scaffold_oid) 
    		    = MetaUtil::getGeneInfo($g2, $taxon_oid, $data_type);
    	    if ( $locus_type ne "CDS" ) { 
        		push( @badGenes, $gene_oid ); 
        		next; 
    	    } 
    	    $url = "$main_cgi?section=MetaGeneDetail" .
    		"&page=metaGeneDetail&gene_oid=$g2" .
    		"&taxon_oid=$taxon_oid&data_type=$data_type";
    	    my ($gene_prod_name, $prod_src) = 
        		MetaUtil::getGeneProdNameSource($g2, $taxon_oid, $data_type);
    	    $gene_display_name = $gene_name;
    	    if ( $gene_prod_name ) {
        		$gene_display_name = $gene_prod_name;
    	    }
    	    $seq = MetaUtil::getGeneFaa($g2, $taxon_oid, $data_type);
    	}

    	if ( ! $seq ) {
    	    next;
    	}

    	print ".";
    
        my $top_n = 200;
    	my $blast_url = $blast_server_url;
        webLog("blast url: $blast_server_url\n");

    	my $ua = WebUtil::myLwpUserAgent(); 
    	$ua->timeout(1000); 
    	$ua->agent("img2.x/genePageTopHits"); 
    	my $db = $img_lid_blastdb; 
    	$db = $img_iso_blastdb;
    
    	my $req = POST $blast_url, [ 
    	    gene_oid => $blast_gene_oid, 
    	    seq      => $seq, 
    	    db       => $db, 
    	    top_n    => $top_n,           # make large number 
    	]; 
     
    	my $res = $ua->request($req); 
    	if ( $res->is_success() ) { 
    	    my @lines = split( /\n/, $res->content ); 
    	    my $idx = 0; 
    	    my @sortRecs; 
    	    my @hrecs; 
    	    my %done; 
    	    my %taxons; 
    
    	    my $line_no = 0;
    	    for my $s (@lines) {
        		$line_no++;
        		if ( $s =~ /ERROR:/ ) {
        		    webError($s); 
        		} 
        		my ( 
        		    $qid,    $sid,      $percIdent, $alen,   $nMisMatch,
        		    $nGaps,  $qstart,   $qend,      $sstart, $send,
        		    $evalue, $bitScore, $opType
        		    ) 
        		    = split( /\t/, $s ); 
        		#my ( $gene_oid, undef ) = split( /_/, $qid ); 
        		my ( $homolog, $staxon, undef ) = split( /_/, $sid );
        		next if !$validTaxons{$staxon};
        		next if $done{$sid}; 
        
        		# check evalue
        		if ( $evalue > $maxEvalue ) {
        		    next;
        		}
        
        		# check percent identity
        		if ( $percIdent < $minPercIdent ) {
        		    next;
        		}
        
        		$taxons{$staxon} = 1;
    	    }
    
    	    my $rh = { 
    		id   => $g2,
    		name => $gene_display_name,
    		url  => "$main_cgi?section=GeneDetail" .
    		         "&page=geneDetail&gene_oid=$gene_oid",
     	        taxonOidHash => \%taxons, 
    		}; 
    	    push( @idRecs, $rh );
    	    $idRecsHash{$gene_oid} = $rh;
    	} else { 
    	    webLog( $res->status_line . "\n" );
    	    warn( $res->status_line . "\n" );
    	} 
    }
    #$dbh->disconnect();
    print "<br/>\n";

    printEndWorkingDiv();

    if ( $sid == 312 ) {
    	print "<p>*** time2: " . currDateTime() . "\n";
    }

    if ( scalar(@badGenes) > 0 ) {
    	my $s = join( ',', @badGenes ); 
    	printMessage ("The following RNA genes are skipped: $s.");
    } 

    ## Print it out as an alignment.
    require PhyloOccur; 
    my $s = "Profiles are based on bidirectional best hit orthologs.<br/>\n";
    $s .= "A dot '.' means there are no bidirectional best hit orthologs \n";
    $s .= "for the genome.<br/>\n"; 
    PhyloOccur::printAlignment( '', \@idRecs, $s ); 
 
    printStatusLine( "Loaded.", 2 ); 

    print end_form();
} 


############################################################################
# getGeneHits_otf
# (blast on-the-fly)
############################################################################
sub getGeneHits_otf {
    my ($gene_oid, $maxEvalue, $minPercIdent, $blast_gene_oid, $taxon_str) = @_;

    my %validTaxons;
    if ( $taxon_str ) {
        my @taxons = split(/\,/, $taxon_str);
        for my $t1 ( @taxons ) {
            $validTaxons{$t1} = 1;
        }
    }
    else {
        my $dbh = dbLogin();
        %validTaxons = WebUtil::getAllTaxonsHashed($dbh); 
    }

#    print "<p>**** blast $gene_oid against $taxon_str\n";

    my @hits = ();
    my $seq = "";
    if ( isInt($gene_oid) ) {
    	# DB gene
    	my $dbh = dbLogin();
        my ($locus_type, $gene_display_name, $aa_seq) 
        	= QueryUtil::fetchSingleGeneNameLocusTypeAAseq($dbh, $gene_oid);
    	#$dbh->disconnect();
    	if ( $locus_type ne 'CDS' ) {
    	    return @hits;
    	}
    	$seq = $aa_seq;
    }
    else {
    	my ($taxon_oid, $data_type, $g2) = split(/ /, $gene_oid);
    	$seq = MetaUtil::getGeneFaa($g2, $taxon_oid, $data_type);
    }

    if ( ! $seq ) {
    	return @hits;
    }

    my $top_n = 200;
    my $blast_url = $blast_server_url;
    webLog("blast url: $blast_server_url\n");

    my $ua = WebUtil::myLwpUserAgent(); 
    $ua->timeout(1000); 
    $ua->agent("img2.x/genePageTopHits"); 
    my $db = $img_lid_blastdb; 
    $db = $img_iso_blastdb;

    my $req = POST $blast_url, [ 
    	gene_oid => $blast_gene_oid, 
    	seq      => $seq, 
    	db       => $db, 
    	top_n    => $top_n,           # make large number 
    ]; 
 
    my %done; 
    my $res = $ua->request($req); 
    if ( $res->is_success() ) { 
    	my @lines = split( /\n/, $res->content ); 
    	my $idx = 0; 
    	for my $s (@lines) {
    	    if ( $s =~ /ERROR:/ ) {
        		return @hits;
    	    } 
    	    my ( 
    		$qid,    $sid,      $percIdent, $alen,   $nMisMatch,
    		$nGaps,  $qstart,   $qend,      $sstart, $send,
    		$evalue, $bitScore, $opType
    		) 
    		= split( /\t/, $s ); 
    
    	    my ( $homolog, $staxon, undef ) = split( /_/, $sid );
    	    next if !$validTaxons{$staxon};
    	    next if $done{$sid}; 
    
    	    # check evalue
    	    if ( $maxEvalue && $evalue > $maxEvalue ) {
        		next;
    	    }
    	    # check percent identity
    	    if ( $minPercIdent && $percIdent < $minPercIdent ) {
        		next;
    	    }
    
    	    push @hits, ( $homolog );
    	}
    }

    return @hits;
} 


#####################################################################
# printGeneChrViewerSelection
#####################################################################
sub printGeneChrViewerSelection {
    my $filename = param("filename"); 
    my $folder   = param("directory"); 

    printMainForm();
    print "<h1>Choromosome Map for Selected Genes</h1>\n";

    print hiddenVar('directory', $folder);
    print hiddenVar('folder', $folder);

    my @gene_oids = param('gene_oid');

#    if ( scalar(@gene_oids) > $NUM_OF_BANDS ) {
#        print "<p>";
#        print "Note: there are too many genes, only the first "
#            . $NUM_OF_BANDS . " will be selected.";
#        print "</p>"; 
#    } 

    my $sid = getContactOid();

    if ( $sid == 312 ) {
    	print "<p>*** time1: " . currDateTime() . "\n";
    }

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
 
    printStatusLine( "Loading ...", 1 ); 
    printStartWorkingDiv();
    print "<p>Retrieving gene information ...<br/>\n";
    my $maxGeneListResults = 1000;
    my $cnt = 0; 
    my $trunc = 0;
    my %gene_h;
    my %scaffold_h;
    my %scaffold_band_h;
    for my $id ( @gene_oids ) {
    	if ( $trunc ) {
    	    last;
    	}

    	my $r = "";
    
    	# get gene information
    	my ($t2, $d2, $g2) = split(/ /, $id);
    	if ( $d2 eq 'unassembled' ) {
    	    next;
    	}
    	elsif ( $d2 eq 'assembled' ) {
    	    my ($gene_oid2, $locus_type, $locus_tag, $gene_name,
    		$start_coord, $end_coord, $strand, $scaffold_oid) =
    		    MetaUtil::getGeneInfo($g2, $t2, $d2);
    	    my ($gene_prod_name, $prod_src) = 
        		MetaUtil::getGeneProdNameSource($g2, $t2, $d2);
    	    if ( $gene_prod_name ) { 
        		$gene_name = $gene_prod_name;
    	    } 
    	    $r = "$g2\t$locus_tag\t$gene_name\t$start_coord\t$end_coord\t$strand\t" .
    		"$scaffold_oid\t$filename\t$t2";
    	    my $ws_scaf_id = "$t2 $d2 $scaffold_oid";
    	    $scaffold_h{$ws_scaf_id} = $t2;
    	}
    	elsif ( isInt($id) ) {
    	    my ($gene_oid2, $locus_type, $locus_tag, $gene_name, 
    		    $start_coord, $end_coord, $strand, $scaffold_oid, $taxon_oid) 
    		    = QueryUtil::fetchSingleGeneInfo($dbh, $id, $rclause, $imgClause);
    	    $r = "$id\t$locus_tag\t$gene_name\t$start_coord\t$end_coord\t$strand\t" .
    		"$scaffold_oid\t$filename\t$taxon_oid";
    	    $scaffold_h{$scaffold_oid} = $taxon_oid;
    	}
    	else {
    	    next;
    	}
    
    	$gene_h{$id} = $r;
    
    	if ( scalar(keys %scaffold_h) > $maxScaffolds ) {
    	    #$dbh->disconnect();
    	    printEndWorkingDiv();
    	    webError("There are too many scaffold -- Please limit selection to $maxScaffolds.");
    	    return;
    	}
    
    	$cnt++;
    	if ( ($cnt % 10) == 0 ) {
    	    print ".";
    	}
    
    	if ( $cnt >= $maxGeneListResults ) {
    	    $trunc = 1;
    	    last;
    	}
    }
    print "<br/>\n";
    #$dbh->disconnect();
    printEndWorkingDiv();

    if ( $sid == 312 ) {
    	print "<p>*** time2: " . currDateTime() . "\n";
    }

    my @scaffold_oids = (keys %scaffold_h);
    my $scaffold_str = join(":", @scaffold_oids);

    if ( $trunc ) {
    	printMessage("<font color='red'>There are too many genes -- only $cnt genes are listed.</font>");
    }

    my $it = new InnerTable(1, "chromMap$$", "chromMap", 0); 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Gene ID", "asc", "right", "", "", "wrap" ); 
    $it->addColSpec( "Locus Tag", "asc", "left" ); 
    $it->addColSpec( "Gene Product Name", "asc", "left" ); 
    $it->addColSpec( "Start", "asc", "left" ); 
    $it->addColSpec( "End", "asc", "left" ); 
    $it->addColSpec( "Strand", "asc", "left" ); 
    $it->addColSpec( "Scaffold", "asc", "left" ); 
    $it->addColSpec( "Gene Set", "asc", "left" ); 
    for (my $i=1; $i<= $NUM_OF_BANDS; $i++) { 
        $it->addColSpec( "Band ".$i, "", "", "", "", "wrap" ); 
    } 

    my $band_cnt = 0;
    $cnt = 0;
    for my $workspace_id (keys %gene_h) {
    	my $r = $gene_h{$workspace_id};
    	my ($gene_oid, $locus_tag, $gene_name, $start_coord, $end_coord, $strand,
    	    $scaffold_oid, $filename, $taxon_oid) 
    	    = split(/\t/, $gene_h{$workspace_id});

        my $row = $gene_oid . "\t";
        $row .= $locus_tag . "\t";
        $row .= $gene_name . "\t"; 
        $row .= $start_coord . "\t"; 
        $row .= $end_coord . "\t"; 
        $row .= $strand . "\t"; 
        $row .= $scaffold_oid . "\t"; 
        $row .= $filename . "\t"; 

    	# assign band
        my $circle; 
    	if ( $scaffold_band_h{$scaffold_oid} ) {
    	    $circle = $scaffold_band_h{$scaffold_oid};
    	}
    	else {
    	    if ( $band_cnt < $NUM_OF_BANDS ) {
        		$band_cnt++;
    	    }
    	    $circle = $band_cnt;
    	    $scaffold_band_h{$scaffold_oid} = $band_cnt;
    	}

        for ( my $ch = 1 ; $ch <= $NUM_OF_BANDS ; $ch++ ) { 
            my $check_box_name = "Circle" . $ch; 
 
            $row .= $sd."<input type='checkbox' " 
                  . "name=\"$check_box_name\" " 
                  . "value=\"$workspace_id\" "; 
            $row .= " checked " if ($ch) == $circle; 
            $row .= "/>\t"; 
        } 
        $it->addRow($row); 
    	$cnt++;
    } 

    if ( $cnt == 0 ) {
    	webError("There are no assembled genes in the selections.");
    	return;
    }

    $it->printOuterTable("nopage"); 
 
    print hiddenVar( "section", $section ); 
    print hiddenVar( "scaffolds", $scaffold_str ); 

    my $name = "_section_${section}_drawChromMap";  
    print submit( -name  => $name, 
                  -value => "Draw Map", 
                  -class => "smdefbutton" 
	);

    printStatusLine( "$cnt Loaded.", 2 );

    print end_form();
}

#####################################################################
# printChromosomeViewerSelection
#####################################################################
sub printChromosomeViewerSelection {
    my @filenames = param("filename"); 
    my $folder   = param("directory"); 

    printMainForm();
    print "<h1>Choromosome Map</h1>\n";
    if ( scalar(@filenames) > $NUM_OF_BANDS ) {
        print "<p>";
        print "Note: there are too many batches, only the first "
            . $NUM_OF_BANDS . " will be selected.";
        print "</p>"; 
    } 

    print hiddenVar('directory', $folder);
    print hiddenVar('folder', $folder);

    my $sid = getContactOid();

    if ( $sid == 312 ) {
	print "<p>*** time1: " . currDateTime() . "\n";
    }
 
    printStatusLine( "Loading ...", 1 ); 
    printStartWorkingDiv();
    print "<p>Retrieving gene information ...<br/>\n";

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $maxGeneListResults = 1000;
    my $cnt = 0; 
    my $trunc = 0;
    my %gene_h;
    my %scaffold_h;
    my %scaffold_band_h;
    for my $filename ( @filenames ) {
    	if ( $trunc ) {
    	    last;
    	}

    	print "Processing gene set $filename ...<br/>\n";
    	my $res   = newReadFileHandle("$workspace_dir/$sid/$folder/$filename");
    	my $line_no = 0;
    	while ( my $id = $res->getline() ) {
    	    chomp $id; 
    	    my $r;
    
    	    # get gene information
    	    my ($t2, $d2, $g2) = split(/ /, $id);
    	    if ( $d2 eq 'unassembled' ) {
        		next;
    	    }
    	    elsif ( $d2 eq 'assembled' ) {
        		my ($gene_oid2, $locus_type, $locus_tag, $gene_name,
        		    $start_coord, $end_coord, $strand, $scaffold_oid) =
        			MetaUtil::getGeneInfo($g2, $t2, $d2);
        		my ($gene_prod_name, $prod_src) = 
        		    MetaUtil::getGeneProdNameSource($g2, $t2, $d2);
        		if ( $gene_prod_name ) { 
        		    $gene_name = $gene_prod_name;
        		} 
        		$r = "$g2\t$locus_tag\t$gene_name\t$start_coord\t$end_coord\t$strand\t" .
        		    "$scaffold_oid\t$filename\t$t2";
        		my $ws_scaf_id = "$t2 $d2 $scaffold_oid";
        		$scaffold_h{$ws_scaf_id} = $t2;
    	    }
    	    elsif ( isInt($id) ) {
        	    my ($gene_oid2, $locus_type, $locus_tag, $gene_name, 
        		    $start_coord, $end_coord, $strand, $scaffold_oid, $taxon_oid) 
        		    = QueryUtil::fetchSingleGeneInfo($dbh, $id, $rclause, $imgClause);

        		$r = "$id\t$locus_tag\t$gene_name\t$start_coord\t$end_coord\t$strand\t" .
        		    "$scaffold_oid\t$filename\t$taxon_oid";
        		$scaffold_h{$scaffold_oid} = $taxon_oid;
    	    }
    	    else {
        		next;
    	    }
    
    	    $gene_h{$id} = $r;
    
    	    if ( scalar(keys %scaffold_h) > $maxScaffolds ) {
        		#$dbh->disconnect();
        		printEndWorkingDiv();
        		webError("There are too many scaffold -- Please limit selection to $maxScaffolds.");
        		return;
    	    }
    
    	    $line_no++;
    	    if ( ($line_no % 10) == 0 ) {
        		print ".";
    	    }
    	    if ( ($line_no % 1800) == 0 ) {
        		print "<br/>";
    	    }
    	    if ( $cnt >= $maxGeneListResults ) {
        		$trunc = 1;
        		last;
    	    }
    	}
    }
    print "<br/>\n";
    #$dbh->disconnect();
    printEndWorkingDiv();

    if ( $sid == 312 ) {
	print "<p>*** time2: " . currDateTime() . "\n";
    }

    my @scaffold_oids = (keys %scaffold_h);
    my $scaffold_str = join(":", @scaffold_oids);

    if ( $trunc ) {
    	printMessage("<font color='red'>There are too many genes -- only $cnt genes are listed.</font>");
    }

    my $it = new InnerTable(1, "chromMap$$", "chromMap", 0); 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Gene ID", "asc", "right", "", "", "wrap" ); 
    $it->addColSpec( "Locus Tag", "asc", "left" ); 
    $it->addColSpec( "Gene Product Name", "asc", "left" ); 
    $it->addColSpec( "Start", "asc", "left" ); 
    $it->addColSpec( "End", "asc", "left" ); 
    $it->addColSpec( "Strand", "asc", "left" ); 
    $it->addColSpec( "Scaffold", "asc", "left" ); 
    $it->addColSpec( "Gene Set", "asc", "left" ); 
    for (my $i=1; $i<= $NUM_OF_BANDS; $i++) { 
        $it->addColSpec( "Band ".$i, "", "", "", "", "wrap" ); 
    } 

    my $band_cnt = 0;
    $cnt = 0;
    for my $workspace_id (keys %gene_h) {
    	my $r = $gene_h{$workspace_id};
    	my ($gene_oid, $locus_tag, $gene_name, $start_coord, $end_coord, $strand,
    	    $scaffold_oid, $filename, $taxon_oid) = split(/\t/, $gene_h{$workspace_id});

        my $row = $gene_oid . "\t";
        $row .= $locus_tag . "\t";
        $row .= $gene_name . "\t"; 
        $row .= $start_coord . "\t"; 
        $row .= $end_coord . "\t"; 
        $row .= $strand . "\t"; 
        $row .= $scaffold_oid . "\t"; 
        $row .= $filename . "\t"; 

    	# assign band
        my $circle; 
    	if ( $scaffold_band_h{$scaffold_oid} ) {
    	    $circle = $scaffold_band_h{$scaffold_oid};
    	}
    	else {
    	    if ( $band_cnt < $NUM_OF_BANDS ) {
        		$band_cnt++;
    	    }
    	    $circle = $band_cnt;
    	    $scaffold_band_h{$scaffold_oid} = $band_cnt;
    	}

        for ( my $ch = 1 ; $ch <= $NUM_OF_BANDS ; $ch++ ) { 
            my $check_box_name = "Circle" . $ch; 
 
            $row .= $sd."<input type='checkbox' " 
                  . "name=\"$check_box_name\" " 
                  . "value=\"$workspace_id\" "; 
            $row .= " checked " if ($ch) == $circle; 
            $row .= "/>\t"; 
        } 
        $it->addRow($row); 
    	$cnt++;
    } 

    if ( $cnt == 0 ) {
    	webError("There are no assembled genes in the selected gene sets.");
    	return;
    }

    $it->printOuterTable("nopage"); 
 
    print hiddenVar( "section", $section ); 
    print hiddenVar( "scaffolds", $scaffold_str ); 

    my $name = "_section_${section}_drawChromMap";  
    print submit( -name  => $name, 
                  -value => "Draw Map", 
                  -class => "smdefbutton" 
	);

    printStatusLine( "$cnt Loaded.", 2 );

    print end_form();
}


##########################################################################
# printChromosomeMap
##########################################################################
sub printChromosomeMap {

    printMainForm(); 
    my @batch_genes; 
    my @circle_batch; 
    my $scaffold_str = param('scaffolds');
    my @scaffolds = split(/\:/, $scaffold_str);
    my @circles; # = ( 'Circle1', 'Circle2', 'Circle3', 'Circle4',
                 #     'Circle5', 'Circle6', 'Circle7', 'Circle8' );

    for (my $i=1; $i<=$NUM_OF_BANDS; $i++) { 
        my $tmp = 'Circle' . $i; 
        push(@circles, $tmp); 
    } 
 
    for ( my $c = 1 ; $c <= scalar(@circles) ; $c++ ) { 
        my $circle = $circles[ $c - 1 ]; 
        if (    param($circle)
		&& param('scaffolds') ) {   
            # genes that belong to circle 1.
            my @circle_genes = param($circle);
            foreach my $gene (@circle_genes) {
        		my ($t2, $d2, $g2) = split(/ /, $gene);
        		if ( $d2 eq 'assembled' && $g2 ) {
        		    $gene = $g2;
        		}
                push @batch_genes, [ $gene, $c ];
            } 
            push @circle_batch, $c; 
        } 
    } 

    if ( param('scaffolds') ) {
        @scaffolds = split( ":", param('scaffolds') );
    } 

    if ( scalar(@batch_genes) > 0 && scalar(@scaffolds) > 0 ) {
    	require CircularMap;
    	CircularMap::draw_pix( \@scaffolds, \@circle_batch, \@batch_genes );
    } 
 
    print end_form(); 
} 


##########################################################################
# printViewProteinDomain
##########################################################################
sub printViewProteinDomain {

    printMainForm(); 
    my @batch_genes = param('gene_oid');

    my $total = scalar(@batch_genes);
    my $max_cnt = $total;
    if ( $total > $maxGeneProfileIds ) {
	print "<p><font color='red'>Too many genes -- only the first " .
	    $maxGeneProfileIds . " are listed.</font>\n";
	$max_cnt = $maxGeneProfileIds;
    }

    my $dbh    = dbLogin(); 
    my $sql = "select locus_tag, gene_display_name from gene where gene_oid = ?";
    my $cnt = 0;
    my @gene_list = ();
    for my $gene_oid ( @batch_genes ) {
	$cnt++;
	if ( $cnt <= 1 ) {
	    print "<p>Order genes to display in the result.\n";
	    print "<table class='img'>\n";
	    print "<th class='img'>Gene ID</th>\n";
	    print "<th class='img'>Locus Tag</th>\n";
	    print "<th class='img'>Gene Name</th>\n";
	    print "<th class='img'>Order</th>\n";
	}

	if ( $cnt > $maxGeneProfileIds ) {
	    last;
	}

	push @gene_list, ( $gene_oid );

	print "<tr class='img'>\n";

	if ( $gene_oid && isInt($gene_oid) ) {
	    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	    my ($locus_tag, $gene_name) = $cur->fetchrow();
	    $cur->finish();

	    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
	    print "<td class='img'>" . alink($url, $gene_oid) . "</td>\n";
	    print "<td class='img'>$locus_tag</td>\n";
	    print "<td class='img'>$gene_name</td>\n";
	}
	else {
	    my ($t3, $d3, $g3) = split(/ /, $gene_oid);
	    if ( isInt($t3) ) {
		my ($g_name, $g_src) = MetaUtil::getGeneProdNameSource($g3, $t3,
								       $d3);
		my $url = "$main_cgi?section=MetaGeneDetail&page=geneDetail" .
		    "&taxon_oid=$t3&data_type=$d3&gene_oid=$g3";

		print "<td class='img'>" . alink($url, $g3) . "</td>\n";
		print "<td class='img'>$g3</td>\n";
		print "<td class='img'>$g_name</td>\n";
	    }
	    else {
		print "<td class='img'>$gene_oid</td>\n";
		print "<td class='img'>-</td>\n";
		print "<td class='img'>-</td>\n";
	    }
	}
	print "<td class='img'>";
	my $sel_name = "order_" . $gene_oid;
	print "<select name='" . $sel_name . "'>\n";
	for (my $j = 1; $j <= $max_cnt; $j++) {
	    print "<option value='" . $j . "' ";
	    if ( $j == $cnt ) {
		print " selected ";
	    }
	    print ">" . $j . "</option>\n";
	}
	print "</select>\n";
	print "</td>\n";
	print "</tr>\n";
    }

    if ( $cnt ) {
	print "</table>\n";
    }
    else {
	print "<h5>Error: No genes have been selected.</h5>\n";
	print end_form();
	return;
    }

    for my $gene_oid ( @gene_list ) {
	print hiddenVar( "gene_oid", $gene_oid ); 
    }
    print hiddenVar( "max_cnt", $max_cnt ); 

    print "<p><input type='checkbox' name='domain_only' value='1' /> " .
	"Show Domain Only? \n";
    print nbsp(3);
    print "<input type='checkbox' name='show_bbh' value='1' /> " .
	"Also Show Best Hits? <br/>\n";
    print "<p>\n";
    my $name = "_section_WorkspaceGeneSet_listProteinDomainResult"; 
    print submit( 
            -name  => $name, 
            -value => 'List Protein Domains', 
            -class => 'meddefbutton' 
            ); 
    print "<br/>\n";
    
    print end_form(); 
} 


##########################################################################
# printListProteinDomainResult
##########################################################################
sub printListProteinDomainResult {

    printMainForm(); 

    print "<h1>Protein Domains of Selected Genes</h1>\n";

    my @batch_genes = param('gene_oid');
    my $max_cnt = param('max_cnt');
    my $domain_only = param('domain_only');
    my $show_bbh = param('show_bbh');
    my %gene_h;

    for my $gene_oid ( @batch_genes ) {
	my $sel_name = "order_" . $gene_oid;
	my $order = param($sel_name);
	if ( $gene_h{$order} ) {
	    $gene_h{$order} .= "\n" . $gene_oid;
	}
	else {
	    $gene_h{$order} = $gene_oid;
	}
    }

    my $dbh = dbLogin();

    my %public_taxons;
    if ( $show_bbh ) {
	my $sql = qq{
            select taxon_oid, taxon_display_name
            from taxon
            where is_public = 'Yes'
            and obsolete_flag = 'No'
            and genome_type = 'isolate'
	}; 
	my $cur = execSql($dbh, $sql, $verbose);
	for ( ;; ) {
	    my ($taxon_oid, $taxon_name) = $cur->fetchrow();
	    last if(!$taxon_oid);
	    $public_taxons{$taxon_oid} = $taxon_name; 
	} 
	$cur->finish();
    }

    print "<table>\n";
    print "<tr class='highlight'>\n"; 
    print "<th class='img'>Gene</th>\n";
    print "<th class='img'>Protein Domain</th>\n";
    if ( $show_bbh ) {
	print "<th class='img'>Best Hit</th>\n";
	print "<th class='img'>Best Hit Genome</th>\n";
    }
    print "</tr>\n"; 

    for (my $i = 1; $i <= $max_cnt; $i++) {
	my @genes = split(/\n/, $gene_h{$i});
	for my $g2 ( @genes ) {
	    if ( isInt($g2) ) {
		my ($sql2, @bindList) = 
		    FunctionAlignmentUtil::getPfamSqlForGene($g2, undef,
							     "", ""); 
		my ($cnt, $recs_ref, $doHmm) =
		    FunctionAlignmentUtil::execPfamSearch( $dbh, $sql2,
							   \@bindList); 
		my $count = printPfamResults_pd( $dbh, $cnt, 
						 $recs_ref, $doHmm,
						 $domain_only, $show_bbh, 
						 \%public_taxons); 
	    }
	    else {
		my @recs = ();
		my ($t3, $d3, $g3) = split(/ /, $g2);
		if ( isInt($t3) ) {
		    my @pfams = MetaUtil::getGenePfamId($g3, $t3, $d3);
		    my $pfam_sql = "select name, description from pfam_family " .
			"where ext_accession = ?";
		    for my $p2 ( @pfams ) {
			my $cur = execSql( $dbh, $pfam_sql, $verbose, $p2 );
			my ($p_name, $p_desc) = $cur->fetchrow();
			$cur->finish();

			my $r2 = "$g2\t$p2\t$p_name\t$p_desc\t";
			push @recs, ( $r2 );
		    }
		}
		my $cnt = scalar(@recs);
		my $count = printPfamResults_pd( $dbh, $cnt, 
						 \@recs, 0, $domain_only, 
						 $show_bbh, \%public_taxons );
	    }
	}
    }

    print "</table>\n"; 

    print end_form(); 
} 

sub printPfamResults_pd { 
    my ( $dbh, $cnt, $recs_ref, $doHmm, $domain_only, 
	 $show_bbh, $public_taxons ) = @_;
    my @recs = @$recs_ref; 

    return $cnt if ( $cnt == 0 ); 

    my $bbh_sql = qq{
        select dt.homolog, t.taxon_oid, t.taxon_display_name
        from dt_phylum_dist_genes dt, taxon t
        where dt.gene_oid = ?
        and dt.homolog_taxon = t.taxon_oid
    };

    my $taxon_name_sql = qq{
        select taxon_display_name from taxon
        where obsolete_flag = 'No' and taxon_oid = ?
        };
    my $genome_type_sql = qq{
        select t.taxon_oid, t.genome_type 
        from taxon t, gene g
        where t.obsolete_flag = 'No' 
        and t.taxon_oid = g.taxon
        and g.gene_oid = ?
        };

    my %cc_h;
    my $cc_sql = "select compound_class from biosynth_signatures " .
	"where source_id = ?";
    my $gene_sql = "select locus_tag, gene_display_name from gene " .
	"where gene_oid = ?";

    my $pfam_sql = "select name, description from pfam_family " .
	"where ext_accession = ?";

    my $count = 0; 
    my $prev_gene_id = 0;
    for my $r (@recs) {
        my ( 
             $gene_oid,    $ext_accession,    
#	     $name, $description, 
	     $percent_identity, $query_start,
             $query_end,   $aa_seq_length, 
             $evalue,      $bit_score,
             $taxon_oid,   $taxon_display_name
          ) 
	    = split( /\t/, $r ); 
        $count++; 

	my $cur = execSql( $dbh, $pfam_sql, $verbose, $ext_accession );
	my ($name, $description) = $cur->fetchrow();
	$cur->finish();

	if ( $gene_oid != $prev_gene_id ) {
	    if ( $prev_gene_id ) {
		if ( ! $domain_only ) {
		    print "</table>\n";
		}

		print "</td>";
		if ( $show_bbh ) {
		    my $genome_type = 'metagenome';
		    my $taxon_oid = 0;
		    if ( isInt($prev_gene_id) ) {
			my $cur2 = execSql( $dbh, $genome_type_sql, $verbose, $prev_gene_id );
			($taxon_oid, $genome_type) = $cur2->fetchrow();
			$cur2->finish();
		    }

		    if ( isInt($prev_gene_id) && $genome_type eq 'isolate' ) {
#			my $cur2 = execSql( $dbh, $bbh_sql, $verbose, $prev_gene_id );
#			my ($homolog, $h_taxon, $h_taxon_name) = $cur2->fetchrow();
			my $res = getGeneBestHit_bbh($taxon_oid, $prev_gene_id,
						     $public_taxons);
			my ($homolog, $h_taxon) = split("\t", $res);

			if ( $homolog && $h_taxon ) {
			    my $h_taxon_name = $public_taxons->{$h_taxon};
			    my $url2 = "$main_cgi?section=GeneDetail" .
				"&page=geneDetail&gene_oid=$homolog";
			    print "<td class='img'>" . alink($url2, $homolog) . 
				"</td>\n";
			    my $url3 = "$main_cgi?section=TaxonDetail" .
				"&page=taxonDetail&taxon_oid=$h_taxon";
			    print "<td class='img>" . alink($url3, $h_taxon_name) . 
				"</td>\n";
			}
			else {
			    print "<td class='img'>-</td><td class='img'>-</td>\n";
			}
#			$cur2->finish();
		    }
		    else {
			# metagenome
			my ($t2, $d2, $g2) = split(/ /, $prev_gene_id);
			if ( ! $g2 ) {
			    $t2 = $taxon_oid;
			    $d2 = 'assembled';
			    $g2 = $prev_gene_id;
			}

			my $bbh = MetaUtil::getGeneBBH($t2, $d2, $g2);
			if ( $bbh ) { 
			    my ($id2, $perc, $homolog, $h_taxon, @rest) = 
				split(/\t/, $bbh); 
			    if ( $homolog && $h_taxon ) {
				my $t_cur = execSql( $dbh, $taxon_name_sql, 
						     $verbose, $h_taxon );
				my ($h_taxon_name) = $t_cur->fetchrow();
				$t_cur->finish();

				if ( $h_taxon_name ) {
				    my $url2 = "$main_cgi?section=GeneDetail" .
					"&page=geneDetail&gene_oid=$homolog";
				    print "<td class='img'>" . alink($url2, $homolog) . 
					"</td>\n";
				    my $url3 = "$main_cgi?section=TaxonDetail" .
					"&page=taxonDetail&taxon_oid=$h_taxon";
				    print "<td class='img>" . alink($url3, $h_taxon_name) . 
					"</td>\n";
				}
				else {
				    print "<td class='img'>-</td><td class='img'>-</td>\n";
				}
			    }
			    else {
				print "<td class='img'>-</td><td class='img'>-</td>\n";
			    }
			}
			else {
			    print "<td class='img'>-</td><td class='img'>-</td>\n";
			}
		    }
		}
		print "</tr>\n";
	    }

	    print "<tr class='img'>\n";
	    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";

	    if ( isInt($gene_oid) ) {
		my $cur = execSql( $dbh, $gene_sql, $verbose, $gene_oid );
		my ($locus_tag, $gene_name) = $cur->fetchrow();
		$cur->finish();

		my $geneLink .= alink( $url, $gene_oid );
		print "<td class='img' >" . $geneLink . 
		    "<br/>Locus Tag: $locus_tag" . "<br/> $gene_name " .
		    "</td>\n";
	    }
	    else {
		my ($t3, $d3, $g3) = split(/ /, $gene_oid);
		$url = "$main_cgi?section=MetaGeneDetail&page=geneDetail" .
		    "&taxon_oid=$t3&data_type=$d3&gene_oid=$g3";
		my ($g_name, $g_src) = MetaUtil::getGeneProdNameSource($g3, $t3,
								       $d3);
		
		my $geneLink .= alink( $url, $g3 );
		print "<td class='img' >" . $geneLink . 
		    "<br/>Locus Tag: $g3" . "<br/> $g_name " .
		    "</td>\n";
	    }

	    print "<td class='img'>\n";
	    if ( ! $domain_only ) {
		print "<table>\n";
	    }
	    $prev_gene_id = $gene_oid;
	}

	if ( $domain_only ) {
	    print escHtml($name) . "<br/>";
	    next;
	}

	print "<tr class='img'><td class='img'>\n";
	print escHtml($name) . "</td>\n";
 
        my $ext_accession2 = $ext_accession;
        $ext_accession2 =~ s/pfam/PF/;
        my $url = "$pfam_base_url$ext_accession2";
        print "<td class='img'>" . alink( $url, $ext_accession ) .
	    "</td>\n";
 
        my @sentences = split( /\. /, $description );
        my $description2 = $sentences[0];
        print "<td class='img'>" . escHtml($description2) . 
	    "</td>";

	# compound class
	my $cc = $cc_h{$ext_accession};
	if ( ! $cc ) {
	    my $cur = execSql( $dbh, $cc_sql, $verbose, $ext_accession );
	    ($cc) = $cur->fetchrow();
	    $cur->finish();
	    $cc_h{$ext_accession} = $cc;
	}
	if ( $cc ) {
	    print "<td class='img'>" . escHtml($cc) . 
		"</td>";
	}
	print "<tr/>\n";
    } 

    if ( $prev_gene_id ) {
	if ( ! $domain_only ) {
	    print "</table>\n";
	}
	print "</td>\n";
	if ( $show_bbh ) {
	    my $genome_type = 'metagenome';
	    my $taxon_oid = 0;
	    if ( isInt($prev_gene_id) ) {
		my $cur2 = execSql( $dbh, $genome_type_sql, $verbose, $prev_gene_id );
		($taxon_oid, $genome_type) = $cur2->fetchrow();
		$cur2->finish();
	    }

	    if ( isInt($prev_gene_id) && $genome_type eq 'isolate' ) {
#		my $cur2 = execSql( $dbh, $bbh_sql, $verbose, $prev_gene_id );
#		my ($homolog, $h_taxon, $h_taxon_name) = $cur2->fetchrow();
		my $res = getGeneBestHit_bbh($taxon_oid, $prev_gene_id,
					     $public_taxons);
		my ($homolog, $h_taxon) = split("\t", $res);

		if ( $homolog && $h_taxon ) {
		    my $h_taxon_name = $public_taxons->{$h_taxon};
		    my $url2 = "$main_cgi?section=GeneDetail" .
			"&page=geneDetail&gene_oid=$homolog";
		    print "<td class='img'>" . alink($url2, $homolog) . 
			"</td>\n";
		    my $url3 = "$main_cgi?section=TaxonDetail" .
			"&page=taxonDetail&taxon_oid=$h_taxon";
		    print "<td class='img'>" . alink($url3, $h_taxon_name) . 
			"</td>\n";
		}
		else {
		    print "<td class='img'>-</td><td class='img'>-</td>\n";
		}
#		$cur2->finish();
	    }
	    else {
		# metagenome
		my ($t2, $d2, $g2) = split(/ /, $prev_gene_id);
		if ( ! $g2 ) {
		    $t2 = $taxon_oid;
		    $d2 = 'assembled';
		    $g2 = $prev_gene_id;
		}

		my $bbh = MetaUtil::getGeneBBH($t2, $d2, $g2);
		if ( $bbh ) { 
		    my ($id2, $perc, $homolog, $h_taxon, @rest) = 
			split(/\t/, $bbh); 
		    if ( $homolog && $h_taxon ) {
			my $t_cur = execSql( $dbh, $taxon_name_sql, 
					     $verbose, $h_taxon );
			my ($h_taxon_name) = $t_cur->fetchrow();
			$t_cur->finish();

			if ( $h_taxon_name ) {
			    my $url2 = "$main_cgi?section=GeneDetail" .
				"&page=geneDetail&gene_oid=$homolog";
			    print "<td class='img'>" . alink($url2, $homolog) . 
				"</td>\n";
			    my $url3 = "$main_cgi?section=TaxonDetail" .
				"&page=taxonDetail&taxon_oid=$h_taxon";
			    print "<td class='img'>" . alink($url3, $h_taxon_name) . 
				"</td>\n";
			}
			else {
			    print "<td class='img'>-</td><td class='img'>-</td>\n";
			}
		    }
		    else {
			print "<td class='img'>-</td><td class='img'>-</td>\n";
		    }
		}  # end if bbh
		else {
		    print "<td class='img'>-</td><td class='img'>-</td>\n";
		}
	    }
	}
	print "</tr>\n";
    }
 
    return $count; 
} 


###########################################################
# getGeneBestHit_bbh: get gene best hit from bbh_zfiles
###########################################################
sub getGeneBestHit_bbh {
    my ($taxon_oid, $gene_oid, $public_taxons) = @_;

    my $res = "";

    my $bbh_dir = $env->{bbh_zfiles_dir}; 
    $taxon_oid = sanitizeInt($taxon_oid); 
    my $bbh_file_name = $bbh_dir . "/" . $taxon_oid . ".zip"; 
 
    if ( ! blankStr($bbh_file_name) && (-e $bbh_file_name) ) {
	# yes, we have file
    } 
    else { 
        return; 
    }

    # open file
    my $rfh = newUnzipFileHandle 
	( $bbh_file_name, $gene_oid, "getBBHZipFiles" ); 
    while ( my $s = $rfh->getline() ) { 
    	chomp $s; 
    	my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
    	     $qstart, $qend, $sstart, $send, $evalue, $bitScore )
    	    = split( /\t/, $s );
    	my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
    	my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
     
    	if ( $staxon && $public_taxons->{$staxon} ) {
    	    $res = "$sgene_oid\t$staxon";
    	    last;
    	} 
    }  # end while                                                                         
    close $rfh; 
 
    WebUtil::resetEnvPath();
    return $res;
}




1;
