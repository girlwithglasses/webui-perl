########################################################################
# WorkspaceFuncSet.pm                                                   
########################################################################
package WorkspaceFuncSet; 

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
use GenomeListFilter;
use MetaUtil; 
use HashUtil; 
use MetaGeneTable; 
use TabHTML;
use Workspace;
use WorkspaceUtil;
use WorkspaceQueryUtil;
use MerFsUtil;
use QueryUtil;
use FuncUtil;
 
 
$| = 1; 
 
my $section              = "WorkspaceFuncSet"; 
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
my $enable_genomelistJson = $env->{enable_genomelistJson};
my $YUI                   = $env->{yui_dir_28};
 
my $cog_base_url       = $env->{cog_base_url};
my $pfam_base_url      = $env->{pfam_base_url};
my $tigrfam_base_url   = $env->{tigrfam_base_url};
my $enzyme_base_url    = $env->{enzyme_base_url};
my $kegg_orthology_url = $env->{kegg_orthology_url};
 
my $mer_data_dir      = $env->{mer_data_dir};
my $taxon_lin_fna_dir = $env->{taxon_lin_fna_dir};
my $cgi_tmp_dir       = $env->{cgi_tmp_dir};
 
my $essential_gene    = $env->{essential_gene};


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
my $GENOME_FOLDER   = "genome"; 

my $max_workspace_view = 10000; 
my $max_profile_select = 50;
my $maxProfileOccurIds     = 100;

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
    return if ( $sid == 0 ||  $sid < 1 || $sid eq '901'); 
 
    # TODO check if workspace area is available - ken                          
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
        printFuncSetDetail(); 
    }
    elsif ( $page eq "showFuncSetScaffoldSearch" ||
            paramMatch("showFuncSetScaffoldSearch") ) { 
        showFuncSetScaffoldSearch(); 
    }
    elsif ( $page eq "showFuncScaffoldSearch" ||
            paramMatch("showFuncScaffoldSearch") ) { 
        showFuncScaffoldSearch(); 
    }
    elsif ( $page eq "showFuncSetGeneProfile" ||
            paramMatch("showFuncSetGeneProfile") ) { 
        showFuncSetGeneProfile(); 
    }
    elsif ( $page eq "showFuncGeneProfile" ||
            paramMatch("showFuncGeneProfile") ) { 
        showFuncGeneProfile(); 
    }
    elsif ( $page eq "showFuncGenomeProfile" ||
            paramMatch("showFuncGenomeProfile") ) { 
        showFuncGenomeProfile(); 
    }
    elsif ( $page eq "showFuncGenomeTreeProfile" ||
            paramMatch("showFuncGenomeTreeProfile") ) { 
        showFuncGenomeTreeProfile(); 
    }
    elsif ( $page eq "geneFuncSetList" ||
            paramMatch("geneFuncSetList") ) { 
	    listFuncInSetForGene();
    }
    elsif ( $page eq "funcOccurProfiles" ||
            paramMatch("funcOccurProfiles") ) { 
	    printPhyloOccurProfiles();
    }
    elsif ( $page eq "showPwayAssertionProfile_s" ||
	    paramMatch("showPwayAssertionProfile_s") ne "" ) {
        printPwayAssertionProfile_s();
    }
    elsif ( $page eq "showPwayAssertionProfile_t" ||
	    paramMatch("showPwayAssertionProfile_t") ne "" ) {
        printPwayAssertionProfile_t();
    }
    elsif ( $page eq "essentialGeneProfile" ||
            paramMatch("essentialGeneProfile") ) { 
	    printEssentialGeneProfiles();
    } 
    elsif ( paramMatch("submitFuncScafSearch") ne ""
        || $page eq "submitFuncScafSearch" )
    {
        submitJob('func_scaf_search');
    }    
    else {
	    printFuncSetMainForm();
    }
}


############################################################################
# printFuncSetMainForm
############################################################################
sub printFuncSetMainForm {
    my ($text) = @_;

    my $folder = $FUNC_FOLDER;

    my $sid = getContactOid(); 
    opendir( DIR, "$workspace_dir/$sid/$folder" ) 
        or webDie("failed to open folder list");
    my @files = readdir(DIR);
    closedir(DIR); 

    print "<h1>My Workspace - Function Sets</h1>"; 

    print qq{
        <script type="text/javascript" src="$base_url/Workspace.js" >
        </script>
    }; 
 
    print $text; 

    printMainForm(); 
 
    my $super_user_flag = getSuperUser(); 

    TabHTML::printTabAPILinks("funcsetTab"); 
    my @tabIndex = ( "#funcsettab1", "#funcsettab2", "#funcsettab3", "#funcsettab4", "#funcsettab5" );
    my @tabNames = ( "Function Sets", "Import & Export", "Scaffold Search", "Gene Profile", "Set Operation" );
    TabHTML::printTabDiv("funcsetTab", \@tabIndex, \@tabNames);

    print "<div id='funcsettab1'>";
    WorkspaceUtil::printShareMainTable($section_cgi, $section, 
		       $workspace_dir, $sid, $folder, @files);
    print hiddenVar( "directory", "$folder" );
    print "</div>\n";

    print "<div id='funcsettab2'>";
    # Import/Export
    Workspace::printImportExport($folder);
    print "</div>\n";

    print "<div id='funcsettab3'>";
    print "<h2>Function Scaffold Search</h2>\n"; 

    my $onCLickValidation;
    if ( $enable_genomelistJson ) {
        WorkspaceUtil::printGenomeListForm();
        $onCLickValidation = "return myValidationBeforeSubmit2('$folder', 'selectedGenome1', '1', '', '');";
    } 
    else {
        printHint(   "- Hold down the control key (or command key in the case of the Mac) "
                   . "to select multiple genomes.<br/>\n"
                   . "- Drag down list to select all genomes.<br/>\n"
                   . "- More genome and function selections result in slower query.\n" );
        print "<br/>";
        my $dbh = dbLogin();
        if ($include_metagenomes) {
            GenomeListFilter::appendGenomeListFilter( $dbh, '', 1, '', 'Yes', '', 1 );
        } else {
            GenomeListFilter::appendGenomeListFilter( $dbh, '', 1, '', 'Yes', '' );
        }
        $onCLickValidation = "return checkSetsIncludingShare('$folder');";
    }
    HtmlUtil::printMetaDataTypeChoice('_f', '', 1);

    print submit(
        -name    => "_section_WorkspaceFuncSet_showFuncSetScaffoldSearch", 
        -value   => "Workspace Function-Scaffold Search",
        -class => "lgbutton",
        -onClick => $onCLickValidation
    );

    require WorkspaceJob;
    my ($genomeFuncSets_ref, $genomeBlastSets_ref, $genomePairwiseANISets_ref, $geneFuncSets_ref, 
        $scafFuncSets_ref, $scafHistSets_ref, $scafKmerSets_ref, $scafPhyloSets_ref, $funcScafSearchSets_ref, 
        $genomeSaveFuncGeneSets_ref, $geneSaveFuncGeneSets_ref, $scafSaveFuncGeneSets_ref)
        = WorkspaceJob::getExistingJobSets();

    Workspace::printSubmitComputation( $sid, $folder, 'func_scaf_search', 
        '_section_WorkspaceFuncSet_submitFuncScafSearch', '', $funcScafSearchSets_ref );

    print "</div>\n";

    print "<div id='funcsettab4'>";
    print "<h2>Function Set Gene Profile</h2>\n"; 
    printHint("Limit number of function set selections to avoid timeout."); 

    print "<p>Using genes in Gene Set: \n"; 
    print "&nbsp;\n"; 
    print "<select name='gene_set_name'>\n"; 
    Workspace::printSetSelectOptions( $sid, $GENE_FOLDER );    
    print "</select>\n"; 
 
    print nbsp(5); 
    print "<input type='checkbox' name='show_zero_count' />"; 
    print nbsp(1); 
    print "Show zero count?\n"; 
 
    # submit button                                                                                              
    print "<p>\n"; 
    print submit( 
    	-name  => "_section_WorkspaceFuncSet_showFuncSetGeneProfile", 
    	-value => "Workspace Function-Gene Profile", 
    	-class => "lgbutton",
        -onClick => "return checkSetsIncludingShare('$folder');"
	); 
    print "</div>\n";

    print "<div id='funcsettab5'>";
    Workspace::printSetOperation($folder, $sid);
    print "</div>\n";

    TabHTML::printTabDivEnd();

    print end_form();

}


###############################################################################
# printFuncSetDetail
###############################################################################
sub printFuncSetDetail { 
    my $filename = param("filename"); 
    my $folder   = param("folder"); 
 
    printMainForm(); 
 
    my $super_user_flag = getSuperUser(); 

    my $sid = getContactOid();
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
                last; 
            } 
        } 
 
        if ( ! $can_view ) { 
            print "<h1>My Workspace - Function Sets - Individual Function Set</h1>"; 
            print "<p><u>File Name</u>: " . escapeHTML($filename) . "</p>";
            webError("Function set does not exist.");
            return; 
        }
    } 

    print "<h1>My Workspace - Function Sets - Individual Function Set</h1>"; 
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
 
    # this also untaints the name
    $filename = WebUtil::validFileName($filename);
    my $select_id_name = "func_id";
 
    my $full_path_name = "$workspace_dir/$sid/$folder/$filename"; 
    if ( $owner ) {
        $full_path_name = "$workspace_dir/$owner/$folder/$filename";
    } 
    if ( ! (-e $full_path_name) ) { 
        webError("Function set does not exist."); 
        return;
    } 
 
    my %names; 
    my @db_ids = (); 
 
    my $row   = 0;
    my $trunc = 0;
    my $res   = newReadFileHandle($full_path_name);
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

=pod 
    TabHTML::printTabAPILinks("funcsetTab"); 
    my @tabIndex = ( "#funcsettab1", "#funcsettab2", "#funcsettab3", 
		     "#funcsettab4", "#funcsettab5" );
    my @tabNames = ( "Functions", "Save", "Profiles", 
		     "Analysis", "Set Operation" );
    TabHTML::printTabDiv("funcsetTab", \@tabIndex, \@tabNames);
=cut

    print "<div id='funcsettab1'>";
    print "<p>\n"; 
 
    printStartWorkingDiv();
    print "Retrieving function information ...<br/>\n";
 
    my $it = new InnerTable( 1, "funcSet$$", "funcSet", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Function ID",   "char asc", "left" );
    $it->addColSpec( "Name", "char asc", "left" ); 
    my $sd = $it->getSdDelim(); 
 
    my @keys           = ( keys %names );
     
    for my $id (@keys) { 
    	my $name = Workspace::getMetaFuncName($id);
    	if ( $name ) {
    	    $names{$id} = $name;
    	}
    	else { 
    	    $names{$id} = "-";
    	}
    
        # make url
        my $detail_url = "";
        my $id_lower = lc $id;
        if (substr( $id_lower, 0, 4 ) eq "tigr" ) {
            $detail_url = "http://cmr.jcvi.org/tigr-scripts/CMR/HmmReport.cgi?hmm_acc=$id";
        } elsif ( substr( $id_lower, 0, 3 ) eq "kog" ) {
            $detail_url = "http://www.ncbi.nlm.nih.gov/COG/grace/shokog.cgi?$id";
        } elsif ( substr( $id_lower, 0, 3 ) eq "cog" ) {
            $detail_url = "http://www.ncbi.nlm.nih.gov/COG/grace/wiew.cgi?$id";
        } elsif ( substr( $id_lower, 0, 4 ) eq "pfam" ) {
            $detail_url = "http://pfam.sanger.ac.uk/family/PF" . substr($id, 4);
        } elsif ( substr( $id_lower, 0, 3 ) eq "ko:" ) {
            # KEGG
            $detail_url = "http://www.genome.jp/dbget-bin/www_bget?ko+" . $id;
        } elsif ( substr( $id_lower, 0, 3 ) eq "tc:" ) {
            # Transporter class 
            $detail_url = "http://www.tcdb.org/search/result.php?tc=" . substr($id, 3);
        } elsif ( substr( $id_lower, 0, 6 ) eq "netwk:" ) {
            # IMG Networks
            my $img_networks_number = substr($id, 6);
            $detail_url = $main_cgi . "?section=ImgNetworkBrowser&page=pathwayNetworkDetail&network_oid=" . $img_networks_number;
        } elsif ( substr( $id_lower, 0, 6 ) eq "ipway:" ) {
            # IMG Pathway
            my $img_networks_number = substr($id, 6);
            $detail_url = $main_cgi . "?section=ImgPwayBrowser&page=imgPwayDetail&pway_oid=" . $img_networks_number;
        } elsif ( substr( $id_lower, 0, 6 ) eq "plist:" ) {
            # IMG Parts List
            my $img_networks_number = substr($id, 6);
            $detail_url = $main_cgi . "?section=ImgPartsListBrowser&page=partsListDetail&parts_list_oid=" . $img_networks_number;
        } elsif ( substr( $id_lower, 0, 6 ) eq "iterm:" ) {
            # IMG Term
            my $img_networks_number = substr($id, 6);
            $detail_url = $main_cgi . "?section=ImgTermBrowser&page=imgTermDetail&term_oid=" . $img_networks_number;
        } else {
            $detail_url = "";
        }
        my $id_with_link = "";
        if ($detail_url eq "") {
            $id_with_link = $id;
        } else {
            $id_with_link = "<a href=\"$detail_url\" target=\"_blank\" >" . $id . "</a>";
        }

    	my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$id' checked /> \t";
     	$r .= $id . $sd . $id_with_link . "\t";
    	$r .= $names{$id} . $sd . $names{$id} . "\t";
 
        $it->addRow($r); 
    } 
 
    printEndWorkingDiv(); 

    if ($row > 10) {
        WebUtil::printFuncCartFooter();
    } 
  
    $it->printOuterTable(1);
 
    my $load_msg = "$row function(s) loaded."; 
 
    printStatusLine( $load_msg, 2 );
    if ( ! $row ) {
        print end_form();
        return;
    }

    WebUtil::printFuncCartFooter();

    print "</div>\n";

    print "<div id='funcsettab2'>";
    WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    print "</div>\n";



    print end_form(); 
} 

