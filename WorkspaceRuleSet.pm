###########################################################################           
# WorkspaceRuleSet.pm
###########################################################################
package WorkspaceRuleSet; 

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
use BerkeleyDB; 
use MetaGeneTable; 
use TabHTML;
use Workspace;
use WorkspaceUtil;
use WorkspaceQueryUtil;
use PhyloTreeMgr;  
use FuncCartStor;
use FuncUtil;
use ImgPwayBrowser;

 
$| = 1; 
 
my $section              = "WorkspaceRuleSet"; 
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
my $GENOME_FOLDER   = "genome"; 
my $GENE_FOLDER   = "gene"; 
my $FUNC_FOLDER   = "function"; 
my $RULE_FOLDER   = "rule"; 

my $filename_size      = 25; 
my $filename_len       = 60; 
my $max_workspace_view = 10000; 
my $max_profile_select = 50;
my $maxProfileOccurIds     = 100;

my $for_super_user_only = 1;



#########################################################################
# dispatch
#########################################################################
sub dispatch { 
    return if ( !$enable_workspace ); 
    return if ( !$user_restricted_site ); 
 
    my $page = param("page"); 
 
    my $sid = getContactOid(); 
    return if ( $sid == 0 ||  $sid < 1 || $sid eq '901'); 

    my $super_user = getSuperUser();
    if ( $for_super_user_only && $super_user ne 'Yes' ) {
	return;
    }

    # check to see user's folder has been created                              
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
        printRuleSetDetail(); 
    }
    elsif ($page eq "createNewSet"  ||
	   paramMatch("createNewSet") ) {
        createNewSet(); 
    }
    elsif ($page eq "addRule"  ||
	   paramMatch("addRule") ) {
	addRule();
    }
    elsif ($page eq "updSelectedRule"  ||
	   paramMatch("updSelectedRule") ) {
	updateRule();
    }
    elsif ($page eq "saveRuleUpdate"  ||
	   paramMatch("saveRuleUpdate") ) {
	saveRuleUpdate();
    }
    elsif ($page eq "confirmDelRules"  ||
	   paramMatch("confirmDelRules") ) {
	confirmDeleteRule();
    }
    elsif ($page eq "delSelectedRule"  ||
	   paramMatch("delSelectedRule") ) {
	deleteRule();
    }
    elsif ($page eq "createNewRule"  ||
	   paramMatch("createNewRule") ) {
	defineRule(1);
    }
    elsif ( $page eq "showRuleGenomeProfile" ||
            paramMatch("showRuleGenomeProfile") ) { 
        showRuleGenomeProfile(); 
    }
    elsif ( $page eq "showRuleResultTree" ||
            paramMatch("showRuleResultTree") ) { 
        showRuleResultTree();
    }
    elsif ( $page eq "showEvalResult" ||
            paramMatch("showEvalResult") ) { 
        showEvalResult();
    }
    elsif ( $page eq "showBioClusterEvalResult" ||
            paramMatch("showBioClusterEvalResult") ) { 
        showBioClusterEvalResult();
    }
    elsif ( $page eq "taxonCondDetail" ||
            paramMatch("taxonCondDetail") ) { 
        showTaxonCondDetail();
    }
    elsif ( $page eq "showRuleGeneProfile" ||
            paramMatch("showRuleGeneProfile") ) { 
	my $eval_type = param('gene_set_eval_type');
	if ( $eval_type eq 'ind_gene' ) {
	    showRuleGeneProfile(); 
	}
	else {
	    showRuleGeneSetProfile();
	}
    }
    elsif ( $page eq "showGeneSetEvalResult" ||
            paramMatch("showGeneSetEvalResult") ) { 
        showGeneSetEvalResult();
    }
    elsif ( $page eq "showGeneEvalResult" ||
            paramMatch("showGeneEvalResult") ) { 
        showGeneEvalResult();
    }
    elsif ( $page eq "listRuleGenes" ||
            paramMatch("listRuleGenes") ) { 
        listRuleGenes();
    }
    elsif ( $page eq "showRuleBioClusterProfile" ||
            paramMatch("showRuleBioClusterProfile") ) { 
        showRuleBioClusterProfile(); 
    }
    elsif ( $page eq "showFuncSetGeneProfile" ||
            paramMatch("showFuncSetGeneProfile") ) { 
#        showFuncSetGeneProfile(); 
    }
    elsif ( $page eq "showFuncGeneProfile" ||
            paramMatch("showFuncGeneProfile") ) { 
#        showFuncGeneProfile(); 
    }
    elsif ( $page eq "geneFuncSetList" ||
            paramMatch("geneFuncSetList") ) { 
#	listFuncInSetForGene();
    }
    elsif ( $page eq "funcOccurProfiles" ||
            paramMatch("funcOccurProfiles") ) { 
#	printPhyloOccurProfiles();
    }
    elsif ( $page eq "showPwayAssertionProfile_s" ||
	    paramMatch("showPwayAssertionProfile_s") ne "" ) {
#        printPwayAssertionProfile_s();
    }
    elsif ( $page eq "showPwayAssertionProfile_t" ||
	    paramMatch("showPwayAssertionProfile_t") ne "" ) {
#        printPwayAssertionProfile_t();
    }
    elsif ( $page eq "essentialGeneProfile" ||
            paramMatch("essentialGeneProfile") ) { 
#	printEssentialGeneProfiles();
    }
    else {
	printRuleSetMainForm();
    }
}


############################################################################
# printRuleSetMainForm
############################################################################
sub printRuleSetMainForm {
    my ($text) = @_;

    my $super_user = getSuperUser();
    if ( $for_super_user_only && $super_user ne 'Yes' ) {
	return;
    }

    my $folder = $RULE_FOLDER;

    my $sid = getContactOid(); 
    my $rule_dir = "$workspace_dir/$sid/$folder";
    if ( !-e "$rule_dir" ) { 
        mkdir "$rule_dir" or webError("Workspace is down!");
    } 
    opendir( DIR, $rule_dir )
        or webDie("failed to open folder list");
    my @files = readdir(DIR);
    closedir(DIR); 

    print "<h1>My Workspace</h1>"; 
    print "<h2>Rule Sets</h2>\n"; 

    print qq{
        <script type="text/javascript" src="$base_url/Workspace.js" >
        </script>
    }; 
 
    print $text; 
 
    printMainForm(); 
 
    my $super_user_flag = getSuperUser(); 
    WorkspaceUtil::printSetMainTable($section_cgi, $section, $workspace_dir, $sid, $folder, @files);
    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder", "$folder" );
    print "<br/>";

    TabHTML::printTabAPILinks("rulesetTab"); 
#    my @tabIndex = ( "#rulesettab1", "#rulesettab2" );
#    my @tabNames = ( "New & Import & Export", "Gene Profile" );
    my @tabIndex = ( "#rulesettab1" );
    my @tabNames = ( "New" );

    TabHTML::printTabDiv("rulesetTab", \@tabIndex, \@tabNames);
    print "<div id='rulesettab1'>";
    print "<h2>Create New Rule Set</h2>\n";

    print "<p><i> Special characters in file name will be removed and spaces converted to _ </i>\n";
    print "<p>File name:<br/>\n";
    print "<input type='text' size='$filename_size' maxLength='$filename_len' " 
        . "name='workspacefilename' " 
        . "title='All special characters will be removed and spaces converted to _ ' />\n"; 
    print "<br/>";

    print "<p>\n";
    print submit( -name  => "_section_WorkspaceRuleSet_createNewSet",
                  -value => "Create New Rule Set", 
                  -class => 'meddefbutton' );

    # Import/Export
#    Workspace::printImportExport($folder);
    print "</div>\n";

    print end_form();
    return;

    ## ingore the following
    print "<div id='funcsettab2'>";
    print "<h2>Function Set Gene Profile</h2>\n"; 
    printHint("Limit number of function set selections to avoid timeout."); 
    print "<p>Using genes in Gene Set: \n"; 
    print "&nbsp;\n"; 
    print "<select name='gene_set_name'>\n"; 
    my @gene_set_names = Workspace::getDataSetNames($GENE_FOLDER); 
    for my $name2 (@gene_set_names) { 
    	print "<option value='$name2' > $name2 </option> \n"; 
    } 
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
	-class => "lgbutton " 
	); 
    print "</div>\n";

    print end_form();
}


###############################################################################
# printRuleSetDetail
###############################################################################
sub printRuleSetDetail { 
    my $filename = param("filename"); 
    my $folder   = param("folder"); 
 
    printMainForm(); 
 
    my $super_user = getSuperUser(); 
    if ( $for_super_user_only && $super_user ne 'Yes' ) {
	return ;
    }

    print "<h1>My Workspace - Rule Sets</h1>"; 
    print "<h2>Rule Set : <font color='red'>" . escapeHTML($filename) . "</font></h2>\n"; 

    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder",   $folder ); 
    print hiddenVar( "filename", $filename ); 
 
    my $sid = getContactOid();
 
    # check filename
    if ( $filename eq "" ) { 
        webError("Cannot read file."); 
        return; 
    } 

    WebUtil::checkFileName($filename); 
 
    # this also untaints the name
    $filename = WebUtil::validFileName($filename);
    my $select_id_name = "rule_id";
 
    print "<p>\n"; 

    my $it = new InnerTable( 1, "funcSet$$", "funcSet", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Rule Name",   "char asc", "left" );
    $it->addColSpec( "Rule Type", "char asc", "left" ); 
    $it->addColSpec( "Rule Definition", "char asc", "left" ); 
    my $sd = $it->getSdDelim(); 

    my $row   = 0;
    my $trunc = 0;
    my $res   = newReadFileHandle("$workspace_dir/$sid/$folder/$filename");
    while ( my $line = $res->getline() ) {
	chomp($line);
	my ($id, $type, $body) = split(/\t/, $line);
        if ( $row >= $max_workspace_view ) {
            $trunc = 1;
            last;
        }
 
        next if ( $id eq "" );

	my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$id' checked /> \t";
 	$r .= $id . $sd . $id . "\t";
	$r .= $type . $sd . $type . "\t";
 	$r .= $body . $sd . $body . "\t";

        $it->addRow($r); 
	$row++; 
    } 
    close $res;
 
    if ( $row ) {
	$it->printOuterTable(1);
    }

    my $load_msg = "$row rule(s) loaded."; 
 
    printStatusLine( $load_msg, 2 );
#    if ( ! $row ) {
#        print end_form();
#        return;
#    }
 
    if ( $row ) {
	print "<input type='button' name='selectAll' value='Select All' "
	    . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
	print nbsp(1);
	print "<input type='button' name='clearAll' value='Clear All' "
	    . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
	print nbsp(1);
	print submit( -name  => "_section_WorkspaceRuleSet_confirmDelRules",
		      -value => "Delete Selected Rules", 
		      -class => 'meddefbutton' );
	print "<br/><br/>";
    }
    else {
	print "<p><b>No rules in this set.</b>\n";
    }

    TabHTML::printTabAPILinks("rulesetTab"); 
    my @tabIndex = ( "#rulesettab1", "#rulesettab2", "#rulesettab3",
	"#rulesettab4");
    my @tabNames = ( "New/Update", "Genome Profiles", "Gene Set Profiles",
	"BioCluster Profiles");

    TabHTML::printTabDiv("rulesetTab", \@tabIndex, \@tabNames);
    print "<div id='rulesettab1'>";
    print "<h2>Create New Rule or Update First Selected Rule</h2>\n";

    print "<p>New Rule name (max. 60 chars):<br/>\n";
    print "<input type='text' size='60' maxLength='60' " 
        . "name='newrulename' " 
        . "title='All special characters will be removed and spaces converted to _ ' />\n"; 
    print nbsp(2);
    print "New Rule type: ";
    print "<input type='radio' name='rule_type' value='and' checked/>AND-Rule\n";
    print "<input type='radio' name='rule_type' value='or' />";
    print "OR-Rule<br/>\n";

    print "<p>Number of clauses: ";
    print "<select name='clause_num'>\n"; 
    for my $i ( 1, 2, 3, 4, 5, 6, 10, 15, 20 ) {
	print "<option value='$i' > $i </option> \n"; 
    } 
    print "</select>\n"; 
    print nbsp(2);
    print "Number of conditions in a clause: ";
    print "<select name='cond_num'>\n"; 
    for my $i ( 1, 2, 3, 4, 5, 6, 10 ) {
	print "<option value='$i' > $i </option> \n"; 
    } 
    print "</select>\n"; 

    print "<p>\n";
    print "<input type='radio' name='func_source' value='func_cart' checked />";
    print "Use Functions from Function Cart<br/>\n";
    print "<input type='radio' name='func_source' value='func_set' />";
    print "Use Functions from Function Set: \n";
    print "<select name='func_set_name'>\n"; 
    my @func_set_names = Workspace::getDataSetNames($FUNC_FOLDER); 
    for my $name2 (@func_set_names) { 
    	print "<option value='$name2' > $name2 </option> \n"; 
    } 
    print "</select>\n"; 

    print "<p>\n";
    print submit( -name  => "_section_WorkspaceRuleSet_createNewRule",
                  -value => "Create New Rule", 
                  -class => 'meddefbutton' );
    print nbsp(1);
    print submit( -name  => "_section_WorkspaceRuleSet_updSelectedRule",
		  -value => "Update First Selected Rule", 
		  -class => 'meddefbutton' );
    print "</div>\n";

    print "<div id='rulesettab2'>";
    print "<h2>Rule Genome Profile</h2>\n";
    printHint("Limit number of genomes and/or number of rules to avoid timeout."); 
    print "<p>Genome Set: \n"; 
    print "&nbsp;\n"; 
    print "<select name='genome_set_name'>\n"; 
    my @genome_set_names = Workspace::getDataSetNames($GENOME_FOLDER); 
    for my $name2 (@genome_set_names) { 
    	print "<option value='$name2' > $name2 </option> \n"; 
    } 
    print "</select>\n"; 
 
    print "<p>Including MyIMG annotations? ";
    print nbsp(1);
    print "<select name='include_myimg'>\n";
    print "   <option value='0'>No</option>\n";
    print "   <option value='1'>Only my own MyIMG annotations</option>\n";
    print "   <option value='2'>Only public MyIMG annotations</option>\n";
    print "   <option value='3'>All MyIMG annotations</option>\n";
    print "</select>\n";

    # submit button
    print "<p>\n"; 
    print submit( 
	-name  => "_section_WorkspaceRuleSet_showRuleGenomeProfile", 
	-value => "Check Selected Rules", 
	-class => "lgbutton " 
	); 
    print nbsp(1);
    print submit( 
	-name  => "_section_WorkspaceRuleSet_showRuleResultTree", 
	-value => "Show Result on Phylo Tree", 
	-class => "lgbutton " 
	); 

    print "</div>\n";

    print "<div id='rulesettab3'>";
    print "<h2>Rule Gene-Set Profile</h2>\n";
    printHint("Limit number of genes and/or number of functions to avoid timeout."); 
    print "<p>Gene Set: \n"; 
    print "&nbsp;\n"; 
    print "<select name='gene_set_name'>\n"; 
    my @gene_set_names = Workspace::getDataSetNames($GENE_FOLDER); 
    for my $name2 (@gene_set_names) { 
    	print "<option value='$name2' > $name2 </option> \n"; 
    } 
    print "</select>\n"; 
 
    print "<p>\n";
    print "<input type='radio' name='gene_set_eval_type' value='gene_set' checked/>" .
	"Evaluating Entire Gene Set<br/>\n";
    print "<input type='radio' name='gene_set_eval_type' value='ind_gene' />" .
	"Evaluating Individual Genes\n";
    print nbsp(3); 
    print "<input type='checkbox' name='show_true_only' />"; 
    print nbsp(1); 
    print "Show true only?\n"; 

    print "<p>Including MyIMG annotations on genes? ";
    print nbsp(1);
    print "<select name='include_gene_myimg'>\n";
    print "   <option value='0'>No</option>\n";
    print "   <option value='1'>Only my own MyIMG annotations</option>\n";
    print "   <option value='2'>Only public MyIMG annotations</option>\n";
    print "   <option value='3'>All MyIMG annotations</option>\n";
    print "</select>\n";
 
    # submit button
    print "<p>\n"; 
    print submit( 
	-name  => "_section_WorkspaceRuleSet_showRuleGeneProfile", 
	-value => "Check Selected Rules on Gene Set", 
	-class => "lgbutton " 
	); 

    ### Occurrence Profile
#    print "<h2>Occurrence Profile</h2>"; 
#    print "<p>\n"; 
#    print "Show phylogenetic occurrence profile for " .
#	"Archaea, Bacteria and Eukarya genomes " .
#	"against currently selected functions. " ;
#    print "</p>\n"; 
#    my $name = "_section_${section}_funcOccurProfiles"; 
#    print submit( 
#                  -name  => $name, 
#                  -value => "View Phylogenetic Occurrence Profiles", 
#                  -class => 'lgbutton' 
#	); 

    ### EssentialGene Profile
#    my $isAdmin = getSuperUser($sid);
#    my $show_essential_gene = 0;
#    if ( $essential_gene && $isAdmin eq 'Yes' && $show_essential_gene ) {
#	print "<h2>Essential Gene Profile</h2>"; 
#	print "<p>\n"; 
#	print "Show essential gene occurrrence profile for " .
#	    "Archaea, Bacteria and Eukarya genomes " .
#	    "against currently selected functions. " ;
#	print "</p>\n"; 
#	my $name = "_section_${section}_essentialGeneProfiles"; 
#	print submit( 
#	    -name  => $name, 
#	    -value => "View Essential Gene Occurrence Profiles", 
#	    -class => 'lgbutton' 
#	    ); 
#    }

    print "</div>\n";

    print "<div id='rulesettab4'>";
    print "<h2>Rule Biosynthetic Cluster Profile</h2>\n";
    printHint("Limit number of genomes and/or number of rules to avoid timeout."); 
    print "<p>Biosynthetic Clusters in Genome Set: \n"; 
    print "&nbsp;\n"; 
    print "<select name='bc_genome_set_name'>\n"; 
    my @genome_set_names = Workspace::getDataSetNames($GENOME_FOLDER); 
    for my $name2 (@genome_set_names) { 
    	print "<option value='$name2' > $name2 </option> \n"; 
    } 
    print "</select>\n"; 
 
    print "<p>Including MyIMG annotations? ";
    print nbsp(1);
    print "<select name='bc_include_myimg'>\n";
    print "   <option value='0'>No</option>\n";
    print "   <option value='1'>Only my own MyIMG annotations</option>\n";
    print "   <option value='2'>Only public MyIMG annotations</option>\n";
    print "   <option value='3'>All MyIMG annotations</option>\n";
    print "</select>\n";

    # submit button
    print "<p>\n"; 
    print submit( 
	-name  => "_section_WorkspaceRuleSet_showRuleBioClusterProfile", 
	-value => "Check Selected Rules", 
	-class => "lgbutton " 
	); 

    print "</div>\n";

    print end_form(); 
} 

#############################################################################
# createNewSet
#############################################################################
sub createNewSet {
    my $super_user = getSuperUser();
    if ( $for_super_user_only && $super_user ne 'Yes' ) {
	return;
    }

    my $sid          = getContactOid();

    my $page     = param("page");
    my $filename = param("workspacefilename");
    my $folder   = param("directory"); 
    if ( !$folder ) { 
        $folder = $RULE_FOLDER;
    } 
 
    $filename =~ s/\W+/_/g; 
    if ( !$filename ) { 
        webError("Please enter a workspace file name.");
        return;
    } 
 
    # check filename
    # valid chars
    WebUtil::checkFileName($filename);
 
    # this also untaints the name
    $filename = WebUtil::validFileName($filename);

    # check if filename already exist
    if ( -e "$workspace_dir/$sid/$RULE_FOLDER/$filename" ) { 
        webError("File name $filename already exists. Please enter a new file name."); 
        return; 
    } 

    my $res = newWriteFileHandle("$workspace_dir/$sid/$RULE_FOLDER/$filename"); 
    close $res;

    printRuleSetMainForm();
}


#############################################################################
# defineRule
#############################################################################
sub defineRule {
    my ($is_new) = @_;

    my $super_user = getSuperUser();
    if ( $for_super_user_only && $super_user ne 'Yes' ) {
	return;
    }

    my $sid          = getContactOid();

    my $page     = param("page");
    my $filename = param("filename");
    my $rulename = param("newrulename");
    my $folder   = param("directory"); 
    if ( !$folder ) { 
        $folder = $RULE_FOLDER;
    } 
 
    $rulename =~ s/\W+/_/g; 
    if ( !$rulename ) { 
        webError("Please enter a rule name.");
        return;
    } 
 
    # check rule name
    if ( -e "$workspace_dir/$sid/$RULE_FOLDER/$filename" ) { 
	my $res   = newReadFileHandle("$workspace_dir/$sid/$RULE_FOLDER/$filename");
	my $found = 0;
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    if ( $id eq $rulename ) {
		$found = 1;
		last;
	    }
	}
	close $res;

	if ( $found ) {
	    webError("Rule $rulename already exists.");
	    return; 
	}
    } 

    my $rule_type = param('rule_type');
    my $clause_num = param("clause_num");
    my $cond_num = param("cond_num");
    my $func_source = param("func_source");
    my $func_set_name = param("func_set_name");

    my @funcs = ();
    my %func_name_h;
    if ( $func_source eq 'func_cart' ) {
	my $fc = new FuncCartStor( ); 
	my $recs = $fc->{ recs }; # get records
	# my $selected = $fc->{ selected };
	my @keys = keys( %$recs );
	for my $k ( @keys ) {
	    my $r = $recs->{ $k };
	    my( $func_id, $func_name, $batch_id ) = split( /\t/, $r );
	    push @funcs, ( $func_id );
	    $func_name_h{$func_id} = $func_name;
	}
    }
    else {
	my $res   = newReadFileHandle("$workspace_dir/$sid/$FUNC_FOLDER/$func_set_name");
	while ( my $id = $res->getline() ) {
	    chomp $id; 
	    push @funcs, ( $id );
	    $func_name_h{$id} = Workspace::getMetaFuncName($id);
	}
	close $res;
    }

    if ( scalar(@funcs) == 0 ) {
	webError("No functions have been selected.");
	return;
    }
    
    printMainForm();
    print "<h1>New Rule: " . $rulename . " in set <b>$filename</b></h1>\n";
    print "<h2>rule type: $rule_type</h2>\n";

    print hiddenVar('folder', $folder);
    print hiddenVar('filename', $filename);
    print hiddenVar('rulename', $rulename);
    print hiddenVar('rule_type', $rule_type);
    print hiddenVar('clause_num', $clause_num);
    print hiddenVar('cond_num', $cond_num);

    my $sub_type = "and";
    if ( $rule_type eq 'and' ) {
	$sub_type = "or";
    }

    for (my $i = 1; $i <= $clause_num; $i++) {
	if ( $i > 1 ) {
	    print "<p>" . uc($rule_type) . " ( ";
	}
	else {
	    print "<p>( ";
	}

	for (my $j = 1; $j <= $cond_num; $j++) {
	    if ( $j > 1 ) {
		print nbsp(2) . " $sub_type ";
	    }

	    my $name2 = "not_" . $i . "_" . $j;
	    print "<select name='$name2'>\n"; 
	    print "<option value='pos'>+</option>\n";
	    print "<option value='neg'>-</option>\n";
	    print "</select>\n";

	    $name2 = "func_" . $i . "_" . $j;
	    print "<select name='$name2'>\n"; 
#	    if ( $j > 1 ) {
		print "<option value='0' > </option> \n"; 
#	    }
	    for my $func_id (sort @funcs) { 
		print "<option value='$func_id' > $func_id </option> \n"; 
	    }
	    print "</select>\n";
	}

	print ")" . "</br>\n";
    }

    print "<p>\n";
    my $str = "";
    for my $id (sort (keys %func_name_h)) {
	if ( $str ) {
	    $str .= "<br/>" . $id . ": " . $func_name_h{$id};
	}
	else {
	    $str = $id . ": " . $func_name_h{$id};
	}
    }
    printHint($str);

    print "<p>\n";
    print submit( -name  => "_section_WorkspaceRuleSet_addRule",
                  -value => "Add Rule", 
                  -class => 'meddefbutton' );

    print end_form();
}


#############################################################################
# addRule
#############################################################################
sub addRule {
    my $super_user = getSuperUser();
    if ( $for_super_user_only && $super_user ne 'Yes' ) {
	return;
    }

    my $sid          = getContactOid();

    my $page     = param("page");
    my $filename = param("filename");
    my $folder   = param("directory"); 
    if ( !$folder ) { 
        $folder = $RULE_FOLDER;
    } 
 
    my $rulename = param('rulename');
    my $rule_type = param('rule_type');
    my $clause_num = param("clause_num");
    my $cond_num = param("cond_num");

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	my $found = 0;
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    if ( $id eq $rulename ) {
		$found = 1;
		last;
	    }
	}
	close $res;

	if ( $found ) {
	    print "<p><font color='red'>Rule $rulename already exists.</font>\n";
	    printRuleSetDetail();
	    return;
	}
    }

    my $rule = "";

    for (my $i = 1; $i <= $clause_num; $i++) {
	my $clause = "";
	my $is_first = 1;
	for (my $j = 1; $j <= $cond_num; $j++) {
	    my $name2 = "func_" . $i . "_" . $j;
	    my $func_id = param($name2);
	    if ( ! $func_id ) {
		next;
	    }

	    if ( $is_first ) {
		$is_first = 0;
	    }
	    else {
		if ( $rule_type eq 'and' ) {
		    $clause .= "|";
		}
		else {
		    $clause .= ",";
		}
	    }

	    $name2 = "not_" . $i . "_" . $j;
	    if ( param($name2) eq '-' || param($name2) eq 'neg' ) {
		$clause .= "!";
	    }

	    $clause .= $func_id;
	}  # end for j
	    
	if ( $is_first || length($clause) == 0 ) {
	    next;
	}

	if ( $rule ) {
	    if ( $rule_type eq 'and' ) {
		$rule .= ",(" . $clause . ")";
	    }
	    else {
		$rule .= "|(" . $clause . ")";
	    }
	}
	else {
	    $rule = "$rulename" . "\t" . $rule_type . "\t" .
		"(" . $clause . ")";
	}
    }  # end for i

    my $res;
    if ( -e $fullname ) {
	$res = newAppendFileHandle("$workspace_dir/$sid/$RULE_FOLDER/$filename"); 
    }
    else {
	$res = newWriteFileHandle("$workspace_dir/$sid/$RULE_FOLDER/$filename"); 
    }
    print $res "$rule" . "\n";
    close $res;

    printRuleSetDetail();
}


