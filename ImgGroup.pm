package ImgGroup;
my $section = "ImgGroup";

use strict; 
use CGI qw( :standard ); 
use DBI; 
use Time::localtime; 
use Digest::MD5 qw( md5_base64 ); 
use MIME::Base64 qw( encode_base64 decode_base64 ); 
use Data::Dumper; 
use WebConfig; 
use WebUtil; 
use InnerTable; 
use DataEntryUtil; 
use TabHTML;

my $env                  = WebConfig::getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir}; 
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $img_internal         = $env->{img_internal};
my $include_metagenomes  = $env->{include_metagenomes};
my $include_plasmids     = $env->{include_plasmids};
my $show_myimg_login     = $env->{show_myimg_login};
my $show_mygene          = $env->{show_mygene};
my $user_restricted_site = $env->{user_restricted_site};
my $public_nologin_site  = $env->{public_nologin_site};
my $img_lite             = $env->{img_lite};
my $annotation_site_url  = $env->{annotation_site_url};
my $show_private         = $env->{show_private};
my $annot_site_url       = $env->{annot_site_url};

my $YUI            = $env->{yui_dir_28}; 
my $yui_tables     = $env->{yui_tables}; 


###################################################################
# dispatch
###################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq 'showGroupDetail' ||
	 paramMatch("showGroupDetail") ne "" ||
	 $page eq 'updGroup' ||
	 paramMatch("updGroup") ne "" ) {
	PrintGroupDetailPage();
    }
    elsif ( $page eq 'updateGroupDesc' ||
	 paramMatch("updateGroupDesc") ne "" ) {
	my $msg = db_updateGroupDesc();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    PrintGroupDetailPage();
	}
    }
    elsif ( $page eq 'addGroup' ||
	 paramMatch("addGroup") ne "" ) {
	PrintAddGroupPage();
    }
    elsif ( $page eq 'confirmDeleteGroup' ||
	 paramMatch("confirmDeleteGroup") ne "" ) {
	PrintConfirmDeleteGroupMsg();
    }
    elsif ( $page eq 'delGroup' ||
	 paramMatch("delGroup") ne "" ) {
	my $msg = db_deleteImgGroup();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    require MyIMG;
	    MyIMG::printHome();
	}
    }
    elsif ( $page eq 'confirmWithdraw' ||
	 paramMatch("confirmWithdraw") ne "" ) {
	PrintConfirmWithdrawMsg();
    }
    elsif ( $page eq 'wdGroup' ||
	 paramMatch("wdGroup") ne "" ) {
	my $msg = db_withdrawMembership();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    require MyIMG;
	    MyIMG::printHome();
	}
    }
    elsif ( $page eq 'confirmDeleteMember' ||
	 paramMatch("confirmDeleteMember") ne "" ) {
	PrintConfirmDeleteMember();
    }
    elsif ( $page eq 'deleteMember' ||
	 paramMatch("deleteMember") ne "" ) {
	my $msg = db_deleteMember();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    PrintGroupDetailPage();
	}
    }
    elsif ( $page eq 'updMemberRole' ||
	 paramMatch("updMemberRole") ne "" ) {
	my $msg = db_updateMemberRole();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    PrintGroupDetailPage();
	}
    }
    elsif ( $page eq 'postNews' ||
	 paramMatch("postNews") ne "" ) {
	my $msg = db_postNews();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    PrintGroupDetailPage(1);
	}
    }
    elsif ( $page eq 'releaseNews' ||
	 paramMatch("releaseNews") ne "" ) {
	my $msg = db_releaseNews();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    PrintGroupDetailPage(1);
	}
    }
    elsif ( $page eq 'makePrivateNews' ||
	 paramMatch("makePrivateNews") ne "" ) {
	my $msg = db_makePrivateNews();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    PrintGroupDetailPage(1);
	}
    }
    elsif ( $page eq 'deleteNews' ||
	 paramMatch("deleteNews") ne "" ) {
	my $msg = db_deleteNews();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    PrintGroupDetailPage(1);
	}
    }
    elsif ( $page eq 'addMember' ||
	 paramMatch("addMember") ne "" ) {
	my $msg = db_addMember();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    PrintGroupDetailPage();
	}
    }
    elsif ( $page eq 'dbAddNewGroup' ||
	 paramMatch("dbAddNewGroup") ne "" ) {
	my $msg = db_addNewGroup();
	if ( $msg ) {
	    WebUtil::webError($msg);
	}
	else {
	    require MyIMG;
	    MyIMG::printHome();
	}
    }
    elsif ( $page eq 'shareGenomes' ||
	 paramMatch("shareGenomes") ne "" ) {
	shareGenomesWithMembers();
    }
    elsif ( $page eq 'showNewsDetail' ||
	 paramMatch("showNewsDetail") ne "" ) {
	my $group_id = param('group_id');
	my $news_id = param('news_id');
	showNewsWithId ($group_id, $news_id);
    }
    elsif ( $page eq 'showMain' ||
	 paramMatch("showMain") ne "" ) {
	require MyIMG;
	MyIMG::printHome();
    }
}


