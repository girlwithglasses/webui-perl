###########################################################################
# Workspace.pm
#
# allow user to upload and download
# for upload - check valid entries in file
#
# filenames with white spaces     $filename =~ s/\s/_/g;
# - ken
#
# $Id: Workspace.pm 33905 2015-08-05 20:24:41Z klchu $
#
############################################################################
package Workspace;
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use warnings;
use feature ':5.16';
use Carp;
use Archive::Zip;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use POSIX qw(ceil floor);
use InnerTable;
use StaticInnerTable;
use WebConfig;
use WebUtil;
use GeneCartStor;
use MetaUtil;
use HashUtil;
use MetaGeneTable;
use WorkspaceUtil;
use WorkspaceQueryUtil;
use MerFsUtil;
use QueryUtil;
use HtmlUtil;
use DataEntryUtil;
$| = 1;

my $section              = "Workspace";
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
my $workspace_sandbox_dir = $env->{workspace_sandbox_dir};

my $public_nologin_site = $env->{public_nologin_site};
my $web_data_dir        = $env->{web_data_dir};

my $cog_base_url       = $env->{cog_base_url};
my $pfam_base_url      = $env->{pfam_base_url};
my $tigrfam_base_url   = $env->{tigrfam_base_url};
my $enzyme_base_url    = $env->{enzyme_base_url};
my $kegg_orthology_url = $env->{kegg_orthology_url};

my $mer_data_dir      = $env->{mer_data_dir};
my $taxon_lin_fna_dir = $env->{taxon_lin_fna_dir};
my $cgi_tmp_dir       = $env->{cgi_tmp_dir};
my $YUI               = $env->{yui_dir_28};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = getSessionParam("maxGeneListResults") || 1000;

my $enable_workspace = $env->{enable_workspace};
my $in_file          = $env->{in_file};

my $merfs_timeout_mins = $env->{merfs_timeout_mins} || 30;

# user's sub folder names
my $GENE_FOLDER   = "gene";
my $FUNC_FOLDER   = "function";
my $SCAF_FOLDER   = "scaffold";
my $GENOME_FOLDER = "genome";
my $RULE_FOLDER   = "rule";
my $BC_FOLDER     = 'bc';
my @subfolders    = ( $GENE_FOLDER, $FUNC_FOLDER, $SCAF_FOLDER, $GENOME_FOLDER, $BC_FOLDER );

my $ownerFilesetDelim = "|";
my $ownerFilesetDelim_message = "::::";

my $filename_size      = 25;
my $filename_len       = 60;
my $max_workspace_view = 10000;
my $max_upload_size    = 50000000;

my $nvl          = getNvl();
my $unknown      = "Unknown";
my $unclassified = 'unclassified';
my $chkBoxDelim  = "/";

my $mer_fs_debug = 0;

my $for_super_user_only = 1;
if ( !$for_super_user_only ) {
    @subfolders = ( $GENE_FOLDER, $FUNC_FOLDER, $SCAF_FOLDER, $GENOME_FOLDER, $BC_FOLDER, $RULE_FOLDER );
}

# initialize the workspace for new users
# if a user click function set list the folder has not been created yet and
# and error occurs
sub initialize {
    my $sid = getContactOid();
    return if ( $sid == 0 ||  $sid < 1 || $sid eq '901');

    my $super_user = getSuperUser();

    push @subfolders, $RULE_FOLDER if $super_user eq 'Yes';

    # check if workspace area is available - ken
    # check to see user's folder has been created
    if ( !-e "$workspace_dir" ) {
        mkdir "$workspace_dir" or webError("Workspace is down!");
    }

    if ( !-e "$workspace_dir/$sid" ) {
        mkdir "$workspace_dir/$sid" or webError("Workspace is down!");
    }

    foreach my $x (@subfolders) {
        if ( !-e "$workspace_dir/$sid/$x" ) {
            mkdir "$workspace_dir/$sid/$x" or webError("Workspace is down!");
        }
    }
}

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    return if ( !$enable_workspace );
    return if ( !$user_restricted_site );

    my $page = param("page");

    my $sid = getContactOid();
    return if ( $sid == 0 ||  $sid < 1 || $sid eq '901');

    initialize();

##    if ( !$page && paramMatch("wpload") ) {
    if ( paramMatch("wpload") ) {
        $page = "load";
    }

    if ( $page eq "profileGeneList" || paramMatch("profileGeneList") ) {
        showProfileGeneList();
    } elsif ( $page eq "scafProfileGeneList"
        || paramMatch("scafProfileGeneList") )
    {
        showScafProfileGeneList();
    } elsif ( $page eq "scafCateProfileGeneList"
        || paramMatch("scafCateProfileGeneList") )
    {
        showScafCateProfileGeneList();
    } elsif ( $page eq "genomeProfileGeneList"
        || paramMatch("genomeProfileGeneList") )
    {
        showGenomeProfileGeneList();
    } elsif ( $page eq $GENE_FOLDER ) {
        # display list of user's saved gene cart
        folderList($page);
    } elsif ( $page eq $FUNC_FOLDER ) {
        folderList($page);
    } elsif ( $page eq $SCAF_FOLDER ) {
        folderList($page);
    } elsif ( $page eq $GENOME_FOLDER ) {
        folderList($page);
    } elsif ($page eq $BC_FOLDER) {
        folderList($BC_FOLDER);
    } elsif ( $page eq $RULE_FOLDER ) {
        folderList($page);

    } elsif ( $page eq $BC_FOLDER ) {
        require WorkspaceBcSet;
        WorkspaceBcSet::printWorkspaceSets();
        
    } elsif ( $page eq "view" ) {
        viewFile();
    } elsif ( $page eq "delete" ) {
        deleteFile();
    } elsif ( $page eq "load" ) {
        timeout( 60 * $merfs_timeout_mins );
        readFile();
    } elsif ( $page eq "showDetail"
        || $page eq "genomeSetDetail" )
    {
        printWorkspaceSetDetail();
    } elsif ( paramMatch("breakLargeSet") ) {
        timeout( 60 * $merfs_timeout_mins );
        breakLargeSet();
    } elsif ( paramMatch("saveGeneCart2") ) {
        saveGeneCart2();
    } elsif ( paramMatch("saveGeneCart") ) {
        saveGeneCart();
    } elsif ( paramMatch("saveAllGeneCart") ) {
        saveAllGeneCart();
    } elsif ( paramMatch("saveFuncGenes") ) {
        saveAllGeneCart();
    } elsif ( paramMatch("saveSelectedGenomeFuncGenes") ) {
        saveSelectedFuncGenes($GENOME_FOLDER);
    } elsif ( paramMatch("saveSelectedScaffoldFuncGenes") ) {
        saveSelectedFuncGenes($SCAF_FOLDER);
    } elsif ( paramMatch("saveExtFuncGenes") ) {
        saveAllGeneCart();
    } elsif ( $page eq "saveAllDbScafGenes"
        || paramMatch("saveAllDbScafGenes") )
    {
        saveAllDbScafGenes();
    } elsif ( $page eq "saveAllMetaScafGenes"
        || paramMatch("saveAllMetaScafGenes") )
    {
        saveAllMetaScafGenes();
    } elsif ( paramMatch("saveAllTaxonFuncGenes") ) {
        saveAllTaxonFuncGenes();
    } elsif ( paramMatch("saveAllTaxonRnaGenes") ) {
        saveAllTaxonRnaGenes();
    } elsif ( paramMatch("saveAllCDSGeneList") ) {
        saveAllCDSGeneList();
    } elsif ( paramMatch("saveAllRnaGeneList") ) {
        saveAllRnaGeneList();
    } elsif ( paramMatch("saveAllGeneProdList") ) {
        saveAllGeneProdList();
    } elsif ( paramMatch("saveAllGeneWithoutFuncList") ) {
        saveAllGeneWithoutFuncList();
    } elsif ( paramMatch("saveAllNoEnzymeWithKOGenes") ) {
        saveAllNoEnzymeWithKOGenes();
    } elsif ( paramMatch("saveAllKeggCategoryGeneList") ) {
        saveAllKeggCategoryGeneList();
    } elsif ( paramMatch("saveAllKeggPathwayGeneList") ) {
        saveAllKeggPathwayGeneList();
    } elsif ( paramMatch("saveAllNonKeggGeneList") ) {
        saveAllNonKeggGeneList();
    } elsif ( paramMatch("saveAllNonKoGeneList") ) {
        saveAllNonKoGeneList();
    } elsif ( paramMatch("saveAllNonMetacycGeneList") ) {
        saveAllNonMetacycGeneList();
    } elsif ( paramMatch("saveAllGeneFuncList") ) {
        saveAllGeneFuncList();
    } elsif ( paramMatch("saveAllCKogCatGenes") ) {
        saveAllCKogCatGenes();
    } elsif ( paramMatch("saveAllPfamCatGenes") ) {
        saveAllPfamCatGenes();
    } elsif ( paramMatch("saveAllTIGRfamCatGenes") ) {
        saveAllTIGRfamCatGenes();
    } elsif ( paramMatch("saveAllImgTermCatGenes") ) {
        saveAllImgTermCatGenes();
    } elsif ( paramMatch("saveAllClusterGenes") ) {
        saveAllClusterGenes();
    } elsif ( paramMatch("saveAllCassetteGenes") ) {
        saveAllCassetteGenes();
    } elsif ( paramMatch("saveAllCassetteOccurrenceGenes") ) {
        saveAllCassetteOccurrenceGenes();
    } elsif ( paramMatch("saveAllFusedGenes") ) {
        saveAllFusedGenes();
    } elsif ( paramMatch("saveAllSignalGenes") ) {
        saveAllSignalGenes();
    } elsif ( paramMatch("saveAllTransmembraneGenes") ) {
        saveAllTransmembraneGenes();
    } elsif ( paramMatch("saveAllBiosyntheticGenes") ) {
        saveAllBiosyntheticGenes();
    } elsif ( paramMatch("saveAllMetaHits") ) {
        saveAllMetaHits();
    } elsif ( paramMatch("saveScaffoldDistToWorkspace") ) {
        saveScaffoldDistToWorkspace();
    } elsif ( paramMatch("saveScaffoldLengthRange") ) {
        #saveScaffoldLengthRange();
        saveScaffoldDistToWorkspace();
    } elsif ( paramMatch("saveScaffoldCart") ) {
        saveScaffoldCart();
    } elsif ( paramMatch("removeAndSaveScaffolds") ) {
        removeAndSaveScaffolds();
    } elsif ( paramMatch("saveFunctionCart") ) {
        saveFunctionCart();
    } elsif ( paramMatch("saveGenomeCart") ) {
        saveGenomeCart();
    } elsif ( paramMatch("saveAllBrowserGenomeList") ) {
        saveAllBrowserGenomeList();
    } elsif ( paramMatch("addSharing") ) {
        addSharing();
    } elsif ( paramMatch("removeSharing") ) {
        removeSharing();
    } elsif ( paramMatch("saveIntersection") ) {
        saveIntersection();
    } elsif ( paramMatch("saveUnion") ) {
        saveUnion();
    } elsif ( paramMatch("saveSetOpMinus") ) {
        saveSetOp(1);
    } elsif ( paramMatch("saveSetOp") ) {
        saveSetOp();
    } elsif ( paramMatch("saveGeneSetScaffoldsAlternative") ) {
        saveGeneScaffolds( 1, 1 );
    } elsif ( paramMatch("saveGeneSetScaffolds") ) {
        saveGeneScaffolds(1);
    } elsif ( paramMatch("saveGeneScaffoldsAlternative") ) {
        saveGeneScaffolds( 0, 1 );
    } elsif ( paramMatch("saveGeneScaffolds") ) {
        saveGeneScaffolds(0);
    } elsif ( paramMatch("saveGeneSetGenomesAlternative") ) {
        saveGeneGenomes( 1, 1 );
    } elsif ( paramMatch("saveGeneSetGenomes") ) {
        saveGeneGenomes(1);
    } elsif ( paramMatch("saveGeneGenomesAlternative") ) {
        saveGeneGenomes( 0, 1 );
    } elsif ( paramMatch("saveGeneGenomes") ) {
        saveGeneGenomes(0);
    } elsif ( paramMatch("saveScaffoldSetGenesAlternative") ) {
        saveScaffoldGenes( 1, 1 );
    } elsif ( paramMatch("saveScaffoldSetGenes") ) {
        saveScaffoldGenes(1);
    } elsif ( paramMatch("saveScaffoldGenesAlternative") ) {
        saveScaffoldGenes( 0, 1 );
    } elsif ( paramMatch("saveScaffoldGenes") ) {
        saveScaffoldGenes(0);
    } elsif ( paramMatch("saveScaffoldSetGenomesAlternative") ) {
        saveScaffoldGenomes( 1, 1 );
    } elsif ( paramMatch("saveScaffoldSetGenomes") ) {
        saveScaffoldGenomes(1);
    } elsif ( paramMatch("saveScaffoldGenomesAlternative") ) {
        saveScaffoldGenomes( 0, 1 );
    } elsif ( paramMatch("saveScaffoldGenomes") ) {
        saveScaffoldGenomes(0);
    } elsif ( paramMatch("exportGeneFasta") ) {
        exportGeneFasta();
    } elsif ( paramMatch("exportGeneAA") ) {
        exportGeneAA();
    } elsif ( paramMatch("exportScaffoldFasta") ) {
        exportScaffoldFasta();
    } elsif ( paramMatch("exportScaffoldData") ) {
        exportScaffoldData();
    } elsif ( param("importStep") == 2 ) {
        importSelected();
    } elsif ( paramMatch("export") ) {
        exportWorkspace();
    } elsif ( param("importStep") == 1 ) {
        importWorkspace();
    } elsif ( paramMatch("exAll") ) {
        exportAll();
    } else {
        printMainPage();
    }
}

# save users preferences in workspace
#
# default use is for preferences
# can be used for genome list config preferences
# given the filename mygenomelistprefs ??? - TODO
# - ken
#
sub saveUserPreferences {
    my ( $href, $customFilename ) = @_;
    return if ( !$user_restricted_site );

    my $sid      = getContactOid();
    my $filename = "$workspace_dir/$sid/mypreferences";
    if ( $customFilename ne '' ) {
        $filename = "$workspace_dir/$sid/$customFilename";
    }

    if ( !-e "$workspace_dir/$sid" ) {
        mkdir "$workspace_dir/$sid" or webError("Workspace is down!");
    }

    my $wfh = newWriteFileHandle($filename);
    foreach my $key ( sort keys %$href ) {
        my $value = $href->{$key};
        print $wfh "${key}=${value}\n";
    }

    close $wfh;
}

sub loadUserPreferences {
    my $pref_file = shift;

	return {} if ! $user_restricted_site;

    my $sid      = getContactOid();
	$pref_file //= "$workspace_dir/$sid/mypreferences";

	return {} if ! -e $pref_file;

    # read file
    # return hash
    my %hash;
    my $rfh = newReadFileHandle($pref_file);
    while ( my $line = $rfh->getline() ) {
        chomp $line;
        next if ( $line eq "" );
        my ( $key, $value ) = split( /=/, $line );
        $hash{$key} = $value;
    }
    close $rfh;
    return \%hash;
}

sub loadUserPreferencesByContactOid {

	my $c_oid = shift // croak 'No contact ID supplied!';
	my $f_name = "$workspace_dir/$c_oid/mypreferences";

	return IMG::IO::File::file_to_hash( $f_name );

}

# main page
# list summary of how many files saved - each cart
sub printMainPage {
    my $sid = getContactOid();
    my %file_counts;

    # for super users only
    my $super_user = getSuperUser();
    if ( $super_user eq 'Yes' ) {
        @subfolders = ( $GENE_FOLDER, $FUNC_FOLDER, $SCAF_FOLDER, $GENOME_FOLDER, $BC_FOLDER, $RULE_FOLDER );
    }

    printMainForm();
    print "<h1>My Workspace</h1>\n";

    foreach my $subdir (@subfolders) {
	## count my own
        opendir( DIR, "$workspace_dir/$sid/$subdir" )
          or webDie("failed to read files");
        my @files = readdir(DIR);

        my $count = 0;
        foreach my $x ( sort @files ) {

            # remove files "."  ".." "~$"
            next if ( $x eq "." || $x eq ".." || $x =~ /~$/ );
            $count++;
        }

        $file_counts{$subdir} = $count;
        closedir(DIR);

	## count share datasets
	my %share_h = WorkspaceUtil::getShareFromGroups($subdir);
	my @keys = (keys %share_h);
	$file_counts{$subdir} += scalar(@keys);
    }

    my $sit = new StaticInnerTable();
    $sit->addColSpec("Data Category");
    $sit->addColSpec( "Number of Sets<br>(click the link to each data category)", "", "right" );

    my $grTotal;
    foreach my $x ( sort keys %file_counts ) {
        my $name  = $x;
        my $count = $file_counts{$x};
        $grTotal += $count;
        if (   $count > 0
            || ( $super_user eq 'Yes' && $count >= 0 )
            || ( ! $for_super_user_only && $name eq $RULE_FOLDER ) )
        {
            $count = alink( "$section_cgi&page=$name", $count );
        }
        my $row = "\u$name Sets\t";
        $row .= "$count\t";
        $sit->addRow($row);
    }
    $sit->printTable();

    # Show Export All button for non-empty workspace
    if ($grTotal) {
        print "<p>";
        my $contact_oid = WebUtil::getContactOid();
        my $str = HtmlUtil::trackEvent( "Export", $contact_oid, "img button _section_Workspace_exAll_noHeader" );
        print qq{
<input class='meddefbutton' name='_section_Workspace_exAll_noHeader' type="submit" value="Export All" $str>
        };
    }

    print "<h2>Computation Jobs Using Message System</h2>\n";
    print "<table class='img'>\n";
    print "<tr class='img'>\n";
    print "<td class='img'>Computation Jobs</td>\n";

    my $job_dir = "$workspace_dir/$sid/job";
    if ( -d $job_dir ) {
        my $cnt = 0;
        opendir( DIR, $job_dir ) or webDie("failed to read files");
        my @files = readdir(DIR);
        foreach my $x ( sort @files ) {

            # remove files "."  ".." "~$"
            next if ( $x eq "." || $x eq ".." || $x =~ /~$/ );
            $cnt++;
        }
        closedir(DIR);

        my $url = "$main_cgi?section=WorkspaceJob" . "&page=workspaceJobMain";
        print "<td class='img'>" . alink( $url, $cnt ) . "</td>\n";
    } else {
        print "<td class='img'>No Jobs</td>\n";
    }

    print "</tr>\n";
    print "</table>\n";

    print end_form();
}

#
# list sub directory
#
sub folderList {
    my ( $folder, $text ) = @_;

    if ( $folder eq $GENE_FOLDER ) {
        require WorkspaceGeneSet;
        WorkspaceGeneSet::printGeneSetMainForm($text);
    } elsif ( $folder eq $FUNC_FOLDER ) {
        require WorkspaceFuncSet;
        WorkspaceFuncSet::printFuncSetMainForm($text);
    } elsif ( $folder eq $GENOME_FOLDER ) {
        require WorkspaceGenomeSet;
        WorkspaceGenomeSet::printGenomeSetMainForm($text);
    } elsif($folder eq $BC_FOLDER) {
        require WorkspaceBcSet;
        WorkspaceBcSet::printMainForm();
    } elsif ( $folder eq $SCAF_FOLDER ) {
        require WorkspaceScafSet;
        WorkspaceScafSet::printScafSetMainForm($text);
    } elsif ( $folder eq $RULE_FOLDER ) {
        require WorkspaceRuleSet;
        WorkspaceRuleSet::printRuleSetMainForm($text);
    }
}

###############################################################################
# getDataSetNames
###############################################################################
sub getDataSetNames {
    my ($folder) = @_;

    WebUtil::validFileName($folder);

    my $sid = getContactOid();
    opendir( DIR, "$workspace_dir/$sid/$folder" )
        or webDie("failed to open folder list");
    my @files = readdir(DIR);
    closedir(DIR);

    my @names = ();
    for my $name ( sort @files ) {
        if ( $name ne "." && $name ne ".." ) {
            push @names, ($name);
        }
    }

    return @names;
}

###############################################################################
# breakLargeSet
###############################################################################
sub breakLargeSet {

    my $sid = getContactOid();

    my @input_files = param("filename");
    #print "breakLargeSet() input_files @input_files<br/>\n";
    if ( scalar(@input_files) != 1 ) {
        webError("Please select only one set to break.");
        return;
    }

    # check filename
    # valid chars
    my $rootfilename = $input_files[0];
    WebUtil::checkFileName($rootfilename);

    # this also untaints the name
    $rootfilename = WebUtil::validFileName($rootfilename);

    my $folder = param("directory");
    #print "folder $folder<br/>\n";
    if ( !$folder ) {
        # default is gene folder
        $folder = $GENE_FOLDER;
    }

    my $breaksize = param("breaksize");
    if ( !$breaksize ) {
        webError("Please select a size to break the $folder set.");
        return;
    }

    my %oids_hash = WorkspaceUtil::getOidsFromFile( $workspace_dir, $sid, $folder, @input_files );

    my $nOids     = scalar( keys %oids_hash );
    if ( $breaksize >= $nOids ) {
        webError("The selected $folder set has $nOids $folder(s), smaller than the selected break size $breaksize.");
        return;
    }

    printStartWorkingDiv();

    my @fileNames = ();
    my $filename;
    my $res;
    my $suffix_num = 0;
    my $cnt        = 0;
    for my $key ( keys %oids_hash ) {
        if ( !$key ) {
            next;
        }

        if ( $cnt % $breaksize == 0 ) {
            if ($filename) {
                close $res;
                push( @fileNames, $filename );
            }
            ( $filename, $suffix_num ) = getUsableFilename( $rootfilename, $suffix_num );
            while ( -e "$workspace_dir/$sid/$folder/$filename" ) {
                ( $filename, $suffix_num ) = getUsableFilename( $rootfilename, $suffix_num );
            }
            $res = newWriteFileHandle("$workspace_dir/$sid/$folder/$filename");
        }
        print $res "$key\n";
        $cnt++;
    }
    close $res;
    push( @fileNames, $filename );

    printEndWorkingDiv();

    my $text = qq{
        <p>
        $cnt $folder(s) in $rootfilename are saved to the following files:<br/>
        <b>
    };
    my $nFiles  = scalar(@fileNames);
    my $cntFile = 0;
    foreach my $fname (@fileNames) {
        $cntFile++;
        $text .= $fname;
        if ( $cntFile < $nFiles ) {
            $text .= ', ';
        }
    }
    $text .= qq{
        </b>
        </p>
    };

    folderList( $folder, $text );
}

sub getUsableFilename {
    my ( $rootfilename, $suffix_num ) = @_;

    $suffix_num++;
    my $filename = $rootfilename . '_' . $suffix_num;
    WebUtil::checkFileName($filename);
    $filename = WebUtil::validFileName($filename);

    return ( $filename, $suffix_num );
}

