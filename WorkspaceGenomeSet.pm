###########################################################################
# WorkspaceGenomeSet.pm
# $Id: WorkspaceGenomeSet.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
############################################################################
package WorkspaceGenomeSet;

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
use MerFsUtil;
use OracleUtil;
use QueryUtil;
use Workspace;
use WorkspaceUtil;
use WorkspaceQueryUtil;

$| = 1;

my $section              = "WorkspaceGenomeSet";
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
my $new_func_count       = $env->{new_func_count};

my $cog_base_url       = $env->{cog_base_url};
my $pfam_base_url      = $env->{pfam_base_url};
my $tigrfam_base_url   = $env->{tigrfam_base_url};
my $enzyme_base_url    = $env->{enzyme_base_url};
my $kegg_orthology_url = $env->{kegg_orthology_url};

my $mer_data_dir      = $env->{mer_data_dir};
my $taxon_lin_fna_dir = $env->{taxon_lin_fna_dir};
my $cgi_tmp_dir       = $env->{cgi_tmp_dir};
my $cgi_url           = $env->{cgi_url};
my $enable_ani        = $env->{enable_ani};

my $blast_max_genome = $env->{blast_max_genome};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

my $enable_workspace = $env->{enable_workspace};

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

# user's sub folder names
my $GENOME_FOLDER = "genome";
my $FUNC_FOLDER   = "function";

my $max_workspace_view = 10000;
my $max_profile_select = 50;

my $ownerFilesetDelim = "|";
my $ownerFilesetDelim_message = "::::";

#########################################################################
# dispatch
#########################################################################
sub dispatch {
    return if ( !$enable_workspace );
    return if ( !$user_restricted_site );

    my $page = param("page");

    #print "page: $page";

    my $sid = WebUtil::getContactOid();
    return if ( $sid == 0 ||  $sid < 1 || $sid eq '901');

    # check to see user's folder has been created
    Workspace::initialize();

    if ( !$page && paramMatch("wpload") ) {
        $page = "load";
    }
    elsif ( !$page && paramMatch("delete") ) {
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
    elsif ( $page eq "showDetail" ) {
        printGenomeSetDetail();
    }
    elsif ( $page eq "saveGenomeCart"
        || paramMatch("saveGenomeCart") )
    {
        Workspace::saveGenomeCart();
    }
    elsif ( $page eq "showGenomeSetFuncProfile"
        || paramMatch("showGenomeSetFuncProfile") )
    {
        my $profile_type = param('ws_profile_type');
        if ( $profile_type eq 'func_category' ) {
            showGenomeFuncCategoryProfile(1);
        }
        else {
            showGenomeFuncSetProfile(1);
        }
    }
    elsif ( $page eq "showGenomeFuncProfile"
        || paramMatch("showGenomeFuncProfile") )
    {
        my $profile_type = param('ws_profile_type');
        if ( $profile_type eq 'func_category' ) {
            showGenomeFuncCategoryProfile(0);
        }
        else {
            showGenomeFuncSetProfile(0);
        }
    }
    elsif ( $page eq "genomeProfileGeneList"
        || paramMatch("genomeProfileGeneList") )
    {
        timeout( 60 * $merfs_timeout_mins );
        showGenomeProfileGeneList();
    } 
    elsif ( $page eq "showGenomeSetBlast"
        || paramMatch("showGenomeSetBlast") )
    {
        printGenomeBlast(1);
    } 
    elsif ( $page eq "showGenomeSetPairwiseANI"
        || paramMatch("showGenomeSetPairwiseANI") )
    {
        printGenomePairwiseANI(1);
    }
    elsif ( paramMatch("submitFuncProfile") ne ""
        || $page eq "submitFuncProfile" )
    {
        Workspace::submitFuncProfile($GENOME_FOLDER);
    }
    elsif ( paramMatch("submitBlast") ne ""
        || $page eq "submitBlast" )
    {
        submitJob('Blast');
    }
    elsif ( paramMatch("submitPairwiseANI") ne ""
        || $page eq "submitPairwiseANI" )
    {
        submitJob('Pairwise ANI');
    }
    elsif ( paramMatch("submitSaveFuncGene") ne ""
        || $page eq "submitSaveFuncGene" )
    {
        Workspace::submitSaveFuncGene($GENOME_FOLDER);
    }
    else {
        printGenomeSetMainForm();
    }
}

############################################################################
# printGenomeSetMainForm
############################################################################
sub printGenomeSetMainForm {
    my ($text) = @_;

    my $folder = $GENOME_FOLDER;

    my $sid = WebUtil::getContactOid();
    opendir( DIR, "$workspace_dir/$sid/$folder" )
      or webDie("failed to open folder list");
    my @files = readdir(DIR);
    closedir(DIR);

    print "<h1>My Workspace - Genome Sets</h1>";

    print qq{
        <script type="text/javascript" src="$base_url/Workspace.js" >
        </script>
    };

    print $text;

    printMainForm();

    TabHTML::printTabAPILinks("genomesetTab");
    my @tabIndex =
      ( "#genomesettab1", "#genomesettab2", "#genomesettab3",
        "#genomesettab4", "#genomesettab6", "#genomesettab7" );
    my @tabNames =
      ( "Genome Sets", "Import & Export", "Function Profile", "Blast", "Set Creation", "Set Operation" );

    if ( $enable_ani ) {
        splice(@tabIndex, 4, 0, "#genomesettab5");
        splice(@tabNames, 4, 0, "Pairwise ANI");
    }

    TabHTML::printTabDiv( "genomesetTab", \@tabIndex, \@tabNames );

    print "<div id='genomesettab1'>";
    WorkspaceUtil::printShareMainTable( $section_cgi, $section, $workspace_dir,
        $sid, $folder, @files );
    print hiddenVar( "directory", "$folder" );
    print "</div>\n";

    print "<div id='genomesettab2'>";

    # Import/Export
    Workspace::printImportExport($folder);
    print "</div>\n";

    print "<div id='genomesettab3'>";
    print "<h2>Genome Set Function Profile</h2>\n";
    print
"<p>Select no more than $max_profile_select genome sets to generate genome set vs. function profile.\n";
    printHint(
"Limit number of selected genome sets and/or number of functions to avoid timeout."
    );
    Workspace::printUseFunctionsInSet($sid);
    Workspace::printUseAllFunctionTypes();
    HtmlUtil::printMetaDataTypeChoice();

    # submit button
    print "<p>\n";
    print submit(
        -name    => "_section_WorkspaceGenomeSet_showGenomeSetFuncProfile",
        -value   => "Genome Set Function Profile",
        -class   => "meddefbutton",
        -onClick => "return checkSetsIncludingShare('$folder');"
    );

    require WorkspaceJob;
    my ($genomeFuncSets_ref, $genomeBlastSets_ref, $genomePairwiseANISets_ref, $geneFuncSets_ref, 
        $scafFuncSets_ref, $scafHistSets_ref, $scafKmerSets_ref, $scafPhyloSets_ref, $funcScafSearchSets_ref, 
        $genonmeSaveFuncGeneSets_ref, $geneSaveFuncGeneSets_ref, $scafSaveFuncGeneSets_ref)
        = WorkspaceJob::getExistingJobSets();
    
    Workspace::printSubmitComputation( $sid, $folder, 'func_profile', 
        '_section_WorkspaceGenomeSet_submitFuncProfile', '', $genomeFuncSets_ref );

    print "</div>\n";

    print "<div id='genomesettab4'>";
    require FindGenesBlast;
    FindGenesBlast::printGeneSearchBlastForm('', 1, "_section_WorkspaceGenomeSet_showGenomeSetBlast", "return checkSetsIncludingShare('$folder');");
    Workspace::printSubmitComputation( $sid, $folder, 'blast', 
        '_section_WorkspaceGenomeSet_submitBlast', '', $genomeBlastSets_ref );
    print "</div>\n";

    if ( $enable_ani ) {
        print "<div id='genomesettab5'>";
        print "<h2>Pairwise ANI</h2>\n";
        require ANI;
        my $max_pairwise = ANI::getMaxPairwise();
        print qq{
            <p>
            You may analyze 2 selected genome sets for Pairwise ANI.<br/>
            Please use message system if the selected genome set has over $max_pairwise genomes.<br/>
            <input type='checkbox' name='reverseSets' />\n
            Reverse the order of 2 selected genome sets<br/>\n
            </p>
        };
        print submit(
            -name    => "_section_${section}_showGenomeSetPairwiseANI",
            -value   => 'Pairwise ANI',
            -class   => 'lgdefbutton',
            -onClick => "return checkTwoSetsIncludingShare('$folder');"
        );
    
        Workspace::printSubmitComputation( $sid, $folder, 'pairwise_ani', 
            '_section_WorkspaceGenomeSet_submitPairwiseANI', '', $genomePairwiseANISets_ref );
        print "</div>\n";
    }

    print "<div id='genomesettab6'>";
    print "<h2>Genome Set Creation</h2>\n"; 
    WorkspaceUtil::printGenomeListForm();
    my $name = "_section_Workspace_saveGenomeSetCreation";
    WorkspaceUtil::printSaveSelectedGenomeToWorkspace( $name );

    print "</div>\n";

    print "<div id='genomesettab7'>";
    Workspace::printSetOperation( $folder, $sid );
    print "</div>\n";

    TabHTML::printTabDivEnd();

    print end_form();
}

###############################################################################
# printGenomeSetDetail
###############################################################################
sub printGenomeSetDetail {

    my $owner    = param("owner");
    my $filename = param("filename");
    my $folder   = param("folder");

    printMainForm();
    print "<h1>My Workspace - Genome Sets - Individual Genome Set</h1>";
    print "<h2>Set Name: <i>" . escapeHTML($filename) . "</i></h2>\n";

    print hiddenVar( "owner",  $owner ) if ( $owner );
    print hiddenVar( "directory", "$folder" );
    print hiddenVar( "folder",    $folder );
    print hiddenVar( "filename",  $filename );

    if ( ! $owner ) {
        $owner = WebUtil::getContactOid();
    }

    # check filename
    if ( $filename eq "" ) {
        webError("Cannot read file.");
        return;
    }

    WebUtil::checkFileName($filename);

    # this also untaints the name
    $filename = WebUtil::validFileName($filename);
    my $select_id_name = "taxon_filter_oid";

    my %names;
    my @db_ids = ();

    my $row   = 0;
    my $trunc = 0;
    my $res   = newReadFileHandle("$workspace_dir/$owner/$folder/$filename");
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
    TabHTML::printTabAPILinks("genomesetTab");
    my @tabIndex = ( "#genomesettab1", "#genomesettab2", "#genomesettab3", "#genomesettab4" );
    my @tabNames = ( "Genomes", "Save", "Function Profile", "Set Operation" );
    TabHTML::printTabDiv( "genomesetTab", \@tabIndex, \@tabNames );
=cut

    print "<div id='genomesettab1'>";

    my $dbh = dbLogin();

    my %taxons_in_file;
    if ($include_metagenomes) {
        %taxons_in_file = MerFsUtil::getTaxonsInFile($dbh);
    }

    my %taxon_domain_h;
    my %taxon_seqstatus_h;
    if ( scalar(@db_ids) > 0 ) {
        my $db_str = OracleUtil::getNumberIdsInClause( $dbh, @db_ids );                
        my $sql = QueryUtil::getTaxonDataSql($db_str);
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id2, $domain, $seq_status, $name2 ) =
              $cur->fetchrow();
            last if !$id2;
            if ( !$name2 ) {
                $name2 = "hypothetical protein";
            }
            $taxon_domain_h{$id2}    = $domain;
            $taxon_seqstatus_h{$id2} = $seq_status;
            $names{$id2}             = $name2;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $db_str =~ /gtt_num_id/i );
    }

    my $it = new InnerTable( 1, "genomeSet$$", "genomeSet", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Domain", "char asc", "center", "",
"*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses"
    );
    $it->addColSpec( "Status", "char asc", "center", "",
        "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome ID", "char asc", "right" );
    $it->addColSpec( "Genome Name", "char asc", "left" );
    my $sd = $it->getSdDelim();

    my @keys = ( keys %names );

    my $can_select = 0;
    for my $id (@keys) {
        my $r;
        my $url;

        if ( $names{$id} ) {
            $can_select++;
            $r = $sd
              . "<input type='checkbox' name='$select_id_name' value='$id' checked/> \t"
              . $taxon_domain_h{$id}
              . $sd
              . substr( $taxon_domain_h{$id}, 0, 1 ) . "\t"
              . $taxon_seqstatus_h{$id}
              . $sd
              . substr( $taxon_seqstatus_h{$id}, 0, 1 ) . "\t";

            $r .= $id . $sd . $id . "\t";
            # determine URL
            if ( $taxons_in_file{$id} ) {
                $url =
                    "$main_cgi?section=MetaDetail"
                  . "&page=metaDetail&taxon_oid=$id";
            }
            else {
                $url =
                    "$main_cgi?section=TaxonDetail"
                  . "&page=taxonDetail&taxon_oid=$id";
            }

            if ($url) {
                $r .= $names{$id} . $sd . alink( $url, $names{$id} ) . "\t";
            }
            else {
                $r .= $names{$id} . $sd . $names{$id} . "\t";
            }
        }
        else {

            # not in database
            $r = $sd . "\t\t\t\t" . "(not in this database)" . $sd . $id . "\t";
        }

        $it->addRow($r);
    }

    if ( $row > 10 ) {
        WebUtil::printGenomeCartFooter();
    }

    $it->printOuterTable(1);

    my $load_msg = "Loaded $row";
    if ( $can_select <= 0 ) {
        $load_msg .= "; none in this database.";
    }
    elsif ( $can_select < $row ) {
        $load_msg .= "; only $can_select selectable.";
    }
    else {
        $load_msg .= ".";
    }
    if ($trunc) {
        $load_msg .= " (additional rows truncated)";
    }

    WebUtil::printGenomeCartFooter();

    printStatusLine( $load_msg, 2 );
    if ( $can_select <= 0 ) {
        print "</div>\n";
        print end_form();
        return;
    }

    print "</div>\n";

    print "<div id='genomesettab2'>";
    WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    print "</div>\n";