#############################################################################
# showFuncSetScaffoldSearch
#############################################################################
sub showFuncSetScaffoldSearch {

    my $sid = getContactOid();

    my $folder = param("directory");

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);
    if ( scalar(@all_files) == 0 ) {
        print "<p>No workspace files are selected.\n";
        return;
    }

    my %set2funcs;     # all func_ids in a function set
    my %all_func_ids;         # func_ids in all selected sets
    for my $x2 ( @all_files ) {    
        my ($c_oid, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
        open( FH, "$workspace_dir/$c_oid/$folder/$x" )
            or webError("File size - file error $x"); 

        my %funcs_h;
        while ( my $line = <FH> ) {
            chomp($line);
            $all_func_ids{$line} = 1;
            $funcs_h{$line} = 1;
        }
        close FH;
        my @funcs = keys %funcs_h;
        $set2funcs{$x2} = \@funcs;
        #print "showFuncSetScaffoldSearch() funcs in $x: @funcs<br/>\n";
    }

    my @func_ids = keys %all_func_ids;
    if ( scalar(@func_ids) <= 0 ) {
        @func_ids = param('func_id');
    }
    if ( scalar(@func_ids) == 0 ) {
        webError("No functions are selected.");
        return;
    }

    my @selected_funcs;
    my $col_count = 1;
    my $truncated_cols = 0;
    for my $func_id ( @func_ids ) {
        if ( $col_count > $max_profile_select ) {
            $truncated_cols = 1;
            last;
        }
        push(@selected_funcs, $func_id );
        $col_count++;
    }
    @selected_funcs = sort(@selected_funcs);
        
    my $data_type = param('data_type_f');

    my @taxon_oids;
    if ($enable_genomelistJson) {
        @taxon_oids = param("selectedGenome1");
    }
    else {
        @taxon_oids = OracleUtil::processTaxonBinOids("t");
    }
    if ( scalar(@taxon_oids) == 0 ) {
        webError("No genomes are selected.");
        return;
    }        

    my ( $func_names_href, $taxon2name_href, $taxon_in_file_href, $taxon_db_href, 
        $dbScaf2name_href, $taxon_scaffolds_href, $scaf_func2genes_href, 
        $timeout_msg ) 
        = processFuncScaffoldSearch( \@selected_funcs, $data_type, \@taxon_oids );

    printFuncScaffoldSearch( $sid, \%set2funcs,
        \@selected_funcs, $data_type, \@taxon_oids, 
        $func_names_href, $taxon2name_href, $taxon_in_file_href, $taxon_db_href, 
        $dbScaf2name_href, $taxon_scaffolds_href, $scaf_func2genes_href, 
        $truncated_cols, $timeout_msg );
}

#############################################################################
# processFuncScaffoldSearch
#############################################################################
sub processFuncScaffoldSearch {
    my ( $selected_funcs_ref, $data_type, $taxon_oids_ref ) = @_;

    my @func_groups = QueryUtil::groupFuncIdsIntoOneArray( $selected_funcs_ref );

    # get function names
    my $dbh = dbLogin();
    my %func_names = QueryUtil::fetchFuncIdAndName( $dbh, $selected_funcs_ref );

    my ($taxon2name_href, $taxon_in_file_href, $taxon_db_href, $taxon_oids_str) 
        = QueryUtil::fetchTaxonsOidAndNameFile($dbh, $taxon_oids_ref);

    printStartWorkingDiv();

    require WorkspaceScafSet;

    my %dbScaf2name_h;
    my %taxon_scaffolds_h;
    my %scaf_func2genes_h;

    if ( scalar(keys %$taxon_db_href) > 0 ) {
        my @dbTaxons = keys %$taxon_db_href;
        my ($scaffolds_href, $id2name_href, $taxon_scaffolds_href) = QueryUtil::fetchGenomeScaffoldOidsHash( $dbh, @dbTaxons );
        %dbScaf2name_h = %$id2name_href;
        %taxon_scaffolds_h = %$taxon_scaffolds_href;

        my @scaffolds = keys %$scaffolds_href;
        WorkspaceScafSet::countDbScafFuncGene( $dbh, \@scaffolds, \@func_groups, \%scaf_func2genes_h );
    }
    #print "showFuncScaffoldSearch() db scaf_func2genes_h<br/>\n";
    #print Dumper(\%scaf_func2genes_h)."<br/>\n";

    timeout( 60 * $merfs_timeout_mins );
    my $start_time = time(); 
    my $timeout_msg;

    if ( scalar(keys %$taxon_in_file_href) > 0 ) {
        my @metaTaxons = keys %$taxon_in_file_href;
        foreach my $taxon_oid ( @metaTaxons ) {
            print "Computing function count for genome $taxon_oid scaffolds ... <br/>\n";
            WorkspaceScafSet::countMetaTaxonScafFuncGene( $dbh, $taxon_oid, $data_type, \@func_groups, \%scaf_func2genes_h, \%taxon_scaffolds_h );

            if ( (($merfs_timeout_mins * 60) -
                  (time() - $start_time)) < 200 ) {
                $timeout_msg = "Process takes too long to run " . 
                "-- stopped at taxon $taxon_oid. " . 
                "Only partial result is displayed."; 
                last; 
            }
        }
    }
    #print "showFuncScaffoldSearch() meta scaf_func2genes_h<br/>\n";
    #print Dumper(\%scaf_func2genes_h)."<br/>\n";

    printEndWorkingDiv();

    return ( \%func_names, $taxon2name_href, $taxon_in_file_href, $taxon_db_href, 
        \%dbScaf2name_h, \%taxon_scaffolds_h, \%scaf_func2genes_h, $timeout_msg );
        
}

sub printFuncScaffoldSearch {
    my ( $sid, $set2funcs_href, 
        $selected_funcs_ref, $data_type, $taxon_oids_ref, 
        $func_names_href, $taxon2name_href, $taxon_in_file_href, $taxon_db_href, 
        $dbScaf2name_href, $taxon_scaffolds_href, $scaf_func2genes_href, 
        $truncated_cols, $timeout_msg ) = @_;

    #print "printFuncScaffoldSearch() scaf_func2genes_href<br/>\n";
    #print Dumper($scaf_func2genes_href)."<br/>\n";

    printMainForm();
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print "<h1>Function Scaffold Search</h1>\n";
    print "<p>";
    print "Selected Function set(s): ";
    my @all_files = keys %$set2funcs_href;
    WorkspaceUtil::printShareSetName($dbh, $sid, @all_files);
    print "<br/>\n";
    print "Number of Genomes: " . scalar(@$taxon_oids_ref) . "<br/>\n" 
        if ( scalar(@$taxon_oids_ref) > 0 );
    HtmlUtil::printMetaDataTypeSelection( $data_type, 2 ) 
        if ($data_type);
    print "</p>";

    print hiddenVar( "data_type", $data_type ) if ($data_type);

    my $it = new InnerTable( 1, "funcScaffoldSearch$$", "funcScaffoldSearch", 1 );
    my $sd = $it->getSdDelim();

    $it->addColSpec("Select");
    $it->addColSpec( "Scaffold ID",   "char asc", "left" );
    $it->addColSpec( "Scaffold Name", "char asc", "left" );
    $it->addColSpec( "Genome", "char asc", "left" );
    for my $func_id ( @$selected_funcs_ref ) {
        $it->addColSpec( $func_id,  "char asc", "left", "", $func_names_href->{$func_id} );
    }

    my $select_id_name = "scaffold_oid";

    my $row = 0;
    foreach my $taxon_oid ( @$taxon_oids_ref ) {

        my $genome_url;
        if ( $taxon_db_href->{$taxon_oid} ) {
            $genome_url = "$main_cgi?section=TaxonDetail" 
            . "&page=taxonDetail&taxon_oid=$taxon_oid";
        }
        elsif ( $taxon_in_file_href->{$taxon_oid} ) {
            $genome_url = "$main_cgi?section=MetaDetail" 
            . "&page=metaDetail&taxon_oid=$taxon_oid";
        }
        else {
            #invalid taxon oid
            next;
        }

        my $scaffolds_href = $taxon_scaffolds_href->{$taxon_oid};
        for my $scaffold_oid ( keys %$scaffolds_href ) {
            my $r = $sd
                . "<input type='checkbox' name='$select_id_name' value='$scaffold_oid' />\t";

            my ( $t_oid, $d2, $scaf_oid );
            my $scaf_url;
            my $scaffold_name;
            if ( $taxon_in_file_href->{$taxon_oid} ) {
                ( $t_oid, $d2, $scaf_oid ) = split( / /, $scaffold_oid );
                $scaf_url =
                    "$main_cgi?section=MetaDetail"
                  . "&page=metaScaffoldDetail&scaffold_oid=$scaf_oid"
                  . "&taxon_oid=$taxon_oid&data_type=$d2";
                $scaffold_name = $scaf_oid;
            }
            else {
                $t_oid = $taxon_oid;
                $scaf_oid = $scaffold_oid;
                $scaf_url = "$main_cgi?section=ScaffoldCart"
                    . "&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
                $scaffold_name = $dbScaf2name_href->{$scaffold_oid};
            }

            $r .= $scaf_oid . $sd . alink( $scaf_url, $scaf_oid ) . "\t";
            $r .= $scaffold_name . $sd . "$scaffold_name\t";

            my $taxon_name = $taxon2name_href->{$taxon_oid};
            $r .= $taxon_name . $sd . alink( $genome_url, $taxon_name ) . "\t";

            my $func2genes_href = $scaf_func2genes_href->{$scaffold_oid};
            if ( $func2genes_href ) {
                for my $func_id (@$selected_funcs_ref) {
                    my $genes_href = $func2genes_href->{$func_id};
                    my $cnt = scalar( keys %$genes_href );
                    #print "showFuncScaffoldSearch() scaffold $scaffold_oid func $func_id cnt: $cnt<br/>\n";
                    if ($cnt) {
                        my $url = "$main_cgi?section=WorkspaceScafSet"
                          . "&page=scafProfileGeneList"
                          . "&scaffold_oid=$scaffold_oid"
                          . "&func_id=$func_id";
                        if ( $taxon_in_file_href->{$taxon_oid} ) {
                            $url .= "&data_type=$data_type" if ( $data_type );
                        }
                        $r .= $cnt . $sd . alink($url, $cnt) . "\t";
                    }
                    else {
                        $r .= "0" . $sd . "0\t";
                    }
                }                
            }                        
        
            $it->addRow($r);
            $row++;        
        }
    }

    if ( $truncated_cols ) { 
        WebUtil::printMessage("There are too many selections. Only $max_profile_select functions are displayed.");
    }
    if ( $timeout_msg ) {
        printMessage( "<font color='red'>Warning: $timeout_msg</font>");
    }

    if ( $row ) {
        WebUtil::printScaffoldCartFooter() if $row > 10;
        $it->printOuterTable(1);
        WebUtil::printScaffoldCartFooter();
    
        WorkspaceUtil::printSaveScaffoldToWorkspace($select_id_name);
    }
    else {
        print "<h6>No scaffolds have selected functions.</h6>\n";
    }

    printStatusLine( "$row scaffold(s) loaded", 2 );
    print end_form();
}