#############################################################################
# updateRule
#############################################################################
sub updateRule {
    my $sid = getContactOid();

    printMainForm();

    my $filename = param("filename");
    my @rule_ids = param("rule_id");

    my $folder   = param("directory"); 
    if ( !$folder ) { 
        $folder = $RULE_FOLDER;
    } 
 
    WebUtil::checkFileName($filename);

    if ( scalar(@rule_ids) == 0 ) {
	webError("No rule has been selected for update.");
	return;
    }

    print hiddenVar("filename", $filename);
    print hiddenVar("directory", $folder);
    print hiddenVar("folder", $folder);
    for my $r2 ( @rule_ids ) {
	print hiddenVar("rule_id", $r2);
    }

    my $rule_id = $rule_ids[0];
    my $rule_type = "";
    my $rule = "";

    my $res   = newReadFileHandle("$workspace_dir/$sid/$RULE_FOLDER/$filename");
    my @rules = ();
    while ( my $line = $res->getline() ) {
	chomp($line);
	my ($id, $type, $body) = split(/\t/, $line);
        next if ( $id eq "" );

	if ( $id eq $rule_id ) {
	    $rule_type = $type;
	    $rule = $body;
	    last;
	}
    }
    close $res;

    print "<h2>Rule: $rule_id</h2>\n";
    print hiddenVar("rulename", $rule_id);

    if ( $rule_type ) {
	print "<p>Rule Type: $rule_type\n";
	print hiddenVar("rule_type", $rule_type);
	print "<p>Rule Definition: $rule\n";
    }
    else {
	webError("Cannot find rule $rule_id.");
    }

    my $func_source = param("func_source");
    my $func_set_name = param("func_set_name");

    my %funcs;
    if ( $func_source eq 'func_cart' ) {
	my $fc = new FuncCartStor( ); 
	my $recs = $fc->{ recs }; # get records
	# my $selected = $fc->{ selected };
	my @keys = keys( %$recs );
	for my $k ( @keys ) {
	    my $r = $recs->{ $k };
	    my( $func_id, $func_name, $batch_id ) = split( /\t/, $r );
	    $funcs{$func_id} = $func_name;
	}
    }
    else {
	my $res   = newReadFileHandle("$workspace_dir/$sid/$FUNC_FOLDER/$func_set_name");
	while ( my $id = $res->getline() ) {
	    chomp $id; 
	    $funcs{$id} = Workspace::getMetaFuncName($id);
	}
	close $res;
    }

    my $clause_num = param("clause_num");
    my $cond_num = param("cond_num");

    ## parse the rule
    my @conds = ();
    if ( $rule_type eq 'and' ) {
	@conds = split(/\,/, $rule);
    }
    else {
	@conds = split(/\|/, $rule);
    }
    if ( $clause_num < (scalar(@conds)+3) ) {
	$clause_num = scalar(@conds) + 3;
    }

    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my @comps = ();
	if ( $rule_type eq 'and' ) {
	    @comps = split(/\|/, $cond1);
	}
	else {
	    @comps = split(/\,/, $cond1);
	}

	for my $comp2 ( @comps ) {
	    if ( $comp2 =~ /^\!/ ) {
		$comp2 = substr($comp2, 1, length($comp2)-1);
	    }
	    $funcs{$comp2} = Workspace::getMetaFuncName($comp2);
	}

	if ( $cond_num < (scalar(@comps)+2) ) {
	    $cond_num = scalar(@comps) + 2;
	}
    }

    print hiddenVar("clause_num", $clause_num);
    print hiddenVar("cond_num", $cond_num);

    ## show rule definition
    my $sub_type = "or";
    if ( $rule_type eq "or" ) {
	$sub_type = "and";
    }
    for (my $i = 1; $i <= $clause_num; $i++) {
	my @comps = ();

	my $k1 = $i - 1;
	if ( $k1 < scalar(@conds) ) {
	    my $cond1 = $conds[$k1];
	    if ( $rule_type eq 'and' ) {
		@comps = split(/\|/, $cond1);
	    }
	    else {
		@comps = split(/\,/, $cond1);
	    }
	}

	if ( $i > 1 ) {
	    print "<p>" . uc($rule_type) . " ( ";
	}
	else {
	    print "<p>( ";
	}

	for (my $j = 1; $j <= $cond_num; $j++) {
	    if ( $j > 1 ) {
		print nbsp(2) . " $sub_type ";
	    }

	    my $k2 = $j - 1;
	    my $pos_neg = "";
	    my $f2 = "";
	    if ( $k2 < scalar(@comps) ) {
		my $comp2 = $comps[$k2];
		if ( $comp2 =~ /^\!/ ) {
		    $pos_neg = '-';
		    $f2 = substr($comp2, 1, length($comp2)-1);
		}
		else {
		    $pos_neg = '+';
		    $f2 = $comp2;
		}
	    }

	    my $name2 = "not_" . $i . "_" . $j;
	    print "<select name='$name2'>\n"; 
	    if ( $pos_neg eq '+' ) {
		print "<option value='pos' selected>+</option>\n";
	    }
	    else {
		print "<option value='pos'>+</option>\n";
	    }

	    if ( $pos_neg eq '-' || $pos_neg eq 'neg' ) {
		print "<option value='neg' selected>-</option>\n";
	    }
	    else {
		print "<option value='neg'>-</option>\n";
	    }
	    print "</select>\n";

	    $name2 = "func_" . $i . "_" . $j;
	    print "<select name='$name2'>\n"; 
	    print "<option value='0' > </option> \n"; 

	    for my $func_id (sort (keys %funcs)) { 
		my $func_sel = "";
		if ( $func_id eq $f2 ) {
		    $func_sel = "selected";
		}

		print "<option value='$func_id' $func_sel >" . $func_id .
		    "</option> \n"; 
	    }
	    print "</select>\n";
	}

	print ")" . "</br>\n";
    }

    print "<p>\n";
    my $str = "";
    for my $id (sort (keys %funcs)) {
	if ( $str ) {
	    $str .= "<br/>" . $id . ": " . $funcs{$id};
	}
	else {
	    $str = $id . ": " . $funcs{$id};
	}
    }
    printHint($str);

    print "<p>\n";
    print submit( -name  => "_section_WorkspaceRuleSet_saveRuleUpdate",
		  -value => "Update Rule", 
		  -class => 'meddefbutton' );

    print end_form();
}



#############################################################################
# saveRuleUpdate
#############################################################################
sub saveRuleUpdate {
    my $super_user = getSuperUser();
    if ( $for_super_user_only && $super_user ne 'Yes' ) {
	return;
    }

    my $sid          = getContactOid();

    my $page     = param("page");
    my $filename = param("filename");
    my $folder   = param("directory"); 
    if ( !$folder ) { 
        $folder = $RULE_FOLDER;
    } 
 
    my $rulename = param('rulename');
    my $rule_type = param('rule_type');
    my $clause_num = param("clause_num");
    my $cond_num = param("cond_num");

    # save rule definition
    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my @rule_names = ();
    my %rule_def;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	my $found = 0;
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    push @rule_names, ( $id );
	    $rule_def{$id} = $line;
	}
	close $res;
    }

    my $rule = "";

    for (my $i = 1; $i <= $clause_num; $i++) {
	my $clause = "";
	my $is_first = 1;
	for (my $j = 1; $j <= $cond_num; $j++) {
	    my $name2 = "func_" . $i . "_" . $j;
	    my $func_id = param($name2);
	    if ( ! $func_id ) {
		next;
	    }

	    if ( $is_first ) {
		$is_first = 0;
	    }
	    else {
		if ( $rule_type eq 'and' ) {
		    $clause .= "|";
		}
		else {
		    $clause .= ",";
		}
	    }

	    $name2 = "not_" . $i . "_" . $j;
	    if ( param($name2) eq '-' || param($name2) eq 'neg' ) {
		$clause .= "!";
	    }

	    $clause .= $func_id;
	}  # end for j
	    
	if ( $is_first || length($clause) == 0 ) {
	    next;
	}

	if ( $rule ) {
	    if ( $rule_type eq 'and' ) {
		$rule .= ",(" . $clause . ")";
	    }
	    else {
		$rule .= "|(" . $clause . ")";
	    }
	}
	else {
	    $rule = "$rulename" . "\t" . $rule_type . "\t" .
		"(" . $clause . ")";
	}
    }  # end for i

    my $res = newWriteFileHandle("$workspace_dir/$sid/$RULE_FOLDER/$filename"); 
    for my $r2 ( @rule_names ) {
	if ( $r2 eq $rulename ) {
	    print $res "$rule" . "\n";
	}
	else {
	    print $res $rule_def{$r2} . "\n";
	}
    }
    close $res;

    printRuleSetDetail();
}


#############################################################################
# confirmDeleteRule
#############################################################################
sub confirmDeleteRule {
    my $sid = getContactOid();

    printMainForm();

    my $filename = param("filename");
    my @rule_ids = param("rule_id");

    WebUtil::checkFileName($filename);

    print hiddenVar("filename", $filename);

    if ( scalar(@rule_ids) == 0 ) {
	webError("No rules have been selected.");
	return;
    }

    print "<h2>Confirm Deleting Rules</h2>\n";
    print "<p>The following rule(s) will be deleted:\n";

    for my $r1 ( @rule_ids ) {
	print "<p>Rule $r1\n";
	print hiddenVar("rule_id", $r1);
    }

    print "<p>\n";
    print submit( -name  => "_section_WorkspaceRuleSet_delSelectedRule",
		  -value => "Delete Selected Rules", 
		  -class => 'meddefbutton' );
    print nbsp(1);
    print submit( -name  => "_section_WorkspaceRuleSet_showDetail",
		  -value => "Cancel", 
		  -class => 'smdefbutton' );

    print "<br/><br/>";

    print end_form();
}


#############################################################################
# deleteRule
#############################################################################
sub deleteRule {
    my $sid = getContactOid();

    printMainForm();

    my $filename = param("filename");
    my @rule_ids = param("rule_id");

    WebUtil::checkFileName($filename);

    my %rule_h;
    for my $r1 ( @rule_ids ) {
	print "<p>delete $r1\n";
	$rule_h{$r1} = 1;
    }

    my $res   = newReadFileHandle("$workspace_dir/$sid/$RULE_FOLDER/$filename");
    my @rules = ();
    while ( my $line = $res->getline() ) {
	chomp($line);
	my ($id, $type, $body) = split(/\t/, $line);
        next if ( $id eq "" );

	if ( $rule_h{$id} ) {
	    next;
	}

	push @rules, ( $line );
    }
    close $res;

    my $res1 = newWriteFileHandle("$workspace_dir/$sid/$RULE_FOLDER/$filename"); 
    for my $r2 ( @rules ) {
	print $res1 "$r2" . "\n";
    }
    close $res1;

    printRuleSetDetail();
}


#############################################################################
# showRuleGenomeProfile_old
#############################################################################
sub showRuleGenomeProfile_old {
    my $sid = getContactOid();

    printMainForm();

    my $folder   = param("directory");
    my $filename = param("filename");
    my $genome_set = param('genome_set_name');
    my $include_myimg = param('include_myimg');
    print "<h1>Rule Genome Profile ($genome_set)</h1>\n";

    my @set = param('genome_set_name');
    my @rules = param('rule_id');
    if ( scalar(@rules) == 0 ) {
        print "<p>No rules are selected.\n";
        return;
    }

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my %rule_type_h;
    my %rule_def_h;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    $rule_type_h{$id} = $type;
	    $rule_def_h{$id} = $body;
	}
	close $res;
    }

    my $x;
    for $x (@rules) {
#	print "<p>*** rule: $x\n";
#	print $rule_type_h{$x} . "; " . $rule_def_h{$x} . "\n";
        print hiddenVar( "rule_id", $x );
    }

    print "<p>selected rule(s): " . join(", ", @rules) . "\n";

    if ( $genome_set eq "" ) {
        webError("Please select a genome set.\n");
        return;
    }

    WebUtil::checkFileName($genome_set);

    # this also untaints the name
    my $genome_filename = WebUtil::validFileName($genome_set);

    open( FH, "$workspace_dir/$sid/$GENOME_FOLDER/$genome_filename" )
	or webError("File size - file error $genome_filename"); 

    timeout( 60 * $merfs_timeout_mins ); 
    my $start_time = time();
    my $timeout_msg = "";

    printStartWorkingDiv();
    print "<p>Checking genomes in genome set ...\n";

    my $select_id_name = "taxon_oid";

    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon_oid");
    my $sql = "select t.taxon_display_name from taxon t where t.taxon_oid = ? " .
	$rclause;

    my $it = new InnerTable( 1, "funcSet$$", "funcSet", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Taxon ID",   "number asc", "right" );
    $it->addColSpec( "Genome",   "char asc", "left" );
    for $x (@rules) {
	$it->addColSpec( "$x", "char asc", "left" ); 
    }
    my $sd = $it->getSdDelim(); 

    my $cnt1 = 0;
    my $prev_taxon = "";
    while ( my $line = <FH> ) {
        if ( (($merfs_timeout_mins * 60) -
              (time() - $start_time)) < 80 ) {
            $timeout_msg = "Process takes too long to run " .
                "-- stopped at $prev_taxon. " .
                "Only partial result is displayed.";
            last;
        } 

	chomp($line);
	my $taxon_oid = $line;
	my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' checked /> \t";
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	my ($taxon_name) = $cur->fetchrow();
	$cur->finish();
	if ( ! $taxon_name ) {
	    next;
	}

	my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
	$url .= "&taxon_oid=$taxon_oid";

	$r .= $taxon_oid . $sd . alink($url, $taxon_oid) . "\t";
	$r .= $taxon_name . $sd . $taxon_name . "\t";

	for $x (@rules) {
	    my $result = evalRuleOnGenome($dbh, $rule_type_h{$x}, $rule_def_h{$x}, $line,
		$include_myimg);
	    my $result_text = 'false';
	    if ( $result > 0 ) {
		$result_text = 'true';
	    }
	    elsif ( $result < 0 ) {
		$result_text = 'unknown';
	    }
	    my $url = "$main_cgi?section=WorkspaceRuleSet"; 
	    $url .= "&page=showEvalResult&taxon_oid=$line" .
		"&filename=$filename&rule_id=$x";

	    $r .= $result_text . $sd . alink($url, $result_text) . "\t";
	}

	$cnt1++;
	$prev_taxon = $taxon_oid;

	if ( ($cnt1 % 10) == 0 ) {
	    print ".";
	}
	if ( ($cnt1 % 900) == 0 ) {
	    print "<br/>";
	}

        $it->addRow($r); 
    }
    close FH;
    #$dbh->disconnect();
    printEndWorkingDiv();

    if ( $timeout_msg ) {
    	print "<p><font color='red'>$timeout_msg</font>\n";
    }

    $it->printOuterTable(1);

    if ($cnt1) { 
        WebUtil::printButtonFooter();

        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

    print end_form();
}

#############################################################################
# showRuleGenomeProfile
#############################################################################
sub showRuleGenomeProfile {
    my $sid = getContactOid();

    printMainForm();

    my $folder   = param("directory");
    my $filename = param("filename");
    my $genome_set = param('genome_set_name');
    my $include_myimg = param('include_myimg');
    print "<h1>Rule Genome Profile ($genome_set)</h1>\n";

    my @set = param('genome_set_name');
    my @rules = param('rule_id');
    if ( scalar(@rules) == 0 ) {
        print "<p>No rules are selected.\n";
        return;
    }

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my %rule_type_h;
    my %rule_def_h;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    $rule_type_h{$id} = $type;
	    $rule_def_h{$id} = $body;
	}
	close $res;
    }

    my $x;
    for $x (@rules) {
#	print "<p>*** rule: $x\n";
#	print $rule_type_h{$x} . "; " . $rule_def_h{$x} . "\n";
        print hiddenVar( "rule_id", $x );
    }

    print "<p>selected rule(s): " . join(", ", @rules) . "\n";

    if ( $include_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
    }

    if ( $genome_set eq "" ) {
        webError("Please select a genome set.\n");
        return;
    }

    WebUtil::checkFileName($genome_set);

    # this also untaints the name
    my $genome_filename = WebUtil::validFileName($genome_set);

    open( FH, "$workspace_dir/$sid/$GENOME_FOLDER/$genome_filename" )
	or webError("File size - file error $genome_filename"); 

    timeout( 60 * $merfs_timeout_mins ); 
    my $start_time = time();
    my $timeout_msg = "";

    my $sid = getContactOid(); 
    if ( $sid == 312 ) {
	print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }
    printStartWorkingDiv();
    print "<p>Checking genomes in genome set ...<br/>\n";

    my $select_id_name = "taxon_oid";

    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon_oid");
    my $sql = "select t.taxon_display_name from taxon t where t.taxon_oid = ? " .
	"and t.obsolete_flag = 'No' " .
	$rclause;

    my $it = new InnerTable( 1, "funcSet$$", "funcSet", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Taxon ID",   "number asc", "right" );
    $it->addColSpec( "Genome",   "char asc", "left" );
    for $x (@rules) {
	$it->addColSpec( "$x", "char asc", "left" ); 
    }
    my $sd = $it->getSdDelim(); 

    my @taxons = ();
    my @taxons_in_set = ();
    my %taxon_result_text; 
    my $prev_taxon = "";
    while ( my $line = <FH> ) {
        if ( (($merfs_timeout_mins * 60) -
              (time() - $start_time)) < 80 ) {
            $timeout_msg = "Process takes too long to run " .
                "-- stopped at $prev_taxon. " .
                "Only partial result is displayed.";
            last;
        } 

	chomp($line);
	my $taxon_oid = $line;
	push @taxons, ( $taxon_oid );
	push @taxons_in_set, ( $taxon_oid );

	if ( scalar(@taxons) >= 1000 ) {
            print "Checking taxon " . $taxons[0] . " ...<br/>\n";
            my %res_h; 
            for my $taxon_oid ( @taxons ) {
                $res_h{$taxon_oid} = 0; 
            }
            my $taxon_str = join(",", @taxons);
            for $x (@rules) {
                evalRuleOnGenomeSet($dbh, $rule_type_h{$x}, $rule_def_h{$x},
                                    $taxon_str, \%res_h, $include_myimg);
 
                for my $taxon_oid ( @taxons ) {
		    my $result_text = 'false';
		    my $result = $res_h{$taxon_oid};
		    if ( $result > 0 ) {
			$result_text = 'true';
		    }
		    elsif ( $result < 0 ) {
			$result_text = 'unknown';
		    }

		    if ( $taxon_result_text{$taxon_oid} ) {
			my $href = $taxon_result_text{$taxon_oid};
			$href->{$x} = $result_text;
		    }
		    else { 
			my %h2;
			$h2{$x} = $result_text;
			$taxon_result_text{$taxon_oid} = \%h2;
		    }
                } 
            }  # end for $x                                                                 
 
            $prev_taxon = $taxons[-1];
            @taxons = (); 
        }  # end >= 1000                                                                    
    } 
    close FH; 

    # last one
    if ( scalar(@taxons) > 0 ) {
	print "Checking taxon " . $taxons[0] . " ...<br/>\n";
	my %res_h; 
	for my $taxon_oid ( @taxons ) {
	    $res_h{$taxon_oid} = 0; 
	}
	my $taxon_str = join(",", @taxons);
	for $x (@rules) {
	    evalRuleOnGenomeSet($dbh, $rule_type_h{$x}, $rule_def_h{$x},
				$taxon_str, \%res_h, $include_myimg);
 
	    for my $taxon_oid ( @taxons ) {
		my $result_text = 'false';
		my $result = $res_h{$taxon_oid};
		if ( $result > 0 ) {
		    $result_text = 'true';
		}
		elsif ( $result < 0 ) {
		    $result_text = 'unknown';
		}

		if ( $taxon_result_text{$taxon_oid} ) {
		    my $href = $taxon_result_text{$taxon_oid};
		    $href->{$x} = $result_text;
		}
		else { 
		    my %h2;
		    $h2{$x} = $result_text;
		    $taxon_result_text{$taxon_oid} = \%h2;
		}
	    } 
	}  # end for $x                                                                 
 
	@taxons = (); 
    }

    for my $taxon_oid ( @taxons_in_set ) {
	my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	my ($taxon_name) = $cur->fetchrow();
	$cur->finish();
	if ( ! $taxon_name ) {
	    $r = $sd . " \t";
	    $r .= $taxon_oid . $sd . $taxon_oid . "\t";
	    $r .= "(Genome not in database)" . $sd . "(Genome not in database)" . "\t";
	    $r .= "-" . $sd . "-" . "\t";
	    $it->addRow($r); 
	    next;
	}

	my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
	$url .= "&taxon_oid=$taxon_oid";

	$r .= $taxon_oid . $sd . alink($url, $taxon_oid) . "\t";
	$r .= $taxon_name . $sd . $taxon_name . "\t";

	for $x (@rules) {
	    my $href = $taxon_result_text{$taxon_oid};
	    my $result_text = 'false';
	    if ( $href && $href->{$x} ) {
		$result_text = $href->{$x};
	    }

	    my $url = "$main_cgi?section=WorkspaceRuleSet"; 
	    $url .= "&page=showEvalResult&taxon_oid=$taxon_oid" .
		"&filename=$filename&rule_id=$x";
	    if ( $include_myimg ) {
		$url .= "&include_myimg=$include_myimg";
	    }

	    $r .= $result_text . $sd . alink($url, $result_text) . "\t";
	}

	$prev_taxon = $taxon_oid;
        $it->addRow($r); 
    }

    $dbh->disconnect();
    printEndWorkingDiv();
    if ( $sid == 312 ) {
	print "<p>*** end time: " . currDateTime() . "<br/>\n";
    }

    if ( $timeout_msg ) {
    	print "<p><font color='red'>$timeout_msg</font>\n";
    }

    $it->printOuterTable(1);

    WebUtil::printButtonFooter();
    WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);

    print end_form();
}


#############################################################################
# showRuleResultTree_old
#############################################################################
sub showRuleResultTree_old {
    my $sid = getContactOid();

    printMainForm();

    my $folder   = param("directory");
    my $filename = param("filename");
    my $genome_set = param('genome_set_name');
    my $include_myimg = param('include_myimg');
    print "<h1>Rule Genome Profile ($genome_set)</h1>\n";

    my @rules = param('rule_id');
    if ( scalar(@rules) == 0 ) {
        print "<p>No rules are selected.\n";
        return;
    }

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my %rule_type_h;
    my %rule_def_h;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    $rule_type_h{$id} = $type;
	    $rule_def_h{$id} = $body;
	}
	close $res;
    }

    my $x;
    for $x (@rules) {
#	print "<p>*** rule: $x\n";
#	print $rule_type_h{$x} . "; " . $rule_def_h{$x} . "\n";
        print hiddenVar( "rule_id", $x );
    }

    print "<p>selected rule(s): " . join(", ", @rules) . "\n";

    if ( $genome_set eq "" ) {
        webError("Please select a genome set.\n");
        return;
    }

    WebUtil::checkFileName($genome_set);

    # this also untaints the name
    my $genome_filename = WebUtil::validFileName($genome_set);

    open( FH, "$workspace_dir/$sid/$GENOME_FOLDER/$genome_filename" )
	or webError("File size - file error $genome_filename"); 

    timeout( 60 * $merfs_timeout_mins ); 
    my $start_time = time();
    my $timeout_msg = "";

    my $sid = getContactOid(); 
    if ( $sid == 312 ) {
	print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }
    printStartWorkingDiv();
    print "<p>Checking genomes in genome set ...\n";

    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon");
    my $sql = "select t.taxon_display_name from taxon t where t.taxon_oid = ? " .
	$rclause;

    my %taxon_filter;
    my $cnt1 = 0;
    my $prev_taxon;
    while ( my $line = <FH> ) {
        if ( (($merfs_timeout_mins * 60) -
              (time() - $start_time)) < 80 ) {
            $timeout_msg = "Process takes too long to run " .
                "-- stopped at $prev_taxon. " .
                "Only partial result is displayed.";
            last;
        } 

	chomp($line);
	my $taxon_oid = $line;
	print "Checking taxon $taxon_oid ...<br/>\n";
	my $result_text = "";

	for $x (@rules) {
	    my $result = evalRuleOnGenome($dbh, $rule_type_h{$x}, $rule_def_h{$x}, $line,
					  $include_myimg);
	    if ( $result > 0 ) {
		if ( $result_text ) {
		    $result_text .= "\t" . $x;
		}
		else {
		    $result_text = $x;
		}
	    }
	}

	if ( $result_text ) {
	    $taxon_filter{$taxon_oid} = $result_text;
	    $cnt1++;
	}
	else {
	    $taxon_filter{$taxon_oid} = " ";
	}

	$prev_taxon = $taxon_oid;
    }
    close FH;

    if ( $cnt1 == 0 ) {
    	printEndWorkingDiv();
	if ( $sid == 312 ) {
	    print "<p>*** end time: " . currDateTime() . "<br/>\n";    
	}
    	#$dbh->disconnect();
    	print "<p>No genomes satisfy the rules.\n";
    	print end_form();
    	return;
    }

    print "<p>Generating tree display ...\n";

    my @keys             = keys(%taxon_filter);
    my $taxon_filter_cnt = @keys;
 
    my $show_all = 0;
    require PhyloTreeMgr; 
    my $mgr = new PhyloTreeMgr(); 
    $mgr->loadFuncTree( $dbh, \%taxon_filter, $show_all );

    printEndWorkingDiv();
    if ( $sid == 312 ) {
	print "<p>*** end time: " . currDateTime() . "<br/>\n";    
    }
    if ( $timeout_msg ) {
    	print "<p><font color='red'>$timeout_msg</font>\n";
    }

    print "<p>Total selected genome count: $cnt1\n";
    $dbh->disconnect();

#   my $url3 = "$main_cgi?section=WorkspaceGenomeSet" .
#        "&page=genomeProfileGeneList" .
#        "&input_file=$genome_filename&func_id=";

    my $url3 = "$main_cgi?section=WorkspaceRuleSet" .
	"&page=showEvalResult" .
	"&filename=$filename&rule_id=";

    $mgr->printFuncTree( \%taxon_filter, $taxon_filter_cnt, $url3, $show_all );

    if ($cnt1) { 
        WebUtil::printButtonFooter();

        WorkspaceUtil::printSaveGenomeToWorkspace('taxon_filter_oid');
    }

    print end_form();
}

#############################################################################
# showRuleResultTree
#############################################################################
sub showRuleResultTree {
    my $sid = getContactOid();

    printMainForm();

    my $folder   = param("directory");
    my $filename = param("filename");
    my $genome_set = param('genome_set_name');
    my $include_myimg = param('include_myimg');
    print "<h1>Rule Genome Profile ($genome_set)</h1>\n";

    my @rules = param('rule_id');
    if ( scalar(@rules) == 0 ) {
        print "<p>No rules are selected.\n";
        return;
    }

    if ( $include_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
    }

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my %rule_type_h;
    my %rule_def_h;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    $rule_type_h{$id} = $type;
	    $rule_def_h{$id} = $body;
	}
	close $res;
    }

    my $x;
    for $x (@rules) {
#	print "<p>*** rule: $x\n";
#	print $rule_type_h{$x} . "; " . $rule_def_h{$x} . "\n";
        print hiddenVar( "rule_id", $x );
    }

    print "<p>selected rule(s): " . join(", ", @rules) . "\n";

    if ( $genome_set eq "" ) {
        webError("Please select a genome set.\n");
        return;
    }

    WebUtil::checkFileName($genome_set);

    # this also untaints the name
    my $genome_filename = WebUtil::validFileName($genome_set);

    open( FH, "$workspace_dir/$sid/$GENOME_FOLDER/$genome_filename" )
	or webError("File size - file error $genome_filename"); 

    timeout( 60 * $merfs_timeout_mins ); 
    my $start_time = time();
    my $timeout_msg = "";

    my $sid = getContactOid(); 
    if ( $sid == 312 ) {
	print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }
    printStartWorkingDiv();
    print "<p>Checking genomes in genome set ...\n";

    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon");
    my $sql = "select t.taxon_display_name from taxon t " .
	"where t.taxon_oid = ? " .
	"and t.obsolete_flag = 'No' " .
	$rclause;

    my @taxons = ();
    my %taxon_filter;
    my $cnt1 = 0;
    my $prev_taxon;
    while ( my $line = <FH> ) {
        if ( (($merfs_timeout_mins * 60) -
              (time() - $start_time)) < 80 ) {
            $timeout_msg = "Process takes too long to run " .
                "-- stopped at $prev_taxon. " .
                "Only partial result is displayed.";
            last;
        } 

	chomp($line);
	my $taxon_oid = $line;
	push @taxons, ( $taxon_oid );

	if ( scalar(@taxons) >= 1000 ) {
	    print "Checking taxon " . $taxons[0] . " ...<br/>\n";
	    my %result_text;
	    my %res_h;
	    for my $taxon_oid ( @taxons ) {
		$result_text{$taxon_oid} = "";
		$res_h{$taxon_oid} = 0;
	    }
	    my $taxon_str = join(",", @taxons);
	    for $x (@rules) {
		evalRuleOnGenomeSet($dbh, $rule_type_h{$x}, $rule_def_h{$x},
				    $taxon_str, \%res_h, $include_myimg);

		for my $taxon_oid ( @taxons ) {
		    if ( $res_h{$taxon_oid} > 0 ) {
			if ( $result_text{$taxon_oid} ) {
			    $result_text{$taxon_oid} .= "\t" . $x;
			}
			else {
			    $result_text{$taxon_oid} = $x;
			}
		    }
		}
	    }  # end for $x

	    for my $taxon_oid ( @taxons ) {
		if ( $result_text{$taxon_oid} ) {
		    $taxon_filter{$taxon_oid} = $result_text{$taxon_oid};
		    $cnt1++;
		}
		else {
		    $taxon_filter{$taxon_oid} = " ";
		}
	    }

	    $prev_taxon = $taxons[-1];
	    @taxons = ();
	}  # end >= 1000
    }
    close FH;

    # last one
    if ( scalar(@taxons) > 0 ) {
	print "Checking taxon " . $taxons[0] . "...<br/>\n";
	my %result_text;
	my %res_h;
	for my $taxon_oid ( @taxons ) {
	    $result_text{$taxon_oid} = "";
	    $res_h{$taxon_oid} = 0;
	}
	my $taxon_str = join(",", @taxons);
	for $x (@rules) {
	    evalRuleOnGenomeSet($dbh, $rule_type_h{$x}, $rule_def_h{$x},
				$taxon_str, \%res_h, $include_myimg);

	    for my $taxon_oid ( @taxons ) {
		if ( $res_h{$taxon_oid} > 0 ) {
		    if ( $result_text{$taxon_oid} ) {
			$result_text{$taxon_oid} .= "\t" . $x;
		    }
		    else {
			$result_text{$taxon_oid} = $x;
		    }
		}
	    }
	}  # end for $x

	for my $taxon_oid ( @taxons ) {
	    if ( $result_text{$taxon_oid} ) {
		$taxon_filter{$taxon_oid} = $result_text{$taxon_oid};
		$cnt1++;
	    }
	    else {
		$taxon_filter{$taxon_oid} = " ";
	    }
	}

	@taxons = ();
    }

    if ( $cnt1 == 0 ) {
    	printEndWorkingDiv();
	if ( $sid == 312 ) {
	    print "<p>*** end time: " . currDateTime() . "<br/>\n";    
	}
    	#$dbh->disconnect();
    	print "<p>No genomes satisfy the rules.\n";
    	print end_form();
    	return;
    }

    print "<p>Generating tree display ...\n";

    my @keys             = keys(%taxon_filter);
    my $taxon_filter_cnt = @keys;
 
    my $show_all = 0;
    require PhyloTreeMgr; 
    my $mgr = new PhyloTreeMgr(); 
    $mgr->loadFuncTree( $dbh, \%taxon_filter, $show_all );

    printEndWorkingDiv();
    if ( $sid == 312 ) {
	print "<p>*** end time: " . currDateTime() . "<br/>\n";    
    }
    if ( $timeout_msg ) {
    	print "<p><font color='red'>$timeout_msg</font>\n";
    }

    print "<p>Total selected genome count: $cnt1\n";
    #$dbh->disconnect();