###################################################################
# showAllGroups: show all IMG groups one has access to
###################################################################
sub showAllGroups {
    if ( ! $show_myimg_login ) {
	return;
    }

    print "<h3>IMG Group(s)</h3>\n";

    my $contact_oid = WebUtil::getContactOid();
    my $super_user_flag = WebUtil::getSuperUser();

    my %group_role;
    my $dbh = dbLogin();
    my $sql = "select img_group, role from contact_img_groups\@imgsg_dev where contact_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for (;;) {
	my ( $group_id, $role ) = $cur->fetchrow();
	last if ! $group_id;

	$group_role{$group_id} = $role;
    }
    $cur->finish(); 

    my %member_no_h;
    $sql = "select img_group, count(*) from contact_img_groups\@imgsg_dev group by img_group";
    $cur = execSql( $dbh, $sql, $verbose );
    for (;;) {
	my ( $group_id, $cnt ) = $cur->fetchrow();
	last if ! $group_id;

	$member_no_h{$group_id} = $cnt;
    }
    $cur->finish(); 

    if ( $super_user_flag eq 'Yes' ) {
	$sql = qq{
               select distinct g.group_id, g.group_name, 
                      c.contact_oid, c.name,
                      to_char(g.add_date, 'yyyy-mm-dd'), g.comments
               from contact c, img_group\@imgsg_dev g
               where g.lead = c.contact_oid
               };
	$cur = execSql( $dbh, $sql, $verbose );
    }
    else {
	$sql = qq{
               select distinct g.group_id, g.group_name,
                      c.contact_oid, c.name,
                      to_char(g.add_date, 'yyyy-mm-dd'), g.comments
               from contact c, img_group\@imgsg_dev g,
                    contact_img_groups\@imgsg_dev cig
               where g.lead = c.contact_oid
               and g.group_id = cig.img_group
               and cig.contact_oid = ?
               };
	$cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    }

    my $it = new InnerTable( 1, "myGroup$$", "myGroup", 1 );

    my $sd = $it->getSdDelim(); # sort delimiter

    $it->addColSpec("Select");
    $it->addColSpec( "Group ID",     "number asc", "right" ); 
    $it->addColSpec( "Group Name",  "char asc",  "left" );
    $it->addColSpec( "Owner Name",  "char asc",  "left" );
    $it->addColSpec( "Add Date",  "char asc",  "left" );
    $it->addColSpec( "Description",     "char desc", "left" ); 
    $it->addColSpec( "Member Count",  "number asc",  "right" );
    $it->addColSpec( "My Role",  "char asc",  "left" );

    my $cnt = 0;
    my $owner_cnt = 0;
    my $member_cnt = 0;
    for (;;) {
	my ( $group_id, $group_name, $lead_oid, $lead_name, 
	     $add_date, $desc ) 
	    = $cur->fetchrow();
	last if ! $group_id;

        my $r = $sd . "<input type='radio' name='group_id' value='$group_id' /> \t"; 
        my $url = $section_cgi . "&page=showGroupDetail&group_id=$group_id";
        $r .= $group_id . $sd . alink($url, $group_id) . "\t"; 
        $r .= $group_name . $sd . $group_name . "\t"; 
        $r .= $lead_name . $sd . $lead_name . "\t"; 
        $r .= $add_date . $sd . $add_date . "\t"; 
        $r .= $desc . $sd . $desc . "\t";

	my $member_n = $member_no_h{$group_id};
        $r .= $member_n . $sd . $member_n . "\t";

	my $role = "-";
	if ( $lead_oid == $contact_oid ) {
	    $role = "owner";
	    $owner_cnt++;
	}
	else {
	    $role = $group_role{$group_id};
	    if ( $role ) {
		$member_cnt++;
	    }
	}
        $r .= $role . $sd . $role . "\t";

        $it->addRow($r); 

	$cnt++;
	if ( $cnt > 10000 ) {
	    last;
	}
    }
    $cur->finish(); 

    if ( $cnt ) {
	$it->printOuterTable(1);
    }
    else {
	print "<h5>No IMG Groups.</h5>\n";
    }

    ## buttons
    my $name = "_section_${section}_addGroup"; 
    print submit( 
            -name  => $name, 
            -value => 'Add', 
            -class => 'smdefbutton' 
	); 

    if ( $cnt ) {
	print nbsp(1); 
	my $name = "_section_${section}_updGroup"; 
	print submit( 
            -name  => $name, 
            -value => 'Update', 
            -class => 'smdefbutton' 
	);
    }

    if ( $owner_cnt || $super_user_flag eq 'Yes' ) {
	print nbsp(1); 
	my $name = "_section_${section}_confirmDeleteGroup"; 
	print submit( 
            -name  => $name, 
            -value => 'Delete', 
            -class => 'smdefbutton' 
	);
    }

    if ( $member_cnt ) {
	print nbsp(1); 
	my $name = "_section_${section}_confirmWithdraw"; 
	print submit( 
            -name  => $name, 
            -value => 'Withdraw', 
            -class => 'smdefbutton'
	);
    }
}

##################################################################
# PrintGroupDetailPage
##################################################################
sub PrintGroupDetailPage {
    my ($news_first) = @_;

    my $group_id = param("group_id");

    if ( ! $group_id ) {
	WebUtil::webError("No IMG Group ID is selected.");
	return;
    }

    my $g_access = hasAccessToGroupInfo($group_id);
    if ( ! $g_access ) {
	WebUtil::webError("Incorrect Group ID: $group_id");
	return;
    }

    WebUtil::printMainForm();

    print "<h1>IMG Group Information</h1>\n";

    ## back to group lists
    my $url2 = $main_cgi . "?section=MyIMG&page=home";
    print "<p>" . alink($url2, "Back to IMG Group List");

    print WebUtil::hiddenVar( "group_id", $group_id );

    my $dbh = dbLogin();
    showGroupDetailSection($dbh, $group_id);

    TabHTML::printTabAPILinks("groupTab");
    my @tabIndex = ( "#grouptab1", "#grouptab2" );
    my @tabNames = ( "Members", "News" );

    if ( $news_first ) {
	@tabIndex = ( "#grouptab2", "#grouptab1" );
	@tabNames = ( "News", "Members" );
    }

    TabHTML::printTabDiv("groupTab", \@tabIndex, \@tabNames); 

    for my $t ( @tabIndex ) {
	my $tab = substr($t, 1, length($t) - 1);
	print "<div id='$tab'>";
	if ( $tab eq 'grouptab1' ) {
	    showGroupMemberSection($dbh, $group_id);
	}
	else {
	    showGroupNewsSection($dbh, $group_id);
	}
	print "</div>\n";
    }

    print end_form();
}

##################################################################
# PrintAddGroupPage
##################################################################
sub PrintAddGroupPage {

    WebUtil::printMainForm();

    print "<h1>Add A New IMG Group</h1>\n";

    my $super_user_flag = WebUtil::getSuperUser();
    my $contact_oid = WebUtil::getContactOid();

    print "<h3>Group Information</h3>\n";
    print "<table class='img' border='1'>\n"; 
    print "<tr class='img'><td class='img'><b>Group Name</b></td>\n";
    print "<td class='img'>\n";
    print "<input type='text' name='group_name' value='' size='80' maxLength='255'/>" ;
    print "</td></tr>\n";

    my $dbh = dbLogin();
    if ( $super_user_flag eq 'Yes' ) {
	print "<tr class='img'><td class='img'><b>Owner</b></td>\n";
	print "<td class='img'>\n";
	print "<select name='lead_contact' class='img' size='1'>\n";
	my $sql = "select contact_oid, username, name, email from contact where username is not null and email is not null order by 2, 4";
	my $cur = execSql( $dbh, $sql, $verbose );
	for (;;) {
	    my ($c_oid, $u_name, $c_name, $email) = $cur->fetchrow();
	    last if ! $c_oid;

            print "    <option value='" . $c_oid . "'";
	    if ( $c_oid == $contact_oid ) {
		print " selected ";
	    }
            print ">$u_name (Name: " . escapeHTML($c_name) .
	           "; Email: " . escapeHTML($email) . ")</option>\n";
	}
	$cur->finish();
	print "</td></tr>\n";
    }
    else {
	my $sql = "select username, name, email from contact where contact_oid = ?";
	my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
	my ($u_name, $c_name, $email) = $cur->fetchrow();
	$cur->finish();
	printAttrRowRaw( "Owner", $c_name . " (" . $u_name . ")" );
	printAttrRowRaw( "Owner Email", $email );
    }

    print "<tr class='img'><td class='img'><b>Description</b></td>\n";
    print "<td class='img'>\n";
    print "<input type='text' name='group_desc' value='' size='80' maxLength='512'/>" ;
    print "</td></tr>\n";

    print "</table>\n"; 

    print "<p>\n";
    my $name = "_section_${section}_dbAddNewGroup"; 
    print submit( 
	-name  => $name, 
	-value => 'Add Group', 
	-class => 'smdefbutton' 
	);

    print end_form();
}


###################################################################
# hasAccessToGroupInfo: Do I have access to group info?
#
# return 1: owner or super user
#        2: co-owner
#        3: member
#        0: no access
###################################################################
sub hasAccessToGroupInfo {
    my ($group_id) = @_;

    my $super_user_flag = WebUtil::getSuperUser();
    if ( $super_user_flag eq 'Yes' ) {
	return 1;
    }

    my $contact_oid = WebUtil::getContactOid();
    if ( ! $contact_oid ) {
	return 0;
    }

    my $dbh = dbLogin();
    my $sql = "select lead from img_group\@imgsg_dev where group_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $group_id );
    my ($lead) = $cur->fetchrow();
    $cur->finish();
    if ( $lead == $contact_oid ) {
	return 1;
    }

    $sql = "select role from contact_img_groups where img_group = ? and contact_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $group_id, $contact_oid );
    my ($role) = $cur->fetchrow();
    $cur->finish();

    if ( lc($role) eq 'co-owner' ) {
	return 2;
    }
    elsif ( lc($role) eq 'member' ) {
	return 3;
    }

    return 0;
}