#
# save gene cart genes to workspace file
# Form gene cart form submit
#
sub saveGeneCart {
    my $sid = getContactOid();

    # form selected genes
    my @genes = param("gene_oid");
    if ( $#genes < 0 ) {
        webError("Please select some genes to save.");
        return;
    }

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $count = 0;
    foreach my $gene_oid (@genes) {
        if ( $h2_href->{$gene_oid} ) {
            # already in
            next;
        }
        print $res "$gene_oid\n";
        $h2_href->{$gene_oid} = 1;
        $count++;
    }
    close $res;

    my $text = qq{
        <p>
        $count genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

#
# save gene cart genes to workspace file
# This version saves both gene_oid and workspace_id
#
sub saveGeneCart2 {
    my $sid = getContactOid();

    # form selected genes
    my @genes = param("gene_oid");

    my @workspace_ids = param("workspace_id");
    for my $id2 (@workspace_ids) {
        push @genes, ($id2);
    }

    if ( $#genes < 0 ) {
        webError("Please select some genes to save.");
        return;
    }

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $count = 0;
    foreach my $gene_oid (@genes) {
        if ( $h2_href->{$gene_oid} ) {
            # already in
            next;
        }
        print $res "$gene_oid\n";
        $h2_href->{$gene_oid} = 1;
        $count++;
    }

    close $res;

    my $text = qq{
        <p>
        $count genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

sub saveAllGeneCart {
    my $sid = getContactOid();

    my @input_files = param("input_file");
    #print "saveAllGeneCart() input_files @input_files<br/>\n";
    if ( scalar(@input_files) == 0 ) {
        webError("There are no genes to save. Please select genes.");
        return;
    }

    my $data_type = param('data_type');

    my @func_ids = param("func_id");
    #print "saveAllGeneCart() func_ids @func_ids<br/>\n";
    if ( scalar(@func_ids) == 0 ) {
        webError("There are no genes to save. Please select a function.");
        return;
    }

    my $folder = param("directory");
    #print "saveAllGeneCart() folder $folder<br/>\n";
    if ( !$folder ) {
        # default is gene folder
        $folder = $GENE_FOLDER;
    }

    my ($filename, $res, $gene_href) = prepareSaveToWorkspace( $sid, $GENE_FOLDER );

    timeout( 60 * $merfs_timeout_mins );
    printStartWorkingDiv();

    my $total = 0;
    if ( scalar(@func_ids) > 0 ) {
        my $dbh = dbLogin();
        for my $input_file (@input_files) {
            print "Processing input_file $input_file ...<br/>\n";
            my $fullname = "$workspace_dir/$sid/$folder/$input_file";
            my @func_groups = QueryUtil::groupFuncIdsIntoOneArray( \@func_ids );
            foreach my $func_ids_ref (@func_groups) {
                my $cnt = outputFuncsGenes( $res, $dbh, $func_ids_ref, $folder, $fullname, $data_type, $gene_href );
                #print "saveAllGeneCart() $cnt gene output from $fullname ...<br/>\n";
                $total += $cnt;
            }
        }
    }

    printEndWorkingDiv();

    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $GENE_FOLDER, $text );
}

sub saveSelectedFuncGenes {
    my ($folder) = @_;

    #print "folder: $folder<br/>\n";

    my $sid = getContactOid();

    my @oids;
    if ( $folder eq $GENOME_FOLDER ) {
        @oids = param("taxon_oid");
        #print "taxon_oids: @oids<br/>\n";
        if ( scalar(@oids) == 0 ) {
            webError("There are no genes to save. Please select a genome.");
            return;
        }
    } elsif ( $folder eq $SCAF_FOLDER ) {
        @oids = param("scaffold_oid");
        #print "scaffold_oids: @oids<br/>\n";
        if ( scalar(@oids) == 0 ) {
            webError("There are no genes to save. Please select a scaffold.");
            return;
        }
    }

    my @func_ids = param("func_id");
    #print "func_ids: @func_ids<br/>\n";
    if ( scalar(@func_ids) == 0 ) {
        webError("There are no genes to save. Please select a function.");
        return;
    }

    $folder = $GENE_FOLDER;
    my ($filename, $res, $gene_href) = prepareSaveToWorkspace( $sid, $folder );

    printStartWorkingDiv();

    my $dbh   = dbLogin();
    my $total = 0;
    for my $oid (@oids) {
        if ( $folder eq $GENOME_FOLDER ) {
            print "Processing taxon $oid function @func_ids ...<br/>\n";
            $total += outputTaxonFuncsGenes( $dbh, $res, \@func_ids, $oid, '', $gene_href );
        } elsif ( $folder eq $SCAF_FOLDER ) {
            print "Processing scaffold $oid function @func_ids ...<br/>\n";
            $total += outputScaffoldFuncsGenes( $dbh, $res, \@func_ids, $oid, $gene_href );
        }
    }

    printEndWorkingDiv();
    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

###############################################################################
# saveAllTaxonFuncGenes: save all genes of a taxon with func_id to a
#                        workspace file
###############################################################################
sub saveAllTaxonFuncGenes {
    my $sid = getContactOid();

    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my @func_ids  = param("func_id");

    if ( !$taxon_oid || scalar(@func_ids) == 0 ) {
        webError("There are no genes to save.");
        return;
    }

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    printStartWorkingDiv();
    my $dbh = dbLogin();
    #print "saveAllTaxonFuncsGenes() data_type: $data_type<br/>\n";
    my $total = outputTaxonFuncsGenes( $dbh, $res, \@func_ids, $taxon_oid, $data_type, $h2_href );
    printEndWorkingDiv();
    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

##############################################################################
# outputFuncGene - output genes in input_file with func_id
# only return count and no output if $res is not defined
##############################################################################
sub outputFuncGene {
    my ( $res, $dbh, $func_id, $folder, $input_file, $data_type, $gene_href ) = @_;

    my %taxon_datatype_h;

    open( FH, "$input_file" )
      or webError("File size - file error $input_file");

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my @gene_oids    = param('gene_oid');
    my $min_gene_oid = 0;
    my $max_gene_oid = 0;
    my $gene_count   = 0;

    if ( $folder eq $GENOME_FOLDER ) {
        my $taxon_cnt = 0;
        my %taxon_hash;
        while ( my $line = <FH> ) {
            chomp($line);
            if ( $taxon_hash{$line} ) {
                # already checked
                next;
            } else {
                $taxon_hash{$line} = 1;
            }

            $taxon_cnt++;
            if ( ( $taxon_cnt % 10 ) == 0 ) {
                print ".";
            }
            if ( ( $taxon_cnt % 1800 ) == 0 ) {
                print "<br/>\n";
            }

            my $taxon_oid = $line;
            my $d2 = 'database';
            if ($in_file) {
                if ( MerFsUtil::isTaxonInFile( $dbh, $taxon_oid ) ) {
                    my $file = $mer_data_dir . "/" . $taxon_oid . "/assembled/taxon_stats.txt";
                    if ( -e $file ) {
                        $file = $mer_data_dir . "/" . $taxon_oid . "/unassembled/taxon_stats.txt";
                        if ( -e $file ) {
                            $d2 = 'both';
                        } else {
                            $d2 = 'assembled';
                        }
                    } else {
                        $d2 = 'unassembled';
                    }
                }
            }
            #print "outputFuncGene() taxon=$taxon_oid d2=$d2 data_type=$data_type in_file=$in_file d2=$d2<br/>\n";

            if ( $d2 eq 'database' ) {

                my ( $sql, @bindList ) =
                  WorkspaceQueryUtil::getDbTaxonFuncGeneSql( $func_id, $taxon_oid, $rclause, $imgClause );
                if ( !$sql ) {
                    next;
                }

                if ($sql) {
                    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
                    for ( ; ; ) {
                        my ( $gene_oid, $func_id2, $t_id, $gene_name ) = $cur->fetchrow();
                        last if ( !$gene_oid );

                        print $res "$gene_oid\n";
                        $gene_count++;
                    }
                    $cur->finish();
                }
            } else {
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled')
                    && ($d2 ne $data_type && $d2 ne 'both') ) {
                        next;
                }

                $taxon_oid = sanitizeInt($taxon_oid);

                my @func_ids;
                if ( $func_id =~ /MetaCyc/i ) {
                    # get MetaCyc enzymes
                    @func_ids = QueryUtil::fetchMetaCyc2Ec( $dbh, $func_id );
                } else {
                    @func_ids = ($func_id);
                }

                for my $func_id2 (@func_ids) {
                    my %func_gene_hash = MetaUtil::getTaxonFuncGenes( $taxon_oid, $data_type, $func_id2 );
                    foreach my $func_gene ( keys %func_gene_hash ) {
                        my $workspace_id = $func_gene_hash{$func_gene};
                        print $res $workspace_id . "\n";
                        $gene_count++;
                    }
                }

            }
        }    # end while line

        return $gene_count;
    } elsif ( $folder eq $SCAF_FOLDER ) {

        # scaffold folder
        my %scaf_hash;
        while ( my $line = <FH> ) {
            chomp($line);

            #print "line: $line<br/>\n";
            if ( $scaf_hash{$line} ) {
                # already checked
                next;
            } else {
                $scaf_hash{$line} = 1;
            }

            my $taxon_oid;
            my $d2;
            my $scaffold_oid;
            if ( WebUtil::isInt($line) ) {
                $scaffold_oid = $line;
                $d2 = "database";
            }
            else {
                ($taxon_oid, $d2, $scaffold_oid)  = split( / /, $line );
            }
            #print "outputFuncGene() scaffold=$scaffold_oid d2=$d2 data_type=$data_type<br/>\n";

            if ( $data_type eq 'database' ) {
                my ( $sql, @bindList ) =
                  WorkspaceQueryUtil::getDbScaffoldFuncGeneSql( $func_id, $scaffold_oid, $rclause, $imgClause );
                if ( !$sql ) {
                    next;
                }

                if ($sql) {
                    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
                    for ( ; ; ) {
                        my ( $gene_oid, $func_id2, $t_id, $gene_name ) = $cur->fetchrow();
                        last if ( !$gene_oid );

                        #print "outputFuncGene() scaffold=$scaffold_oid gene_oid=$gene_oid<br/>\n";
                        if ($res) {
                            print $res "$gene_oid\n";
                        }
                        $gene_count++;
                    }
                    $cur->finish();
                }
            } elsif ( $d2 eq 'assembled' || $d2 eq 'unassembled' ) {
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled')
                    && ($d2 ne $data_type) ) {
                        next;
                }

                my @genes      = ();
                my $key        = "$taxon_oid $d2";
                my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $d2, $scaffold_oid );

                for my $s2 (@genes_on_s) {

                    #my ($gene_oid, $start_coord, $end_coord, $strand) =
                    #split(/\,/, $s2);
                    my (
                        $gene_oid,  $locus_type, $locus_tag, $gene_display_name, $start_coord,
                        $end_coord, $strand,     $seq_id,    $source
                      )
                      = split( /\t/, $s2 );

                    #my $workspace_id = "$taxon_oid $d2 $gene_oid";
                    push @genes, ($gene_oid);
                }

                #print "outputFuncGene() scaffold $scaffold_oid genes: @genes<br/>\n";

                if ( $taxon_datatype_h{$key} ) {
                    my $h_ref = $taxon_datatype_h{$key};
                    for my $gene_oid (@genes) {
                        $h_ref->{$gene_oid} = 1;
                    }
                } else {
                    my %hash2;
                    for my $gene_oid (@genes) {
                        $hash2{$gene_oid} = 1;
                    }
                    $taxon_datatype_h{$key} = \%hash2;
                }
            }
        }    # end while line
    } else {

        # gene folder
        if ( scalar(@gene_oids) == 0 ) {
            while ( my $line = <FH> ) {
                chomp($line);
                push @gene_oids, ($line);
            }
        }

        for my $line (@gene_oids) {

            my $gene_oid;
            my $key;
            if ( WebUtil::isInt($line) ) {
                $gene_oid = $line;
                $key = "database";

                if ( !$min_gene_oid || $gene_oid < $min_gene_oid ) {
                    $min_gene_oid = $gene_oid;
                }
                if ( $gene_oid > $max_gene_oid ) {
                    $max_gene_oid = $gene_oid;
                }
            }
            else {
                my ($taxon_oid, $d2, $gene_oid0)  = split( / /, $line );
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled')
                    && ($d2 ne $data_type) ) {
                        next;
                }
                $gene_oid = $gene_oid0;
                if ( $d2 eq 'assembled' || $d2 eq 'unassembled' ) {
                    $key = "$taxon_oid $d2";
                }
            }

            if ( $taxon_datatype_h{$key} ) {
                my $h_ref = $taxon_datatype_h{$key};
                $h_ref->{$gene_oid} = 1;
            } else {
                my %hash2;
                $hash2{$gene_oid} = 1;
                $taxon_datatype_h{$key}  = \%hash2;
            }
        }    # end while line
    }
    close FH;

    #print "outputFuncGene() taxon_datatype_h:<br/>\n";
    #print Dumper(\%taxon_datatype_h);
    #print "<br/>\n";

    for my $key ( keys %taxon_datatype_h ) {
        my $h_ref = $taxon_datatype_h{$key};
        if ( !$h_ref ) {
            next;
        }

        if ( $key eq 'database' ) {

            # database

            my ( $sql, @bindList ) =
              WorkspaceQueryUtil::getDbFuncGeneSql( $func_id, $min_gene_oid, $max_gene_oid, $rclause, $imgClause );

            if ($sql) {
                my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

                for ( ; ; ) {
                    my ( $gene_oid, $func_id2 ) = $cur->fetchrow();
                    last if ( !$gene_oid );
                    #print "outputFuncGene() gene_oid=$gene_oid<br/>\n";

                    if ( $gene_href->{$gene_oid} ) {
                        # already included
                        #print "outputFuncGene() already in gene_href gene_oid=$gene_oid<br/>\n";
                        next;
                    }
                    $gene_href->{$gene_oid} = 1;

                    if ( $h_ref->{$gene_oid} ) {
                        if ($res) {
                            print $res "$gene_oid\n";
                        }
                        $gene_count++;
                    }
                }
                $cur->finish();
            }
        } else {
            my ( $taxon_oid, $d2 ) = split( / /, $key );
            if ( ($data_type eq 'assembled' || $data_type eq 'unassembled')
                && ($d2 ne $data_type) ) {
                    next;
            }
            my @func_genes = MetaUtil::getTaxonFuncMetaGenes( $taxon_oid, $d2, $func_id );

            for my $gene_oid (@func_genes) {
                if ( $h_ref->{$gene_oid} ) {
                    my $r;
                    my $workspace_id = "$taxon_oid $d2 $gene_oid";

                    if ( $gene_href->{$workspace_id} ) {
                        # already included
                        next;
                    }
                    $gene_href->{$workspace_id} = 1;

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


##############################################################################
# outputFuncsGenes - output genes in input_file with func_id
# only return count and no output if $res is not defined
##############################################################################
sub outputFuncsGenes {
    my ( $res, $dbh, $func_ids_ref, $folder, $input_file, $data_type, $gene_href ) = @_;

    my %taxon_datatype_h;

    my $func_id = @$func_ids_ref[0];
    my $func_tag = MetaUtil::getFuncTagFromFuncId( $func_id );

    open( FH, "$input_file" )
      or webError("File size - file error $input_file");

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my @gene_oids    = param('gene_oid');
    my $min_gene_oid = 0;
    my $max_gene_oid = 0;
    my $gene_count   = 0;

    if ( $folder eq $GENOME_FOLDER ) {
        my %taxon_hash;
        while ( my $line = <FH> ) {
            chomp($line);
            if ( $taxon_hash{$line} ) {
                # already checked
                next;
            } else {
                $taxon_hash{$line} = 1;
            }
            #print "outputFuncsGenes() taxon=$taxon_oid data_type=$data_type<br/>\n";

            my $taxon_oid = $line;
            my $d2 = 'database';
            if ( MerFsUtil::isTaxonInFile( $dbh, $taxon_oid ) ) {
                if ( !$func_tag ) {
                    print "<p>Unknown function ID $func_id\n";
                    next;
                }

                $taxon_oid = sanitizeInt($taxon_oid);
                my $file = $mer_data_dir . "/" . $taxon_oid . "/assembled/taxon_stats.txt";
                if ( -e $file ) {
                    $file = $mer_data_dir . "/" . $taxon_oid . "/unassembled/taxon_stats.txt";
                    if ( -e $file ) {
                        $d2 = 'both';
                    } else {
                        $d2 = 'assembled';
                    }
                } else {
                    $d2 = 'unassembled';
                }

                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled')
                    && ($d2 ne $data_type && $d2 ne 'both') ) {
                        next;
                }

                if ( $func_id =~ /MetaCyc/i ) {
                    my ( $metacyc2ec_href, $ec2metacyc_href ) = QueryUtil::fetchMetaCyc2EcHash( $dbh, $func_ids_ref );
                    my @ec_ids = keys %$ec2metacyc_href;
                    $func_ids_ref = \@ec_ids;
                }

                my @type_list = MetaUtil::getDataTypeList($data_type);
                for my $t2 (@type_list) {
                    my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, $func_tag, $func_ids_ref );
                    for my $func_id ( @$func_ids_ref ) {
                        my @func_genes = split( /\t/, $func_genes{$func_id} );
                        for my $gene_oid (@func_genes) {
                            my $workspace_id = "$taxon_oid $t2 $gene_oid";
                            if ( $gene_href && $gene_href->{$workspace_id} ) {
                                # already in
                            } else {
                                if ($gene_href) {
                                    $gene_href->{$workspace_id} = 1;
                                }
                                if ($res) {
                                    print $res "$workspace_id\n";
                                }
                                $gene_count++;
                            }
                        }
                    }
                }

            }
            else {

                # database
                my ( $sql, @bindList ) = WorkspaceQueryUtil::getDbTaxonFuncsGenesSql( $dbh, $func_ids_ref, $taxon_oid, $rclause, $imgClause );
                if ($sql) {
                    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
                    for ( ; ; ) {
                        my ( $gene_oid, $func_id2, @junk ) = $cur->fetchrow();
                        last if ( !$gene_oid );

                        if ( $gene_href && $gene_href->{$gene_oid} ) {
                            # already in
                        } else {
                            if ($gene_href) {
                                $gene_href->{$gene_oid} = 1;
                            }
                            if ($res) {
                                print $res "$gene_oid\n";
                            }
                            $gene_count++;
                        }
                    }
                    $cur->finish();
                }
            }
        }    # end while line

    }
    elsif ( $folder eq $SCAF_FOLDER ) {

        # scaffold folder
        my %scaf_hash;
        while ( my $line = <FH> ) {
            chomp($line);

            #print "line: $line<br/>\n";
            if ( $scaf_hash{$line} ) {
                # already checked
                next;
            } else {
                $scaf_hash{$line} = 1;
            }
            #print "outputFuncsGenes() scaffold=$line data_type=$data_type<br/>\n";
            $gene_count += outputScaffoldFuncsGenesCore( $dbh, $res, $func_ids_ref, $line, $gene_href );
        }    # end while line

    } else {

        # gene folder
        if ( scalar(@gene_oids) == 0 ) {
            while ( my $line = <FH> ) {
                chomp($line);
                push @gene_oids, ($line);
            }
        }

        for my $line (@gene_oids) {

            my $gene_oid;
            my $key;
            if ( WebUtil::isInt($line) ) {
                $gene_oid = $line;
                $key = "database";

                if ( !$min_gene_oid || $gene_oid < $min_gene_oid ) {
                    $min_gene_oid = $gene_oid;
                }
                if ( $gene_oid > $max_gene_oid ) {
                    $max_gene_oid = $gene_oid;
                }
            }
            else {
                my ($taxon_oid, $d2, $gene_oid0)  = split( / /, $line );
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled')
                    && ($d2 ne $data_type) ) {
                        next;
                }
                $gene_oid = $gene_oid0;
                if ( $d2 eq 'assembled' || $d2 eq 'unassembled' ) {
                    $key = "$taxon_oid $d2";
                }
            }

            if ( $taxon_datatype_h{$key} ) {
                my $h_ref = $taxon_datatype_h{$key};
                $h_ref->{$gene_oid} = 1;
            } else {
                my %hash2;
                $hash2{$gene_oid} = 1;
                $taxon_datatype_h{$key}  = \%hash2;
            }
        }    # end while line

        #print "outputFuncsGenes() taxon_datatype_h:<br/>\n";
        #print Dumper(\%taxon_datatype_h);
        #print "<br/>\n";

        for my $key ( keys %taxon_datatype_h ) {
            my $h_ref = $taxon_datatype_h{$key};
            if ( !$h_ref ) {
                next;
            }

            if ( $key eq 'database' ) {
                # database
                my ( $sql, @bindList ) =
                  WorkspaceQueryUtil::getDbFuncsGenesSql( $dbh, $func_ids_ref, $min_gene_oid, $max_gene_oid, $rclause, $imgClause );

                if ($sql) {
                    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

                    for ( ; ; ) {
                        my ( $gene_oid, $func_id2 ) = $cur->fetchrow();
                        last if ( !$gene_oid );
                        #print "outputFuncGene() gene_oid=$gene_oid<br/>\n";

                        if ( $gene_href->{$gene_oid} ) {
                            # already included
                            #print "outputFuncGene() already in gene_href gene_oid=$gene_oid<br/>\n";
                            next;
                        }
                        $gene_href->{$gene_oid} = 1;

                        if ( $h_ref->{$gene_oid} ) {
                            if ($res) {
                                print $res "$gene_oid\n";
                            }
                            $gene_count++;
                        }
                    }
                    $cur->finish();
                }
            } else {
                if ( !$func_tag ) {
                    print "<p>Unknown function ID $func_id\n";
                    next;
                }

                my ( $taxon_oid, $d2 ) = split( / /, $key );
                if ( ($data_type eq 'assembled' || $data_type eq 'unassembled')
                    && ($d2 ne $data_type) ) {
                        next;
                }

                my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $d2, $func_tag, $func_ids_ref );
                for my $func_id ( @$func_ids_ref ) {
                    my @func_genes = split( /\t/, $func_genes{$func_id} );
                    for my $gene_oid (@func_genes) {
                        my $workspace_id = "$taxon_oid $d2 $gene_oid";
                        if ( $gene_href && $gene_href->{$workspace_id} ) {
                            # already in
                        } else {
                            if ($gene_href) {
                                $gene_href->{$workspace_id} = 1;
                            }
                            if ($res) {
                                print $res "$workspace_id\n";
                            }
                            $gene_count++;
                        }
                    }
                }
            }
        }

    }
    close FH;


    return $gene_count;
}


###############################################################################
# outputTaxonFuncGenes - output genes in taxon_oid with func_id
# only return count and no output if $res is not defined
###############################################################################
sub outputTaxonFuncGenes {
    my ( $dbh, $res, $func_id, $taxon_oid, $data_type, $gene_href ) = @_;

    my $gene_count = 0;

    if ( MerFsUtil::isTaxonInFile( $dbh, $taxon_oid ) ) {
        #print "$taxon_oid data_type: $data_type<br/>\n";
        my @type_list = MetaUtil::getDataTypeList($data_type);
        for my $t2 (@type_list) {
            print "Processing function $func_id ...<br/>\n";
            my @func_genes = MetaUtil::getTaxonFuncMetaGenes( $taxon_oid, $t2, $func_id );

            for my $gene_oid (@func_genes) {
                my $workspace_id = "$taxon_oid $t2 $gene_oid";
                if ($res) {
                    if ( $gene_href && $gene_href->{$workspace_id} ) {
                        # already in
                    } else {
                        print $res "$workspace_id\n";
                        if ($gene_href) {
                            $gene_href->{$workspace_id} = 1;
                        }
                        $gene_count++;
                    }
                }
            }
        }

    } else {
        if ( !$taxon_oid || !WebUtil::isInt($taxon_oid) ) {
            return 0;
        }

        # database
        my ( $sql, @bindList ) = WorkspaceQueryUtil::getDbTaxonFuncGeneSql( $func_id, $taxon_oid );
        if ($sql) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $gene_oid, $func_id2 ) = $cur->fetchrow();
                last if ( !$gene_oid );

                #print "outputTaxonFuncGenes() obtain gene_oid: $gene_oid<br/>\n";
                if ($res) {
                    if ( $gene_href && $gene_href->{$gene_oid} ) {
                        # already in
                    } else {
                        print $res "$gene_oid\n";
                        #print "outputTaxonFuncGenes() $gene_oid added into file<br/>\n";
                        if ($gene_href) {
                            $gene_href->{$gene_oid} = 1;
                        }
                        $gene_count++;
                    }
                }
            }
            $cur->finish();
        }
    }

    return $gene_count;
}

###############################################################################
# outputTaxonFuncsGenes - output genes in taxon_oid with func_ids
# only return count and no output if $res is not defined
###############################################################################
sub outputTaxonFuncsGenes {
    my ( $dbh, $res, $funcs_ids_ref, $taxon_oid, $data_type, $gene_href ) = @_;

    my $gene_count = 0;

    my @func_groups = QueryUtil::groupFuncIdsIntoOneArray( $funcs_ids_ref );
    foreach my $func_ids_ref (@func_groups) {
        $gene_count += outputTaxonFuncsGenesCore( $dbh, $res, $func_ids_ref, $taxon_oid, $data_type, $gene_href );
    }

    return $gene_count;
}

sub outputTaxonFuncsGenesCore {
    my ( $dbh, $res, $func_ids_ref, $taxon_oid, $data_type, $gene_href ) = @_;

    my $gene_count = 0;

    #print "outputTaxonFuncsGenesCore() func_ids_ref: @$func_ids_ref<br/>\n";
    if ( MerFsUtil::isTaxonInFile( $dbh, $taxon_oid ) ) {
        #print "$taxon_oid data_type: $data_type<br/>\n";

        my $func_id = @$func_ids_ref[0];
        my $func_tag = MetaUtil::getFuncTagFromFuncId( $func_id );
        if ( !$func_tag ) {
            print "<p>Unknown function ID $func_id\n";
            next;
        }

        my @type_list = MetaUtil::getDataTypeList($data_type);
        for my $t2 (@type_list) {
            my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, $func_tag, $func_ids_ref );
            for my $func_id ( @$func_ids_ref ) {
                my @func_genes = split( /\t/, $func_genes{$func_id} );
                for my $gene_oid (@func_genes) {
                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    if ($res) {
                        if ( $gene_href && $gene_href->{$workspace_id} ) {
                            # already in
                        } else {
                            print $res "$workspace_id\n";
                            if ($gene_href) {
                                $gene_href->{$workspace_id} = 1;
                            }
                            $gene_count++;
                        }
                    }
                }
            }
        }

    } else {
        if ( !$taxon_oid || !WebUtil::isInt($taxon_oid) ) {
            return 0;
        }

        # database
        my ( $sql, @bindList ) = WorkspaceQueryUtil::getDbTaxonFuncsGenesSql( $dbh, $func_ids_ref, $taxon_oid );
        if ($sql) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $gene_oid, $func_id2, @junk ) = $cur->fetchrow();
                last if ( !$gene_oid );

                #print "outputTaxonFuncsGenesCore() obtain gene_oid: $gene_oid<br/>\n";
                if ($res) {
                    if ( $gene_href && $gene_href->{$gene_oid} ) {
                        # already in
                    } else {
                        print $res "$gene_oid\n";
                        #print "outputTaxonFuncsGenesCore() $gene_oid added into file<br/>\n";
                        if ($gene_href) {
                            $gene_href->{$gene_oid} = 1;
                        }
                        $gene_count++;
                    }
                }
            }
            $cur->finish();
        }
    }

    return $gene_count;
}


###############################################################################
# outputScaffoldFunGenes - output genes in scaffold with func_id
# only return count and no output if $res is not defined
###############################################################################
sub outputScaffoldFuncGenes {
    my ( $dbh, $res, $func_id, $input_scaffold, $gene_href ) = @_;

    # just one scaffold
    my $taxon_oid;
    my $data_type;
    my $scaffold_oid;
    if ( WebUtil::isInt($input_scaffold) ) {
        $scaffold_oid = $input_scaffold;
        $data_type    = "database";
    }
    else {
        ($taxon_oid, $data_type, $scaffold_oid)  = split( / /, $input_scaffold );
    }

    my %taxon_datatype_h;
    my @db_scaffolds;
    my $gene_count = 0;

    my $key = "";
    if ( $data_type eq 'database' ) {
        $key = $data_type;
        push @db_scaffolds, ($scaffold_oid);
    } elsif ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
        $key = "$taxon_oid $data_type";

        # get genes on this scaffold
        my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );

        for my $s2 (@genes_on_s) {
            my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id,
                $source ) = split( /\t/, $s2 );
            #my $workspace_id = "$taxon_oid $data_type $gene_oid";

            if ( $taxon_datatype_h{$key} ) {
                my $h_ref = $taxon_datatype_h{$key};
                $h_ref->{$gene_oid} = 1;
            } else {
                my %hash2;
                $hash2{$gene_oid} = 1;
                $taxon_datatype_h{$key}  = \%hash2;
            }
        }    # end for s2
    }

    # database
    if ( scalar(@db_scaffolds) > 0 ) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my $scaf_str = OracleUtil::getNumberIdsInClause( $dbh, @db_scaffolds );

        my ( $sql, @bindList ) =
          WorkspaceQueryUtil::getDbScaffoldFuncGeneSql( $func_id, $scaf_str, $rclause, $imgClause );
        if ( $sql ) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $gene_oid, $func_id2, $t_id, $gene_name ) = $cur->fetchrow();
                last if ( !$gene_oid );

                #print "scaffold=$scaffold_oid $gene_oid<br/>\n";
                if ($res) {
                    if ( $gene_href && $gene_href->{$gene_oid} ) {
                        # already in
                    } else {
                        print $res "$gene_oid\n";
                        #print "outputScaffoldFuncGenes() $gene_oid added into file<br/>\n";
                        if ($gene_href) {
                            $gene_href->{$gene_oid} = 1;
                        }
                    }
                    $gene_count++;
                }
            }
            $cur->finish();
            OracleUtil::truncTable( $dbh, "gtt_num_id" )
                if ( $scaf_str =~ /gtt_num_id/i );
        }
    }

    # file
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
                if ($res) {
                    if ( $gene_href && $gene_href->{$workspace_id} ) {
                        # already in
                    } else {
                        print $res "$workspace_id\n";
                        if ($gene_href) {
                            $gene_href->{$workspace_id} = 1;
                        }
                    }
                    $gene_count++;
                }
            }
        }
    }

    return $gene_count;
}


