########################################################################
# Workspace BC set / cart
#
# There is no BC set as of yet because of changing BC ids.
# This is as of now a BC cart but the temp storage will be in the workspace
#
# for workspace the temp cart file is teh unsaved buffer file
#
# $Id: WorkspaceBcSet.pm 33837 2015-07-29 18:35:02Z klchu $
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

my $sid = WebUtil::getContactOid();
my $contact_oid = $sid;
my $BC_DIR             = $workspace_dir. '/' . $sid . '/bc/';

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
    my $page = param('page');
    my $filename = param('filename'); # to workspace set
    my @bcIds = param('bc_id');
    
    my $showBcWorkspaceList = 0;
    $showBcWorkspaceList = 1 if($filename ne ''); # or should this be the enable workspace flag. 
    
    #print "page: $page<br>";
    if($page eq 'addToBcBuffer' || paramMatch("addToBcBuffer") ne "") {
        
        addBcIds(\@bcIds, $filename);
                
    } elsif($page eq 'deleteBcIds' || paramMatch("deleteBcIds") ne "") {
        #print "deleting<br>\n";
        deleteBcIds(\@bcIds, $filename);
    }
    
    if($showBcWorkspaceList) {
        printWorkspaceSets();
    } else {
        printBuffer();
    }
}

# print list bc workspace sets
sub printWorkspaceSets {
    opendir( DIR, "$BC_DIR" )
      or webDie("failed to open folder list");
    my @files = readdir(DIR);
    closedir(DIR);

    print qq{
      <h1>BC Workspace List</h1\>  
    };
    

    print "<p>\n";
    print Dumper \@files;
    print "</p>\n";    
        
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
    $it->addColSpec("BC Id", 'num asc', 'right');
    
    my $count = 0;
    foreach my $bcId (@$list_aref) {
        my $row = $sd . "<input type='checkbox' name='bc_id' value='$bcId' />\t";
        $row .= $bcId . $sd . $bcId . "\t";
        $it->addRow($row);
        $count++;
    } 
    
    #printCartTab1Start();
    TabHTML::printTabAPILinks("bcTab");
    my @tabIndex = ( "#bccarttab1",   "#bccarttab2" );
    my @tabNames = ( "BC in Cart", "Upload & Export & Save" );
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

    my $name = "_section_GenomeCart_uploadGenomeCart";
    print submit(
                  -name    => $name,
                  -value   => "Upload from File",
                  -class   => "medbutton",
                  -onClick => "return uploadFileName('$textFieldId');",
    );


    print "<h2>Export Genomes</h2>";
    print "<p>\n";
    print "You may select genomes from the cart to export.";
    print "</p>\n";
    
    my $name = "_section_${section}_exportBc_noHeader";    
    my $str = HtmlUtil::trackEvent("Export", $contact_oid, "img button $name");
    print qq{
    <input class='medbutton' name='$name' type="submit" value="Export BC" $str>
    };    
    
    
    print "</div>";    # end bccarttab2
    
    TabHTML::printTabDivEnd();
    
    print end_form();
}


# save buffer to workspace
#
# $filename the new workspace filename
sub saveBufferToWorkspace {
    my ($filename) = @_;

    my $buff = getBufferFile();
    
    my $newFile = $BC_DIR . $filename;

    copy($buff, $newFile);
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
        if(exists $distinct{$bcId}) {
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
    my $rfh = newReadFileHandle( $filename );
    my $wfh = newWriteFileHandle($tempfile);
    while ( my $line = $rfh->getline() ) {
        chomp $line;
        if(!exists $deleteIds{$line}) {
            print $wfh "$line\n";   
        }
    }    
    
    close $wfh;
    close $rfh;
    
    # do i have to unlink $filename first?
    move($tempfile, $filename);
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
    my $BUFFER_DIR = WebUtil::getSessionDir() . '/';
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

1;