#################################################################
# showGroupDetailSection: Show IMG group info
#################################################################
sub showGroupDetailSection {
    my ($dbh, $group_id) = @_;

    if ( ! $group_id ) {
	return;
    }

    my $contact_oid = WebUtil::getContactOid();
    my $super_user_flag = WebUtil::getSuperUser();

    my $sql = qq{
               select g.group_id, g.group_name, 
                      c.contact_oid, c.username, c.name, c.email,
                      to_char(g.add_date, 'yyyy-mm-dd'), g.comments
               from contact c, img_group\@imgsg_dev g
               where g.group_id = ?
               and g.lead = c.contact_oid
               };
    my $cur = execSql( $dbh, $sql, $verbose, $group_id );
    my ($g_id, $group_name, $lead, $u_name, $c_name, $email,
	$add_date, $desc) = $cur->fetchrow();
    $cur->finish();

    print "<h3>Group Information</h3>\n";
    print "<table class='img' border='1'>\n"; 
    printAttrRowRaw( "Group ID", $group_id );
    if ( $contact_oid == $lead || $super_user_flag eq 'Yes' ) {
	print "<tr class='img'><td class='img'><b>Group Name</b></td>\n";
	print "<td class='img'>\n";
        print "<input type='text' name='group_name' value='" 
	    . escapeHTML($group_name) 
	    . "' size='60' maxLength='255'/>" ;
	print "</td></tr>\n";
    }
    else {
	printAttrRowRaw( "Group Name", WebUtil::escHtml($group_name) );
    }
    printAttrRowRaw( "Owner", $c_name . " (" . $u_name . ")" );
    printAttrRowRaw( "Owner Email", $email );
    printAttrRowRaw( "Add Date", $add_date );
    if ( $contact_oid == $lead || $super_user_flag eq 'Yes' ) {
	print "<tr class='img'><td class='img'><b>Description</b></td>\n";
	print "<td class='img'>\n";
        print "<input type='text' name='group_desc' value='" 
	    . escapeHTML($desc) 
	    . "' size='60' maxLength='512'/>" ;
	print "</td></tr>\n";
    }
    else {
	printAttrRowRaw( "Description", WebUtil::escHtml($desc) );
    }
    print "</table>\n"; 

    if ( $contact_oid == $lead || $super_user_flag eq 'Yes' ) {
	print "<p>\n";
	my $name = "_section_${section}_updateGroupDesc"; 
	print submit( 
            -name  => $name, 
            -value => 'Save Update in Database', 
            -class => 'meddefbutton' 
	);
	print nbsp(3);
	print "(Click the Save button after you make changes to group name and/or description; otherwise the change won't be saved in database.)\n";
    }
}


##################################################################
# db_updateGroupDesc: check and update group desc
##################################################################
sub db_updateGroupDesc {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return "No group ID is selected.";
    }

    my $can_update = checkCanUpdateGroup($group_id);

    if ( ! $can_update ) {
	return "You cannot update group name or description.";
    }

    my $group_name = param('group_name');
    if ( ! $group_name ) {
	return "Please enter a group name.";
    }
    if ( length($group_name) > 255 ) {
	$group_name = substr( $group_name, 0, 255 ); 
    } 
    $group_name =~ s/'/''/g;   # replace ' with ''

    my $group_desc = param('group_desc');
    if ( ! $group_desc ) {
	return "Please enter a group description.";
    }
    if ( length($group_desc) > 512 ) {
	$group_desc = substr( $group_desc, 0, 512 ); 
    } 
    $group_desc =~ s/'/''/g;   # replace ' with ''

    my $sql = "update img_group\@imgsg_dev set group_name = '" .
	$group_name . "', comments = '" . $group_desc .
	"' where group_id = $group_id";
    my @sqlList = ( $sql );

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}


################################################################
# checkCanUpdateGroup
#
# return 1, if super user or group lead
# return 0, otherwise
################################################################
sub checkCanUpdateGroup {
    my ($group_id) = @_;

    if ( ! $group_id ) {
	return 0;
    }

    my $super_user_flag = WebUtil::getSuperUser();
    if ( $super_user_flag eq 'Yes' ) {
	return 1;
    }

    my $contact_oid = WebUtil::getContactOid();
    my $dbh = dbLogin();
    my $sql = qq{
               select g.group_id, g.lead
               from img_group\@imgsg_dev g
               where g.group_id = ?
               };
    my $cur = execSql( $dbh, $sql, $verbose, $group_id );
    my ($g_id, $lead) = $cur->fetchrow();
    $cur->finish();

    if ( $contact_oid == $lead ) {
	return 1;
    }

    return 0;
}


#################################################################
# showGroupMemberSection: Show IMG group members
#################################################################
sub showGroupMemberSection {
    my ($dbh, $group_id) = @_;

    if ( ! $group_id ) {
	return;
    }

    my $contact_oid = WebUtil::getContactOid();
    my $my_role = "";

    my $it = new InnerTable( 1, "myGroupMember$$", "myGroupmember", 1 );

    my $sd = $it->getSdDelim(); # sort delimiter

    $it->addColSpec("Select");
    $it->addColSpec( "Member ID",  "char asc",  "left" );
    $it->addColSpec( "Member Name",  "char asc",  "left" );
    $it->addColSpec( "Email",  "char asc",  "left" );
    $it->addColSpec( "Organization",  "char asc",  "left" );
    $it->addColSpec( "Role",  "char asc",  "left" );

    my $sql = qq{
               select g.img_group, c.contact_oid, c.username, 
                      c.name, c.email, c.organization,
                      g.role
               from contact c, contact_img_groups\@imgsg_dev g
               where g.img_group = ?
               and g.contact_oid = c.contact_oid
               and g.role != 'owner'
               };
    my $cur = execSql( $dbh, $sql, $verbose, $group_id );
    my $cnt = 0;
    for (;;) {
	my ($g_id, $c_oid, $u_name, $c_name, $c_email,
	    $c_org, $role) = $cur->fetchrow();
	last if ! $g_id;

	if ( ! $c_org ) {
	    $c_org = '-';
	}
	if ( ! $role ) {
	    $role = 'member';
	}

	if ( $c_oid == $contact_oid ) {
	    $my_role = $role;
	}

        my $r = $sd . "<input type='checkbox' name='member_oid' value='$c_oid' /> \t"; 
        $r .= $u_name . $sd . $u_name . "\t"; 
        $r .= $c_name . $sd . $c_name . "\t"; 
        $r .= $c_email . $sd . $c_email . "\t"; 
        $r .= $c_org . $sd . $c_org . "\t";
        $r .= $role . $sd . $role . "\t";

        $it->addRow($r); 
	$cnt++;
	if ( $cnt > 10000 ) {
	    last;
	}
    }
    $cur->finish(); 

    print "<h3>Members</h3>\n";
    if ( $cnt ) {
	$it->printOuterTable(1);
    }
    else {
	print "<h5>No members in this group</h5>\n";
    }

    my $can_update = checkCanUpdateGroup($group_id);
    if ( $can_update ) {
	print "<p>Change selected to: \n";
	print nbsp(1);
	print "<select name='new_role' class='img' size='1'>\n";
	print "  <option value='co-owner'>co-owner</option>\n";
	print "  <option value='member'>member</option>\n";
	print "</select>\n";
	print nbsp(1);
	my $name = "_section_${section}_updMemberRole"; 
	print submit( 
            -name  => $name, 
            -value => 'Update Member Role', 
            -class => 'meddefbutton' 
	);
	print nbsp(3);
    }

    if ( $can_update || $my_role eq 'co-owner' ) {
	my $name = "_section_${section}_confirmDeleteMember"; 
	print submit( 
            -name  => $name, 
            -value => 'Delete Member(s)', 
            -class => 'smdefbutton' 
	);

	print "<h4>Add New Members</h4>\n";
	print "<p>IMG user names or JGI SSO user names (separated by ,): \n"; 
	print nbsp(3); 
	print "<input type='text' name='img_user_names' value='' size='80' maxLength='200'/>\n"; 
	print "</p>\n"; 
	my $name = "_section_${section}_addMember"; 
	print submit( 
            -name  => $name, 
            -value => 'Add Member(s)', 
            -class => 'smdefbutton' 
	);
    }


    ## share genomes with group members
    if ( $can_update || $my_role ) {
	print "<h4>Share Genomes with Group Members</h4>\n";
	print "<p><b>Note:</b> This option is for new sharings only. It does <u>not</u> revoke previousely granted access permissions. Contact us if you wish to revoke any access permission.\n";
	print "<p>Please enter IMG OIDs (separated by ,): \n"; 
	print nbsp(3); 
	print "<input type='text' name='img_taxons' value='' size='80' maxLength='400'/>\n"; 
	print "</p>\n"; 
	my $name = "_section_${section}_shareGenomes"; 
	print submit( 
            -name  => $name, 
            -value => 'Grant Access', 
            -class => 'smdefbutton' 
	);
    }
}