###############################################################################
# outputScaffoldFuncsGenes - output genes in scaffold with func_ids
# only return count and no output if $res is not defined
###############################################################################
sub outputScaffoldFuncsGenes {
    my ( $dbh, $res, $funcs_ids_ref, $input_scaffold, $gene_href ) = @_;

    my $gene_count = 0;

    my @func_groups = QueryUtil::groupFuncIdsIntoOneArray( $funcs_ids_ref );
    foreach my $func_ids_ref (@func_groups) {
        $gene_count += outputScaffoldFuncsGenesCore( $dbh, $res, $func_ids_ref, $input_scaffold, $gene_href );
    }

    return $gene_count;
}

sub outputScaffoldFuncsGenesCore {
    my ( $dbh, $res, $func_ids_ref, $input_scaffold, $gene_href ) = @_;

    my $gene_count = 0;

    if ( WebUtil::isInt($input_scaffold) ) {
        # database
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my ( $sql, @bindList ) =
          WorkspaceQueryUtil::getDbScaffoldFuncsGenesSql( $dbh, $func_ids_ref, $input_scaffold, $rclause, $imgClause );
        if ( $sql ) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $gene_oid, @junk ) = $cur->fetchrow();
                last if ( !$gene_oid );

                #print "scaffold=$input_scaffold $gene_oid<br/>\n";
                if ( $gene_href && $gene_href->{$gene_oid} ) {
                    # already in
                } else {
                    if ($gene_href) {
                        $gene_href->{$gene_oid} = 1;
                    }
                    if ($res) {
                        print $res "$gene_oid\n";
                    }
                    $gene_count++;
                }
            }
            $cur->finish();
        }

    }
    else {
        # file
        my $func_id = @$func_ids_ref[0];
        my $func_tag = MetaUtil::getFuncTagFromFuncId( $func_id );
        if ( !$func_tag ) {
            print "<p>Unknown function ID $func_id\n";
            next;
        }

        if ( $func_id =~ /MetaCyc/i ) {
            my ( $metacyc2ec_href, $ec2metacyc_href ) = QueryUtil::fetchMetaCyc2EcHash( $dbh, $func_ids_ref );
            my @ec_ids = keys %$ec2metacyc_href;
            $func_ids_ref = \@ec_ids;
        }

        my %taxon_datatype_h;

        my ($taxon_oid, $data_type, $scaffold_oid)  = split( / /, $input_scaffold );
        if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
            my $key = "$taxon_oid $data_type";

            # get genes on this scaffold
            my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );

            for my $s2 (@genes_on_s) {
                my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id,
                    $source ) = split( /\t/, $s2 );
                #my $workspace_id = "$taxon_oid $data_type $gene_oid";

                if ( $taxon_datatype_h{$key} ) {
                    my $h_ref = $taxon_datatype_h{$key};
                    $h_ref->{$gene_oid} = 1;
                } else {
                    my %hash2;
                    $hash2{$gene_oid} = 1;
                    $taxon_datatype_h{$key}  = \%hash2;
                }
            }    # end for s2
        }

        for my $key ( keys %taxon_datatype_h ) {
            my $h_ref = $taxon_datatype_h{$key};
            if ( !$h_ref ) {
                next;
            }

            my ( $taxon_oid2, $t2 ) = split( / /, $key );
            my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid2, $t2, $func_tag, $func_ids_ref );
            for my $func_id ( @$func_ids_ref ) {
                my @func_genes = split( /\t/, $func_genes{$func_id} );
                for my $gene_oid (@func_genes) {
                    next if ( ! $h_ref->{$gene_oid} );

                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    if ( $gene_href && $gene_href->{$workspace_id} ) {
                        # already in
                    } else {
                        if ($gene_href) {
                            $gene_href->{$workspace_id} = 1;
                        }
                        if ($res) {
                            print $res "$workspace_id\n";
                        }
                        $gene_count++;
                    }
                }
            }
        }

    }

    return $gene_count;
}


###############################################################################
# saveAllTaxonRnaGenes: save all genes of a taxon with certain RNA type
#                       in workspace file
###############################################################################
sub saveAllTaxonRnaGenes {
    my $sid = getContactOid();

    my $taxon_oid   = param("taxon_oid");
    my $data_type   = param("data_type");
    my $locus_type  = param("locus_type");
    my $gene_symbol = param("gene_symbol");

    if ( !$taxon_oid || !$locus_type ) {
        webError("There are no genes to save.");
        return;
    }

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my @rna_type;
    if ( $locus_type eq 'tRNA' ) {
        @rna_type = ('tRNA');
    } elsif ( $locus_type eq 'rRNA' ) {
        @rna_type = ('rRNA');
    } else {
        @rna_type = ( 'tRNA', 'rRNA' );
    }

    my $total = 0;
    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        for my $t3 (@rna_type) {
            my @names;
            if ( $t3 eq 'tRNA' ) {
                @names = ('tRNA');
            } elsif ( $t3 eq 'rRNA' ) {
                if ($gene_symbol) {
                    # 5S, 16S, 23S etc
                    my $name2 = "rRNA_" . $gene_symbol;
                    @names = ($name2);
                } else {
                    # all rRNAs
                    @names = ( 'rRNA_5S', 'rRNA_16S', 'rRNA_18S', 'rRNA_18S', 'rRNA_23S', 'rRNA_other' );
                }
            }

            for my $n2 (@names) {
                my %genes = MetaUtil::getTaxonRnaGenes( $taxon_oid, $t2, $n2 );
                for my $workspace_id ( keys %genes ) {
                    if ( $h2_href->{$workspace_id} ) {
                        #already exist
                    }
                    else {
                        $h2_href->{$workspace_id} = 1;
                        print $res "$workspace_id\n";
                        $total++;
                    }
                }
            }    # end for n2
        }    # end for t3
    }    # end for t2

    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