#############################################################################
# showFuncSetGeneProfile - show workspace function-gene profile for
#                       selected files and gene set
#############################################################################
sub showFuncSetGeneProfile {

    my $sid = getContactOid();

    my $folder   = param("directory");
    my $gene_set = param('gene_set_name');

    printMainForm();

    my $dbh = dbLogin();
    my $shareSetName = WorkspaceUtil::getShareSetName($dbh, $gene_set, $sid);
    print "<h1>Function Set Gene Profile ($shareSetName)</h1>\n";

    my ( $gene_set_owner, $gene_set ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $gene_set, $ownerFilesetDelim, $GENE_FOLDER );

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);
    if ( scalar(@all_files) == 0 ) {
        print "<p>No workspace files are selected.\n";
        return;
    }

    # read all function ids in the function set
    if ( $gene_set eq "" ) {
        webError("Please select a gene set.\n");
        return;
    }

    my $show_zero_count = param('show_zero_count');
    if ( !$show_zero_count ) {
        print "<h5>Genes with no selected function counts are not displayed.</h5>\n";
    }

    WebUtil::checkFileName($gene_set);

    # this also untaints the name
    my $gene_filename = WebUtil::validFileName($gene_set);

    my @selected_sets = ();
    my $col_count = 1;
    my %all_funcs_in_set;     # all func_ids in a function set
    my %all_func_ids;         # func_ids in all selected sets
    for my $x2 ( @all_files ) {
    	if ( $col_count > $max_profile_select ) {
    	    last;
    	}

    	push @selected_sets, ( $x2 );
    	$col_count++;
    
        my ($c_oid, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
    	open( FH, "$workspace_dir/$c_oid/$folder/$x" )
    	    or webError("File size - file error $x"); 
    	my $func_str = "";
    	while ( my $line = <FH> ) {
    	    chomp($line);
    	    $all_func_ids{$line} = 1;
    	    if ( $func_str ) {
		$func_str .= "\t" . $line;
    	    }
    	    else {
		$func_str = $line;
    	    }
    	}
        close FH;
    	$all_funcs_in_set{$x2} = $func_str;
        #print "showFuncSetGeneProfile() funcs in $x: $func_str<br/>\n";
    }

    printStatusLine( "Loading ...", 1 );

    timeout( 60 * $merfs_timeout_mins );
    my $start_time = time(); 
    my $timeout_msg = "";

    printStartWorkingDiv();
    print "<p>\n";

    # get function names
    print "Retrieving function names ...<br/>\n";
    my @func_ids = (keys %all_func_ids);
    my %func_names = QueryUtil::fetchFuncIdAndName( $dbh, \@func_ids );

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    my $sd = $it->getSdDelim();

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "char asc", "left" );
    $it->addColSpec( "Gene Product Name", "char asc", "left" );

    for my $func_set ( @selected_sets ) {
    	my $disp_name = WorkspaceUtil::getShareSetName($dbh, $func_set, $sid);
    	my ($n1, $n2) = split(/ /, $disp_name, 2);
    	if ( $n2 ) {
    	    $disp_name = $n1 . "<br/>" . $n2;
    	}
    	$it->addColSpec( $disp_name,  "char asc", "right" );
    }

    my $fullname = "$workspace_dir/$gene_set_owner/$GENE_FOLDER/$gene_filename";

    open( FH, $fullname )
	or webError("File error $fullname.");

    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    
    my $trunc = 0;
    my $row = 0;
    while ( my $gene_oid = <FH> ) {
    	chomp($gene_oid);
    	if ( $row >= $maxGeneListResults ) { 
    	    $trunc = 1; 
    	    last;
    	}

        print "Computing function count for $gene_oid ... <br/>\n";
    	my ($taxon_oid, $data_type, $g2);
        my $r = $sd
            . "<input type='checkbox' name='gene_oid' value='$gene_oid' />\t";
    	my $url = "";
    	my $gene_product_name = "";
    	my %gene_func;
    	undef %gene_func;
    	if ( isInt($gene_oid) ) {
    	    $url = "$main_cgi?section=GeneDetail"; 
    	    $url .= "&page=geneDetail&gene_oid=$gene_oid";
    	    $data_type = "database";
    
    	    ($gene_product_name, $taxon_oid) 
    	        = QueryUtil::fetchSingleGeneNameAndTaxon($dbh, $gene_oid, '', $rclause, $imgClause);
    	    if ($taxon_oid) {
        	    $g2 = $gene_oid;
    	    }
    	}
    	else {
    	    ($taxon_oid, $data_type, $g2) = split(/ /, $gene_oid);
    	    $url = "$main_cgi?section=MetaGeneDetail"; 
    	    $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid"
    		. "&data_type=$data_type&gene_oid=$g2";
    	    my ($new_name, $source) = MetaUtil::getGeneProdNameSource( $g2, $taxon_oid, $data_type );
    	    $gene_product_name = $new_name;
    	}
    	if ( ! $g2 ) {
    	    next;
    	}

    	$r .= $gene_oid . $sd . alink( $url, $g2 ) . "\t";
        $r .= $gene_product_name . $sd . $gene_product_name . "\t";

    	for my $func_id (@func_ids) {
    	    if ( $data_type eq 'database' ) {
    
        		my ($sql2, @bindList);
                if ( ! (isFuncDefined($func_id, %gene_func)) ) {
                    #todo: reimplemet to improve efficieny, no need to retirive all of every category
                    ($sql2, @bindList) = WorkspaceQueryUtil::getDbSingleGeneFuncSql($func_id, $gene_oid, $rclause, $imgClause);
                }
                                
        		my @funcs = ();    
        		if ( $sql2 ) {
                    #print "showFuncSetGeneProfile() sql: $sql2<br/>\n";                       
                    my $cur2 = execSqlBind( $dbh, $sql2, \@bindList, $verbose );
        		    for (;;) {
            			my ($f_id) = $cur2->fetchrow();
            			last if !$f_id;
            
            			if ( $func_id =~ /^ITERM/ ) {
            			    $f_id = "ITERM:$f_id";
            			}
            			elsif ( $func_id =~ /^IPWAY/ ) {
            			    $f_id = "IPWAY:$f_id";
            			}
                        elsif ( $func_id =~ /^PLIST/ ) {
                            $f_id = "PLIST:$f_id";
                        }
            			elsif ( $func_id =~ /^MetaCyc/ ) {
            			    $f_id = "MetaCyc:$f_id";
            			}
            
            			push @funcs, ( $f_id );
        		    }
        		    $cur2->finish();
        		    
        		    if (scalar(@funcs) > 0) {
                        #print "showFuncSetGeneProfile() sql: $sql2<br/>\n";                       
                        #print "showFuncSetGeneProfile() $func_id added funcs: @funcs<br/>\n";                       
                        addFuncsToHash($func_id, \@funcs, \%gene_func);
        		    }
        		}
    	    }
    	    else {
        		# MER-FS
        		my @funcs;
        		if ( $func_id =~ /^COG/ ) {
        		    if ( ! (defined $gene_func{'cog'}) ) {
            			@funcs = MetaUtil::getGeneCogId($g2, $taxon_oid, $data_type);
            			$gene_func{'cog'} = \@funcs;
        		    }
        		}
        		elsif ( $func_id =~ /^pfam/ ) {
        		    if ( ! (defined $gene_func{'pfam'}) ) {
            			@funcs = MetaUtil::getGenePfamId($g2, $taxon_oid, $data_type);
            			$gene_func{'pfam'} = \@funcs;
        		    }
        		}
        		elsif ( $func_id =~ /^TIGR/ ) {
        		    if ( ! (defined $gene_func{'tigr'}) ) {
            			@funcs = MetaUtil::getGeneTIGRfamId($g2, $taxon_oid, $data_type);
            			$gene_func{'tigr'} = \@funcs;
        		    }
        		}
        		elsif ( $func_id =~ /^KO/ ) {
        		    if ( ! (defined $gene_func{'ko'}) ) {
            			@funcs = MetaUtil::getGeneKoId($g2, $taxon_oid, $data_type);
            			$gene_func{'ko'} = \@funcs;
        		    }
        		}
        		elsif ( $func_id =~ /^EC/ ) {
        		    if ( ! (defined $gene_func{'ec'}) ) {
            			@funcs = MetaUtil::getGeneEc($g2, $taxon_oid, $data_type);
            			$gene_func{'ec'} = \@funcs;
        		    }
        		}
        		elsif ( $func_id =~ /^MetaCyc/ ) {
        		    if ( ! (defined $gene_func{'metacyc'}) ) {
            			if ( ! (defined $gene_func{'ec'}) ) {
            			    @funcs = MetaUtil::getGeneEc($g2, $taxon_oid, $data_type);
            			    $gene_func{'ec'} = \@funcs;
            			}
            			my @ecs = @{$gene_func{'ec'}};
            			my $ec_str = "";
            			my $ec_cnt = 0;
            			for my $ec2 ( @ecs ) {
            			    if ( $ec_str ) {
                				$ec_str .= ", '" . $ec2 . "'";
            			    }
            			    else {
                				$ec_str = "'" . $ec2 . "'";
            			    }
            			    $ec_cnt++;
            			    if ( $ec_cnt >= 1000 ) {
                				last;
            			    }
            			}
        
            			@funcs = ();
            			if ( $ec_str ) {
            			    my $sql2 = qq{
                                select distinct brp.in_pwys
                                from biocyc_reaction_in_pwys brp, biocyc_reaction br
                                where brp.unique_id = br.unique_id
                                and br.ec_number in ( $ec_str )
            			    }; 
            			    my $cur2 = execSql( $dbh, $sql2, $verbose );
            			    for (;;) { 
                				my ($pway2) = $cur2->fetchrow(); 
                				last if !$pway2; 
                
                				$pway2 = "MetaCyc:" . $pway2;
                				push @funcs, ( $pway2 );
            			    } 
            			    $cur2->finish(); 
            			    $gene_func{'metacyc'} = \@funcs;
            			}
        		    }
        		}
    	    }
    	}   # end for my func_id
    	#print Dumper(\%gene_func);

    	my $total_cnt = 0;
    	for my $func_set ( @selected_sets ) {
            #print "showFuncSetGeneProfile() funcs in func_set $func_set: " . $all_funcs_in_set{$func_set} . "<br/>\n";
    	    my @f = split(/\t/, $all_funcs_in_set{$func_set});
    	    my $cnt = 0;
    	    for my $f1 ( @f ) {
        		my @funcs;
        		if ( $f1 =~ /^COG/ ) {
        		    if ($gene_func{'cog'}) {
                        @funcs = @{$gene_func{'cog'}};
        		    }
        		}
        		elsif ( $f1 =~ /^pfam/ ) {
                    if ($gene_func{'pfam'}) {
                        @funcs = @{$gene_func{'pfam'}};
                    }
        		}
        		elsif ( $f1 =~ /^TIGR/ ) {
                    if ($gene_func{'tigr'}) {
                        @funcs = @{$gene_func{'tigr'}};
                    }
        		}
        		elsif ( $f1 =~ /^KOG/ ) {
                    if ($gene_func{'kog'}) {
                        @funcs = @{$gene_func{'kog'}};
                    }
        		}
        		elsif ( $f1 =~ /^KO/ ) {
                    if ($gene_func{'ko'}) {
                        @funcs = @{$gene_func{'ko'}};
                    }
        		}
        		elsif ( $f1 =~ /^EC/ ) {
                    if ($gene_func{'ec'}) {
                        @funcs = @{$gene_func{'ec'}};
                    }
        		}
        		elsif ( $f1 =~ /^MetaCyc/ ) {
        		    if ($gene_func{'metacyc'}) {
            			@funcs = @{$gene_func{'metacyc'}};
        		    }
        		}
        		elsif ( $f1 =~ /^IPR/ ) {
                    if ($gene_func{'interpro'}) {
                        @funcs = @{$gene_func{'interpro'}};
                    }
        		}
        		elsif ( $f1 =~ /^TC/ ) {
                    if ($gene_func{'tc'}) {
                        @funcs = @{$gene_func{'tc'}};
                    }
        		}
        		elsif ( $f1 =~ /^ITERM/ ) {
                    if ($gene_func{'iterm'}) {
                        @funcs = @{$gene_func{'iterm'}};
                    }
        		}
        		elsif ( $f1 =~ /^IPWAY/ ) {
                    if ($gene_func{'ipway'}) {
                        @funcs = @{$gene_func{'ipway'}};
                    }
        		}
                elsif ( $f1 =~ /^PLIST/ ) {
                    if ($gene_func{'plist'}) {
                        @funcs = @{$gene_func{'plist'}};
                    }
                }
        
        		if ( WebUtil::inArray($f1, @funcs) ) {
                    #print "showFuncSetGeneProfile() $f1 inside funcs: @funcs<br/>\n";
        		    $cnt++;
        		    $total_cnt++;
        		}
    	    }

    	    # show count for this function set $func_set
    	    if ( $cnt ) {
        		my $url = "$section_cgi&page=geneFuncSetList" 
        		    . "&input_file=$func_set&gene_oid=$gene_oid";
        		$url = alink( $url, $cnt ); 
        		$r .= $cnt . $sd . $url . "\t"; 
    	    }
    	    else {
        		$r .= "0" . $sd . "0\t";
    	    }
    	}

        if ( !$total_cnt && !$show_zero_count ) {
            next;
        }

        $it->addRow($r);
    	$row++;

        if ( (($merfs_timeout_mins * 60) -
              (time() - $start_time)) < 200 ) {
            $timeout_msg = "Process takes too long to run " . 
                "-- stopped at gene $gene_oid. " . 
                "Only partial result is displayed."; 
            last; 
        } 
    }  # end for gene_oid
    close FH;

    printEndWorkingDiv();

    if ($trunc) { 
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= 
            "( Go to " 
            . alink( $preferences_url, "Preferences" )
            . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 ); 
    } 
    else { 
        printStatusLine( "$row gene(s) loaded", 2 );
    } 

    if ( $row ) {
    	if ( scalar(@all_files) > $max_profile_select ) { 
    	    WebUtil::printMessage("There are too many selections. Only $max_profile_select functions are displayed.");
    	}
    	$it->printOuterTable(1);
    
    	if ( $timeout_msg ) {
    	    printMessage( "<font color='red'>Warning: $timeout_msg</font>");
    	}
    }
    else {
    	if ( scalar(@func_ids) > $max_profile_select ) { 
    	    WebUtil::printMessage("There are too many selections. Only $max_profile_select functions are computed.");
    	}
    	if ( $timeout_msg ) {
    	    printMessage( "<font color='red'>Warning: $timeout_msg</font>");
    	}
    	print "<h6>No genes have selected functions.</h6>\n";
    	print end_form();
    	return;
    }

    print "<p>\n";
    WebUtil::printGeneCartFooter();
 
    MetaGeneTable::printMetaGeneTableSelect();

    print end_form();
}

