########################################################################
# Workspace BC set / cart
#
# There is no BC set as of yet because of changing BC ids.
# This is as of now a BC cart but the temp storage will be in the workspace
#
# for workspace the temp cart file is teh unsaved buffer file
#
# $Id: WorkspaceBcSet.pm 33905 2015-08-05 20:24:41Z klchu $
########################################################################
package WorkspaceBcSet;

use strict;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use Tie::File;
use File::Copy;
use Template;
use TabHTML;
use InnerTable;
use WebConfig;
use WebUtil;
use Workspace;

$| = 1;

my $section              = "WorkspaceBcSet";
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
my $mer_data_dir         = $env->{mer_data_dir};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $enable_workspace     = $env->{enable_workspace};

my $sid         = WebUtil::getContactOid();
my $contact_oid = $sid;
my $BC_DIR      = $workspace_dir . '/' . $sid . '/bc/';

sub getPageTitle {
    return 'Workspace';
}

sub getAppHeaderData {
    my ($self) = @_;

    my @a = ();
    if ( WebUtil::paramMatch("noHeader") ne "" ) {
        return @a;
    } else {

        #push(@a, "MyIMG", '', '', '', '', 'IMGWorkspaceUserGuide.pdf');
        push( @a, "MyIMG" );
        return @a;
    }
}

# add button "add to BC Cart / workspace buffer"
# https://img-stage.jgi-psf.org/cgi-bin/img_ken_m/main.cgi?section=BiosyntheticDetail&page=biosynthetic_clusters&taxon_oid=637000129
# and here too
# https://img-stage.jgi-psf.org/cgi-bin/img_ken_m/main.cgi?section=BcNpIDSearch
# bc id search was 160320026
#
# url to BC cart or set directory listing
# https://img-stage.jgi-psf.org/cgi-bin/img_ken_m/main.cgi?section=WorkspaceBcSet
#
sub dispatch {
    my ( $self, $numTaxons ) = @_;

    my $page      = param('page');
    my @filenames = param('filename');    # to workspace set
    my @bcIds     = param('bc_id');

    my $sid = WebUtil::getContactOid();
    return if ( $sid == 0 || $sid < 1 || $sid eq '901' );

    # check to see user's folder has been created
    Workspace::initialize();

    if ( $page eq 'addToBcBuffer' || paramMatch("addToBcBuffer") ne "" ) {

        addBcIds( \@bcIds, $filenames[0] );

    } elsif ( $page eq 'deleteBcIds' || paramMatch("deleteBcIds") ne "" ) {

        #print "deleting<br>\n";
        deleteBcIds( \@bcIds, $filenames[0] );
    } elsif ( $page eq 'delete' || paramMatch("delete") ne "" ) {
        deleteSelectedFiles();
    } elsif ( $page eq 'saveBc' || paramMatch("saveBc") ne "" ) {
        saveToWorkspace();
    }

    if ( $page eq 'viewCart' ) {
        printBuffer();
    } elsif ( $page eq 'viewSet' ) {
        printSetList();
    } else {

        printWorkspaceSets();
    }

}

# print list bc workspace sets
sub printWorkspaceSets {
    print qq{
      <h1>BC Workspace List</h1>  
    };

    my %file2Size;    # bc set file names to bc id count
    my $bufferFilename = '';
    my $bufferIdCount  = 0;

    print qq{
        <h2>BC Cart</h2>
        <p>
    };

    if ( !isEmptyCart() ) {

        # show the buffer
        $bufferFilename = getBufferFile();

        # get the ids count
        my $aref = getAllIds();
        $bufferIdCount = $#$aref + 1;

        print qq{
            You have <a href='main.cgi?section=WorkspaceBcSet&page=viewCart'> $bufferIdCount BC Ids</a> in your cart.<br>
        };

        if ($enable_workspace) {
            print qq{
                <a href='main.cgi?section=WorkspaceBcSet&page=viewCart'>View BC cart</a> to save it to your workspace. <br> 
                Your cart data will be lost when you logout or close your browser
            };
        } else {
            return;    # public site no workspace
        }

    } else {
        print "Your BC Cart is empty.";
    }

    print qq{ </p>
        <h2>BC Sets List</h2>
    };

    # read bc file list
    #
    my @files = getAllBcSetFilenames();

    # get all the set sizes
    foreach my $f (@files) {
        my $aref = getAllIds($f);
        my $cnt  = $#$aref + 1;
        $file2Size{$f} = $cnt;
    }

    my $txTableName = "bctable";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 1 );
    my $sd          = $it->getSdDelim();                                        # sort delimiter

    # columns headers
    $it->addColSpec("Select");
    $it->addColSpec( "File Name",        'num asc', 'right' );
    $it->addColSpec( "Number of BC Ids", "desc",    "right" );

    my $count = 0;
    foreach my $file ( keys %file2Size ) {
        my $row = $sd . "<input type='checkbox' name='filename' value='$file' />\t";
        $row .= $file . $sd . $file . "\t";

        my $size = $file2Size{$file};
        my $url  = "main.cgi?section=$section&page=viewSet&filename=$file";
        $url = alink( $url, $size );
        $row .= $size . $sd . $url . "\t";

        $it->addRow($row);
        $count++;
    }

    printMainForm();

    if ($count) {
        WebUtil::printButtonFooterInLine();

        print nbsp(1);
        print submit(
                      -name    => "_section_" . $section . "_delete",
                      -value   => 'Remove Selected',
                      -class   => 'medbutton',
                      -onClick => "return confirmDelete('bc');"
        );

        $it->printOuterTable(1);

    } else {
        print "<h5>No workspace BC sets.</h5>\n";
    }

    print end_form();

}