=pod
    print "<div id='geomnesettab3'>";
    print "<h2>Genome Function Profile</h2>\n";
    print
"<p>Select no more than $max_profile_select genomes to generate genome vs. function profile.\n";
    printHint(
"Limit number of selected genomes and/or number of functions to avoid timeout."
    );
    Workspace::printUseFunctionsInSet($sid);
    Workspace::printUseAllFunctionTypes();

    # submit button
    print "<p>\n";
    print submit(
        -name  => "_section_WorkspaceGenomeSet_showGenomeFuncProfile",
        -value => "Run Function Profile",
        -class => "medbutton "
    );
    print "</div>\n";

    print "<div id='genomesettab4'>";
    Workspace::printSetOpSection( $filename, $folder );
    print "</div>\n";

    TabHTML::printTabDivEnd();
=cut

    print end_form();
}

#############################################################################
# showGenomeFuncCategoryProfile - show genome function profile 
#                                 for selected function category
#############################################################################
sub showGenomeFuncCategoryProfile {
    my ($isSet) = @_;

    my $sid = WebUtil::getContactOid();

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    my $dbh = dbLogin();

    my $folder = param("directory");
    #print "folder $folder<br/>\n";
    print hiddenVar( "directory", "$folder" );

    my $functype = param('functype');
    #print "functype $functype<br/>\n";
    if ( $functype eq "" ) {
        webError("Please select a function type.\n");
        return;
    }

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);

    # taxons
    my $fileFullname = param('filename');
    #print "fileFullname $fileFullname<br/>\n";
    my @taxon_oids = param('taxon_oid');
    for my $y (@taxon_oids) {
        print hiddenVar( "taxon_oid", $y );
    }
    #print "taxon_oids @taxon_oids<br/>\n";

    my $data_type = param('data_type');
    print hiddenVar( "data_type", $data_type ) if ($data_type);

    if ($isSet) {
        validateGenomeSelection( $isSet, @all_files );
        print "<h1>Genome Set Function Profile ($functype)</h1>\n";
        print "<p>";
        print "Profile is based on genome set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected Genome Set(s): ";
    	WorkspaceUtil::printShareSetName($dbh, $sid, @all_files);
        print "<br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }
    else {
        # individual genomes
        validateGenomeSelection( $isSet, @taxon_oids );
        print "<h1>Genome Function Profile ($functype)</h1>\n";
        print
"<p>Profile is based on individual genomes in genome set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected Genome(s): <i>@taxon_oids</i><br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }

    timeout( 60 * $merfs_timeout_mins );
    my $start_time  = time();
    my $timeout_msg = "";

    if ( $sid == 312 || $sid == 100546 ) {
        print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }

    printStartWorkingDiv();

    print "Retriving function names ... <br/>\n";
    my %func_names = QueryUtil::getFuncTypeNames($dbh, $functype);
    my @func_ids   = sort ( keys %func_names );
    if ( scalar(@func_ids) == 0 ) {
        printEndWorkingDiv();
        webError("Incorrect function type.\n");
        return;
    }

    print "<p>Computing genome function count ...\n";
    my %taxonOrset_cnt_h;
    if ($isSet) {
        # genome sets
        for my $x2 (@all_files) { 
            my ($c_id, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 ); 
            my $fullname     = "$workspace_dir/$c_id/$folder/$x";
            my %func2count_h =
              getGenomeFuncCateCount( $dbh, $functype, $fullname, "", $data_type );
            $taxonOrset_cnt_h{$x2} = \%func2count_h;
            print ".";
        }
    }
    else {
        # taxons
        for my $taxon_oid (@taxon_oids) {
            my %func2count_h =
              getGenomeFuncCateCount( $dbh, $functype, $fileFullname, $taxon_oid, $data_type );
            $taxonOrset_cnt_h{$taxon_oid} = \%func2count_h;
            print ".";
        }
    }
    print "<p>\n";

    my $total_cnt = 0;
    my %funcId2taxonOrset2cnt_h;
    for my $func_id (@func_ids) {
        my $select_id = $func_id;
        if ( Workspace::isComplicatedFuncCategory($functype) ) {
            $select_id = $functype . ":" . $func_id;
        }

        if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 )
        {
            $timeout_msg =
                "Process takes too long to run "
              . "-- stopped at $func_id. "
              . "Only partial result is displayed.";
            last;
        }

        print "Processing $func_id ... <br/>\n";
        my %taxonOrset2cnt_h;
        if ($isSet) {
            # genome sets
    	    for my $x2 (@all_files) { 
        		my ($c_id, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 ); 
                my $cnt = 0;
                my $func_cnt_href = $taxonOrset_cnt_h{$x2};
                if ($func_cnt_href) {
                    $cnt = $func_cnt_href->{$func_id};
                }
                else {
                    #should not be used
                    my $fullname = "$workspace_dir/$c_id/$folder/$x";
                    $cnt = getGenomeFuncCount( $dbh, $func_id, $fullname, "", $data_type );
                }
                $taxonOrset2cnt_h{$x2} = $cnt;
                $total_cnt += $cnt;
            }
        }
        else {

            # taxons
            for my $taxon_oid (@taxon_oids) {
                my $cnt = 0;
                my $func_cnt_href = $taxonOrset_cnt_h{$taxon_oid};
                if ($func_cnt_href) {
                    $cnt = $func_cnt_href->{$func_id};
                }
                else {
                    #should not be used
                    $cnt = getGenomeFuncCount( $dbh, $func_id, $fileFullname, $taxon_oid, $data_type );
                }
                $taxonOrset2cnt_h{$taxon_oid} = $cnt;
                $total_cnt += $cnt;
            }    # end for my taxon_oid
        }
        $funcId2taxonOrset2cnt_h{$func_id} = \%taxonOrset2cnt_h;
    }

    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 100546 ) {
        print "<p>*** end time: " . currDateTime() . "<br/>\n";
    }

    if ( !$total_cnt ) {
        print "<p><b>No genes are associated with selected function type.</b>\n";
        print end_form();
        return;
    }

    if ($timeout_msg) {
        printMessage("<font color='red'>Warning: $timeout_msg</font>");
    }

    my $it = new InnerTable( 1, "WSFuncSetProfile$$", "WSSetFuncProfile", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    if ( Workspace::isComplicatedFuncCategory($functype) ) {
    	# not allow selection
    }
    else {
    	$it->addColSpec("Selection");
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
        if ( scalar(@taxon_oids) > 0 ) {
            my %taxon_name_h = QueryUtil::fetchTaxonOid2NameHash( $dbh, \@taxon_oids );
            for my $taxon_oid (@taxon_oids) {
                my $taxon_name = $taxon_name_h{$taxon_oid};
                $it->addColSpec( "$taxon_oid", "number asc", "right", "",
                    $taxon_name );
            }
        }
    }

    my $total_cnt = 0;
    my $row_cnt = 0;
    for my $func_id (@func_ids) {
    	my $select_id = $func_id;
        if ( Workspace::isComplicatedFuncCategory($functype) ) {
    	    $select_id = $functype . ":" . $func_id;
    	}

        my $r;

        if ( Workspace::isComplicatedFuncCategory($functype) ) {
            # not allow selection
        }
        else {
            $r = $sd
            . "<input type='checkbox' name='func_id' value='$select_id' /> \t";
        }
        $r .= $func_id . $sd . $func_id . "\t";
        $r .=
            $func_names{$func_id} . $sd
          . $func_names{$func_id} . "\t";

        my $taxonOrset2cnt_href = $funcId2taxonOrset2cnt_h{$func_id};
        if ($isSet) {
            # genome sets
            for my $x2 (@all_files) {
                my $cnt = $taxonOrset2cnt_href->{$x2};
                if ($cnt) {
                    my $url =
                        "$section_cgi&page=genomeProfileGeneList&directory=$folder"
                      . "&input_file=$x2&func_id=$select_id";
                    $url .= "&data_type=$data_type" if ( $data_type );
                    $url = alink( $url, $cnt );
                    $r .= $cnt . $sd . $url . "\t";
        		}
                else {
        			$r .= "0" . $sd . "0" . "\t";
        		}
            }
        }
        else {
            for my $taxon_oid (@taxon_oids) {
                my $cnt = $taxonOrset2cnt_href->{$taxon_oid};
                if ($cnt) {
                    my $url =
                        "$section_cgi&page=genomeProfileGeneList&directory=$folder"
                      . "&taxon_oid=$taxon_oid"
                      . "&input_file=$fileFullname&func_id=$select_id";
                    $url .= "&data_type=$data_type" if ( $data_type );
                    $url = alink( $url, $cnt );
                    $r .= $cnt . $sd . $url . "\t";
                }
                else {
                    $r .= "0" . $sd . "0\t";
                }
            }    # end for my taxon_oid
        }
        $it->addRow($r);
        $row_cnt++;
    }

    if ( Workspace::isSimpleFuncType($functype) && $row_cnt > 10 ) {
        WebUtil::printFuncCartFooter();
    }
    $it->printOuterTable(1);
    if ( Workspace::isSimpleFuncType($functype) ) {
        WebUtil::printFuncCartFooter();
		WorkspaceUtil::printFuncGeneSaveToWorkspace( $GENOME_FOLDER, $isSet );
    }

    printStatusLine( "$row_cnt loaded", 2 );
    print end_form();
}