###############################################################################
# saveAllGeneFuncList
###############################################################################
sub saveAllGeneFuncList {
    my $sid = getContactOid();

    my $taxon_oid   = param("taxon_oid");
    my $data_type   = param("data_type");
    my $func_type   = param('func_type');
    my $filter_type = param('filter_type');
    my $bucket      = param('bucket');

    if (   !$taxon_oid
        || !$data_type
        || !$func_type
        || !$bucket )
    {
        webError("There are no genes to save.");
        return;
    }

    $taxon_oid = sanitizeInt($taxon_oid);
    my $zip_name = $mer_data_dir . "/$taxon_oid/";
    if ( $data_type eq 'assembled' ) {
        $zip_name .= "assembled/gene_";
    } elsif ( $data_type eq 'unassembled' ) {
        $zip_name .= "unassembled/gene_";
    } else {
        webError("No data");
        return;
    }

    my $i2 = "";
    if ( $func_type eq 'cog' ) {
        $zip_name .= "cog_stats.zip";
        $i2 = "cog_" . sanitizeInt($bucket);
    } elsif ( $func_type eq 'pfam' ) {
        $zip_name .= "pfam_stats.zip";
        $i2 = "pfam_" . sanitizeInt($bucket);
    } elsif ( $func_type eq 'tigr' ) {
        $zip_name .= "tigr_stats.zip";
        $i2 = "tigr_" . sanitizeInt($bucket);
    } elsif ( $func_type eq 'ec' ) {
        $zip_name .= "ec_stats.zip";
        $i2 = "ec_" . sanitizeInt($bucket);
    } elsif ( $func_type eq 'ko' ) {
        $zip_name .= "ko_stats.zip";
        $i2 = "ko_" . sanitizeInt($bucket);
    } elsif ( $func_type eq 'phylo' ) {
        $zip_name .= "phylo_stats.zip";
        $i2 = "phylo_" . sanitizeInt($bucket);
    } else {
        webError("No data");
        return;
    }

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $total = 0;
    WebUtil::unsetEnvPath();
    my $fh = newCmdFileHandle( "/usr/bin/unzip -p $zip_name $i2 ", "geneFuncStatsList" );
    while ( my $line = $fh->getline() ) {
        chomp($line);
        my ( $gene_oid, $gene_length, $type2, $func_str ) =
          split( /\t/, $line );
        if ( $filter_type && $filter_type != $type2 ) {
            # skip
            next;
        }

        $total++;
        my $workspace_id = "$taxon_oid $data_type $gene_oid";
        if ( $h2_href->{$workspace_id} ) {
            # already in
        } else {
            print $res "$workspace_id\n";
            $h2_href->{$workspace_id} = 1;
        }
    }
    close $fh;
    close $res;
    WebUtil::resetEnvPath();

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

###############################################################################
# saveAllCDSGeneList
###############################################################################
sub saveAllCDSGeneList {
    my $sid = getContactOid();

    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    if ( !$taxon_oid ) {
        webError("There are no genes to save.");
        return;
    }
    if ( !$data_type ) {
        $data_type = 'both';
    }

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $total = 0;

    WebUtil::unsetEnvPath();

    my $dbh = dbLogin();
    if ( MerFsUtil::isTaxonInFile( $dbh, $taxon_oid ) ) {
        $taxon_oid = sanitizeInt($taxon_oid);
        my @type_list = MetaUtil::getDataTypeList($data_type);
        for my $t2 (@type_list) {
            my %gene_infos = MetaUtil::getGeneInfosForTaxon( $taxon_oid, $t2 );
            for my $workspace_id ( keys %gene_infos ) {
                if ( $h2_href->{$workspace_id} ) {
                    # already in
                } else {
                    my ( $locus_type, $locus_tag, $gene_name, $start_coord, $end_coord, $strand, $scaffold ) =
                      split( /\t/, $gene_infos{$workspace_id} );
                    if ( $locus_type ne 'CDS' ) {
                        next;
                    }

                    print $res "$workspace_id\n";
                    $h2_href->{$workspace_id} = 1;
                }
                $total++;
            }

        }    # end for t2
    }
    else {
        my @gene_oids = QueryUtil::fetchSingleTaxonCDSGenes( $dbh, $taxon_oid);
        #webLog("saveAllCDSGeneList() gene_oids: @gene_oids");
        for my $gene_oid ( @gene_oids ) {
            if ( $h2_href->{$gene_oid} ) {
                # already in
            } else {
                print $res "$gene_oid\n";
                $h2_href->{$gene_oid} = 1;
            }
            $total++;
        }
    }

    WebUtil::resetEnvPath();
    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

###############################################################################
# saveAllRnaGeneList
###############################################################################
sub saveAllRnaGeneList {
    my $sid = getContactOid();

    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    if ( !$taxon_oid ) {
        webError("There are no genes to save.");
        return;
    }
    if ( !$data_type ) {
        $data_type = 'both';
    }

    my $locus_type  = param("locus_type");
    my $gene_symbol = param("gene_symbol");

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $total = 0;

    WebUtil::unsetEnvPath();

    my $dbh = dbLogin();
    if ( MerFsUtil::isTaxonInFile( $dbh, $taxon_oid ) ) {
        $taxon_oid = sanitizeInt($taxon_oid);
        my @type_list = MetaUtil::getDataTypeList($data_type);
        for my $t2 (@type_list) {
            #to be implemented
        }    # end for t2
    }
    else {
        my @gene_oids = QueryUtil::fetchSingleTaxonRnaGenes( $dbh, $taxon_oid, $locus_type, $gene_symbol);
        for my $gene_oid ( @gene_oids ) {
            if ( $h2_href->{$gene_oid} ) {
                # already in
            } else {
                print $res "$gene_oid\n";
                $h2_href->{$gene_oid} = 1;
            }
            $total++;
        }
    }

    WebUtil::resetEnvPath();
    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}


###############################################################################
# saveAllGeneProdList
###############################################################################
sub saveAllGeneProdList {

    my $sid = getContactOid();

    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    if ( !$taxon_oid ) {
        webError("There are no genes to save.");
        return;
    }
    if ( !$data_type ) {
        $data_type = 'both';
    }

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $total = 0;

    my $dbh = dbLogin();
    if ( MerFsUtil::isTaxonInFile( $dbh, $taxon_oid ) ) {
        $taxon_oid = sanitizeInt($taxon_oid);
        my @type_list = MetaUtil::getDataTypeList($data_type);
        for my $t2 (@type_list) {

            my (%names) = MetaUtil::getGeneProdNamesForTaxon( $taxon_oid, $t2 );
            for my $gene_oid ( keys %names ) {
                $total++;
                my $workspace_id = "$taxon_oid t2 $gene_oid";
                if ( $h2_href->{$workspace_id} ) {
                    # already in
                } else {
                    print $res "$workspace_id\n";
                    $h2_href->{$workspace_id} = 1;
                }
            }
        }
    }
    else {
        my @gene_oids = QueryUtil::fetchSingleTaxonGenesWithFunc( $dbh, $taxon_oid);
        for my $gene_oid ( @gene_oids ) {
            if ( $h2_href->{$gene_oid} ) {
                # already in
            } else {
                print $res "$gene_oid\n";
                $h2_href->{$gene_oid} = 1;
            }
            $total++;
        }
    }

    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

###############################################################################
# saveAllGeneWithoutFuncList
###############################################################################
sub saveAllGeneWithoutFuncList {

    execSaveAllGeneList( 'WithoutFunc' );
}

###############################################################################
# saveAllNoEnzymeWithKOGenes
###############################################################################
sub saveAllNoEnzymeWithKOGenes {

    saveAllNoEnzymeWithKOGenes( 'Missing' );
}

###############################################################################
# saveAllKeggCategoryGeneList
###############################################################################
sub saveAllKeggCategoryGeneList {

    execSaveAllGeneList( 'KeggCategory' );
}

###############################################################################
# saveAllKeggPathwayGeneList
###############################################################################
sub saveAllKeggPathwayGeneList {

    execSaveAllGeneList( 'KeggPathway' );
}

###############################################################################
# saveAllNonKeggGeneList
###############################################################################
sub saveAllNonKeggGeneList {

    execSaveAllGeneList( 'NonKegg' );
}

###############################################################################
# saveAllNonKoGeneList
###############################################################################
sub saveAllNonKoGeneList {

    execSaveAllGeneList( 'NonKo' );
}

###############################################################################
# saveAllNonMetacycGeneList
###############################################################################
sub saveAllNonMetacycGeneList {

    execSaveAllGeneList( 'NonMetacyc' );
}

###############################################################################
# saveAllCKogCatGenes
###############################################################################
sub saveAllCKogCatGenes {

    execSaveAllGeneList( 'CKogCat' );
}

###############################################################################
# saveAllPfamCatGenes
###############################################################################
sub saveAllPfamCatGenes {

    execSaveAllGeneList( 'PfamCat' );
}

###############################################################################
# saveAllTIGRfamCatGenes
###############################################################################
sub saveAllTIGRfamCatGenes {

    execSaveAllGeneList( 'TIGRfamCat' );
}

###############################################################################
# saveAllImgTermCatGenes
###############################################################################
sub saveAllImgTermCatGenes {

    execSaveAllGeneList( 'ImgTermCat' );
}

###############################################################################
# saveAllClusterGenes
###############################################################################
sub saveAllClusterGenes {

    execSaveAllGeneList( 'Cluster' );
}

###############################################################################
# saveAllCassetteGenes
###############################################################################
sub saveAllCassetteGenes {

    execSaveAllGeneList( 'Cassette' );
}

###############################################################################
# saveAllCassetteOccurrenceGenes
###############################################################################
sub saveAllCassetteOccurrenceGenes {

    execSaveAllGeneList( 'Occurrence' );
}

###############################################################################
# saveAllFusedGenes
###############################################################################
sub saveAllFusedGenes {

    execSaveAllGeneList( 'Fused' );
}

###############################################################################
# saveAllSignalGenes
###############################################################################
sub saveAllSignalGenes {

    execSaveAllGeneList( 'Signal' );
}

###############################################################################
# saveAllTransmembraneGenes
###############################################################################
sub saveAllTransmembraneGenes {

    execSaveAllGeneList( 'Transmembrane' );
}

###############################################################################
# saveAllBiosyntheticGenes
###############################################################################
sub saveAllBiosyntheticGenes {

    execSaveAllGeneList( 'Biosynthetic' );
}

###############################################################################
# execSaveAllGeneList
###############################################################################
sub execSaveAllGeneList {
    my ( $type ) = @_;

    my $sid = getContactOid();

    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    if ( !$taxon_oid && $type !~ /Cluster/i ) {
        webError("There are no genes to save.");
        return;
    }
    if ( !$data_type ) {
        $data_type = 'both';
    }

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $total = 0;

    my $dbh = dbLogin();
    if ( MerFsUtil::isTaxonInFile( $dbh, $taxon_oid ) ) {
        $taxon_oid = sanitizeInt($taxon_oid);
        my @type_list = MetaUtil::getDataTypeList($data_type);
        for my $t2 (@type_list) {
            #to be implemented
        }
    }
    else {
        my @gene_oids;
        if ( $type =~ /WithoutFunc/i ) {
            @gene_oids = QueryUtil::fetchSingleTaxonGenesWithoutFunc( $dbh, $taxon_oid );
        }
        elsif ( $type =~ /Missing/i ) {
            @gene_oids = QueryUtil::fetchSingleTaxonNoEnzymeWithKOGenes( $dbh, $taxon_oid );
        }
        elsif ( $type =~ /KeggCategory/i ) {
            my $category   = param("category");
            my $cluster_id = param("cluster_id");    # biosynthetic cluster
            @gene_oids = QueryUtil::fetchSingleTaxonKeggCategoryGenes( $dbh, $taxon_oid, $category, $cluster_id );
        }
        elsif ( $type =~ /KeggPathway/i ) {
            my $pathway_oid = param("pathway_oid");
            @gene_oids = QueryUtil::fetchSingleTaxonKeggPathwayGenes( $dbh, $taxon_oid, $pathway_oid );
        }
        elsif ( $type =~ /NonKegg/i ) {
            @gene_oids = QueryUtil::fetchSingleTaxonNonKeggGenes( $dbh, $taxon_oid );
        }
        elsif ( $type =~ /NonKo/i ) {
            @gene_oids = QueryUtil::fetchSingleTaxonNonKoGenes( $dbh, $taxon_oid );
        }
        elsif ( $type =~ /NonMetacyc/i ) {
            @gene_oids = QueryUtil::fetchSingleTaxonNonMetacycGenes( $dbh, $taxon_oid );
        }
        elsif ( $type =~ /CKogCat/i ) {
            my $function_code = param("function_code");
            my $og = param("og");
            @gene_oids = QueryUtil::fetchSingleTaxonCKogCatGenes( $dbh, $taxon_oid, $function_code, $og );
        }
        elsif ( $type =~ /PfamCat/i ) {
            my $func_code = param("func_code");
            @gene_oids = QueryUtil::fetchSingleTaxonPfamCatGenes( $dbh, $taxon_oid, $func_code );
        }
        elsif ( $type =~ /TIGRfamCat/i ) {
            my $role = param("role");
            @gene_oids = QueryUtil::fetchSingleTaxonTIGRfamCatGenes( $dbh, $taxon_oid, $role );
        }
        elsif ( $type =~ /ImgTermCat/i ) {
            my $term_oid = param("term_oid");
            @gene_oids = QueryUtil::fetchSingleTaxonImgTermCatGenes( $dbh, $taxon_oid, $term_oid );
        }
        elsif ( $type =~ /Cluster/i ) {
            my @cluster_id = param("cluster_id");
            @gene_oids = QueryUtil::fetchClusterGenes( $dbh, \@cluster_id );
        }
        elsif ( $type =~ /Cassette/i ) {
            @gene_oids = QueryUtil::fetchSingleTaxonCassetteGenes( $dbh, $taxon_oid );
        }
        elsif ( $type =~ /Occurrence/i ) {
            my $gene_count = param("genecount");
            @gene_oids = QueryUtil::fetchSingleTaxonCassetteOccurrenceGenes( $dbh, $taxon_oid, $gene_count );
        }
        elsif ( $type =~ /Fused/i ) {
            @gene_oids = QueryUtil::fetchSingleTaxonFusedGenes( $dbh, $taxon_oid );
        }
        elsif ( $type =~ /Signal/i ) {
            @gene_oids = QueryUtil::fetchSingleTaxonSignalGenes( $dbh, $taxon_oid );
        }
        elsif ( $type =~ /Transmembrane/i ) {
            @gene_oids = QueryUtil::fetchSingleTaxonTransmembraneGenes( $dbh, $taxon_oid );
        }
        elsif ( $type =~ /Biosynthetic/i ) {
            @gene_oids = QueryUtil::fetchSingleTaxonBiosyntheticGenes( $dbh, $taxon_oid );
        }

        for my $gene_oid ( @gene_oids ) {
            if ( $h2_href->{$gene_oid} ) {
                # already in
            } else {
                print $res "$gene_oid\n";
                $h2_href->{$gene_oid} = 1;
                $total++;
            }
        }
    }

    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}


###############################################################################
# prepareSaveToWorkspace
###############################################################################
sub prepareSaveToWorkspace {
    my ( $sid, $folder ) = @_;

    my $filename = param("workspacefilename");

    my $ws_save_mode = param('ws_save_mode');
    if (   $ws_save_mode eq 'append'
        || $ws_save_mode eq 'replace' )
    {
        $filename = param("selectedwsfilename");
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
    if ( $ws_save_mode eq 'save'
        && -e "$workspace_dir/$sid/$folder/$filename" )
    {
        webError("File name $filename already exists. Please enter a new file name.");
        return;
    }

    my $res;
    my %h2;
    if ( $ws_save_mode eq 'append' ) {
        my $fh = newReadFileHandle("$workspace_dir/$sid/$folder/$filename");
        while ( my $id = $fh->getline() ) {
            chomp $id;
            next if ( $id eq "" );
            $h2{$id} = 1;
        }
        close $fh;

        $res = newAppendFileHandle("$workspace_dir/$sid/$folder/$filename");
    } else {
        $res = newWriteFileHandle("$workspace_dir/$sid/$folder/$filename");
    }

    return ($filename, $res, \%h2);
}

###############################################################################
# printWorkspaceSetDetail
###############################################################################
sub printWorkspaceSetDetail {
    my $filename = param("filename");
    my $folder   = param("folder");

    printMainForm();

    print "<h1>Workspace $folder set: " . escapeHTML($filename) . "</h1>\n";

    print hiddenVar( "folder",   $folder );
    print hiddenVar( "filename", $filename );

    my $sid        = getContactOid();
    my $super_user = getSuperUser();
    if ( $super_user eq 'Yes' ) {
        @subfolders = ( $GENE_FOLDER, $FUNC_FOLDER, $SCAF_FOLDER, $GENOME_FOLDER, $BC_FOLDER, $RULE_FOLDER );
    }

    # check filename
    if ( $filename eq "" ) {
        webError("Cannot read file.");
        return;
    }

    my $valid = 0;
    foreach my $x (@subfolders) {
        if ( $folder eq $x ) {
            $valid = 1;
            last;
        }
    }
    if ( !$valid ) {
        webError("Invalid directory ($folder).");
    }

    WebUtil::checkFileName($filename);

    # this also untaints the name
    $filename = WebUtil::validFileName($filename);

    my $select_id_name = "func_id";
    if ( $folder eq $GENOME_FOLDER ) {
        $select_id_name = "taxon_oid";
    } elsif ( $folder eq $GENE_FOLDER ) {
        $select_id_name = "gene_oid";
    }
    if ( $folder eq $SCAF_FOLDER ) {
        $select_id_name = "scaffold_oid";
    }

    print "<p>\n";
    my %names;
    my @db_ids = ();

    my $row   = 0;
    my $trunc = 0;
    my $res   = newReadFileHandle("$workspace_dir/$sid/$folder/$filename");
    while ( my $id = $res->getline() ) {

        # set a limit so that it won't crash web browser
        if ( $row >= $max_workspace_view ) {
            $trunc = 1;
            last;
        }

        chomp $id;
        next if ( $id eq "" );

        # $names{$id} = $id;
        $names{$id} = 0;

        if ( WebUtil::isInt($id) ) {
            push @db_ids, ($id);
        } elsif ( $folder eq $FUNC_FOLDER ) {
            push @db_ids, ( "'" . $id . "'" );
        }
        $row++;
    }
    close $res;

    my $dbh = dbLogin();
    my %taxons_in_file;
    if ($in_file) {
        %taxons_in_file = MerFsUtil::getTaxonsInFile($dbh);
    }

    my %taxon_name_h;
    my %taxon_h;
    if ( scalar(@db_ids) > 0 ) {
        my $cnt0   = scalar(@db_ids);
        my $db_str = "";
        my $cnt1   = 0;
        for my $id1 (@db_ids) {
            if ($db_str) {
                $db_str .= ", " . $id1;
            } else {
                $db_str = $id1;
            }

            $cnt1++;
            if ( ( $cnt1 % 1000 ) == 0 || ( $cnt1 == $cnt0 ) ) {
                my $sql;
                if ( $folder eq $GENOME_FOLDER ) {
                    my ($rclause) = WebUtil::urClause('tx');
                    my $imgClause = WebUtil::imgClause('tx');
                    $sql = qq{
                        select tx.taxon_oid, tx.taxon_display_name
                        from taxon tx
                        where tx.taxon_oid in ($db_str)
                        $rclause
                        $imgClause
                    };
                } elsif ( $folder eq $GENE_FOLDER ) {
                    my $rclause   = WebUtil::urClause('g.taxon');
                    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
                    $sql = qq{
                        select g.gene_oid, g.gene_display_name, g.taxon
                        from gene g
                        where g.gene_oid in ($db_str)
                        $rclause
                        $imgClause
                    };
                } elsif ( $folder eq $SCAF_FOLDER ) {
                    my $rclause   = WebUtil::urClause('s.taxon');
                    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
                    $sql = qq{
                        select s.scaffold_oid, s.scaffold_name, s.taxon
                        from scaffold s
                        where s.scaffold_oid in ($db_str)
                        $rclause
                        $imgClause
                    };
                } else {

                    # functions
                    if ( $cnt1 == $cnt0 ) {
                        my %funcId2Name = QueryUtil::fetchFuncIdAndName( $dbh, \@db_ids );
                        for my $id2 ( keys %funcId2Name ) {
                            my $name2 = $funcId2Name{$id2};
                            $names{$id2} = $name2;
                        }
                    }
                }

                if ($sql) {
                    my $cur = execSql( $dbh, $sql, $verbose );
                    for ( ; ; ) {
                        my ( $id2, $name2, $t_oid ) = $cur->fetchrow();
                        last if !$id2;
                        $names{$id2} = $name2;
                        if ($t_oid) {
                            $taxon_h{$id2} = $t_oid;
                        }
                    }
                    $cur->finish();
                }
                $db_str = "";
            }
        }
    }

    my $show_gene_name = 1;
    my @keys           = ( keys %names );

    if ( $folder eq $GENE_FOLDER && scalar(@keys) > 100 ) {
        printHint(
"Gene names of large gene sets are not displayed. Use 'Exapnd Gene Table Display' option below to view detailed gene information."
        );
        $show_gene_name = 0;
    }

    if ( $folder eq $GENE_FOLDER && $show_gene_name ) {
        printStartWorkingDiv();
        print "Retrieving gene information ...<br/>\n";
    }

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "ID",   "char asc", "left" );
    $it->addColSpec( "Name", "char asc", "left" );
    if ( $folder eq $GENE_FOLDER || $folder eq $SCAF_FOLDER ) {
        $it->addColSpec( "Genome", "char asc", "left" );
    }
    my $sd = $it->getSdDelim();

    my $can_select = 0;
    for my $id (@keys) {
        my $r;
        my $url;
        my $display_id = $id;

        if ( $folder eq $GENE_FOLDER ) {
            my ( $taxon3, $type3, $id3 ) = split( / /, $id );
            if ( ( $type3 eq 'assembled' || $type3 eq 'unassembled' )
                && $taxons_in_file{$taxon3} )
            {
                $taxon_h{$id} = $taxon3;
                if ( !$names{$id} ) {
                    if ($show_gene_name) {
                        print ".";
                        my ( $new_name, $source ) = MetaUtil::getGeneProdNameSource( $id3, $taxon3, $type3 );
                        if ($new_name) {
                            $names{$id} = $new_name;
                        } else {
                            $names{$id} = "-";
                        }
                    } else {
                        $names{$id} = "-";
                    }
                }
            }
        } elsif ( $folder eq $SCAF_FOLDER ) {
            my ( $taxon3, $type3, $id3 ) = split( / /, $id );
            if ( ( $type3 eq 'assembled' || $type3 eq 'unassembled' )
                && $taxons_in_file{$taxon3} )
            {
                $taxon_h{$id} = $taxon3;
                if ( !$names{$id} ) {
                    $names{$id} = $id;
                }
            }
        }

        if ( $names{$id} ) {
            $can_select++;
            $r = $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";

            # determine URL
            if ( $folder eq $GENOME_FOLDER ) {
                if ( $taxons_in_file{$id} ) {
                    $url = "$main_cgi?section=MetaDetail"
                        . "&page=metaDetail&taxon_oid=$id";
                } else {
                    $url = "$main_cgi?section=TaxonDetail"
                        . "&page=taxonDetail&taxon_oid=$id";
                }
            } elsif ( $folder eq $GENE_FOLDER ) {
                my ( $t1, $d1, $g1 ) = split( / /, $id );
                if ( !$g1 && WebUtil::isInt($t1) ) {
                    $url = "$main_cgi?section=GeneDetail"
                        . "&page=geneDetail&gene_oid=$t1";
                } else {
                    $display_id = $g1;
                    $url = "$main_cgi?section=MetaGeneDetail"
                        . "&page=metaGeneDetail&taxon_oid=$t1"
                        . "&data_type=$d1&gene_oid=$g1";
                }
            } elsif ( $folder eq $SCAF_FOLDER ) {
                my ( $t1, $d1, $g1 ) = split( / /, $id );
                if ( !$g1 && WebUtil::isInt($t1) ) {
                    $url = "$main_cgi?section=ScaffoldCart"
                        . "&page=scaffoldDetail&scaffold_oid=$t1";
                } else {
                    $display_id = $g1;
                    $url = "$main_cgi?section=MetaDetail&page=metaScaffoldDetail"
                      . "&taxon_oid=$t1&scaffold_oid=$g1&data_type=$d1";
                }
            } else {

                # functions
                if ( $id =~ /^COG/ ) {
                    $url = "$cog_base_url$id";
                } elsif ( $id =~ /^pfam/ ) {
                    my $func_id2 = $id;
                    $func_id2 =~ s/pfam/PF/;
                    $url = "$pfam_base_url$func_id2";
                } elsif ( $id =~ /^TIGR/ ) {
                    $url = "$tigrfam_base_url$id";
                } elsif ( $id =~ /^EC:/ ) {
                    my $func_id2 = $id;
                    $func_id2 =~ s/EC://;
                    $url = "$enzyme_base_url$id";
                } elsif ( $id =~ /^KO:/ ) {
                    $url = $kegg_orthology_url . $id;
                }
            }

            if ($url) {
                $r .= $id . $sd . alink( $url, $display_id ) . "\t";
            } else {
                $r .= $id . $sd . $id . "\t";
            }

            $r .= $names{$id} . $sd . $names{$id} . "\t";

            if ( $folder eq $GENE_FOLDER || $folder eq $SCAF_FOLDER ) {
                if ( $taxon_h{$id} ) {
                    my $t_oid     = $taxon_h{$id};
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
                    $r .= $t_oid . $sd . "<a href=\"$taxon_url\" >" . $taxon_name . "</a> \t";
                } else {
                    $r .= "-" . $sd . "-" . "\t";
                }
            }
        } else {

            # not in database
            $r = $sd . " \t" . $id . $sd . $id . "\t" . "(not in this database)" . $sd . "(not in this database)" . "\t";
            if ( $folder eq $GENE_FOLDER || $folder eq $SCAF_FOLDER ) {
                $r .= "-" . $sd . "-" . "\t";
            }
        }

        $it->addRow($r);
    }

    #$dbh->disconnect();

    if ( $folder eq $GENE_FOLDER && $show_gene_name ) {
        printEndWorkingDiv();
    }

    $it->printOuterTable(1);

    if ( $folder eq $GENE_FOLDER && !$show_gene_name ) {
        printHint(
"Gene names of large gene sets are not displayed. Use 'Exapnd Gene Table Display' option below to view detailed gene information."
        );
    }

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

    printStatusLine( $load_msg, 2 );

    if ( $can_select <= 0 ) {
        print end_form();
        return;
    }

    print "<p>\n";
    WebUtil::printButtonFooter();

    if ( $folder eq $GENE_FOLDER ) {
        MetaGeneTable::printMetaGeneTableSelect();
    }

    if ( $folder eq $GENOME_FOLDER ) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    } elsif ( $folder eq $GENE_FOLDER ) {
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    } elsif ( $folder eq $SCAF_FOLDER ) {
        WorkspaceUtil::printSaveScaffoldToWorkspace($select_id_name);
    } else {

        # functions
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printSetOpSection( $filename, $folder );

    print end_form();
}

###############################################################################
# printSetOpSection: print set operation (difference, intersection)
###############################################################################
sub printSetOpSection {
    my ( $filename, $folder ) = @_;

    my $sid = getContactOid();

    opendir( DIR, "$workspace_dir/$sid/$folder" )
      or webDie("failed to open folder list");
    my @files = readdir(DIR);
    closedir(DIR);

    my @names = ();
    for my $name ( sort @files ) {
        if ( $name ne "." && $name ne ".." && $name ne $filename ) {
            push @names, ($name);
        }
    }
    if ( scalar(@names) == 0 ) {

        # no other files
        return;
    }

    print "<h2>Create New Set Using Set Operations</h2>\n";

    print "<p>\n";
    print "<input type='radio' name='set_select_mode' value='all' checked/>\n";
    print "All " . $folder . "s in the set.<br/>\n";
    print "<input type='radio' name='set_select_mode' value='only_selected' />\n";
    print "Only <u>selected</u> " . $folder . "s in the set. <br/>\n";

    print "<p>Operation: &nbsp\n";
    print "<select name='setoptype' style='width:150px;' >\n";
    print "<option value='minus'> Set Difference </option> \n";
    print "<option value='intersect'> Set Intersection </option> \n";
    print "<option value='union'> Set Union </option> \n";
    print "</select>\n";

    print "<p>Second $folder set: &nbsp\n";
    print "<select name='setopname2' >\n";
    for my $name2 (@names) {
        print "<option value='$name2'  selected='selected'> $name2 </option> \n";
    }
    print "</select>\n";

    my $errMsg = "Please enter a file name.";
    print "<p><i> Special characters in file name will be removed and spaces converted to _ </i>\n";
    print "<p>File name:<br/>\n";
    print "<input type='text' size='$filename_size' maxLength='$filename_len' "
      . "name='op_res_filename' "
      . "title='All special characters will be removed and spaces converted to _ ' />\n";
    print "<br/>";
    print "<input class='medbutton' type='submit' name='_section_Workspace_saveSetOp' "
      . "value='Save Result to Workspace' onClick= 'return isFilled(\"op_res_filename\", \"$errMsg\");' />\n";

}

############################################################################
# printSetOperation - Prints Union or Intersection of Sets
#                     input: set type: "gene"|"function"|"genome"|"scaffold"
############################################################################
sub printSetOperation {
    my ( $folder, $sid ) = @_;

    print "<h2>Union or Intersection of Sets</h2>\n";
    print "<p>You may select two or more $folder sets from the table above to get their union or intersection.\n";
    print "</p>\n";

    print "<p>\n";
    if ( $folder eq $GENOME_FOLDER || $folder eq $GENE_FOLDER || $folder eq $SCAF_FOLDER ) {
        HtmlUtil::printMetaDataTypeChoice('_s', '', '', 1);
    }
    print "</p>\n";
    print "<p>\n";
    print "Save to File name:  \n";
    print "<input type='text' size='$filename_size' maxLength='$filename_len' "
      . "name='workspacefilename' "
      . "title='All special characters will be removed and spaces converted to _ ' />\n";
    print "<br/>";
    print "(<i>Special characters in file name will be removed and spaces converted to _ </i>)\n";
    print "<br/>";
    print submit(
        -name    => "_section_Workspace_saveIntersection",
        -value   => "Save Intersection to Workspace",
        -class   => "medbutton",
        -onClick => "return checkTwoSetsIncludingShareAndFilled('workspacefilename', '$folder');"
    );
    print nbsp(1);
    print submit(
        -name    => "_section_Workspace_saveUnion",
        -value   => "Save Union to Workspace",
        -class   => "medbutton",
        -onClick => "return checkTwoSetsIncludingShareAndFilled('workspacefilename', '$folder');"
    );
    print "</p>\n";

    if ( !$sid ) {
        $sid = getContactOid();
    }

    opendir( DIR, "$workspace_dir/$sid/$folder" )
      or webDie("failed to open folder list");
    my @files = readdir(DIR);
    closedir(DIR);

    ## my own
    my %names_h = ();
    my @names = ();
    for my $name ( sort @files ) {
        if ( $name ne "." && $name ne ".." ) {
            #my $fullName = WorkspaceUtil::getOwnerFilesetFullName( $sid, $name );
            my $fullName = $name;
    	    $names_h{$fullName} = $name;
    	    push @names, ( $fullName );
        }
    }
    ## share
    my %share_from_h = WorkspaceUtil::getShareFromGroups($folder);
    for my $k (keys %share_from_h) {
        my ($c_oid, $data_set_name) = WorkspaceUtil::splitOwnerFileset( $sid, $k );
        my ($g_id, $g_name, $c_name) = split(/\t/, $share_from_h{$k});

    	$names_h{$k} = $data_set_name . " (owner: $c_name)";
    	push @names, ( $k );
    }
    if ( scalar(@names) == 0 ) {
        # no other files
        return;
    }

    print "<h2>Difference of Two Sets (First - Second)</h2>\n";

    print "<p>First $folder set: &nbsp\n";
    print "<select name='setopname1' >\n";
    for my $name1 (@names) {
        print "<option value='$name1' >" . $names_h{$name1} .
	    "</option> \n";
    }
    print "</select>\n";
    print "</p>\n";

    print "<p>Second $folder set: &nbsp\n";
    print "<select name='setopname2' >\n";
    for my $name2 (@names) {
        print "<option value='$name2' >" . $names_h{$name2} .
	    "</option> \n";
    }
    print "</select>\n";
    print "</p>\n";

    my $errMsg = "Please enter a file name.";
    print "<p>Save to File name:  \n";
    print "<input type='text' size='$filename_size' maxLength='$filename_len' "
      . "name='op_res_filename' "
      . "title='All special characters will be removed and spaces converted to _ ' />\n";
    print "<br/>";
    print "(<i>Special characters in file name will be removed and spaces converted to _ </i>)\n";
    print "<br/>";
    print "<input class='medbutton' type='submit' name='_section_Workspace_saveSetOpMinus' "
      . "value='Save Difference to Workspace' onClick= 'return isFilled(\"op_res_filename\", \"$errMsg\");' />\n";
    print "</p>\n";

}

#############################################################################
# printBreakLargeSet
#############################################################################
sub printBreakLargeSet {
    my ( $contact_oid, $folder ) = @_;

    if ( !$contact_oid ) {
        $contact_oid = getContactOid();
    }
    return if ( !$contact_oid );

    # workspace
    if ( $user_restricted_site && !$public_nologin_site ) {

        #my $what = ucfirst( lc($folder) );
	my $extra_text = "";
	my $grpCnt = WorkspaceUtil::getContactImgGroupCnt();
	if ( $grpCnt > 0 ) {
	    $extra_text = "<u>your own</u>";
	}
        print "<h2>Break Large Set</h2>";
        print qq{
            <p>
            Break the selected $extra_text large
            $folder set to smaller sets in
            <a href="$main_cgi?section=Workspace">My Workspace</a>.
            <br/>
            (<i>Suffixes '_' and number will be placed to the large set name as small set names </i>)
            <br/>
        };

        print "<p>\n";

        my @break_sizes = ( 20000, 10000, 5000, 1000, 500 );
        print "Break the large set into the following size: ";
        print "<select name='breaksize'>\n";
        for my $num (@break_sizes) {
            print "<option value='$num'>$num</option>\n";
        }
        print "</select>\n";

        print "<br/>";
        my $name = "_section_Workspace_breakLargeSet";
        print submit(
            -name    => $name,
            -value   => "Break Large Set",
            -class   => "lgbutton",
            -onClick => "return checkOneSet('$folder');"
        );

        print "</p>\n";
    }
}

###############################################################################
# saveAllDbScafGenes: save all genes in a db scaffold to gene set
###############################################################################
sub saveAllDbScafGenes {
    my $sid          = getContactOid();
    my $scaffold_oid = param("scaffold_oid");

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $dbh   = dbLogin();
    my $sql   = getSingleScaffoldGenesSql();
    my $cur   = execSql( $dbh, $sql, $verbose, $scaffold_oid );

    my $total = 0;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        if ( $h2_href->{$gene_oid} ) {
            # already in
            next;
        } else {
            print $res "$gene_oid\n";
            $h2_href->{$gene_oid} = 1;
        }
        $total++;
    }
    $cur->finish();

    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

###############################################################################
# saveAllMetaScafGenes: save all genes in a file scaffold to gene set
###############################################################################
sub saveAllMetaScafGenes {
    my $sid          = getContactOid();
    my $taxon_oid    = param("taxon_oid");
    my $scaffold_oid = param("scaffold_oid");
    my $data_type    = 'assembled';

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );

    my $total  = 0;
    for my $s2 (@genes_on_s) {
        my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id, $source ) =
          split( /\t/, $s2 );
        my $workspace_id = "$taxon_oid $data_type $gene_oid";
        if ( $h2_href->{$workspace_id} ) {
            # already in
        } else {
            print $res "$workspace_id\n";
            $h2_href->{$workspace_id} = 1;
            $total++;
        }
    }

    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

###############################################################################
# saveAllMetaHits - save all genes in a metagenome best hits list to
#                        workspace file
###############################################################################
sub saveAllMetaHits {
    my $sid = getContactOid();

    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    if ( !$taxon_oid ) {
        webError("There are no genes to save.");
        return;
    }

    my $percent_identity = param("percent_identity");
    my $domain           = param("domain");
    my $phylum           = param("phylum");
    my $ir_class         = param("ir_class");
    my $ir_order         = param("ir_order");
    my $family           = param("family");
    my $genus            = param("genus");
    my $species          = param("species");
    my $plus             = param("plus");

    my $plusSign = $plus ? "+" : "";    # to show "+" in titles when cumulative
    $domain           = MetaUtil::sanitizePhylum2($domain);
    $phylum           = MetaUtil::sanitizePhylum2($phylum);
    $ir_class         = MetaUtil::sanitizePhylum2($ir_class);
    $taxon_oid        = sanitizeInt($taxon_oid);
    $percent_identity = sanitizeInt($percent_identity);

    # workspace
    if ($enable_workspace) {
        print WebUtil::getHtmlBookmark( "workspace", "<h2>Save to My Workspace</h2>" );
        print qq{
        <p>
        <a href="$main_cgi?section=Workspace">My Workspace ($taxon_oid $data_type)</a>
        <br/>
        <i> Special characters in file name will be removed and spaces converted to _ </i>
        <br/>
        };
    }

    my $folder = $GENE_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    # array of arrays rec data
    my $dir_name = substr( $domain, 0, 1 ) . $phylum . $ir_class;
    $dir_name =~ s/\s+//g;    # remove space
    $dir_name =~ s/\"//g;     # remove double quote

    my @percent_list = ($percent_identity);
    if ($plus) {
        if ( $percent_identity == 30 ) {
            @percent_list = ( 30, 60, 90 );
        } elsif ( $percent_identity == 60 ) {
            @percent_list = ( 60, 90 );
        }
    }

    my $total = 0;
    my $dbh   = dbLogin();

    my @binds   = ( $domain, $phylum );
    my $rclause = WebUtil::urClause('t.taxon_oid');
    my $sql     =
        "select t.taxon_oid, t.taxon_display_name, "
      . "t.family, t.genus, t.species from taxon t "
      . "where t.domain = ? and t.phylum = ? ";
    if ($ir_class) {
        $sql .= " and t.ir_class = ? ";
        push @binds, ($ir_class);
    }
    if ($family) {
        $sql .= " and t.family = ? ";
        push @binds, ($family);
    }
    if ($genus) {
        $sql .= " and t.genus = ? ";
        push @binds, ($genus);
    }
    if ($species) {
        $sql .= " and t.species = ? ";
        push @binds, ($species);
    }
    $sql .= " and t.obsolete_flag = 'No' " . $rclause;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my %taxon_h;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name, $family2, $genus2, $species2 ) = $cur->fetchrow();
        last if !$taxon_oid;

        if ( !$family2 ) {
            $family2 = $unclassified;
        }
        if ( !$genus2 ) {
            $genus2 = $unclassified;
        }
        if ( !$species2 ) {
            $species2 = $unclassified;
        }

        $taxon_h{$taxon_oid} = "$family2\t$genus2\t$species2\t$taxon_name";
    }
    $cur->finish();

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        # use SQLite
        my @perc_list = ($percent_identity);
        if ($plus) {
            for my $p3 ( 60, 90 ) {
                if ( $p3 > $percent_identity ) {
                    push @perc_list, ($p3);
                }
            }
        }

        for my $p3 (@perc_list) {

            my $sdb_name = MetaUtil::getPhyloDistTaxonDir($taxon_oid) . "/" . $t2 . "." . $p3 . ".sdb";
            my $dbh2 = WebUtil::sdbLogin($sdb_name);

            my @toid_list = keys %taxon_h;
            my $sql = MetaUtil::getPhyloDistHomoTaxonsSql( @toid_list );
            my $sth  = $dbh2->prepare($sql);
            $sth->execute();

            my ( $gene_oid, $gene_perc, $homolog_gene, $homo_taxon, $copies );
            while ( ( $gene_oid, $gene_perc, $homolog_gene, $homo_taxon, $copies ) = $sth->fetchrow_array() ) {
                last if ( !$gene_oid );
                my $workspace_id = "$taxon_oid $t2 $gene_oid";
                if ( $h2_href->{$workspace_id} ) {
                    # already in
                } else {
                    print $res "$workspace_id\n";
                    $h2_href->{$workspace_id} = 1;
                    $total++;
                }
            }
            $sth->finish();
            $dbh2->disconnect();
        }    # end for my $p3
    }    # end for t2

    close $res;

    my $text = qq{
        <p>
        $total genes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

# remove the selected items from existing scaffold set and re-save
sub removeAndSaveScaffolds {
    my $sid = getContactOid();

    my @oids = param("scaffold_oid");
    if ( $#oids < 0 ) {
        webError("Please select some scaffolds to remove.");
        return;
    }
    my %remove_these;
    foreach my $id (@oids) {
        $remove_these{ $id } = 1
    }

    my $folder = $SCAF_FOLDER;

    my $filename = param("filename");
    WebUtil::checkFileName($filename);

    if (! -e "$workspace_dir/$sid/$folder/$filename") {
        webError("File name $filename does not exist.");
        return;
    }

    my %keep_these;
    my $fh = newReadFileHandle("$workspace_dir/$sid/$folder/$filename");
    while ( my $id = $fh->getline() ) {
    	chomp $id;
    	next if ( $id eq "" );
    	next if ( $remove_these{ $id } );
    	$keep_these{$id} = 1;
    }
    close $fh;

    my $res = newWriteFileHandle("$workspace_dir/$sid/$folder/$filename");
    foreach my $id (keys %keep_these) {
    	print $res "$id\n";
    }
    close $res;

    my $text = qq{
        <p>
        Scaffolds removed and file <b>$filename</b> re-saved
        </p>
    };

    folderList( $folder, $text );
}

# save scaffold cart
sub saveScaffoldCart {
    my $sid = getContactOid();

    my $page     = param("page");
    my $section  = param("section");

    # form selected genes
    my @oids = param("scaffold_oid");
    if ( $#oids < 0 ) {
        webError("Please select some scaffolds to save.");
        return;
    }

    my $folder = $SCAF_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $count = 0;
    foreach my $id (@oids) {
        if ( $h2_href->{$id} ) {
            # already in
            next;
        }
        print $res "$id\n";
        $h2_href->{$id} = 1;
        $count++;
    }
    close $res;

    my $text = qq{
        <p>
        $count scaffolds saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

################################################################################
# saveScaffoldDistToWorkspace: save to workspace based on scaffold distribution
################################################################################
sub saveScaffoldDistToWorkspace {
    my $sid       = getContactOid();
    my $taxon_oid = param('taxon_oid');
    if ( !$taxon_oid ) {
        webError("Unknown Taxon ID.");
        return;
    }
    my $dist_type = param('dist_type');
    #print "saveScaffoldDistToWorkspace() dist_type=$dist_type<br/>\n";
    if ( !$dist_type ) {
        webError("Distribution type unknown.");
        return;
    }

    # selected scaffold counts or lengths
    my @ids = param($dist_type);
    #print "saveScaffoldDistToWorkspace() ids=@ids<br/>\n";
    if ( $#ids < 0 ) {
        webError("Please select some scaffolds to save.");
        return;
    }

    my $folder = $SCAF_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    printStartWorkingDiv();
    print "<p>\n";

    my $t2 = 'assembled';

    # scaffold count
    my $count = 0;
    for my $id2 (@ids) {
        my ( $trunc, @lines );

        if ( $dist_type eq 'seq_length' ) {
            my ( $min_length, $max_length ) = split( /\:/, $id2 );
            print "Retrieving scaffolds with sequence length $min_length .. $max_length ...<br/>\n";
            webLog("$min_length, $max_length\n\n");
            my ( $trunc2, $lines_ref, $scafs_ref ) =
              MetaUtil::getScaffoldStatsInLengthRange( $taxon_oid, $t2, $min_length, $max_length );
            $trunc = $trunc2;
            @lines = @$lines_ref;

        } elsif ( $dist_type eq 'gene_count' ) {
            my $i2 = sanitizeInt($id2);
            print "Retrieving scaffolds with gene count = $i2 ...<br/>\n";
            webLog("$i2\n\n");
            my ( $trunc2, $lines_ref, $scafs_ref ) = MetaUtil::getScaffoldStatsWithFixedGeneCnt( $taxon_oid, $t2, $i2 );
            $trunc = $trunc2;
            @lines = @$lines_ref;

        } else {
            webError("Cannot find dist type.");
            return;
        }

        for my $line (@lines) {
            my ( $scaf_oid, $seq_len, $gc_percent, $gene_cnt ) = split( /\t/, $line );

            my $workspace_id = "$taxon_oid $t2 $scaf_oid";
            if ( $h2_href->{$workspace_id} ) {
                # already in
                next;
            }
            $h2_href->{$workspace_id} = 1;
            print $res "$workspace_id\n";
            $count++;
        }

    }
    close $res;

    printEndWorkingDiv();

    my $text = qq{
        <p>
        $count scaffolds saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

################################################################################
# save function cart
################################################################################
sub saveFunctionCart {
    my $sid = getContactOid();

    # form selected genes
    my $save_func_id_name = param('save_func_id_name');
    if ( !$save_func_id_name ) {
        $save_func_id_name = "func_id";
    }

    my @oids = param($save_func_id_name);
    if ( $#oids < 0 ) {
        webError("Please select some functions to save.");
        return;
    }

    if ( $save_func_id_name eq 'term_oid' ) {
        my @new_ids;
        foreach my $oid (@oids) {
            if ( WebUtil::isInt($oid) ) {
                $oid = 'ITERM:' . $oid;
            }
            push( @new_ids, $oid );
        }
        @oids = @new_ids;
    } elsif ( $save_func_id_name eq 'parts_list_oid' ) {
        my @new_ids;
        foreach my $oid (@oids) {
            if ( WebUtil::isInt($oid) ) {
                $oid = 'PLIST:' . $oid;
            }
            push( @new_ids, $oid );
        }
        @oids = @new_ids;
    } elsif ( $save_func_id_name eq 'pway_oid' ) {
        my @new_ids;
        foreach my $oid (@oids) {
            if ( WebUtil::isInt($oid) ) {
                $oid = 'IPWAY:' . $oid;
            }
            push( @new_ids, $oid );
        }
        @oids = @new_ids;
    }

    my $folder = $FUNC_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $count = 0;
    foreach my $id (@oids) {
        if ( $h2_href->{$id} ) {
            # already in
            next;
        }
        print $res "$id\n";
        $h2_href->{$id} = 1;
        $count++;
    }
    close $res;

    my $text = qq{
        <p>
        $count functions saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );

}

################################################################################
# genome cart
# todo: merge with the one in WorkspaceGenomeSet
################################################################################
sub saveGenomeCart {
    my $sid = getContactOid();

    # form selected genes
    my @oids = param("taxon_oid");
    if ( scalar(@oids) == 0 ) {
        @oids = param("taxon_filter_oid");
    }
    if ( scalar(@oids) == 0 ) {
        webError("Please select some genomes to save.");
        return;
    }

    my $folder = $GENOME_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $count = 0;
    foreach my $id (@oids) {
        if ( $h2_href->{$id} ) {
            # already in
            next;
        }
        print $res "$id\n";
        $h2_href->{$id} = 1;
        $count++;
    }
    close $res;

    my $text = qq{
        <p>
        $count genomes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

################################################################################
# saveAllBrowserGenomeList
################################################################################
sub saveAllBrowserGenomeList {

    my $sid = getContactOid();

    my $from = param('from');
    if ( $from eq 'genomeCart' ) {
        return;
    }

    my $genomeListFilename = param('genomeListFilename');

    require GenomeList;
    my @oids = GenomeList::getTaxonsFromGenomeListFile($genomeListFilename);
    if ( scalar(@oids) <= 0 ) {
        webError('No Genome can be saved.');
    }

    my $folder = $GENOME_FOLDER;
    my ($filename, $res, $h2_href) = prepareSaveToWorkspace( $sid, $folder );

    my $count = 0;
    foreach my $id (@oids) {
        if ( $h2_href->{$id} ) {
            # already in
            next;
        }
        print $res "$id\n";
        $h2_href->{$id} = 1;
        $count++;
    }
    close $res;

    my $text = qq{
        <p>
        $count genomes saved to file <b>$filename</b>
        </p>
    };

    folderList( $folder, $text );
}

#
# lets make sure the folder name is correct
#
sub checkFolder {
    my ($f) = @_;

    my $sid = getContactOid();

    my $super_user = getSuperUser();
    if ( $super_user eq 'Yes' ) {
        @subfolders = ( $GENE_FOLDER, $FUNC_FOLDER, $SCAF_FOLDER, $GENOME_FOLDER, $RULE_FOLDER );
    }

    my $found = WebUtil::inArray( $f, @subfolders );

    if ( !$found ) {
        webDie("Invalid folder name: $f\n");
    }
}

#
# read workspace / load file
#
sub readFile {
    my $sid = getContactOid();

    my $folder = param("directory");
    checkFolder($folder);

    my @all_files = WorkspaceUtil::getAllInputFiles($sid);
    if ( scalar(@all_files) == 0 ) {
        main::printAppHeader("MyIMG");
        webError("Please select at least one data set to load.");
        return;
    }

    my @oids;
    my @metaOids;

    foreach my $ownerFilename (@all_files) {
        my ($owner, $filename) = WorkspaceUtil::splitOwnerFileset( $sid, $ownerFilename );
        if ( ! $owner || ! $filename ) {
            next;
        }

        # check filename
        WebUtil::checkFileName($filename);

        # this also untaints the name
        $filename = WebUtil::validFileName($filename);

        my $res = newReadFileHandle("$workspace_dir/$owner/$folder/$filename");
        while ( my $id = $res->getline() ) {
            chomp $id;
            $id = WebUtil::strTrim($id);
            next if ( $id eq "" );
            next if ( ! WebUtil::hasAlphanumericChar($id) );
            push( @oids, $id );
        }
        close $res;
    }
    #print "Workspace::readFile() oids: ".@oids."<br/>\n";

    if ( $folder eq $GENE_FOLDER ) {

        # show gene cart
        setSessionParam( "lastCart", "geneCart" );
        main::printAppHeader("AnaCart");
        my $gc = new GeneCartStor();
        $gc->addGeneBatch( \@oids );
        $gc->printGeneCartForm( '', 1 );
    } elsif ( $folder eq $FUNC_FOLDER ) {
        setSessionParam( "lastCart", "funcCart" );
        main::printAppHeader("AnaCart");
        require FuncCartStor;
        my $fc = new FuncCartStor();
        $fc->addFuncBatch( \@oids );
        $fc->printFuncCartForm( '', 1 );
    } elsif ( $folder eq $SCAF_FOLDER ) {
        require ScaffoldCart;
        setSessionParam( "lastCart", "scaffoldCart" );
        main::printAppHeader("AnaCart");

        # scaffold add checks for user permission - user restriction clause
        ScaffoldCart::addToScaffoldCart( \@oids );
        ScaffoldCart::printIndex();
    } elsif ( $folder eq $GENOME_FOLDER ) {
        setSessionParam( "lastCart", "genomeCart" );
        main::printAppHeader("AnaCart");

        # check permission
        my $rclause   = WebUtil::urClause('t');
        my $imgClause = WebUtil::imgClause('t');
        my $sql       = qq{
            select t.taxon_oid
            from taxon t, gtt_num_id tt
            where t.taxon_oid = tt.id
            $rclause
            $imgClause
        };
        my $dbh = dbLogin();
        OracleUtil::truncTable( $dbh, "gtt_num_id" );
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@oids );
        my @good_oids;
        my $cur = execSql( $dbh, $sql, $verbose );

        for ( ; ; ) {
            my ($oid) = $cur->fetchrow();
            last if !$oid;
            push( @good_oids, $oid );
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" );

        #$dbh->disconnect();

        require GenomeCart;
        GenomeCart::addToGenomeCart( \@good_oids );
        GenomeCart::dispatch();
    }
}

# view data in a file
sub viewFile {
    my $sid = getContactOid();

    my $super_user = getSuperUser();
    if ( $super_user eq 'Yes' ) {
        @subfolders = ( $GENE_FOLDER, $FUNC_FOLDER, $SCAF_FOLDER, $GENOME_FOLDER, $RULE_FOLDER );
    }

    # check filename
    my $filename = param("filename");
    if ( $filename eq "" ) {
        webError("Cannot read file.");
        return;
    }

    my $folder = param("folder");
    my $valid  = 0;
    foreach my $x (@subfolders) {
        if ( $folder eq $x ) {
            $valid = 1;
            last;
        }
    }
    if ( !$valid ) {
        webError("Invalid directory ($folder).");
    }

    WebUtil::checkFileName($filename);

    # this also untaints the name
    $filename = WebUtil::validFileName($filename);

    print qq{
        <h1> $filename $folder list</h1>
    };
    print "<p>\n";
    my $row   = 0;
    my $trunc = 0;
    my $res   = newReadFileHandle("$workspace_dir/$sid/$folder/$filename");
    while ( my $id = $res->getline() ) {

        # set a limit so that it won't crash web browser
        if ( $row >= $max_workspace_view ) {
            $trunc = 1;
            last;
        }

        chomp $id;
        next if ( $id eq "" );
        print "$id<br/>\n";
        $row++;
    }
    close $res;
    if ($trunc) {
        printStatusLine( "Loaded $row (additional rows truncated)", 2 );
    } else {
        printStatusLine( "Loaded $row", 2 );
    }
}

sub deleteFile {
    my $sid = getContactOid();

    # check filename
    my @files      = param("filename");
    my $super_user = getSuperUser();
    if ( $super_user eq 'Yes' ) {
        @subfolders = ( $GENE_FOLDER, $FUNC_FOLDER, $SCAF_FOLDER, $GENOME_FOLDER, $BC_FOLDER, $RULE_FOLDER );
    }

    if ( scalar(@files) == 0 ) {
        webError("Please select at least one data set to delete.");
        return;
    }

    my $folder = param("folder");
    my $valid  = 0;
    foreach my $x (@subfolders) {
        if ( $folder eq $x ) {
            $valid = 1;
            last;
        }
    }
    if ( !$valid ) {
        webError("Invalid directory.");
    }

    my $text = '';
    my @sqlList = ();
    foreach my $filename (@files) {

        # check filename
        WebUtil::checkFileName($filename);

        # this also untaints the name
	my $db_file_name = $filename;
	$db_file_name =~ s/'/''/g;    # replace ' with ''
        $filename = WebUtil::validFileName($filename);

	my $sql2 = "delete from contact_workspace_group\@imgsg_dev " .
	    "where contact_oid = $sid " .
	    " and data_set_type = '" . $folder .
	    "' and data_set_name = '" . $db_file_name . "'";
	push @sqlList, ( $sql2 );

        wunlink("$workspace_dir/$sid/$folder/$filename");

        $text .= qq{
            <p>
            File <b>$filename</b> deleted.
            </p>
        };
    }


    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        $text .= " SQL Error: $err";
    }

    folderList( $folder, $text );
}

###############################################################################
# showProfileGeneList - show all genes in a file with selected function
###############################################################################
sub showProfileGeneList {
    my $sid = getContactOid();

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $dbh = dbLogin();
    my $folder = $GENE_FOLDER;

    my $func_id = param('func_id');
    if ( ! $func_id ) {
        webError("No function is selected.\n");
        return;
    }

    my $input_file = param('input_file');
    my ($owner, $x) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $input_file, $ownerFilesetDelim, $folder );
    my $share_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $owner, $x, $sid );

    my $data_type = param('data_type');

    print "<h1>Workspace Function Profile Gene List</h1>\n";
    print "<p>";
    print "Function: $func_id";
    my $selected_func_name = getFuncName( $dbh, $func_id );
    if ( $selected_func_name ) {
        print " (" . $selected_func_name . ")";
    }
    print "<br/>\n";
    print "Workspace Set: $share_set_name<br/>\n";
    HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
    print "</p>";

    print hiddenVar( "input_file", $input_file );
    print hiddenVar( "func_id",    $func_id );

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    print "<p>\n";
    my $trunc = 0;

    my %taxon_datatype_h;
    undef %taxon_datatype_h;

    printStartWorkingDiv();

    open( FH, "$workspace_dir/$owner/$folder/$x" )
      or webError("File size - file error $input_file");

    print "<p>processing $input_file ...\n";

    my $min_gene_oid = 0;
    my $max_gene_oid = 0;

    while ( my $line = <FH> ) {
        chomp($line);

        my $taxon_oid;
        my $d2;
        my $gene_oid;
        my $key;
        if ( WebUtil::isInt($line) ) {
            $gene_oid = $line;
            $d2 = "database";
            $key = $d2;
            if ( !$min_gene_oid || $gene_oid < $min_gene_oid ) {
                $min_gene_oid = $gene_oid;
            }
            if ( $gene_oid > $max_gene_oid ) {
                $max_gene_oid = $gene_oid;
            }
        }
        else {
            ($taxon_oid, $d2, $gene_oid)  = split( / /, $line );
            if ( ($data_type eq 'assembled' || $data_type eq 'unassembled')
                && ($d2 ne $data_type) ) {
                    next;
            }
            $key = "$taxon_oid $d2";
        }

        if ( $taxon_datatype_h{$key} ) {
            my $h_ref = $taxon_datatype_h{$key};
            $h_ref->{$gene_oid} = 1;
        } else {
            my %hash2;
            $hash2{$gene_oid} = 1;
            $taxon_datatype_h{$key}  = \%hash2;
        }
    }    # end while line
    close FH;

    my $select_id_name = "gene_oid";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",     "char asc", "left" );
    $it->addColSpec( "Function ID", "char asc", "left" );
    my $sd = $it->getSdDelim();

    my $gene_count = 0;

    for my $key ( keys %taxon_datatype_h ) {
        my $h_ref = $taxon_datatype_h{$key};
        if ( !$h_ref ) {
            next;
        }

        if ( $key eq 'database' ) {

            # database

            my ( $sql, @bindList ) =
              WorkspaceQueryUtil::getDbFuncGeneSql2( $func_id, $selected_func_name, $min_gene_oid, $max_gene_oid, $rclause,
                $imgClause );

            #print "showProfileGeneList() WorkspaceQueryUtil::getDbFuncGeneSql2 sql: $sql<br/>\n";
            #print "showProfileGeneList() WorkspaceQueryUtil::getDbFuncGeneSql2 bindList: @bindList<br/>\n";

            if ($sql) {
                my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

                my %gene_func_h;
                my $cnt = 0;
                for ( ; ; ) {
                    my ( $gene_oid, $func_id2 ) = $cur->fetchrow();
                    last if ( !$gene_oid );

                    #print "showProfileGeneList() gene_oid: $gene_oid, func_id2: $func_id2<br/>\n";

                    if ( $func_id =~ /^ITERM/ ) {
                        $func_id2 = "ITERM:$func_id2";
                    } elsif ( $func_id =~ /^IPWAY/ ) {
                        $func_id2 = "IPWAY:$func_id2";
                    } elsif ( $func_id =~ /^PLIST/ ) {
                        $func_id2 = "PLIST:$func_id2";
                    } elsif ( $func_id =~ /^MetaCyc/ ) {
                        $func_id2 = "MetaCyc:$func_id2";
                    }

                    if ( $h_ref->{$gene_oid} ) {
                        if ( $gene_func_h{$gene_oid} ) {
                            $gene_func_h{$gene_oid} .= "," . $func_id2;
                        } else {
                            $gene_func_h{$gene_oid} = $func_id2;
                            $gene_count++;
                        }

                        if ( $gene_count >= $maxGeneListResults ) {
                            $trunc = 1;
                            last;
                        }
                    }
                }
                $cur->finish();

                for my $gene_oid ( keys %gene_func_h ) {
                    my $r;
                    my $workspace_id = $gene_oid;
                    $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=GeneDetail";
                    $url .= "&page=geneDetail&gene_oid=$gene_oid";
                    $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    my $str = $func_id;
                    if ( $func_id ne $gene_func_h{$gene_oid} ) {
                        $str .= " (" . $gene_func_h{$gene_oid} . ")";
                    }
                    $r .= $str . $sd . $str . "\t";
                    $it->addRow($r);
                }
            }
        } else {

            # MER-FS
            my ( $taxon_oid, $d2 ) = split( / /, $key );
            if ( ($data_type eq 'assembled' || $data_type eq 'unassembled')
                && ($d2 ne $data_type) ) {
                    next;
            }
            my @func_genes;
            my %gene_h;

            if (   $func_id =~ /COG\_Category/i
                || $func_id =~ /COG\_Pathway/i
                || $func_id =~ /Pfam\_Category/i
                || $func_id =~ /KEGG\_Category\_EC/i
                || $func_id =~ /KEGG\_Category\_KO/i
                || $func_id =~ /KEGG\_Pathway\_EC/i
                || $func_id =~ /KEGG\_Pathway\_KO/i
                || $func_id =~ /TIGRfam\_Role/i
                || $func_id =~ /MetaCyc/i )
            {

                my ( $sql, $id2 ) = WorkspaceQueryUtil::getFuncIdForSomeFuncSql( $func_id, $selected_func_name );

                my $cur = execSql( $dbh, $sql, $verbose, $id2 );
                for ( ; ; ) {
                    my ($id3) = $cur->fetchrow();
                    last if !$id3;

                    print "Processing function $id3 ...<br/>\n";

                    my @f_genes = MetaUtil::getTaxonFuncMetaGenes( $taxon_oid, $d2, $id3 );
                    for my $g2 (@f_genes) {
                        if ( $gene_h{$g2} ) {
                            $gene_h{$g2} .= "," . $id3;
                        } else {
                            $gene_h{$g2} = $id3;
                        }
                    }
                }
                $cur->finish();

                @func_genes = ( keys %gene_h );
            } else {
                @func_genes = MetaUtil::getTaxonFuncMetaGenes( $taxon_oid, $d2, $func_id );
            }

            for my $gene_oid (@func_genes) {
                if ( $h_ref->{$gene_oid} ) {
                    my $r;
                    my $workspace_id = "$taxon_oid $d2 $gene_oid";
                    $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid" . "&data_type=$d2&gene_oid=$gene_oid";
                    $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";

                    if (   $func_id =~ /COG\_Category/i
                        || $func_id =~ /COG\_Pathway/i
                        || $func_id =~ /Pfam\_Category/i
                        || $func_id =~ /KEGG\_Category\_EC/i
                        || $func_id =~ /KEGG\_Category\_KO/i
                        || $func_id =~ /KEGG\_Pathway\_EC/i
                        || $func_id =~ /KEGG\_Pathway\_KO/i
                        || $func_id =~ /TIGRfam\_Role/i )
                    {
                        my $new_id = $func_id;
                        if ( $gene_h{$gene_oid} ) {
                            $new_id = $func_id . " (" . $gene_h{$gene_oid} . ")";
                        }
                        $r .= $new_id . $sd . $new_id . "\t";
                    } else {
                        $r .= $func_id . $sd . $func_id . "\t";
                    }
                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
            }
        }
    }

    printEndWorkingDiv();

    $it->printOuterTable(1);

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
    }

    if ( $gene_count > 0 ) {
        WebUtil::printGeneCartFooter();
        print "<br/><br/>";
        WorkspaceUtil::printSaveAndExpandTabsForGenes( $select_id_name );
    }

    print end_form();
}


##############################################################################
# addSharing: share data sets with group
##############################################################################
sub addSharing {
    my $sid = getContactOid();

    my $folder = param("directory");

    my @input_files = param("filename");
    if ( scalar(@input_files) == 0 ) {
        webError("Select at least 1 $folder set to share.");
        return;
    }

    my $group_share = param("group_share");
    if ( ! $group_share ) {
        webError("Select a group to share.");
        return;
    }

    my %group_h = WorkspaceUtil::getContactImgGroups();
    if ( ! $group_h{$group_share} ) {
	webError("You do not belong to the group.");
	return;
    }
    my $group_name = $group_h{$group_share};
    my %share_h = WorkspaceUtil::getShareToGroups($folder);
    my $total = 0;
    my @sqlList = ();
    for my $file_name ( @input_files ) {
	my @already_share = split(/\t/, $share_h{$file_name});
	my %h2;
	for my $s2 ( @already_share ) {
	    my ($g_id, $g_name) = split(/\,/, $s2, 2);
	    $h2{$g_id} = $g_name;
	}
	if ( $h2{$group_share} ) {
	    # already shared
	    next;
	}

	$file_name =~ s/'/''/g;   # replace ' with ''
	my $sql2 = "insert into contact_workspace_group\@imgsg_dev (contact_oid, data_set_type, data_set_name, group_id) values ($sid, '" . $folder .
	    "', '" . $file_name . "', $group_share) ";
	push @sqlList, ( $sql2 );
	$total++;
    }
    if ( $total ) {
	my $err = db_sqlTrans( \@sqlList );
	if ( $err ) {
	    my $sql = $sqlList[$err-1];
	    webError("SQL error: $sql");
	    return;
	}
    }

    my $text = qq{
        <p>
        $total item(s) shared with group <b>$group_name</b>
        </p>
    };

    folderList( $folder, $text );
}

##############################################################################
# removeSharing: remove data set sharing with group
##############################################################################
sub removeSharing {
    my $sid = getContactOid();

    my $folder = param("directory");

    my @input_files = param("filename");
    if ( scalar(@input_files) == 0 ) {
        webError("Select at least 1 $folder set to remove sharing.");
        return;
    }

    my %share_h = WorkspaceUtil::getShareToGroups($folder);
    my $total = 0;
    my @sqlList = ();
    for my $file_name ( @input_files ) {
	my @already_share = split(/\t/, $share_h{$file_name});
	if ( scalar(@already_share) > 0 ) {
	    # remove sharing
	    $file_name =~ s/'/''/g;   # replace ' with ''
	    my $sql2 = "delete from contact_workspace_group\@imgsg_dev where contact_oid = $sid and data_set_type = '" . $folder .
		"' and data_set_name = '" . $file_name . "' ";
	    push @sqlList, ( $sql2 );
	    $total++;
	}
    }

    if ( $total ) {
	my $err = db_sqlTrans( \@sqlList );
	if ( $err ) {
	    my $sql = $sqlList[$err-1];
	    webError("SQL error: $sql");
	    return;
	}
    }

    my $text = qq{
        <p>
        $total item(s) with all sharing removed
        </p>
    };

    folderList( $folder, $text );
}

##############################################################################
# saveIntersection: save intersection of selected sets
##############################################################################
sub saveIntersection {

    my $sid = getContactOid();

    my $folder = param("directory");

    my @all_files = WorkspaceUtil::getAllInputFiles($sid);
    if ( scalar(@all_files) < 2 ) {
        webError("Select at least 2 $folder sets to get intersection.");
        return;
    }

    my $data_type = param('data_type_s');

    my $ws_filename = param("workspacefilename");
    $ws_filename =~ s/\W+/_/g;
    if ( !$ws_filename ) {
        webError("Please enter a workspace file name.");
        return;
    }

    # check filename
    # valid chars
    WebUtil::checkFileName($ws_filename);

    # this also untaints the name
    $ws_filename = WebUtil::validFileName($ws_filename);

    # check if ws_filename already exist
    if ( -e "$workspace_dir/$sid/$folder/$ws_filename" ) {
        webError("File name $ws_filename already exists. Please enter a new file name.");
        return;
    }

    # get the smallest set to start with
    my $file_size = 0;
    my $min_file  = "";
    my $min_c_oid = 0;
    my $msg       = "";
    for my $x2 (@all_files) {
    	my ($c_oid, $input_file) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
    	if ( ! $c_oid || ! $input_file ) {
    	    next;
    	}
        my $full_path = "$workspace_dir/$c_oid/$folder/" . $input_file;
        my $size      = fileSize($full_path);

        $msg .= "$input_file: $size; ";
        if ( !$size ) {
            next;
        }

        if ( $file_size == 0 || $file_size > $size ) {
            $file_size = $size;
            $min_file  = $input_file;
    	    $min_c_oid = $c_oid;
        }
    }

    if ( !$file_size ) {
        webError("No data in selected $folder sets. ($msg)");
        return;
    }

    my $dbh = dbLogin();

    my %item_counts;
    undef %item_counts;

    open( FH, "$workspace_dir/$min_c_oid/$folder/$min_file" )
      or webError("File size - file error $min_file");
    while ( my $line = <FH> ) {
        chomp($line);

        if ( WebUtil::isInt($line) ) {
            if ( ( $folder eq $GENOME_FOLDER )
                && ($data_type eq 'assembled' || $data_type eq 'unassembled') ) {
                my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $line );
                if ( $isTaxonInFile ) {
                    my $fname = $mer_data_dir . "/" . $line . "/" . $data_type;
                    if ( !(-e $fname ) ) {
                        next;
                    }
                }
            }
        }
        else {
            if ( ( $folder eq $SCAF_FOLDER || $folder eq $GENE_FOLDER )
                && ($data_type eq 'assembled' || $data_type eq 'unassembled') ) {
                my @v = split( / /, $line );
                if ( scalar(@v) == 3 ) {
                    if ($v[1] ne $data_type) {
                        next;
                    }
                }
            }
        }
        $item_counts{$line} = 1;
    }
    close FH;

    my @keys = keys %item_counts;
    if ( scalar(@keys) == 0 ) {
        webError("No data in selected $folder sets. (item size = 0)");
        return;
    }

    for my $x2 (@all_files) {
	my ($c_oid, $input_file) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
        if ( $input_file eq $min_file && $c_oid == $min_c_oid ) {
            # already counted
            next;
        }

        open( FH2, "$workspace_dir/$c_oid/$folder/$input_file" )
          or webError("File size - file error $input_file");

        while ( my $line = <FH2> ) {
            chomp($line);
            if ( $item_counts{$line} ) {
                $item_counts{$line} += 1;
            } else {
                $item_counts{$line} = 1;
            }
        }

        close FH2;
    }    # end for x2

    my $total       = 0;
    my $total_files = scalar(@all_files);
    my $res         = newWriteFileHandle("$workspace_dir/$sid/$folder/$ws_filename");

    for my $id ( sort @keys ) {
        if ( $item_counts{$id} >= $total_files ) {
            $total++;
            print $res "$id\n";
        }
    }
    close $res;

    my $text = qq{
        <p>
        $total items saved to file <b>$ws_filename</b>
        </p>
    };

    folderList( $folder, $text );
}

##############################################################################
# saveUnion: save union of selected sets
##############################################################################
sub saveUnion {

    my $sid = getContactOid();

    my $folder = param("directory");

    my @all_files = WorkspaceUtil::getAllInputFiles($sid);
    if ( scalar(@all_files) < 2 ) {
        webError("Select at least 2 $folder sets to get union.");
        return;
    }

    my $data_type = param('data_type_s');

    my $ws_filename = param("workspacefilename");
    $ws_filename =~ s/\W+/_/g;
    if ( !$ws_filename ) {
        webError("Please enter a workspace file name.");
        return;
    }

    # check filename
    # valid chars
    WebUtil::checkFileName($ws_filename);

    # this also untaints the name
    $ws_filename = WebUtil::validFileName($ws_filename);

    # check if ws_filename already exist
    if ( -e "$workspace_dir/$sid/$folder/$ws_filename" ) {
        webError("File name $ws_filename already exists. Please enter a new file name.");
        return;
    }

    my $dbh = dbLogin();

    my %item_counts;
    undef %item_counts;

    for my $x2 (@all_files) {
    	my ($c_oid, $input_file) = WorkspaceUtil::splitOwnerFileset( $sid, $x2 );
    	if ( ! $c_oid || ! $input_file ) {
    	    next;
    	}
        open( FH2, "$workspace_dir/$c_oid/$folder/$input_file" )
          or webError("File size - file error $input_file");

        while ( my $line = <FH2> ) {
            chomp($line);

            if ( WebUtil::isInt($line) ) {
                if ( ( $folder eq $GENOME_FOLDER )
                    && ($data_type eq 'assembled' || $data_type eq 'unassembled') ) {
                    my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $line );
                    if ( $isTaxonInFile ) {
                        my $fname = $mer_data_dir . "/" . $line . "/" . $data_type;
                        if ( !(-e $fname ) ) {
                            next;
                        }
                    }
                }
            }
            else {
                if ( ( $folder eq $SCAF_FOLDER || $folder eq $GENE_FOLDER )
                    && ($data_type eq 'assembled' || $data_type eq 'unassembled') ) {
                    my @v = split( / /, $line );
                    if ( scalar(@v) == 3 ) {
                        if ($v[1] ne $data_type) {
                            next;
                        }
                    }
                }
            }
            if ( $item_counts{$line} ) {
                $item_counts{$line} += 1;
            } else {
                $item_counts{$line} = 1;
            }
        }

        close FH2;
    }    # end for x2

    my $total = 0;
    my $res   = newWriteFileHandle("$workspace_dir/$sid/$folder/$ws_filename");

    my @keys = keys %item_counts;
    for my $id ( sort @keys ) {
        if ( $item_counts{$id} >= 1 ) {
            $total++;
            print $res "$id\n";
        }
    }

    close $res;

    my $text = qq{
        <p>
        $total items saved to file <b>$ws_filename</b>
        </p>
    };

    folderList( $folder, $text );
}

##############################################################################
# saveSetOp: save intersection or difference of selected sets
##############################################################################
sub saveSetOp {
    my ($isMinus) = @_;

    my $sid = getContactOid();

    my $filename;
    if ($isMinus) {
        $filename = param("setopname1");
    } else {
        $filename = param("filename");
    }

    #print "Workspace::saveSetOp() filename: $filename<br/>\n";

    my $folder = param("folder");
    if ( !$folder ) {
        $folder = param('directory');
    }

    my $set_select_mode  = param('set_select_mode');
    my $selected_id_type = "gene_oid";
    if ( $folder eq $FUNC_FOLDER ) {
        $selected_id_type = 'func_id';
    } elsif ( $folder eq $SCAF_FOLDER ) {
        $selected_id_type = 'scaffold_oid';
    } elsif ( $folder eq $GENOME_FOLDER ) {
        $selected_id_type = 'taxon_oid';
    }

    my $setoptype;
    if ($isMinus) {
        $setoptype = 'minus';
    } else {
        $setoptype = param("setoptype");
    }
    my $setopname2 = param("setopname2");

    my $ws_filename = param("op_res_filename");
    $ws_filename =~ s/\W+/_/g;
    if ( !$ws_filename ) {
        webError("Please enter a workspace file name.");
        return;
    }

    # check filename
    # valid chars
    WebUtil::checkFileName($ws_filename);

    # this also untaints the name
    $ws_filename = WebUtil::validFileName($ws_filename);

    # check if ws_filename already exist
    if ( -e "$workspace_dir/$sid/$folder/$ws_filename" ) {
        webError("File name $ws_filename already exists. Please enter a new file name.");
        return;
    }

    my %item_counts;
    undef %item_counts;

    if ( $set_select_mode eq 'only_selected' ) {

        # selected only
        my @ids = param($selected_id_type);
        for my $id (@ids) {
            $item_counts{$id} = 1;
        }
    } else {

        # all
        my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $filename, $ownerFilesetDelim, $folder );
        my $fullPathName = "$workspace_dir/$owner/$folder/$x";
        open( FH, $fullPathName )
          or webError("File size - file error $filename");

        while ( my $line = <FH> ) {
            chomp($line);
            my @v = split( / /, $line );
            my $id = join( ' ', @v );
            $item_counts{$id} = 1;
        }

        close FH;
    }

    my @keys = keys %item_counts;
    if ( scalar(@keys) == 0 ) {
        if ( $set_select_mode eq 'only_selected' ) {
            webError( "No " . $folder . "s have been selected." );
        } else {
            webError("No data in selected $folder sets. (item size = 0)");
        }
        return;
    }

    my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $setopname2, $ownerFilesetDelim, $folder );
    my $fullPathName2 = "$workspace_dir/$owner/$folder/$x";
    open( FH2, $fullPathName2 )
      or webError("File size - file error $setopname2");

    while ( my $line = <FH2> ) {
        chomp($line);
        my @v = split( / /, $line );
        my $id = join( ' ', @v );
        if ( $item_counts{$id} ) {
            $item_counts{$id} += 1;
        } elsif ( $setoptype eq 'union' ) {
            $item_counts{$id} = 1;
        }
    }    # end for input_file
    close FH2;

    my $total = 0;
    my $res   = newWriteFileHandle("$workspace_dir/$sid/$folder/$ws_filename");

    if ( $setoptype eq 'minus' || $setoptype eq 'intersect' ) {
        for my $id ( sort @keys ) {
            if ( $setoptype eq 'minus' ) {
                if ( $item_counts{$id} == 1 ) {
                    $total++;
                    print $res "$id\n";
                }
            } elsif ( $setoptype eq 'intersect' ) {
                if ( $item_counts{$id} == 2 ) {
                    $total++;
                    print $res "$id\n";
                }
            }
        }
    } elsif ( $setoptype eq 'union' ) {
        for my $id ( keys %item_counts ) {
            $total++;
            print $res "$id\n";
        }
    }

    close $res;

    my $text = qq{
        <p>
        $total items saved to file <b>$ws_filename</b>
        </p>
    };

    folderList( $folder, $text );
}