sub getAllBcSetFilenames {

    #
    opendir( DIR, "$BC_DIR" ) or webDie("failed to open folder list");
    my @files = readdir(DIR);
    closedir(DIR);

    # filter out . and ..
    my @a;
    foreach my $f (@files) {
        next if ( $f eq '.' || $f eq '..' );
        push( @a, $f );
    }
    return @a;
}

# this should show the contents of a bc cart or set bc set
#
# $filename - full absolute path to bc cart file or set
sub printBuffer {
    print qq{
      <h1>BC Cart</h1\>  
    };

    my $filename = getBufferFile();

    my $list_aref = getAllIds();

    my $txTableName = "bctable";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 1 );
    my $sd          = $it->getSdDelim();                                        # sort delimiter

    # columns headers
    $it->addColSpec("Select");
    $it->addColSpec( "BC Id", 'num asc', 'right' );

    my $count = 0;
    foreach my $bcId (@$list_aref) {
        my $row = $sd . "<input type='checkbox' name='bc_id' value='$bcId' />\t";
        $row .= $bcId . $sd . $bcId . "\t";
        $it->addRow($row);
        $count++;
    }

    #printCartTab1Start();
    TabHTML::printTabAPILinks("bcTab");
    my @tabIndex = ( "#bccarttab1", "#bccarttab2" );
    my @tabNames = ( "BC in Cart",  "Upload & Export & Save" );
    TabHTML::printTabDiv( "bcTab", \@tabIndex, \@tabNames );

    print "<div id='bccarttab1'>";

    printMainForm();

    WebUtil::printButtonFooterInLineWithToggle();
    print nbsp(1);

    print submit(
                  -id    => "remove",
                  -name  => "_section_WorkspaceBcSet_deleteBcIds",
                  -value => "Remove Selected",
                  -class => "meddefbutton"
    );

    $it->printOuterTable(1);

    printSave2BcSet();

    #printCartTab1End($count);
    printStatusLine( "$count BC(s) in cart.", 2 ) if $count > 0;
    print "</div>";

    # end genomecarttab1
    #printCartTab2($count);
    print "<div id='bccarttab2'>";
    print "<h2>Upload BC Cart</h2>";

    my $textFieldId = "cartUploadFile";
    print "File to upload:<br/>\n";
    print "<input id='$textFieldId' type='file' name='uploadFile' size='45'/>";
    print "<br/>\n";

    my $name = "_section_${section}_uploadBcCart";
    print submit(
                  -name    => $name,
                  -value   => "Upload from File",
                  -class   => "medbutton",
                  -onClick => "return uploadFileName('$textFieldId');",
    );

    print "<h2>Export BC</h2>";
    print "<p>\n";
    print "You may select BC from the cart to export.";
    print "</p>\n";

    my $name = "_section_${section}_exportBc_noHeader";
    my $str = HtmlUtil::trackEvent( "Export", $contact_oid, "img button $name" );
    print qq{
    <input class='medbutton' name='$name' type="submit" value="Export BC" $str>
    };

    print "</div>";    # end bccarttab2

    TabHTML::printTabDivEnd();

    print end_form();
}