#############################################################################
# validateGenomeSelection
#############################################################################
sub validateGenomeSelection {
    my ( $isSet, @genomeCols ) = @_;

    my $genomeDescription;
    if ( $isSet ) {
        $genomeDescription = "genome sets";
    }
    else {
        $genomeDescription = "genomes";            
    }
    if ( scalar( @genomeCols ) == 0 ) {
        webError("No $genomeDescription are selected.");
        return;
    }
    if ( scalar( @genomeCols ) > $max_profile_select ) {
        webError("Please limit your selection of $genomeDescription to no more than $max_profile_select.\n");
        return;
    }

}

#############################################################################
# showGenomeFuncSetProfile - show genome function profile for selected files
#                       and function set
#############################################################################
sub showGenomeFuncSetProfile {
    my ($isSet) = @_;

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $dbh = dbLogin();
    my $sid = WebUtil::getContactOid();

    my $folder = param("directory");
    #print "folder $folder<br/>\n";
    print hiddenVar( "directory", "$folder" );

    my $func_set_name = param('func_set_name');
    #print "func_set_name $func_set_name<br/>\n";
    if ( ! $func_set_name ) {
        webError("Please select a function set.\n");
        return;
    }
    my ( $func_set_owner, $func_set ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $func_set_name, $ownerFilesetDelim, $FUNC_FOLDER );
    my $share_func_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $func_set_owner, $func_set, $sid );

    # read all function ids in the function set
    WebUtil::checkFileName($func_set);
    # this also untaints the name
    my $func_filename = WebUtil::validFileName($func_set);

    my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);

    # taxons
    my $fileFullname = param('filename');
    #print "fileFullname $fileFullname<br/>\n";
    my @taxon_oids = param('taxon_oid');
    for my $y (@taxon_oids) {
        print hiddenVar( "taxon_oid", $y );
    }
    #print "taxon_oids @taxon_oids<br/>\n";

    my $data_type = param('data_type');
    print hiddenVar( "data_type", $data_type ) if ($data_type);

    if ($isSet) {
        validateGenomeSelection( $isSet, @all_files );
        print "<h1>Genome Set Function Profile ($share_func_set_name)</h1>\n";
        print
"<p>Profile is based on genome set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected genome set(s): ";
	    WorkspaceUtil::printShareSetName($dbh, $sid, @all_files);
        print "<br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }
    else {
        # individual genomes
        validateGenomeSelection( $isSet, @taxon_oids );
        print "<h1>Genome Function Profile ($share_func_set_name)</h1>\n";
        print
"<p>Profile is based on individual genomes in genome set(s).  Counts in the data table are gene counts.<br/>\n";
        print "Selected genome(s): <i>@taxon_oids</i><br/>\n";
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
        print "</p>";
    }

    timeout( 60 * $merfs_timeout_mins );
    my $start_time  = time();
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

    my %taxonOrset_cnt_h;
    my @func_groups = QueryUtil::groupFuncIdsIntoOneArray( \@func_ids );
    foreach my $func_ids_ref (@func_groups) {
        if ($isSet) {
            # genome sets
            for my $x2 (@all_files) { 
                print "Computing genome set $x2 function counts ... <br/>\n";
                my($c_id, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 ); 
                my $fullname = "$workspace_dir/$c_id/$folder/$x";
                my %func2count_h = getGenomeFuncSetCount( $dbh, $func_ids_ref, $fullname, '', $data_type );
                my $taxonOrset_func2count_href = $taxonOrset_cnt_h{$x2};
                if ( $taxonOrset_func2count_href ) {
                    foreach my $func_id ( keys %func2count_h ) {
                        $taxonOrset_func2count_href->{$func_id} = $func2count_h{$func_id};
                    }
                }
                else {
                    $taxonOrset_cnt_h{$x2} = \%func2count_h;                    
                }
            }
        }
        else {
            # taxons
            for my $taxon_oid (@taxon_oids) {
                print "Computing $taxon_oid function counts ... <br/>\n";
                my %func2count_h = getGenomeFuncSetCount( $dbh, $func_ids_ref, $fileFullname, $taxon_oid, $data_type );
                my $taxonOrset_func2count_href = $taxonOrset_cnt_h{$taxon_oid};
                if ( $taxonOrset_func2count_href ) {
                    foreach my $func_id ( keys %func2count_h ) {
                        $taxonOrset_func2count_href->{$func_id} = $func2count_h{$func_id};
                    }
                }
                else {
                    $taxonOrset_cnt_h{$taxon_oid} = \%func2count_h;                    
                }
            }
        }        
    }
    #print "showGenomeFuncSetProfile() taxonOrset_cnt_h: <br/>\n";
    #print Dumper(\%taxonOrset_cnt_h);
    #print "<br/>\n";
    
    my $total_cnt = 0;
    my %funcId2taxonOrset2cnt_h;    
    for my $func_id (@func_ids) {
        if ( ( ( $merfs_timeout_mins * 60 ) - ( time() - $start_time ) ) < 200 )
        {
            $timeout_msg =
                "Process takes too long to run "
              . "-- stopped at $func_id. "
              . "Only partial result is displayed.";
            last;
        }

        print "Processing $func_id ... <br/>\n";
        my %taxonOrset2cnt_h;
        if ($isSet) {
    	    for my $x2 (@all_files) { 
        		my($c_id, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );

                my $cnt = 0;
                my $func_cnt_href = $taxonOrset_cnt_h{$x2};
                if ($func_cnt_href) {
                    $cnt = $func_cnt_href->{$func_id};
                }
                #else {
                #    #should not be used
                #    my $fullname = "$workspace_dir/$c_id/$folder/$x";
                #    $cnt = getGenomeFuncCount( $dbh, $func_id, $fullname, "", $data_type );
                #}
                $taxonOrset2cnt_h{$x2} = $cnt;
                $total_cnt += $cnt;
            }    # end for x2
        }
        else {    
            for my $taxon_oid (@taxon_oids) {
                my $cnt = 0;
                my $func_cnt_href = $taxonOrset_cnt_h{$taxon_oid};
                if ($func_cnt_href) {
                    $cnt = $func_cnt_href->{$func_id};
                }
                #else {
                #    #should not be used
                #    $cnt = getGenomeFuncCount( $dbh, $func_id, $fileFullname, $taxon_oid, $data_type );
                #}
                $taxonOrset2cnt_h{$taxon_oid} = $cnt;
                $total_cnt += $cnt;
            }    # end for taxon_oid
        }
        $funcId2taxonOrset2cnt_h{$func_id} = \%taxonOrset2cnt_h;
    }
    #print "showGenomeFuncSetProfile() funcId2taxonOrset2cnt_h: <br/>\n";
    #print Dumper(\%funcId2taxonOrset2cnt_h);
    #print "<br/>\n";

    printEndWorkingDiv();

    if ( $sid == 312 || $sid == 100546 ) {
        print "<p>*** end time: " . currDateTime() . "<br/>\n";
    }

    if ( !$total_cnt ) {
        print "<p><b>No genes are associated with selected function set.</b>\n";
        print end_form();
        return;
    }

    if ($timeout_msg) {
        printMessage("<font color='red'>Warning: $timeout_msg</font>");
    }

    my $it =
      new InnerTable( 1, "WSGenomeSetProfile$$", "WSGenomeSetProfile", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Selection");
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
        if ( scalar(@taxon_oids) > 0 ) {
            my %taxon_name_h = QueryUtil::fetchTaxonOid2NameHash( $dbh, \@taxon_oids );
            for my $taxon_oid (@taxon_oids) {
                my $taxon_name = $taxon_name_h{$taxon_oid};
                $it->addColSpec( "$taxon_oid", "number asc", "right", "",
                    $taxon_name );
            }
        }
    }

    my $row_cnt = 0;
    for my $func_id (@func_ids) {

        my $r =
          $sd . "<input type='checkbox' name='func_id' value='$func_id' /> \t";
        $r .= $func_id . $sd . $func_id . "\t";
        $r .= $func_names{$func_id} . $sd . $func_names{$func_id} . "\t";

        my $taxonOrset2cnt_href = $funcId2taxonOrset2cnt_h{$func_id};
        if ($isSet) {
            for my $x2 (@all_files) {
                my $cnt = $taxonOrset2cnt_href->{$x2};
                if ($cnt) {
                    my $url =
                        "$section_cgi&page=genomeProfileGeneList&directory=$folder"
                      . "&input_file=$x2&func_id=$func_id";
                    $url .= "&data_type=$data_type" if ( $data_type );
                    $url = alink( $url, $cnt );
                    $r .= $cnt . $sd . $url . "\t";
                }
                else {
                    $r .= "0" . $sd . "0\t";
                }
            }    # end for x2
        }
        else {
            for my $taxon_oid (@taxon_oids) {
                my $cnt = $taxonOrset2cnt_href->{$taxon_oid};
                if ($cnt) {
                    my $url =
                        "$section_cgi&page=genomeProfileGeneList&directory=$folder"
                      . "&taxon_oid=$taxon_oid"
                      . "&input_file=$fileFullname&func_id=$func_id";
                    $url .= "&data_type=$data_type" if ( $data_type );
                    $url = alink( $url, $cnt );
                    $r .= $cnt . $sd . $url . "\t";
                }
                else {
                    $r .= "0" . $sd . "0\t";
                }
            }    # end for taxon_oid
        }

        $it->addRow($r);
        $row_cnt++;
    }    # end for my func_id

    WebUtil::printFuncCartFooter() if ( $row_cnt > 10 );
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();
    WorkspaceUtil::printFuncGeneSaveToWorkspace( $GENOME_FOLDER, $isSet );

    require WorkspaceJob;
    my ($genomeFuncSets_ref, $genomeBlastSets_ref, $genomePairwiseANISets_ref, $geneFuncSets_ref, 
        $scafFuncSets_ref, $scafHistSets_ref, $scafKmerSets_ref, $scafPhyloSets_ref, $funcScafSearchSets_ref, 
        $genomeSaveFuncGeneSets_ref, $geneSaveFuncGeneSets_ref, $scafSaveFuncGeneSets_ref)
        = WorkspaceJob::getExistingJobSets();
    
    Workspace::printSubmitComputation( $sid, $folder, 'save_func_gene', 
        '_section_WorkspaceGenomeSet_submitSaveFuncGene', '', $genomeSaveFuncGeneSets_ref );

    printStatusLine( "$row_cnt loaded", 2 );
    print end_form();
}