#   my $url3 = "$main_cgi?section=WorkspaceGenomeSet" .
#        "&page=genomeProfileGeneList" .
#        "&input_file=$genome_filename&func_id=";

    my $url3 = "$main_cgi?section=WorkspaceRuleSet" .
	"&page=showEvalResult" .
	"&filename=$filename&rule_id=";

    $mgr->printFuncTree( \%taxon_filter, $taxon_filter_cnt, $url3, $show_all );

    if ($cnt1) { 
        WebUtil::printButtonFooter();

        WorkspaceUtil::printSaveGenomeToWorkspace('taxon_filter_oid');
    }

    print end_form();
}


#############################################################################
# showEvalResult
#############################################################################
sub showEvalResult {
    my $sid = getContactOid();

    printMainForm();

    my $filename = param("filename");
    my $taxon_oid = param("taxon_oid");
    my $rule_id = param("rule_id");
    my $include_myimg = param('include_myimg');

    WebUtil::checkFileName($filename);

    print "<h1>Rule Evaluation (Rule $rule_id in $filename)</h1>\n";

    print hiddenVar("filename", $filename);
    print hiddenVar("taxon_oid", $taxon_oid);
    print hiddenVar("rule_id", $rule_id);
    print hiddenVar("include_myimg", $include_myimg);

    if ( $include_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
    }

    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon_oid");
    my $sql = "select t.taxon_display_name from taxon t where t.taxon_oid = ? " .
	$rclause;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_name) = $cur->fetchrow();
    $cur->finish();
    if ( ! $taxon_name ) {
	#$dbh->disconnect();
	return;
    }

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
    $url .= "&taxon_oid=$taxon_oid";
    print "<h3>" . alink($url, $taxon_name) . "</h3>\n";

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my $rule_type;
    my $rule_def;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    if ( $id eq $rule_id ) {
		$rule_type = $type;
		$rule_def = $body;
		last;
	    }
	}
	close $res;
    }

    my @conds;
    if ( $rule_type eq 'or' ) {
	@conds = split(/\|/, $rule_def);
    }
    elsif ( $rule_type eq 'and' ) {
	@conds = split(/\,/, $rule_def);
    }

    my $eval_result = 0;
    if ( $rule_type eq 'and' ) {
	$eval_result = 1;
    }

    my $url2 = "$main_cgi?section=WorkspaceRuleSet&page=taxonCondDetail" .
	"&taxon_oid=$taxon_oid";
    if ( $include_myimg ) {
	$url2 .= "&include_myimg=$include_myimg";
    }

    print "<table class='img' border='1'>\n";
    my $j = 0;
    for my $cond1 ( @conds ) {
	my $def1 = printRuleDefinition($cond1);
	my $result = -1;
	print "<tr class='img'>\n";
	if ( $j > 0 ) {
	    print "<td class='img'>$rule_type</td>\n";
	}
	else {
	    print "<td class='img'> </td>\n";
	}

	if ( $rule_type eq 'or' ) {
	    $result = evalOrRuleOnGenome($dbh, $cond1, $taxon_oid, $include_myimg);

	    if ( $result > 0 ) {
		$eval_result = 1;
	    }
	    elsif ( $result < 0 ) {
		if ( $eval_result == 0 ) {
		    $eval_result = -1;
		}
	    }
	}
	elsif ( $rule_type eq 'and' ) {
	    $result = evalAndRuleOnGenome($dbh, $cond1, $taxon_oid, $include_myimg);

	    if ( $result == 0 ) {
		$eval_result = 0;
	    }
	    elsif ( $result < 0 ) {
		if ( $eval_result > 0 ) {
		    $eval_result = -1;
		}
	    }
	}

	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}
	print "<td class='img'>$cond1</td>\n";
	print "<td class='img'>$def1</td>\n";
	print "<td class='img'>";
	my $url3 = $url2 . "&cond=" . $cond1;

	if ( $result > 0 ) {
	    print alink($url3, "true");
	}
	elsif ( $result < 0 ) {
	    print alink($url3, "unknown");
	}
	else {
	    print alink($url3, "false");
	}
	print "</td>\n";
	print "</tr>\n";
	$j++;
    }
    print "</table>\n";

    print "<p><b>Evaluation Result: ";
    if ( $eval_result > 0 ) {
	print "true";
    }
    elsif ( $eval_result < 0 ) {
	print "unknown";
    }
    else {
	print "false";
    }
    print "</b>\n";

    print "<p>\n";
    print submit( -name  => "_section_WorkspaceRuleSet_listRuleGenes",
		  -value => "List Genes", 
		  -class => 'meddefbutton' );

    print end_form();
}


#############################################################################
# listRuleGenes
#############################################################################
sub listRuleGenes {
    my $sid = getContactOid();

    printMainForm();

    my $filename = param("filename");
    my $taxon_oid = param("taxon_oid");
    my $rule_id = param("rule_id");
    my $include_myimg = param('include_myimg');
    my $bc_id = param("cluster_id");

    WebUtil::checkFileName($filename);

    print "<h1>Gene List (Rule $rule_id in $filename)</h1>\n";

    if ( $include_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
    }

    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon_oid");
    my $sql = "select t.taxon_display_name from taxon t where t.taxon_oid = ? " .
	$rclause;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_name) = $cur->fetchrow();
    $cur->finish();
    if ( ! $taxon_name ) {
	#$dbh->disconnect();
	return;
    }

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
    $url .= "&taxon_oid=$taxon_oid";
    print "<h3>" . alink($url, $taxon_name);
    if ( $bc_id ) {
	print " (Cluster $bc_id)";
    }
    print "</h3>\n";

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my $rule_type;
    my $rule_def;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    if ( $id eq $rule_id ) {
		$rule_type = $type;
		$rule_def = $body;
		last;
	    }
	}
	close $res;
    }

    my @conds;
    if ( $rule_type eq 'or' ) {
	@conds = split(/\|/, $rule_def);
    }
    elsif ( $rule_type eq 'and' ) {
	@conds = split(/\,/, $rule_def);
    }

    my $eval_result = 0;
    if ( $rule_type eq 'and' ) {
	$eval_result = 1;
    }

    my $url2 = "$main_cgi?section=WorkspaceRuleSet&page=taxonCondDetail" .
	"&taxon_oid=$taxon_oid";
    if ( $include_myimg ) {
	$url2 .= "&include_myimg=$include_myimg";
    }

    my %genes_h;

    print "<table class='img' border='1'>\n";
    my $j = 0;
    for my $cond1 ( @conds ) {
	if ( $rule_type eq 'or' ) {
	    getOrRuleGenesOnGenome($dbh, $cond1, $taxon_oid, $include_myimg,
		\%genes_h);
	}
	elsif ( $rule_type eq 'and' ) {
	    getAndRuleGenesOnGenome($dbh, $cond1, $taxon_oid, $include_myimg,
		\%genes_h);
	}
	$j++;
    }

    my %bc_h;
    if ( $bc_id ) {
	my $sql =  "select feature_id from bio_cluster_features_new " .
	    "where feature_type = 'gene' and cluster_id = ? ";
	my $cur = execSql( $dbh, $sql, $verbose, $bc_id );
	for (;;) {
	    my ($gene2) = $cur->fetchrow();
	    last if ! $gene2;
	    $bc_h{$gene2} = $gene2;
	}
	$cur->finish();
    }

    my $it = new InnerTable( 1, "ruleGenes$$", "ruleGenes", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "char asc", "left" );
    $it->addColSpec( "Gene Name",   "char asc", "left" );
    $it->addColSpec( "Functions", "char asc", "left" ); 
    my $sd = $it->getSdDelim(); 

    my $cnt = 0;
    for my $workspace_id (keys %genes_h) {
	my $url = "";
	my $gene_oid;
	my $gene_name;

	if ( isInt($workspace_id) ) {
	    $gene_oid = $workspace_id;
	    if ( $bc_id && ! $bc_h{$gene_oid} ) {
		next;
	    }

	    $url = "$main_cgi?section=GeneDetail&page=geneDetail" .
		"&gene_oid=$gene_oid";
	    $gene_name = geneOid2Name($dbh, $gene_oid);
	}
	else {
	    my ($t2, $d2, $g2) = split(/ /, $workspace_id);
	    $gene_oid = $g2;
	    if ( $bc_id && ! $bc_h{$gene_oid} && !$bc_h{$g2} ) {
		next;
	    }

	    $url = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail";
	    $url .= "&taxon_oid=$t2&data_type=$d2&gene_oid=$gene_oid";
	    my ($n2, $r2) = MetaUtil::getGeneProdNameSource($gene_oid,
							    $t2, $d2);
	    $gene_name = $n2;
	}

	my $r = $sd . "<input type='checkbox' name='gene_oid' value='$workspace_id' checked /> \t";
	$r .= $gene_oid . $sd . alink($url, $gene_oid) . "\t";

	if ( ! $gene_name ) {
	    $gene_name = "hypothetical protein";
	}
	$r .= $gene_name . $sd . $gene_name . "\t";

	my $res = "";
	my $k2 = $genes_h{$workspace_id};
	for my $func2 (keys %$k2) {
	    $res .= " " . $func2;
	}

	$r .= $res . $sd . $res . "\t";

	$cnt++;
        $it->addRow($r); 
    }

    if ( $cnt ) {
	$it->printOuterTable(1);
	WebUtil::printGeneCartFooter();
    }

    print end_form();
}


#############################################################################
# showTaxonCondDetail
#############################################################################
sub showTaxonCondDetail {
    my $sid = getContactOid();

    printMainForm();

    my $taxon_oid = param("taxon_oid");
    my $bc_id = param("cluster_id");
    my $cond = param("cond");
    my $include_myimg = param('include_myimg');

    my @pways = ();

    my $dbh = dbLogin();
    my $sql = "select t.taxon_oid, t.taxon_display_name, t.in_file " .
	"from taxon t where t.taxon_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($t2, $taxon_name, $taxon_in_file) = $cur->fetchrow();
    $cur->finish();

    if ( ! $t2 ) {
	webError("Error: Incorrect Taxon OID.");
	$dbh->disconnect();
	return;
    }

    print "<h1>$taxon_name</h1>\n";
    if ( $bc_id ) {
	print "<h4>Cluster $bc_id</h4>\n";
    }
    print "<h2>Condition: $cond</h2>\n";

    if ( $include_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
    }


    my %bc_h;
    if ( $bc_id ) {
	my $sql =  "select feature_id from bio_cluster_features_new " .
	    "where feature_type = 'gene' and cluster_id = ? ";
	my $cur = execSql( $dbh, $sql, $verbose, $bc_id );
	for (;;) {
	    my ($gene2) = $cur->fetchrow();
	    last if ! $gene2;
	    $bc_h{$gene2} = $gene2;
	}
	$cur->finish();
    }

    $cond =~ s/\|/\t/g;
    $cond =~ s/\,/\t/g;
    my @func_ids = split(/\t/, $cond);
    for my $func_id ( @func_ids ) {
	my $cnt = 0;
	my $rclause = WebUtil::urClause('g.taxon'); 
	my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
	my $func_name = Workspace::getMetaFuncName($func_id);
	print "<h5>Function: $func_id: $func_name</h5>\n";

	if ( $taxon_in_file eq 'Yes' ) {
	    my %genes = MetaUtil::getTaxonFuncGenes($taxon_oid, 'both', $func_id);
	    for my $gene_oid (keys %genes) {
		my $workspace_id = $genes{$gene_oid};
		my ($t2, $d2, $g2) = split(/ /, $workspace_id);
		if ( $bc_id && ! $bc_h{$gene_oid} && !$bc_h{$g2} ) {
		    next;
		}

		my ($gene_name, $source) = MetaUtil::getGeneProdNameSource($g2, $t2, $d2);
		my $url = "$main_cgi?section=MetaGeneDetail"; 
		$url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid"
		    . "&data_type=$d2&gene_oid=$g2";
		print "<p>" . alink($url, $g2) . " " . $gene_name . "\n";
		$cnt++;
	    }
	}
	else {
	    my $sql = "";
	    my @bindList = ();

	    if ( $func_id =~ /^IPWAY/ ) {
		my ($f1, $f2) = split(/\:/, $func_id);
		if ( isInt($f2) ) {
		    push @pways, ( $f2 );
		}
		else {
		    $f2 = "0";
		}
		my @terms = ImgPwayBrowser::getPwayAllTerms($dbh, $f2);
		my $term_str = "";
		my $term_cnt = 0;
		for my $term1 ( @terms ) {
		    $term_cnt++;
		    if ( $term_cnt <= 1000 ) {
			if ( $term_str ) {
			    $term_str .= ", " . $term1;
			}
			else {
			    $term_str = $term1;
			}
		    }
		}
		if ( ! $term_str ) {
		    $term_str = "0";
		}

		$sql = "select gene_oid, function from gene_img_functions " .
		    "where taxon = ? and function in ( $term_str) ";
		@bindList = ( $taxon_oid );

		if ( $include_myimg ) {
		    my $sql2 = "select gmt.gene_oid, gmt.term_oid " .
			"from gene_myimg_terms gmt, gene_myimg_functions f " .
		    "where gmt.term_oid in ( $term_str ) " .
		    "and f.taxon = ? " .
		    "and gmt.gene_oid = f.gene_oid " .
		    "and gmt.modified_by = f.modified_by ";
		    if ( $include_myimg == 1 ) {
			$sql2 .= "and f.modified_by = $sid";
		    }
		    elsif ( $include_myimg == 2 ) {
			$sql2 .= "and f.is_public = 'Yes'";
		    }
		    elsif ( $include_myimg == 2 ) {
			$sql2 .= "and (f.modified_by = $sid or f.is_public = 'Yes')";
		    }

		    $sql = "(" . $sql . ") union (" . $sql2 . ")";
		    @bindList = ( $taxon_oid, $taxon_oid );
		}
	    }
	    else {
		($sql, @bindList) = WorkspaceQueryUtil::getDbTaxonSimpleFuncGeneSql( $func_id, 
					       $taxon_oid, $rclause, $imgClause );
	    }

	    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

	    for (;;) {
		my ($gene_oid, $f2) = $cur->fetchrow();
		last if ! $gene_oid;

		if ( $bc_id && ! $bc_h{$gene_oid} ) {
		    next;
		}

		my $url = "$main_cgi?section=GeneDetail"; 
		$url .= "&page=geneDetail&gene_oid=$gene_oid";
		my ($gene_name) = WebUtil::geneOid2Name($dbh, $gene_oid);
		print "<p>" . alink($url, $gene_oid) . " " . $gene_name . "\n";
		$cnt++;
	    }
	    $cur->finish();

	    if ( ($func_id =~ /^ITERM/ || $func_id =~ /^EC/) 
		    && $include_myimg ) {
		my ($f1, $f2) = split(/\:/, $func_id);
		my $db_id = 0;
		my $table_name = "gene_myimg_enzymes";
		my $attr_name = "ec_number";
		if ( $f1 =~ /ITERM/ ) {
		    if ( isInt($f2) ) {
			$db_id = $f2;
			$table_name = "gene_myimg_terms";
			$attr_name = "term_oid";
		    }
		}
		elsif ( $f2 =~ /EC/ ) {
		    $db_id = $func_id;
		}

		my $sql2 = "select gmt.gene_oid, gmt.modified_by " .
		    "from " . $table_name . " gmt, gene_myimg_functions f " .
		    "where gmt." . $attr_name . " = ? " .
		    "and gmt.gene_oid = f.gene_oid and gmt.modified_by = f.modified_by ";
		if ( $include_myimg == 1 ) {
		    $sql2 .= "and f.modified_by = $sid";
		}
		elsif ( $include_myimg == 2 ) {
		    $sql2 .= "and f.is_public = 'Yes'";
		}
		elsif ( $include_myimg == 2 ) {
		    $sql2 .= "and (f.modified_by = $sid or f.is_public = 'Yes')";
		}
		$sql2 .= "and f.gene_oid in (select g.gene_oid from gene g where g.taxon = ?)";

		#print "<p>SQL: $sql2 ($taxon_oid)\n";
		my $cur2 = execSql( $dbh, $sql2, $verbose, $db_id, $taxon_oid );
		for (;;) {
		    my ($gene_oid, $modified_by) = $cur2->fetchrow();
		    last if ! $gene_oid;

		    if ( $bc_id && ! $bc_h{$gene_oid} ) {
			next;
		    }

		    my $url = "$main_cgi?section=GeneDetail"; 
		    $url .= "&page=geneDetail&gene_oid=$gene_oid";
		    my ($gene_name) = WebUtil::geneOid2Name($dbh, $gene_oid);
		    print "<p>";
		    if ( $modified_by == $sid ) {
			print "(MyIMG) ";
		    }
		    else {
			print "(Public MyIMG) ";
		    }
		    print alink($url, $gene_oid) . " " . $gene_name . "\n";
		    $cnt++;
		}
		$cur2->finish();
	    }
	}

	if ( ! $cnt ) {
	    print "<p>No genes.\n";
	}
    }

    if ( scalar(@pways) > 0 ) {
	print "<h6>Existing IMG Pathway Assertion Result</h6>\n";
	print "<p><table class='img'>\n";
	print "<th class='img'>Pathway ID</th>\n";
	print "<th class='img'>Status</th>\n";
	print "<th class='img'>Evidence</th>\n";
	print "<th class='img'>Comments</th>\n";
	print "<th class='img'>Modified By</th>\n";
	print "<th class='img'>Mod Date</th>\n";

	my $sql = "select p.pathway_oid, p.status, p.evidence, p.comments, " .
	    " c.name, p.mod_date " .
	    "from img_pathway_assertions p, contact c " .
	    "where p.taxon = ? and p.modified_by = c.contact_oid " .
	    "and p.pathway_oid in (" . join(", ", @pways) . ") ";
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	for (;;) {
	    my ($pid, $status, $evid, $comments, $name, $mod_date) =
		$cur->fetchrow();
	    last if ! $pid;
	    print "<tr class='img'>\n";
	    my $p_url = "$main_cgi?section=ImgPwayBrowser";
	    $p_url .= "&page=imgPwayDetail";
	    $p_url .= "&pway_oid=$pid";
	    print "<td class='img'>" .
		alink($p_url, $pid) . "</td>\n";

	    $p_url = "$main_cgi?section=ImgPwayBrowser" .
		"&page=pwayTaxonDetail" .
		"&pway_oid=$pid&taxon_oid=$taxon_oid";
	    print "<td class='img'>" .
		alink($p_url, $status) . "</td>\n";

	    print "<td class='img'>$evid</td>\n";
	    print "<td class='img'>$comments</td>\n";
	    print "<td class='img'>$name</td>\n";
	    print "<td class='img'>$mod_date</td>\n";
	    print "</tr>\n";
	}
	print "</table>\n";
	$cur->finish();
    }

    $dbh->disconnect();
    print end_form();
}


#############################################################################
# evalRuleOnGenome
#
# rule_type: and, or
# rule_def: rule definition
# taxon_oid: taxon to be evaluated
#############################################################################
sub evalRuleOnGenome {
    my ($dbh, $rule_type, $rule_def, $taxon_oid, $include_myimg) = @_;

    my $result = 0;

    if ( $rule_type eq 'and' ) {
	$result = evalAndRuleOnGenome($dbh, $rule_def, $taxon_oid, $include_myimg);
    }
    else {
	$result = evalOrRuleOnGenome($dbh, $rule_def, $taxon_oid, $include_myimg);
    }

    return $result;
}

#############################################################################
# evalRuleOnGenomeSet
#
# rule_type: and, or
# rule_def: rule definition
# taxon_str: taxons to be evaluated
#############################################################################
sub evalRuleOnGenomeSet {
    my ($dbh, $rule_type, $rule_def, $taxon_str, $res_href, $include_myimg) = @_;

    if ( $rule_type eq 'and' ) {
	evalAndRuleOnGenomeSet($dbh, $rule_def, $taxon_str, $res_href, $include_myimg);
    }
    else {
	evalOrRuleOnGenomeSet($dbh, $rule_def, $taxon_str, $res_href, $include_myimg);
    }
}


#############################################################################
# evalOrRuleOnGenome
#
# rule_def: rule definition
# taxon_oid: taxon to be evaluated
#############################################################################
sub evalOrRuleOnGenome {
    my ($dbh, $rule_def, $taxon_oid, $include_myimg) = @_;

    my @conds = split(/\|/, $rule_def);

    my $result1 = 0;
    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my $result2 = 1;
	my @comps = split(/\,/, $cond1);
	for my $c2 ( @comps ) {
	    my $result3 = evalFuncOnGenome($dbh, $c2, $taxon_oid, $include_myimg);
	    if ( $result3 == 0 ) {
		# false
		$result2 = 0;
		last;
	    }
	    elsif ( $result3 < 0 ) {
		# unknown
		$result2 = -1;
	    }
	}

	if ( $result2 > 0 ) {
	    # true
	    $result1 = 1;
	    last;
	}
	elsif ( $result2 < 0 ) {
	    # unknown
	    $result1 = -1;
	}
    }

    return $result1;
}

#############################################################################
# getOrRuleGenesOnGenome
#
# rule_def: rule definition
# taxon_oid: taxon to be evaluated
#############################################################################
sub getOrRuleGenesOnGenome {
    my ($dbh, $rule_def, $taxon_oid, $include_myimg, $gene_href) = @_;

    my @conds = split(/\|/, $rule_def);

    my %func_h;

    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my @comps = split(/\,/, $cond1);
	for my $c2 ( @comps ) {
	    if ( $func_h{$c2} ) {
		# already did
		next;
	    }
	    $func_h{$c2} = 1;
	    getFuncGenesOnGenome($dbh, $c2, $taxon_oid, $include_myimg,
		$gene_href);
	}
    }

}


#############################################################################
# evalOrRuleOnGenomeSet
#
# rule_def: rule definition
# taxon_str: taxons to be evaluated
#############################################################################
sub evalOrRuleOnGenomeSet {
    my ($dbh, $rule_def, $taxon_str, $res_href, $include_myimg) = @_;

    my @conds = split(/\|/, $rule_def);
    my @taxons = split(/\,/, $taxon_str);

    for my $taxon_oid ( @taxons ) {
	$res_href->{$taxon_oid} = 0;
    }

    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my %res2;
	for my $taxon_oid ( @taxons ) {
	    $res2{$taxon_oid} = 1;
	}

	my @comps = split(/\,/, $cond1);
	for my $c2 ( @comps ) {
	    my %res3;
	    evalFuncOnGenomeSet($dbh, $c2, $taxon_str, \%res3, $include_myimg);
	    for my $taxon_oid ( @taxons ) {
		if ( ! $res3{$taxon_oid} ) {
		    # false
		    $res2{$taxon_oid} = 0;
		}
		elsif ( $res3{$taxon_oid} < 0 ) {
		    # unknown
		    $res2{$taxon_oid} = -1;
		}
	    }
	}   # end for c2

	for my $taxon_oid ( @taxons ) {
	    if ( $res2{$taxon_oid} > 0 ) {
		# true
		$res_href->{$taxon_oid} = 1;
	    }
	    elsif ( $res2{$taxon_oid} < 0 ) {
		# unknown
		$res_href->{$taxon_oid} = -1;
	    }
	}
    }
}


#############################################################################
# evalAndRuleOnGenome
#
# rule_def: rule definition
# taxon_oid: taxon to be evaluated
#############################################################################
sub evalAndRuleOnGenome {
    my ($dbh, $rule_def, $taxon_oid, $include_myimg) = @_;

    my @conds = split(/\,/, $rule_def);

    my $result1 = 1;
    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my $result2 = 0;
	my @comps = split(/\|/, $cond1);
	for my $c2 ( @comps ) {
	    my $result3 = evalFuncOnGenome($dbh, $c2, $taxon_oid, $include_myimg);

	    if ( $result3 == 1 ) {
		# true
		$result2 = 1;
		last;
	    }
	    elsif ( $result3 < 0 ) {
		# unknown
		if ( $result2 == 0 ) {
		    $result2 = -1;
		}
	    }
	}

	if ( $result2 == 0 ) {
	    # false
	    $result1 = 0;
	    last;
	}
	elsif ( $result2 < 0 ) {
	    # unknown
	    if ( $result1 > 0 ) {
		$result1 = -1;
	    }
	}
    }

    return $result1;
}


#############################################################################
# getAndRuleGenesOnGenome
#
# rule_def: rule definition
# taxon_oid: taxon to be evaluated
#############################################################################
sub getAndRuleGenesOnGenome {
    my ($dbh, $rule_def, $taxon_oid, $include_myimg, $gene_href) = @_;

    my @conds = split(/\,/, $rule_def);

    my %func_h;

    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my @comps = split(/\|/, $cond1);
	for my $c2 ( @comps ) {
	    if ( $func_h{$c2} ) {
		# already did
		next;
	    }
	    $func_h{$c2} = 1;

	    getFuncGenesOnGenome($dbh, $c2, $taxon_oid, $include_myimg,
		$gene_href);
	}
    }

}


#############################################################################
# evalAndRuleOnGenomeSet
#
# rule_def: rule definition
# taxon_str: taxon2 to be evaluated
#############################################################################
sub evalAndRuleOnGenomeSet {
    my ($dbh, $rule_def, $taxon_str, $res_href, $include_myimg) = @_;

    my @conds = split(/\,/, $rule_def);
    my @taxons = split(/\,/, $taxon_str);

    for my $taxon_oid ( @taxons ) {
	$res_href->{$taxon_oid} = 1;
    }
    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my %res2;
	for my $taxon_oid ( @taxons ) {
	    $res2{$taxon_oid} = 0;
	}

	my @comps = split(/\|/, $cond1);
	for my $c2 ( @comps ) {
	    my %res3;
	    evalFuncOnGenomeSet($dbh, $c2, $taxon_str, \%res3, $include_myimg);

	    for my $taxon_oid ( @taxons ) {
		if ( $res3{$taxon_oid} == 1 ) {
		    # true
		    $res2{$taxon_oid} = 1;
		}
		elsif ( $res3{$taxon_oid} < 0 ) {
		    # unknown
		    if ( ! $res2{$taxon_oid} == 0 ) {
			$res2{$taxon_oid} = -1;
		    }
		}
	    }
	}  # end for c2

	for my $taxon_oid ( @taxons ) {
	    if ( ! $res2{$taxon_oid} ) {
		# false
		$res_href->{$taxon_oid} = 0;
	    }
	    elsif ( $res2{$taxon_oid} < 0 ) {
		# unknown
		if ( $res_href->{$taxon_oid} > 0 ) {
		    $res_href->{$taxon_oid} = -1;
		}
	    }
	}
    }
}