sub printSetList {
    my $filename = param('filename');

    if ( $filename && !blankStr($filename) ) {
        WebUtil::checkFileName($filename);
        $filename = WebUtil::validFileName($filename);

        $filename =~ s/\W+/_/g;
    }

    my $path = $BC_DIR . $filename;
    if ( !-e $path ) {
        webDie("$filename does not exists.");
        return;
    }

    my $rfh = newReadFileHandle($path);
    my @ids;

    while ( my $id = $rfh->getline() ) {
        chomp $id;
        next if ( $id eq "" );
        push( @ids, $id );
    }

    close $rfh;

    my $txTableName = "bctable";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 1 );
    my $sd          = $it->getSdDelim();                                        # sort delimiter

    # columns headers
    $it->addColSpec("Select");
    $it->addColSpec( "BC Id", 'num asc', 'right' );

    my $count = 0;
    foreach my $bcId (@ids) {
        my $row = $sd . "<input type='checkbox' name='bc_id' value='$bcId' />\t";
        $row .= $bcId . $sd . $bcId . "\t";
        $it->addRow($row);
        $count++;
    }

    $it->printOuterTable(1);
    printStatusLine( "$count rows", 2 ) if $count > 0;
}

#
# print Save to BC My workpsace section
#
sub printSave2BcSet {

    my @files  = getAllBcSetFilenames();
    my @sorted = sort @files;

    print qq{
<h2>Save BC to My Workspace</h2>
<p>
Save <b>selected BC</b> to <a href="main.cgi?section=Workspace">My Workspace</a>.<br/>(<i>Special characters in file name will be removed and spaces converted to _ </i>)<br/><br/>

<input type='radio' name='ws_save_mode' value='save' checked />
Save to File name:&nbsp; <input id='workspace' type='text' name='workspacefilename' size='25' maxLength='60' title='All special characters will be removed and spaces converted to _' /><br/>
<input type='radio' name='ws_save_mode' value='append' /> Append to the following genome set: <br/>
<input type='radio' name='ws_save_mode' value='replace' /> Replacing the following genome set: <br/>
&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 
<select name='selectedwsfilename'>
    };

    foreach my $f (@sorted) {
        print "<option value='$f'>$f</option>\n";
    }

    print qq{
</select>
<br/>
<input type="submit" name="_section_WorkspaceBcSet_saveBc" value="Save Selected to Workspace" 
onclick="" class="medbutton" />
</p>
};

}

# save to workspace
#
#
sub saveToWorkspace {
    my $saveMode           = param('ws_save_mode');
    my $selectedwsfilename = param('selectedwsfilename');    # replace mode
    my $filename           = param('workspacefilename');
    my @bcIds              = param('bc_id');
    my $sid                = WebUtil::getContactOid();

    if ( $filename && !blankStr($filename) ) {
        WebUtil::checkFileName($filename);
        $filename = WebUtil::validFileName($filename);

        $filename =~ s/\W+/_/g;
    }

    if ( $saveMode eq 'save' ) {
        if ( -e "$workspace_dir/$sid/bc/$filename" ) {
            webError("File name $filename already exists. Please enter a new file name.");
            return;
        }

        my $path = "$workspace_dir/$sid/bc/$filename";
        my $wfh  = newWriteFileHandle($path);
        foreach my $id (@bcIds) {
            print $wfh "$id\n";
        }
        close $wfh;

    } elsif ( $saveMode eq 'append' ) {

        # TODO check for duplicates and do not add duplicate ids
        my $path = "$workspace_dir/$sid/bc/$selectedwsfilename";
        my $wfh  = newAppendFileHandle($path);
        foreach my $id (@bcIds) {
            print $wfh "$id\n";
        }
        close $wfh;

    } elsif ( $saveMode eq 'replace' ) {
        my $path = "$workspace_dir/$sid/bc/$selectedwsfilename";
        my $wfh  = newWriteFileHandle($path);
        foreach my $id (@bcIds) {
            print $wfh "$id\n";
        }
        close $wfh;
    }

}