##############################################################################
# findDbAndMetaTaxons
##############################################################################
sub findDbAndMetaTaxons {
    my ( $dbh, $input_file, $input_taxon ) = @_;

    my @db_taxons;
    my @file_taxons;
    
    if ( $input_taxon ) {
        # only this taxon
        my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $input_taxon );
        if ( $isTaxonInFile ) {
            @file_taxons = ($input_taxon);
        }
        else {
            @db_taxons = ($input_taxon);
        }
        return ( \@db_taxons, \@file_taxons );
        
    }
    else {
        # from file
        my @taxons;
        open( FH, "$input_file" )
          or webError("File size - file error $input_file");
        while ( my $line = <FH> ) {
            chomp($line);
            push(@taxons, $line);
        }
        close FH;

        my ( $db_taxons_ref, $file_taxons_ref ) 
            = MerFsUtil::findTaxonsInFile($dbh, @taxons);
        #print "findDbAndMetaTaxons() db_taxons_ref=@$db_taxons_ref, file_taxons_ref=@$file_taxons_ref<br/>\n";
        return ( $db_taxons_ref, $file_taxons_ref );
    }

    return ( \@db_taxons, \@file_taxons );
}

##############################################################################
# getGenomeFuncCount - get gene counts in genome with func_id
#
# input_file: read taxon oids from this file
# input_taxon: only this taxon
##############################################################################
sub getGenomeFuncCount {
    my ( $dbh, $func_id, $input_file, $input_taxon, $data_type ) = @_;

    ## get MER-FS taxons
    my ($db_taxons_ref, $file_taxons_ref) 
        = findDbAndMetaTaxons( $dbh, $input_file, $input_taxon );

    my $gene_count = 0;

    # database
    if ( scalar(@$db_taxons_ref) > 0 ) {
        my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_taxons_ref );
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my ( $sql, @bindList ) = WorkspaceQueryUtil::getDbTaxonFuncGeneCountSql(
            $func_id, $taxon_str, $rclause, $imgClause );
        if ( $sql ) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            my ($cnt1) = $cur->fetchrow();
            $gene_count += $cnt1;
            $cur->finish();
        }
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $taxon_str =~ /gtt_num_id/i );        
    }

    # file
    if ( scalar(@$file_taxons_ref) > 0 ) {
        if ($new_func_count) {
            my $c_table_name = "taxon_cog_count";
            if ( $func_id =~ /pfam/i ) {
                $c_table_name = "taxon_pfam_count";
            }
            elsif ( $func_id =~ /TIGR/i ) {
                $c_table_name = "taxon_tigr_count";
            }
            elsif ( $func_id =~ /EC\:/i ) {
                $c_table_name = "taxon_ec_count";
            }
            elsif ( $func_id =~ /KO\:/i ) {
                $c_table_name = "taxon_ko_count";
            }

            my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$file_taxons_ref );

            my $datatypeClause;
            my @binds;
            if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
                $datatypeClause = "and data_type = ? ";
                push(@binds, $data_type);
            }
            
            my $sql2 = qq{
                select taxon_oid, data_type, gene_count 
                from $c_table_name
                where taxon_oid in ( $taxon_str )
                and func_id = ?
                $datatypeClause
            };
            my $cur2 = execSql( $dbh, $sql2, $verbose, $func_id, @binds );
            for ( ; ; ) {
                my ( $t2, $d2, $cnt2 ) = $cur2->fetchrow();
                last if !$t2;
                $gene_count += $cnt2;
            }
            $cur2->finish();
            OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
                if ( $taxon_str =~ /gtt_num_id/i );        
        }
        else {
            my @type_list = MetaUtil::getDataTypeList($data_type);
            for my $taxon_oid (@$file_taxons_ref) {
                for my $t2 ( @type_list ) {
                    my $cnt2 = MetaUtil::getTaxonOneFuncCnt( $taxon_oid, $t2, $func_id );
                    $gene_count += $cnt2;
                }
            }
        }
    }

    return $gene_count;
}