#############################################################################
# showFuncGeneProfile - show workspace function-gene profile for
#                       selected files and gene set
#############################################################################
sub showFuncGeneProfile {
    my $sid = getContactOid();

    printMainForm();

    my $folder   = param("directory");
    my $gene_set = param('gene_set_name');
    print "<h1>Function Gene Profile ($gene_set)</h1>\n";
    print hiddenVar("directory", $folder);

    my @filenames = param('filename');
    if ( scalar(@filenames) == 0 ) {
        print "<p>No workspace files are selected.\n";
        return;
    }

    my $x;
    for $x (@filenames) {
        print hiddenVar( "input_file", $x );
    }

    # read all function ids in the function set
    if ( $gene_set eq "" ) {
        webError("Please select a gene set.\n");
        return;
    }

    my $show_zero_count = param('show_zero_count');
    if ( !$show_zero_count ) {
        print "<h5>Genes with no selected function counts are not displayed.</h5>\n";
    }

    WebUtil::checkFileName($gene_set);

    # this also untaints the name
    my $gene_filename = WebUtil::validFileName($gene_set);

    my @func_ids = param('func_id');
    if ( scalar(@func_ids) == 0 ) {
    	webError("No functions are selected.");
    	return;
    }

    my @selected_funcs = ();
    my $col_count = 1;
    for my $func_id ( @func_ids ) {
    	if ( $col_count > $max_profile_select ) {
    	    last;
    	}
    	push @selected_funcs, ( $func_id );
    	$col_count++;
    }

    printStatusLine( "Loading ...", 1 );

    timeout( 60 * $merfs_timeout_mins );
    my $start_time = time(); 
    my $timeout_msg = "";

    printStartWorkingDiv();
    print "<p>\n";

    # get function names
    print "Retriving function names ...<br/>\n";
    my $dbh = dbLogin();
    my %func_names = QueryUtil::fetchFuncIdAndName( $dbh, \@func_ids );

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    my $sd = $it->getSdDelim();

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "char asc", "left" );
    $it->addColSpec( "Gene Product Name", "char asc", "left" );

    for my $func_id ( @selected_funcs ) {
    	$it->addColSpec( $func_id,  "char asc", "left", "", $func_names{$func_id} );
    }

    my $fullname = "$workspace_dir/$sid/$GENE_FOLDER/$gene_filename";

    open( FH, $fullname )
	or webError("File error $gene_filename.");

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $trunc = 0;
    my $row = 0;
    while ( my $gene_oid = <FH> ) {
    	chomp($gene_oid);
    	if ( $row >= $maxGeneListResults ) { 
    	    $trunc = 1; 
    	    last;
    	}

        print "Computing function count for $gene_oid ... <br/>\n";
    	my ($taxon_oid, $data_type, $g2);
        my $r = $sd
            . "<input type='checkbox' name='gene_oid' value='$gene_oid' />\t";
    	my $url = "";
    	my $gene_product_name = "";
    	my %gene_func;
    	undef %gene_func;
    	if ( isInt($gene_oid) ) {
    	    $url = "$main_cgi?section=GeneDetail"; 
    	    $url .= "&page=geneDetail&gene_oid=$gene_oid";
    	    $data_type = "database";
    
    	    ($gene_product_name, $taxon_oid) 
    	         = QueryUtil::fetchSingleGeneNameAndTaxon($dbh, $gene_oid, '', $rclause, $imgClause);
    	    if ($taxon_oid) {
        	    $g2 = $gene_oid;
    	    }
    	}
    	else {
    	    ($taxon_oid, $data_type, $g2) = split(/ /, $gene_oid);
    	    $url = "$main_cgi?section=MetaGeneDetail"; 
    	    $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid"
    		. "&data_type=$data_type&gene_oid=$g2";
    	    my ($new_name, $source) = MetaUtil::getGeneProdNameSource( $g2, $taxon_oid, $data_type );
    	    $gene_product_name = $new_name;
    	}
    	if ( ! $g2 ) {
    	    next;
    	}

    	$r .= $gene_oid . $sd . alink( $url, $g2 ) . "\t";
            $r .= $gene_product_name . $sd . $gene_product_name . "\t";
    
    	my $total_cnt = 0;
    	for my $func_id (@selected_funcs) {
    	    my $cnt = 0;
    	    if ( $data_type eq 'database' ) {

                my ($sql, @bindList) = WorkspaceQueryUtil::getDbGeneFuncCountSql($func_id, $gene_oid, $rclause, $imgClause);

        		if ( $sql ) {
                    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        			my ($cnt2) = $cur->fetchrow();
        			$cur->finish();
        		    if ( $cnt2 ) {
            			$cnt = 1;
        		    }
        		}

    	    }
    	    else {
        		# MER-FS
        		my @funcs;
        		if ( $func_id =~ /^COG/ ) {
        		    if ( ! (defined $gene_func{'cog'}) ) {
            			@funcs = MetaUtil::getGeneCogId($g2, $taxon_oid, $data_type);
            			$gene_func{'cog'} = \@funcs;
        		    }
        		    else {
            			@funcs = @{$gene_func{'cog'}};
        		    }
        		}
        		elsif ( $func_id =~ /^pfam/ ) {
        		    if ( ! (defined $gene_func{'pfam'}) ) {
            			@funcs = MetaUtil::getGenePfamId($g2, $taxon_oid, $data_type);
            			$gene_func{'pfam'} = \@funcs;
        		    }
        		    else {
            			@funcs = @{$gene_func{'pfam'}};
        		    }
        		}
        		elsif ( $func_id =~ /^TIGR/ ) {
        		    if ( ! (defined $gene_func{'tigr'}) ) {
            			@funcs = MetaUtil::getGeneTIGRfamId($g2, $taxon_oid, $data_type);
            			$gene_func{'tigr'} = \@funcs;
        		    }
        		    else {
            			@funcs = @{$gene_func{'tigr'}};
        		    }
        		}
        		elsif ( $func_id =~ /^KO/ ) {
        		    if ( ! (defined $gene_func{'ko'}) ) {
            			@funcs = MetaUtil::getGeneKoId($g2, $taxon_oid, $data_type);
            			$gene_func{'ko'} = \@funcs;
        		    }
        		    else {
            			@funcs = @{$gene_func{'ko'}};
        		    }
        		}
        		elsif ( $func_id =~ /^EC/ ) {
        		    if ( ! (defined $gene_func{'ec'}) ) {
            			@funcs = MetaUtil::getGeneEc($g2, $taxon_oid, $data_type);
            			$gene_func{'ec'} = \@funcs;
        		    }
        		    else {
            			@funcs = @{$gene_func{'ec'}};
        		    }
        		}
        		elsif ( $func_id =~ /^MetaCyc/ ) {
        		    my ($id1, $id2) = split(/\:/, $func_id);
        		    my @ecs = ();
        		    if ( ! (defined $gene_func{'ec'}) ) {
            			@ecs = MetaUtil::getGeneEc($g2, $taxon_oid, $data_type);
            			$gene_func{'ec'} = \@ecs;
        		    }
        		    else {
            			@ecs = @{$gene_func{'ec'}};
        		    }
        
        		    # get MetaCyc enzymes
        		    my $sql2 = qq{
                         select distinct br.ec_number
                         from biocyc_reaction_in_pwys brp, biocyc_reaction br
                         where brp.unique_id = br.unique_id
                         and brp.in_pwys = ?
                         and br.ec_number is not null
                    };
        		    my $cur2 = execSql( $dbh, $sql2, $verbose, $id2 );
        		    for (;;) {
            			my ($ec2) = $cur2->fetchrow();
            			last if !$ec2;
            			if ( WebUtil::inArray($ec2, @ecs) ) {
            			    @funcs = ( $func_id );
            			    last;
            			}
        		    }
        		    $cur2->finish();
        		}
        
        		if ( WebUtil::inArray($func_id, @funcs) ) {
        		    $cnt = 1;
        		}
    	    }
    	    $total_cnt += $cnt;
    
    	    if ($cnt) {
        		$r .= $cnt . $sd . $cnt . "\t";
    	    }
    	    else {
        		$r .= "0" . $sd . "0\t";
    	    }
    	}

        if ( !$total_cnt && !$show_zero_count ) {
            next;
        }

        $it->addRow($r);
    	$row++;

        if ( (($merfs_timeout_mins * 60) -
              (time() - $start_time)) < 200 ) {
            $timeout_msg = "Process takes too long to run " . 
                "-- stopped at gene $gene_oid. " . 
                "Only partial result is displayed."; 
            last; 
        } 
    }
    close FH;

    printEndWorkingDiv();

    #$dbh->disconnect();

    if ($trunc) { 
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= 
            "( Go to " 
            . alink( $preferences_url, "Preferences" )
            . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 ); 
    } 
    else { 
        printStatusLine( "$row gene(s) loaded", 2 );
    } 

    if ( $row ) {
    	if ( scalar(@func_ids) > $max_profile_select ) { 
    	    WebUtil::printMessage("There are too many selections. Only $max_profile_select functions are displayed.");
    	}
    	$it->printOuterTable(1);
    
    	if ( $timeout_msg ) {
    	    printMessage( "<font color='red'>Warning: $timeout_msg</font>");
    	}
    }
    else {
    	if ( scalar(@func_ids) > $max_profile_select ) { 
    	    WebUtil::printMessage("There are too many selections. Only $max_profile_select functions are computed.");
    	}
    	if ( $timeout_msg ) {
    	    printMessage( "<font color='red'>Warning: $timeout_msg</font>");
    	}
    	print "<h6>No genes have selected functions.</h6>\n";
    	print end_form();
    	return;
    }

    print "<p>\n";
    WebUtil::printButtonFooter();
 
    MetaGeneTable::printMetaGeneTableSelect();

    print end_form();
}