#############################################################################
# evalFuncOnGenome
#
# func_id: function id
# taxon_oid: taxon to be evaluated
# return: true 1, false 0, unknown -1
#############################################################################
sub evalFuncOnGenome {
    my ($dbh, $func_id, $taxon_oid, $include_myimg) = @_;

    my $sql = "select in_file from taxon where taxon_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_in_file) = $cur->fetchrow();
    $cur->finish();

    my $neg = 0;
    if ( $func_id =~ /^\!/ ) {
	$neg = 1;
	$func_id = substr($func_id, 1, length($func_id)-1);
    }

    if ( $taxon_in_file eq 'Yes' ) {
	my $cnt = MetaUtil::getTaxonOneFuncCnt($taxon_oid, 'both', $func_id);
	if ( $cnt ) {
	    if ( $neg ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
	else {
	    if ( $neg ) {
		return 1;
	    }
	    else {
		return 0;
	    }
	}
    }

    my ($f1, $f2) = split(/\:/, $func_id);

    if ( $f1 eq 'IPWAY' ) {
	if ( ! $f2 ) {
	    $f2 = 0;
	}

	my $sql = "select status from img_pathway_assertions where " .
	    "pathway_oid = ? and taxon = ?";

	my $cur = execSql( $dbh, $sql, $verbose, $f2, $taxon_oid );
	my ($res) = $cur->fetchrow();
	$cur->finish();

	if ( $res eq 'asserted' ) {
	    if ( $neg ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
	elsif ( $res eq 'not asserted' ) {
	    if ( $neg ) {
		return 1;
	    }
	    else {
		return 0;
	    }
	}
	else {
	    return -1;
	}
    }
    else {
	my $sql = "";
	my @bindList = ();
        my $rclause = WebUtil::urClause('g.taxon'); 
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

	($sql, @bindList) = WorkspaceQueryUtil::getDbTaxonFuncGeneCountSql( $func_id, 
				       $taxon_oid, $rclause, $imgClause );
	my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
	my ($cnt1) = $cur->fetchrow();
	$cur->finish();

	if ( ! $cnt1 && $include_myimg &&
	     ($func_id =~ /^ITERM/ || $func_id =~ /^EC/) ) {
	    # check MyIMG annotations
	    my $table_name = 'gene_myimg_terms';
	    my $attr_name = 'term_oid';
	    my ($f1, $f2) = split(/\:/, $func_id);
	    if ( ! $f2 ) {
		$f2 = 0;
	    }
	    if ( $f1 =~ /EC/ ) {
		$f2 = $func_id;
		$table_name = 'gene_myimg_enzymes';
		$attr_name = 'ec_number';
	    }

	    my $sid = getContactOid();
	    $sql = "select count(*) from " . $table_name . " gmt, gene_myimg_functions f " .
		"where gmt." . $attr_name . " = ? " .
		"and gmt.gene_oid = f.gene_oid and gmt.modified_by = f.modified_by ";
	    if ( $include_myimg == 1 ) {
		$sql .= "and f.modified_by = $sid ";
	    }
	    elsif ( $include_myimg == 2 ) {
		$sql .= "and f.is_public = 'Yes' ";
	    }
	    elsif ( $include_myimg >= 3 ) {
		$sql .= "and (f.modified_by = $sid or f.is_public = 'Yes') ";
	    }
	    $sql .= "and f.gene_oid in (select g.gene_oid from gene g where g.taxon = ?)";
	    #print "<p>SQL: $sql ($taxon_oid)\n";
	    $cur = execSql( $dbh, $sql, $verbose, $f2, $taxon_oid );
	    ($cnt1) = $cur->fetchrow();
	    $cur->finish();
	}

	if ( $cnt1 ) {
	    if ( $neg ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
	else {
	    if ( $neg ) {
		return 1;
	    }
	    else {
		return 0;
	    }
	}
    }

    if ( $neg ) {
	return 1;
    }

    return 0;
}

#############################################################################
# getFuncGenesOnGenome
#
# func_id: function id
# taxon_oid: taxon to be evaluated
#############################################################################
sub getFuncGenesOnGenome {
    my ($dbh, $func_id, $taxon_oid, $include_myimg, $gene_href) = @_;

    my $sql = "select in_file from taxon where taxon_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_in_file) = $cur->fetchrow();
    $cur->finish();

    my $neg = 0;
    if ( $func_id =~ /^\!/ ) {
	$neg = 1;
	$func_id = substr($func_id, 1, length($func_id)-1);
    }

    if ( $taxon_in_file eq 'Yes' ) {
	my %genes = MetaUtil::getTaxonFuncGenes($taxon_oid, 'both', $func_id);
	for my $k2 (keys %genes) {
	    my $workspace_id = $genes{$k2};
	    if ( $gene_href->{$workspace_id} ) {
		my $h3 = $gene_href->{$workspace_id};
		$h3->{$func_id} = 1;
	    }
	    else {
		my %h2;
		$h2{$func_id} = 1;
		$gene_href->{$workspace_id} = \%h2;
	    }
	}
	return;
    }

    my ($f1, $f2) = split(/\:/, $func_id);

    if ( $f1 eq 'IPWAY' ) {
	if ( ! $f2 ) {
	    $f2 = 0;
	}

	my $sql = qq{
           select gif.gene_oid from gene_img_functions gif
           where gif.taxon = ?
           and gif.function in
           (select irc.catalysts
            from img_pathway_reactions ipr, img_reaction_catalysts irc
            where ipr.pathway_oid = ?
            and ipr.rxn = irc.rxn_oid
            union
            select rtc.term
            from img_pathway_reactions ipr, img_reaction_t_components rtc
            where ipr.pathway_oid = ?
            and ipr.rxn = rtc.rxn_oid )
            };
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $f2, $f2 );

	for (;;) {
	    my ($gene_oid) = $cur->fetchrow();
	    last if ! $gene_oid;

	    if ( $gene_href->{$gene_oid} ) {
		my $h3 = $gene_href->{$gene_oid};
		$h3->{$func_id} = 1;
	    }
	    else {
		my %h2;
		$h2{$func_id} = 1;
		$gene_href->{$gene_oid} = \%h2;
	    }
	}
	$cur->finish();
    }
    else {
	my $sql = "";
	my @bindList = ();
        my $rclause = WebUtil::urClause('g.taxon'); 
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

	($sql, @bindList) = WorkspaceQueryUtil::getDbTaxonSimpleFuncGeneSql( $func_id, 
				       $taxon_oid, $rclause, $imgClause );
	my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
	for (;;) {
	    my ($gene_oid, $f3) = $cur->fetchrow();
	    last if ! $gene_oid;

	    if ( $gene_href->{$gene_oid} ) {
		my $h3 = $gene_href->{$gene_oid};
		$h3->{$func_id} = 1;
	    }
	    else {
		my %h2;
		$h2{$func_id} = 1;
		$gene_href->{$gene_oid} = \%h2;
	    }
	}
	$cur->finish();

	if ( $include_myimg &&
	     ($func_id =~ /^ITERM/ || $func_id =~ /^EC/) ) {
	    # check MyIMG annotations
	    my $table_name = 'gene_myimg_terms';
	    my $attr_name = 'term_oid';
	    my ($f1, $f2) = split(/\:/, $func_id);
	    if ( ! $f2 ) {
		$f2 = 0;
	    }
	    if ( $f1 =~ /EC/ ) {
		$f2 = $func_id;
		$table_name = 'gene_myimg_enzymes';
		$attr_name = 'ec_number';
	    }

	    my $sid = getContactOid();
	    $sql = "select f.gene_oid from " . $table_name . 
		" gmt, gene_myimg_functions f " .
		"where gmt." . $attr_name . " = ? " .
		"and gmt.gene_oid = f.gene_oid and gmt.modified_by = f.modified_by ";
	    if ( $include_myimg == 1 ) {
		$sql .= "and f.modified_by = $sid ";
	    }
	    elsif ( $include_myimg == 2 ) {
		$sql .= "and f.is_public = 'Yes' ";
	    }
	    elsif ( $include_myimg >= 3 ) {
		$sql .= "and (f.modified_by = $sid or f.is_public = 'Yes') ";
	    }
	    $sql .= "and f.gene_oid in (select g.gene_oid from gene g where g.taxon = ?)";
	    #print "<p>SQL: $sql ($taxon_oid)\n";
	    $cur = execSql( $dbh, $sql, $verbose, $f2, $taxon_oid );
	    for (;;) {
		my ($gene_oid) = $cur->fetchrow();
		last if ! $gene_oid;

		if ( $gene_href->{$gene_oid} ) {
		    my $h3 = $gene_href->{$gene_oid};
		    $h3->{$func_id} = 1;
		}
		else {
		    my %h2;
		    $h2{$func_id} = 1;
		    $gene_href->{$gene_oid} = \%h2;
		}
	    }
	    $cur->finish();
	}
    }

}


#############################################################################
# evalFuncOnGenomeSet
#
# func_id: function id
# taxon_str: taxon to be evaluated
# return: $res_href (true 1, false 0, unknown -1)
#############################################################################
sub evalFuncOnGenomeSet {
    my ($dbh, $func_id, $taxon_str, $res_href, $include_myimg) = @_;

    my $neg = 0;
    if ( $func_id =~ /^\!/ ) {
	$neg = 1;
	$func_id = substr($func_id, 1, length($func_id)-1);
    }

    my $sid = getContactOid();
    my ($f1, $f2) = split(/\:/, $func_id);

    my @db_taxons = ();
    my @fs_taxons = ();
    my $sql = "select taxon_oid, in_file from taxon where taxon_oid in (" .
	$taxon_str . ") and obsolete_flag = 'No' ";
    my $cur = execSql( $dbh, $sql, $verbose );
    for (;;) {
	my ($taxon_oid, $taxon_in_file) = $cur->fetchrow();
	last if ! $taxon_oid;

	if ( $taxon_in_file eq 'Yes' ) {
	    push @fs_taxons, ( $taxon_oid );
	}
	else {
	    push @db_taxons, ( $taxon_oid );
	}
    }
    $cur->finish();

    if ( scalar(@db_taxons) > 0 ) {
	my $db_str = join(", ", @db_taxons);

	# check MyIMG?
	my %myimg_cnt;
	if ( ($f1 eq 'ITERM' || $f1 =~ /EC/) && $include_myimg ) {
	    # check MyIMG
	    my $table_name = 'gene_myimg_terms';
	    my $attr_name = 'term_oid';
	    if ( ! $f2 ) {
		$f2 = 0;
	    }
	    if ( $f1 =~ /EC/ ) {
		$f2 = $func_id;
		$table_name = 'gene_myimg_enzymes';
		$attr_name = 'ec_number';
	    }

	    my $sql2 = "select g.taxon, count(*) " .
		"from " . $table_name . " gmt, gene_myimg_functions f, gene g " .
		"where gmt." . $attr_name . " = ? " .
		"and gmt.gene_oid = f.gene_oid and gmt.modified_by = f.modified_by ";
	    if ( $include_myimg == 1 ) {
		$sql2 .= "and f.modified_by = $sid ";
	    }
	    elsif ( $include_myimg == 2 ) {
		$sql2 .= "and f.is_public = 'Yes' ";
	    }
	    elsif ( $include_myimg == 2 ) {
		$sql2 .= "and (f.modified_by = $sid or f.is_public = 'Yes') ";
	    }
	    $sql2 .= "and f.gene_oid = g.gene_oid ";
	    $sql2 .= "group by g.taxon";
	    # print "<p>SQL: $sql2\n";
	    my $cur2 = execSql( $dbh, $sql2, $verbose, $f2 );
	    for (;;) {
		my ($tid, $cnt) = $cur2->fetchrow();
		last if ! $tid;
		$myimg_cnt{$tid} = $cnt;
	    }
	    $cur2->finish();
	}

	$sql = "";
	my @bindList = ();
        my $rclause = WebUtil::urClause('g.taxon'); 
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

	if ( $f1 eq 'IPWAY' ) {
	    $sql = "select g.taxon, g.status from img_pathway_assertions g " .
		"where g.taxon in ( $db_str ) and g.pathway_oid = ? ";
		$rclause . $imgClause;
	    @bindList = ( $f2 );
	}
	else {
	    ($sql, @bindList) = WorkspaceQueryUtil::getDbTaxonFuncGroupByCountSql( $func_id, 
				       $db_str, $rclause, $imgClause );
	}
	#print "<p>SQL: $sql (" . join(",", @bindList) . ")\n";
	$cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

	my %query_cnt;
	for (;;) {
	    my ($taxon_oid, $res) = $cur->fetchrow();
	    last if ! $taxon_oid;

	    $query_cnt{$taxon_oid} = $res;
	}
	$cur->finish();

	for my $taxon_oid ( @db_taxons ) {
	    my $res = $query_cnt{$taxon_oid};

	    if ( $f1 eq 'IPWAY' ) {
		if ( $res eq 'asserted' ) {
		    if ( $neg ) {
			$res_href->{$taxon_oid} = 0;
		    }
		    else {
			$res_href->{$taxon_oid} = 1;
		    }
		}
		elsif ( $res eq 'not asserted' ) {
		    if ( $neg ) {
			$res_href->{$taxon_oid} = 1;
		    }
		    else {
			$res_href->{$taxon_oid} = 0;
		    }
		}
		else {
		    $res_href->{$taxon_oid} = -1;
		}
	    }
	    else {
		if ( $myimg_cnt{$taxon_oid} ) {
		    $res += $myimg_cnt{$taxon_oid};
		}

		if ( $res ) {
		    if ( $neg ) {
			$res_href->{$taxon_oid} = 0;
		    }
		    else {
			$res_href->{$taxon_oid} = 1;
		    }
		}
		else {
		    if ( $neg ) {
			$res_href->{$taxon_oid} = 1;
		    }
		    else {
			$res_href->{$taxon_oid} = 0;
		    }
		}
	    }
	}   # end for loop
    }

    if ( scalar( @fs_taxons ) > 0 ) {
	my $table_name = "";
	if ( $func_id =~ /COG/ ) {
	    $table_name = "taxon_cog_count";
	}
	elsif ( $func_id =~ /pfam/ ) {
	    $table_name = "taxon_pfam_count";
	}
	elsif ( $func_id =~ /TIGR/ ) {
	    $table_name = "taxon_tigr_count";
	}
	elsif ( $func_id =~ /EC\:/ ) {
	    $table_name = "taxon_ec_count";
	}
	elsif ( $func_id =~ /KO\:/ ) {
	    $table_name = "taxon_ko_count";
	}

	if ( $table_name ) {
	    my $fs_str = join(", ", @fs_taxons);
	    my $rclause = WebUtil::urClause('t.taxon_oid'); 
	    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
	    my $sql2 = "select t.taxon_oid, sum(t.gene_count) from " . $table_name .
		" t where t.taxon_oid in (" . $fs_str . ") " .
		" and t.func_id = ? " .
		$rclause . $imgClause . 
		" group by t.taxon_oid";
	    my $cur2 = execSql( $dbh, $sql2, $verbose, $func_id );
	    for (;;) {
		my ($taxon_oid, $res) = $cur2->fetchrow();
		last if ! $taxon_oid;

		if ( $res ) {
		    if ( $neg ) {
			$res_href->{$taxon_oid} = 0;
		    }
		    else {
			$res_href->{$taxon_oid} = 1;
		    }
		}
		else {
		    if ( $neg ) {
			$res_href->{$taxon_oid} = 1;
		    }
		    else {
			$res_href->{$taxon_oid} = 0;
		    }
		}
	    }
	    $cur2->finish();
	}
    }
}


#############################################################################
# showGeneSetEvalResult
#############################################################################
sub showGeneSetEvalResult {
    my $sid = getContactOid();

    printMainForm();

    my $gene_set = param("gene_set");
    my $filename = param("filename");
    my $rule_id = param("rule_id");
    my $include_myimg = param('include_myimg');

    # this also untaints the name
    my $gene_filename = WebUtil::validFileName($gene_set);

    open( FH, "$workspace_dir/$sid/$GENE_FOLDER/$gene_filename" )
	or webError("File size - file error $gene_filename"); 

    timeout( 60 * $merfs_timeout_mins ); 
    my $start_time = time();
    my $timeout_msg = "";

    my $select_id_name = "gene_oid";

    # read all genes
    my @db_genes = ();
    my @fs_genes = ();
    while ( my $line = <FH> ) {
	chomp($line);
	if ( isInt($line) ) {
	    push @db_genes, ( $line );
	}
	else {
	    push @fs_genes, ( $line );
	}
    }
    close FH;

    # parse rule
    WebUtil::checkFileName($filename);
    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my $rule_type;
    my $rule_def;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    if ( $id eq $rule_id ) {
		$rule_type = $type;
		$rule_def = $body;
		last;
	    }
	}
	close $res;
    }

    my @conds;
    if ( $rule_type eq 'or' ) {
	@conds = split(/\|/, $rule_def);
    }
    elsif ( $rule_type eq 'and' ) {
	@conds = split(/\,/, $rule_def);
    }

    print "<h1>Rule Evaluation (Rule $rule_id in $gene_set)</h1>\n";
    print "<p>$rule_def\n";

    my @func_ids = ();
    for my $cond1 ( @conds ) {
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my @comps = ();
	if ( $rule_type eq 'or' ) {
	    @comps = split(/\,/, $cond1);
	}
	elsif ( $rule_type eq 'and' ) {
	    @comps = split(/\|/, $cond1);
	}

	for my $c2 ( @comps ) {
	    if ( $c2 =~ /^!/ ) {
		$c2 = substr($c2, 1);
	    }
	    push @func_ids, ( $c2 );
	}
    }

    my $it = new InnerTable( 1, "geneSetEval$$", "geneSetEval", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "char asc", "left" );
    for my $x (@func_ids) {
	$it->addColSpec( "$x", "char asc", "left" ); 
    }
    my $sd = $it->getSdDelim(); 
    my $dbh = dbLogin();

    my $sid = getContactOid(); 
    if ( $sid == 312 ) {
	print "<p>*** start time: " . currDateTime() . "<br/>\n";    
    }
    printStartWorkingDiv();

    print "<p>Checking genes in gene set ...\n";

    my %func_res_h;
    if ( scalar(@db_genes) > 0 ) {
	print "<p>Querying database ...<br/>\n";
	for my $func_id ( @func_ids ) {
	    print "Checking $func_id ... <br/>\n";
	    my %h2;
	    evalFuncGeneList($dbh, $func_id, \@db_genes, \%h2);
	    $func_res_h{$func_id} = \%h2;
	}

	for my $gene_oid ( @db_genes ) {
	    my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
	    $url .= "&gene_oid=$gene_oid";

	    my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$gene_oid' checked /> \t";
	    $r .= $gene_oid . $sd . alink($url, $gene_oid) . "\t";

	    for my $func_id ( @func_ids ) {
		my $res = 0;
		my $href = $func_res_h{$func_id};
		if ( $href && $href->{$gene_oid} ) {
		    $res = $href->{$gene_oid};
		}
		$r .= $res . $sd . $res . "\t";
	    }

	    $it->addRow($r); 
	}
    }

    my $cnt = 0;
    for my $workspace_id ( @fs_genes ) {
        if ( (($merfs_timeout_mins * 60) -
              (time() - $start_time)) < 120 ) {
            $timeout_msg = "Process takes too long to run " .
                "-- stopped at $workspace_id. " .
                "Only partial result is displayed.";
            last;
        } 

	$cnt++;

	if ( ($cnt % 20) == 0 ) {
	    print "Checking gene $workspace_id ...<br/>\n";
	}

#	if ( $cnt > 5 ) {
#	    last;
#	}

	my ($taxon_oid, $data_type, $gene_oid) = split(/ /, $workspace_id);
	my $url = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail";
	$url .= "&taxon_oid=$taxon_oid&data_type=$data_type&gene_oid=$gene_oid";

	my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' checked /> \t";
	$r .= $gene_oid . $sd . alink($url, $gene_oid) . "\t";

	my $include_myimg = 0;
	for my $func_id ( @func_ids ) {
	    my $res = evalFuncOnGene($dbh, $func_id, $workspace_id, $include_myimg);
	    $r .= $res . $sd . $res . "\t";
	}

        $it->addRow($r); 
    }

    printEndWorkingDiv();
    if ( $sid == 312 ) {
	print "<p>*** end time: " . currDateTime() . "<br/>\n";    
    }
    if ( $timeout_msg ) { 
        printMessage( "<font color='red'>Warning: $timeout_msg</font>");
    } 

    $it->printOuterTable(1);

    print end_form();
}


#############################################################################
# showGeneEvalResult
#############################################################################
sub showGeneEvalResult {
    my $sid = getContactOid();

    printMainForm();

    my $filename = param("filename");
    my $workspace_id = param("gene_oid");
    my $rule_id = param("rule_id");
    my $include_myimg = param('include_myimg');

    WebUtil::checkFileName($filename);

    my $dbh = dbLogin();
    my $gene_oid;
    my $taxon_oid;
    my $data_type;
    if ( isInt($workspace_id) ) {
	$gene_oid = $workspace_id;
	$data_type = "database";
	my $rclause = urClause("g.taxon");
	my $sql = "select g.taxon from gene g where g.gene_oid = ? " .
	    $rclause;
	my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	($taxon_oid) = $cur->fetchrow();
	$cur->finish();
    }
    else {
	($taxon_oid, $data_type, $gene_oid) = split(/ /, $workspace_id);
    }
    #$dbh->disconnect();

    if ( ! $taxon_oid ) {
	return 0;
    }

    print "<h1>Rule Evaluation (Rule $rule_id in $filename)</h1>\n";

    my $dbh = dbLogin();
    my $rclause = urClause("g.taxon");
    my $sql = "select g.gene_display_name from gene g where g.gene_oid = ? " .
	$rclause;
    my $gene_name = $gene_oid;
    my $url = "";
    if ( $data_type eq 'database' && isInt($gene_oid) ) {
	my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	($gene_name) = $cur->fetchrow();
	$cur->finish();
	$url = "$main_cgi?section=GeneDetail&page=geneDetail";
	$url .= "&gene_oid=$gene_oid";
    }
    else {
	$gene_name = MetaUtil::getGeneProdName($gene_oid, $taxon_oid, $data_type);
	$url = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail";
	$url .= "&taxon_oid=$taxon_oid&data_type=$data_type&gene_oid=$gene_oid";
    }

    #$dbh->disconnect();

    print "<h3>" . alink($url, $gene_name) . "</h3>\n";

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my $rule_type;
    my $rule_def;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    if ( $id eq $rule_id ) {
		$rule_type = $type;
		$rule_def = $body;
		last;
	    }
	}
	close $res;
    }

    my @conds;
    if ( $rule_type eq 'or' ) {
	@conds = split(/\|/, $rule_def);
    }
    elsif ( $rule_type eq 'and' ) {
	@conds = split(/\,/, $rule_def);
    }

    my $eval_result = 0;
    if ( $rule_type eq 'and' ) {
	$eval_result = 1;
    }

    print "<table class='img' border='1'>\n";
    my $j = 0;
    for my $cond1 ( @conds ) {
	my $def1 = printRuleDefinition($cond1);
	my $result = -1;
	print "<tr class='img'>\n";
	if ( $j > 0 ) {
	    print "<td class='img'>$rule_type</td>\n";
	}
	else {
	    print "<td class='img'> </td>\n";
	}

	if ( $rule_type eq 'or' ) {
	    $result = evalOrRuleOnGene($dbh, $cond1, $workspace_id);

	    if ( $result > 0 ) {
		$eval_result = 1;
	    }
	    elsif ( $result < 0 ) {
		if ( $eval_result == 0 ) {
		    $eval_result = -1;
		}
	    }
	}
	elsif ( $rule_type eq 'and' ) {
	    $result = evalAndRuleOnGene($dbh, $cond1, $workspace_id);

	    if ( $result == 0 ) {
		$eval_result = 0;
	    }
	    elsif ( $result < 0 ) {
		if ( $eval_result > 0 ) {
		    $eval_result = -1;
		}
	    }
	}

	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}
	print "<td class='img'>$cond1</td>\n";
	print "<td class='img'>$def1</td>\n";
	print "<td class='img'>";
	if ( $result > 0 ) {
	    print "true";
	}
	elsif ( $result < 0 ) {
	    print "unknown";
	}
	else {
	    print "false";
	}
	print "</td>\n";
	print "</tr>\n";
	$j++;
    }
    print "</table>\n";

    print "<p><b>Evaluation Result: ";
    if ( $eval_result > 0 ) {
	print "true";
    }
    elsif ( $eval_result < 0 ) {
	print "unknown";
    }
    else {
	print "false";
    }
    print "</b>\n";

    print end_form();
}


#############################################################################
# evalFuncGeneList - evaluate a function on a gene list
# (db genes only)
#############################################################################
sub evalFuncGeneList {
    my ($dbh, $func_id, $gene_aref, $res_href) = @_;

    if ( scalar(@$gene_aref) == 0 ) {
	return;
    }

    my $db_id = $func_id;
    my ($f1, $f2) = split(/\:/, $func_id);

    my $sql1 = "";
    if ( $func_id =~ /^COG/ ) {
	$sql1 = "select g.gene_oid from gene_cog_groups g " .
	    "where g.cog = ? ";
    }
    elsif ( $func_id =~ /^pfam/ ) {
	$sql1 = "select g.gene_oid from gene_pfam_families g " .
	    "where g.pfam_family = ? ";
    }
    elsif ( $func_id =~ /^TIGR/ ) {
	$sql1 = "select g.gene_oid from gene_tigrfams g " .
	    "where g.ext_accession = ? ";
    }
    elsif ( $f1 eq 'KO' ) {
	$sql1 = "select g.gene_oid from gene_ko_terms g " .
	    "where g.ko_terms = ? ";
    }
    elsif ( $f1 eq 'EC' ) {
	$sql1 = "select g.gene_oid from gene_ko_enzymes g " .
	    "where g.enzymes = ? ";
    }
    elsif ( $f1 eq 'TC' ) { 
	$sql1 = "select g.gene_oid from gene_tc_families g " . 
	    "where g.tc_family = ? "; 
    } 
    elsif ( $func_id =~ /^IPR/ ) { 
	$sql1 = "select g.gene_oid from gene_img_interpro_hits g " . 
	    "where g.iprid = ? "; 
    } 
    elsif ( $f1 eq 'MetaCyc' ) { 
	$sql1 = "select g.gene_oid from " . 
	    "biocyc_reaction_in_pwys brp, " . 
	    "gene_biocyc_rxns g " . 
	    "where brp.in_pwys = ? " . 
	    "and brp.unique_id = g.biocyc_rxn "; 
 
	$db_id = $f2; 
    } 
    elsif ( $f1 eq 'IPWAY' ) { 
	$sql1 = "select g.gene_oid from " . 
	    "img_pathway_reactions ipr, img_reaction_t_components irtc, " . 
	    "gene_img_functions g " . 
	    "where ipr.pathway_oid = ? " . 
	    "and ipr.rxn = irtc.rxn_oid " .
	    "and irtc.term = g.function ";
 
	$db_id = $f2; 
    } 
    elsif ( $f1 eq 'ITERM' ) {
	$sql1 = "select g.gene_oid from gene_img_functions g " .
	    "where g.function = ? ";
	if ( isInt($f2) ) {
	    $db_id = $f2;
	}
	else {
	    $db_id = 0;
	}
    }
    else {
	return;
    }

    my $gene_list = "";
    my $cnt1 = 0;
    for my $gene_oid ( @$gene_aref ) {
	if ( ! isInt($gene_oid) ) {
	    next;
	}

	if ( $gene_list ) {
	    $gene_list .= ", " . $gene_oid;
	}
	else {
	    $gene_list = $gene_oid;
	}
	$cnt1++;

	if ( $cnt1 == 1000 ) {
	    my $sql = $sql1 . " and g.gene_oid in ( $gene_list ) ";
	    my $cur = execSql( $dbh, $sql, $verbose, $db_id );
	    for (;;) {
		my ($gid) = $cur->fetchrow();
		last if ! $gid;
		$res_href->{$gid} = 1;
	    }
	    $cur->finish();

	    $cnt1 = 0;
	    $gene_list = "";
	}
    }   # end for gene_oid

    # last
    if ( $gene_list ) {
	my $sql = $sql1 . " and g.gene_oid in ( $gene_list ) ";
	my $cur = execSql( $dbh, $sql, $verbose, $func_id );
	for (;;) {
	    my ($gid) = $cur->fetchrow();
	    last if ! $gid;
	    $res_href->{$gid} = 1;
	}
	$cur->finish();
    }
}