##############################################################################
# getGenomeFuncSetCount - get gene counts in genome with func_id
#
# input_file: read taxon oids from this file
# input_taxon: only this taxon
##############################################################################
sub getGenomeFuncSetCount {
    my ( $dbh, $func_ids_ref, $input_file, $input_taxon, $data_type ) = @_;

    my @func_ids = @$func_ids_ref;
    
    ## get MER-FS taxons
    my ($db_taxons_ref, $file_taxons_ref) 
        = findDbAndMetaTaxons( $dbh, $input_file, $input_taxon );

    my %func_count;
    my $func_id = $func_ids[0];
    
    # database
    if ( scalar(@$db_taxons_ref) > 0 ) {
        my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_taxons_ref );
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my ( $sql, @bindList ) = WorkspaceQueryUtil::getDbTaxonFuncsGeneCountSql(
            $dbh, \@func_ids, $taxon_str, $rclause, $imgClause );
        #print "getGenomeFuncSetCount() db sql=$sql, bindList=@bindList<br/>\n";
        if ( $sql ) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $func, $cnt1 ) = $cur->fetchrow();
                last if !$func;

                $func = WorkspaceQueryUtil::addBackFuncIdPrefix( $func_id, $func );
                if ( $func_count{$func} ) {
                    $func_count{$func} += $cnt1;
                }
                else {
                    $func_count{$func} = $cnt1;
                }
            }
            $cur->finish();
        }
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $taxon_str =~ /gtt_num_id/i );        
    }

    # file
    if ( scalar(@$file_taxons_ref) > 0 ) {
        if ($new_func_count 
        && ( $func_id =~ /COG/i || $func_id =~ /pfam/i || $func_id =~ /TIGR/i 
            || $func_id =~ /EC\:/i || $func_id =~ /KO\:/i || $func_id =~ /MetaCyc\:/i ) ) {
            my $c_table_name;
            my ( $metacyc2ec_href, $ec2metacyc_href );
            if ( $func_id =~ /COG/i ) {
                $c_table_name = "taxon_cog_count";                
            }
            elsif ( $func_id =~ /pfam/i ) {
                $c_table_name = "taxon_pfam_count";
            }
            elsif ( $func_id =~ /TIGR/i ) {
                $c_table_name = "taxon_tigr_count";
            }
            elsif ( $func_id =~ /EC\:/i ) {
                $c_table_name = "taxon_ec_count";
            }
            elsif ( $func_id =~ /KO\:/i ) {
                $c_table_name = "taxon_ko_count";
            }
            elsif ( $func_id =~ /MetaCyc\:/i ) {
                ( $metacyc2ec_href, $ec2metacyc_href ) = QueryUtil::fetchMetaCyc2EcHash( $dbh, \@func_ids );
                my @ec_ids = keys %$ec2metacyc_href;
                @func_ids = @ec_ids;
                $c_table_name = "taxon_ec_count";
            }
            
            if ( $c_table_name ) {
                my $func_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @func_ids ); 
                my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$file_taxons_ref );
    
                my $datatypeClause;
                my @binds;
                if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
                    $datatypeClause = "and data_type = ? ";
                    push(@binds, $data_type);
                }
                
                my $sql2 = qq{
                    select func_id, sum(gene_count) 
                    from $c_table_name
                    where taxon_oid in ( $taxon_str )
                    and func_id in ( $func_ids_str )
                    $datatypeClause
                    group by func_id
                };
                #print "getGenomeFuncSetCount() meta sql2=$sql2, binds=@binds<br/>\n";
                my $cur2 = execSql( $dbh, $sql2, $verbose, @binds );
                for ( ; ; ) {
                    my ( $func2, $cnt2 ) = $cur2->fetchrow();
                    last if !$func2;
    
                    my @func2s;
                    if ( $func_id =~ /MetaCyc/i ) {
                        my $metacyc_ids_ref = $ec2metacyc_href->{$func2};
                        @func2s = @$metacyc_ids_ref;
                    }
                    else {
                        @func2s = ( $func2 );
                    }

                    foreach my $func ( @func2s ) {
                        $func = WorkspaceQueryUtil::addBackFuncIdPrefix( $func_id, $func );
                        if ( $func_count{$func} ) {
                            $func_count{$func} += $cnt2;
                        }
                        else {
                            $func_count{$func} = $cnt2;
                        }                        
                    }
                }
                $cur2->finish();
                OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
                    if ( $taxon_str =~ /gtt_num_id/i );        
                OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
                    if ( $func_ids_str =~ /gtt_func_id/i );                 
            }

        }
        else {
            my @type_list = MetaUtil::getDataTypeList($data_type);
            for my $taxon_oid (@$file_taxons_ref) {
                for my $t2 ( @type_list ) {
                    my %func_h2 = MetaUtil::getTaxonFuncsCnt( $taxon_oid, $t2, \@func_ids );;
                    for my $func2 ( keys %func_h2 ) {
                        my $cnt2 = $func_h2{$func2};
                        $func2 = WorkspaceQueryUtil::addBackFuncIdPrefix( $func_id, $func2 );
                        if ( $func_count{$func2} ) {
                            $func_count{$func2} += $cnt2;
                        }
                        else {
                            $func_count{$func2} = $cnt2;
                        }
                    }
                }
            }
        }
    }
    #print "getGenomeFuncSetCount() func_count <br/>\n";
    #print Dumper(\%func_count);
    #print "<br/>\n";

    return %func_count;
}