#############################################################################
# showFuncGenomeProfile - show workspace function-genome profile for
#                       selected files and genome set
#############################################################################
sub showFuncGenomeProfile {
    my $sid = getContactOid();

    my $super_user_flag = getSuperUser(); 
    my $ess_gene_cnt = param('show_essential_gene_count');

    printMainForm();

    my $folder   = param("directory");
    my $genome_set = param('genome_set_name');
    print "<h1>Function Genome Profile ($genome_set)</h1>\n";
    print hiddenVar("directory", $folder);

    my @filenames = param('filename');
    if ( scalar(@filenames) == 0 ) {
        print "<p>No workspace files are selected.\n";
        return;
    }

    my $x;
    for $x (@filenames) {
        print hiddenVar( "input_file", $x );
    }

    # read all function ids in the function set
    if ( $genome_set eq "" ) {
        webError("Please select a genome set.\n");
        return;
    }

    my $show_zero_count = param('show_genome_zero_count');
    if ( !$show_zero_count ) {
        print "<h5>Genomes with no selected function counts are not displayed.</h5>\n";
    }

    WebUtil::checkFileName($genome_set);

    # this also untaints the name
    my $genome_filename = WebUtil::validFileName($genome_set);

    my @func_ids = param('func_id');
    if ( scalar(@func_ids) == 0 ) {
    	webError("No functions are selected.");
    	return;
    }

    my @selected_funcs = ();
    my $col_count = 1;
    for my $func_id ( @func_ids ) {
    	if ( $col_count > $max_profile_select ) {
    	    last;
    	}
    	push @selected_funcs, ( $func_id );
    	$col_count++;
    }

    printStatusLine( "Loading ...", 1 );

    timeout( 60 * $merfs_timeout_mins );
    my $start_time = time(); 
    my $timeout_msg = "";

    printStartWorkingDiv();
    print "<p>\n";

    # get function names
    print "Retriving function names ...<br/>\n";
    my $dbh = dbLogin();
    my %func_names = QueryUtil::fetchFuncIdAndName( $dbh, \@func_ids );

    my $it = new InnerTable( 1, "funcGenome$$", "funcGenome", 1 );
    my $sd = $it->getSdDelim();

    $it->addColSpec("Select");
    $it->addColSpec( "Genome ID",   "char asc", "left" );
    $it->addColSpec( "Genome Name", "char asc", "left" );

    for my $func_id ( @selected_funcs ) {
    	$it->addColSpec( $func_id,  "char asc", "left", "", $func_names{$func_id} );
    }

    my $fullname = "$workspace_dir/$sid/$GENOME_FOLDER/$genome_filename";

    open( FH, $fullname )
	or webError("File error $genome_filename.");

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $trunc = 0;
    my $row = 0;
    while ( my $taxon_oid = <FH> ) {
    	chomp($taxon_oid);

        print "Computing function count for genome $taxon_oid ... <br/>\n";
        my $r = $sd
            . "<input type='checkbox' name='taxon_oid' value='$taxon_oid' />\t";

        my $sql = MerFsUtil::getSingleTaxonOidAndNameFileSql($rclause, $imgClause);
    	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    	my ($tid2, $taxon_name, $mer_fs_taxon) = $cur->fetchrow();
    	$cur->finish();
    	if ( ! $tid2 ) {
    	    next;
    	}

    	my $url;
    	if ( $mer_fs_taxon eq 'Yes' ) {
    	    $url = "$main_cgi?section=MetaDetail" 
    		. "&page=metaDetail&taxon_oid=$taxon_oid";
    	} 
    	else { 
    	    $url = "$main_cgi?section=TaxonDetail" 
    		. "&page=taxonDetail&taxon_oid=$taxon_oid";
    	} 

    	$r .= $taxon_oid . $sd . alink( $url, $taxon_oid ) . "\t";
    	$r .= $taxon_name . $sd . $taxon_name . "\t";

    	my $total_cnt = 0;
    	for my $func_id (@selected_funcs) {
    	    require WorkspaceGenomeSet;
    	    my $cnt = WorkspaceGenomeSet::outputGenomeFuncGene( "", $func_id, $genome_filename, $taxon_oid );
    	    $total_cnt += $cnt;
    
    	    if ($cnt) {
        		my $url = "$main_cgi?section=WorkspaceGenomeSet"; 
        		$url .= "&page=genomeProfileGeneList&taxon_oid=$taxon_oid" .
        		    "&input_file=$genome_filename&func_id=$func_id";
                #$url .= "&data_type=$data_type" if ( $data_type );
        		if ( $essential_gene && $super_user_flag eq 'Yes' && $ess_gene_cnt ) {
        		    require EssentialGene;
        		    my ($cnt1, $cnt2) = EssentialGene::getGenomeFuncEssentialCount($taxon_oid, $func_id);
        		    $r .= $cnt .  $sd . alink($url, $cnt) . " ($cnt1, $cnt2)" . "\t";
        		}
        		else {
        		    $r .= $cnt . $sd . alink($url, $cnt) . "\t";
        		}
    	    }
    	    else {
        		$r .= "0" . $sd . "0\t";
    	    }
    	}
    
    	if ( !$total_cnt && !$show_zero_count ) {
    	    next;
    	}
    
    	$it->addRow($r);
    	$row++;
    
    	if ( (($merfs_timeout_mins * 60) -
    	      (time() - $start_time)) < 200 ) {
    	    $timeout_msg = "Process takes too long to run " . 
    		"-- stopped at taxon $taxon_oid. " . 
    		"Only partial result is displayed."; 
    	    last; 
    	}
    }
    close FH;

    printEndWorkingDiv();

    #$dbh->disconnect();

    printStatusLine( "$row genome(s) loaded", 2 );

    if ( $row ) {
	if ( scalar(@func_ids) > $max_profile_select ) { 
	    WebUtil::printMessage("There are too many selections. Only $max_profile_select functions are displayed.");
	}
	$it->printOuterTable(1);

	if ( $timeout_msg ) {
	    printMessage( "<font color='red'>Warning: $timeout_msg</font>");
	}
    }
    else {
	if ( scalar(@func_ids) > $max_profile_select ) { 
	    WebUtil::printMessage("There are too many selections. Only $max_profile_select functions are computed.");
	}
	if ( $timeout_msg ) {
	    printMessage( "<font color='red'>Warning: $timeout_msg</font>");
	}
	print "<h6>No genomes have selected functions.</h6>\n";
	print end_form();
	return;
    }

    print "<p>\n";
    WebUtil::printButtonFooter();
 
    print end_form();
}



#############################################################################
# showFuncGenomeTreeProfile - show workspace function-genome profile for
#                       selected files and genome set
# (phylo tree format)
#############################################################################
sub showFuncGenomeTreeProfile {
    my $sid = getContactOid();

    printMainForm();

    my $folder   = param("directory");
    my $genome_set = param('genome_set_name');
    print "<h1>Genomes in <i>$genome_set</i> with Selected Functions</h1>\n";
    print hiddenVar("directory", $folder);

    my @filenames = param('filename');
    if ( scalar(@filenames) == 0 ) {
        print "<p>No workspace files are selected.\n";
        return;
    }

    my $x;
    for $x (@filenames) {
        print hiddenVar( "input_file", $x );
    }

    # read all function ids in the function set
    if ( $genome_set eq "" ) {
        webError("Please select a genome set.\n");
        return;
    }

    my $show_zero_count = param('show_genome_zero_count');
    if ( !$show_zero_count ) {
        print "<h5>Genomes with no selected function counts are not displayed.</h5>\n";
    }

    WebUtil::checkFileName($genome_set);

    # this also untaints the name
    my $genome_filename = WebUtil::validFileName($genome_set);

    my @func_ids = param('func_id');
    if ( scalar(@func_ids) == 0 ) {
    	webError("No functions are selected.");
    	return;
    }

    my @selected_funcs = ();
    my $col_count = 1;
    for my $func_id ( @func_ids ) {
    	if ( $col_count > $max_profile_select ) {
    	    last;
    	}
    	push @selected_funcs, ( $func_id );
    	$col_count++;
    }

    printStatusLine( "Loading ...", 1 );

    timeout( 60 * $merfs_timeout_mins );
    my $start_time = time(); 
    my $timeout_msg = "";

    printStartWorkingDiv();
    print "<p>\n";

    my $fullname = "$workspace_dir/$sid/$GENOME_FOLDER/$genome_filename";

    open( FH, $fullname )
	or webError("File error $genome_filename.");

    my $trunc = 0;
    my $row = 0;
    my %taxon_filter;
    while ( my $taxon_oid = <FH> ) {
    	chomp($taxon_oid);
    	if ( $show_zero_count ) {
    	    $taxon_filter{$taxon_oid} = "";
    	}

        print "Computing function count for genome $taxon_oid ... <br/>\n";
    	for my $func_id (@selected_funcs) {
    	    require WorkspaceGenomeSet;
    	    my $cnt = WorkspaceGenomeSet::outputGenomeFuncGene( "", $func_id, $genome_filename, $taxon_oid );
    
    	    if ($cnt) {
        		if ( $taxon_filter{$taxon_oid} ) {
        		    $taxon_filter{$taxon_oid} .= "\t" . $func_id;
        		}
        		else {
        		    $row++;
        		    $taxon_filter{$taxon_oid} = $func_id;
        		}
    	    }
    	}

    	if ( (($merfs_timeout_mins * 60) -
    	      (time() - $start_time)) < 200 ) {
    	    $timeout_msg = "Process takes too long to run " . 
    		"-- stopped at taxon $taxon_oid. " . 
    		"Only partial result is displayed."; 
    	    last; 
    	}
    }
    close FH;

    if ( ! $row ) {
	printEndWorkingDiv();

    	if ( scalar(@func_ids) > $max_profile_select ) { 
    	    WebUtil::printMessage("There are too many selections. Only first $max_profile_select functions are computed.");
    	}
    	if ( $timeout_msg ) {
    	    printMessage( "<font color='red'>Warning: $timeout_msg</font>");
    	}
    	print "<h6>No genomes have selected functions.</h6>\n";
    	print end_form();
    	return;
    }

    print "Loading phylo tree ...\n";

    # show tree
    my @keys             = keys(%taxon_filter);
    my $taxon_filter_cnt = @keys;

    my $dbh = dbLogin();
    my $show_all = 0;
    require PhyloTreeMgr;
    my $mgr = new PhyloTreeMgr();
    $mgr->loadFuncTree( $dbh, \%taxon_filter, $show_all );

    printEndWorkingDiv();

    printStatusLine( "$row genome(s) loaded", 2 );

    if ( $row ) {
    	if ( scalar(@func_ids) > $max_profile_select ) { 
    	    WebUtil::printMessage("There are too many selections. Only first $max_profile_select functions are computed.");
    	}
    
    	if ( $timeout_msg ) {
    	    printMessage( "<font color='red'>Warning: $timeout_msg</font>");
    	}
    }

    printTaxonButtons (''); 

    my $url3 = "$main_cgi?section=WorkspaceGenomeSet" .
	"&page=genomeProfileGeneList" .
	"&input_file=$genome_filename&func_id=";
    #$url3 .= "&data_type=$data_type" if ( $data_type );

    $mgr->printFuncTree( \%taxon_filter, $taxon_filter_cnt, $url3, $show_all );
    print "<br/>\n"; 
    printTaxonButtons ('');
    print "</p>\n";

    #$dbh->disconnect();
    print end_form();
}