#############################################################################
# printRuleDefinition
#############################################################################
sub printRuleDefinition {
    my ($rule) = @_;

    my $cond1 = $rule;
    my $len = length($cond1);
    if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	$cond1 = substr($cond1, 1, $len-2);
    }

    my $def = "";
    my @s = split(/ /, $cond1);
    for my $s2 ( @s ) {
	my $sep = "";

	my @comps = ( $s2 );
	if ( $s2 =~ /\|/ ) {
	    @comps = split(/\|/, $s2);
	    $sep = " OR ";
	}
	elsif ( $s2 =~ /\,/ ) {
	    @comps = split(/\,/, $s2);
	    $sep = " AND ";
	}

	my $is_first = 1;
	for my $s3 ( @comps ) {
	    my $neg = 0;

	    if ( $is_first ) {
		$is_first = 0;
	    }
	    elsif ( $sep ) {
		$def .= $sep;
	    }

	    if ( $s3 =~ /^!/ ) {
		$s3 = substr($s3, 1);
		$neg = 1;
	    }

	    if ( $s3 =~ /^COG/ || $s3 =~ /^pfam/ ||
		 $s3 =~ /^TIGR/ || $s3 =~ /^KO/ ||
		 $s3 =~ /^EC/ || $s3 =~ /^ITERM/ ||
		 $s3 =~ /^IPWAY/ ) {
		my $name = Workspace::getMetaFuncName($s3);
		if ( $name ) {
		    $s3 = $name;
		}
	    }

	    if ( $def ) {
		if ( $neg ) {
		    $def .= " (NOT " . $s3 . ")";
		}
		else {
		    $def .= " " . $s3;
		}
	    }
	    else {
		if ( $neg ) {
		    $def = "(NOT " . $s3 . ")";
		}
		else {
		    $def = $s3;
		}
	    }
	}   # end for s3
    }   # end for s2

    return $def;
}


#############################################################################
# showRuleGeneSetProfile
#############################################################################
sub showRuleGeneSetProfile {
    my $sid = getContactOid();

    printMainForm();

    my $folder   = param("directory");
    my $filename = param("filename");
    my $gene_set = param('gene_set_name');
    my $include_gene_myimg = param('include_gene_myimg');

    print "<h1>Rule Gene-Set Profile ($gene_set)</h1>\n";

    my @set = param('gene_set_name');
    my @rules = param('rule_id');
    if ( scalar(@rules) == 0 ) {
        print "<p>No rules are selected.\n";
        return;
    }

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my %rule_type_h;
    my %rule_def_h;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    $rule_type_h{$id} = $type;
	    $rule_def_h{$id} = $body;
	}
	close $res;
    }

    my $x;
    for $x (@rules) {
#	print "<p>*** rule: $x\n";
#	print $rule_type_h{$x} . "; " . $rule_def_h{$x} . "\n";
        print hiddenVar( "rule_id", $x );
    }

    print "<p>selected rule(s): " . join(", ", @rules) . "\n";

    if ( $include_gene_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_gene_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_gene_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
    }

    if ( $gene_set eq "" ) {
        webError("Please select a gene set.\n");
        return;
    }

    WebUtil::checkFileName($gene_set);

    # this also untaints the name
    my $gene_filename = WebUtil::validFileName($gene_set);

    open( FH, "$workspace_dir/$sid/$GENE_FOLDER/$gene_filename" )
	or webError("File size - file error $gene_filename"); 

    timeout( 60 * $merfs_timeout_mins ); 
    my $start_time = time();
    my $timeout_msg = "";

    printStartWorkingDiv();
    print "<p>Checking genes in gene set ...\n";

    my $dbh = dbLogin();
    my $rclause = urClause("g.taxon");
    my $sql = "select g.gene_display_name from gene g where g.gene_oid = ? " .
	$rclause;

    my $select_id_name = "gene_oid";

    my $it = new InnerTable( 1, "ruleGeneSet2$$", "ruleGeneSet2", 1 );
    $it->addColSpec( "Gene Set",   "char asc", "left" );
    for $x (@rules) {
	$it->addColSpec( "$x", "char asc", "left" ); 
    }
    my $sd = $it->getSdDelim(); 

    my @genes = ();
    while ( my $line = <FH> ) {
	chomp($line);
	push @genes, ( $line );
    }

    close FH;
    #$dbh->disconnect();

    my $url = "$main_cgi?section=WorkspaceGeneSet&page=showDetail";
    $url .= "&filename=$gene_set&folder=gene";

    my $r = $gene_set . $sd . alink($url, $gene_set) . "\t";
    for my $x ( @rules ) {
	print "<p>Rule: $x\n";
	my $res = evalRuleOnGeneSet($dbh, $rule_type_h{$x}, $rule_def_h{$x}, 
				    \@genes, $include_gene_myimg);

	my $url = "$main_cgi?section=WorkspaceRuleSet"; 
	$url .= "&page=showGeneSetEvalResult&gene_set=$gene_set" .
	    "&filename=$filename&rule_id=$x";

	if ( $res == 1 ) {
	    $r .= "true" . $sd . alink($url, "true") . "\t";
	}
	elsif ( ! $res ) {
	    $r .= "false" . $sd . alink($url, "false") . "\t";
	}
	else {
	    $r .= "unknown" . $sd . alink($url, "unknown") . "\t";
	}
    }
    $it->addRow($r);

    printEndWorkingDiv();

    $it->printOuterTable(1);

    print end_form();
}

#############################################################################
# showRuleGeneProfile
#############################################################################
sub showRuleGeneProfile {
    my $sid = getContactOid();

    printMainForm();

    my $folder   = param("directory");
    my $filename = param("filename");
    my $gene_set = param('gene_set_name');
    my $show_true_only = param('show_true_only');
    my $include_gene_myimg = param('include_gene_myimg');

    print "<h1>Rule Gene Profile ($gene_set)</h1>\n";
    if ( $show_true_only ) {
	print "<p>Only genes satisfying the conditions are displayed.\n";
    }

    my @set = param('gene_set_name');
    my @rules = param('rule_id');
    if ( scalar(@rules) == 0 ) {
        print "<p>No rules are selected.\n";
        return;
    }

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my %rule_type_h;
    my %rule_def_h;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    $rule_type_h{$id} = $type;
	    $rule_def_h{$id} = $body;
	}
	close $res;
    }

    my $x;
    for $x (@rules) {
#	print "<p>*** rule: $x\n";
#	print $rule_type_h{$x} . "; " . $rule_def_h{$x} . "\n";
        print hiddenVar( "rule_id", $x );
    }

    print "<p>selected rule(s): " . join(", ", @rules) . "\n";

    if ( $include_gene_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_gene_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_gene_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
    }

    if ( $gene_set eq "" ) {
        webError("Please select a gene set.\n");
        return;
    }

    WebUtil::checkFileName($gene_set);

    # this also untaints the name
    my $gene_filename = WebUtil::validFileName($gene_set);

    open( FH, "$workspace_dir/$sid/$GENE_FOLDER/$gene_filename" )
	or webError("File size - file error $gene_filename"); 

    timeout( 60 * $merfs_timeout_mins ); 
    my $start_time = time();
    my $timeout_msg = "";

    printStartWorkingDiv();
    print "<p>Checking genes in gene set ...\n";

    my $dbh = dbLogin();
    my $rclause = urClause("g.taxon");
    my $sql = "select g.gene_display_name from gene g where g.gene_oid = ? " .
	$rclause;

    my $select_id_name = "gene_oid";

    my $it = new InnerTable( 1, "ruleGeneSet$$", "ruleGeneSet", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "char asc", "left" );
    $it->addColSpec( "Gene Name",   "char asc", "left" );
    for $x (@rules) {
	$it->addColSpec( "$x", "char asc", "left" ); 
    }
    my $sd = $it->getSdDelim(); 

    my $cnt1 = 0;
    my $prev_gene = "";
    while ( my $line = <FH> ) {
        if ( (($merfs_timeout_mins * 60) -
              (time() - $start_time)) < 80 ) {
            $timeout_msg = "Process takes too long to run " .
                "-- stopped at $prev_gene. " .
                "Only partial result is displayed.";
            last;
        } 

	chomp($line);
	my $gene_oid = $line;
	my $r = $sd . "<input type='checkbox' name='$select_id_name' value='$gene_oid' checked /> \t";

	my $gene_name = $gene_oid;
	my $url = "";
	my $display_id;
	if ( isInt($gene_oid) ) {
	    $display_id = $gene_oid;
	    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	    ($gene_name) = $cur->fetchrow();
	    $cur->finish();
	    $url = "$main_cgi?section=GeneDetail&page=geneDetail";
	    $url .= "&gene_oid=$gene_oid";
	}
	else {
	    my ($t2, $d2, $g2) = split(/ /, $gene_oid);
	    $display_id = $g2;
	    $gene_name = MetaUtil::getGeneProdName($g2, $t2, $d2);
	    $url = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail";
	    $url .= "&taxon_oid=$t2&data_type=$d2&gene_oid=$g2";
	}

	$r .= $gene_oid . $sd . alink($url, $display_id) . "\t";
	$r .= $gene_name . $sd . $gene_name . "\t";

	my $true_count = 0;
	for $x (@rules) {
	    my $result = evalRuleOnGene($dbh, $rule_type_h{$x}, $rule_def_h{$x}, $line,
		$include_gene_myimg);

	    if ( $result ) {
		$true_count++;
	    }

	    my $result_text = 'false';
	    if ( $result > 0 ) {
		$result_text = 'true';
	    }
	    elsif ( $result < 0 ) {
		$result_text = 'unknown';
	    }
	    my $url = "$main_cgi?section=WorkspaceRuleSet"; 
	    $url .= "&page=showGeneEvalResult&gene_oid=$line" .
		"&filename=$filename&rule_id=$x";

	    $r .= $result_text . $sd . alink($url, $result_text) . "\t";
	}

	$prev_gene = $gene_oid;

	$cnt1++;
	if ( ($cnt1 % 10) == 0 ) {
	    print ".";
	}
	if ( ($cnt1 % 900) == 0 ) {
	    print "<br/>";
	}

	if ( $show_true_only && $true_count <= 0 ) {
	    next;
	}

        $it->addRow($r); 
    }
    close FH;
    #$dbh->disconnect();

    printEndWorkingDiv();

    if ( $timeout_msg ) {
    	print "<p><font color='red'>$timeout_msg</font>\n";
    }

    if ( $cnt1 ) {
    	$it->printOuterTable(1);
    }
    else {
    	print "<h5>No genes satisfy the conditions.</h5>\n";
    }

    if ( $cnt1 ) {
        WebUtil::printButtonFooter();

        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    print end_form();
}

#### eval on entire gene set
#############################################################################
# evalRuleOnGeneSet
#
# rule_type: and, or
# rule_def: rule definition
# gene_aref: genes
#############################################################################
sub evalRuleOnGeneSet {
    my ($dbh, $rule_type, $rule_def, $gene_aref, $include_myimg) = @_;

    my $result = 0;

    if ( $rule_type eq 'and' ) {
	$result = evalAndRuleOnGeneSet($dbh, $rule_def, $gene_aref, $include_myimg);
    }
    else {
	$result = evalOrRuleOnGeneSet($dbh, $rule_def, $gene_aref, $include_myimg);
    }

    return $result;
}



#############################################################################
# evalOrRuleOnGeneSet
#
# rule_def: rule definition
# gene_aref: genes
#############################################################################
sub evalOrRuleOnGeneSet {
    my ($dbh, $rule_def, $gene_aref, $include_myimg) = @_;

    my @conds = split(/\|/, $rule_def);

    my $result1 = 0;
    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my $result2 = 1;
	my @comps = split(/\,/, $cond1);
	for my $c2 ( @comps ) {
	    my $result3 = evalFuncOnGeneSet($dbh, $c2, $gene_aref, $include_myimg);
	    if ( $result3 == 0 ) {
		# false
		$result2 = 0;
		last;
	    }
	    elsif ( $result3 < 0 ) {
		# unknown
		$result2 = -1;
	    }
	}

	if ( $result2 > 0 ) {
	    # true
	    $result1 = 1;
	    last;
	}
	elsif ( $result2 < 0 ) {
	    # unknown
	    $result1 = -1;
	}
    }

    return $result1;
}


#############################################################################
# evalAndRuleOnGeneSet
#
# rule_def: rule definition
# gene_aref: genes
#############################################################################
sub evalAndRuleOnGeneSet {
    my ($dbh, $rule_def, $gene_aref, $include_myimg) = @_;

    my @conds = split(/\,/, $rule_def);

    my $result1 = 1;
    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my $result2 = 0;
	my @comps = split(/\|/, $cond1);
	for my $c2 ( @comps ) {
	    my $result3 = evalFuncOnGeneSet($dbh, $c2, $gene_aref, $include_myimg);
	    if ( $result3 == 1 ) {
		# true
		$result2 = 1;
		last;
	    }
	    elsif ( $result3 < 0 ) {
		# unknown
		if ( $result2 == 0 ) {
		    $result2 = -1;
		}
	    }
	}

	if ( $result2 == 0 ) {
	    # false
	    $result1 = 0;
	    last;
	}
	elsif ( $result2 < 0 ) {
	    # unknown
	    if ( $result1 > 0 ) {
		$result1 = -1;
	    }
	}
    }

    return $result1;
}


#############################################################################
# evalFuncOnGeneSet
#
# func_id: function id
# gene_aref: genes
# return: true 1, false 0, unknown -1
#############################################################################
sub evalFuncOnGeneSet {
    my ($dbh, $func_id, $gene_aref, $include_myimg) = @_;

    my @db_genes = ();
    my @fs_genes = ();
    for my $gene_oid ( @$gene_aref ) {
	if ( isInt($gene_oid) ) {
	    push @db_genes, ( $gene_oid );
	}
	else {
	    push @fs_genes, ( $gene_oid );
	}
    }

    my $gene_oid;
    my $taxon_oid;
    my $data_type = "database";

    my $neg = 0;
    if ( $func_id =~ /^\!/ ) {
	$neg = 1;
	$func_id = substr($func_id, 1, length($func_id)-1);
    }

    my ($f1, $f2) = split(/\:/, $func_id);

    if ( $f1 eq 'IPWAY' ) {
	if ( ! $f2 ) {
	    $f2 = 0;
	}

	if ( scalar(@db_genes) == 0 ) {
	    if ( $neg ) {
		return 1;
	    }
	    else {
		return 0;
	    }
	}

	my $sql = qq{
            select irc.catalysts
               from img_reaction_catalysts irc, img_pathway_reactions ipr1
               where ipr1.pathway_oid = ?
               and ipr1.rxn = irc.rxn_oid
               union
               select irtc.term
               from img_reaction_t_components irtc, img_pathway_reactions ipr2
               where ipr2.pathway_oid = ?
               and ipr2.rxn = irtc.rxn_oid
	    };

	my $cur = execSql( $dbh, $sql, $verbose, $f2, $f2 );
	my @terms = ();
	for (;;) {
	    my ($term_oid) = $cur->fetchrow();
	    last if ! $term_oid;
	    push @terms, ( $term_oid );
	}
	$cur->finish();
	my $term_list = join(", ", @terms);

	my $gene_list = "";
	my $cnt1 = 0;
	for my $gene_oid ( @db_genes ) {
	    if ( $gene_list ) {
		$gene_list .= ", " . $gene_oid;
	    }
	    else {
		$gene_list = $gene_oid;
	    }
	    $cnt1++;

	    if ( $cnt1 == 1000 ) {
		$sql = "select count(*) from gene_img_functions " .
		    "where gene_oid in ( $gene_list ) " .
		    "and function in (" . $term_list . ")";
		$cur = execSql( $dbh, $sql, $verbose );
		my ($term_cnt) = $cur->fetchrow();
		$cur->finish();

		if ( $term_cnt ) {
		    if ( $neg ) {
			return 0;
		    }
		    else {
			return 1;
		    }
		}

		$gene_list = "";
		$cnt1 = 0;
	    }
	}

	# last batch
	if ( $gene_list ) {
	    $sql = "select count(*) from gene_img_functions " .
		"where gene_oid in ( $gene_list ) " .
		"and function in (" . $term_list . ")";
	    $cur = execSql( $dbh, $sql, $verbose );
	    my ($term_cnt) = $cur->fetchrow();
	    $cur->finish();

	    if ( $term_cnt ) {
		if ( $neg ) {
		    return 0;
		}
		else {
		    return 1;
		}
	    }
	    else {
		if ( $neg ) {
		    return 1;
		}
		else {
		    return 0;
		}
	    }
	}
    }
    elsif ( $f1 eq 'ITERM' ) {
	if ( $data_type ne 'database' || ! isInt($gene_oid) ) {
	    return 0;
	}

	if ( ! $f2 ) {
	    $f2 = 0;
	}

	if ( scalar(@db_genes) == 0 ) {
	    if ( $neg ) {
		return 1;
	    }
	    else {
		return 0;
	    }
	}

	my $gene_list = "";
	my $cnt1 = 0;
	for my $gene_oid ( @db_genes ) {
	    if ( $gene_list ) {
		$gene_list .= ", " . $gene_oid;
	    }
	    else {
		$gene_list = $gene_oid;
	    }
	    $cnt1++;

	    if ( $cnt1 == 1000 ) {
		my $sql = "select count(*) from gene_img_functions gif " .
		    "where gif.function = ? and gif.gene_oid in ( $gene_list ) ";
		my $cur = execSql( $dbh, $sql, $verbose, $f2 );
		my ($res) = $cur->fetchrow();
		$cur->finish();

		if ( $include_myimg && (! $res) ) {
		    # check MyIMG
		    my $sid = getContactOid();
		    $sql = "select count(*) " .
			"from gene_myimg_functions gmf, gene_myimg_terms gmt " .
			"where gmt.term_oid = ? and gmt.gene_oid in ( $gene_list ) " .
			"and gmf.gene_oid = gmt.gene_oid ";
		    if ( $include_myimg == 1 ) {
			$sql .= "and gmf.modified_by = $sid ";
		    }
		    elsif ( $include_myimg == 2 ) {
			$sql .= "and gmf.is_public = 'Yes' ";
		    }
		    elsif ( $include_myimg == 3 ) {
			$sql .= "and (gmf.modified_by = $sid or gmf.is_public = 'Yes') ";
		    }
		    $cur = execSql( $dbh, $sql, $verbose, $f2 );
		    ($res) = $cur->fetchrow();
		    $cur->finish();
		}

		if ( $res ) {
		    if ( $neg ) {
			return 0;
		    }
		    else {
			return 1;
		    }
		}

		$gene_list = "";
		$cnt1 = 0;
	    }
	}

	# last batch
	if ( $gene_list ) {
	    my $sql = "select count(*) from gene_img_functions gif " .
		"where gif.function = ? and gif.gene_oid in ( $gene_list ) ";
	    my $cur = execSql( $dbh, $sql, $verbose, $f2 );
	    my ($res) = $cur->fetchrow();
	    $cur->finish();

	    if ( $include_myimg && (! $res) ) {
		# check MyIMG
		my $sid = getContactOid();
		$sql = "select count(*) " .
		    "from gene_myimg_functions gmf, gene_myimg_terms gmt " .
		    "where gmt.term_oid = ? and gmt.gene_oid in ( $gene_list ) " .
		    "and gmf.gene_oid = gmt.gene_oid ";
		if ( $include_myimg == 1 ) {
		    $sql .= "and gmf.modified_by = $sid ";
		}
		elsif ( $include_myimg == 2 ) {
		    $sql .= "and gmf.is_public = 'Yes' ";
		}
		elsif ( $include_myimg == 3 ) {
		    $sql .= "and (gmf.modified_by = $sid or gmf.is_public = 'Yes') ";
		}
		$cur = execSql( $dbh, $sql, $verbose, $f2 );
		($res) = $cur->fetchrow();
		$cur->finish();
	    }

	    if ( $res ) {
		if ( $neg ) {
		    return 0;
		}
		else {
		    return 1;
		}
	    }
	    else {
		if ( $neg ) {
		    return 1;
		}
		else {
		    return 0;
		}
	    }
	}
    }
    else {
	# other functions
	my $sql1 = "";
	my $db_id = $func_id;
	if ( $func_id =~ /^COG/ ) {
	    $sql1 = "select count(*) from gene_cog_groups g " .
		"where g.cog = ? ";
	}
	elsif ( $func_id =~ /^pfam/ ) {
	    $sql1 = "select count(*) from gene_pfam_families g " .
		"where g.pfam_family = ? ";
	}
	elsif ( $func_id =~ /^TIGR/ ) {
	    $sql1 = "select count(*) from gene_tigrfams g " .
		"where g.ext_accession = ? ";
	}
	elsif ( $f1 eq 'KO' ) {
	    $sql1 = "select count(*) from gene_ko_terms g " .
		"where g.ko_terms = ? ";
	}
	elsif ( $f1 eq 'EC' ) {
	    $sql1 = "select count(*) from gene_ko_enzymes g " .
		"where g.enzymes = ? ";
	}
	elsif ( $f1 eq 'TC' ) {
	    $sql1 = "select count(*) from gene_tc_families g " .
		"where g.tc_family = ? ";
	}
	elsif ( $func_id =~ /^IPR/ ) {
	    $sql1 = "select count(*) from gene_img_interpro_hits g " .
		"where g.iprid = ? ";
	}
	elsif ( $f1 eq 'MetaCyc' ) {
	    $sql1 = "select count(*) from " .
		"biocyc_reaction_in_pwys brp, " .
		"gene_biocyc_rxns g " .
		"where brp.in_pwys = ? " .
		"and brp.unique_id = g.biocyc_rxn ";

	    $db_id = $f2;
	}
	elsif ( $f1 eq 'IPWAY' ) { 
	    $sql1 = "select count(*) from " . 
		"img_pathway_reactions ipr, img_reaction_t_components irtc, " . 
		"gene_img_functions g " . 
		"where ipr.pathway_oid = ? " . 
		"and ipr.rxn = irtc.rxn_oid " .
		"and irtc.term = g.function ";
 
	    $db_id = $f2; 
	} 
	elsif ( $f1 eq 'ITERM' ) {
	    $sql1 = "select count(*) from gene_img_functions g " .
		"where g.function = ? ";
	    if ( isInt($f2) ) {
		$db_id = $f2;
	    }
	    else {
		$db_id = 0;
	    }
	}

	if ( scalar(@db_genes) > 0 && $sql1 ) {
	    my $gene_list = "";
	    my $cnt1 = 0;
	    for my $gene_oid ( @db_genes ) {
		if ( $gene_list ) {
		    $gene_list .= ", " . $gene_oid;
		}
		else {
		    $gene_list = $gene_oid;
		}
		$cnt1++;

		if ( $cnt1 == 1000 ) {
		    my $sql = $sql1 . " and g.gene_oid in ( $gene_list ) ";
		    my $cur = execSql( $dbh, $sql, $verbose, $db_id );
		    my ($res) = $cur->fetchrow();
		    $cur->finish();

		    if ( $include_myimg && (! $res) ) {
			# check MyIMG
			my $sid = getContactOid();
			$sql = "select count(*) " .
			    "from gene_myimg_functions gmf, gene_myimg_terms gmt " .
			    "where gmt.term_oid = ? and gmt.gene_oid in ( $gene_list ) " .
			    "and gmf.gene_oid = gmt.gene_oid ";
			if ( $include_myimg == 1 ) {
			    $sql .= "and gmf.modified_by = $sid ";
			}
			elsif ( $include_myimg == 2 ) {
			    $sql .= "and gmf.is_public = 'Yes' ";
			}
			elsif ( $include_myimg == 3 ) {
			    $sql .= "and (gmf.modified_by = $sid or gmf.is_public = 'Yes') ";
			}
			$cur = execSql( $dbh, $sql, $verbose, $db_id );
			($res) = $cur->fetchrow();
			$cur->finish();
		    }

		    if ( $res ) {
			if ( $neg ) {
			    return 0;
			}
			else {
			    return 1;
			}
		    }

		    $gene_list = "";
		    $cnt1 = 0;
		}
	    }

	    # last batch
	    if ( $gene_list ) {
		my $sql = $sql1 . " and g.gene_oid in ( $gene_list ) ";
		my $cur = execSql( $dbh, $sql, $verbose, $db_id );
		my ($res) = $cur->fetchrow();
		$cur->finish();

		if ( $include_myimg && (! $res) ) {
		    # check MyIMG
		    my $sid = getContactOid();
		    $sql = "select count(*) " .
			"from gene_myimg_functions gmf, gene_myimg_terms gmt " .
			"where gmt.term_oid = ? and gmt.gene_oid in ( $gene_list ) " .
			"and gmf.gene_oid = gmt.gene_oid ";
		    if ( $include_myimg == 1 ) {
			$sql .= "and gmf.modified_by = $sid ";
		    }
		    elsif ( $include_myimg == 2 ) {
			$sql .= "and gmf.is_public = 'Yes' ";
		    }
		    elsif ( $include_myimg == 3 ) {
			$sql .= "and (gmf.modified_by = $sid or gmf.is_public = 'Yes') ";
		    }
		    $cur = execSql( $dbh, $sql, $verbose, $db_id );
		    ($res) = $cur->fetchrow();
		    $cur->finish();
		}

		if ( $res ) {
		    if ( $neg ) {
			return 0;
		    }
		    else {
			return 1;
		    }
		}
	    }
	}

	if ( scalar(@fs_genes) > 0 ) {
	    # MER-FS
	    my @func_ids = ( );
	    if ( $func_id =~ /^COG/ || $func_id =~ /^pfam/ ||
		 $func_id =~ /^TIGR/ || $func_id =~ /^KO/ ||
		 $func_id =~ /^EC/ ) {
		@func_ids = ( $func_id );
	    }
	    else {
		@func_ids = Workspace::getComponentFuncIds($func_id);
	    }

	    for my $workspace_id ( @fs_genes ) {
		my ($taxon_oid, $data_type, $gene_oid) = split(/ /, $workspace_id);
		my $res2 = 1;
		for my $func_id2 ( @func_ids ) {
		    my @gene_funcs;
		    if ( $func_id2 =~ /^COG/ ) {
			@gene_funcs = MetaUtil::getGeneCogId($gene_oid, $taxon_oid, $data_type);
		    }
		    elsif ( $func_id2 =~ /^pfam/ ) {
			@gene_funcs = MetaUtil::getGenePfamId($gene_oid, $taxon_oid, $data_type);
		    }
		    elsif ( $func_id2 =~ /^TIGR/ ) {
			@gene_funcs = MetaUtil::getGeneTIGRfamId($gene_oid, $taxon_oid, $data_type);
		    }
		    elsif ( $func_id2 =~ /^KO/ ) {
			@gene_funcs = MetaUtil::getGeneKoId($gene_oid, $taxon_oid, $data_type);
		    }
		    elsif ( $func_id2 =~ /^EC/ ) {
			@gene_funcs = MetaUtil::getGeneEc($gene_oid, $taxon_oid, $data_type);
		    }

		    my $res3 = 0;
		    for my $f3 ( @gene_funcs ) {
			if ( $f3 eq $func_id2 ) {
			    # found
			    $res3 = 1;
			    last;
			}
		    }

		    if ( ! $res3 ) {
			$res2 = 0;
			last;
		    }
		}

		if ( $res2 ) {
		    if ( $neg ) {
			return 0;
		    }
		}
		else {
		    return 1;
		}
	    }
	}
    }

    if ( $neg ) {
	return 1;
    }

    return 0;
}


#### eval on individual genes
#############################################################################
# evalRuleOnGene
#
# rule_type: and, or
# rule_def: rule definition
# workspace_id: gene to be evaluated
#############################################################################
sub evalRuleOnGene {
    my ($dbh, $rule_type, $rule_def, $workspace_id, $include_myimg) = @_;

    my $result = 0;

    if ( $rule_type eq 'and' ) {
	$result = evalAndRuleOnGene($dbh, $rule_def, $workspace_id, $include_myimg);
    }
    else {
	$result = evalOrRuleOnGene($dbh, $rule_def, $workspace_id, $include_myimg);
    }

    return $result;
}



#############################################################################
# evalOrRuleOnGene
#
# rule_def: rule definition
# workspace_id: gene to be evaluaed
#############################################################################
sub evalOrRuleOnGene {
    my ($dbh, $rule_def, $workspace_id, $include_myimg) = @_;

    my @conds = split(/\|/, $rule_def);

    my $result1 = 0;
    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my $result2 = 1;
	my @comps = split(/\,/, $cond1);
	for my $c2 ( @comps ) {
	    my $result3 = evalFuncOnGene($dbh, $c2, $workspace_id, $include_myimg);
	    if ( $result3 == 0 ) {
		# false
		$result2 = 0;
		last;
	    }
	    elsif ( $result3 < 0 ) {
		# unknown
		$result2 = -1;
	    }
	}

	if ( $result2 > 0 ) {
	    # true
	    $result1 = 1;
	    last;
	}
	elsif ( $result2 < 0 ) {
	    # unknown
	    $result1 = -1;
	}
    }

    return $result1;
}