##############################################################################
# getGenomeFuncCateCount - get gene counts in genome with function category
#
# input_file: read taxon oids from this file
# input_taxon: only this taxon
##############################################################################
sub getGenomeFuncCateCount {
    my ( $dbh, $functype, $input_file, $input_taxon, $data_type ) = @_;

    #print "<p>getGenomeFuncCateCount: $functype, $input_file, $input_taxon, $data_type\n";

    my ($db_taxons_ref, $file_taxons_ref) 
        = findDbAndMetaTaxons( $dbh, $input_file, $input_taxon );

    my %func_count;

    my $c_table_name  = "taxon_cog_count";
    my $mv_table_name = "mv_taxon_cog_stat";
    my $mv_attr_name  = "cog";
    if ( lc($functype) eq 'pfam' ) {
        $c_table_name  = "taxon_pfam_count";
        $mv_table_name = "mv_taxon_pfam_stat";
        $mv_attr_name  = "pfam_family";
    }
    elsif ( lc($functype) eq 'tigr' || lc($functype) eq 'tigrfam' ) {
        $c_table_name  = "taxon_tigr_count";
        $mv_table_name = "mv_taxon_tfam_stat";
        $mv_attr_name  = "ext_accession";
    }
    elsif (lc($functype) eq 'ec'
        || lc($functype) eq 'enzyme'
        || lc($functype) eq 'enzymes' )
    {
        $c_table_name  = "taxon_ec_count";
        $mv_table_name = "mv_taxon_ec_stat";
        $mv_attr_name  = "enzyme";
    }
    elsif ( lc($functype) eq 'ko' ) {
        $c_table_name  = "taxon_ko_count";
        $mv_table_name = "mv_taxon_ko_stat";
        $mv_attr_name  = "ko_term";
    }

    # database
    if ( scalar(@$db_taxons_ref) > 0 ) {

        my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_taxons_ref );
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my $sql2 = qq{
            select $mv_attr_name, sum(gene_count)
            from $mv_table_name
            where taxon_oid in ( $taxon_str )
            group by $mv_attr_name
        };

        if ( lc($functype) eq 'cog_category' ) {
            $sql2 = qq{
                select cfs.functions, count(distinct gcg.gene_oid)
                from cog_functions cfs, gene_cog_groups gcg
                where gcg.taxon in ( $taxon_str )
                and cfs.cog_id = gcg.cog
                group by cfs.functions
            };
        }
        elsif ( lc($functype) eq 'cog_pathway' ) {
            $sql2 = qq{
                select cpcm.cog_pathway_oid, count(distinct gcg.gene_oid)
                from cog_pathway_cog_members cpcm, gene_cog_groups gcg
                where gcg.taxon in ( $taxon_str )
                and cpcm.cog_members = gcg.cog
                group by cpcm.cog_pathway_oid
            };
        }
        elsif ( lc($functype) eq 'pfam_category' ) {
            $sql2 = qq{
                select pfc.functions, count(distinct gpf.gene_oid)
                from pfam_family_cogs pfc, gene_pfam_families gpf
                where gpf.taxon in ( $taxon_str )
                and pfc.ext_accession = gpf.pfam_family
                group by pfc.functions
            };
        }
        elsif ( lc($functype) eq 'tigrfam_role' ) {
            $sql2 = qq{
                select tr.roles, count(distinct gt.gene_oid)
                from tigrfam_roles tr, gene_tigrfams gt
                where gt.taxon in ( $taxon_str )
                and tr.ext_accession = gt.ext_accession
                group by tr.roles
            };
        }
        elsif ( lc($functype) eq 'kegg_category_ec' ) {
            $sql2 = qq{
                select kp.category, count(distinct gke.gene_oid),
                       min(kp.pathway_oid)
                from gene_ko_enzymes gke, ko_term_enzymes kt, image_roi_ko_terms rk, 
                    image_roi ir, kegg_pathway kp
                where gke.taxon in ( $taxon_str )
                and gke.enzymes = kt.enzymes
                and kt.ko_id = rk.ko_terms
                and rk.roi_id = ir.roi_id
                and ir.pathway = kp.pathway_oid
                group by kp.category
            };
        }
        elsif ( lc($functype) eq 'kegg_category_ko' ) {
            $sql2 = qq{
                select kp.category, count(distinct gk.gene_oid),
                       min(kp.pathway_oid)
                from image_roi ir, image_roi_ko_terms rk, gene_ko_terms gk,
                     kegg_pathway kp
                where gk.taxon in ( $taxon_str )
                and ir.roi_id = rk.roi_id
                and rk.ko_terms = gk.ko_terms
                and ir.pathway = kp.pathway_oid
                group by kp.category
            };
        }
        elsif ( lc($functype) eq 'kegg_pathway_ec' ) {
            $sql2 = qq{
                select ir.pathway, count(distinct gke.gene_oid)
                from gene_ko_enzymes gke, ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir
                where gke.taxon in ( $taxon_str )
                and gke.enzymes = kt.enzymes
                and kt.ko_id = rk.ko_terms
                and rk.roi_id = ir.roi_id
                group by ir.pathway
            };
        }
        elsif ( lc($functype) eq 'kegg_pathway_ko' ) {
            $sql2 = qq{
                select ir.pathway, count(distinct gk.gene_oid)
                from image_roi ir, image_roi_ko_terms rk, gene_ko_terms gk
                where gk.taxon in ( $taxon_str )
                and ir.roi_id = rk.roi_id
                and rk.ko_terms = gk.ko_terms
                group by ir.pathway
            };
        }
        elsif ( lc($functype) eq 'metacyc' ) {
            $sql2 = qq{
                select brp.in_pwys, count(distinct gke.gene_oid)
                from biocyc_reaction_in_pwys brp, biocyc_reaction br,
                     gene_ko_enzymes gke
                where gke.taxon in ( $taxon_str )
                and brp.unique_id = br.unique_id
                and br.ec_number = gke.enzymes
                group by brp.in_pwys
            };
        }

        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for ( ; ; ) {
            my ( $func2, $cnt2, $id3 ) = $cur2->fetchrow();
            last if !$func2;

            if ( lc($functype) eq 'kegg_category_ec' ||
             lc($functype) eq 'kegg_category_ko' ) {
                if ( $id3 ) {
                    $func2 = $id3;
                }
            }

            if ( $func_count{$func2} ) {
                $func_count{$func2} += $cnt2;
            }
            else {
                $func_count{$func2} = $cnt2;
            }
        }
        $cur2->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $taxon_str =~ /gtt_num_id/i );
    }

    # file
    if ( scalar(@$file_taxons_ref) > 0 ) {

    	if ( lc($functype) eq 'cog_pathway' ||
    	     lc($functype) eq 'kegg_category_ec' ||
    	     lc($functype) eq 'kegg_category_ko' ||
    	     lc($functype) eq 'kegg_pathway_ec' ||
    	     lc($functype) eq 'tigrfam_role' ) {
    	    print "<p>Computing $functype ...\n";
    	    for my $taxon_oid ( @$file_taxons_ref ) {
        		my %profile = MetaUtil::getTaxonCate2($taxon_oid, $data_type, $functype);
        		for my $key2 (keys %profile) {
        		    if ( $func_count{$key2} ) {
            			$func_count{$key2} += $profile{$key2};
        		    }
        		    else {
            			$func_count{$key2} = $profile{$key2};
        		    }
        		}
    	    }
    	}
    	elsif ( lc($functype) eq 'cog_category' ||
    		lc($functype) eq 'kegg_pathway_ko' ||
    		lc($functype) eq 'metacyc' ||
    		lc($functype) eq 'pfam_category' ) {
    	    print "<p>Computing $functype ...\n";
    	    my ($base_type, @rest) = split(/\_/, $functype);
    	    for my $taxon_oid ( @$file_taxons_ref ) {
        		my %profile = MetaUtil::getTaxonCate($taxon_oid, $data_type, $base_type);
        		for my $key2 (keys %profile) {
        		    if ( $func_count{$key2} ) {
            			$func_count{$key2} += $profile{$key2};
        		    }
        		    else {
            			$func_count{$key2} = $profile{$key2};
        		    }
        		}
    	    }
    	}
        elsif ($new_func_count) {

            my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$file_taxons_ref );

            my $datatypeClause;
            my @binds;
            if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
                $datatypeClause = "and data_type = ? ";
                push(@binds, $data_type);
            }

            my $sql2 = qq{
                select func_id, sum(gene_count)
                from $c_table_name
                where taxon_oid in ( $taxon_str )
                $datatypeClause
                group by func_id
            };

            my $cur2 = execSql( $dbh, $sql2, $verbose, @binds );
            for ( ; ; ) {
                my ( $func2, $cnt2 ) = $cur2->fetchrow();
                last if !$func2;

                if ( $func_count{$func2} ) {
                    $func_count{$func2} += $cnt2;
                }
                else {
                    $func_count{$func2} = $cnt2;
                }
            }
            $cur2->finish();
            OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
                if ( $taxon_str =~ /gtt_num_id/i );        
        }
        else {
            my @type_list = MetaUtil::getDataTypeList($data_type);
            for my $taxon_oid (@$file_taxons_ref) {
                for my $t2 ( @type_list ) {
                    my %func_h2 = MetaUtil::getTaxonFuncCount( $taxon_oid, $t2, $functype );
                    for my $func2 ( keys %func_h2 ) {
                        my $cnt2 = $func_h2{$func2};
                        if ( $func_count{$func2} ) {
                            $func_count{$func2} += $cnt2;
                        }
                        else {
                            $func_count{$func2} = $cnt2;
                        }
                    }
                }
            }
        }
    }

    return %func_count;
}

##############################################################################
# outputGenomeFuncGene - output genes in genome with func_id
#
# input_file: read taxon oids from this file
# input_taxon: only this taxon
#
# only return count and no output if $res is not defined
##############################################################################
sub outputGenomeFuncGene {
    my ( $res, $func_id, $input_file, $input_taxon ) = @_;

    ## get MER-FS taxons
    my $dbh = dbLogin();
    my ($db_taxons_ref, $file_taxons_ref) 
        = findDbAndMetaTaxons( $dbh, $input_file, $input_taxon );

    my $gene_count = 0;

    # database
    if ( scalar(@$db_taxons_ref) > 0 ) {

        my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_taxons_ref );
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my $select_count_only = 0;
        my $sql;
        my @bindList;
        if ( $include_metagenomes && !$res ) {
            $select_count_only = 1;
            ( $sql, @bindList ) =
              WorkspaceQueryUtil::getDbTaxonFuncGeneCountSql( $func_id,
                $taxon_str, $rclause, $imgClause );
        }
        else {
            ( $sql, @bindList ) =
              WorkspaceQueryUtil::getDbTaxonSimpleFuncGeneSql( $func_id,
                $taxon_str, $rclause, $imgClause );
        }

        if ( $sql ) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            if ($select_count_only) {
                my ($cnt1) = $cur->fetchrow();
                $gene_count += $cnt1;
            }
            else {
                for ( ; ; ) {
                    my ( $gene_oid, $func_id2 ) = $cur->fetchrow();
                    last if ( !$gene_oid );

                    if ($res) {
                        print $res "$gene_oid\n";
                    }
                    $gene_count++;
                }
            }
            $cur->finish();
        }
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $taxon_str =~ /gtt_num_id/i );        

    }

    # file
    if ( scalar(@$file_taxons_ref) > 0 ) {
        for my $taxon_oid (@$file_taxons_ref) {
            for my $data_type ( 'assembled', 'unassembled' ) {
                my @func_genes = MetaUtil::getTaxonFuncMetaGenes( $taxon_oid, $data_type, $func_id );

                for my $gene_oid (@func_genes) {
                    my $workspace_id = "$taxon_oid $data_type $gene_oid";
                    if ($res) {
                        print $res "$workspace_id\n";
                    }
                    $gene_count++;
                }
            }
        }
    }

    return $gene_count;
}