#
# add a list of bc ids to the cart / set
#
# array ref to bc ids
# $filename - workspace filename not path - blank for bc cart
sub addBcIds {
    my ( $bcId_aref, $filename ) = @_;

    if ( $filename eq '' ) {
        $filename = getBufferFile();
    } else {
        $filename = $BC_DIR . $filename;
    }

    # TODO remove duplicates - ken
    my %distinct;
    my $rfh = newReadFileHandle($filename);
    while ( my $id = $rfh->getline() ) {
        chomp $id;
        next if ( $id eq "" );
        $distinct{$id} = $id;
    }
    close $rfh;
    my $afh = WebUtil::newAppendFileHandle($filename);

    foreach my $bcId (@$bcId_aref) {
        if ( exists $distinct{$bcId} ) {

            #print "skipping id: $bcId <br>\n";
        } else {

            #print "adding: $bcId <br>";
            print $afh "$bcId\n";
        }
    }
    close $afh;
}

# delete a bc id from cart or set
#
# bc id to delete
# $filename - workspace filename not path - blank for bc cart
sub deleteBcId {
    my ( $bcId, $filename ) = @_;
    if ( $filename eq '' ) {
        $filename = getBufferFile();
    } else {
        $filename = $BC_DIR . $filename;
    }

    my @array;
    my $j = -1;
    tie @array, 'Tie::File', $filename or die "delete from failed $!\n";
    for ( my $i = 0 ; $i <= $#array ; $i++ ) {
        if ( $bcId eq $array[$i] ) {
            $j = $i;
            last;
        }
    }

    if ( $j > -1 ) {
        splice @array, $j, 1;
    }

    untie @array;    # done and should close the open file
}

#
# delete a list of bc ids
#
sub deleteBcIds {
    my ( $bcId_aref, $filename ) = @_;
    if ( $filename eq '' ) {
        $filename = getBufferFile();
    } else {
        $filename = $BC_DIR . $filename;
    }

    my %deleteIds = array2Hash(@$bcId_aref);

    # open file file to read
    # open a temp file to write
    # move temp file to read file

    my $tempfile = getBufferFile() . '_' . $$;
    my $rfh      = newReadFileHandle($filename);
    my $wfh      = newWriteFileHandle($tempfile);
    while ( my $line = $rfh->getline() ) {
        chomp $line;
        if ( !exists $deleteIds{$line} ) {
            print $wfh "$line\n";
        }
    }

    close $wfh;
    close $rfh;

    # do i have to unlink $filename first?
    move( $tempfile, $filename );
}

# all ids in cart
#
# # $filename - workspace filename not path - blank for bc cart
sub getAllIds {
    my ($filename) = @_;

    if ( $filename eq '' ) {
        $filename = getBufferFile();
    } else {
        $filename = $BC_DIR . $filename;
    }

    my @records;
    my $res = newReadFileHandle( $filename, "runJob", 1 );
    if ( !$res ) {
        return \@records;
    }
    while ( my $line = $res->getline() ) {
        chomp $line;
        next if ( $line eq "" );

        #my ( $s_oid, $contact_oid, $batch_id, $name ) = split( /\t/, $line );
        push( @records, $line );
    }
    close $res;
    return \@records;

}

#
# the cart name or buffer
# return full absolute path to file
#
sub getBufferFile {

    # temp file - cart file or the unsaved workspace set
    my $BUFFER_DIR         = WebUtil::getSessionDir() . '/';
    my $BC_PREFIX_CARTNAME = 'tempBcCart_';

    # fyi this file will be cleanup by a nightly cronjob
    my $tempFilename = $BUFFER_DIR . $BC_PREFIX_CARTNAME . $contact_oid;

    if ( !-e $tempFilename ) {

        # make a empty file
        open( MYFILE, ">>$tempFilename" );    # won't erase the contents if already exists
        close MYFILE;
    }

    return $tempFilename;
}

# delete the cart / buffer on exit or ui
#
# what happens if the user does not exit / logout
# - no logout for publoc ABC
#
# - session files will build up see deleteOldCarts()
#
sub deleteBufferFile {
    unlink getBufferFile();
}

#
# is the cart / buffer file empty
#
# I've tried with -z and -s but a newline / blank lines in the file are causing issues too - ken
#
sub isEmptyCart {
    my $res = newReadFileHandle( getBufferFile(), "runJob", 1 );
    if ( !$res ) {
        return 1;
    }
    while ( my $line = $res->getline() ) {
        chomp $line;
        next if ( $line eq "" );
        close $res;
        return 0;
    }
    close $res;
    return 1;
}

sub deleteSelectedFiles {
    my @files = param('filename');

    foreach my $f (@files) {
        if ( $f eq getBufferFile() ) {
            deleteBufferFile();
        } else {
            unlink $BC_DIR . $f;
        }

    }
}

1;