###############################################################################
# saveGeneGenomes: save genomes of selected gene sets or genes to genome set
###############################################################################
sub saveGeneGenomes {
    my ( $isSet, $isAlternativeName ) = @_;

    #print "isSet: $isSet, isAlternativeName: $isAlternativeName<br/>\n";

    my $sid = getContactOid();

    my @input_files;
    my @gene_oids;
    if ($isSet) {
        @input_files = WorkspaceUtil::getAllInputFiles($sid);
        if ( scalar(@input_files) == 0 ) {
            webError("Select at least one gene set to save genomes.");
            return;
        }
    } else {
        @gene_oids = param("gene_oid");
        print "gene_oids: @gene_oids<br/>\n";
        if ( scalar(@gene_oids) == 0 ) {
            webError("There are no genomes to save. Please select a gene.");
            return;
        }
    }

    my $folder = $GENOME_FOLDER;

    my $ws_filename;
    if ($isAlternativeName) {
        $ws_filename = param( "workspacefilename" . '_' . $folder );
    } else {
        $ws_filename = param("workspacefilename");
    }

    my $ws_save_mode;
    if ($isAlternativeName) {
        $ws_save_mode = param('ws_save_mode_gene');
    } else {
        $ws_save_mode = param('ws_save_mode');
    }
    if ( $ws_save_mode eq 'append' || $ws_save_mode eq 'replace' ) {
        if ($isAlternativeName) {
            $ws_filename = param("selectedwsfilename_gene");
        } else {
            $ws_filename = param("selectedwsfilename");
        }
    }

    #print "ws_save_mode: $ws_save_mode<br/>\n";
    if ( !$ws_save_mode ) {
        $ws_save_mode = 'save';
    }

    #print "ws_filename: $ws_filename<br/>\n";
    $ws_filename =~ s/\W+/_/g;
    if ( !$ws_filename ) {
        webError("Please enter a workspace file name.");
        return;
    }

    # check filename
    # valid chars
    WebUtil::checkFileName($ws_filename);

    # this also untaints the name
    $ws_filename = WebUtil::validFileName($ws_filename);

    # check if ws_filename already exists
    if ( $ws_save_mode eq 'save'
        && -e "$workspace_dir/$sid/$folder/$ws_filename" )
    {
        webError("File name $ws_filename already exists for genome sets. Please enter a new file name.");
        return;
    }

    # get all gene ids
    my ( $geneDisplayIds_ref, $db_genes_ref, $fs_genes_ref );
    if ($isSet) {
        ( $geneDisplayIds_ref, $db_genes_ref, $fs_genes_ref ) =
          WorkspaceUtil::catalogOidsFromFile( $workspace_dir, $sid, $GENE_FOLDER, @input_files );
    } else {
        ( $geneDisplayIds_ref, $db_genes_ref, $fs_genes_ref ) = WorkspaceUtil::catalogOids(@gene_oids);
    }

    my $res;
    my %h2;
    if ( $ws_save_mode eq 'append' ) {
        my $fh = newReadFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
        while ( my $id = $fh->getline() ) {
            chomp $id;
            next if ( $id eq "" );
            $h2{$id} = 1;
        }
        close $fh;

        $res = newAppendFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
    } else {
        $res = newWriteFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
    }

    my $total = 0;

    # process database genes first
    if ( scalar(@$db_genes_ref) > 0 ) {
        my $dbh = dbLogin();

        my $db_cnt        = 0;
        my $gene_oid_list = "";
        for my $db_gene_oid (@$db_genes_ref) {

            # database
            if ($db_cnt) {
                $gene_oid_list .= ", " . $db_gene_oid;
            } else {
                $gene_oid_list = $db_gene_oid;
            }

            $db_cnt++;
            if ( $db_cnt >= 1000 ) {
                $total = execSaveGeneGenomes( $gene_oid_list, $dbh, $res, \%h2 );

                # clear
                $db_cnt        = 0;
                $gene_oid_list = "";
            }
        }

        # last one
        if ( $db_cnt > 0 ) {
            $total = execSaveGeneGenomes( $gene_oid_list, $dbh, $res, \%h2 );
        }
    }

    # now process file genes
    if ( scalar(@$fs_genes_ref) > 0 ) {
        for my $fs_gene_oid (@$fs_genes_ref) {

            # file
            my ( $taxon_oid, $data_type, $gene_oid ) =
              split( / /, $fs_gene_oid );
            if ( $h2{$taxon_oid} ) {

                # already in
            } else {
                if ($res) {
                    print $res "$taxon_oid\n";
                }
                $h2{$taxon_oid} = 1;
            }
            $total++;
        }
    }

    close $res;

    my $text = qq{
        <p>
        $total items saved to file <b>$ws_filename</b>
        </p>
    };

    folderList( $folder, $text );
}