########################################################################
# showGenomeProfileGeneList - show all genes in a genome with selected function
########################################################################
sub showGenomeProfileGeneList {
    
    my $sid = WebUtil::getContactOid();

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $folder = $GENOME_FOLDER;
    my $page  = param("page");

    my $func_id = param('func_id');
    my $input_file = param('input_file');
    my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $input_file, $ownerFilesetDelim, $folder );

    my $taxon_oid = param('taxon_oid');
    my $data_type = param('data_type');

    my $dbh = dbLogin();

    ## get MER-FS taxons
    my $fullname = "$workspace_dir/$owner/$folder/$x";
    my ($db_taxons_ref, $file_taxons_ref) 
        = findDbAndMetaTaxons( $dbh, $fullname, $taxon_oid );

    my @allTaxons;
    push(@allTaxons, @$db_taxons_ref);
    push(@allTaxons, @$file_taxons_ref);
    my %taxon2name = QueryUtil::fetchTaxonOid2NameHash($dbh, \@allTaxons);

    if ($taxon_oid) {
        print "<h1>Genome Function Profile Gene List</h1>\n";
    }
    else {
        print "<h1>Genome Set Function Profile Gene List</h1>\n";
    }
    print "<p>";
    print "Function: $func_id";
    my $func_name = Workspace::getMetaFuncName($func_id);
    if ( $func_name ) {
       print " (" . $func_name . ")<br/>\n";
    }

    my $share_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $owner, $x, $sid );
    print "Genome Set: $share_set_name<br/>";

    if ($taxon_oid) {
        print "Genome: $taxon_oid<br/>\n";
    }
    HtmlUtil::printMetaDataTypeSelection( $data_type, 2 ) 
        if ( scalar(@$file_taxons_ref) > 0 );
    print "</p>\n";

    #print hiddenVar( "owner", $owner );
    print hiddenVar( "input_file", $input_file );
    print hiddenVar( "func_id",    $func_id );
    print hiddenVar( "directory", $folder );
    #print "showGenomeProfileGeneList() directory folder: $folder<br/>\n";

    printStartWorkingDiv();

    my $select_id_name = "gene_oid";

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",     "number asc", "left" );
    $it->addColSpec( "Gene Name",   "char asc",   "left" );
    $it->addColSpec( "Genome",      "char asc",   "left" );
    my $sd = $it->getSdDelim();

    print "<p>Retrieving gene information ...<br/>\n";
    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    my $trunc = 0;

    my $gene_count = 0;

    # database
    if ( scalar(@$db_taxons_ref) > 0 ) {

        my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$db_taxons_ref );
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my ( $sql, @bindList ) = WorkspaceQueryUtil::getDbTaxonFuncGeneSql( 
            $func_id, $taxon_str, $rclause, $imgClause );

        if ( $sql ) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $gene_oid, $func_id2, $t_oid, $gene_name ) =
                  $cur->fetchrow();
                last if ( !$gene_oid );

                if ( !$gene_name ) {
                    $gene_name = "hypothetical protein";
                }

                my $r;
                $r .= $sd
                  . "<input type='checkbox' name='$select_id_name' value='$gene_oid' "
                  . "  /> \t";
                my $url = "$main_cgi?section=GeneDetail";
                $url .= "&page=geneDetail&gene_oid=$gene_oid";
                $r   .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
                $r   .= $gene_name . $sd . $gene_name . "\t";

                my $t_url = "$main_cgi?section=TaxonDetail";
                $t_url .= "&page=taxonDetail&taxon_oid=$t_oid";
                my $taxon_name = $taxon2name{$t_oid};
                $r .= $taxon_name . $sd . alink( $t_url, $taxon_name ) . "\t";
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
            if ( $taxon_str =~ /gtt_num_id/i );        
    }

    # file
    if ( !$trunc && scalar(@$file_taxons_ref) > 0 ) {
        my @type_list = MetaUtil::getDataTypeList($data_type);
        for my $t_oid (@$file_taxons_ref) {
            for my $t2 ( @type_list ) {
                my @func_genes = MetaUtil::getTaxonFuncMetaGenes( $t_oid, $t2, $func_id );
                #print "showGenomeProfileGeneList() func_id=$func_id, t_oid=$t_oid, data_type=$t2, func_genes=" . @func_genes . "\n";

                for my $gene_oid (@func_genes) {
                    my $r;
                    my $workspace_id = "$t_oid $t2 $gene_oid";
                    $r .= $sd
                      . "<input type='checkbox' name='$select_id_name' value='$workspace_id' "
                      . "  /> \t";

                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .=
                        "&page=metaGeneDetail&taxon_oid=$t_oid"
                      . "&data_type=$t2&gene_oid=$gene_oid";
                    $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";

                    my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $t_oid, $t2 );
                    if ( !$gene_name ) {
                        $gene_name = "hypothetical protein";
                    }
                    $r .= $gene_name . $sd . $gene_name . "\t";

                    my $t_url = "$main_cgi?section=MetaDetail";
                    $t_url .= "&page=metaDetail&taxon_oid=$t_oid";
                    my $taxon_name = $taxon2name{$t_oid};
                    $taxon_name = HtmlUtil::appendMetaTaxonNameWithDataType( $taxon_name, $data_type );
                    $r .= $taxon_name . $sd . alink( $t_url, $taxon_name ) . "\t";

                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
                if ( $gene_count >= $maxGeneListResults ) {
                    $trunc = 1;
                    last;
                }
            }
            if ( $gene_count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }
    }

    printEndWorkingDiv();

    if ( $gene_count == 0 ) {
        print "<p><b>No genes have been found.</b>\n";
        print end_form();
        return;
    }

    WebUtil::printGeneCartFooter() if ( $gene_count > 10 );
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();
    print "<br/>";

    WorkspaceUtil::printSaveAndExpandTabsForGenes( $select_id_name );

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
    }
    print end_form();
}

############################################################################
# printGenomeBlast
############################################################################
sub printGenomeBlast {
    my ($isSet) = @_;

    my $sid = WebUtil::getContactOid();
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    my $folder = $GENOME_FOLDER;

    my %genomes_h;
    my $msg;

    if ($isSet) {
        my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);
        if ( scalar(@all_files) == 0 ) {
            webError("No genome sets are selected.");
            return;
        }

        my $dbh = dbLogin();

        foreach my $file_set_name (@all_files) {
            my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $file_set_name, $ownerFilesetDelim, $folder );
            open( FH, "$workspace_dir/$owner/$folder/$x" )
              or webError("File size - file error $x");

            my @oids;
            while ( my $line = <FH> ) {
                chomp($line);
                push(@oids, $line);
                $genomes_h{$line} = 1;
            }
            close FH;
            
            my $shareSetName = WorkspaceUtil::fetchShareSetName($dbh, $owner, $x, $sid);
            $msg .= "Genome Set: $shareSetName (" . scalar(@oids) . " genomes)<br/>\n";
        }
    }

    my @genomes = keys %genomes_h;
    validateGenomesForBlast(@genomes);

    require FindGenesBlast;
    FindGenesBlast::printGeneSearchBlastResults( \@genomes, $msg );

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

}


sub validateGenomesForBlast {
    my (@genomes) = @_;

    if ( scalar(@genomes) == 0 ) {
        webError("No genomes or genome sets are selected.");
        return;
    }
    if ( scalar(@genomes) > $blast_max_genome ) {
        webError("The total selection of genomes can not be more than $blast_max_genome (including metagenomes).");
        return;
    }
    require FindGenesBlast;
    FindGenesBlast::validateMerfsTaxonNumber(@genomes);    
}


############################################################################
# printGenomeBlastJob
############################################################################
sub printGenomeBlastJob {
    my ($isSet, $genomeset2genomes_href, $blast_program, $evalue, $isDnaSearch, $nRecs, $blastFile) = @_;

    my $sid = WebUtil::getContactOid();
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    my $msg;
    if ($isSet) {
        my $dbh = dbLogin();
        foreach my $file_set_name (keys %$genomeset2genomes_href) {
            my ( $owner, $x ) = WorkspaceUtil::splitOwnerFileset( $sid, $file_set_name, $ownerFilesetDelim_message );
            #print "printGenomeBlastJob() file_set_name=$file_set_name, owner=$owner, x=$x<br/>\n";
            my $share_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $owner, $x, $sid );
            #print "printGenomeBlastJob() share_set_name=$share_set_name<br/>\n";
            my $oids_ref = $genomeset2genomes_href->{$file_set_name};
            $msg .= "Genome Set: $share_set_name (" . scalar(@$oids_ref) . " genomes)<br/>\n";
        }
    }

    print "<h1>Blast Results</h1>\n";
    print "<p>\n";
    print "Program: " . $blast_program ."<br/>\n";
    print "E-value: " . $evalue ."<br/>\n";
    print $msg if ( $msg );
    print "</p>\n";

    require FindGenesBlast;

    my $res = newReadFileHandle("$blastFile");
    if ( $res ) {
        while ( my $line = $res->getline() ) {
            #chomp $line;
            next if ( ! $line );
            #print "printGenomeBlastJob() $line<br/>\n";
    
            if ( $line =~ /\-\-startingformcartbutton\-\-/ ) {
                FindGenesBlast::printStartingForm();
                FindGenesBlast::printCartButton( $isDnaSearch );
            }
            elsif ( $line =~ /\-\-endingformcartbutton\-\-/ ) {
                FindGenesBlast::printCartButtonWithWorkspaceSaving( $isDnaSearch );
                FindGenesBlast::printEndingForm( $nRecs ); 
            }
            elsif ( $line =~ /\-\-main_cgi/ ) {
                $line =~ s/\-\-main_cgi/$main_cgi/g;
                print "$line";
            }
            else {
                print "$line";
            }
        }
        close $res;        
    }

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

}