####################################################################################
# listFuncInSetForGene
####################################################################################
sub listFuncInSetForGene
{
    my $sid = getContactOid();

    printMainForm();
    print "<h1>Functions in Function Set for Selected Gene</h1>\n";

    my $dbh = dbLogin();

    my $folder = $FUNC_FOLDER;

    my $filename = param('input_file');
    if ( ! $filename ) {
    	webError("No function set has been selected.");
    	return;
    }

    my $gene_oid = param('gene_oid');
    if ( ! $gene_oid ) {
    	webError("No gene has been selected.");
    	return;
    }

    my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $filename, $ownerFilesetDelim, $FUNC_FOLDER );
    $x = WebUtil::validFileName($x);
    my $share_func_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $owner, $x, $sid );

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    # get gene product name
    my $gene_product_name = $gene_oid;
    my ($taxon_oid, $data_type, $g2) = split(/ /, $gene_oid);
    if ( ! $data_type ) {
    	$taxon_oid = 0;
    	$data_type = 'database';
    	$g2 = $gene_oid;
    }
    if ($data_type eq 'database' && isInt($gene_oid) ) {
	    ($gene_product_name, $taxon_oid) 
	        = QueryUtil::fetchSingleGeneNameAndTaxon($dbh, $gene_oid);
	    if ($taxon_oid) {
    	    $g2 = $gene_oid;
	    }
    	
    }
    else {
    	my ($new_name, $source) = MetaUtil::getGeneProdNameSource( $g2, $taxon_oid, $data_type );
    	$gene_product_name = $new_name;
    }
    print "<h6>Gene ($g2): $gene_product_name. Function Set: $filename.</h6>\n";

    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    # check all functions in filename
    open( FH, "$workspace_dir/$owner/$folder/$x" )
    	or webError("File size - file error $filename"); 
    my @func_ids = ();     # save all functions in set for the selected gene
    my %gene_func;
    while ( my $line = <FH> ) {
    	chomp($line);
    	my $func_id = $line;
    	my @funcs = ();
    
    	if ( $data_type eq 'database' ) {

    		my ($sql2, @bindList);
            if ( isFuncDefined($func_id, %gene_func) ) {
                @funcs = getFuncsFromHash($func_id, %gene_func);
            }
            else {
                ($sql2, @bindList) = WorkspaceQueryUtil::getDbSingleGeneFuncSql($func_id, $gene_oid, $rclause, $imgClause);
            }
                                
    	    if ( $sql2 ) {
                my $cur2 = execSqlBind( $dbh, $sql2, \@bindList, $verbose );
        		for (;;) {
        		    my ($f_id) = $cur2->fetchrow();
        		    last if !$f_id;
        
                    if ( $func_id =~ /^ITERM/ ) {
                        $f_id = "ITERM:$f_id";
                    }
                    elsif ( $func_id =~ /^IPWAY/ ) {
                        $f_id = "IPWAY:$f_id";
                    }
                    elsif ( $func_id =~ /^PLIST/ ) {
                        $f_id = "PLIST:$f_id";
                    }
                    elsif ( $func_id =~ /^MetaCyc/ ) {
                        $f_id = "MetaCyc:$f_id";
                    }
                    
        		    push @funcs, ( $f_id );
        		}
        		$cur2->finish();

                if (scalar(@funcs) > 0) {\
                    #print "listFuncInSetForGene() sql: $sql2<br/>\n";                       
                    #print "listFuncInSetForGene() $func_id added funcs: @funcs<br/>\n";
                    addFuncsToHash($func_id, \@funcs, \%gene_func);
                }

    	    }
    	}
    	else {
    	    # MER-FS
    	    if ( $func_id =~ /^COG/ ) {
        		if ( ! (defined $gene_func{'cog'}) ) {
        		    @funcs = MetaUtil::getGeneCogId($g2, $taxon_oid, $data_type);
        		    $gene_func{'cog'} = \@funcs;
        		}
        		else {
        		    @funcs = @{$gene_func{'cog'}};
        		}
    	    }
    	    elsif ( $func_id =~ /^pfam/ ) {
        		if ( ! (defined $gene_func{'pfam'}) ) {
        		    @funcs = MetaUtil::getGenePfamId($g2, $taxon_oid, $data_type);
        		    $gene_func{'pfam'} = \@funcs;
        		}
        		else {
        		    @funcs = @{$gene_func{'pfam'}};
        		}
    	    }
    	    elsif ( $func_id =~ /^TIGR/ ) {
        		if ( ! (defined $gene_func{'tigr'}) ) {
        		    @funcs = MetaUtil::getGeneTIGRfamId($g2, $taxon_oid, $data_type);
        		    $gene_func{'tigr'} = \@funcs;
        		}
        		else {
        		    @funcs = @{$gene_func{'tigr'}};
        		}
    	    }
    	    elsif ( $func_id =~ /^KO/ ) {
        		if ( ! (defined $gene_func{'ko'}) ) {
        		    @funcs = MetaUtil::getGeneKoId($g2, $taxon_oid, $data_type);
        		    $gene_func{'ko'} = \@funcs;
        		}
        		else {
        		    @funcs = @{$gene_func{'ko'}};
        		}
    	    }
    	    elsif ( $func_id =~ /^EC/ ) {
        		if ( ! (defined $gene_func{'ec'}) ) {
        		    @funcs = MetaUtil::getGeneEc($g2, $taxon_oid, $data_type);
        		    $gene_func{'ec'} = \@funcs;
        		}
        		else {
        		    @funcs = @{$gene_func{'ec'}};
        		}
    	    }
    	    elsif ( $func_id =~ /^MetaCyc/ ) {
        		if ( ! (defined $gene_func{'metacyc'}) ) {
        		    if ( ! (defined $gene_func{'ec'}) ) {
            			@funcs = MetaUtil::getGeneEc($g2, $taxon_oid, $data_type);
            			$gene_func{'ec'} = \@funcs;
        		    }
        		    my @ecs = @{$gene_func{'ec'}};
        		    my $ec_str = "";
        		    my $ec_cnt = 0;
        		    for my $ec2 ( @ecs ) {
            			if ( $ec_str ) {
            			    $ec_str .= ", '" . $ec2 . "'";
            			}
            			else {
            			    $ec_str = "'" . $ec2 . "'";
            			}
            			$ec_cnt++;
            			if ( $ec_cnt >= 1000 ) {
            			    last;
            			}
        		    }
        
        		    @funcs = ();
        		    if ( $ec_str ) {
            			my $sql2 = qq{
                            select distinct brp.in_pwys
                            from biocyc_reaction_in_pwys brp, biocyc_reaction br
                            where brp.unique_id = br.unique_id
                            and br.ec_number in ( $ec_str )
            			}; 
            			my $cur2 = execSql( $dbh, $sql2, $verbose );
            			for (;;) { 
            			    my ($pway2) = $cur2->fetchrow(); 
            			    last if !$pway2; 
            
            			    $pway2 = "MetaCyc:" . $pway2;
            			    push @funcs, ( $pway2 );
            			} 
            			$cur2->finish(); 
            			$gene_func{'metacyc'} = \@funcs;
        		    }
        		}
        		else {
        		    @funcs = @{$gene_func{'metacyc'}};
        		}
    	    }
    	}

    	if ( WebUtil::inArray($func_id, @funcs) ) {
            #print "listFuncInSetForGene() $func_id inside funcs: @funcs<br/>\n";
    	    push @func_ids, ( $func_id );
    	}
    }   # end for my line

    #$dbh->disconnect();

    if ( scalar(@func_ids) == 0 ) {
    	print "<p>No functions.\n";
    	print end_form();
    	return;
    }

    my $select_id_name = "func_id";

    my $it = new InnerTable( 1, "geneFunc$$", "geneFunc", 1 );
    my $sd = $it->getSdDelim();

    $it->addColSpec("Select");
    $it->addColSpec( "Function ID",   "char asc", "left" );
    $it->addColSpec( "Function Name", "char asc", "left" );

    my $row_cnt = 0;
    for my $func_id ( @func_ids ) {
    	my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$func_id' /> \t";
     	$r .= $func_id . $sd . $func_id . "\t";
    	my $func_name = Workspace::getMetaFuncName($func_id);
    	$r .= $func_name . $sd . $func_name . "\t";
 
        $it->addRow($r); 
    	$row_cnt++;
    } 
 
    $it->printOuterTable(1);

    if ( $row_cnt > 0 ) {
        WebUtil::printFuncCartFooter();
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }
    
    printStatusLine( "$row_cnt function(s) loaded", 2 );

    print end_form();
}


################################################################################
# printPhyloOccurProfiles
################################################################################
sub printPhyloOccurProfiles {
    my @func_ids = param("func_id");
    if ( scalar(@func_ids) == 0 ) {
        webError("Please select at least one function.");
    }

    if ( scalar(@func_ids) > $maxProfileOccurIds ) {
        webError( "Please select no more than " . "$maxProfileOccurIds functions." );
    	return;
    }

    printStatusLine( "Loading ...", 1 );

    my $sid = getContactOid();
    if ( $sid == 312 ) { 
        print "<p>*** time1: " . currDateTime() . "\n";
    }
    my $start_time = time();
    my $timeout_msg = ""; 

    printStartWorkingDiv();

    print "Retrieving genome information from database ...<br/>\n";
    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my %taxon_name_h = fetchTaxonOid2DomainFamilyNameHash($dbh);

    ### Load ID information
    print "Retrieving function information from database ...<br/>\n";
    my @idRecs;
    my %idRecsHash;
    for my $func_id ( @func_ids ) {
        my $name = Workspace::getMetaFuncName($func_id);
        my %taxons;
        my $rh = {
            id           => $func_id,
            name         => $name,
            url          => "#",
            taxonOidHash => \%taxons,
        };
        push( @idRecs, $rh );
        $idRecsHash{$func_id} = $rh;
    }

    ### Load taxonomic hits information
    print "Computing occurrence profile ...<br/>\n";
    for my $func_id ( @func_ids ) {
    	print "Processing $func_id ...<br/>\n";
    	my $rh = $idRecsHash{$func_id};
    	if ( ! defined($rh) ) {
    	    next;
    	}
    
        my ($sql, @bindList) = WorkspaceQueryUtil::getDbFuncTaxonSql( $func_id, $rclause, $imgClause );
        
    	my @taxons = ();
    	my %t_h;
    	my $t_cnt = 0;
    	if ( $sql ) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    	    for (;;) {
        		my ($taxon_oid) = $cur->fetchrow();
        		last if !$taxon_oid;
        
        		$t_cnt++;
        		if ( ($t_cnt % 100) == 0 ) {
        		    print ".";
        		}
        		if ( ($t_cnt % 18000) == 0 ) {
        		    print "<br/>";
        		}
        		if ( $func_id =~ /TIGR/ || $func_id =~ /^KO\:/ ||
        		     $func_id =~ /^TC/ || $func_id =~ /^IPR/ ||
        		     $func_id =~ /^ITERM/ ) {
        		    if ( $t_h{$taxon_oid} ) {
            			next;
        		    }
        		    else {
            			push @taxons, ( $taxon_oid );
            			$t_h{$taxon_oid} = 1;
        		    }
        		}
        		else {
        		    push @taxons, ( $taxon_oid );
        		}
    	    }
    	    $cur->finish();
    	    print "<br/>\n";
    	}
    
    	for my $taxon ( @taxons ) {
    	    if ( ! $taxon_name_h{$taxon} ) {
        		# not selected
        		next;
    	    }
    	    my $taxonOidHash = $rh->{taxonOidHash};
    	    $taxonOidHash->{$taxon} = 1;
        }
    
    	if ( (($merfs_timeout_mins * 60) -
    	      (time() - $start_time)) < 250 ) {
    	    $timeout_msg = "Process takes too long to run " .
    		"-- stopped at $func_id. " .
    		"Only partial result is displayed."; 
    	    last; 
    	} 
    }   # end for func_id

    #$dbh->disconnect();

    printEndWorkingDiv();

    if ( $sid == 312 ) { 
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    if ( $timeout_msg ) { 
	printMessage( "<font color='red'>Warning: $timeout_msg</font>");
    } 
 
    ## Print it out as an alignment.
    require PhyloOccur;
    my $s = getPhyloOccurPanelDesc(); 
    PhyloOccur::printAlignment( '', \@idRecs, $s );

    printStatusLine( "Loaded.", 2 );
}