#################################################################
# showGroupNewsSection: Show IMG group news
#################################################################
sub showGroupNewsSection {
    my ($dbh, $group_id) = @_;

    if ( ! $group_id ) {
	return;
    }

    print qq{
      <script>
      function viewNews(desc) {
          alert('test');
          return;
      }
      </script>
    };

    print "<script src='$base_url/overlib.js'></script>\n";

    my $contact_oid = WebUtil::getContactOid();
    my $my_role = "";

    my $it = new InnerTable( 1, "myGroupNews$$", "myGroupNews", 1 );

    my $sd = $it->getSdDelim(); # sort delimiter

    $it->addColSpec("Select");
    $it->addColSpec( "Title",  "char asc",  "left" );
    $it->addColSpec( "Posted By",  "char asc",  "left" );
    $it->addColSpec( "Post Time",  "char asc",  "left" );
    $it->addColSpec( "Public?",  "char asc",  "left" );

    my $sql = qq{
               select n.group_id, n.news_id, n.title, n.description,
                      c.contact_oid, c.username, c.name,
                      n.add_date, n.is_public
               from contact c, img_group_news\@imgsg_dev n
               where n.group_id = ?
               and n.posted_by = c.contact_oid
               order by 8 desc
               };
    my $cur = execSql( $dbh, $sql, $verbose, $group_id );
    my $cnt = 0;
    for (;;) {
	my ($g_id, $n_id, $title, $desc,
	    $c_oid, $u_name, $c_name, $add_date, $is_public)
	    = $cur->fetchrow();
	last if ! $g_id;

        my $r = $sd . "<input type='checkbox' name='news_id' value='$n_id' /> \t"; 
	$desc = strTrim($desc);
	my $tooltip = "onmouseover=\"return overlib('" .
	    escapeHTML($desc) .
	    "')\" onmouseout='return nd()'";
        my $url2 = $section_cgi . "&page=showNewsDetail" .
	    "&group_id=$group_id&news_id=$n_id";
	my $onclick = "onClick='javascript:window.open(\"$url2\", \"_blank\");'";

        $r .= $title . $sd . "<text style=\"cursor:pointer;\" $tooltip $onclick>$title</text>" . "\t"; 
        $r .= $c_name . $sd . $c_name . "\t"; 
        $r .= $add_date . $sd . $add_date . "\t"; 
        $r .= $is_public . $sd . $is_public . "\t";

        $it->addRow($r); 
	$cnt++;
	if ( $cnt > 10000 ) {
	    last;
	}
    }
    $cur->finish(); 

    print "<h3>News</h3>\n";
    if ( $cnt ) {
	$it->printOuterTable(1);

	print "<p>\n";
	my $name = "_section_${section}_releaseNews"; 
	print submit( 
            -name  => $name, 
            -value => 'Release News', 
            -class => 'smdefbutton' 
	);
	print nbsp(1);
	my $name = "_section_${section}_makePrivateNews"; 
	print submit( 
            -name  => $name, 
            -value => 'Make Private', 
            -class => 'smbutton' 
	);
	print nbsp(1);
	my $name = "_section_${section}_deleteNews"; 
	print submit( 
            -name  => $name, 
            -value => 'Delete News', 
            -class => 'smbutton' 
	);
    }
    else {
	print "<h5>No Group News.</h5>\n";
    }

    print "<hr>\n";
    print "<h4>Post News</h5>\n";
    print "<table class='img' border='1'>\n"; 
    print "<tr class='img'><td class='img'><b>Title</b></td>\n";
    print "<td class='img'>\n";
    print "<input type='text' name='news_title' value='" 
	. "' size='80' maxLength='200'/>" ;
    print "</td></tr>\n";

    print "<tr class='img'><td class='img'><b>Description</b></td>\n";
    print "<td class='img'>\n";
    print "<textarea name='news_desc' rows='12' cols='80'></textarea>\n";
    print "</td></tr>\n";

    print "<tr class='img'><td class='img'><b>Is Public?</b></td>\n";
    print "<td class='img'>\n";
    print "<select name='news_public' class='img' size='1'>\n";
    print "  <option value='No'>No</option>\n";
    print "  <option value='Yes'>Yes</option>\n";
    print "</select>\n";
    print "</td></tr>\n";

    print "</table>\n"; 

    print "<p>\n";
    my $name = "_section_${section}_postNews"; 
    print submit( 
	-name  => $name, 
	-value => 'Post News', 
	-class => 'smdefbutton' 
	);
}