sub execSaveGeneGenomes {
    my ( $gene_oid_list, $dbh, $res, $h2_ref ) = @_;

    my $total = 0;

    my $sql = getGeneGenomeSql($gene_oid_list);
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if ( !$taxon_oid );

        if ( $h2_ref->{$taxon_oid} ) {

            # already in
        } else {
            if ($res) {
                print $res "$taxon_oid\n";
            }
            $h2_ref->{$taxon_oid} = 1;
        }
        $total++;
    }
    $cur->finish();

    return $total;
}

###############################################################################
# saveGeneScaffolds: save scaffolds of selected gene sets or genes to scaffold set
###############################################################################
sub saveGeneScaffolds {
    my ( $isSet, $isAlternativeName ) = @_;

    #print "isSet: $isSet, isAlternativeName: $isAlternativeName<br/>\n";

    my $sid = getContactOid();

    my @input_files;
    my @gene_oids;
    if ($isSet) {
        @input_files = WorkspaceUtil::getAllInputFiles($sid);
        if ( scalar(@input_files) == 0 ) {
            webError("Select at least one gene set to save scaffolds.");
            return;
        }
    } else {
        @gene_oids = param("gene_oid");
        print "gene_oids: @gene_oids<br/>\n";
        if ( scalar(@gene_oids) == 0 ) {
            webError("There are no scaffolds to save. Please select a gene.");
            return;
        }
    }

    my $folder = $SCAF_FOLDER;

    my $ws_filename;
    if ($isAlternativeName) {
        $ws_filename = param( "workspacefilename" . '_' . $folder );
    } else {
        $ws_filename = param("workspacefilename");
    }

    my $ws_save_mode;
    if ($isAlternativeName) {
        $ws_save_mode = param('ws_save_mode_gene');
    } else {
        $ws_save_mode = param('ws_save_mode');
    }
    if ( $ws_save_mode eq 'append' || $ws_save_mode eq 'replace' ) {
        if ($isAlternativeName) {
            $ws_filename = param("selectedwsfilename_gene");
        } else {
            $ws_filename = param("selectedwsfilename");
        }
    }

    #print "ws_save_mode: $ws_save_mode<br/>\n";
    if ( !$ws_save_mode ) {
        $ws_save_mode = 'save';
    }

    #print "ws_filename: $ws_filename<br/>\n";
    $ws_filename =~ s/\W+/_/g;
    if ( !$ws_filename ) {
        webError("Please enter a workspace file name.");
        return;
    }

    # check filename
    # valid chars
    WebUtil::checkFileName($ws_filename);

    # this also untaints the name
    $ws_filename = WebUtil::validFileName($ws_filename);

    # check if ws_filename already exists
    if ( $ws_save_mode eq 'save'
        && -e "$workspace_dir/$sid/$folder/$ws_filename" )
    {
        webError("File name $ws_filename already exists for scaffold sets. Please enter a new file name.");
        return;
    }

    # get all gene ids
    my ( $geneDisplayIds_ref, $db_genes_ref, $fs_genes_ref );
    if ($isSet) {
        ( $geneDisplayIds_ref, $db_genes_ref, $fs_genes_ref ) =
          WorkspaceUtil::catalogOidsFromFile( $workspace_dir, $sid, $GENE_FOLDER, @input_files );
    } else {
        ( $geneDisplayIds_ref, $db_genes_ref, $fs_genes_ref ) = WorkspaceUtil::catalogOids(@gene_oids);
    }

    my $res;
    my %h2;
    if ( $ws_save_mode eq 'append' ) {
        my $fh = newReadFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
        while ( my $id = $fh->getline() ) {
            chomp $id;
            next if ( $id eq "" );
            $h2{$id} = 1;
        }
        close $fh;

        $res = newAppendFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
    } else {
        $res = newWriteFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
    }

    my $total = 0;

    printStartWorkingDiv();

    # process database genes first
    if ( scalar(@$db_genes_ref) > 0 ) {
        my $dbh = dbLogin();

        my $db_cnt        = 0;
        my $gene_oid_list = "";
        for my $db_gene_oid (@$db_genes_ref) {

            # database
            if ($db_cnt) {
                $gene_oid_list .= ", " . $db_gene_oid;
            } else {
                $gene_oid_list = $db_gene_oid;
            }

            $db_cnt++;
            if ( $db_cnt >= 1000 ) {
                $total = execSaveGeneScaffolds( $gene_oid_list, $dbh, $res, \%h2 );

                # clear
                $db_cnt        = 0;
                $gene_oid_list = "";
            }
        }

        # last one
        if ( $db_cnt > 0 ) {
            $total = execSaveGeneScaffolds( $gene_oid_list, $dbh, $res, \%h2 );
        }

        #$dbh->disconnect();
    }

    # now process file genes
    if ( scalar(@$fs_genes_ref) > 0 ) {
        my %fs_gene_scaffolds;
        if ( scalar(@$fs_genes_ref) > 200 ) {
            walkThruScaffoldFiles( $fs_genes_ref, \%fs_gene_scaffolds );
        }

        for my $fs_gene_oid (@$fs_genes_ref) {
            if ( $h2{$fs_gene_oid} ) {

                # already in
            } else {
                my $ws_scaf_id = $fs_gene_scaffolds{$fs_gene_oid};
                if ( !$ws_scaf_id ) {
                    my ( $taxon_oid, $data_type, $gene_oid ) =
                      split( / /, $fs_gene_oid );
                    if ( $data_type ne 'assembled' ) {
                        next;
                    }

                    print "<p>Checking scaffold for gene $gene_oid ...\n";
                    my ( $s1, $e1, $n1, $scaf1 ) = MetaUtil::getGeneScaffold( $taxon_oid, $data_type, $gene_oid );
                    $ws_scaf_id = "$taxon_oid $data_type $scaf1";
                    $fs_gene_scaffolds{$fs_gene_oid} = $ws_scaf_id;
                }

                if ($res) {
                    print $res "$ws_scaf_id\n";
                }
                $h2{$ws_scaf_id} = 1;
            }
            $total++;
        }
    }

    close $res;
    printEndWorkingDiv();

    my $text = qq{
        <p>
        $total items saved to file <b>$ws_filename</b>
        </p>
    };

    folderList( $folder, $text );
}

sub execSaveGeneScaffolds {
    my ( $gene_oid_list, $dbh, $res, $h2_ref ) = @_;

    my $total = 0;

    my $sql = getGeneScaffoldSql($gene_oid_list);
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($scaf_oid) = $cur->fetchrow();
        last if ( !$scaf_oid );

        if ( $h2_ref->{$scaf_oid} ) {

            # already in
        } else {
            if ($res) {
                print $res "$scaf_oid\n";
            }
            $h2_ref->{$scaf_oid} = 1;
        }
        $total++;
    }
    $cur->finish();

    return $total;
}

###############################################################################
# walkThruScaffoldFiles: walk through scaffold files
#       to get gene-scaffold relationship
###############################################################################
sub walkThruScaffoldFiles {
    my ( $genes_ref, $file_scaf_ref ) = @_;

    my @keys = @$genes_ref;
    for my $k (@keys) {
        if ( $file_scaf_ref->{$k} ) {
            next;
        }

        my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $k );
        if ( $data_type ne 'assembled' ) {
            next;
        }

        # get scaffold_oid of this gene
        my ( $start_coord, $end_coord, $strand, $scaffold_oid ) =
          MetaUtil::getGeneScaffold( $taxon_oid, $data_type, $gene_oid );

        my $ws_scaffold_oid = "$taxon_oid $data_type $scaffold_oid";
        if ( $file_scaf_ref->{$ws_scaffold_oid} ) {

            # already included
            next;
        }

        # get all genes of this scaffold
        print "Checking scaffold $scaffold_oid ...<br/>";
        my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );
        for my $gs2 (@genes_on_s) {
            my ( $gid, $start_coord, $end_coord, $strand ) =
              split( /\,/, $gs2 );
            my $ws_gene_id = "$taxon_oid $data_type $gid";
            $file_scaf_ref->{$ws_gene_id} = $ws_scaffold_oid;
        }
    }    # end for my k
}

###############################################################################
# saveScaffoldGenes: save genes of selected scaffold sets or scaffolds to gene set
###############################################################################
sub saveScaffoldGenes {
    my ( $isSet, $isAlternativeName ) = @_;

    #print "isSet: $isSet, isAlternativeName: $isAlternativeName<br/>\n";

    my $sid = getContactOid();

    my @input_files;
    my @scaffold_oids;
    if ($isSet) {
        @input_files = WorkspaceUtil::getAllInputFiles($sid);
        if ( scalar(@input_files) == 0 ) {
            webError("Select at least one scaffold set to save genes.");
            return;
        }
    } else {
        @scaffold_oids = param("scaffold_oid");
        #print "scaffold_oids: @scaffold_oids<br/>\n";
        if ( scalar(@scaffold_oids) == 0 ) {
            webError("There are no genes to save. Please select a scaffold.");
            return;
        }
    }

    my $folder = $GENE_FOLDER;

    my $ws_filename;
    if ($isAlternativeName) {
        $ws_filename = param( "workspacefilename" . '_' . $folder );
    } else {
        $ws_filename = param("workspacefilename");
    }

    my $ws_save_mode;
    if ($isAlternativeName) {
        $ws_save_mode = param('ws_save_mode_gene');
    } else {
        $ws_save_mode = param('ws_save_mode');
    }
    if ( $ws_save_mode eq 'append' || $ws_save_mode eq 'replace' ) {
        if ($isAlternativeName) {
            $ws_filename = param("selectedwsfilename_gene");
        } else {
            $ws_filename = param("selectedwsfilename");
        }
    }

    #print "ws_save_mode: $ws_save_mode<br/>\n";
    if ( !$ws_save_mode ) {
        $ws_save_mode = 'save';
    }

    #print "ws_filename: $ws_filename<br/>\n";
    $ws_filename =~ s/\W+/_/g;
    if ( !$ws_filename ) {
        webError("Please enter a workspace file name.");
        return;
    }

    # check filename
    # valid chars
    WebUtil::checkFileName($ws_filename);

    # this also untaints the name
    $ws_filename = WebUtil::validFileName($ws_filename);

    # check if ws_filename already exists
    if ( $ws_save_mode eq 'save'
        && -e "$workspace_dir/$sid/$folder/$ws_filename" )
    {
        webError("File name $ws_filename already exists for gene sets. Please enter a new file name.");
        return;
    }

    # get all scaffold ids
    my ( $scaffoldDisplayIds_ref, $db_scaffolds_ref, $fs_scaffolds_ref );
    if ($isSet) {
        ( $scaffoldDisplayIds_ref, $db_scaffolds_ref, $fs_scaffolds_ref ) =
          WorkspaceUtil::catalogOidsFromFile2( $sid, $workspace_dir, $SCAF_FOLDER, @input_files );
    } else {
        ( $scaffoldDisplayIds_ref, $db_scaffolds_ref, $fs_scaffolds_ref ) = WorkspaceUtil::catalogOids(@scaffold_oids);
    }

    my $res;
    my %h2;
    if ( $ws_save_mode eq 'append' ) {
        my $fh = newReadFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
        while ( my $id = $fh->getline() ) {
            chomp $id;
            next if ( $id eq "" );
            $h2{$id} = 1;
        }
        close $fh;

        $res = newAppendFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
    } else {
        $res = newWriteFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
    }

    my $dbh = dbLogin();
    my $total = 0;

    # process database scaffolds first
    if ( scalar(@$db_scaffolds_ref) > 0 ) {
        my $db_cnt        = 0;
        my $scaf_oid_list = "";
        for my $db_scaf_oid (@$db_scaffolds_ref) {

            # database
            if ($db_cnt) {
                $scaf_oid_list .= ", " . $db_scaf_oid;
            } else {
                $scaf_oid_list = $db_scaf_oid;
            }

            $db_cnt++;
            if ( $db_cnt >= 1000 ) {
                $total = execSaveScaffoldGenes( $scaf_oid_list, $dbh, $res, \%h2 );

                # clear
                $db_cnt        = 0;
                $scaf_oid_list = "";
            }
        }

        # last one
        if ( $db_cnt > 0 ) {
            $total = execSaveScaffoldGenes( $scaf_oid_list, $dbh, $res, \%h2 );
        }
    }

    # now process file scaffolds
    if ( scalar(@$fs_scaffolds_ref) > 0 ) {
        my %taxon_oid_hash = MerFsUtil::fetchValidMetaTaxonOidHash( $dbh, @$fs_scaffolds_ref );

        for my $fs_scaf_oid (@$fs_scaffolds_ref) {
            # file
            my ( $taxon_oid, $data_type, $scaffold_oid ) =
              split( / /, $fs_scaf_oid );
            if ( $data_type ne 'assembled' ) {
                next;
            }
            if ( ! $taxon_oid_hash{$taxon_oid} ) {
                next;
            }

            my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );

            for my $s2 (@genes_on_s) {
                my ( $gid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id, $source )
                  = split( /\t/, $s2 );

                my $workspace_id = "$taxon_oid $data_type $gid";
                if ( $h2{$workspace_id} ) {
                    # already in
                } else {
                    if ($res) {
                        print $res "$workspace_id\n";
                    }
                    $h2{$workspace_id} = 1;
                }
                $total++;
            }
        }
    }

    close $res;

    my $text = qq{
        <p>
        $total items saved to file <b>$ws_filename</b>
        </p>
    };

    folderList( $folder, $text );
}

sub execSaveScaffoldGenes {
    my ( $scaf_oid_list, $dbh, $res, $h2_ref ) = @_;

    my $total = 0;

    my $sql = getScaffoldGeneSql($scaf_oid_list);
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if ( !$gene_oid );

        if ( $h2_ref->{$gene_oid} ) {

            # already in
        } else {
            if ($res) {
                print $res "$gene_oid\n";
            }
            $h2_ref->{$gene_oid} = 1;
        }
        $total++;
    }
    $cur->finish();

    return $total;
}

###############################################################################
# saveScaffoldGenomes: save genes of selected scaffold sets or scaffolds to genome set
###############################################################################
sub saveScaffoldGenomes {
    my ( $isSet, $isAlternativeName ) = @_;

    #print "isSet: $isSet, isAlternativeName: $isAlternativeName<br/>\n";

    my $sid = getContactOid();

    my @input_files;
    my @scaffold_oids;
    if ($isSet) {
        @input_files = WorkspaceUtil::getAllInputFiles($sid);
        if ( scalar(@input_files) == 0 ) {
            webError("Select at least one scaffold set to save genomes.");
            return;
        }
    } else {
        @scaffold_oids = param("scaffold_oid");
        #print "scaffold_oids: @scaffold_oids<br/>\n";
        if ( scalar(@scaffold_oids) == 0 ) {
            webError("There are no genomes to save. Please select a scaffold.");
            return;
        }
    }

    my $folder = $GENOME_FOLDER;

    my $ws_filename;
    if ($isAlternativeName) {
        $ws_filename = param( "workspacefilename" . '_' . $folder );
    } else {
        $ws_filename = param("workspacefilename");
    }

    my $ws_save_mode;
    if ($isAlternativeName) {
        $ws_save_mode = param('ws_save_mode_gene');
    } else {
        $ws_save_mode = param('ws_save_mode');
    }
    if ( $ws_save_mode eq 'append' || $ws_save_mode eq 'replace' ) {
        if ($isAlternativeName) {
            $ws_filename = param("selectedwsfilename_gene");
        } else {
            $ws_filename = param("selectedwsfilename");
        }
    }

    #print "ws_save_mode: $ws_save_mode<br/>\n";
    if ( !$ws_save_mode ) {
        $ws_save_mode = 'save';
    }

    #print "ws_filename: $ws_filename<br/>\n";
    $ws_filename =~ s/\W+/_/g;
    if ( !$ws_filename ) {
        webError("Please enter a workspace file name.");
        return;
    }

    # check filename
    # valid chars
    WebUtil::checkFileName($ws_filename);

    # this also untaints the name
    $ws_filename = WebUtil::validFileName($ws_filename);

    # check if ws_filename already exists
    if ( $ws_save_mode eq 'save'
        && -e "$workspace_dir/$sid/$folder/$ws_filename" )
    {
        webError("File name $ws_filename already exists for genome sets. Please enter a new file name.");
        return;
    }

    # get all scaffold ids
    my ( $scaffoldDisplayIds_ref, $db_scaffolds_ref, $fs_scaffolds_ref );
    if ($isSet) {
        ( $scaffoldDisplayIds_ref, $db_scaffolds_ref, $fs_scaffolds_ref ) =
          WorkspaceUtil::catalogOidsFromFile2( $sid, $workspace_dir, $SCAF_FOLDER, @input_files );
    } else {
        ( $scaffoldDisplayIds_ref, $db_scaffolds_ref, $fs_scaffolds_ref ) = WorkspaceUtil::catalogOids(@scaffold_oids);
    }

    my $res;
    my %h2;
    if ( $ws_save_mode eq 'append' ) {
        my $fh = newReadFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
        while ( my $id = $fh->getline() ) {
            chomp $id;
            next if ( $id eq "" );
            $h2{$id} = 1;
        }
        close $fh;

        $res = newAppendFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
    } else {
        $res = newWriteFileHandle("$workspace_dir/$sid/$folder/$ws_filename");
    }

    my $total = 0;

    # process database scaffolds first
    if ( scalar(@$db_scaffolds_ref) > 0 ) {
        my $dbh = dbLogin();

        my $db_cnt        = 0;
        my $scaf_oid_list = "";
        for my $db_scaf_oid (@$db_scaffolds_ref) {

            # database
            if ($db_cnt) {
                $scaf_oid_list .= ", " . $db_scaf_oid;
            } else {
                $scaf_oid_list = $db_scaf_oid;
            }

            $db_cnt++;
            if ( $db_cnt >= 1000 ) {
                $total = execSaveScaffoldGenomes( $scaf_oid_list, $dbh, $res, \%h2 );

                # clear
                $db_cnt        = 0;
                $scaf_oid_list = "";
            }
        }

        # last one
        if ( $db_cnt > 0 ) {
            $total = execSaveScaffoldGenomes( $scaf_oid_list, $dbh, $res, \%h2 );
        }

        #$dbh->disconnect();
    }

    # now process file scaffolds
    if ( scalar(@$fs_scaffolds_ref) > 0 ) {
        for my $fs_scaf_oid (@$fs_scaffolds_ref) {

            # file
            my ( $taxon_oid, $data_type, $scaffold_oid ) =
              split( / /, $fs_scaf_oid );
            if ( $data_type ne 'assembled' ) {
                next;
            }

            if ( $h2{$taxon_oid} ) {

                # already in
            } else {
                if ($res) {
                    print $res "$taxon_oid\n";
                }
                $h2{$taxon_oid} = 1;
            }
            $total++;
        }
    }

    close $res;

    my $text = qq{
        <p>
        $total items saved to file <b>$ws_filename</b>
        </p>
    };

    folderList( $folder, $text );
}