############################################################################
#  printPwayAssertionProfile_s - Print straight version of pathway
#    assertion profile.
############################################################################
sub printPwayAssertionProfile_s {
    printMainForm();
    print "<h1>IMG Pathways vs. Genomes Profile</h1>";

    my @func_ids    = param("func_id");


    my %taxon_oid_h;
    my @profileTaxonOids = param("genomeFilterSelections" ); 
    for my $id1 ( @profileTaxonOids ) { 
        if ( ! isInt($id1) ) { 
            next; 
        } 
        $taxon_oid_h{$id1} = 1;
    } 
 
    my @taxon_oids = (keys %taxon_oid_h);
    if ( scalar(@taxon_oids) == 0 || scalar(@taxon_oids) > 1000 ) {
        webError("Please select between 1 and 1000 genomes.");
        return; 
    }

    my @pathway_oids;
    for my $func_id (@func_ids) {
        if ( $func_id =~ /IPWAY:/ ) {
            my $pathway_oid = $func_id;
            $pathway_oid =~ s/IPWAY://;
            push( @pathway_oids, $pathway_oid );
        }
    }
    my $nPwayOids = @pathway_oids;
    my $max_func_batch = 1000;
    if ( $nPwayOids == 0 || $nPwayOids > $max_func_batch ) {
        webError("Please select 1 to $max_func_batch IMG pathways.");
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $pathway_oid_str = join( ',', @pathway_oids );
    my $taxon_oid_str   = join( ',', @taxon_oids );

    my %evidence;

    ## Row labels
    my $sql = qq{
        select pw.pathway_oid, pw.pathway_name
    	from img_pathway pw
    	where pw.pathway_oid in( $pathway_oid_str )
    	order by pw.pathway_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @rowLabels;
    my %rowId2Name;
    for ( ; ; ) {
        my ( $rowId, $rowName ) = $cur->fetchrow();
        last if !$rowId;
        my $r = "$rowId\t$rowName";
        push( @rowLabels, $r );
        $rowId2Name{$rowId} = $rowName;
    }
    $cur->finish();
    my $nRows = @rowLabels;

    ## Column labels
    my $sql = QueryUtil::getTaxonOidNameSql($taxon_oid_str);
    my $cur = execSql( $dbh, $sql, $verbose );
    my @colLabels;
    my %colId2Name;
    for ( ; ; ) {
        my ( $colId, $colName ) = $cur->fetchrow();
        last if !$colId;
        my $r = "$colId\t$colName";
        push( @colLabels, $r );
        $colId2Name{$colId} = $colName;
    }
    $cur->finish();
    my $nCols = @colLabels;

    ## Cells present
    my $rclause = WebUtil::urClause('pwa.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('pwa.taxon');
    my $sql = qq{
        select distinct pwa.pathway_oid, pwa.taxon, pwa.status, pwa.evidence
    	from img_pathway_assertions pwa
    	where pwa.pathway_oid in( $pathway_oid_str )
    	and pwa.taxon in( $taxon_oid_str )
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %asserted;
    for ( ; ; ) {
        my ( $pathway_oid, $taxon, $status, $evid ) = $cur->fetchrow();
        last if !$pathway_oid;

        my $k = "$pathway_oid-$taxon";
        $asserted{$k} = "N/A";

    	if ( $status eq 'asserted' ) {
    	    $asserted{$k} = 'p';
    	}
    	elsif ( $status eq 'not asserted' ) {
    	    $asserted{$k} = 'a';
    	}
    	elsif ( $status eq 'unknown' ) {
    	    $asserted{$k} = 'u';
    	}
    	$evidence{$k} = $evid;
    }
    $cur->finish();

    ## Show table
    printAssertionNote();

    printHint("Mouse over genome abbreviation to see full name.<br/>\n");
    
    my $it = new InnerTable( 1, "ImgPathwaysGenome$$", "ImgPathwaysGenome", 0 );
    my $sd = $it->getSdDelim();  # sort delimiter
    $it->addColSpec( "IMG Pathway", "char asc" );

    @colLabels = sort {
        my @first  = split( /\t/, $a );
        my @second = split( /\t/, $b );
        $first[1] cmp $second[1];
    } @colLabels;

    for ( my $j = 0 ; $j < $nCols ; $j++ ) {
        my ( $colId, $colName ) = split( /\t/, $colLabels[$j] );
        my $abbr = WebUtil::abbrColName( $colId, $colName, 0 );
        $abbr =~ s/$colName//g;
        $it->addColSpec( $abbr, "", "right", "", $colName );
    }

    for ( my $i = 0 ; $i < $nRows ; $i++ ) {
        my ( $rowId, $rowName ) = split( /\t/, $rowLabels[$i] );
        my $row;

        my $url = "$main_cgi?section=ImgPwayBrowser";
        $url .= "&page=imgPwayDetail";
        $url .= "&pway_oid=$rowId";
        my $pathway_oid = FuncUtil::pwayOidPadded($rowId);

        $row .=  $pathway_oid . " - " . escHtml($rowName) . $sd . 
	    alink( $url, $pathway_oid ) . " - " . escHtml($rowName) . "\t";

        for ( my $j = 0 ; $j < $nCols ; $j++ ) {
            my ( $colId, $colName ) = split( /\t/, $colLabels[$j] );
            my $k   = "$rowId-$colId";
            my $a   = $asserted{$k};
            my $url = "$main_cgi?section=ImgPwayBrowser";
            $url .= "&page=pwayTaxonDetail";
            $url .= "&pway_oid=$rowId";
            $url .= "&taxon_oid=$colId";
            my $evid_k = $k;
            my $x      = $evidence{$evid_k};
            $x = "0/0" if $x eq "";
            my $x2 = "($x)";
            my ( $nGenes, $nRxns ) = split( /\//, $x );
            my $shouldBeAsserted = 0;

            if ( $nGenes > 0 && $nRxns > 0 && $nGenes >= $nRxns && !$a ) {
                $shouldBeAsserted = 1;
            }
            my $vPadding = 4;
            my $commonStyle = "padding:${vPadding}px 4px; white-space:nowrap;";

    	    if ( ! $a ) {
        		$a = "N/A";
    	    }
    	    $row .= "$a$x2" . $sd;
    	    $row .= "<span style='$commonStyle'>";
    	    if ( $a eq "N/A" ) {
        		$row .= "N/A ";
    	    }
    	    else {
        		$row .= alink( $url, "<i>$a</i>", "assertDetail$$", 1 );
    	    }
    	    $row .= "$x2</span>\t";
        }
        $it->addRow($row);
    }
    $it->printOuterTable(1);

    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();

    print end_form();
}

############################################################################
#  printPwayAssertionProfile_t - Print transposed version of pathway
#    assertion profile.
############################################################################
sub printPwayAssertionProfile_t {
    printMainForm();
    print "<h1>Genomes vs. IMG Pathways Profile</h1>";

    my @func_ids    = param("func_id");

    my %taxon_oid_h;
    my @profileTaxonOids = param("genomeFilterSelections" ); 
    for my $id1 ( @profileTaxonOids ) { 
        if ( ! isInt($id1) ) { 
            next; 
        } 
        $taxon_oid_h{$id1} = 1;
    } 
 
    my @taxon_oids = (keys %taxon_oid_h);
    if ( scalar(@taxon_oids) == 0 || scalar(@taxon_oids) > 1000 ) {
        webError("Please select between 1 and 1000 genomes.");
        return; 
    }

    my $max_func_batch = 1000;

    my @pathway_oids;
    for my $func_id (@func_ids) {
        if ( $func_id =~ /IPWAY:/ ) {
            my $pathway_oid = $func_id;
            $pathway_oid =~ s/IPWAY://;
            push( @pathway_oids, $pathway_oid );
        }
    }

    my $nPwayOids = @pathway_oids;
    if ( $nPwayOids == 0 || $nPwayOids > $max_func_batch ) {
        webError("Please select 1 to $max_func_batch IMG pathways.");
    }
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $pathway_oid_str = join( ',', @pathway_oids );
    my $taxon_oid_str   = join( ',', @taxon_oids );

    my %evidence;
    getPwayAssertEvidence( $dbh, \@pathway_oids, \@taxon_oids, \%evidence );

    ## Row labels
    my $sql = QueryUtil::getTaxonOidNameSql($taxon_oid_str);
    my $cur = execSql( $dbh, $sql, $verbose );
    my @rowLabels;
    my %rowId2Name;
    for ( ; ; ) {
        my ( $rowId, $rowName ) = $cur->fetchrow();
        last if !$rowId;
        my $r = "$rowId\t$rowName";
        push( @rowLabels, $r );
        $rowId2Name{$rowId} = $rowName;
    }
    $cur->finish();
    my $nRows = @rowLabels;

    ## Column labels
    my $sql = qq{
        select pw.pathway_oid, pw.pathway_name
    	from img_pathway pw
    	where pw.pathway_oid in( $pathway_oid_str )
    	order by pw.pathway_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @colLabels;
    my %colId2Name;
    for ( ; ; ) {
        my ( $colId, $colName ) = $cur->fetchrow();
        last if !$colId;
        my $r = "$colId\t$colName";
        push( @colLabels, $r );
        $colId2Name{$colId} = $colName;
    }
    $cur->finish();
    my $nCols = @colLabels;

    ## Cells present
    my $rclause = WebUtil::urClause('pwa.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('pwa.taxon');
    my $sql = qq{
        select pwa.pathway_oid, pwa.taxon, pwa.status
    	from img_pathway_assertions pwa
    	where pwa.pathway_oid in( $pathway_oid_str )
    	and pwa.taxon in( $taxon_oid_str )
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my %asserted;
    for ( ; ; ) {
        my ( $pathway_oid, $taxon, $status ) = $cur->fetchrow();
        last if !$pathway_oid;
        my $k = "$pathway_oid-$taxon";
        $asserted{$k} = $status;
    }
    $cur->finish();

    ## Show table
    printAssertionNote();

    printHint( "Mouse over pathway object identifier " . "to see full pathway name.<br/>\n" );

    my $it = new InnerTable( 1, "ImgGenomePathways$$", "ImgGenomePathways", 0 );
    my $sd = $it->getSdDelim();   # sort delimiter
    $it->addColSpec( "Genome Name", "char asc" );

    # sort the columns array by colId (subscript 0) +BSJ 03/03/10
    @colLabels = sort @colLabels;

    for ( my $j = 0 ; $j < $nCols ; $j++ ) {
        my ( $colId, $colName ) = split( /\t/, $colLabels[$j] );
        my $pathway_oid = FuncUtil::pwayOidPadded($colId);
        my $url         = "$main_cgi?section=ImgPwayBrowser";
        $url .= "&page=imgPwayDetail";
        $url .= "&pway_oid=$pathway_oid";
        $it->addColSpec( "<a href='$url' title='$colName'>IPWAY:<br>$pathway_oid </a>", "", "left", "", $colName );
    }
    for ( my $i = 0 ; $i < $nRows ; $i++ ) {
        my ( $rowId, $rowName ) = split( /\t/, $rowLabels[$i] );
        my $row;

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$rowId";
        $row .= $rowName . $sd . alink( $url, $rowName ) . "\t";

        for ( my $j = 0 ; $j < $nCols ; $j++ ) {
            my ( $colId, $colName ) = split( /\t/, $colLabels[$j] );
            my $k      = "$colId-$rowId";
            my $a      = $asserted{$k};
            my $evid_k = $k;
            my $x      = $evidence{$evid_k};
            $x = "0/0" if $x eq "";
            my $x2 = "($x)";
            my ( $nGenes, $nRxns ) = split( /\//, $x );
            my $url = "$main_cgi?section=ImgPwayBrowser";
            $url .= "&page=pwayTaxonDetail";
            $url .= "&pway_oid=$colId";
            $url .= "&taxon_oid=$rowId";

            my $vPadding = 4;
            my $commonStyle = "padding:${vPadding}px 8px; white-space:nowrap;";

    	    if ( ! $a ) {
        		$a = "N/A";
    	    }
    	    else {
        		if ( $a eq 'asserted' || $a eq 'MANDATORY' ) {
        		    $a = 'p';
        		}
        		elsif ( $a eq 'not asserted' ) {
        		    $a = 'a';
        		}
        		else {
        		    $a = 'u';
        		}
    	    }

    	    $row .= "$a$x2" . $sd;
    	    $row .= "<span style='$commonStyle'>";
    	    if ( $a eq "N/A" ) {
        		$row .= "N/A ";
    	    }
    	    else {
        		$row .= alink( $url, "<i>$a</i>", "assertDetail$$", 1 );
    	    }
    	    $row .= "$x2</span>\t";
        }
        $it->addRow($row);
    }
    $it->printOuterTable(1);

    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();

    print end_form();
}


############################################################################
# printAssertionNote - Show common note header
############################################################################
sub printAssertionNote { 
    print "<p>\n"; 
 
    print "<b>Assertion:</b><br/>\n"; 
    print nbsp(2); 
    print "<i>a</i> - absent or not asserted<br/>\n"; 
    print nbsp(2); 
    print "<i>p</i> - present or asserted<br/>\n"; 
    print nbsp(2); 
    print "<i>u</i> - unknown<br/>\n"; 
    print nbsp(2); 
    print "<i>N/A</i> - no data available<br/>\n"; 
 
    print "<br/>\n"; 
 
    print "<b>Evidence Level (g/R):</b><br/>\n"; 
    print nbsp(2); 
    print "<i>g</i> - number of reactions with " . "associated genes.<br/>\n"; 
    print nbsp(2); 
    print "<i>R</i> - total number of reactions " . "in pathway.<br/>\n"; 
 
    print "</p>\n"; 
} 


############################################################################
# getPwayAssertEvidence - Get pathway assertion evidence.
############################################################################
sub getPwayAssertEvidence {
    my ( $dbh, $pwayOids_aref, $taxonOids_aref, $evidence_href ) = @_;

    my $pway_oid_str  = join( ',', @$pwayOids_aref );
    my $taxon_oid_str = join( ',', @$taxonOids_aref );

    return if $pway_oid_str  eq "";
    return if $taxon_oid_str eq "";

    my $rclause = WebUtil::urClause('a.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('a.taxon');
    my $sql = qq{
        select a.pathway_oid, a.taxon, a.status, a.evidence
    	from img_pathway_assertions a
    	where a.pathway_oid in( $pway_oid_str )
        and a.taxon in ($taxon_oid_str)
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %pway2Rxns;
    for ( ; ; ) {
        my ( $pathway_oid, $taxon, $status, $evid ) = $cur->fetchrow();
        last if !$pathway_oid;

    	my $k = $pathway_oid . '-' . $taxon;
        $evidence_href->{$k} = "$evid";
    }
}


################################################################################
# printEssentialGeneProfiles
################################################################################
sub printEssentialGeneProfiles {
    if ( ! $essential_gene ) {
    	return;
    }

    my @func_ids = param("func_id");
    if ( scalar(@func_ids) == 0 ) {
        webError("Please select at least one function.");
    }

    if ( scalar(@func_ids) > $maxProfileOccurIds ) {
        webError( "Please select no more than " . "$maxProfileOccurIds functions." );
    	return;
    }

    print "<h2>Essential Gene Profile</h2>\n";

    printStatusLine( "Loading ...", 1 );

    my $sid = getContactOid();
    if ( $sid == 312 ) { 
        print "<p>*** time1: " . currDateTime() . "\n";
    }
    my $start_time = time();
    my $timeout_msg = ""; 

    printStartWorkingDiv();

    print "Retrieving genome information from database ...<br/>\n";
    my %taxon_name_h;
    require EssentialGene;
    my $dbh2 = EssentialGene::Connect_IMG_PMEG();
    my $sql2 = "select distinct taxon_oid from pmeg_gene_pred_essen ";
    my $cur2 = execSql( $dbh2, $sql2, $verbose );
    for (;;) {
    	my ($taxon_oid2) = $cur2->fetchrow();
    	last if !$taxon_oid2;
    	$taxon_name_h{$taxon_oid2} = $taxon_oid2;
    }
    $cur2->finish();

    my $dbh = dbLogin();
    my %taxon_name_h = fetchTaxonOid2DomainFamilyNameHash($dbh);
    my @taxon_oids = (keys %taxon_name_h);

    ### Load ID information
    print "Retrieving function information from database ...<br/>\n";
    my @idRecs;
    my %idRecsHash;
    for my $func_id ( @func_ids ) {
        my $name = Workspace::getMetaFuncName($func_id);
        my %taxons;
        my $rh = {
                   id           => $func_id,
                   name         => $name,
                   url          => "#",
                   taxonOidHash => \%taxons,
        };
        push( @idRecs, $rh );
        $idRecsHash{$func_id} = $rh;
    }

    ### Load taxonomic hits information
    print "Computing essential gene occurrence profile ...<br/>\n";
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        
    for my $taxon ( @taxon_oids ) {
    	if ( ! $taxon_name_h{$taxon} ) {
    	    # not selected
    	    next;
    	}
    
    	# get essential genes
    	my %gene_h;
    	my $sql2 = "select distinct gene_oid from pmeg_gene_pred_essen where taxon_oid = ?";
    	my $cur2 = execSql( $dbh2, $sql2, $verbose, $taxon );	
    	for (;;) {
    	    my ($gene_oid2) = $cur2->fetchrow();
    	    last if !$gene_oid2;
    	    $gene_h{$gene_oid2} = 1;
    	}
    	$cur2->finish();
    	if ( scalar(keys %gene_h) == 0 ) {
    	    next;
    	}
    
    	print "Processing genome " . $taxon_name_h{$taxon} . " ...<br/>\n";
    	for my $func_id ( @func_ids ) {
    	    my $rh = $idRecsHash{$func_id};
    	    if ( ! defined($rh) ) {
        		print "<p>ERROR: no $func_id <br/>\n";
        		next;
    	    }
    
    	    my ($sql, @bindList) = WorkspaceQueryUtil::getDbSingleTaxonFuncGeneSql($func_id, $taxon, $rclause, $imgClause );
    
    	    if ( $sql ) {
        		#$cur = execSql( $dbh, $sql, $verbose, $taxon, $func_id );
                my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        		for (;;) {
        		    my ($gene_oid) = $cur->fetchrow();
        		    last if !$gene_oid;
        
        		    if ( $gene_h{$gene_oid} ) {
            			# essential gene
            			my $taxonOidHash = $rh->{taxonOidHash};
            			$taxonOidHash->{$taxon} = 1;
            			last;
        		    }
        		}
        		$cur->finish();
    	    }
    	}   # end for func_id
    
    	if ( (($merfs_timeout_mins * 60) -
    	      (time() - $start_time)) < 250 ) {
    	    $timeout_msg = "Process takes too long to run " .
    		"-- stopped at genome $taxon. " .
    		"Only partial result is displayed."; 
    	    last; 
    	} 
    }   # end for taxon

    #$dbh->disconnect();

    printEndWorkingDiv();

    if ( $sid == 312 ) { 
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    if ( $timeout_msg ) { 
    	printMessage( "<font color='red'>Warning: $timeout_msg</font>");
    } 
 
    ## Print it out as an alignment.
    require PhyloOccur;
    my $s = getPhyloOccurPanelDesc(); 
    PhyloOccur::printAlignment( '', \@idRecs, $s );

    printStatusLine( "Loaded.", 2 );
}

sub getPhyloOccurPanelDesc {

    my $s = "Profiles are based on instantiation ";
    $s .= "of a function in a genome.\n";
    $s .= "A dot '.' means there is no instantiation.<br/>\n";
        
    return $s;
}

sub fetchTaxonOid2DomainFamilyNameHash {
    my ($dbh) = @_;

    my %taxon_name_h;

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{ 
        select t.taxon_oid, t.domain, t.family, t.taxon_display_name 
        from taxon t
        where domain in ('Archaea', 'Bacteria', 'Eukaryota')
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for (;;) {
    	my ($tid, $domain, $family, $tname) = $cur->fetchrow();
    	last if !$tid;
    	if ( ! $taxon_name_h{$tid} ) {
    	    next;
    	}
    	$domain = substr($domain, 0, 1);
    	$taxon_name_h{$tid} = $domain . "\t" . $family . "\t" . $tname;
    }
    $cur->finish();

    return %taxon_name_h;
}

sub isFuncDefined {
    my ($func_id, %gene_func) = @_;

	if ( ($func_id =~ /^COG/ && (defined $gene_func{'cog'}))
	   || ($func_id =~ /^pfam/ && (defined $gene_func{'pfam'}))
	   || ($func_id =~ /^TIGR/ && (defined $gene_func{'tigr'}))
	   || ($func_id =~ /^KOG/ && (defined $gene_func{'kog'}))
	   || ($func_id =~ /^KO/ && (defined $gene_func{'ko'}))
	   || ($func_id =~ /^EC/ && (defined $gene_func{'ec'}))
	   || ($func_id =~ /^MetaCyc/ && (defined $gene_func{'metacyc'}))
	   || ($func_id =~ /^IPR/ && (defined $gene_func{'interpro'}))
	   || ($func_id =~ /^TC/ && (defined $gene_func{'tc'}))
	   || ($func_id =~ /^ITERM/ && (defined $gene_func{'iterm'}))
	   || ($func_id =~ /^IPWAY/ && (defined $gene_func{'ipway'}))
       || ($func_id =~ /^PLIST/ && (defined $gene_func{'plist'})) ) 
	{
	    return 1;
	}
    
    return 0;
}

sub getFuncsFromHash {
    my ($func_id, %gene_func) = @_;

	my @funcs;

    if ( $func_id =~ /^COG/ && defined $gene_func{'cog'} ) {
		@funcs = @{$gene_func{'cog'}};
    }
    elsif ( $func_id =~ /^pfam/ && defined $gene_func{'pfam'} ) {
	    @funcs = @{$gene_func{'pfam'}};
    }
    elsif ( $func_id =~ /^TIGR/ && defined $gene_func{'tigr'} ) {
	    @funcs = @{$gene_func{'tigr'}};
    }
    elsif ( $func_id =~ /^KOG/ && defined $gene_func{'kog'} ) {
	    @funcs = @{$gene_func{'kog'}};
    }
    elsif ( $func_id =~ /^KO/ && defined $gene_func{'ko'} ) {
	    @funcs = @{$gene_func{'ko'}};
    }
    elsif ( $func_id =~ /^EC/ && defined $gene_func{'ec'} ) {
	    @funcs = @{$gene_func{'ec'}};
    }
    elsif ( $func_id =~ /^MetaCyc/ && defined $gene_func{'metacyc'} ) {
	    @funcs = @{$gene_func{'metacyc'}};
    }
    elsif ( $func_id =~ /^IPR/ && defined $gene_func{'interpro'} ) {
	    @funcs = @{$gene_func{'interpro'}};
    }
    elsif ( $func_id =~ /^TC/ && defined $gene_func{'tc'} ) {
	    @funcs = @{$gene_func{'tc'}};
    }
    elsif ( $func_id =~ /^ITERM/ && defined $gene_func{'iterm'} ) {
	    @funcs = @{$gene_func{'iterm'}};
    }
    elsif ( $func_id =~ /^IPWAY/ && defined $gene_func{'ipway'} ) {
	    @funcs = @{$gene_func{'ipway'}};
    }
    elsif ( $func_id =~ /^PLIST/ && defined $gene_func{'plist'} ) {
        @funcs = @{$gene_func{'plist'}};
    }
    
    return (@funcs);
}

sub addFuncsToHash {
    my ($func_id, $funcs_ref, $gene_func_href) = @_;

    if ( $func_id =~ /^COG/ ) {
		$gene_func_href->{'cog'} = $funcs_ref;
        #print "addFuncsToHash() $func_id added funcs @$funcs_ref to hash, from hash @{$gene_func_href->{'cog'}} <br/>\n";
    }
    elsif ( $func_id =~ /^pfam/ ) {
		$gene_func_href->{'pfam'} = $funcs_ref;
    }
    elsif ( $func_id =~ /^TIGR/ ) {
		$gene_func_href->{'tigr'} = $funcs_ref;
    }
    elsif ( $func_id =~ /^KOG/ ) {
		$gene_func_href->{'kog'} = $funcs_ref;
    }
    elsif ( $func_id =~ /^KO/ ) {
		$gene_func_href->{'ko'} = $funcs_ref;
    }
    elsif ( $func_id =~ /^EC/ ) {
		$gene_func_href->{'ec'} = $funcs_ref;
    }
    elsif ( $func_id =~ /^MetaCyc/ ) {
		$gene_func_href->{'metacyc'} = $funcs_ref;
    }
    elsif ( $func_id =~ /^IPR/ ) {
		$gene_func_href->{'interpro'} = $funcs_ref;
    }
    elsif ( $func_id =~ /^TC/ ) {
		$gene_func_href->{'tc'} = $funcs_ref;
    }
    elsif ( $func_id =~ /^ITERM/ ) {
		$gene_func_href->{'iterm'} = $funcs_ref;
    }
    elsif ( $func_id =~ /^IPWAY/ ) {
		$gene_func_href->{'ipway'} = $funcs_ref;
    }
    elsif ( $func_id =~ /^PLIST/ ) {
        $gene_func_href->{'plist'} = $funcs_ref;
    }

}

#####################################################################
# submitJob
#####################################################################
sub submitJob {
    my ($jobPrefix) = @_;

    printMainForm();

    my $lcJobPrefix = lc($jobPrefix);
    if ( $lcJobPrefix eq 'func_scaf_search' ) {
        $jobPrefix = 'Function Scaffold Search';
    }
    #print "submitJob() job=$jobPrefix, lcJob=$lcJobPrefix<br/>\n";

    my $data_type;
    if ( $lcJobPrefix eq 'func_scaf_search' ) {
        $data_type = param('data_type_f');
    }
    #print "submitJob() data_type=$data_type<br/>\n";

    my @oids;
    my $oidsFileName;
    if ( $lcJobPrefix eq 'func_scaf_search' ) {
        if ($enable_genomelistJson) {
            @oids = param("selectedGenome1");
        }
        else {
            @oids = OracleUtil::processTaxonBinOids("t");            
        }
        validateGenomesForFunctionScaffoldSearch(@oids);
        $oidsFileName = "oidsfile.txt";
    }
    
    print "<h2>Computation Job Submission ($jobPrefix)</h2>\n";

    my $dbh = dbLogin();
    my $sid = WebUtil::getContactOid();
    $sid = sanitizeInt($sid);
    
    my $folder = $FUNC_FOLDER;
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
        webError("Please select at least one function set.");
        return;
    }
        
    print "<p>Function Set(s): $share_set_names<br/>\n";
    print "Number of Genomes: " . scalar(@oids) . "<br/>\n" 
        if ( scalar(@oids) > 0 );
    HtmlUtil::printMetaDataTypeSelection( $data_type, 2 ) if ($data_type);

    my $output_name = Workspace::validJobSetNameToSaveOrReplace( $lcJobPrefix );
    my $job_file_dir = Workspace::getJobFileDirReady( $sid, $output_name );

    ## output info file
    my $info_file = "$job_file_dir/info.txt";
    my $info_fs   = newWriteFileHandle($info_file);
    print $info_fs "$jobPrefix\n";
    print $info_fs "--function $share_set_names\n";
    print $info_fs "--datatype $data_type\n" if ( $data_type );
    if ( scalar(@oids) > 0 ) {
        print $info_fs "--oidsfile $oidsFileName\n";
        my $oidsFile = "$job_file_dir/$oidsFileName";
        my $wfh = newWriteFileHandle( $oidsFile, "FunctionScaffoldSearchGenomes" );
        foreach my $oid ( @oids ) {
            print $wfh "$oid\n";            
        }
        close $wfh;
    }
    print $info_fs currDateTime() . "\n";
    close $info_fs;

    my $queue_dir = $env->{workspace_queue_dir};
    #print "submitJob() queue_dir=$queue_dir<br/>\n";
    my $queue_filename;
    if ( $lcJobPrefix eq 'func_scaf_search' ) {
        $queue_filename = $sid . '_functionScaffoldSearch_' . $output_name;
    } 
    #print "submitJob() queue_filename=$queue_filename<br/>\n";
    my $wfh = newWriteFileHandle( $queue_dir . $queue_filename );

    if ( $lcJobPrefix eq 'func_scaf_search' ) {
        print $wfh "--program=funcScafSearch\n";
    } 
    print $wfh "--contact=$sid\n";
    print $wfh "--output=$output_name\n";
    print $wfh "--funcset=$set_names_message\n";
    print $wfh "--datatype=$data_type\n" if ( $data_type );
    print $wfh "--oidsfile=$oidsFileName\n" if ( $oidsFileName );
    close $wfh;

    Workspace::rsync($sid);
    print "<p>Job is submitted successfully.\n";

    print end_form();

}

sub validateGenomesForFunctionScaffoldSearch {
    my (@genomes) = @_;

    if ( scalar(@genomes) == 0 ) {
        webError("No genomes are selected.");
        return;
    }
}


1;