#################################################################
# showNewsWithId
#################################################################
sub showNewsWithId {
    my ($group_id, $news_id) = @_;

    WebUtil::printMainForm();

    print "<h1>Group News</h1>\n";

    if ( ! $group_id || ! $news_id ) {
	print end_form();
	return;
    }

    my $dbh = dbLogin();
    my $sql = qq{
               select n.group_id, g.group_name,
                      n.news_id, n.title, n.description,
                      c.contact_oid, c.username, c.name,
                      n.add_date, n.is_public
               from contact c, img_group\@imgsg_dev g,
                    img_group_news\@imgsg_dev n
               where n.group_id = ?
               and n.posted_by = c.contact_oid
               and n.news_id = ? 
               and g.group_id = n.group_id
               };
    my $cur = execSql( $dbh, $sql, $verbose, $group_id, $news_id );
    my ($g_id, $group_name, $n_id, $title, $desc,
	$c_oid, $u_name, $c_name, $add_date, $is_public)
	= $cur->fetchrow();
    $cur->finish();

    ## check permission
    my $contact_oid = WebUtil::getContactOid();
    my $super_user_flag = WebUtil::getSuperUser();
    if ( $super_user_flag eq 'Yes' || $is_public eq 'Yes' ||
	 $c_oid == $contact_oid ) {
	# yes
    }
    else {
	# check group permission
	$sql = "select role from contact_img_groups\@imgsg_dev where img_group = ? and contact_oid = ?";
	$cur = execSql( $dbh, $sql, $verbose, $group_id, $contact_oid );
	my ($role) = $cur->fetchrow();
	$cur->finish();

	if ( ! $role ) {
	    print "<h5>No News.</h5>\n";
	    print end_form();
	    return;
	}
    }

    # print news
    print "<table class='img' border='1'>\n"; 
    printAttrRowRaw( "Group",  $group_name );
    printAttrRowRaw( "Posted By",  $c_name );
    printAttrRowRaw( "Title",  $title );
    printAttrRowRaw( "Content",  $desc );
    printAttrRowRaw( "Post Date",  $add_date );
    printAttrRowRaw( "Is Public?",  $is_public );
    print "</table>\n";

    print end_form();
}


#################################################################
# canReleaseNews
#################################################################
sub canReleaseNews {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return 0;
    }
    my $contact_oid = WebUtil::getContactOid();
    if ( ! $contact_oid ) {
	return 0;
    }

    my @all_news = param('news_id');
    if ( scalar(@all_news) > 1000 ) {
	return 0;
    }

    my $super_user_flag = WebUtil::getSuperUser();
    if ( $super_user_flag eq 'Yes' ) {
	return 1;
    }

    my $dbh = dbLogin();
    my $sql = "select role from contact_img_groups\@imgsg_dev where contact_oid = ? and img_group = ? "; 
 
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $group_id );
    my ( $role ) = $cur->fetchrow(); 
    $cur->finish(); 
    if ( $role =~ /owner/ ) {
	return 1;
    }

    my $id_str = join(", ", @all_news);
    $sql = "select count(*) from img_group_news\@imgsg_dev where group_id = ? and posted_by != ? ";
    $cur = execSql( $dbh, $sql, $verbose, $group_id, $contact_oid );
    my ( $cnt ) = $cur->fetchrow(); 
    $cur->finish(); 
    if ( $cnt > 0 ) {
	return 0;
    }

    return 1;
}

##################################################################
# PrintConfirmDeleteGroupMsg
##################################################################
sub PrintConfirmDeleteGroupMsg {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	WebUtil::webError("No group ID is selected.");
	return;
    }

    my $contact_oid = WebUtil::getContactOid();
    if ( ! $contact_oid ) {
	WebUtil::webError("Your login has expired.");
	return "";
    }

    WebUtil::printMainForm();

    print "<h2>Confirm Delete Group</h2>\n";

    my $dbh = dbLogin();
    my $sql = "select g.group_id, g.group_name, g.lead " .
	"from img_group\@imgsg_dev g " .
	"where g.group_id = ? ";
    my $cur = execSql( $dbh, $sql, $verbose, $group_id );
    my ($g_id2, $group_name, $lead) = $cur->fetchrow();
    $cur->finish();

    print "<h3>Group: $group_name</h3>\n";

    print WebUtil::hiddenVar( "group_id", $group_id );
    my $super_user_flag = WebUtil::getSuperUser();
    if ( $super_user_flag ne 'Yes' && $contact_oid != $lead ) {
	WebUtil::webError("You do not have the privilege to delete this group.");
	return "";
    }

    print "<p>After you delete this group, all MyIMG and missing gene annotations sharing information will be removed.";
    print "<p>Create a new group will <u>not</u> automatically restore the previous sharing information.";
    print "<p>Are you sure you want to continue?\n";

    print "<p>\n";
    my $name = "_section_${section}_delGroup"; 
    print submit( 
	-name  => $name, 
	-value => 'Delete', 
	-class => 'smdefbutton'
	);
    print nbsp(1); 
    print submit( 
        -name  => "_section_${section}_showMain", 
        -value => "Cancel", 
        -class => "smbutton" 
	); 
 
    print end_form(); 

    return "";
}


##################################################################
# db_deleteImgGroup
##################################################################
sub db_deleteImgGroup {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return "No group ID is selected.";
    }

    my $dbh = dbLogin();
    my $contact_oid = WebUtil::getContactOid();

    my $sql = qq{
           select lead 
           from img_group\@imgsg_dev g
           where g.group_id = ?
           };
    my $cur = execSql( $dbh, $sql, $verbose, $group_id );
    my ($lead) = $cur->fetchrow();
    $cur->finish();

    my $super_user_flag = WebUtil::getSuperUser();
    if ( $super_user_flag ne 'Yes' && $contact_oid != $lead ) {
	return "You cannot delete this group.";
    }

    my @sqlList = ();
    $sql = "delete from gene_myimg_groups\@img_ext where group_id = $group_id";
    push @sqlList, ( $sql );
    $sql = "delete from mygene_img_groups\@img_ext where group_id = $group_id";
    push @sqlList, ( $sql );
    $sql = "delete from img_group_news\@imgsg_dev where group_id = $group_id";
    push @sqlList, ( $sql );
    $sql = "delete from contact_img_groups\@imgsg_dev where img_group = $group_id";
    push @sqlList, ( $sql );
    $sql = "delete from contact_workspace_group\@imgsg_dev where group_id = $group_id";
    push @sqlList, ( $sql );
    $sql = "delete from img_group\@imgsg_dev where group_id = $group_id";
    push @sqlList, ( $sql );

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        my $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}


##################################################################
# PrintConfirmWithdrawMsg
##################################################################
sub PrintConfirmWithdrawMsg {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	WebUtil::webError("No group ID is selected.");
	return;
    }

    my $contact_oid = WebUtil::getContactOid();
    if ( ! $contact_oid ) {
	WebUtil::webError("You are not log in.");
	return "";
    }

    WebUtil::printMainForm();

    print "<h2>Confirm Withdrawal</h2>\n";

    my $dbh = dbLogin();
    my $sql = "select g.group_id, g.group_name " .
	"from img_group\@imgsg_dev g " .
	"where g.group_id = ? ";
    my $cur = execSql( $dbh, $sql, $verbose, $group_id );
    my ($g_id2, $group_name) = $cur->fetchrow();
    $cur->finish();

    print "<h3>Group: $group_name</h3>\n";

    print WebUtil::hiddenVar( "group_id", $group_id );

    print "<p>After you withdraw from this group, all your MyIMG annotations will no longer be available to the group members.";
    print "<p>Rejoining the group will <u>not</u> automatically make your MyIMG annotations available for sharing.";
    print "<p>Are you sure you want to continue?\n";

    print "<p>\n";
    my $name = "_section_${section}_wdGroup"; 
    print submit( 
	-name  => $name, 
	-value => 'Withdraw', 
	-class => 'smdefbutton'
	);
    print nbsp(1); 
    print submit( 
        -name  => "_section_${section}_showMain", 
        -value => "Cancel", 
        -class => "smbutton" 
	); 
 
    print end_form(); 

    return "";
}