sub execSaveScaffoldGenomes {
    my ( $scaf_oid_list, $dbh, $res, $h2_ref ) = @_;

    my $total = 0;

    my $sql = getScaffoldGenomeSql($scaf_oid_list);
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if ( !$taxon_oid );

        if ( $h2_ref->{$taxon_oid} ) {

            # already in
        } else {
            if ($res) {
                print $res "$taxon_oid\n";
            }
            $h2_ref->{$taxon_oid} = 1;
        }
        $total++;
    }
    $cur->finish();

    return $total;
}

############################################################################
# exportGeneFasta
############################################################################
sub exportGeneFasta {

    my $sid = getContactOid();
    if ( blankStr($sid) ) {
        main::printAppHeader("AnaCart");
        webError("Your login has expired.");
        return;
    }

    my @input_files = param("filename");
    if ( scalar(@input_files) == 0 ) {
        main::printAppHeader("AnaCart");
        webError("Select at least one gene set to export.");
        return;
    }

    my $folder = $GENE_FOLDER;

    timeout( 60 * $merfs_timeout_mins );

    # get all gene ids
    my %genes;
    for my $input_file (@input_files) {
        open( FH, "$workspace_dir/$sid/$folder/$input_file" )
          or webError("File size - file error $input_file");

        while ( my $line = <FH> ) {
            chomp($line);
            if ( $genes{$line} ) {

                # duplicates
                next;
            }

            my @v = split( / /, $line );
            if ( scalar(@v) == 1 ) {
                if ( WebUtil::isInt( $v[0] ) ) {

                    # integer database id
                    $genes{$line} = 1;
                }
            } else {
                $genes{$line} = 2;
            }
        }

        close FH;
    }

    my @keys = ( keys %genes );
    if ( scalar(@keys) == 0 ) {
        main::printAppHeader("AnaCart");
        webError("No genes have been selected.");
        return;
    }

    GenerateArtemisFile::processFastaFile( \@keys, 0, 1, $GENE_FOLDER );
}

############################################################################
# exportGeneAA: Amino Acid
############################################################################
sub exportGeneAA {

    my $sid = getContactOid();
    if ( blankStr($sid) ) {
        main::printAppHeader("AnaCart");
        webError("Your login has expired.");
        return;
    }

    my @input_files = param("filename");
    if ( scalar(@input_files) == 0 ) {
        main::printAppHeader("AnaCart");
        webError("Select at least one gene set to export.");
        return;
    }

    my $folder = $GENE_FOLDER;

    timeout( 60 * $merfs_timeout_mins );

    # get all gene ids
    my %genes;
    for my $input_file (@input_files) {
        open( FH, "$workspace_dir/$sid/$folder/$input_file" )
          or webError("File size - file error $input_file");

        while ( my $line = <FH> ) {
            chomp($line);
            if ( $genes{$line} ) {

                # duplicates
                next;
            }

            my @v = split( / /, $line );
            if ( scalar(@v) == 1 ) {
                if ( WebUtil::isInt( $v[0] ) ) {

                    # integer database id
                    $genes{$line} = 1;
                }
            } else {
                $genes{$line} = 2;
            }
        }

        close FH;
    }

    my @keys = ( keys %genes );
    if ( scalar(@keys) == 0 ) {
        main::printAppHeader("AnaCart");
        webError("No genes have been selected.");
        return;
    }

    GenerateArtemisFile::processFastaFile( \@keys, 1, 1, $GENE_FOLDER );

}

############################################################################
# exportScaffoldFasta
############################################################################
sub exportScaffoldFasta {

    my @scaffolds = getScaffoldsFromSets();
    GenerateArtemisFile::processFastaFile( \@scaffolds, 0, 1, $SCAF_FOLDER );
}

############################################################################
# exportScaffoldData
############################################################################
sub exportScaffoldData {

    my @scaffolds = getScaffoldsFromSets();
    GenerateArtemisFile::processDataFile( \@scaffolds, 1, $SCAF_FOLDER );

}

############################################################################
# getScaffoldsFromSets
############################################################################
sub getScaffoldsFromSets {

    my $sid = getContactOid();
    if ( blankStr($sid) ) {
        main::printAppHeader("AnaCart");
        webError("Your login has expired.");
        return;
    }

    my @input_files = param("filename");
    if ( scalar(@input_files) == 0 ) {
        webError("Select at least one scaffold set to export.");
        return;
    }

    my $folder = $SCAF_FOLDER;

    # get all scaffold ids
    my %scaffolds;
    for my $input_file (@input_files) {
        open( FH, "$workspace_dir/$sid/$folder/$input_file" )
          or webError("File size - file error $input_file");

        while ( my $line = <FH> ) {
            chomp($line);
            if ( $scaffolds{$line} ) {
                # duplicates
                next;
            }

            my @v = split( / /, $line );
            if ( scalar(@v) == 1 ) {
                if ( WebUtil::isInt( $v[0] ) ) {
                    # integer database id
                    $scaffolds{$line} = 1;
                }
            } else {
                $scaffolds{$line} = 2;
            }
        }

        close FH;
    }

    my @keys = ( keys %scaffolds );
    if ( scalar(@keys) == 0 ) {
        main::printAppHeader("AnaCart");
        webError("No scaffolds have been selected.");
        return;
    }

    return (@keys);
}

############################################################################
# getAllFuncIds
############################################################################
sub getAllFuncIds {
    my ($dbh, $functype) = @_;

    my $sql;
    if ( $functype eq 'COG' ) {
        $sql = "select cog_id from cog";
    } elsif ( $functype eq 'Pfam' ) {
        $sql = "select ext_accession from pfam_family";
    } elsif ( $functype eq 'TIGRfam' ) {
        $sql = "select ext_accession from tigrfam";
    } elsif ( $functype eq 'KOG' ) {
        $sql = "select kog_id from kog";
    } elsif ( $functype eq 'KO' ) {
        $sql = "select ko_id from ko_term";
    } elsif ( $functype eq 'Enzymes' ) {
        $sql = "select ec_number from enzyme";
    } elsif ( $functype eq 'MetaCyc' ) {
        $sql = "select unique_id from biocyc_pathway";
    } elsif ( $functype eq 'InterPro' ) {
        $sql = "select ext_accession from biocyc_pathway";
    } elsif ( $functype eq 'TC' ) {
        $sql = "select tc_family_num from tc_family";
    } elsif ( $functype eq 'ITERM' || $functype eq 'IMG_Term' ) {
        $sql = "select term_oid from img_term";
    } elsif ( $functype eq 'IPWAY' || $functype eq 'IMG_Pathway' ) {
        $sql = "select pathway_oid from img_pathway";
    }

    my @ids;
    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($func_id) = $cur->fetchrow();
            last if ( !$func_id );

            push @ids, ($func_id);
        }
        $cur->finish();

        #$dbh->disconnect();
    }

    return @ids;
}


############################################################################
# getMetaFuncName
############################################################################
sub getMetaFuncName {
    my ($func_id) = @_;

    my $func_name = $func_id;

    my ( $id1, $id2 ) = split( /\:/, $func_id );

    my $sql = "";
    my $db_id;
    if ( $id1 eq 'COG_Category' || $id1 eq 'Pfam_Category' ) {
        $db_id = $id2;
        $sql   = "select definition from cog_function where function_code = ?";
    } elsif ( $id1 eq 'COG_Pathway' ) {
        $db_id = $id2;
        $sql   = "select cog_pathway_name from cog_pathway where cog_pathway_oid = ?";
    } elsif ( $id1 =~ /COG/i && !$id2 ) {
        $db_id = $func_id;
        $sql   = "select cog_name from cog where cog_id = ?";
    } elsif ( $id1 =~ /pfam/i ) {
        $db_id = $func_id;
        $sql   = "select description from pfam_family where ext_accession = ?";
    } elsif ( $id1 eq 'TIGRfam_Role' ) {
        $db_id = $id2;
        $sql   = "select sub_role from tigr_role where role_id = ?";
    } elsif ( $id1 =~ /TIGR/i ) {
        $db_id = $func_id;
        $sql   = "select expanded_name from tigrfam where ext_accession = ?";
    } elsif ( $id1 eq 'KEGG_Category_EC'
        || $id1 eq 'KEGG_Category_KO' )
    {
        $db_id = $id2;
        $sql   = "select category from kegg_pathway where pathway_oid = ?";
    } elsif ( $id1 eq 'KEGG_Pathway_EC'
        || $id1 eq 'KEGG_Pathway_KO' )
    {
        $db_id = $id2;
        $sql   = "select pathway_name from kegg_pathway where pathway_oid = ?";
    } elsif ( $id1 =~ /^EC/i ) {
        $db_id = $func_id;
        $sql   = "select enzyme_name from enzyme where ec_number = ?";
    } elsif ( $id1 =~ /^KOG/i ) {
        $db_id = $func_id;
        $sql   = "select kog_name from kog where kog_id = ?";
    } elsif ( $id1 =~ /^KO/i ) {
        $db_id = $func_id;
        $sql   = "select definition from ko_term where ko_id = ?";
    } elsif ( $id1 =~ /^MetaCyc/i ) {
        $db_id = $id2;
        $sql   = "select common_name from biocyc_pathway where unique_id = ?";
    } elsif ( $id1 =~ /^IPR/i ) {
        $db_id = $func_id;
        $sql   = "select name from interpro where ext_accession = ?";
    } elsif ( $id1 =~ /^TC/i ) {
        $db_id = $func_id;
        $sql   = "select tc_family_name from tc_family where tc_family_num = ?";
    } elsif ( $id1 =~ /^ITERM/i && WebUtil::isInt($id2) ) {
        $db_id = $id2;
        $sql   = "select term from img_term where term_oid = ?";
    } elsif ( $id1 =~ /^IPWAY/i && WebUtil::isInt($id2) ) {
        $db_id = $id2;
        $sql   = "select pathway_name from img_pathway where pathway_oid = ?";
    } elsif ( $id1 =~ /^PLIST/i && WebUtil::isInt($id2) ) {
        $db_id = $id2;
        $sql   = "select parts_list_name from img_parts_list where parts_list_oid = ?";
    } elsif ( $id1 =~ /^NETWK/i && WebUtil::isInt($id2) ) {
        $db_id = $id2;
        $sql   = "select network_name from pathway_network where network_oid = ?";
    }

    if ($sql) {
        my $dbh = dbLogin();
        my $cur = execSql( $dbh, $sql, $verbose, $db_id );
        ($func_name) = $cur->fetchrow();
        $cur->finish();

        #$dbh->disconnect();
    }

    return $func_name;
}

############################################################################
# getFuncName
# need to merge with getMetaFuncName
############################################################################
sub getFuncName {
    my ( $dbh, $func_id ) = @_;

    my $func_name = $func_id;

    my $sql   = "";
    my $db_id = $func_id;

    if ( $func_id =~ /COG\_Category/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql   = "select definition from cog_function where function_code = ?";
    } elsif ( $func_id =~ /COG\_Pathway/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql   = "select cog_pathway_name from cog_pathway where cog_pathway_oid = ?";
    } elsif ( $func_id =~ /COG/i ) {
        $sql = "select cog_name from cog where cog_id = ?";
    } elsif ( $func_id =~ /Pfam\_Category/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql   = "select definition from cog_function where function_code = ?";
    } elsif ( $func_id =~ /pfam/i ) {
        $sql = "select description from pfam_family where ext_accession = ?";
    } elsif ( $func_id =~ /TIGRfam\_Role/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql   = "select sub_role from tigr_role where role_id = ?";
    } elsif ( $func_id =~ /TIGR/i ) {
        $sql = "select expanded_name from tigrfam where ext_accession = ?";
    } elsif ( $func_id =~ /KEGG\_Category\_EC/i
        || $func_id =~ /KEGG\_Category\_KO/i )
    {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql   = "select category from kegg_pathway where pathway_oid = ?";
    } elsif ( $func_id =~ /KEGG\_Pathway\_EC/i
        || $func_id =~ /KEGG\_Pathway\_KO/i )
    {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql   = "select pathway_name from kegg_pathway where pathway_oid = ?";
    } elsif ( $func_id =~ /KOG/i ) {
        $sql = "select kog_name from kog where kog_id = ?";
    } elsif ( $func_id =~ /KO/i ) {
        $sql = "select ko_name, definition from ko_term where ko_id = ?";
    } elsif ( $func_id =~ /EC/i ) {
        $sql = "select enzyme_name from enzyme where ec_number = ?";
    } elsif ( $func_id =~ /^MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        $sql   = "select common_name from biocyc_pathway where unique_id = ?";
    } elsif ( $func_id =~ /^IPR/i ) {
        $sql = "select name from interpro where ext_accession = ?";
    } elsif ( $func_id =~ /^TC/i ) {
        $sql = "select tc_family_name from tc_family where tc_family_num = ?";
    } elsif ( $func_id =~ /^ITERM/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( WebUtil::isInt($id2) ) {
            $sql = "select term from img_term where term_oid = ?";
        }
    } elsif ( $func_id =~ /^IPWAY/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( WebUtil::isInt($id2) ) {
            $sql = "select pathway_name from img_pathway where pathway_oid = ?";
        }
    } elsif ( $func_id =~ /^PLIST/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        $db_id = $id2;
        if ( WebUtil::isInt($id2) ) {
            $sql = "select parts_list_name from img_parts_list where parts_list_oid = ?";
        }
    }

    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose, $db_id );
        my ( $name1, $name2 ) = $cur->fetchrow();
        $cur->finish();

        $func_name = $name1;
        if ( $func_id =~ /KO/ ) {
            if ( !$name1 ) {
                $func_name = $name2;
            } elsif ($name2) {
                $func_name = "$name2 ($name1)";
            }
        }
    }

    return $func_name;
}


############################################################################
# getComponentFuncIds: get component func_id for a
#                      category function ID
############################################################################
sub getComponentFuncIds {
    my ($cate_func_id) = @_;

    my ( $id1, $id2 ) = split( /\:/, $cate_func_id );
    my $sql      = "";
    my @func_ids = ();
    if ( $id1 eq 'COG_Category' || $id1 eq 'Pfam_Category' ) {
        $sql = qq{
            select distinct cf.cog_id
            from cog_functions cf
            where cf.functions = ?
        };
    } elsif ( $id1 eq 'COG_Pathway' ) {
        $sql = qq{
	       select distinct cpcm.cog_members
	       from cog_pathway_cog_members cpcm
	       where cpcm.cog_pathway_oid = ?
        };
    } elsif ( $id1 eq 'Pfam_Category' ) {
        $sql = qq{
	       select distinct pfc.ext_accession
	       from pfam_family_cogs pfc
	       where pfc.functions = ?
        };
    } elsif ( $id1 eq 'TIGRfam_Role' ) {
        $sql = qq{
	       select distinct tr.ext_accession
	       from tigrfam_roles tr
	       where tr.roles = ?
       };
    } elsif ( $id1 eq 'KEGG_Category_EC' ) {
        $sql = qq{
           select distinct kt.enzymes
           from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp
           where kt.ko_id = rk.ko_terms
           and rk.roi_id = ir.roi_id
           and ir.pathway = kp.pathway_oid
           and kp.category = (select p2.category from kegg_pathway p2
                              where p2.pathway_oid = ?)
       };
    } elsif ( $id1 eq 'KEGG_Category_KO' ) {
        $sql = qq{
           select distinct rk.ko_terms
           from kegg_pathway kp, image_roi_ko_terms rk, image_roi ir
           where rk.roi_id = ir.roi_id
           and kp.pathway_oid = ir.pathway
           and kp.category = (select p2.category from kegg_pathway p2
                              where p2.pathway_oid = ?)
       };
    } elsif ( $id1 eq 'KEGG_Pathway_EC' ) {
        $sql = qq{
            select distinct kt.enzymes
            from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = ?
       };
    } elsif ( $id1 eq 'KEGG_Pathway_KO' ) {
        $sql = qq{
	        select distinct rk.ko_terms
	        from image_roi_ko_terms rk, image_roi ir
		    where rk.roi_id = ir.roi_id
		    and ir.pathway = ?
       };
    } elsif ( $id1 eq 'MetaCyc' ) {
        $sql = qq{
	        select distinct br.ec_number
	        from biocyc_reaction_in_pwys brp, biocyc_reaction br
		    where brp.unique_id = br.unique_id
		    and brp.in_pwys = ?
       };
    }

    if ($sql) {
        my $dbh = dbLogin();
        my $cur = execSql( $dbh, $sql, $verbose, $id2 );
        for ( ; ; ) {
            my ($func_id) = $cur->fetchrow();
            push @func_ids, ($func_id);
        }
        $cur->finish();

        #$dbh->disconnect();
    }

    return @func_ids;
}

############################################################################
# printImportExport - Prints import and export section
#                     input: set type: "gene"|"function"|"genome"|"scaffold"
############################################################################
sub printImportExport {
    my ($folder) = @_;
    printPopUpMarkup();

    print "<h2>Import</h2>\n";

    print qq{
      <p>You may import $folder sets from a file created by using the
      export feature below.<br>A file can also be successfully imported
      if it follows a <a href="" onClick="return false;">
      <span id="w_imp_fmt" title="Workspace Import Format">
      specific format</span></a>.</p>
    };

    my $textFieldId = "workspaceFile";
    print "<p>";
    print "File to upload:<br/>\n";
    print "<input id='$textFieldId' type='file' name='uploadFile' size='45'/>";
    print "</p>";
    print button(
        -value   => "Import \u$folder Sets",
        -class   => "meddefbutton",
        -onClick => "importSet('$textFieldId');",
    );

    print "<h2>Export</h2>\n";
    my $extra_text = "";
    my $grpCnt = WorkspaceUtil::getContactImgGroupCnt();
    if ( $grpCnt > 0 ) {
	$extra_text = "<u>your own</u>";
    }

    print qq{
        <p>You may select one or more $extra_text
        $folder sets from above to export.
        The exported file may be imported later into your workspace.<br>
        <span style="color:red;font-weight:bold">NOTE</span>:
        Exported $folder sets contain IDs only. To export the contents
        of a $folder set, please go to the $folder set page.</p>
    };

    #    print submit(
    #                  -name    => "_section_Workspace_export_noHeader",
    #                  -value   => "Export \u$folder Sets",
    #                  -class   => "meddefbutton",
    #                  -onClick => "return checkSets('$folder');"
    #    );
    my $contact_oid = WebUtil::getContactOid();
    my $str         = HtmlUtil::trackEvent(
        "Export", $contact_oid,
        "img button $folder _section_Workspace_export_noHeader",
        "return checkSets('$folder');"
    );
    print qq{
   <input class='meddefbutton' name='_section_Workspace_export_noHeader' type="submit" value="Export \u$folder Sets" $str>
 };

    print hiddenVar( "section",    $section );
    print hiddenVar( "importStep", 1 );          # import from file upload
    print hiddenVar( "folder",     $folder );    # to be set in Workspace.js to track url
}

############################################################################
# importWorkspace - Import workspace sets from a tab delimited file
#                   and display them as in a table for selection
############################################################################
sub importWorkspace {
    my $setType    = param("directory");
    my @setFile    = param("filename");
    my $sid        = getContactOid();
    my $super_user = getSuperUser();
    if ( $super_user eq 'Yes' ) {
        @subfolders = ( $GENE_FOLDER, $FUNC_FOLDER, $SCAF_FOLDER, $GENOME_FOLDER, $BC_FOLDER, $RULE_FOLDER );
    }

    my $fh = upload("uploadFile");
    if ( $fh && cgi_error() ) {
        webError( header( -status => cgi_error() ) );
    }

    # Save imported file to tmpFile.
    my $tmpFile   = "$cgi_tmp_dir/${setType}set-import$$.tab.txt";
    my $wfh       = newWriteFileHandle( $tmpFile, "${setType}set-import" );
    my $file_size = 0;

    # Limit upload file size
    while ( my $s = <$fh> ) {
        $s =~ s/\r//g;    # fix DOS/Windows cr-lf
        $file_size += length($s);
        if ( $file_size > $max_upload_size ) {
            print "Maximum file size $max_upload_size bytes exceeded.";
            close $wfh;
            wunlink($tmpFile);
            return 0;
        }
        print $wfh $s;
    }
    close $wfh;

    # Empty file
    if ( $file_size == 0 ) {
        print "File is empty.";
        close $wfh;
        wunlink($tmpFile);
        return 0;
    }
    my $rfh = newReadFileHandle( $tmpFile, "${setType}set-import" );
    my $sit = new StaticInnerTable();
    my $chk =
        "<input type='checkbox' title='Select All'"
      . "checked='checked' onClick='this.checked=true;selAll(1);' />"
      . "&nbsp;<input type='checkbox' title='Clear All'"
      . "onClick='this.checked=false;selAll(0);' />";
    $sit->addColSpec( $chk, "", "center", "", "", "nowrap" );
    $sit->addColSpec("Set Type");
    $sit->addColSpec("Set Name");
    $sit->addColSpec( "Number of IDs", "", "right" );

    my %dupFileName;

    # Start reading file
    my $lineCnt = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $lineCnt++;

        # Get workspace type and filename. (valid types: @subfolders)
        my ( $fileSetType, $fileSetName ) = split( /\t/, $s );
        if ( !$fileSetType ) {
            print "Invalid workspace import file format at line $lineCnt.\n\n"
              . "Please refer to import format specifications in tooltip below.";
            return;
        }
        $fileSetName = "New${fileSetType}set$$"
          if !$fileSetName;

        my $valid = 0;
        for my $type (@subfolders) {
            if ( $fileSetType eq $type ) {
                $valid = 1;
                last;
            }
        }

        if ( !$valid ) {
            print "Invalid workspace type: '$fileSetType' "
              . "at line $lineCnt.\n\nPlease refer to import "
              . "format specifications in tooltip below.";
            return;
        }

        # check for uniqueness of set type and name combination
        my $type_name = "$fileSetType${chkBoxDelim}$fileSetName";
        while ( $dupFileName{$type_name} ) {

            # if duplicate, make unique
            $fileSetName .= "_1";
            $type_name = "$fileSetType${chkBoxDelim}$fileSetName";
        }
        $dupFileName{$type_name} = 1;

        my @setIDs;
        while ( my $s = $rfh->getline() ) {
            chomp $s;
            $lineCnt++;
            my ($oid) = split( /\t/, $s );
            last if blankStr($oid);
            push( @setIDs, $oid );
        }

        my $setCount   = @setIDs;
        my $setIDstr   = join( "\n", @setIDs ) . "\n";
        my $tmpSetFile = $cgi_tmp_dir . "/Workspace-$sid-$fileSetType-$fileSetName";
        str2File( $setIDstr, $tmpSetFile );
        my $row = "<input type='checkbox' name='selected_import' " . "value='$fileSetType${chkBoxDelim}$fileSetName' />\t";
        $row .= "\u$fileSetType\t";
        $row .= "$fileSetName\t";
        $row .= "$setCount\t";
        $sit->addRow($row);
    }
    $sit->printTable();
    close $rfh;
    wunlink($tmpFile);
    WebUtil::webExit(0);
}