#############################################################################
# evalAndRuleOnGene
#
# rule_def: rule definition
# workspace_id: gene to be evaluated
#############################################################################
sub evalAndRuleOnGene {
    my ($dbh, $rule_def, $workspace_id, $include_myimg) = @_;

    my @conds = split(/\,/, $rule_def);

    my $result1 = 1;
    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my $result2 = 0;
	my @comps = split(/\|/, $cond1);
	for my $c2 ( @comps ) {
	    my $result3 = evalFuncOnGene($dbh, $c2, $workspace_id, $include_myimg);
	    if ( $result3 == 1 ) {
		# true
		$result2 = 1;
		last;
	    }
	    elsif ( $result3 < 0 ) {
		# unknown
		if ( $result2 == 0 ) {
		    $result2 = -1;
		}
	    }
	}

	if ( $result2 == 0 ) {
	    # false
	    $result1 = 0;
	    last;
	}
	elsif ( $result2 < 0 ) {
	    # unknown
	    if ( $result1 > 0 ) {
		$result1 = -1;
	    }
	}
    }

    return $result1;
}


#############################################################################
# evalFuncOnGene
#
# func_id: function id
# workspace_id: gene to be evaluated
# return: true 1, false 0, unknown -1
#############################################################################
sub evalFuncOnGene {
    my ($dbh, $func_id, $workspace_id, $include_myimg) = @_;

    my $gene_oid;
    my $taxon_oid;
    my $data_type;

    if ( isInt($workspace_id) ) {
	$gene_oid = $workspace_id;
	$data_type = "database";
	my $rclause = urClause("g.taxon");
	my $sql = "select g.taxon from gene g where g.gene_oid = ? " .
	    $rclause;
	my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	($taxon_oid) = $cur->fetchrow();
	$cur->finish();
    }
    else {
	($taxon_oid, $data_type, $gene_oid) = split(/ /, $workspace_id);
    }

    if ( ! $taxon_oid ) {
	return 0;
    }

    my $neg = 0;
    if ( $func_id =~ /^\!/ ) {
	$neg = 1;
	$func_id = substr($func_id, 1, length($func_id)-1);
    }

    my ($f1, $f2) = split(/\:/, $func_id);

    if ( $f1 eq 'IPWAY' ) {
	if ( $data_type ne 'database' || ! isInt($gene_oid) ) {
	    return -1;
	}

	if ( ! $f2 ) {
	    $f2 = 0;
	}

	my $sql = qq{
            select irc.catalysts
               from img_reaction_catalysts irc, img_pathway_reactions ipr1
               where ipr1.pathway_oid = ?
               and ipr1.rxn = irc.rxn_oid
               union
               select irtc.term
               from img_reaction_t_components irtc, img_pathway_reactions ipr2
               where ipr2.pathway_oid = ?
               and ipr2.rxn = irtc.rxn_oid
	    };

	my $cur = execSql( $dbh, $sql, $verbose, $f2, $f2 );
	my @terms = ();
	for (;;) {
	    my ($term_oid) = $cur->fetchrow();
	    last if ! $term_oid;
	    push @terms, ( $term_oid );
	}
	$cur->finish();
	my $term_list = join(", ", @terms);

	$sql = "select count(*) from gene_img_functions where gene_oid = $gene_oid " .
	    "and function in (" . $term_list . ")";
	$cur = execSql( $dbh, $sql, $verbose );
	my ($term_cnt) = $cur->fetchrow();
	$cur->finish();

	if ( $term_cnt ) {
	    if ( $neg ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
	else {
	    if ( $neg ) {
		return 1;
	    }
	    else {
		return 0;
	    }
	}
    }
    elsif ( $f1 eq 'ITERM' ) {
	if ( $data_type ne 'database' || ! isInt($gene_oid) ) {
	    return -1;
	}

	if ( ! $f2 ) {
	    $f2 = 0;
	}

	my $sql = "select count(*) from gene_img_functions gif " .
	    "where gif.function = ? and gif.gene_oid = ?";
	my $cur = execSql( $dbh, $sql, $verbose, $f2, $gene_oid );
	my ($res) = $cur->fetchrow();
	$cur->finish();

	if ( $include_myimg && (! $res) ) {
	    # check MyIMG
	    my $sid = getContactOid();
	    $sql = "select count(*) " .
		"from gene_myimg_functions gmf, gene_myimg_terms gmt " .
		"where gmt.term_oid = ? and gmt.gene_oid = ? " .
		"and gmf.gene_oid = gmt.gene_oid ";
	    $cur = execSql( $dbh, $sql, $verbose, $f2, $gene_oid );
	    if ( $include_myimg == 1 ) {
		$sql .= "and gmf.modified_by = $sid ";
	    }
	    elsif ( $include_myimg == 2 ) {
		$sql .= "and gmf.is_public = 'Yes' ";
	    }
	    elsif ( $include_myimg == 3 ) {
		$sql .= "and (gmf.modified_by = $sid or gmf.is_public = 'Yes') ";
	    }
	    ($res) = $cur->fetchrow();
	    $cur->finish();
	}

	if ( $res ) {
	    if ( $neg ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
	else {
	    if ( $neg ) {
		return 1;
	    }
	    else {
		return 0;
	    }
	}
    }
    elsif ( $data_type eq 'database' && isInt($gene_oid) ) {
	my $sql = "";
	my @bindList = ();
        my $rclause = WebUtil::urClause('g.taxon'); 
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
	($sql, @bindList) = WorkspaceQueryUtil::getDbGeneFuncCountSql( $func_id, 
				      $gene_oid, $rclause, $imgClause );
	my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
	my ($cnt1) = $cur->fetchrow();
	$cur->finish();
	#$dbh->disconnect();

	if ( $include_myimg && (! $cnt1) ) {
	    # check MyIMG
	    my $sql2 = "";
	    my $db_id = "";
	    my $sid = getContactOid();
	    if ( $f1 eq 'ITERM' ) {
		$sql2 = "select count(*) " .
		    "from gene_myimg_functions gmf, gene_myimg_terms g " .
		    "where g.term_oid = ? and g.gene_oid = ? " ,
		    "and gmf.gene_oid = g.gene_oid ";
		$db_id = $f2;
	    }
	    elsif ( $f1 eq 'IPWAY' ) { 
		$sql2 = "select count(*) from " . 
		    "img_pathway_reactions ipr, img_reaction_t_components irtc, " . 
		    "gene_myimg_terms g, gene_myimg_functions gmf " . 
		    "where ipr.pathway_oid = ? " . 
		    "and ipr.rxn = irtc.rxn_oid " .
		    "and irtc.term = g.term_oid " .
		    "and g.gene_oid = ? " .
		    "and gmf.gene_oid = g.gene_oid ";
		$db_id = $f2;
	    }
	    elsif ( $f1 eq 'EC' ) {
		$sql2 = "select count(*) " .
		    "from gene_myimg_functions gmf, gene_myimg_enzymes g " .
		    "where g.ec_number = ? and g.gene_oid = ? " .
		    "and gmf.gene_oid = g.gene_oid ";
		$db_id = $func_id;
	    }
	    if ( $include_myimg == 1 ) {
		$sql .= "and gmf.modified_by = $sid ";
	    }
	    elsif ( $include_myimg == 2 ) {
		$sql .= "and gmf.is_public = 'Yes' ";
	    }
	    elsif ( $include_myimg == 3 ) {
		$sql .= "and (gmf.modified_by = $sid or gmf.is_public = 'Yes') ";
	    }
	    my $cur2 = execSql( $dbh, $sql2, $verbose, $db_id, $gene_oid );
	    ($cnt1) = $cur2->fetchrow();
	    $cur2->finish();
	}

	if ( $cnt1 ) {
	    if ( $neg ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
	else {
	    if ( $neg ) {
		return 1;
	    }
	    else {
		return 0;
	    }
	}
    }
    else {
	# MER-FS
	my @func_ids = ( );
	if ( $func_id =~ /^COG/ || $func_id =~ /^pfam/ ||
	     $func_id =~ /^TIGR/ || $func_id =~ /^KO/ ||
	     $func_id =~ /^EC/ ) {
	    @func_ids = ( $func_id );
	}
	else {
	    @func_ids = Workspace::getComponentFuncIds($func_id);
	}

	my $res2 = 1;
	for my $func_id2 ( @func_ids ) {
	    my @gene_funcs;
	    if ( $func_id2 =~ /^COG/ ) {
		@gene_funcs = MetaUtil::getGeneCogId($gene_oid, $taxon_oid, $data_type);
	    }
	    elsif ( $func_id2 =~ /^pfam/ ) {
		@gene_funcs = MetaUtil::getGenePfamId($gene_oid, $taxon_oid, $data_type);
	    }
	    elsif ( $func_id2 =~ /^TIGR/ ) {
		@gene_funcs = MetaUtil::getGeneTIGRfamId($gene_oid, $taxon_oid, $data_type);
	    }
	    elsif ( $func_id2 =~ /^KO/ ) {
		@gene_funcs = MetaUtil::getGeneKoId($gene_oid, $taxon_oid, $data_type);
	    }
	    elsif ( $func_id2 =~ /^EC/ ) {
		@gene_funcs = MetaUtil::getGeneEc($gene_oid, $taxon_oid, $data_type);
	    }

	    my $res3 = 0;
	    for my $f3 ( @gene_funcs ) {
		if ( $f3 eq $func_id2 ) {
		    # found
		    $res3 = 1;
		    last;
		}
	    }

	    if ( ! $res3 ) {
		$res2 = 0;
		last;
	    }
	}

	if ( $neg ) {
	    if ( $res2 ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
	else {
	    return $res2;
	}
    }

    if ( $neg ) {
	return 1;
    }

    return 0;
}


#############################################################################
# showFuncSetGeneProfile - show workspace function-gene profile for
#                       selected files and gene set
#############################################################################
sub showFuncSetGeneProfile {
    my $sid = getContactOid();

    printMainForm();

    my $folder   = param("directory");
    my $gene_set = param('gene_set_name');
    my $include_gene_myimg = param('include_gene_myimg');
    print "<h1>Function Set Gene Profile ($gene_set)</h1>\n";

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

    if ( $include_gene_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_gene_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_gene_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
    }

    WebUtil::checkFileName($gene_set);

    # this also untaints the name
    my $gene_filename = WebUtil::validFileName($gene_set);

    my @selected_sets = ();
    my $col_count = 1;
    my %all_funcs_in_set;     # all func_ids in a function set
    my %all_func_ids;         # func_ids in all selected sets
    for my $x ( @filenames ) {
	if ( $col_count > $max_profile_select ) {
	    last;
	}
	push @selected_sets, ( $x );
	$col_count++;

	open( FH, "$workspace_dir/$sid/$folder/$x" )
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
	$all_funcs_in_set{$x} = $func_str;
	close FH;
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
    my @func_ids = (keys %all_func_ids);
    my %func_names = QueryUtil::fetchFuncIdAndName( $dbh, \@func_ids );

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    my $sd = $it->getSdDelim();

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "char asc", "left" );
    $it->addColSpec( "Gene Name", "char asc", "left" );

    for my $func_set ( @selected_sets ) {
	$it->addColSpec( $func_set,  "char asc", "left" );
    }

    my $fullname = "$workspace_dir/$sid/$GENE_FOLDER/$gene_filename";

    open( FH, $fullname )
	or webError("File error $gene_filename.");

    my $trunc = 0;
    my $dbh = dbLogin();
    my $rclause = urClause("g.taxon");
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

	    my $sql = "select gene_oid, taxon, gene_display_name from gene " .
		"where gene_oid = ? " . $rclause;
	    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	    ($g2, $taxon_oid, $gene_product_name) = $cur->fetchrow();
	    $cur->finish();
	}
	else {
	    ($taxon_oid, $data_type, $g2) = split(/ /, $gene_oid);
	    $url = "$main_cgi?section=MetaGeneDetail"; 
	    $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid"
		. "&data_type=$data_type&gene_oid=$g2";
	    my ( $new_name, $source ) =
		getGeneProdName( $g2, $taxon_oid, $data_type );
	    $gene_product_name = $new_name;
	}
	if ( ! $g2 ) {
	    next;
	}

	$r .= $gene_oid . $sd . alink( $url, $g2 ) . "\t";
        $r .= $gene_product_name . $sd . $gene_product_name . "\t";

	for my $func_id (@func_ids) {
	    if ( $data_type eq 'database' ) {
		my $sql2 = "";
		my @funcs = ();
		if ( $func_id =~ /^COG/ ) {
		    if ( ! (defined $gene_func{'cog'}) ) {
			$sql2 = "select cog from gene_cog_groups " .
			    "where gene_oid = ? ";
		    }
		}
		elsif ( $func_id =~ /^pfam/ ) {
		    if ( ! (defined $gene_func{'pfam'}) ) {
			$sql2 = "select pfam_family from gene_pfam_families " .
			    "where gene_oid = ? ";
		    }
		}
		elsif ( $func_id =~ /^TIGR/ ) {
		    if ( ! (defined $gene_func{'tigr'}) ) {
			$sql2 = "select ext_accession from gene_tigrfams " .
			    "where gene_oid = ? ";
		    }
		}
		elsif ( $func_id =~ /^KOG/ ) {
		    if ( ! (defined $gene_func{'kog'}) ) {
			$sql2 = "select kog from gene_kog_groups " .
			    "where gene_oid = ? ";
		    }
		}
		elsif ( $func_id =~ /^KO/ ) {
		    if ( ! (defined $gene_func{'ko'}) ) {
			$sql2 = "select ko_terms from gene_ko_terms " .
			    "where gene_oid = ? ";
		    }
		}
		elsif ( $func_id =~ /^EC/ ) {
		    if ( ! (defined $gene_func{'ec'}) ) {
			$sql2 = "select enzymes from gene_ko_enzymes " .
			    "where gene_oid = ? ";
		    }
		}
		elsif ( $func_id =~ /^MetaCyc/ ) {
		    if ( ! (defined $gene_func{'metacyc'}) ) {
			$sql2 = "select brp.in_pwys from " .
			    "biocyc_reaction_in_pwys brp, " .
			    "gene_biocyc_rxns gb " .
			    "where gb.gene_oid = ? " .
			    "and brp.unique_id = gb.biocyc_rxn ";
		    }
		}
		elsif ( $func_id =~ /^IPR/ ) {
		    if ( ! (defined $gene_func{'interpro'}) ) {
			$sql2 = "select iprid from gene_img_interpro_hits " .
			    "where gene_oid = ? ";
		    }
		}
		elsif ( $func_id =~ /^TC/ ) {
		    if ( ! (defined $gene_func{'tc'}) ) {
			$sql2 = "select tc_family from gene_tc_families " .
			    "where gene_oid = ? ";
		    }
		}
		elsif ( $func_id =~ /^ITERM/ ) {
		    if ( ! (defined $gene_func{'iterm'}) ) {
			$sql2 = "select function from gene_img_functions " .
			    "where gene_oid = ? ";
		    }
		}
		elsif ( $func_id =~ /^IPWAY/ ) {
		    if ( ! (defined $gene_func{'ipway'}) ) {
                        $sql2 = qq{
                               select ipr.pathway_oid
                               from img_pathway_reactions ipr,
                                    img_reaction_catalysts irc,
                                    gene_img_functions g
                               where g.gene_oid = ?
                               and ipr.rxn = irc.rxn_oid
                               and irc.catalysts = g.function
                               union
                               select ipr2.pathway_oid
                               from img_pathway_reactions ipr2,
                                    img_reaction_t_components irtc,
                                    gene_img_functions g2
                               where g2.gene_oid = $gene_oid
                               and ipr2.rxn = irtc.rxn_oid
                               and irtc.term = g2.function
			};
		    }
		}

		if ( $sql2 ) {
		    my $cur2 = execSql( $dbh, $sql2, $verbose, $gene_oid );
		    for (;;) {
			my ($f_id) = $cur2->fetchrow();
			last if !$f_id;

			if ( $func_id =~ /^ITERM/ ) {
			    $f_id = "ITERM:" . FuncUtil::termOidPadded( $f_id );
			}
			elsif ( $func_id =~ /^IPWAY/ ) {
			    $f_id = "IPWAY:" . FuncUtil::pwayOidPadded( $f_id );
			}
			elsif ( $func_id =~ /^MetaCyc/ ) {
			    $f_id = "MetaCyc:" . $f_id;
			}

			push @funcs, ( $f_id );
		    }
		    $cur2->finish();

		    if ( $func_id =~ /^COG/ ) {
			$gene_func{'cog'} = \@funcs;
		    }
		    elsif ( $func_id =~ /^pfam/ ) {
			$gene_func{'pfam'} = \@funcs;
		    }
		    elsif ( $func_id =~ /^TIGR/ ) {
			$gene_func{'tigr'} = \@funcs;
		    }
		    elsif ( $func_id =~ /^KOG/ ) {
			$gene_func{'kog'} = \@funcs;
		    }
		    elsif ( $func_id =~ /^KO/ ) {
			$gene_func{'ko'} = \@funcs;
		    }
		    elsif ( $func_id =~ /^EC/ ) {
			$gene_func{'ec'} = \@funcs;
		    }
		    elsif ( $func_id =~ /^MetaCyc/ ) {
			$gene_func{'metacyc'} = \@funcs;
		    }
		    elsif ( $func_id =~ /^IPR/ ) {
			$gene_func{'interpro'} = \@funcs;
		    }
		    elsif ( $func_id =~ /^TC/ ) {
			$gene_func{'tc'} = \@funcs;
		    }
		    elsif ( $func_id =~ /^ITERM/ ) {
			$gene_func{'iterm'} = \@funcs;
		    }
		    elsif ( $func_id =~ /^IPWAY/ ) {
			$gene_func{'ipway'} = \@funcs;
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

	my $total_cnt = 0;
	for my $func_set ( @selected_sets ) {
	    my @f = split(/\t/, $all_funcs_in_set{$func_set});
	    my $cnt = 0;
	    for my $f1 ( @f ) {
		my @funcs;
		if ( $f1 =~ /^COG/ ) {
		    @funcs = @{$gene_func{'cog'}};
		}
		elsif ( $f1 =~ /^pfam/ ) {
		    @funcs = @{$gene_func{'pfam'}};
		}
		elsif ( $f1 =~ /^TIGR/ ) {
		    @funcs = @{$gene_func{'tigr'}};
		}
		elsif ( $f1 =~ /^KOG/ ) {
		    @funcs = @{$gene_func{'kog'}};
		}
		elsif ( $f1 =~ /^KO/ ) {
		    @funcs = @{$gene_func{'ko'}};
		}
		elsif ( $f1 =~ /^EC/ ) {
		    @funcs = @{$gene_func{'ec'}};
		}
		elsif ( $f1 =~ /^MetaCyc/ ) {
		    if ( $gene_func{'metacyc'} ) {
			@funcs = @{$gene_func{'metacyc'}};
		    }
		}
		elsif ( $f1 =~ /^IPR/ ) {
		    @funcs = @{$gene_func{'interpro'}};
		}
		elsif ( $f1 =~ /^TC/ ) {
		    @funcs = @{$gene_func{'tc'}};
		}
		elsif ( $f1 =~ /^ITERM/ ) {
		    @funcs = @{$gene_func{'iterm'}};
		}
		elsif ( $f1 =~ /^IPWAY/ ) {
		    @funcs = @{$gene_func{'ipway'}};
		}

		if ( WebUtil::inArray($f1, @funcs) ) {
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
              (time() - $start_time)) < 80 ) {
            $timeout_msg = "Process takes too long to run " . 
                "-- stopped at gene $gene_oid. " . 
                "Only partial result is displayed."; 
            last; 
        } 
    }  # end for gene_oid
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
	if ( scalar(@filenames) > $max_profile_select ) { 
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
    print "<input type='button' name='selectAll' value='Select All' "
        . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1); 
    print "<input type='button' name='clearAll' value='Clear All' "
        . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n"; 
 
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
    my $include_gene_myimg = param('include_gene_myimg');
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

    if ( $include_gene_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_gene_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_gene_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
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
    $it->addColSpec( "Gene Name", "char asc", "left" );

    for my $func_id ( @selected_funcs ) {
	$it->addColSpec( $func_id,  "char asc", "left", "", $func_names{$func_id} );
    }

    my $fullname = "$workspace_dir/$sid/$GENE_FOLDER/$gene_filename";

    open( FH, $fullname )
	or webError("File error $gene_filename.");

    my $trunc = 0;
    my $dbh = dbLogin();
    my $rclause = urClause("g.taxon");
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

	    my $sql = "select gene_oid, taxon, gene_display_name from gene " .
		"where gene_oid = ? " . $rclause;
	    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	    ($g2, $taxon_oid, $gene_product_name) = $cur->fetchrow();
	    $cur->finish();
	}
	else {
	    ($taxon_oid, $data_type, $g2) = split(/ /, $gene_oid);
	    $url = "$main_cgi?section=MetaGeneDetail"; 
	    $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid"
		. "&data_type=$data_type&gene_oid=$g2";
	    my ( $new_name, $source ) =
		getGeneProdName( $g2, $taxon_oid, $data_type );
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
	    my $db_id = $func_id;
	    if ( $data_type eq 'database' ) {
		my $sql2 = "";
		if ( $func_id =~ /^COG/ ) {
		    $sql2 = "select count(*) from gene_cog_groups " .
			"where gene_oid = ? and cog = ?";
		}
		elsif ( $func_id =~ /^pfam/ ) {
		    $sql2 = "select count(*) from gene_pfam_families " .
			"where gene_oid = ? and pfam_family = ?";
		}
		elsif ( $func_id =~ /^TIGR/ ) {
		    $sql2 = "select count(*) from gene_tigrfams " .
			"where gene_oid = ? and ext_accession = ?";
		}
		elsif ( $func_id =~ /^KOG/ ) {
		    $sql2 = "select count(*) from gene_kog_groups " .
			"where gene_oid = ? and kog = ?";
		}
		elsif ( $func_id =~ /^KO/ ) {
		    $sql2 = "select count(*) from gene_ko_terms " .
			"where gene_oid = ? and ko_terms = ?";
		}
		elsif ( $func_id =~ /^EC/ ) {
		    $sql2 = "select count(*) from gene_ko_enzymes " .
			"where gene_oid = ? and enzymes = ?";
		}
		elsif ( $func_id =~ /^MetaCyc/ ) {
		    my ($id1, $id2) = split(/\:/, $func_id);
		    $db_id = $id2;
		    $sql2 = qq{
                         select count(*)
                         from biocyc_reaction_in_pwys brp, gene_biocyc_rxns gb
                         where brp.unique_id = gb.biocyc_rxn
                         and gb.gene_oid = ?
                         and brp.in_pwys = ?
                         };
		}
		elsif ( $func_id =~ /^IPR/ ) {
		    $sql2 = "select count(*) from gene_img_interpro_hits " .
			"where gene_oid = ? and iprid = ? ";
		}
		elsif ( $func_id =~ /^TC/ ) {
		    $sql2 = "select count(*) from gene_tc_families " .
			"where gene_oid = ? and tc_family = ? ";
		}
		elsif ( $func_id =~ /^ITERM/ ) {
		    my ($id1, $id2) = split(/\:/, $func_id);
		    $db_id = $id2;
		    if ( isInt($id2) ) {
			$sql2 = qq{
                             select count(*)
                             from gene_img_functions
                             where gene_oid = ?
                             and function = ?
                         };
		    }
		}
		elsif ( $func_id =~ /IPWAY/ ) { 
		    my ($id1, $id2) = split(/\:/, $func_id); 
		    $db_id = $id2;
		    if ( isInt($id2) ) { 
			my $sql3 = qq{
                               select count(*)
                               from img_pathway_reactions ipr,
                                    img_reaction_catalysts irc, 
                                    gene_img_functions g 
                               where g.gene_oid = ?
                               and ipr.pathway_oid = ?
                               and ipr.rxn = irc.rxn_oid
                               and irc.catalysts = g.function
                           };
			my $cur3 = execSql( $dbh, $sql3, $verbose, $gene_oid, $db_id );
			my ($cnt3) = $cur3->fetchrow();
			$cur3->finish();
			if ( $cnt3 ) {
			    $cnt = 1;
			}
			else {
			    $sql3 = qq{
                               select g2.gene_oid, g2.function
                               from img_pathway_reactions ipr2, 
                                    img_reaction_t_components irtc, 
                                    gene_img_functions g2 
                               where g2.gene_oid = ?
                               and ipr2.pathway_oid = ?
                               and ipr2.rxn = irtc.rxn_oid 
                               and irtc.term = g2.function
			    }; 
			    $cur3 = execSql( $dbh, $sql3, $verbose, $gene_oid, $db_id );
			    ($cnt3) = $cur3->fetchrow();
			    $cur3->finish();
			    if ( $cnt3 ) {
				$cnt = 1;
			    }
			} 
		    } 
		}

		if ( $sql2 ) {
		    my $cur2 = execSql( $dbh, $sql2, $verbose, $gene_oid, $db_id );
		    my ($cnt2) = $cur2->fetchrow();
		    $cur2->finish();
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
			@funcs = getGeneTIGRfamId($g2, $taxon_oid, $data_type);
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
              (time() - $start_time)) < 80 ) {
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
    print "<input type='button' name='selectAll' value='Select All' "
        . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1); 
    print "<input type='button' name='clearAll' value='Clear All' "
        . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n"; 
 
    MetaGeneTable::printMetaGeneTableSelect();

    print end_form();
}


####################################################################################
# listFuncInSetForGene
####################################################################################
sub listFuncInSetForGene
{
    my $sid = getContactOid();

    printMainForm();

    my $filename = param('input_file');
    my $gene_oid = param('gene_oid');

    print "<h1>Functions in Function Set for Selected Gene</h1>\n";
    if ( ! $filename ) {
	webError("No function set has been selected.");
	return;
    }
    if ( ! $gene_oid ) {
	webError("No gene has been selected.");
	return;
    }

    my $filename = WebUtil::validFileName($filename);

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
	my $rclause = urClause("g.taxon");
	my $sql = "select gene_oid, gene_display_name, taxon from gene " .
	    "where gene_oid = ? " . $rclause;
	my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	($g2, $taxon_oid, $gene_product_name) = $cur->fetchrow();
	$cur->finish();
    }
    else {
	my ( $new_name, $source ) =
	    getGeneProdName( $g2, $taxon_oid, $data_type );
	$gene_product_name = $new_name;
    }
    print "<h6>Gene ($g2): $gene_product_name. Function Set: $filename.</h6>\n";

    # check all functions in filename
    my $folder = $FUNC_FOLDER;
    open( FH, "$workspace_dir/$sid/$folder/$filename" )
	or webError("File size - file error $filename"); 
    my @func_ids = ();     # save all functions in set for the selected gene
    my %gene_func;
    while ( my $line = <FH> ) {
	chomp($line);
	my $func_id = $line;
	my @funcs = ();

	if ( $data_type eq 'database' ) {
	    my $sql2 = "";
	    if ( $func_id =~ /^COG/ ) {
		if ( ! (defined $gene_func{'cog'}) ) {
		    $sql2 = "select cog from gene_cog_groups " .
			"where gene_oid = ? ";
		}
		else {
		    @funcs = @{$gene_func{'cog'}};
		}
	    }
	    elsif ( $func_id =~ /^pfam/ ) {
		if ( ! (defined $gene_func{'pfam'}) ) {
		    $sql2 = "select pfam_family from gene_pfam_families " .
			"where gene_oid = ? ";
		}
		else {
		    @funcs = @{$gene_func{'pfam'}};
		}
	    }
	    elsif ( $func_id =~ /^TIGR/ ) {
		if ( ! (defined $gene_func{'tigr'}) ) {
		    $sql2 = "select ext_accession from gene_tigrfams " .
			"where gene_oid = ? ";
		}
		else {
		    @funcs = @{$gene_func{'tigr'}};
		}
	    }
	    elsif ( $func_id =~ /^KOG/ ) {
		if ( ! (defined $gene_func{'kog'}) ) {
		    $sql2 = "select kog from gene_kog_groups " .
			"where gene_oid = ? ";
		}
		else {
		    @funcs = @{$gene_func{'kog'}};
		}
	    }
	    elsif ( $func_id =~ /^KO/ ) {
		if ( ! (defined $gene_func{'ko'}) ) {
		    $sql2 = "select ko_terms from gene_ko_terms " .
			"where gene_oid = ? ";
		}
		else {
		    @funcs = @{$gene_func{'ko'}};
		}
	    }
	    elsif ( $func_id =~ /^EC/ ) {
		if ( ! (defined $gene_func{'ec'}) ) {
		    $sql2 = "select enzymes from gene_ko_enzymes " .
			"where gene_oid = ? ";
		}
		else {
		    @funcs = @{$gene_func{'ec'}};
		}
	    }
	    elsif ( $func_id =~ /^MetaCyc/ ) {
		if ( ! (defined $gene_func{'metacyc'}) ) {
		    $sql2 = "select brp.in_pwys from " .
			"biocyc_reaction_in_pwys brp, " .
			"gene_biocyc_rxns gb " .
			"where gb.gene_oid = ? " .
			"and brp.unique_id = gb.biocyc_rxn ";
		}
		else {
		    @funcs = @{$gene_func{'metacyc'}};
		}
	    }
	    elsif ( $func_id =~ /^IPR/ ) {
		if ( ! (defined $gene_func{'interpro'}) ) {
		    $sql2 = "select iprid from gene_img_interpro_hits " .
			"where gene_oid = ? ";
		}
		else {
		    @funcs = @{$gene_func{'interpro'}};
		}
	    }
	    elsif ( $func_id =~ /^TC/ ) {
		if ( ! (defined $gene_func{'tc'}) ) {
		    $sql2 = "select tc_family from gene_tc_families " .
			"where gene_oid = ? ";
		}
		else {
		    @funcs = @{$gene_func{'tc'}};
		}
	    }
	    elsif ( $func_id =~ /^ITERM/ ) {
		if ( ! (defined $gene_func{'iterm'}) ) {
		    $sql2 = "select function from gene_img_functions " .
			"where gene_oid = ? ";
		}
		else {
		    @funcs = @{$gene_func{'iterm'}};
		}
	    }
	    elsif ( $func_id =~ /^IPWAY/ ) {
		if ( ! (defined $gene_func{'ipway'}) ) {
		    $sql2 = qq{
                               select ipr.pathway_oid
                               from img_pathway_reactions ipr,
                                    img_reaction_catalysts irc,
                                    gene_img_functions g
                               where g.gene_oid = ?
                               and ipr.rxn = irc.rxn_oid
                               and irc.catalysts = g.function
                               union
                               select ipr2.pathway_oid
                               from img_pathway_reactions ipr2,
                                    img_reaction_t_components irtc,
                                    gene_img_functions g2
                               where g2.gene_oid = $gene_oid
                               and ipr2.rxn = irtc.rxn_oid
                               and irtc.term = g2.function
			};
		}
		else {
		    @funcs = @{$gene_func{'ipway'}};
		}
	    }

	    if ( $sql2 ) {
		my $cur2 = execSql( $dbh, $sql2, $verbose, $gene_oid );
		for (;;) {
		    my ($f_id) = $cur2->fetchrow();
		    last if !$f_id;

		    if ( $func_id =~ /^ITERM/ ) {
			$f_id = "ITERM:" . FuncUtil::termOidPadded( $f_id );
		    }
		    elsif ( $func_id =~ /^IPWAY/ ) {
			$f_id = "IPWAY:" . FuncUtil::pwayOidPadded( $f_id );
		    }
		    elsif ( $func_id =~ /^MetaCyc/ ) {
			$f_id = "MetaCyc:" . $f_id;
		    }

		    push @funcs, ( $f_id );
		}
		$cur2->finish();

		if ( $func_id =~ /^COG/ ) {
		    $gene_func{'cog'} = \@funcs;
		}
		elsif ( $func_id =~ /^pfam/ ) {
		    $gene_func{'pfam'} = \@funcs;
		}
		elsif ( $func_id =~ /^TIGR/ ) {
		    $gene_func{'tigr'} = \@funcs;
		}
		elsif ( $func_id =~ /^KOG/ ) {
		    $gene_func{'kog'} = \@funcs;
		}
		elsif ( $func_id =~ /^KO/ ) {
		    $gene_func{'ko'} = \@funcs;
		}
		elsif ( $func_id =~ /^EC/ ) {
		    $gene_func{'ec'} = \@funcs;
		}
		elsif ( $func_id =~ /^MetaCyc/ ) {
		    $gene_func{'metacyc'} = \@funcs;
		}
		elsif ( $func_id =~ /^IPR/ ) {
		    $gene_func{'interpro'} = \@funcs;
		}
		elsif ( $func_id =~ /^TC/ ) {
		    $gene_func{'tc'} = \@funcs;
		}
		elsif ( $func_id =~ /^ITERM/ ) {
		    $gene_func{'iterm'} = \@funcs;
		}
		elsif ( $func_id =~ /^IPWAY/ ) {
		    $gene_func{'ipway'} = \@funcs;
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
    my %taxon_name_h;
    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon_oid");
    my $sql = "select taxon_oid, domain, family, taxon_display_name from taxon " .
	"where domain in ('Archaea', 'Bacteria', 'Eukaryota') " . $rclause;
    my $cur = execSql( $dbh, $sql, $verbose );
    for (;;) {
	my ($tid, $domain, $family, $tname) = $cur->fetchrow();
	last if !$tid;
	$domain = substr($domain, 0, 1);
	$taxon_name_h{$tid} = $domain . "\t" . $family . "\t" . $tname;
    }
    $cur->finish();

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

	$sql = "";
	my @taxons = ();
	my $db_id = $func_id;
	if ( $func_id =~ /COG/ ) {
	    $sql = "select distinct taxon_oid from dt_cog_taxon where cog_id = ?";
	}
	elsif ( $func_id =~ /pfam/ ) {
	    $sql = "select distinct taxon_oid from dt_taxon_pfam where ext_accession = ?";
	}
	elsif ( $func_id =~ /TIGR/ ) {
	    $sql = "select g.taxon from gene g where exists " .
		"(select f.gene_oid from gene_tigrfams f " .
		"where f.ext_accession = ? and f.gene_oid = g.gene_oid )";
	}
	elsif ( $func_id =~ /EC/ ) {
	    $sql = "select distinct taxon_oid from dt_ko_enzyme_taxon where ec_number = ?";
	}
	elsif ( $func_id =~ /KOG/ ) {
	    $sql = "select distinct taxon_oid from dt_kog_taxon where kog_id = ?";
	}
	elsif ( $func_id =~ /^KO\:/ ) {
	    $sql = "select g.taxon from gene g where exists " .
		"(select f.gene_oid from gene_ko_terms f " .
		"where f.ko_terms = ? and f.gene_oid = g.gene_oid )";
	}
	elsif ( $func_id =~ /^MetaCyc/ ) {
	    my ($id1, $id2) = split(/\:/, $func_id);
	    $db_id = $id2;
	    $sql = qq{
                select distinct dt.taxon_oid
                from biocyc_reaction_in_pwys brp, biocyc_reaction br,
                     dt_ko_enzyme_taxon dt
                where brp.unique_id = br.unique_id
                and br.ec_number = dt.ec_number
                and dt.gene_count > 0
                and brp.in_pwys = ?
	    }; 
	}
	elsif ( $func_id =~ /^IPR/ ) {
	    $sql = "select g.taxon from gene g where exists " .
		"(select f.gene_oid from gene_img_interpro_hits f " .
		"where f.iprid = ? and f.gene_oid = g.gene_oid )";
	}
	elsif ( $func_id =~ /^TC/ ) {
	    $sql = "select g.taxon from gene g where exists " .
		"(select f.gene_oid from gene_tc_families f " .
		"where f.tc_family = ? and f.gene_oid = g.gene_oid )";
	}
	elsif ( $func_id =~ /^ITERM/ ) {
	    my ($id1, $id2) = split(/\:/, $func_id);
	    $db_id = $id2;
	    if ( isInt($id2) ) {
		$sql = "select g.taxon from gene g where exists " .
		    "(select f.gene_oid from gene_img_functions f " .
		    "where f.function = ? and f.gene_oid = g.gene_oid )";
	    }
	}
	elsif ( $func_id =~ /^IPWAY/ ) { 
	    my ($id1, $id2) = split(/\:/, $func_id); 
	    $db_id = $id2;
	    if ( isInt($id2) ) { 
		$sql = qq{
                       select g.taxon
                       from img_pathway_reactions ipr, 
                            img_reaction_catalysts irc, 
                            gene_img_functions g
                       where ipr.pathway_oid = ?
                       and ipr.rxn = irc.rxn_oid
                       and irc.catalysts = g.function
                       union
                       select g2.taxon
                       from img_pathway_reactions ipr2, 
                            img_reaction_t_components irtc, 
                            gene_img_functions g2
                       where ipr2.pathway_oid = $id2
                       and ipr2.rxn = irtc.rxn_oid 
                       and irtc.term = g2.function
		       }; 
	    }
	}

	my %t_h;
	my $t_cnt = 0;
	if ( $sql ) {
	    $cur = execSql( $dbh, $sql, $verbose, $db_id );
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
	      (time() - $start_time)) < 80 ) {
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
    my $s = "Profiles are based on instantiation ";
    $s .= "of a function in a genome.\n";
    $s .= "A dot '.' means there is no instantiation.<br/>\n";
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
    my $sql = qq{
        select tx.taxon_oid, tx.taxon_display_name
	from taxon tx
	where tx.taxon_oid in( $taxon_oid_str )
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
    my $sql = qq{
        select distinct pwa.pathway_oid, pwa.taxon, pwa.status, pwa.evidence
	from img_pathway_assertions pwa
	where pwa.pathway_oid in( $pathway_oid_str )
	and pwa.taxon in( $taxon_oid_str )
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
    my $sql = qq{
        select tx.taxon_oid, tx.taxon_display_name
	from taxon tx
	where tx.taxon_oid in( $taxon_oid_str )
	order by tx.taxon_display_name
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
    my $sql = qq{
        select pwa.pathway_oid, pwa.taxon, pwa.status
	from img_pathway_assertions pwa
	where pwa.pathway_oid in( $pathway_oid_str )
	and pwa.taxon in( $taxon_oid_str )
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
    $it->addColSpec( "Genome", "char asc" );

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

    my $sql = qq{
        select a.pathway_oid, a.taxon, a.status, a.evidence
	from img_pathway_assertions a
	where a.pathway_oid in( $pway_oid_str )
        and a.taxon in ($taxon_oid_str)
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
    my $rclause = urClause("t.taxon_oid");
    my $sql = "select taxon_oid, domain, family, taxon_display_name from taxon " .
	"where domain in ('Archaea', 'Bacteria', 'Eukaryota') " . $rclause;
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
    for my $taxon ( @taxon_oids ) {
	if ( ! $taxon_name_h{$taxon} ) {
	    # not selected
	    next;
	}

	# get essential genes
	my %gene_h;
	my $sql2 = "select distinct gene_oid from pmeg_gene_pred_essen " .
	    "where taxon_oid = ?";
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

	    $sql = "";
	    if ( $func_id =~ /COG/ ) {
		$sql = "select g.gene_oid from gene g, gene_cog_groups gcg " .
		    "where g.taxon = ? and gcg.cog = ? and g.gene_oid = gcg.gene_oid";
	    }
	    elsif ( $func_id =~ /pfam/ ) {
		$sql = "select distinct g.gene_oid from gene g, gene_pfam_families gpf " .
		    "where g.taxon = ? and g.gene_oid = gpf.gene_oid and gpf.ext_accession = ?";
	    }
	    elsif ( $func_id =~ /TIGR/ ) {
		$sql = "select distinct g.gene_oid from gene g, gene_tigrfams gt " .
		    "where g.taxon = ? and g.gene_oid = gt.gene_oid and gt.ext_accession = ?";
	    }
	    elsif ( $func_id =~ /EC/ ) {
		$sql = "select distinct g.gene_oid from gene g, gene_ko_enzymes gke " .
		    "where g.taxon = ? and g.gene_oid = gke.gene_oid and gke.enzymes = ?";
	    }
	    elsif ( $func_id =~ /KO/ ) {
		$sql = "select distinct g.gene_oid from gene g, gene_ko_terms gkt " .
		    "where g.taxon = ? and g.gene_oid = gkt.gene_oid and gkt.ko_terms = ?";
	    }

	    if ( $sql ) {
		$cur = execSql( $dbh, $sql, $verbose, $taxon, $func_id );
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
	      (time() - $start_time)) < 80 ) {
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
    my $s = "Profiles are based on instantiation ";
    $s .= "of a function in a genome.\n";
    $s .= "A dot '.' means there is no instantiation.<br/>\n";
    PhyloOccur::printAlignment( '', \@idRecs, $s );

    printStatusLine( "Loaded.", 2 );
}


#############################################################################
# showRuleBioClusterProfile
#############################################################################
sub showRuleBioClusterProfile {
    my $sid = getContactOid();

    printMainForm();

    my $folder   = param("directory");
    my $filename = param("filename");
    my $genome_set = param('bc_genome_set_name');
    my $include_myimg = param('include_myimg');
    print "<h1>Rule Biosynthetic Cluster Profile (Genome Set: $genome_set)</h1>\n";

    my @set = param('genome_set_name');
    my @rules = param('rule_id');
    if ( scalar(@rules) == 0 ) {
        print "<p>No rules are selected.\n";
        return;
    }

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my %rule_type_h;
    my %rule_def_h;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    $rule_type_h{$id} = $type;
	    $rule_def_h{$id} = $body;
	}
	close $res;
    }

    my $x;
    for $x (@rules) {
#	print "<p>*** rule: $x\n";
#	print $rule_type_h{$x} . "; " . $rule_def_h{$x} . "\n";
        print hiddenVar( "rule_id", $x );
    }

    print "<p>selected rule(s): " . join(", ", @rules) . "\n";

    if ( $include_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
    }

    if ( $genome_set eq "" ) {
        webError("Please select a genome set.\n");
        return;
    }

    WebUtil::checkFileName($genome_set);

    # this also untaints the name
    my $genome_filename = WebUtil::validFileName($genome_set);

    open( FH, "$workspace_dir/$sid/$GENOME_FOLDER/$genome_filename" )
	or webError("File size - file error $genome_filename"); 

    timeout( 60 * $merfs_timeout_mins ); 
    my $start_time = time();
    my $timeout_msg = "";

    my $sid = getContactOid(); 
    if ( $sid == 312 ) {
	print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }
    printStartWorkingDiv();
    print "<p>Checking genomes in genome set ...<br/>\n";

    my $select_id_name = "taxon_oid";

    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon_oid");
    my $sql = "select t.taxon_display_name from taxon t where t.taxon_oid = ? " .
	$rclause;

    my $it = new InnerTable( 0, "funcSet$$", "funcSet", 0 );
    $it->addColSpec( "Bio Cluster ID",   "number asc", "right" );
    $it->addColSpec( "Genome",   "char asc", "left" );
    for $x (@rules) {
	$it->addColSpec( "$x", "char asc", "left" ); 
    }
    my $sd = $it->getSdDelim(); 

    my %bc_taxon;
    my %bc_result_text; 
    my $prev_taxon = "";
    while ( my $line = <FH> ) {
        if ( (($merfs_timeout_mins * 60) -
              (time() - $start_time)) < 80 ) {
            $timeout_msg = "Process takes too long to run " .
                "-- stopped at $prev_taxon. " .
                "Only partial result is displayed.";
            last;
        } 

	chomp($line);
	my $taxon_oid = $line;

	for $x (@rules) {
	    print "<p>Evaluating rule $x on genome $taxon_oid ...<br/>\n";
	    my %res_h;
	    evalRuleOnBioCluster($dbh, $rule_type_h{$x}, $rule_def_h{$x},
				 $taxon_oid, \%res_h, $include_myimg);
 
	    for my $bc_id ( keys %res_h ) {
		$bc_taxon{$bc_id} = $taxon_oid;
		my $result_text = 'false';
		my $result = $res_h{$bc_id};
		if ( $result > 0 ) {
		    $result_text = 'true';
		}
		elsif ( $result < 0 ) {
		    $result_text = 'unknown';
		}

		if ( $bc_result_text{$bc_id} ) {
		    my $href = $bc_result_text{$bc_id};
		    $href->{$x} = $result_text;
		}
		else { 
		    my %h2;
		    $h2{$x} = $result_text;
		    $bc_result_text{$bc_id} = \%h2;
		}
	    }  #end bc_id
	}  # end for x

	##### test
	## last;
    }  # end while
    close FH; 

    print "<p>Preparing output ...\n";

    my %taxon_name_h;
    for my $bc_id ( keys %bc_taxon ) {
	my $r;
	my $taxon_oid = $bc_taxon{$bc_id};
	my $taxon_name = "";
	if ( $taxon_name_h{$taxon_oid} ) {
	    $taxon_name = $taxon_name_h{$taxon_oid};
	}
	else {
	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    ($taxon_name) = $cur->fetchrow();
	    $cur->finish();
	}

	if ( ! $taxon_name ) {
	    next;
	}

	my $bc_url = "$main_cgi?section=BiosyntheticDetail&page=cluster_detail";
	$bc_url .= "&taxon_oid=$taxon_oid&cluster_id=$bc_id";

	my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
	$url .= "&taxon_oid=$taxon_oid";

	$r .= $bc_id . $sd . alink($bc_url, $bc_id) . "\t";
	$r .= $taxon_name . $sd . alink($url, $taxon_name) . "\t";

	for $x (@rules) {
	    my $href = $bc_result_text{$bc_id};
	    my $result_text = 'false';
	    if ( $href && $href->{$x} ) {
		$result_text = $href->{$x};
	    }

	    my $url = "$main_cgi?section=WorkspaceRuleSet"; 
	    $url .= "&page=showBioClusterEvalResult&taxon_oid=$taxon_oid" .
		"&cluster_id=$bc_id&filename=$filename&rule_id=$x";
	    if ( $include_myimg ) {
		$url .= "&include_myimg=$include_myimg";
	    }

	    $r .= $result_text . $sd . alink($url, $result_text) . "\t";
	}

	$prev_taxon = $taxon_oid;
        $it->addRow($r); 
    }

    $dbh->disconnect();
    printEndWorkingDiv();
    if ( $sid == 312 ) {
	print "<p>*** end time: " . currDateTime() . "<br/>\n";
    }

    if ( $timeout_msg ) {
    	print "<p><font color='red'>$timeout_msg</font>\n";
    }

    $it->printOuterTable(1);

#    WebUtil::printButtonFooter();
#    WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);

    print end_form();
}


#############################################################################
# evalRuleOnBioCluster
#
# rule_type: and, or
# rule_def: rule definition
# taxon_oid: taxon to be evaluated
#############################################################################
sub evalRuleOnBioCluster {
    my ($dbh, $rule_type, $rule_def, $taxon_oid, $res_href, $include_myimg)
	= @_;

    my @clusters = ();
    my $sql = "select cluster_id from bio_cluster_new where taxon = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for (;;) {
	my ($bc_id) = $cur->fetchrow();
	last if ! $bc_id;

	push @clusters, ( $bc_id );
    }
    $cur->finish();

    $sql = "select in_file from taxon where taxon_oid = ? " .
	"and obsolete_flag = 'No' ";
    $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($in_file) = $cur->fetchrow();
    $cur->finish();

    if ( ! $in_file ) {
	return;
    }

    if ( $in_file eq 'No' ) {
	if ( $rule_type eq 'and' ) {
	    for my $bc_id ( @clusters ) {
		$res_href->{$bc_id} = 1;
	    }
	    evalAndRuleOnTaxonBC($dbh, $rule_def, $taxon_oid,
				 $include_myimg, $res_href);
	}
	elsif ( $rule_type eq 'or' ) {
	    for my $bc_id ( @clusters ) {
		$res_href->{$bc_id} = 0;
	    }
	    evalOrRuleOnTaxonBC($dbh, $rule_def, $taxon_oid,
				$include_myimg, $res_href);
	}

	return;
    }

    for my $bc_id ( @clusters ) {
	if ( $rule_type eq 'and' ) {
	    my $res1 = evalAndRuleOnBioCluster($dbh, $rule_def, $bc_id,
				    $include_myimg);
	    $res_href->{$bc_id} = $res1;
	}
	else {
	    my $res2 = evalOrRuleOnBioCluster($dbh, $rule_def, $bc_id,
				   $include_myimg);
	    $res_href->{$bc_id} = $res2;
	}
    }
}


#############################################################################
# evalAndRuleOnBioCluster
#
# rule_def: rule definition
# bc_id: bio cluster id
#############################################################################
sub evalAndRuleOnBioCluster {
    my ($dbh, $rule_def, $bc_id, $include_myimg) = @_;

    if ( ! $bc_id ) {
	return 0;
    }

    my $sql = "select t.in_file from taxon t, bio_cluster_new bc " .
	"where t.taxon_oid = bc.taxon and bc.cluster_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $bc_id );
    my ($in_file) = $cur->fetchrow();
    $cur->finish();

    my @conds = split(/\,/, $rule_def);

    my $result1 = 1;
    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my $result2 = 0;
	my @comps = split(/\|/, $cond1);
	for my $c2 ( @comps ) {
	    my $result3 = 0;
	    if ( $in_file eq 'Yes' ) {
		$result3 = evalFuncOnBioCluster_meta($dbh, $c2, $bc_id, 
						     $include_myimg);
	    }
	    else {
		$result3 = evalFuncOnBioCluster($dbh, $c2, $bc_id, $include_myimg);
	    }

	    if ( $result3 == 1 ) {
		# true
		$result2 = 1;
		last;
	    }
	    elsif ( $result3 < 0 ) {
		# unknown
		if ( $result2 == 0 ) {
		    $result2 = -1;
		}
	    }
	}

	if ( $result2 == 0 ) {
	    # false
	    $result1 = 0;
	    last;
	}
	elsif ( $result2 < 0 ) {
	    # unknown
	    if ( $result1 > 0 ) {
		$result1 = -1;
	    }
	}
    }

    return $result1;
}

#############################################################################
# evalAndRuleOnTaxonBC (for Oracle only)
#
# rule_def: rule definition
# taxon_oid: taxon oid
#############################################################################
sub evalAndRuleOnTaxonBC {
    my ($dbh, $rule_def, $taxon_oid, $include_myimg, $res_h) = @_;

    if ( ! $taxon_oid ) {
	return;
    }

    for my $key (keys %$res_h) {
	$res_h->{$key} = 1;
    }

    my @conds = split(/\,/, $rule_def);

    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	# result for sub or condition
	my %res2_h;
	for my $key (keys %$res_h) {
	    $res2_h{$key} = 0;
	}

	my @comps = split(/\|/, $cond1);
	for my $c2 ( @comps ) {
	    my %res3_h;
	    for my $key (keys %$res_h) {
		$res3_h{$key} = 0;
	    }
	    evalFuncOnTaxonBC($dbh, $c2, $taxon_oid, $include_myimg, \%res3_h);

	    for my $key (keys %$res_h) {
		if ( $res3_h{$key} == 1 ) {
		    # true
		    $res2_h{$key} = 1;
		}
		elsif ( $res3_h{$key} < 0 ) {
		    # unknown
		    $res2_h{$key} = -1;
		}
	    }
	}

	for my $key (keys %$res_h) {
	    if ( $res2_h{$key} > 0 ) {
		# true
	    }
	    elsif ( $res2_h{$key} < 0 ) {
		# unknown
		$res_h->{$key} = -1;
	    }
	    else {
		# false
		$res_h->{$key} = 0;
	    }
	}
    }  # end for cond1

    return;
}


#############################################################################
# evalOrRuleOnBioCluster
#
# rule_def: rule definition
# bc_id: bio cluster id
#############################################################################
sub evalOrRuleOnBioCluster {
    my ($dbh, $rule_def, $bc_id, $include_myimg) = @_;

    if ( ! $bc_id ) {
	return 0;
    }

    my $sql = "select t.in_file from taxon t, bio_cluster_new bc " .
	"where t.taxon_oid = bc.taxon and bc.cluster_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $bc_id );
    my ($in_file) = $cur->fetchrow();
    $cur->finish();

    my @conds = split(/\|/, $rule_def);

    my $result1 = 0;
    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

	my $result2 = 1;
	my @comps = split(/\,/, $cond1);
	for my $c2 ( @comps ) {
	    my $result3 = 0;
	    if ( $in_file eq 'Yes' ) {
		$result3 = evalFuncOnBioCluster_meta($dbh, $c2, $bc_id, 
						     $include_myimg);
	    }
	    else {
		$result3 = evalFuncOnBioCluster($dbh, $c2, $bc_id, $include_myimg);
	    }

	    if ( $result3 == 0 ) {
		# false
		$result2 = 0;
		last;
	    }
	    elsif ( $result3 < 0 ) {
		# unknown
		$result2 = -1;
	    }
	}

	if ( $result2 > 0 ) {
	    # true
	    $result1 = 1;
	    last;
	}
	elsif ( $result2 < 0 ) {
	    # unknown
	    $result1 = -1;
	}
    }

    return $result1;
}

#############################################################################
# evalOrRuleOnTaxonBC (only for Oracle)
#
# rule_def: rule definition
# taxon_oid: taxon_oid
#############################################################################
sub evalOrRuleOnTaxonBC {
    my ($dbh, $rule_def, $taxon_oid, $include_myimg, $res_h) = @_;

    if ( ! $taxon_oid ) {
	return;
    }

    for my $key (keys %$res_h) { 
        $res_h->{$key} = 0;
    } 

    my @conds = split(/\|/, $rule_def);

    for my $cond1 ( @conds ) {
	# remove quote
	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}

        # result for sub and condition
        my %res2_h; 
        for my $key (keys %$res_h) { 
            $res2_h{$key} = 1;
        } 

	my @comps = split(/\,/, $cond1);
	for my $c2 ( @comps ) {
            my %res3_h; 
            for my $key (keys %$res_h) {
                $res3_h{$key} = 0;
            }
	    evalFuncOnBioCluster($dbh, $c2, $taxon_oid, $include_myimg, \%res3_h);

            for my $key (keys %$res_h) {
                if ( $res3_h{$key} == 1 ) { 
                    # true
                } 
                elsif ( $res3_h{$key} < 0 ) {
                    # unknown
                    $res2_h{$key} = -1;
                } 
		else {
		    # false
                    $res2_h{$key} = 0;
		}
            } 
	}

        for my $key (keys %$res_h) { 
            if ( $res2_h{$key} > 0 ) {
                # true
                $res_h->{$key} = 1;
	    }
            elsif ( $res2_h{$key} < 0 ) {
                # unknown
                $res_h->{$key} = -1; 
            } 
            else { 
                # false
            } 
        } 
    }

    return;
}


#############################################################################
# evalFuncOnBioCluster
#
# func_id: function id
# bc_id: bio cluster
# return: true 1, false 0, unknown -1
#############################################################################
sub evalFuncOnBioCluster {
    my ($dbh, $func_id, $bc_id, $include_myimg) = @_;

    my $gene_oid;
    my $taxon_oid;

    my $neg = 0;
    if ( $func_id =~ /^\!/ ) {
	$neg = 1;
	$func_id = substr($func_id, 1, length($func_id)-1);
    }

    my ($f1, $f2) = split(/\:/, $func_id);

    if ( $f1 eq 'IPWAY' ) {
	if ( ! $f2 ) {
	    $f2 = 0;
	}

	my $sql = qq{
            select irc.catalysts
               from img_reaction_catalysts irc, img_pathway_reactions ipr1
               where ipr1.pathway_oid = ?
               and ipr1.rxn = irc.rxn_oid
               union
               select irtc.term
               from img_reaction_t_components irtc, img_pathway_reactions ipr2
               where ipr2.pathway_oid = ?
               and ipr2.rxn = irtc.rxn_oid
	    };

	my $cur = execSql( $dbh, $sql, $verbose, $f2, $f2 );
	my @terms = ();
	for (;;) {
	    my ($term_oid) = $cur->fetchrow();
	    last if ! $term_oid;
	    push @terms, ( $term_oid );
	}
	$cur->finish();
	my $term_list = join(", ", @terms);

	my $sql = "select count(*) from gene_img_functions " .
	    "where gene_oid in ( select gene_oid from bio_cluster_features_new " .
	    "where feature_type = 'gene' and cluster_id = ? ) " .
	    "and function in (" . $term_list . ")";
	$cur = execSql( $dbh, $sql, $verbose, $bc_id );
	my ($term_cnt) = $cur->fetchrow();
	$cur->finish();

	if ( $term_cnt ) {
	    if ( $neg ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
	else {
	    if ( $neg ) {
		return 1;
	    }
	    else {
		return 0;
	    }
	}
    }
    elsif ( $f1 eq 'ITERM' ) {
	if ( ! $f2 ) {
	    $f2 = 0;
	}

	my $sql = "select count(*) from gene_img_functions gif " .
	    "where gif.function = ? and gif.gene_oid in " .
	    " ( select gene_oid from bio_cluster_features_new " .
	    "where feature_type = 'gene' and cluster_id = ? ) ";
	my $cur = execSql( $dbh, $sql, $verbose, $f2, $bc_id );
	my ($res) = $cur->fetchrow();
	$cur->finish();

	if ( $include_myimg && (! $res) ) {
	    # check MyIMG
	    my $sid = getContactOid();
	    $sql = "select count(*) " .
		"from gene_myimg_functions gmf, gene_myimg_terms gmt " .
		"where gmt.term_oid = ? and gmt.gene_oid in " .
		" ( select gene_oid from bio_cluster_features_new " .
		"where feature_type = 'gene' and cluster_id = ? ) " .
		"and gmf.gene_oid = gmt.gene_oid ";
	    if ( $include_myimg == 1 ) {
		$sql .= "and gmf.modified_by = $sid ";
	    }
	    elsif ( $include_myimg == 2 ) {
		$sql .= "and gmf.is_public = 'Yes' ";
	    }
	    elsif ( $include_myimg == 3 ) {
		$sql .= "and (gmf.modified_by = $sid or gmf.is_public = 'Yes') ";
	    }
	    $cur = execSql( $dbh, $sql, $verbose, $f2, $bc_id );
	    ($res) = $cur->fetchrow();
	    $cur->finish();
	}

	if ( $res ) {
	    if ( $neg ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
	else {
	    if ( $neg ) {
		return 1;
	    }
	    else {
		return 0;
	    }
	}
    }
    else {
	# other functions
	my $sql1 = "";
	my $db_id = $func_id;
	if ( $func_id =~ /^COG/ ) {
	    $sql1 = "select count(*) from gene_cog_groups g " .
		"where g.cog = ? ";
	}
	elsif ( $func_id =~ /^pfam/ ) {
	    $sql1 = "select count(*) from gene_pfam_families g " .
		"where g.pfam_family = ? ";
	}
	elsif ( $func_id =~ /^TIGR/ ) {
	    $sql1 = "select count(*) from gene_tigrfams g " .
		"where g.ext_accession = ? ";
	}
	elsif ( $f1 eq 'KO' ) {
	    $sql1 = "select count(*) from gene_ko_terms g " .
		"where g.ko_terms = ? ";
	}
	elsif ( $f1 eq 'EC' ) {
	    $sql1 = "select count(*) from gene_ko_enzymes g " .
		"where g.enzymes = ? ";
	}
	elsif ( $f1 eq 'TC' ) {
	    $sql1 = "select count(*) from gene_tc_families g " .
		"where g.tc_family = ? ";
	}
	elsif ( $func_id =~ /^IPR/ ) {
	    $sql1 = "select count(*) from gene_img_interpro_hits g " .
		"where g.iprid = ? ";
	}
	elsif ( $f1 eq 'MetaCyc' ) {
	    $sql1 = "select count(*) from " .
		"biocyc_reaction_in_pwys brp, " .
		"gene_biocyc_rxns g " .
		"where brp.in_pwys = ? " .
		"and brp.unique_id = g.biocyc_rxn ";

	    $db_id = $f2;
	}
	elsif ( $f1 eq 'IPWAY' ) { 
	    $sql1 = "select count(*) from " . 
		"img_pathway_reactions ipr, img_reaction_t_components irtc, " . 
		"gene_img_functions g " . 
		"where ipr.pathway_oid = ? " . 
		"and ipr.rxn = irtc.rxn_oid " .
		"and irtc.term = g.function ";
 
	    $db_id = $f2; 
	} 
	elsif ( $f1 eq 'ITERM' ) {
	    $sql1 = "select count(*) from gene_img_functions g " .
		"where g.function = ? ";
	    if ( isInt($f2) ) {
		$db_id = $f2;
	    }
	    else {
		$db_id = 0;
	    }
	}

	my $sql = $sql1 . " and g.gene_oid in " .
	    " ( select gene_oid from bio_cluster_features_new " .
	    "where feature_type = 'gene' and cluster_id = ? ) ";

	my $cur = execSql( $dbh, $sql, $verbose, $db_id, $bc_id );
	my ($res) = $cur->fetchrow();
	$cur->finish();

	if ( $include_myimg && (! $res) ) {
	    # check MyIMG
	    my $sql2 = "";
	    my $sid = getContactOid();
	    if ( $f1 eq 'ITERM' ) {
		$sql2 = "select count(*) " .
		    "from gene_myimg_functions gmf, gene_myimg_terms g " .
		    "where g.term_oid = ? " .
		    "and gmf.gene_oid = g.gene_oid ";
	    }
	    elsif ( $f1 eq 'IPWAY' ) { 
		$sql2 = "select count(*) from " . 
		    "img_pathway_reactions ipr, img_reaction_t_components irtc, " . 
		    "gene_myimg_terms g, gene_myimg_functions gmf " . 
		    "where ipr.pathway_oid = ? " . 
		    "and ipr.rxn = irtc.rxn_oid " .
		    "and irtc.term = g.term_oid " .
		    "and gmf.gene_oid = g.gene_oid ";
	    }
	    elsif ( $f1 eq 'EC' ) {
		$sql2 = "select count(*) " .
		    "from gene_myimg_functions gmf, gene_myimg_enzymes g " .
		    "where g.ec_number = ? " .
		    "and gmf.gene_oid = g.gene_oid ";
	    }

	    if ( $sql2 ) {
		$sql = $sql2 . " and g.gene_oid in " .
		    " ( select gene_oid from bio_cluster_features_new " .
		    "where feature_type = 'gene' and cluster_id = ? ) ";
		if ( $include_myimg == 1 ) {
		    $sql .= "and gmf.modified_by = $sid ";
		}
		elsif ( $include_myimg == 2 ) {
		    $sql .= "and gmf.is_public = 'Yes' ";
		}
		elsif ( $include_myimg == 3 ) {
		    $sql .= "and (gmf.modified_by = $sid or gmf.is_public = 'Yes') ";
		}
		$cur = execSql( $dbh, $sql, $verbose, $db_id, $bc_id );
		($res) = $cur->fetchrow();
		$cur->finish();
	    }
	}

	if ( $res ) {
	    if ( $neg ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
    }

    if ( $neg ) {
	return 1;
    }

    return 0;
}


#############################################################################
# evalFuncOnTaxonBC (for Oracle only)
#
# func_id: function id
# taxon_oid: taxon oid
# return: true 1, false 0, unknown -1
#############################################################################
sub evalFuncOnTaxonBC {
    my ($dbh, $func_id, $taxon_oid, $include_myimg, $res_h) = @_;

    my $gene_oid;

    my $neg = 0;
    if ( $func_id =~ /^\!/ ) {
	$neg = 1;
	$func_id = substr($func_id, 1, length($func_id)-1);
    }

    if ( $neg ) {
	# initialize all to 1
	for my $key (keys %$res_h) {
	    $res_h->{$key} = 1;
	}
    }
    else {
	# initialize all to 0
	for my $key (keys %$res_h) {
	    $res_h->{$key} = 0;
	}
    }

    my ($f1, $f2) = split(/\:/, $func_id);

    if ( $f1 eq 'IPWAY' ) {
	if ( ! $f2 ) {
	    $f2 = 0;
	}

	my $sql = qq{
            select irc.catalysts
               from img_reaction_catalysts irc, img_pathway_reactions ipr1
               where ipr1.pathway_oid = ?
               and ipr1.rxn = irc.rxn_oid
               union
               select irtc.term
               from img_reaction_t_components irtc, img_pathway_reactions ipr2
               where ipr2.pathway_oid = ?
               and ipr2.rxn = irtc.rxn_oid
	    };

	my $cur = execSql( $dbh, $sql, $verbose, $f2, $f2 );
	my @terms = ();
	for (;;) {
	    my ($term_oid) = $cur->fetchrow();
	    last if ! $term_oid;
	    push @terms, ( $term_oid );
	}
	$cur->finish();
	my $term_list = join(", ", @terms);

	my $sql = "select bc.cluster_id, count(*) " .
	    "from bio_cluster_new bc, bio_cluster_features_new bcf, " .
	    "gene_img_functions gif " .
	    "where bcf.gene_oid = gif.gene_oid " . 
	    "and bc.cluster_id = bcf.cluster_id " .
	    "and bc.taxon = ? " .
	    "and bcf.feature_type = 'gene' " .
	    "and function in (" . $term_list . ") " .
	    "group by bc.cluster_id ";
	$cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	for (;;) {
	    my ($bc_id, $term_cnt) = $cur->fetchrow();
	    last if ! $bc_id;

	    if ( $term_cnt ) {
		if ( $neg ) {
		    $res_h->{$bc_id} = 0;
		}
		else {
		    $res_h->{$bc_id} = 1;
		}
	    }
	    else {
		if ( $neg ) {
		    $res_h->{bc_id} = 1;
		}
		else {
		    $res_h->{bc_id} = 0;
		}
	    }
	}
	$cur->finish();
    }
    elsif ( $f1 eq 'ITERM' ) {
	if ( ! $f2 ) {
	    $f2 = 0;
	}

	my $sql = "select bc.cluster_id, count(*) " .
	    "from bio_cluster_new bc, bio_cluster_features_new bcf, " .
	    "gene_img_functions gif " .
	    "where gif.function = ? and gif.gene_oid = bcf.gene_oid " .
	    "and bc.taxon = ? and bc.cluster_id = bcf.cluster_id " .
	    "and bcf.feature_type = 'gene' " .
	    "group by bc.cluster_id ";
	my $cur = execSql( $dbh, $sql, $verbose, $f2, $taxon_oid );
	for (;;) {
	    my ($bc_id, $res) = $cur->fetchrow();
	    last if ! $bc_id;

	    if ( $res ) {
		if ( $neg ) {
		    $res_h->{$bc_id} = 0;
		}
		else {
		    $res_h->{$bc_id} = 1;
		}
	    }
	    else {
		if ( $neg ) {
		    $res_h->{bc_id} = 1;
		}
		else {
		    $res_h->{$bc_id} = 0;
		}
	    }
	}
	$cur->finish();

	if ( $include_myimg ) {
	    # check MyIMG
	    my $sid = getContactOid();
	    $sql = "select bc.cluster_id, count(*) " .
		"from bio_cluster_new bc, bio_cluster_features_new bcf, " .
		"gene_myimg_functions gmf, gene_myimg_terms gmt " .
		"where gmt.term_oid = ? and gmt.gene_oid = bcf.gene_oid " .
		"and bcf.feature_type = 'gene' " .
		"and bc.taxon = ? and bc.cluster_id = bcf.cluster_id " .
		"and gmf.gene_oid = gmt.gene_oid ";
	    if ( $include_myimg == 1 ) {
		$sql .= "and gmf.modified_by = $sid ";
	    }
	    elsif ( $include_myimg == 2 ) {
		$sql .= "and gmf.is_public = 'Yes' ";
	    }
	    elsif ( $include_myimg == 3 ) {
		$sql .= "and (gmf.modified_by = $sid or gmf.is_public = 'Yes') ";
	    }
	    $sql .= " group by bc.cluster_id ";
	    $cur = execSql( $dbh, $sql, $verbose, $f2, $taxon_oid );
	    for (;;) {
		my ($bc_id, $res) = $cur->fetchrow();
		last if ! $bc_id;
		if ( $res ) {
		    if ( $neg ) {
			$res_h->{$bc_id} = 0;
		    }
		    else {
			$res_h->{$bc_id} = 1;
		    }
		}
		else {
		    if ( $neg ) {
			$res_h->{bc_id} = 1;
		    }
		    else {
			$res_h->{$bc_id} = 0;
		    }
		}
	    }
	    $cur->finish();
	}
    }
    else {
	# other functions
	my $sql1 = "";
	my $db_id = $func_id;
	if ( $func_id =~ /^COG/ ) {
	    $sql1 = "select bcf.cluster_id, count(*) " .
		"from gene_cog_groups g, bio_cluster_features_new bcf " .
		"where g.cog = ? ";
	}
	elsif ( $func_id =~ /^pfam/ ) {
	    $sql1 = "select bcf.cluster_id, count(*) " .
		"from gene_pfam_families g, bio_cluster_features_new bcf " .
		"where g.pfam_family = ? ";
	}
	elsif ( $func_id =~ /^TIGR/ ) {
	    $sql1 = "select bcf.cluster_id, count(*) " .
		"from gene_tigrfams g, bio_cluster_features_new bcf " .
		"where g.ext_accession = ? ";
	}
	elsif ( $f1 eq 'KO' ) {
	    $sql1 = "select bcf.cluster_id, count(*) " .
		"from gene_ko_terms g, bio_cluster_features_new bcf " .
		"where g.ko_terms = ? ";
	}
	elsif ( $f1 eq 'EC' ) {
	    $sql1 = "select bcf.cluster_id, count(*) " .
		"from gene_ko_enzymes g, bio_cluster_features_new bcf " .
		"where g.enzymes = ? ";
	}
	elsif ( $f1 eq 'TC' ) {
	    $sql1 = "select bcf.cluster_id, count(*) " .
		"from gene_tc_families g, bio_cluster_features_new bcf " .
		"where g.tc_family = ? ";
	}
	elsif ( $func_id =~ /^IPR/ ) {
	    $sql1 = "select bcf.cluster_id, count(*) " .
		"from gene_img_interpro_hits g, bio_cluster_features_new bcf " .
		"where g.iprid = ? ";
	}
	elsif ( $f1 eq 'MetaCyc' ) {
	    $sql1 = "select bcf.cluster_id, count(*) from " .
		"biocyc_reaction_in_pwys brp, " .
		"gene_biocyc_rxns g, bio_cluster_features_new bcf " .
		"where brp.in_pwys = ? " .
		"and brp.unique_id = g.biocyc_rxn ";

	    $db_id = $f2;
	}
	elsif ( $f1 eq 'IPWAY' ) { 
	    $sql1 = "select bcf.cluster_id, count(*) from " . 
		"img_pathway_reactions ipr, img_reaction_t_components irtc, " . 
		"gene_img_functions g, bio_cluster_features_new bcf " . 
		"where ipr.pathway_oid = ? " . 
		"and ipr.rxn = irtc.rxn_oid " .
		"and irtc.term = g.function ";
 
	    $db_id = $f2; 
	} 
	elsif ( $f1 eq 'ITERM' ) {
	    $sql1 = "select bcf.cluster_id, count(*) " .
		"from gene_img_functions g, bio_cluster_features_new bcf " .
		"where g.function = ? ";
	    if ( isInt($f2) ) {
		$db_id = $f2;
	    }
	    else {
		$db_id = 0;
	    }
	}

	my $sql = $sql1 . " and g.gene_oid = bcf.gene_oid " .
	    "and bcf.feature_type = 'gene' " .
	    "and g.taxon = ? group by bcf.cluster_id ";

	my $cur = execSql( $dbh, $sql, $verbose, $db_id, $taxon_oid );
	for (;;) {
	    my ($bc_id, $res) = $cur->fetchrow();
	    last if ! $bc_id;
	    if ( $res ) {
		if ( $neg ) {
		    $res_h->{$bc_id} = 0;
		}
		else {
		    $res_h->{$bc_id} = 1;
		}
	    }
	    else {
		if ( $neg ) {
		    $res_h->{bc_id} = 1;
		}
		else {
		    $res_h->{$bc_id} = 0;
		}
	    }
	}
	$cur->finish();

	if ( $include_myimg ) {
	    # check MyIMG
	    my $sql2 = "";
	    my $sid = getContactOid();
	    if ( $f1 eq 'ITERM' ) {
		$sql2 = "select bc.cluster_id, count(*) " .
		    "from gene_myimg_functions gmf, " .
		    "gene_myimg_terms g, bio_cluster_new bc, " .
		    "bio_cluster_features_new bcf " .
		    "where g.term_oid = ? " .
		    "and gmf.gene_oid = g.gene_oid " .
		    "and bcf.gene_oid = g.gene_oid " .
		    "and bcf.feature_type = 'gene' " .
		    "and bc.cluster_id = bcf.cluster_id " .
		    "and bc.taxon = ? ";
	    }
	    elsif ( $f1 eq 'IPWAY' ) { 
		$sql2 = "select bc.cluster_id, count(*) from " . 
		    "img_pathway_reactions ipr, " .
		    "img_reaction_t_components irtc, " . 
		    "bio_cluster_new bc, bio_cluster_features_new bcf, " .
		    "gene_myimg_terms g, gene_myimg_functions gmf " . 
		    "where ipr.pathway_oid = ? " . 
		    "and ipr.rxn = irtc.rxn_oid " .
		    "and irtc.term = g.term_oid " .
		    "and gmf.gene_oid = g.gene_oid " .
		    "and bcf.gene_oid = g.gene_oid " .
		    "and bcf.feature_type = 'gene' " .
		    "and bc.cluster_id = bcf.cluster_id " .
		    "and bc.taxon = ? ";
	    }
	    elsif ( $f1 eq 'EC' ) {
		$sql2 = "select bc.cluster_id, count(*) " .
		    "from gene_myimg_functions gmf, gene_myimg_enzymes g, " .
		    "bio_cluster_new bc, bio_cluster_features_new bcf " .
		    "where g.ec_number = ? " .
		    "and gmf.gene_oid = g.gene_oid " .
		    "and bcf.gene_oid = g.gene_oid " .
		    "and bcf.feature_type = 'gene' " .
		    "and bc.cluster_id = bcf.cluster_id " .
		    "and bc.taxon = ? ";
	    }

	    if ( $sql2 ) {
		$sql = $sql2;
		if ( $include_myimg == 1 ) {
		    $sql .= "and gmf.modified_by = $sid ";
		}
		elsif ( $include_myimg == 2 ) {
		    $sql .= "and gmf.is_public = 'Yes' ";
		}
		elsif ( $include_myimg == 3 ) {
		    $sql .= "and (gmf.modified_by = $sid or gmf.is_public = 'Yes') ";
		}
		$sql .= " group by bc.cluster_id ";
		$cur = execSql( $dbh, $sql, $verbose, $db_id, $taxon_oid );
		for (;;) {
		    my ($bc_id, $res) = $cur->fetchrow();
		    last if ! $bc_id;
		    if ( $res ) {
			if ( $neg ) {
			    $res_h->{$bc_id} = 0;
			}
			else {
			    $res_h->{$bc_id} = 1;
			}
		    }
		    else {
			if ( $neg ) {
			    $res_h->{bc_id} = 1;
			}
			else {
			    $res_h->{$bc_id} = 0;
			}
		    }
		}
		$cur->finish();
	    }
	}
    }

    return;
}


#############################################################################
# evalFuncOnBioCluster_meta (for MER-FS)
#
# func_id: function id
# bc_id: bio cluster
# return: true 1, false 0, unknown -1
#############################################################################
sub evalFuncOnBioCluster_meta {
    my ($dbh, $func_id, $bc_id, $include_myimg) = @_;

    my $gene_oid;

    my $neg = 0;
    if ( $func_id =~ /^\!/ ) {
	$neg = 1;
	$func_id = substr($func_id, 1, length($func_id)-1);
    }

    my ($f1, $f2) = split(/\:/, $func_id);

    if ( $f1 eq 'IPWAY' || $f1 eq 'ITERM' || 
	 $f1 eq 'IPR' || $f1 eq 'TC' ) {
	if ( ! $f2 ) {
	    $f2 = 0;
	}

	if ( $neg ) {
	    return 1;
	}
	else {
	    return 0;
	}
    }
    elsif ( $f1 eq 'ITERM' ) {
	if ( ! $f2 ) {
	    $f2 = 0;
	}

	if ( $neg ) {
	    return 1;
	}
	else {
	    return 0;
	}
    }
    else {
	# other functions
	my $sql = "select taxon from bio_cluster_new where cluster_id = ?";
	my $cur = execSql( $dbh, $sql, $verbose, $bc_id );
	my ($taxon_oid) = $cur->fetchrow();
	$cur->finish();

	if ( $func_id =~ /^COG/ || $func_id =~ /^pfam/ ||
	     $func_id =~ /^TIGR/ || $func_id =~ /^KO/ ||
	     $func_id =~ /^EC/ ) {
	    my %genes = MetaUtil::getTaxonFuncGenes($taxon_oid, 'assembled', $func_id);

	    $sql = "select feature_id from bio_cluster_features_new " .
		"where feature_type = 'gene' and cluster_id = ? ";
	    $cur = execSql( $dbh, $sql, $verbose, $bc_id );
	    for (;;) {
		my ($g2) = $cur->fetchrow();
		last if ! $g2;

		if ( ! $neg && $genes{$g2} ) {
		    $cur->finish();
		    return 1;
		}
	    }
	    $cur->finish();

	    if ( ! $neg ) {
		return 0;
	    }
	    else {
		return 1;
	    }
	}
	elsif ( $f1 eq 'MetaCyc' ) {
	    my $sql = qq{
                select distinct br.ec_number
                from biocyc_reaction_in_pwys brp, biocyc_reaction br
                where brp.in_pwys = ?
                and brp.unique_id = br.unique_id
                }; 
	    my $cur = execSql( $dbh, $sql, $verbose, $f2 );
	    my @ecs = ();
	    for (;;) {
		my ($ec2) = $cur->fetchrow();
		last if ! $ec2;
		push @ecs, ( $ec2 );
	    }
	    $cur->finish();

	    $sql = "select feature_id from bio_cluster_features_new " .
		"where feature_type = 'gene' and cluster_id = ? ";
	    $cur = execSql( $dbh, $sql, $verbose, $bc_id );
	    my @features = ();
	    for (;;) {
		my ($g2) = $cur->fetchrow();
		last if ! $g2;
		push @features, ( $g2 );
	    }
	    $cur->finish();

	    for my $ec2 ( @ecs ) {
		my %genes = MetaUtil::getTaxonFuncGenes($taxon_oid, 'assembled', $ec2);
		for my $g2 (@features) {
		    if ( $genes{$g2} ) {
			return 1;
		    }
		}
	    }
	}
	elsif ( $f1 eq 'KEGG' && isInt($f2) ) {
	    my $sql = qq{
                select distinct rk.ko_terms
                from image_roi roi, image_roi_ko_terms rk
                where roi.pathway = ?
                and roi.roi_id = rk.roi_id
                }; 
	    my $cur = execSql( $dbh, $sql, $verbose, $f2 );
	    my @kos = ();
	    for (;;) {
		my ($ko2) = $cur->fetchrow();
		last if ! $ko2;
		push @kos, ( $ko2 );
	    }
	    $cur->finish();

	    $sql = "select feature_id from bio_cluster_features_new " .
		"where feature_type = 'gene' and cluster_id = ? ";
	    $cur = execSql( $dbh, $sql, $verbose, $bc_id );
	    my @features = ();
	    for (;;) {
		my ($g2) = $cur->fetchrow();
		last if ! $g2;
		push @features, ( $g2 );
	    }
	    $cur->finish();

	    for my $ko2 ( @kos ) {
		my %genes = MetaUtil::getTaxonFuncGenes($taxon_oid, 'assembled', $ko2);
		for my $g2 (@features) {
		    if ( $genes{$g2} ) {
			return 1;
		    }
		}
	    }
	}

	if ( $include_myimg ) {
	    ## no MyIMG for MER-FS genes
	}
    }

    if ( $neg ) {
	return 1;
    }

    return 0;
}


#############################################################################
# showBioClusterEvalResult
#############################################################################
sub showBioClusterEvalResult {
    my $sid = getContactOid();

    printMainForm();

    my $filename = param("filename");
    my $bc_id = param("cluster_id");
    my $taxon_oid = param("taxon_oid");
    my $rule_id = param("rule_id");
    my $include_myimg = param('include_myimg');

    WebUtil::checkFileName($filename);

    print "<h1>Rule Evaluation (Rule $rule_id in $filename)</h1>\n";

    print hiddenVar("filename", $filename);
    print hiddenVar("taxon_oid", $taxon_oid);
    print hiddenVar("rule_id", $rule_id);
    print hiddenVar("include_myimg", $include_myimg);
    print hiddenVar("cluster_id", $bc_id);

    if ( $include_myimg == 1 ) {
	print "<p>Include my own MyIMG annotations\n";
    }
    elsif ( $include_myimg == 2 ) {
	print "<p>Include public MyIMG annotations\n";
    }
    elsif ( $include_myimg >= 3 ) {
	print "<p>Include all MyIMG annotations\n";
    }

    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon_oid");
    my $sql = "select t.taxon_display_name from taxon t where t.taxon_oid = ? " .
	$rclause;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_name) = $cur->fetchrow();
    $cur->finish();
    if ( ! $taxon_name ) {
	#$dbh->disconnect();
	return;
    }

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
    $url .= "&taxon_oid=$taxon_oid";
    print "<h3>" . alink($url, $taxon_name) . "  (Cluster $bc_id) </h3>\n";

    my $fullname = "$workspace_dir/$sid/$RULE_FOLDER/$filename";
    my $rule_type;
    my $rule_def;
    if ( -e $fullname ) {
	# check whether there is already a rule with the same name
	my $res   = newReadFileHandle($fullname);
	while ( my $line = $res->getline() ) {
	    chomp($line);
	    my ($id, $type, $body) = split(/\t/, $line);
	    if ( $id eq $rule_id ) {
		$rule_type = $type;
		$rule_def = $body;
		last;
	    }
	}
	close $res;
    }

    my @conds;
    if ( $rule_type eq 'or' ) {
	@conds = split(/\|/, $rule_def);
    }
    elsif ( $rule_type eq 'and' ) {
	@conds = split(/\,/, $rule_def);
    }

    my $eval_result = 0;
    if ( $rule_type eq 'and' ) {
	$eval_result = 1;
    }

    my $url2 = "$main_cgi?section=WorkspaceRuleSet&page=taxonCondDetail" .
	"&taxon_oid=$taxon_oid&cluster_id=$bc_id";
    if ( $include_myimg ) {
	$url2 .= "&include_myimg=$include_myimg";
    }

    print "<table class='img' border='1'>\n";
    my $j = 0;
    for my $cond1 ( @conds ) {
	my $def1 = printRuleDefinition($cond1);
	my $result = -1;
	print "<tr class='img'>\n";
	if ( $j > 0 ) {
	    print "<td class='img'>$rule_type</td>\n";
	}
	else {
	    print "<td class='img'> </td>\n";
	}

	if ( $rule_type eq 'or' ) {
	    $result = evalOrRuleOnBioCluster($dbh, $cond1, $bc_id, $include_myimg);

	    if ( $result > 0 ) {
		$eval_result = 1;
	    }
	    elsif ( $result < 0 ) {
		if ( $eval_result == 0 ) {
		    $eval_result = -1;
		}
	    }
	}
	elsif ( $rule_type eq 'and' ) {
	    $result = evalAndRuleOnBioCluster($dbh, $cond1, $bc_id, $include_myimg);

	    if ( $result == 0 ) {
		$eval_result = 0;
	    }
	    elsif ( $result < 0 ) {
		if ( $eval_result > 0 ) {
		    $eval_result = -1;
		}
	    }
	}

	my $len = length($cond1);
	if ( $len >= 2 && $cond1 =~ /^\(/ ) {
	    $cond1 = substr($cond1, 1, $len-2);
	}
	print "<td class='img'>$cond1</td>\n";
	print "<td class='img'>$def1</td>\n";
	print "<td class='img'>";
	my $url3 = $url2 . "&cond=" . $cond1;

	if ( $result > 0 ) {
	    print alink($url3, "true");
	}
	elsif ( $result < 0 ) {
	    print alink($url3, "unknown");
	}
	else {
	    print alink($url3, "false");
	}
	print "</td>\n";
	print "</tr>\n";
	$j++;
    }
    print "</table>\n";

    print "<p><b>Evaluation Result: ";
    if ( $eval_result > 0 ) {
	print "true";
    }
    elsif ( $eval_result < 0 ) {
	print "unknown";
    }
    else {
	print "false";
    }
    print "</b>\n";

    print "<p>\n";
    print submit( -name  => "_section_WorkspaceRuleSet_listRuleGenes",
		  -value => "List Genes", 
		  -class => 'meddefbutton' );

    print end_form();
}



1;