##################################################################
# db_withdrawMembership
##################################################################
sub db_withdrawMembership {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return "No group ID is selected.";
    }

    my $dbh = dbLogin();
    my $contact_oid = WebUtil::getContactOid();

    my $sql = qq{
           select lead 
           from img_group\@imgsg_dev g
           where g.group_id = ?
           };
    my $cur = execSql( $dbh, $sql, $verbose, $group_id );
    my ($lead) = $cur->fetchrow();
    $cur->finish();

    if ( $contact_oid == $lead ) {
	return "Group owner cannot withdraw from the group.";
    }

    $sql = qq{
               select role
               from contact_img_groups\@imgsg_dev g
               where g.contact_oid = ? and g.img_group = ?
               };
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $group_id );
    my ($my_role) = $cur->fetchrow();
    $cur->finish();

    if ( ! $my_role ) {
	return "You are not a member of this group.";
    }

    my @sqlList = ();
    $sql = "delete from contact_img_groups\@imgsg_dev where img_group = $group_id and contact_oid = $contact_oid";
    push @sqlList, ( $sql );

    my $sql2 = removeMyIMGSharing($group_id, $contact_oid);
    if ( $sql2 ) {
	push @sqlList, ( $sql2 );
    }

    $sql2 = "delete from contact_workspace_group\@imgsg_dev where group_id = $group_id and contact_oid = $contact_oid";
    push @sqlList, ( $sql2 );

    $sql2 = "delete from img_group_news\@imgsg_dev where group_id = $group_id and posted_by = $contact_oid";
    push @sqlList, ( $sql2 );

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        my $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}


##################################################################
# PrintConfirmDeleteMember
##################################################################
sub PrintConfirmDeleteMember {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	WebUtil::webError("No group ID is selected.");
	return;
    }

    my $contact_oid = WebUtil::getContactOid();
    if ( ! $contact_oid ) {
	WebUtil::webError("You are not log in.");
	return "";
    }

    WebUtil::printMainForm();

    print "<h2>Confirm Member Deletion</h2>\n";

    my $dbh = dbLogin();
    my $sql = "select g.group_id, g.group_name " .
	"from img_group\@imgsg_dev g " .
	"where g.group_id = ? ";
    my $cur = execSql( $dbh, $sql, $verbose, $group_id );
    my ($g_id2, $group_name) = $cur->fetchrow();
    $cur->finish();

    print "<h3>Group: $group_name</h3>\n";

    print WebUtil::hiddenVar( "group_id", $group_id );

    my @members = param('member_oid');
    for my $m ( @members ) {
	print WebUtil::hiddenVar( "member_oid", $m );
    }

    for my $m ( @members ) {
	$sql = "select c.username, c.name, g.role " .
	    "from contact c, contact_img_groups\@imgsg_dev g " .
	    "where c.contact_oid = g.contact_oid " .
	    "and c.contact_oid = ? " .
	    "and g.img_group = ? ";
	$cur = execSql( $dbh, $sql, $verbose, $m, $group_id );
	my ($uname, $name, $role) = $cur->fetchrow();
	$cur->finish();
	print "<h4>Delete $role $name ($uname)?</h4>\n";
    }

    print "<p>After you delete members, all their MyIMG annotations will no longer be available to this group.";
    print "<p>Adding members back will <u>not</u> automatically make their MyIMG annotations available for sharing.";
    print "<p>Are you sure you want to continue?\n";

    print "<p>\n";
    my $name = "_section_${section}_deleteMember"; 
    print submit( 
	-name  => $name, 
	-value => 'Delete', 
	-class => 'smdefbutton'
	);
    print nbsp(1); 
    print submit( 
        -name  => "_section_${section}_showGroupDetail",
        -value => "Cancel", 
        -class => "smbutton" 
    ); 
 
    print end_form(); 
}

##################################################################
# db_deleteMember
##################################################################
sub db_deleteMember {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return "No group ID is selected.";
    }

    my $dbh = dbLogin();
    my $can_update = checkCanUpdateGroup($group_id);
    my $contact_oid = WebUtil::getContactOid();
    my $my_role = '';
    if ( ! $can_update ) {
	my $sql = qq{
               select role
               from contact_img_groups\@imgsg_dev g
               where g.contact_oid = ? and g.img_group = ?
               };
	my $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $group_id );
	($my_role) = $cur->fetchrow();
	$cur->finish();
    }

    if ( ! $can_update && lc($my_role) ne 'co-owner' ) {
	return "You cannot delete members from this group.";
    }

    my @members = param('member_oid');
    if ( scalar(@members) == 0 ) {
	return "No members have been selected for deletion.";
    }
    if ( scalar(@members) > 1000 ) {
	return "Please select no more than 1000 members."
    }

    if ( ! $can_update ) {
	my $sql = qq{
               select count(*)
               from contact_img_groups\@imgsg_dev g
               where g.role = 'co-owner' and g.img_group = ?
               };
	$sql .= " and g.contact_oid in (" . join(",", @members) . ")";
	my $cur = execSql( $dbh, $sql, $verbose );
	my ($c_cnt) = $cur->fetchrow();
	$cur->finish();

	if ( $c_cnt > 0 ) {
	    return "You cannot delete other co-owners.";
	}
    }

    my @sqlList = ();
    for my $m ( @members ) {
	my $sql = "delete from contact_img_groups\@imgsg_dev where img_group = $group_id and contact_oid = $m";
	push @sqlList, ( $sql );

	my $sql2 = removeMyIMGSharing($group_id, $m);
	if ( $sql2 ) {
	    push @sqlList, ( $sql2 );
	}

	$sql2 = "delete from contact_workspace_group\@imgsg_dev where group_id = $group_id and contact_oid = $m";
	push @sqlList, ( $sql2 );

	$sql2 = "delete from img_group_news\@imgsg_dev where group_id = $group_id and posted_by = $m";
	push @sqlList, ( $sql2 );
    }

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        my $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}


#################################################################
# removeMyIMGSharing
#################################################################
sub removeMyIMGSharing {
    my ($group_id, $contact_id) = @_;

    if ( ! isInt($group_id) || ! isInt($contact_id) ) {
	return "";
    }

    my $sql = "delete from gene_myimg_groups\@img_ext where group_id = $group_id and contact_oid = $contact_id";

    return $sql;
}


##################################################################
# db_updateMemberRole
##################################################################
sub db_updateMemberRole {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return "No group ID is selected.";
    }

    my $dbh = dbLogin();
    my $can_update = checkCanUpdateGroup($group_id);
    my $contact_oid = WebUtil::getContactOid();

    if ( ! $can_update ) {
	return "You cannot change member roles in this group.";
    }

    my @members = param('member_oid');
    if ( scalar(@members) == 0 ) {
	return "No members have been selected for deletion.";
    }
    if ( scalar(@members) > 1000 ) {
	return "Please select no more than 1000 members."
    }

    my $new_role = param('new_role');
    if ( ! $new_role ) {
	$new_role = 'member';
    }
    my @sqlList = ();
    for my $m ( @members ) {
	my $sql = "update contact_img_groups\@imgsg_dev set role = '$new_role' where img_group = $group_id and contact_oid = $m";
	push @sqlList, ( $sql );
    }

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        my $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}