############################################################################
# importSelected - Import selected sets from a tab delimited file
#                  and save them in the workspace
############################################################################
sub importSelected {
    my $setType      = param("directory");
    my @setFile      = param("filename");
    my @selections   = param("selected_import");
    my $folder       = param("folder");                       # to get the current Workspace type
    my $sid          = getContactOid();
    my $curWorkspace = "Workspace\u${folder}Set";
    my $url          = "'$main_cgi?section=$curWorkspace'";

    require File::Copy;
    my %setCount;
    my $strMsg;
    for my $chkBoxFile (@selections) {
        my ( $fileSetType, $fileSetName ) = split( /\//, $chkBoxFile );
        $setCount{$fileSetType} = 0 if !$setCount{$fileSetType};
        $setCount{$fileSetType} += 1;
        my $savedTmpFile = "$cgi_tmp_dir/Workspace-$sid-$fileSetType-$fileSetName";
        my $wksSpcFile   = "$workspace_dir/$sid/$fileSetType/$fileSetName";

        while ( -e $wksSpcFile ) {    # if file exists, change name until unique
            $wksSpcFile .= "-copy";
        }

        $savedTmpFile = each %{ { $savedTmpFile, 0 } };    # untaint the variable to make it safe for Perl
        $wksSpcFile   = each %{ { $wksSpcFile,   0 } };    # untaint the variable to make it safe for Perl
        File::Copy::copy( $savedTmpFile, $wksSpcFile )
          or $strMsg = "Failed to copy $wksSpcFile to workspace.";
        wunlink($savedTmpFile);
    }
    if ($strMsg) {                                         # file copy failed
        print $strMsg;
        return;
    } else {
        $strMsg = "Imported into your workspace:\n\n";
        for my $setType ( keys %setCount ) {
            my $unit = "sets";
            $unit = "set" if $setCount{$setType} == 1;
            $strMsg .= "$setCount{$setType} $setType $unit\n";
        }
        print $strMsg;
    }
}

############################################################################
# exportWorkspace - Export selected data sets to tab delimited text file
############################################################################
sub exportWorkspace {
    my $setType = param("directory");
    my @setFile = param("filename");
    my $sid     = getContactOid();

    my $excelFileName = "${setType}sets";
    $excelFileName = $setFile[0] if ( @setFile == 1 );
    $excelFileName .= "_" . lc( getSysDate() ) . ".tab";

    print "Content-type: application/text\n";
    print "Content-Disposition: attachment;filename=$excelFileName\n";
    print "\n";

    exportFile( $setType, \@setFile, $sid );
    WebUtil::webExit(0);
}

############################################################################
# exportAll - Export entire workspace
############################################################################
sub exportAll {
    my $sid  = getContactOid();
    my $user = getUserName();
    my $exFileName .= "\L${user}_workspace_" . lc( getSysDate() ) . ".tab";
    my $super_user = getSuperUser();
    if ( $super_user eq 'Yes' ) {
        @subfolders = ( $GENE_FOLDER, $FUNC_FOLDER, $SCAF_FOLDER, $GENOME_FOLDER, $BC_FOLDER, $RULE_FOLDER );
    }

    print "Content-type: application/text\n";
    print "Content-Disposition: attachment;filename=$exFileName\n";
    print "\n";

    for my $setType (@subfolders) {
        opendir( DIR, "$workspace_dir/$sid/$setType" )
          or webDie("failed to read files");
        my @files = readdir(DIR);

        my @setFile;
        for my $x ( sort @files ) {

            # remove files "."  ".." "~$"
            next if ( $x eq "." || $x eq ".." || $x =~ /~$/ );
            push @setFile, $x;
        }
        exportFile( $setType, \@setFile, $sid );
        closedir(DIR);
    }
    WebUtil::webExit(0);
}

############################################################################
# exportFile - Support function for exporting workspace
#                   input: set type, arrayref of files in set, contactOid
#                   set type: "gene"|"function"|"genome"|"scaffold"
############################################################################
sub exportFile {
    my ( $setType, $setFile, $sid ) = @_;

    my $super_user = getSuperUser();
    if ( $super_user eq 'Yes' ) {
        @subfolders = ( $GENE_FOLDER, $FUNC_FOLDER, $SCAF_FOLDER, $GENOME_FOLDER, $BC_FOLDER, $RULE_FOLDER );
    }

    for my $setName (@$setFile) {
        print "$setType\t$setName\n";

        my $valid = 0;
        foreach my $x (@subfolders) {
            if ( $setType eq $x ) {
                $valid = 1;
                last;
            }
        }
        if ( !$valid ) {
            webError("Invalid directory ($setType).");
        }

        WebUtil::checkFileName($setName);

        # this also untaints the name
        $setName = WebUtil::validFileName($setName);

        my $res = newReadFileHandle("$workspace_dir/$sid/$setType/$setName");
        while ( my $id = $res->getline() ) {
            chomp $id;
            $id = WebUtil::strTrim($id);
            next if ( $id eq "" );
            next if ( ! WebUtil::hasAlphanumericChar($id) );
            print "$id\n";
        }
        close $res;
        print "\n";
    }
}

############################################################################
# printPopUpMarkup - Print the container required by import dialog box
############################################################################
sub printPopUpMarkup {
    print <<POP_UP;

<div id="popup_box" class="yui-pe-content" style="display:none">
<div class="hd">Workspace sets in import file</div>
<div class="bd">
<div id="popup_content" style="max-height:500px;overflow:auto"></div>
</div>
</div>
POP_UP
}

############################################################################
# getStyles - Return common workspace YUI JavaScript and styles
############################################################################
sub getStyles {
    my $ws_yui_js = qq{<!-- WS JS header -->
<link rel="stylesheet" type="text/css" href="$YUI/build/container/assets/skins/sam/container.css" />
<link rel="stylesheet" type="text/css" href="$YUI/build/button/assets/skins/sam/button.css" />
<link rel="stylesheet" type="text/css" href="$YUI/build/datatable/assets/skins/sam/datatable.css">

<script type="text/javascript" src="$YUI/build/container/container-min.js"></script>
<script type="text/javascript" src="$YUI/build/element/element-min.js"></script>
<script type="text/javascript" src="$YUI/build/button/button-min.js"></script>
<script type="text/javascript" src="$YUI/build/dragdrop/dragdrop-min.js"></script>
<script type="text/javascript" src="$YUI/build/animation/animation-min.js"></script>


<style type="text/css">
#modalwait.yui-panel .bd {
   background-image:url("$base_url/images/yui_progressbar.gif");
   background-repeat:no-repeat;
   background-position:center;
   height:30px;
}

.yui-skin-sam .yui-panel .hd {
    font-family: "Helvetica Neue", Arial, Helvetica, sans-serif;
    font-size: 12px;
}

.yui-skin-sam .yui-dialog .yui-panel .hd {
    font-size:12px;
}

.yui-pe .yui-pe-content {
    visibility:hidden;
}

.yui-skin-sam .yui-dialog .ft .button-group {
    font-size:90%;
}

#importTip.yui-panel .bd {
    font-family: "Helvetica Neue",Arial,Helvetica,sans-serif;
    font-size:12px;
    background-color: #FFEE69;
    border-color: #D4C237 #A6982B #A6982B;
    border-style: solid;
}

</style>};
    return $ws_yui_js;
}

sub printJS {
    print qq{
        <script language="javascript" type="text/javascript">
        function mySubmit(section, page, domain, phylum, irclass, family, genus, species, percent) {
            document.mainForm.section.value = section;
            document.mainForm.page.value = page;
            document.mainForm.domain.value = domain;
            document.mainForm.phylum.value = phylum;
            document.mainForm.ir_class.value = irclass;
            document.mainForm.family.value = family;
            document.mainForm.genus.value = genus;
            document.mainForm.species.value = species;
            document.mainForm.percent_identity.value = percent;
            document.mainForm.perc.value = percent;
            document.mainForm.percent.value = percent;
            document.mainForm.submit();
        }

        function mySubmit1(section, page, domain, phylum, irclass, irorder, family, genus, species, percent, xcopy, jobname, datatype) {
            document.mainForm.section.value = section;
            document.mainForm.page.value = page;
            document.mainForm.domain.value = domain;
            document.mainForm.phylum.value = phylum;
            document.mainForm.ir_class.value = irclass;
            document.mainForm.ir_order.value = irorder;
            document.mainForm.family.value = family;
            document.mainForm.genus.value = genus;
            document.mainForm.species.value = species;
            document.mainForm.percent_identity.value = percent;
            document.mainForm.perc.value = percent;
            document.mainForm.percent.value = percent;
            document.mainForm.xcopy.value = xcopy;
            document.mainForm.job_name.value = jobname;
            document.mainForm.data_type.value = datatype;
            document.mainForm.submit();
        }

        function mySubmit2(section, page) {
            document.mainForm.section.value = section;
            document.mainForm.page.value = page;
            document.mainForm.submit();
        }

        </script>
    };
}

sub getGeneScaffoldSql {
    my ($gene_oid_list) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.scaffold
        from gene g
        where g.gene_oid in ( $gene_oid_list )
        $rclause
        $imgClause
        order by 1
    };

    return $sql;
}

sub getGeneGenomeSql {
    my ($gene_oid_list) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.taxon
        from gene g
        where g.gene_oid in ( $gene_oid_list )
        $rclause
        $imgClause
        order by 1
    };

    return $sql;
}

sub getSingleScaffoldGenesSql {

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.gene_oid
        from gene g
    	where g.scaffold = ?
        $rclause
        $imgClause
        order by 1
	};

    #print "getSingleScaffoldGenesSql sql: $sql<br/>\n";

    return $sql;
}

sub getScaffoldGeneSql {
    my ($scaf_oid_list) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.gene_oid
        from gene g
        where g.scaffold in ( $scaf_oid_list )
        $rclause
        $imgClause
        order by 1
    };

    return $sql;
}

sub getScaffoldGenomeSql {
    my ($scaf_oid_list) = @_;

    my $rclause   = WebUtil::urClause('s.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    my $sql       = qq{
        select distinct s.taxon
        from scaffold s
        where s.scaffold_oid in ( $scaf_oid_list )
        $rclause
        $imgClause
        order by 1
    };

    return $sql;
}

##########################################################################
# getIsJgiUser - whether the user is a JGI user
##########################################################################
sub getIsJgiUser {
    my ($contact_oid) = @_;

    my $dbh = dbLogin();

    my $sql = qq{
        select contact_oid, jgi_user
            from contact
            where contact_oid = $contact_oid
    };
    my $cur = $dbh->prepare($sql);
    $cur->execute();
    my ( $c_oid, $isJgiUser ) = $cur->fetchrow_array();
    $cur->finish();

    #$dbh->disconnect();

    if ( defined($c_oid) ) {
        return $isJgiUser;
    }

    return 'No';
}

############################################################################
# printSubmitComputation - Print submit computation
############################################################################
sub printSubmitComputation {
    my ( $sid, $folder, $jobPrefix, $submitName, $moreInfo, $existing_jobs_ref ) = @_;

    my $jobType    = 'function profile';
    my $wsSaveMode = 'ws_save_mode';
    my $jobResultName = 'job_result_name';
    my $selectedJobName = 'selected_job_name';

    if ( $jobPrefix ) {
        if ( $jobPrefix =~ /func_profile/i ) {
            $jobType = 'function profile';
        }
        elsif ( $jobPrefix =~ /histogram/i ) {
            $jobType = 'histogram';
        }
        elsif ( $jobPrefix =~ /kmer/i ) {
            $jobType = 'kmer';
        }
        elsif ( $jobPrefix =~ /phylo/i ) {
            $jobType = 'phylogenetic distribution';
        }
        elsif ( $jobPrefix =~ /blast/i ) {
            $jobType = 'Blast';
        }
        elsif ( $jobPrefix =~ /pairwise_ani/i ) {
            $jobType = 'Pairwise ANI';
        }
        elsif ( $jobPrefix =~ /func_scaf_search/i ) {
            $jobType = 'Function Scaffold Search';
        }
        $wsSaveMode = $jobPrefix . '_save_mode';
        $jobResultName = $jobPrefix . '_job_result_name';
        $selectedJobName = $jobPrefix . '_selected_job_name';
    }

    print "<p>\n";
    print "<h2>Submit as Computation Job Using Message System</h2>\n";

    print "<p>You may submit a $folder set $jobType computation to run in the background.\n";
    if ( $moreInfo ) {
        print "<br/>\n";
        print $moreInfo;
    }
    print "</p>\n";

    print "<p>\n";
    print "<input type='radio' name='$wsSaveMode' value='save' checked />\n";
    print "Save as a new job with name:" . nbsp(1);
    print "<input type='text' size='$filename_size' maxLength='$filename_len' "
      . "name='$jobResultName' "
      . "title='All special characters will be removed and spaces converted to _ ' />";
    print "</p>\n";

    my $onclickCall;
    if ( scalar(@$existing_jobs_ref) > 0 ) {
        print "<p>\n";
        print "<input type='radio' name='$wsSaveMode' value='replace' />\n";
        print "Replace the selected job: \n";
        print nbsp(5);
        print "<select name='$selectedJobName'>\n";
        for my $x ( sort @$existing_jobs_ref ) {
            print "<option value='$x'>$x</option>\n";
        }
        print "</select>\n";
        print "</p>\n";
        if ( $jobPrefix && $jobPrefix =~ /kmer/i ) {
            $onclickCall = "return validateAndCheckSets('$jobResultName', '$wsSaveMode', '$folder');";
        }
        elsif ( $jobPrefix && $jobPrefix =~ /pairwise_ani/i ) {
            $onclickCall = "return checkTwoSetsIncludingShareAndFileName('$jobResultName', '$wsSaveMode', '$folder');";
        }
        else {
            $onclickCall = "return checkSetsIncludingShareAndFileName('$jobResultName', '$wsSaveMode', '$folder');";
        }
    }
    else {
        if ( $jobPrefix && $jobPrefix =~ /kmer/i ) {
            $onclickCall = "return validateAndCheckSets('$jobResultName', '', '$folder');";
        }
        elsif ( $jobPrefix && $jobPrefix =~ /pairwise_ani/i ) {
            $onclickCall = "return checkTwoSetsIncludingShareAndFilled('$jobResultName', '$folder');";
        }
        else {
            $onclickCall = "return checkSetsIncludingShareAndFilled('$jobResultName', '$folder');";
        }
    }
    print "<p>\n";
    print submit(
        -name    => $submitName,
        -value   => "Submit Computation",
        -class   => "medbutton",
        -onClick => $onclickCall
    );
    print "</p>\n";
}

#####################################################################
# submitFuncProfile
#####################################################################
sub submitFuncProfile {
    my ($folder) = @_;

    printMainForm();

    my $wsSaveMode = param('func_profile_save_mode');
    if ( ! $wsSaveMode ) {
        $wsSaveMode = param('ws_save_mode');
    }

    my $job_result_name;
    if ( $wsSaveMode eq 'save' ) {
        $job_result_name = param('func_profile_job_result_name');
        if ( ! $job_result_name ) {
            $job_result_name = param('job_result_name');
        }
        if ( !$job_result_name ) {
            webError("Please specify a job name.");
            return;
        }
    } else {
        # replace
        $job_result_name = param('func_profile_selected_job_name');
        if ( ! $job_result_name ) {
            $job_result_name = param('selected_job_name');
        }
        if ( ! $job_result_name ) {
            webError("Please select a job.");
            return;
        }
    }

    my $dbh = dbLogin();
    my $sid = WebUtil::getContactOid();
    $sid = sanitizeInt($sid);

    my $ws_profile_type = param('ws_profile_type');
    my $func_set_name;
    my $share_func_set_name;
    my $func_set_names_message;
    my $functype;
    if ( $ws_profile_type eq 'func_category' ) {
        $functype = param('functype');
        if ( !$functype ) {
            webError("No function category has been selected.");
            return;
        }
        print "<h2>Computation Job Submission (function category)</h2>\n";
        $functype = MetaUtil::sanitizeGeneId3($functype);
        print "<p>Function Category: $functype\n";
    } else {
        $func_set_name = param('func_set_name');
    	### FIXME: set to my own data set only
    	my ( $owner, $x) = WorkspaceUtil::splitOwnerFileset( $sid, $func_set_name );
        if ( !$x ) {
            webError("No function set has been selected.");
            return;
        }
        $x = MetaUtil::sanitizeGeneId3($x);
        $share_func_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $owner, $x, $sid );
        $func_set_names_message = WorkspaceUtil::getOwnerFilesetName( $owner, $x, $ownerFilesetDelim_message, $sid );

        print "<h2>Computation Job Submission (function set $share_func_set_name)</h2>\n";
        print "<p>Function Set: $share_func_set_name<br/>\n";
    }

    $job_result_name =~ s/\W+/_/g;
    my $output_name = MetaUtil::sanitizeGeneId3($job_result_name);

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
        webError("Please select at least one $folder set.");
        return;
    }

    my $data_type = param('data_type');

    my $folder_uc = '';
    if ( $folder =~ /genome/i ) {
        $folder_uc = 'Genome';
    } elsif ( $folder =~ /gene/i ) {
        $folder_uc = 'Gene';
    } elsif ( $folder =~ /scaffold/i ) {
        $folder_uc = 'Scaffold';
    }
    print "$folder_uc Set(s): $share_set_names<br/>\n";

    if ( $data_type ) {
        HtmlUtil::printMetaDataTypeSelection( $data_type, 2 );
    }

    my $job_file_dir = getJobFileDirReady( $sid, $output_name );

    ## output info file
    my $info_file = "$job_file_dir/info.txt";
    my $info_fs   = newWriteFileHandle($info_file);
    print $info_fs "$folder_uc Function Profile\n";
    if ( $ws_profile_type eq 'func_category' ) {
        print $info_fs "--functype $functype\n";
    } else {
        print $info_fs "--function $share_func_set_name\n";
    }
    print $info_fs "--$folder $share_set_names\n";
    print $info_fs "--datatype $data_type\n";
    print $info_fs currDateTime() . "\n";
    close $info_fs;

    #old code that uses .py files, keep it as reference
    #if ( $env->{client_py_exe} ) {
    #    #$ENV{'PATH'}.='/global/homes/i/imachen/amy_home/img_dev/v2/webUI/webui.cgi/';
    #    $ENV{'PATH'} .= $env->{client_path};
    #    my @cmd = ();
    #    if ( $folder =~ /gene/i ) {
    #        @cmd = (
    #            "client_wrapper.sh", "--program", "geneFuncSetProfile", "--contact", "$sid", "--output",
    #            "$output_name",      "--geneset", "$set_names"
    #        );
    #    } elsif ( $folder =~ /scaffold/i ) {
    #        @cmd = (
    #            "client_wrapper.sh", "--program", "scafFuncSetProfile", "--contact", "$sid", "--output",
    #            "$output_name",      "--scafset", "$set_names"
    #        );
    #    }
    #
    #    if ( $ws_profile_type eq 'func_category' ) {
    #        push @cmd, ( "--functype", "$functype" );
    #    } else {
    #        push @cmd, ( "--funcset", "$func_set_name" );
    #    }
    #
    #    printStartWorkingDiv();
    #    print "<p>cmd: " . join( " ", @cmd ) . "<p>\n";
    #
    #    WebUtil::unsetEnvPath();
    #    my $st = system( $env->{client_py_exe}, @cmd );
    #
    #    #my $st = runCmdNoExit($cmd);
    #    #print "<p>st: ".($st>>8)."\n";
    #    printEndWorkingDiv();
    #
    #    if ($st) {
    #        print "<p><font color='red'>Error Code: $st</font>\n";
    #    } else {
    #        print "<p>Job is submitted successfully.\n";
    #    }
    #
    #    #my $fh = newCmdFileHandle( $cmd, 'client_py' );
    #    #my $line = "";
    #    #while ( $line = $fh->getline() ) {
    #    #    chomp($line);
    #    #    print "<p>$line\n";
    #    #}
    #    #close $fh;
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
    my $queue_filename = $sid . '_' . $folder . '_' . $output_name;
    my $wfh = newWriteFileHandle($queue_dir . $queue_filename);

    if ( $folder =~ /genome/i ) {
        print $wfh "--program=genomeFuncSetProfile\n";
        print $wfh "--contact=$sid\n";
        print $wfh "--output=$output_name\n";
        print $wfh "--genomeset=$set_names_message\n";
    } elsif ( $folder =~ /gene/i ) {
        print $wfh "--program=geneFuncSetProfile\n";
        print $wfh "--contact=$sid\n";
        print $wfh "--output=$output_name\n";
        print $wfh "--geneset=$set_names_message\n";
    } elsif ( $folder =~ /scaffold/i ) {
        print $wfh "--program=scafFuncSetProfile\n";
        print $wfh "--contact=$sid\n";
        print $wfh "--output=$output_name\n";
        print $wfh "--scafset=$set_names_message\n";
    }

    if ( $data_type ) {
        print $wfh "--datatype=$data_type\n";
    }

    if ( $ws_profile_type eq 'func_category' ) {
        #push @cmd, ( "--functype", "$functype" );
        print $wfh "--functype=$functype\n";
    } else {
        #push @cmd, ( "--funcset", "$func_set_name" );
        print $wfh "--funcset=$func_set_names_message\n";
    }
    close $wfh;

    rsync($sid);
    print "<p>Job is submitted successfully.\n";

    print end_form();
}

#####################################################################
# validJobSetNameToSaveOrReplace
#####################################################################
sub validJobSetNameToSaveOrReplace {
    my ( $lcJobPrefix ) = @_;

    my $job_result_name;
    my $save_mode_param = $lcJobPrefix . '_save_mode';
    my $wsSaveMode = param($save_mode_param);
    if ( $wsSaveMode eq 'save' ) {
        my $job_result_param = $lcJobPrefix . '_job_result_name';
        $job_result_name = param($job_result_param);
        if ( ! $job_result_name ) {
            webError("Please specify a job name.");
            return;
        }
    } else {
        # replace
        my $job_result_param = $lcJobPrefix . '_selected_job_name';
        $job_result_name = param($job_result_param);
        if ( ! $job_result_name ) {
            $job_result_name = param('selected_job_name');
        }
        if ( ! $job_result_name ) {
            webError("Please select a job.");
            return;
        }
    }

    $job_result_name =~ s/\W+/_/g;
    $job_result_name= MetaUtil::sanitizeGeneId3($job_result_name);

    return $job_result_name;
}

#####################################################################
# getJobFileDirReady
#####################################################################
sub getJobFileDirReady {
    my ( $sid, $output_name ) = @_;

    my $job_dir = "$workspace_dir/$sid/job";
    if ( !-e $job_dir ) {
        umask 0002;
        mkdir $job_dir or webError("Workspace is down!");
    }

    my $job_file_dir = "$job_dir/$output_name";
    if ( !-e $job_file_dir ) {
        mkdir $job_file_dir or webError("Workspace is down!");
    }
    else {
        cleanOldFiles( $job_file_dir );
        cleanOldFiles( "$workspace_sandbox_dir/$sid/job/$output_name" );
    }

    return $job_file_dir;
}


#####################################################################
# cleanOldFiles - clean out old files
#####################################################################
sub cleanOldFiles {
    my ( $job_file_dir ) = @_;

    if ( -e $job_file_dir ) {
        opendir( DIR, $job_file_dir )
          or webDie("failed to read files");
        my @files = readdir(DIR);

        for my $x (@files) {
            next if ( $x eq "." || $x eq ".." );
            $x = MetaUtil::sanitizeGeneId3($x);

            my $fname = "$job_file_dir/$x";
            unlink $fname;
        }
    }
}

#####################################################################
# rsync -azvO
#     /webfs/projectdirs/microbial/img/web_data/workspace/3038
#      /global/projectb/sandbox/IMG_web/workspace_temp/workspace
#####################################################################
sub rsync {
    my ($contact_oid) = @_;

    if ( ! $contact_oid ) {
        webError("contact oid cannot be null.");
    }

    #
    # BUG need to ignore running job dir - how? the rsync overwrites the profile.txt files etc ....
    # http://www.thegeekstuff.com/2011/01/rsync-exclude-files-and-folders/
    #  -u, --update                skip files that are newer on the receiver
    my $worspaceDirWebfs = $workspace_dir . '/' . $contact_oid;
    my $cmd = "/usr/bin/rsync -auzvO $worspaceDirWebfs $workspace_sandbox_dir";

    WebUtil::unsetEnvPath();
    if( $img_ken || $contact_oid == 107 || $contact_oid == 100546 ) {
        print "Running: $cmd <br>\n";
    }
    print "<p>Submitting job....<br>\n";

    my $st = system($cmd);
    if ( $st != 0 ) {
        print "Error: $cmd failed to run $? <br>\n";
    }
}

##################################################################
# printSetSelectOptions
##################################################################
sub printSetSelectOptions {
    my ( $sid, $folder ) = @_;

    my @set_names = getDataSetNames( $folder );
    for my $name2 (sort @set_names) {
        my $k = $sid . $ownerFilesetDelim . $name2;
        print "<option value='$k' > $name2 </option> \n";
    }

    my %share_h = WorkspaceUtil::getShareFromGroups( $folder );
    for my $k (keys %share_h) {
        my ($c_oid, $data_set_name) = WorkspaceUtil::splitOwnerFileset( $sid, $k );
        my ($g_id, $g_name, $c_name) = split(/\t/, $share_h{$k});
        print "<option value='$k' > $data_set_name (owner: $c_name) </option> \n";
    }

}

##################################################################
# printUseFunctionsInSet
##################################################################
sub printUseFunctionsInSet {
    my ( $sid ) = @_;

    print "<p/>\n";
    print "<input type='radio' name='ws_profile_type' "
        . "value='func_set' checked>Use only functions in set:\n";
    print "&nbsp;\n";
    print "<select name='func_set_name'>\n";
    printSetSelectOptions( $sid, $FUNC_FOLDER );
    print "</select>\n";
}

##################################################################
# printUseAllFunctionTypes
##################################################################
sub printUseAllFunctionTypes {

    print "<p/>\n";
    print "<input type='radio' name='ws_profile_type' "
        . "value='func_category' >Use all functions of type:\n";
    print qq{
        &nbsp;
        <select name='functype' style="width:220px;" >
        <option value='COG' selected='selected'>COG</option>
        <option value='COG_Category'>COG Categories</option>
        <option value='COG_Pathway'>COG Pathways</option>
        <option value='Enzymes'>Enzymes</option>
        <option value='KEGG_Category_EC'>KEGG Categories via EC</option>
        <option value='KEGG_Category_KO'>KEGG Categories via KO Terms</option>
        <option value='KEGG_Pathway_EC'>KEGG Pathways via EC</option>
        <option value='KEGG_Pathway_KO'>KEGG Pathways via KO Terms</option>
        <option value='KO'>KO</option>
        <option value='Pfam'>Pfam</option>
        <option value='Pfam_Category'>Pfam Categories</option>
        <option value='TIGRfam'>TIGRfam</option>
        <option value='TIGRfam_Role'>TIGRfam Category Roles</option>
        </select>
    };

}

sub isSimpleFuncType {
    my ( $functype ) = @_;

    if (   $functype eq 'COG'
        || $functype eq 'Pfam'
        || $functype eq 'TIGRfam'
        || $functype eq 'KO'
        || $functype eq 'Enzymes' )
    {
        return 1;
    }

    return 0;
}

sub isComplicatedFuncCategory {
    my ( $functype ) = @_;

    if (   $functype eq 'COG_Category'
        || $functype eq 'COG_Pathway'
        || $functype eq 'Pfam_Category'
        || $functype eq 'KEGG_Category_EC'
        || $functype eq 'KEGG_Category_KO'
        || $functype eq 'KEGG_Pathway_EC'
        || $functype eq 'KEGG_Pathway_KO'
        || $functype eq 'TIGRfam_Role' )
    {
        return 1;
    }

    return 0;
}


1;