############################################################################
# printGenomePairwiseANI
############################################################################
sub printGenomePairwiseANI {
    my ($isSet) = @_;

    my $sid = WebUtil::getContactOid();
    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    my $folder = $GENOME_FOLDER;

    my %set2genomes;
    my @oids1;
    my @oids2;
    my $msg;

    if ($isSet) {
        my @all_files = WorkspaceUtil::getAllInputFiles($sid, 1);
        if ( scalar(@all_files) == 0 ) {
            webError("No genome sets are selected.");
            return;
        }
        if ( scalar(@all_files) < 2 ) {
            webError("Please select 2 genome sets.");
            return;
        }
        if ( scalar(@all_files) > 2 ) {
            $msg .= "<font color=red>Only first 2 genome sets are used for computation.</font><br/><br/>\n";
        }

        my @ordered_filenames;
        my $reverseSets = param('reverseSets');
        if ( $reverseSets ) {
            @ordered_filenames = ($all_files[1], $all_files[0]);
        }
        else {
            @ordered_filenames = ($all_files[0], $all_files[1]);            
        }

        my $dbh = dbLogin();
        
        my $cnt;
        foreach my $file_set_name (@ordered_filenames) {
            $cnt++;
            my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $file_set_name, $ownerFilesetDelim, $folder );
            open( FH, "$workspace_dir/$owner/$folder/$x" )
              or webError("File size - file error $x");

            my %genomes_h;
            while ( my $line = <FH> ) {
                chomp($line);
                #no metagenomes
                if ( isInt($line) ) {
                    $genomes_h{$line} = 1;
                } 
            }
            close FH;

            my @oids = keys %genomes_h;
            $set2genomes{$x} = \@oids;
            if ( $cnt == 1 ) {
                @oids1 = @oids;                    
            }
            elsif ( $cnt == 2 ) {
                @oids2 = @oids;                    
            }
            
            my $shareSetName = WorkspaceUtil::fetchShareSetName($dbh, $owner, $x, $sid);
            $msg .= "Genome" . $cnt . ": $shareSetName (" . scalar(@oids) . " genomes)<br/>\n";
        }

        my @intersection = WebUtil::intersectionOfArrays( \@oids1, \@oids2 );
        if ( scalar(@intersection) > 0 ) {
            webError("Pairwise ANI cannot compare same genome. There are " . scalar(@intersection) . " genomes in both genome sets.");
            return;
        }

    }

    if ( scalar(@oids1) == 0 || scalar(@oids2) == 0 ) {
        webError("Metagenomes are not supported in ANI.");
        return;
    }

    require ANI;
    ANI::doPairwise(\@oids1, \@oids2, $msg, $isSet);

    if ( $sid == 312 || $sid == 107 || $sid == 100546 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

}


#####################################################################
# submitJob
#####################################################################
sub submitJob {
    my ($jobPrefix) = @_;

    printMainForm();

    my $lcJobPrefix = lc($jobPrefix);
    if ( $jobPrefix =~ /pairwise/i ) {
        $lcJobPrefix = 'pairwise_ani';
    }
    else {
        $lcJobPrefix = lc($jobPrefix);
    }
    #print "submitJob() job=$jobPrefix, lcJob=$lcJobPrefix<br/>\n";

    my $data_type;
    if ( $lcJobPrefix eq 'blast' ) {
        $data_type = param('data_type_b');
    }

    my $d_type;
    my $evalue;
    my $fasta;
    my $fastaFileName;
    if ( $lcJobPrefix eq 'blast' ) {
        $d_type = param('blast_program');
        $evalue = param("blast_evalue");
        $evalue = WebUtil::checkEvalue($evalue);
        $fasta  = param("fasta");
        if ( blankStr($fasta) ) {
            webError("Query sequence not specified..");
        }
        if ( $fasta !~ /[a-zA-Z]+/ ) {
            webError("Query sequence should have letter characters.");
        }
        $fastaFileName = "fasta.txt"
    }
    elsif ( $lcJobPrefix eq 'pairwise_ani' ) {
        $d_type = param('reverseSets');
    }
    
    print "<h2>Computation Job Submission ($jobPrefix)</h2>\n";

    my $dbh = dbLogin();
    my $sid = WebUtil::getContactOid();
    $sid = sanitizeInt($sid);
    
    my $folder = $GENOME_FOLDER;
    my $set_names;
    my $share_set_names;
    my $set_names_message;

    my @genomes_oids;

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

        if ( $lcJobPrefix eq 'blast' ) {
            open( FH, "$workspace_dir/$owner/genome/$x" )
              or next;
    
            my %genomes_h;
            while ( my $line = <FH> ) {
                chomp($line);
                next if ( ! $line );
                if ( WebUtil::isInt($line) ) {
                    $genomes_h{$line} = 1;
                } 
            }
            close FH;
            my @g_oids = keys %genomes_h;
            push(@genomes_oids, @g_oids);
        }
    }
    if ( !$set_names ) {
        webError("Please select at least one genome set.");
        return;
    }    
    if ( $lcJobPrefix eq 'blast' ) {
        validateGenomesForBlast(@genomes_oids);
    }
        
    print "<p>Genome Set(s): $share_set_names<br/>\n";
    HtmlUtil::printMetaDataTypeSelection( $data_type, 2 ) if ($data_type);
    print "Display Type: $d_type<br/>\n" if ( $d_type );
    print "E-Value: $evalue<br/>\n" if ( $evalue );
    print "Sequence: <br/>\n$fasta<br/>\n" if ( $fasta );

    my $output_name = Workspace::validJobSetNameToSaveOrReplace( $lcJobPrefix );
    my $job_file_dir = Workspace::getJobFileDirReady( $sid, $output_name );

    ## output info file
    my $info_file = "$job_file_dir/info.txt";
    my $info_fs   = newWriteFileHandle($info_file);
    print $info_fs "Genome $jobPrefix\n";
    print $info_fs "--genome $share_set_names\n";
    print $info_fs "--datatype $data_type\n" if ( $data_type );
    print $info_fs "--dtype $d_type\n" if ( $d_type );
    print $info_fs "--evalue $evalue\n" if ( $evalue );
    if ( $fasta ) {
        print $info_fs "--fasta $fastaFileName\n";

        $fasta =~ s/^\s+//;
        $fasta =~ s/\s+$//;
        my $fasta2 = $fasta;
        if ( $fasta !~ /^>/ ) {
            $fasta2 = ">query$$\n";
            $fasta2 .= "$fasta\n";
        }
        my $fastaFile = "$job_file_dir/$fastaFileName";
        my $wfh = newWriteFileHandle( $fastaFile, "BlastQuery" );
        print $wfh "$fasta2\n";
        close $wfh;
    }
    print $info_fs currDateTime() . "\n";
    close $info_fs;

    my $queue_dir = $env->{workspace_queue_dir};
    #print "submitJob() queue_dir=$queue_dir<br/>\n";
    my $queue_filename;
    if ( $lcJobPrefix eq 'blast' ) {
        $queue_filename = $sid . '_genomeBlast_' . $output_name;
    } 
    elsif ( $lcJobPrefix eq 'pairwise_ani' ) {
        $queue_filename = $sid . '_genomePairwiseANI_' . $output_name;
    } 
    #print "submitJob() queue_filename=$queue_filename<br/>\n";
    my $wfh = newWriteFileHandle( $queue_dir . $queue_filename );

    if ( $lcJobPrefix eq 'blast' ) {
        print $wfh "--program=genomeBlast\n";
    } 
    elsif ( $lcJobPrefix eq 'pairwise_ani' ) {
        print $wfh "--program=genomePairwiseANI\n";
    } 
    print $wfh "--contact=$sid\n";
    print $wfh "--output=$output_name\n";
    print $wfh "--genomeset=$set_names_message\n";
    print $wfh "--datatype=$data_type\n" if ( $data_type );
    print $wfh "--dtype=$d_type\n" if ( $d_type );
    print $wfh "--evalue=$evalue\n" if ( $evalue );
    print $wfh "--fasta=$fastaFileName\n" if ( $fastaFileName );
    close $wfh;
    
    Workspace::rsync($sid);
    print "<p>Job is submitted successfully.\n";

    print end_form();
}

1;