##################################################################
# db_postNews
##################################################################
sub db_postNews {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return "No group ID is selected.";
    }

    my $dbh = dbLogin();
    my $contact_oid = WebUtil::getContactOid();
    my $sql = qq{
               select role
               from contact_img_groups\@imgsg_dev g
               where g.contact_oid = ? and g.img_group = ?
               };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $group_id );
    my ($my_role) = $cur->fetchrow();
    $cur->finish();

    if ( ! $my_role ) {
	return "You cannot post news to this group.";
    }

    my $news_title = param('news_title');
    if ( length($news_title) > 250 ) {
	$news_title = substr($news_title, 0, 250);
    }
    $news_title =~ s/'/''/g;    # replace ' with ''

    my $news_desc = param('news_desc');
    if ( length($news_desc) > 4000 ) {
	$news_desc = substr($news_desc, 0, 4000);
    }
    $news_desc =~ s/'/''/g;    # replace ' with ''

    my $news_public = param('news_public');
    if ( $news_public ne 'Yes' ) {
	$news_public = 'No';
    }

    $sql = "select max(news_id) from img_group_news\@imgsg_dev";
    $cur = execSql( $dbh, $sql, $verbose );
    my ($news_id) = $cur->fetchrow();
    $cur->finish();
    if ( $news_id ) {
	$news_id += 1;
    }
    else {
	$news_id = 1;
    }

    my @sqlList = ();
    my $sql2 = "insert into img_group_news\@imgsg_dev " .
	"(group_id, news_id, title, description, posted_by, " .
	"add_date, is_public) values ($group_id, $news_id, '" .
	$news_title . "', '" . $news_desc . "', $contact_oid, " .
	"sysdate, '" . $news_public . "')";

    push @sqlList, ( $sql2 );

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        my $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}

##################################################################
# db_releaseNews
##################################################################
sub db_releaseNews {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return "No group ID is selected.";
    }

    my @all_news = param('news_id');
    if ( scalar(@all_news) == 0 ) {
	return "Please select at least one item.";
    }
    elsif ( scalar(@all_news) > 1000 ) {
	return "Please select no more than 1000 items";
    }
    my $id_list = join(", ", @all_news);

    if ( ! canReleaseNews() ) {
	return "You cannot release all the news you have selected.";
    }

    my $contact_oid = WebUtil::getContactOid();
    my @sqlList = ();
    my $sql2 = "update img_group_news\@imgsg_dev " .
	"set is_public = 'Yes', released_by = $contact_oid, " .
	"release_date = sysdate " .
	"where group_id = $group_id and is_public = 'No' " .
	"and news_id in ( $id_list ) ";
    push @sqlList, ( $sql2 );

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        my $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}

##################################################################
# db_makePrivateNews
##################################################################
sub db_makePrivateNews {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return "No group ID is selected.";
    }

    my @all_news = param('news_id');
    if ( scalar(@all_news) == 0 ) {
	return "Please select at least one item.";
    }
    elsif ( scalar(@all_news) > 1000 ) {
	return "Please select no more than 1000 items";
    }
    my $id_list = join(", ", @all_news);

    if ( ! canReleaseNews() ) {
	return "You cannot un-release all the news you have selected.";
    }

    my $contact_oid = WebUtil::getContactOid();
    my @sqlList = ();
    my $sql2 = "update img_group_news\@imgsg_dev " .
	"set is_public = 'No', released_by = $contact_oid, " .
	"release_date = sysdate " .
	"where group_id = $group_id and is_public = 'Yes' " .
	"and news_id in ( $id_list ) ";
    push @sqlList, ( $sql2 );

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        my $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}

##################################################################
# db_deleteNews
##################################################################
sub db_deleteNews {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return "No group ID is selected.";
    }

    my @all_news = param('news_id');
    if ( scalar(@all_news) == 0 ) {
	return "Please select at least one item.";
    }
    elsif ( scalar(@all_news) > 1000 ) {
	return "Please select no more than 1000 items";
    }
    my $id_list = join(", ", @all_news);

    if ( ! canReleaseNews() ) {
	return "You cannot delete all the news you have selected.";
    }

    my $contact_oid = WebUtil::getContactOid();
    my @sqlList = ();
    my $sql2 = "delete from img_group_news\@imgsg_dev " .
	"where group_id = $group_id and news_id in ( $id_list ) ";
    push @sqlList, ( $sql2 );

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        my $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}


##################################################################
# db_addMember
##################################################################
sub db_addMember {
    my $group_id = param('group_id');
    if ( ! $group_id ) {
	return "No group ID is selected.";
    }

    my $dbh = dbLogin();
    my $can_update = checkCanUpdateGroup($group_id);
    my $contact_oid = WebUtil::getContactOid();
    my $my_role = '';
    if ( ! $can_update ) {
	my $sql = qq{
               select role
               from contact_img_groups\@imgsg_dev g
               where g.contact_oid = ? and g.img_group = ?
               };
	my $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $group_id );
	($my_role) = $cur->fetchrow();
	$cur->finish();
    }

    if ( ! $can_update && lc($my_role) ne 'co-owner' ) {
	return "You cannot add members to this group.";
    }

    my $img_user_names = param('img_user_names');
    my @names = ();
    if ( $img_user_names ) {
	@names = split(/\,/, $img_user_names);

	if ( scalar(@names) == 0 ) { 
	    return "Please enter IMG user name(s).";
	}
    }

    my $sql = qq{
               select g.group_id, g.lead, 'owner'
               from img_group\@imgsg_dev g
               where g.group_id = ?
               union
               select cig.img_group, cig.contact_oid, cig.role
               from contact_img_groups\@imgsg_dev cig
               where cig.img_group = ?
               };
    my $cur = execSql( $dbh, $sql, $verbose, $group_id, $group_id );
    my %ext_member_h;
    for (;;) {
	my ($g_id, $c_oid, $role) = $cur->fetchrow();
	last if ! $g_id;
    
	$ext_member_h{$c_oid} = $role;
    }
    $cur->finish();

    my @sqlList = ();
    for my $m ( @names ) {
	my $m2 = lc($m);
	my $sql2 = "select contact_oid from contact where lower(username) = ? or lower(caliban_user_name) = ?";
	my $cur2 = execSql( $dbh, $sql2, $verbose, $m2, $m2 );
	my ($c2_oid) = $cur2->fetchrow();
	$cur2->finish();
	if ( ! $c2_oid ) {
	    return "Incorrect IMG user name: $m";
	}
	if ( $ext_member_h{$c2_oid} ) {
	    return "User $m is already a member of this group.";
	}

	my $sql = "insert into contact_img_groups\@imgsg_dev (contact_oid, img_group, role) values ($c2_oid, $group_id, 'member')";
	push @sqlList, ( $sql );
    }

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        my $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}


##################################################################
# shareGenomesWithMembers
##################################################################
sub shareGenomesWithMembers {
    WebUtil::printMainForm();

    print "<h1>Grant Genome Access Permission to Members</h1>\n";

    my $group_id = param('group_id');
    if ( ! $group_id ) {
	WebUtil::webError("No group ID is selected.");
	return;
    }

    print WebUtil::hiddenVar( "group_id", $group_id );

    my $contact_oid = WebUtil::getContactOid();
    if ( ! $contact_oid ) {
	WebUtil::webError("Your login has expired.");
	return;
    }
    my $super_user_flag = WebUtil::getSuperUser();

    my $taxon_str = param('img_taxons');
    if ( ! $taxon_str ) {
	WebUtil::webError( "No IMG OIDs are provided." );
	return;
    }
    my $dbh = dbLogin();
    my $sql = qq{
               select role
               from contact_img_groups\@imgsg_dev g
               where g.contact_oid = ? and g.img_group = ?
               };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $group_id );
    my ($my_role) = $cur->fetchrow();
    $cur->finish();
    if ( ! $my_role && $super_user_flag ne 'Yes' ) {
	WebUtil::webError("You don't belong to this group.");
	return;
    }

    ## check users
    my @members = param('member_oid');
    if ( scalar(@members) == 0 ) {
	WebUtil::webError("No members have been selected for sharing.");
	return;
    }

    ## check taxon permissions
    my %public_h;
    my @taxons = split(/\,/, $taxon_str);
    for my $taxon_oid ( @taxons ) {
	$taxon_oid = strTrim($taxon_oid);
	if ( ! isInt($taxon_oid) ) {
	    WebUtil::webError("Incorrect IMG OID: $taxon_oid");
	    return;
	}

	my $sql = "select t.taxon_oid, t.is_public, t.obsolete_flag " .
	    "from taxon t where t.taxon_oid = ? ";
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	my ($t_id, $is_public, $obsolete_flag) = $cur->fetchrow();
	$cur->finish();
	if ( ! $t_id || $obsolete_flag eq 'Yes' ) {
	    WebUtil::webError( "Incorrect IMG OID: $taxon_oid" );
	    return;
	}
	if ( $is_public eq 'Yes' ) {
	    $public_h{$taxon_oid} = $taxon_oid;
	    next;
	}

	## check permission
	if ( $super_user_flag eq 'Yes' ) {
	    ## ok, super user
	    next;
	}
	else {
	    $sql = "select t.taxon_oid, t.analysis_project_id, s.contact " .
		"from taxon t, submission s " .
		"where t.taxon_oid = ? " .
		"and t.submission_id = s.submission_id (+) ";
	    $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	    my ($t2_id, $ap_id, $submitter) = $cur->fetchrow();
	    $cur->finish();

	    if ( $contact_oid == $submitter ) {
		## ok, submitter
		next;
	    }

	    ## check PI
	    if ( $ap_id ) {
		$sql = "select ga.pi_email " .
		    "from gold_analysis_project ga, contact c " .
		    "where ga.gold_id = ? " .
		    "and c.contact_oid = ? " .
		    "and lower(ga.pi_email) = lower(c.email) ";
		$cur = execSql( $dbh, $sql, $verbose, $ap_id, $contact_oid );
		my ($pi_email) = $cur->fetchrow();
		$cur->finish();
		if ( $pi_email ) {
		    ## ok, PI
		    next;
		}
		else {
		    ## check access permission
		    $sql = "select count(*) from contact_taxon_permissions " .
			"where contact_oid = ? and taxon_permissions = ? ";
			$cur = execSql( $dbh, $sql, $verbose,
					$contact_oid, $taxon_oid );
		    my ($cnt) = $cur->fetchrow();
		    $cur->finish();
		    if ( $cnt ) {
			WebUtil::webError( "You don't have the privilege to grant access of IMG Genome $taxon_oid. Please contact the PI or the submitter to grant access." );
			return;
		    }
		    else {
			WebUtil::webError("Incorrect IMG OID: $taxon_oid");
			return;
		    }
		}
	    }
	}
    }

    ## now we can grant access permission
    my @sqlList = ();
    for my $taxon_oid ( @taxons ) {
	if ( $public_h{$taxon_oid} ) {
	    print "<p>Genome $taxon_oid is already public.\n";
	    next;
	}

	my %user_h;
	my $sql = qq{
               select c.contact_oid, c.name
               from contact_taxon_permissions p, contact c
               where p.taxon_permissions = ?
               and p.contact_oid = c.contact_oid
               };
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	for (;;) {
	    my ($c_id, $c_name) = $cur->fetchrow();
	    last if ! $c_id;
	    $user_h{$c_id} = $c_name;
	}
	$cur->finish();

	for my $m1 ( @members ) {
	    if ( $user_h{$m1} ) {
		# user already has permission
		print "<p>Member " . $user_h{$m1} . " already has access permission to genome $taxon_oid\n";
	    }
	    else {
		my $sql3 = "select name, super_user from contact where contact_oid = ? ";
		my $cur3 = execSql( $dbh, $sql3, $verbose, $m1 );
		my ($member_name, $super3) = $cur3->fetchrow();
		$cur3->finish();

		if ( $super3 eq 'Yes' ) {
		    print "<p>Member " . $member_name . " already has access permission to genome $taxon_oid\n";
		}
		else {
		    my $sql2 = "insert into contact_taxon_permissions " .
			"(contact_oid, taxon_permissions) " .
			"values ($m1, $taxon_oid)";
		    print "<p>Grant access of genome $taxon_oid to " . 
			$member_name . "\n";
		    push @sqlList, ( $sql2 );
		}
	    }
	}
    }

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        my $sql = $sqlList[$err-1]; 
        WebUtil::webError( "SQL Error" );
    }

    print "<h5>Finish permission granting. <u>Please do not refresh this page.</u></h5>\n";

    print "<p>\n";
    my $name = "_section_${section}_showGroupDetail";
    print submit( 
	-name  => $name, 
	-value => 'OK', 
	-class => 'smdefbutton'
	);

    print end_form();
}


##################################################################
# db_addNewGroup
##################################################################
sub db_addNewGroup {
    my $group_name = param('group_name');
    if ( ! $group_name ) {
	return "Please enter a group name.";
    }
    if ( length($group_name) > 255 ) {
	$group_name = substr( $group_name, 0, 255 ); 
    } 

    ## check existing group name
    my $dbh = dbLogin();
    my $sql = "select group_id from img_group\@imgsg_dev where lower(group_name) = ?";
    my $cur = execSql( $dbh, $sql, $verbose, lc($group_name) );
    my ($id2) = $cur->fetchrow();
    $cur->finish();
    if ( $id2 ) {
	return "Group name " . escapeHTML($group_name) . " already exists.";
    }

    $group_name =~ s/'/''/g;   # replace ' with ''

    my $group_desc = param('group_desc');
    if ( ! $group_desc ) {
	return "Please enter a group description.";
    }
    if ( length($group_desc) > 512 ) {
	$group_desc = substr( $group_desc, 0, 512 ); 
    } 
    $group_desc =~ s/'/''/g;   # replace ' with ''

    my $contact_oid = WebUtil::getContactOid();
    my $lead_contact = param('lead_contact');
    if ( ! $lead_contact ) {
	$lead_contact = $contact_oid;
    }

    my $sql = "select max(group_id) from img_group\@imgsg_dev";
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($group_id) = $cur->fetchrow();
    $cur->finish();
    if ( ! $group_id ) {
	$group_id = 100;
    }
    else {
	$group_id++;
    }

    my $sql = "insert into img_group\@imgsg_dev (group_id, group_name, " .
	"lead, add_date, comments) values ($group_id, '" .
	$group_name . "', $lead_contact, sysdate, '" . $group_desc . "')";
    my @sqlList = ( $sql );
    $sql = "insert into contact_img_groups\@imgsg_dev " .
	"(contact_oid, img_group, role) " .
	"values ($lead_contact, $group_id, 'owner')";
    push @sqlList, ( $sql );

    my $err = db_sqlTrans( \@sqlList );
    if ( $err ) {
        $sql = $sqlList[$err-1]; 
        return "SQL Error: $sql";
    }

    return "";
}


1;
