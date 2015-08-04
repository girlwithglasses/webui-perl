###########################################################################
# MyImg.pm - Functions supporting MyIMG utilty.
#    --es 04/16/2005
# $Id: MyIMG.pm 33772 2015-07-21 20:45:17Z klchu $
############################################################################
package MyIMG;
my $section = "MyIMG";

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
use GeneCartStor;
use DataEntryUtil;
use Sequence;
use InnerTable;
use MailUtil;
use QueryUtil;
use GenomeListFilter;
use ImgGroup;

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
my $public_login         = $env->{public_login};
my $public_nologin_site  = $env->{public_nologin_site};
my $img_lite             = $env->{img_lite};
my $annotation_site_url  = $env->{annotation_site_url};
my $show_private         = $env->{show_private};
my $annot_site_url       = $env->{annot_site_url};
my $myimg_job            = $env->{myimg_job};
my $cgi_cache_enable     = $env->{cgi_cache_enable};
my $rdbms                = WebUtil::getRdbms();
my $imgAppTerm           = "IMG";
my $oracle_config        = $env->{oracle_config};
$imgAppTerm = "IMG/M" if $include_metagenomes;

my $max_batch_size            = 100;
my $max_upload_size           = 10000000;
my $max_annotation_size       = 10000;
my $max_gene_annotation_batch = 10000;

my $max_upload_line_count = 10000;

my $tabDelimErrMsg = qq{
  (Also, please ensure that your file type is a 
   tab delimited file.)
};

my $YUI            = $env->{yui_dir_28};
my $yui_tables     = $env->{yui_tables};
my $img_taxon_edit = $env->{img_taxon_edit};    # for taxon editor

my $config_fname = WebUtil::lastPathTok($oracle_config);
my ( $web0, $ora_db_user, $config0 ) = split( /\./, $config_fname );

my $contact_oid = WebUtil::getContactOid();

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page     = param("page");
    my $username = param("username");
    my $password = param("password");

    my $contact_oid = WebUtil::getContactOid();

    ## Backwards compability
    my $form = param("form");
    $page = $form if ( $form ne "" && $page eq "" );
    if ( $page eq "changePasswordForm" ) {
        if ( $contact_oid eq "" || $contact_oid < 1 ||  $contact_oid eq '901') {
            WebUtil::webError("Page not found");
        } 
        printChangePasswordForm();
    } elsif ( paramMatch("changePassword") ne "" ) {
        if ( $contact_oid eq "" || $contact_oid < 1 ||  $contact_oid eq '901') {
            WebUtil::webError("Page not found");
        } 
        changePassword();
    } elsif ( $page eq "updateContactForm" ) {
        if ( $contact_oid eq "" || $contact_oid < 1 ||  $contact_oid eq '901') {
            WebUtil::webError("Page not found");
        } 
        print "<h1>Contact Information</h1>\n";
        printUpdateContactForm();
    } elsif ( paramMatch("contactChanged") ne "" ) {
        if ( $contact_oid eq "" || $contact_oid < 1 ||  $contact_oid eq '901') {
            WebUtil::webError("Page not found");
        }         
        updateContactInfo();
    } elsif ( $page eq "geneCartUploadForm" ) {
        printGeneCartUploadForm();
    } elsif ( $page eq "funcCartUploadForm" ) {
        printFuncCartUploadForm();
    } elsif ( $page eq "taxonUploadForm" ) {
        GenomeCart::printTaxonUploadForm();
    } elsif ( $page eq "myJobForm" ) {
        printMyJobForm();
    } elsif ( $page eq "myAnnotationsForm" ) {
        printMyAnnotationsForm();
    } elsif ( $page eq "preferences" ) {
        printPreferences();
    } elsif ( paramMatch("setPreferences") ne "" ) {
        doSetPreferences();
    } elsif ( paramMatch("saveMyIMGPref") ne "" ) {

        #	my $res = doSaveMyIMGPref();
        #	printPreferences();
    } elsif ( $page eq "viewMyAnnotations"
        || paramMatch("viewMyAnnotations") ne "" )
    {
        my $view_type = param('view_type');
        if ( blankStr($view_type) || $view_type eq 'all' ) {
            printViewMyAnnotationResults("");
        } elsif ( $view_type eq 'genome' ) {
            printMyGenomeAnnotationForm();
        } elsif ( $view_type eq 'cart' ) {
            printGeneCartAnnotationForm(1);
        }
    } elsif ( paramMatch("removeMyAnnotations") ne "" ) {
        printViewMyAnnotationResults("");
    } elsif ( paramMatch("uploadAnnotations") ne "" ) {
        printUploadAnnotationFileForm();
    } elsif ( paramMatch("validateAnnotFile") ne "" ) {
        printValidateAnnotResultForm();
    } elsif ( paramMatch("dbAnnotFileUpload") ne "" ) {
        my $gene_oid_list = dbAnnotFileUpload();
        WebUtil::webError("No annotation uploaded!")
          if ( blankStr($gene_oid_list) );
        printViewMyAnnotationResults($gene_oid_list);
    } elsif ( paramMatch("updateAnnotations") ne "" ) {
        dbUpdateAnnotation();
        if ( param('source_page') eq 'selected_gene_annot' ) {
            main::printAppHeader("MyIMG");
            my $view_type = param('view_type');
            if ( blankStr($view_type) || $view_type eq 'all' ) {
                printViewMyAnnotationResults("");
            } elsif ( $view_type eq 'genome' ) {
                printMyGenomeAnnotationForm();
            } elsif ( $view_type eq 'cart' ) {
                printGeneCartAnnotationForm(1);
            }
        } else {

            # show gene cart
            main::printAppHeader("AnaCart");
            my $gc = new GeneCartStor();
            $gc->webAddGenes();
            $gc->printGeneCartForm( '', 1 );
        }
    } elsif ( paramMatch("deleteAnnotations") ne "" ) {
        dbDeleteAnnotation();

        # show gene cart
        main::printAppHeader("AnaCart");
        my $gc = new GeneCartStor();
        $gc->webAddGenes();
        $gc->printGeneCartForm( '', 1 );
    } elsif ( paramMatch("geneCartAnnotations") ne "" ) {
        printGeneAnnotationForm();
    } elsif ( paramMatch("loadGeneAnnotations") ne "" ) {
        printGeneAnnotationForm(1);
    } elsif ( paramMatch("transferAnnotations") ne "" ) {
        transferGenePageAnnotations();
    } elsif ( paramMatch("viewMyGenomeAnnotations") ne "" ) {
        printMyGenomeAnnotationForm();
    } elsif ( paramMatch("mySelectedGenomeAnnotations") ne "" ) {
        printViewMyAnnotationResults();
    } elsif ( $page eq "viewGroupAnnotations"
        || paramMatch("viewGroupAnnotations") ne "" )
    {
        my $view_type = param('view_type');
        if ( blankStr($view_type) || $view_type eq 'all' ) {
            printGroupAnnotationForm();
        } elsif ( $view_type eq 'genome' ) {
            printGroupGenomeAnnotationForm();
        } elsif ( $view_type eq 'cart' ) {
            printGeneCartAnnotationForm(2);
        }
    } elsif ( $page eq "groupUsersList" ) {
        printGroupUserAnnotationForm();
    } elsif ( paramMatch("viewAllUserAnnotations") ne "" ) {
        my $view_type = param('view_type');
        if ( blankStr($view_type) || $view_type eq 'all' ) {
            printAllUserAnnotationForm();
        } elsif ( $view_type eq 'genome' ) {
            printAllGenomeAnnotationForm();
        } elsif ( $view_type eq 'cart' ) {
            printGeneCartAnnotationForm(3);
        }
    } elsif ( $page eq "groupAnnotForGenome" ) {
        printViewOneTaxonGroupAnnot();
    } elsif ( paramMatch("selectedAnnotations") ne "" ) {
        printSelectedAnnotationForm();
    } elsif ( paramMatch("viewGenomeAnnotations") ne "" ) {
        printAllGenomeAnnotationForm();
    } elsif ( paramMatch("showGeneAnnotation") ne "" ) {
        printShowGeneAnnotationForm();
    } elsif ( paramMatch("exportMyAnnotation") ne "" ) {
        exportMyAnnotations();
    } elsif ( param("logout") ne "" ) {
        WebUtil::setSessionParam( "contact_oid", "" );
        if ($user_restricted_site) {
            print qq{
                <div id='message'>\n
		    <p>Logged out.</p>\n
		</div>\n
	    };
        } else {
            printHome();
        }
    } elsif ( paramMatch("newAnnotations") ne "" ) {
        viewNewAnnotations();
    } elsif ( paramMatch("updMyGeneAnnot") ne "" ) {
        printUpdateGeneAnnotForm();
    } elsif ( $page eq "genomesList" ) {
        printAllGenomeAnnotationForm();
    } elsif ( $page eq "usersList" ) {
        printAllUserAnnotationForm();
    } elsif ( $page eq "annotationsForGenome" ) {
        printViewOneTaxonAnnot();
    } elsif ( $page eq "viewMyMissingGenes"
        || paramMatch("viewMyMissingGenes") ne "" )
    {
        printMyMissingGenesForm();
    } elsif ( $page eq "viewMyTaxonMissingGenes"
        || paramMatch("viewMyTaxonMissingGenes") ne "" )
    {
        printMyTaxonMissingGenesForm();
    } elsif ( $page eq "viewPublicTaxonMissingGenes"
        || paramMatch("viewPublicTaxonMissingGenes") ne "" )
    {
        printPublicTaxonMissingGenesForm();
    } elsif ( $page eq "selectTaxonForMissingGene"
        || paramMatch("selectTaxonForMissingGene") ne "" )
    {
        my $selected_taxon = param('taxon_oid');
        selectTaxonForMissingGeneForm($selected_taxon);
    } elsif ( $page eq "dbShareTaxonMyIMG"
        || paramMatch("dbShareTaxonMyIMG") ne "" )
    {
        my $msg = dbShareTaxonMyIMGAnnotations();
        if ($msg) {
            WebUtil::webError($msg);
        } else {
            printMyGenomeAnnotationForm();
        }
    } elsif ( $page eq "dbShareTaxonMissingGene"
        || paramMatch("dbShareTaxonMissingGene") ne "" )
    {
        my $msg = dbShareTaxonMissingGene();
        if ($msg) {
            WebUtil::webError($msg);
        } else {
            printMyMissingGenesForm();
        }
    } elsif ( $page eq "shareMissingGene"
        || paramMatch("shareMissingGene") ne "" )
    {
        shareMissingGeneForm();
    } elsif ( $page eq "dbUpdateMissingGeneSharing"
        || paramMatch("dbUpdateMissingGeneSharing") ne "" )
    {
        my $msg = dbUpdateMissingGeneSharing();
        if ($msg) {
            WebUtil::webError($msg);
        } else {
            printMyTaxonMissingGenesForm();
        }
    } elsif ( $page eq "addMyTaxonMissingGene"
        || paramMatch("addMyTaxonMissingGene") ne "" )
    {
        addUpdateMyTaxonMissingGeneForm(0);
    } elsif ( paramMatch("dbAddMyGene") ne "" ) {
        dbAddUpdateMyGene(0);

        # show missing gene annotations
        my $source_page = param('source_page');
        main::printAppHeader("MyIMG");
        if ( $source_page eq 'group_missing_gene' ) {
            printGrpAllMissingGenesForm('group');
        } elsif ( $source_page eq 'all_missing_gene' ) {
            printGrpAllMissingGenesForm('all');
        } else {
            printMyMissingGenesForm();
        }
    } elsif ( $page eq "refreshViewer"
        || paramMatch("refreshViewer") ne "" )
    {
        my $mygene_oid     = param('mygene_oid');
        my $taxon_oid      = param('taxon_oid');
        my $product        = param('product_name');
        my $ec_number      = param('ec_number');
        my $locus_type     = param('locus_type');
        my $locus_tag      = param('locus_tag');
        my $scaffold       = param('scaffold');
        my $dna_coords     = param('dna_coords');
        my $strand         = param('strand1');          # form name not "strand"
        my $ispseudo       = param('is_pseudogene');
        my $description    = param('description');
        my $symbol         = param('gene_symbol');
        my $hitgene_oid    = param('hitgene_oid');
        my $ispublic       = param('is_public');
        my $replacing_gene = param('replacing_gene');
        printTaxonMissingGeneForm(
            $mygene_oid,  $taxon_oid, $product,     $ec_number, $locus_type,
            $locus_tag,   $scaffold,  $dna_coords,  $strand,    $ispseudo,
            $description, $symbol,    $hitgene_oid, $ispublic,  $replacing_gene
        );
    } elsif ( $page eq "updateMyTaxonMissingGene"
        || paramMatch("updateMyTaxonMissingGene") ne "" )
    {
        my $mygene_oid = param('mygene_oid');
        WebUtil::webError("Please select a missing gene annotation to update.")
          if ( !$mygene_oid );
        addUpdateMyTaxonMissingGeneForm($mygene_oid);
    } elsif ( paramMatch("dbUpdateMyGene") ne "" ) {
        my $mygene_oid = param('mygene_oid');
        if ( !$mygene_oid ) {
            main::printAppHeader("MyIMG");
            WebUtil::webError("Please select a missing gene annotation to update.");
        }
        dbAddUpdateMyGene($mygene_oid);

        # show missing gene annotations
        my $source_page = param('source_page');
        main::printAppHeader("MyIMG");
        if ( $source_page eq 'group_missing_gene' ) {
            printGrpAllMissingGenesForm('group');
        } elsif ( $source_page eq 'all_missing_gene' ) {
            printGrpAllMissingGenesForm('all');
        } else {
            printMyMissingGenesForm();
        }
    } elsif ( $page eq "deleteMyTaxonMissingGene"
        || paramMatch("deleteMyTaxonMissingGene") ne "" )
    {
        my $mygene_oid = param('mygene_oid');
        WebUtil::webError("Please select a missing gene annotation to delete.")
          if ( !$mygene_oid );
        confirmDeleteMyTaxonMissingGeneForm($mygene_oid);
    } elsif ( paramMatch("dbDeleteMyGene") ne "" ) {
        my $mygene_oid = param('mygene_oid');
        if ( !$mygene_oid ) {
            main::printAppHeader("MyIMG");
            WebUtil::webError("Please select a missing gene annotation to delete.");
        }
        dbDeleteMyGene($mygene_oid);

        # show missing gene annotations
        my $source_page = param('source_page');
        main::printAppHeader("MyIMG");
        if ( $source_page eq 'group_missing_gene' ) {
            printGrpAllMissingGenesForm('group');
        } elsif ( $source_page eq 'all_missing_gene' ) {
            printGrpAllMissingGenesForm('all');
        } else {
            printMyMissingGenesForm();
        }
    } elsif ( $page eq "viewGroupMissingGenes"
        || paramMatch("viewGroupMissingGenes") ne "" )
    {
        printGrpAllMissingGenesForm('group');
    } elsif ( $page eq "viewGroupTaxonMissingGenes"
        || paramMatch("viewGroupTaxonMissingGenes") ne "" )
    {
        printGrpAllTaxonMissingGenesForm('group');
    } elsif ( $page eq "viewAllMissingGenes"
        || paramMatch("viewAllMissingGenes") ne "" )
    {
        printGrpAllMissingGenesForm('all');
    } elsif ( $page eq "viewAllTaxonMissingGenes"
        || paramMatch("viewAllTaxonMissingGenes") ne "" )
    {
        printGrpAllTaxonMissingGenesForm('all');
    } elsif ( $page eq "displayMissingGeneInfo"
        || paramMatch("displayMissingGeneInfo") ne "" )
    {
        displayMissingGeneInfo();
    } elsif ( $page eq "potentialMissingGene"
        || paramMatch("potentialMissingGene") ne "" )
    {
        listPotentialMissingGenes();
    } elsif ( paramMatch("dbAddPotentialGene") ne "" ) {
        my $msg = dbAddPotentialGene();
        main::printAppHeader("MyIMG");
        if ( isInt($msg) && $msg > 0 ) {
            my $mygene_oid = $msg;
            addUpdateMyTaxonMissingGeneForm($mygene_oid);
        } else {
            WebUtil::webError($msg);
        }
    } elsif ( $page eq "scaffoldMissingGene"
        || paramMatch("scaffoldMissingGene") ne "" )
    {
        listScaffoldMissingGenes();
    } elsif ( paramMatch("dbAddScaffoldGene") ne "" ) {
        my $msg = dbAddScaffoldGene();
        main::printAppHeader("MyIMG");
        if ( isInt($msg) && $msg > 0 ) {
            my $mygene_oid = $msg;
            addUpdateMyTaxonMissingGeneForm($mygene_oid);
        } else {
            WebUtil::webError($msg);
        }
    } elsif ( $page eq "computePhyloDistOnDemand"
        || paramMatch("computePhyloDistOnDemand") ne "" )
    {
        my $msg = computePhyloDistOnDemand();
        WebUtil::webError($msg) if ( !blankStr($msg) );
        printMyJobForm();
    } elsif ( $page eq "computePhyloProfOnDemand"
        || paramMatch("computePhyloProfOnDemand") ne "" )
    {
        my $msg = computePhyloProfOnDemand();
        WebUtil::webError($msg) if ( !blankStr($msg) );
        printMyJobForm();
    } elsif ( paramMatch("viewJobDetail") ne "" ) {
        printViewJobDetail();
    } elsif ( paramMatch("cancelImgJob") ne "" ) {
        my $msg = cancelImgJob();
        WebUtil::webError($msg) if ( !blankStr($msg) );
        printMyJobForm();
    } elsif ( paramMatch("changeUserNotes") ne "" ) {
        changeUserNotes();
    } elsif ( $page eq "updateMyIMGTermForm"
        || paramMatch("updateMyIMGTermForm") ne "" )
    {
        printMyIMGGenesTermForm();
    } elsif ( $page eq "confirmMyIMGGeneTerms"
        || paramMatch("confirmMyIMGGeneTerms") ne "" )
    {
        printConfirmMyIMGGenesTerms();
    } elsif ( $page eq "updateMyIMGGeneTerms"
        || paramMatch("updateMyIMGGeneTerms") ne "" )
    {
        dbUpdateMyIMGGeneTerms();

        my $source_page = param('source_page');
        if ( $source_page eq 'viewMyAnnotations' ) {
            printViewMyAnnotationResults("");
        } else {
            printMyAnnotationsForm();
        }
    } elsif ( $page eq "updateTermForm"
        || paramMatch("updateTermForm") ne "" )
    {
        printMyMissingGenesTermForm();
    } elsif ( $page eq "confirmMissingGeneTerms"
        || paramMatch("confirmMissingGeneTerms") ne "" )
    {
        printConfirmMissingGenesTerms();
    } elsif ( $page eq "updateMissingGeneTerms"
        || paramMatch("updateMissingGeneTerms") ne "" )
    {
        dbUpdateMissingGeneTerms();

        my $source_page = param('source_page');
        if ( $source_page eq 'viewMyTaxonMissingGenes' ) {
            printMyTaxonMissingGenesForm();
        } else {
            printMyAnnotationsForm();
        }
    } else {
        printHome();
    }
}

############################################################################
# printUpdateContactForm
############################################################################
sub printUpdateContactForm {
    my ($error_message) = @_;

    my $contact_oid = WebUtil::getContactOid();
    if ( $contact_oid eq "" || $contact_oid < 1 ) {
        WebUtil::webError("Page not found");
    }

    if ( $error_message ne "" ) {
        print qq{
            <h1>Error</h1>
            <p> <font color='red'>
            $error_message
            </font> </p>
        };

        # do not return here.
        # The unupdated contact form should still be displayed.
    }

    ### SQL
    my $sql = qq{
	select name, title, department, 
	    email, phone, organization, 
	    address, city, state, country
	from contact
	where contact_oid = ?
    };
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my ( $name, $title, $department, $email, $phone, $organization, $address, $city, $state, $country, ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    ### print html form
    print start_form( -action => "$section_cgi", -name => "contactForm" );
    print "<table border=0>\n";

    my @form_labels = (
        "*Name",   "*Title", "*Department", "*Organization", "*Email", "*Phone",
        "Address", "*City",  "State/Prov.", "*Country"
    );
    my @form_names =
      ( "name", "title", "department", "organization", "email", "phone", "address", "city", "state", "country" );
    my @form_values = ( $name, $title, $department, $organization, $email, $phone, $address, $city, $state, $country );
    for ( my $i = 0 ; $i < $#form_labels + 1 ; $i++ ) {
        my $form_label = @form_labels[$i];
        my $form_name  = @form_names[$i];
        my $form_value = @form_values[$i];
        my $first_char = substr( $form_label, 0, 1 );
        my $font_color;
        if ( $first_char eq "*" ) {
            $font_color = "red";
        } else {
            $font_color = "black";
        }
        print qq{
            <tr>
            <td><font color='$font_color'>$form_label</td>
            <td><input type='text' name='$form_name' value='$form_value'/></td>
            </tr>
        };
    }

    print qq{
        </table>\n
        <p>* Required fields.</p>\n
    };

    my $name = "_section_${section}_contactChanged";
    print submit(
        -name  => $name,
        -value => "Update",
        -class => "smbutton"
    );
    print end_form();
}

############################################################################
# updateContactInfo
############################################################################
sub updateContactInfo {
    my $contact_oid = WebUtil::getContactOid();
    if ( $contact_oid eq "" || $contact_oid < 1 ) {
        WebUtil::webError("Page not found");
    }

    my $name         = param('name');
    my $title        = param('title');
    my $department   = param('department');
    my $email        = param('email');
    my $phone        = param('phone');
    my $organization = param('organization');
    my $address      = param('address');
    my $city         = param('city');
    my $state        = param('state');
    my $country      = param('country');
    my @fields       = ( $name, $title, $department, $email, $phone, $organization, $address, $city, $state, $country, );
    my @dummy_names  =
      ( "Name", "Title", "Department", "Email", "Phone number", "Organization", "-", "City", "-", "Country" );

    for ( my $i = 0 ; $i < $#fields + 1 ; $i++ ) {
        if ( blankStr( $fields[$i] ) ) {
            if ( $dummy_names[$i] ne "-" ) {

                # blank fields not tolerated
                printUpdateContactForm("$dummy_names[$i] cannot be blank.");
                WebUtil::printStatusLine( "Error", 2 );
                WebUtil::webExit(0);
            } else {

                # blank fields tolerated
                $fields[$i] = undef;
            }
        }
    }

    if ( !MailUtil::validateEMail($email) ) {
        printUpdateContactForm("$email is not a valid email address.");
        WebUtil::printStatusLine( "Error", 2 );
        WebUtil::webExit(0);
    }

    # SQL
    my $dbh = dbLogin();
    my $sql = qq{
           update contact
           set name = ?, title = ?, department = ?, email = ?, phone = ?, 
           organization = ?, address = ?, city = ?, state = ?, country = ?
           where contact_oid = ? 
    };
    my @data = ( @fields, $contact_oid );
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@data, $verbose );
    $cur->finish();

    #$dbh->disconnect();

    ### print html form
    print "<h1>Contact Information Updated</h1>\n";
    printUpdateContactForm();
}

############################################################################
# printHome - Show home page, which is different depending upon if
#   the user is logged in.
############################################################################
sub printHome {
    my $contact_oid = WebUtil::getContactOid();
    if ( $contact_oid > 0 ) {
        printLoggedInPage();
    } else {
        printAboutPage();
    }
}

############################################################################
# printAboutPage - Print "about MyIMG" page.
# This page is printed only when user_restricted_site = 0
############################################################################
sub printAboutPage {
    print "<h1>MyIMG</h1>\n";

    my $url                 = "$main_cgi?section=TaxonList&page=taxonListAlpha";
    my $genome_browser_link = WebUtil::alink( $url, "Genome Browser" );

    my $url = "$main_cgi?section=CompareGenomes&page=taxonBreakdownStats";
    $url .= "&statTableName=taxon_stats&initial=1";
    my $genome_statistics_link = WebUtil::alink( $url, "Genome Statistics" );

    print qq{
        <p>
        IMG provides support for exporting genome information from
        the $genome_browser_link and $genome_statistics_link pages,
        via genome breakdown and comparative statistics.
        </p>
        <p>
        From this page you can:<br/>
        <ul>
        <li>save your preferences throughout IMG</li>
        <li>upload Genome selections</li>
        </ul>
        </p>
    };

    if ($public_nologin_site) {
        print qq{
            <p>
            (You are currently logged in as <i>public</i> user.)
            </p>\n
        };
    }
}

############################################################################
# printLoggedInPage
############################################################################
sub printLoggedInPage {
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid || $public_nologin_site ) {
        printAboutPage();
        return;
    }

    ### SQL
    my $dbh = WebUtil::dbLogin();
    my $sql = qq{
        select username
        from contact
        where contact_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my $username = $cur->fetchrow();
    $cur->finish();

    # print html form
    WebUtil::printMainForm();
    print "<h1>MyIMG</h1>\n";
    print "<h3>Logged in as <b>$username</b>.</h3>\n";

    my $super_user_flag = "";
    if ( $contact_oid > 0 ) {
        $super_user_flag = WebUtil::getSuperUser();
    }

    my $html_text_fragment;
    if ( DataEntryUtil::db_isPublicUser($contact_oid) ) {
        $html_text_fragment = "<li>to upload your Genome selections</li>\n";
    } else {
        my $x;
        my $y;
        $x = "<li>to view and edit your annotations</li>\n"
          if ($show_myimg_login);
        $y = "<li>to view annotations by other users</li>\n"
          if ( $show_myimg_login && $super_user_flag eq 'Yes' );
        $html_text_fragment = qq{
            <li>to annotate your Genome</li>\n
            <li>to upload your Genome selections</li>\n
            $x$y
        };
    }

    print qq{   
        <p>Welcome to the curation version of IMG.</p>
        <p>
        You can use MyIMG for:
        <ul>
        <li>saving your preferences throughout IMG</li>
        $html_text_fragment
        </ul>
        </p>\n
    };

    #$dbh->disconnect();

    ImgGroup::showAllGroups();

    printLogout();
    print end_form();

}

############################################################################
# printChangePasswordForm - Form for user to change password.
# Only used by "oldLogin".
############################################################################
sub printChangePasswordForm {
    print start_form( -action => "$section_cgi", -name => "changePaswordForm" );

    print qq{
        <h1>Change Password</h1>
        <p>
        Old Password:<br/>
        <input type='password' name='oldPassword' size='30'>
        </p>
        <p>
        New Password:<br/>
        <input type='password' name='newPassword1' size='30'>
        </p>
        <p>
        New Password (again):<br/>
        <input type='password' name='newPassword2' size='30'>
        </p>
    };

    my $name = "_section_${section}_changePassword";
    print submit(
        -name  => $name,
        -value => "Change Password",
        -class => "smbutton"
    );

    print end_form();
}

############################################################################
# validateUserPassword - Valid user login.  Set session username if valid.
#    Return 1 (true) for ok, or 0 (false) for incorrect login.
############################################################################
sub validateUserPassword {
    my ( $username, $password ) = @_;
    $username = param("username") if $username eq "";
    $password = param("password") if $password eq "";

    if($user_restricted_site && $username eq 'public') {
        # public user only for img/w or img/m not er or mer
        return 0;
    } 


    my $dbh   = WebUtil::dbLogin();
    my $md5pw = md5_base64($password);
    $username = strTrim($username);
    my $sql = qq{
            select contact_oid, username, password, super_user, name, email, caliban_id, caliban_user_name
            from contact
            where username = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $username );
    my ( $contact_oid0, $username0, $password0, $super_user0, $name, $email, $caliban_id, $caliban_user_name ) =
      $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    if ( $password0 ne $md5pw ) {
        WebUtil::webLog "password0='$password0'\n" if $verbose >= 2;
        WebUtil::webLog("validateUserPassword: incorrect login for username='$username'\n")
          if $verbose >= 1;
        return 0;
    }

    setSessionParam( "contact_oid",       $contact_oid0 );
    setSessionParam( "super_user",        $super_user0 );
    setSessionParam( "username",          $username0 );
    setSessionParam( "name",              $name );
    setSessionParam( "email",             $email );
    setSessionParam( "caliban_id",        $caliban_id );
    setSessionParam( "caliban_user_name", $caliban_user_name );
    return 1;
}

############################################################################
# setPublicUser - Set public user, does not require login.
############################################################################
sub setPublicUser {
    my ($username) = @_;

    my $dbh = WebUtil::dbLogin();
    my $sql = qq{
        select contact_oid
        from contact
        where username = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $username );
    my ($contact_oid) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();
    if ( !$contact_oid ) {
        webDie("setPublicUser: invalid user '$username'\n");
    }

    setSessionParam( "contact_oid", $contact_oid );
    setSessionParam( "super_user",  "No" );
    setSessionParam( "username",    $username );
}

############################################################################
# changePassword - See if you can change the password.
############################################################################
sub changePassword {
    my $oldPassword  = param("oldPassword");
    my $newPassword1 = param("newPassword1");
    my $newPassword2 = param("newPassword2");

    print "<h1>Change Password</h1>\n";

    my $dbh         = dbLogin();
    my $contact_oid = WebUtil::getContactOid();
    my $md5pw       = md5_base64($oldPassword);
    my $sql         = qq{
        select password
        from contact
        where contact_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my ($password0) = $cur->fetchrow();
    $cur->finish();

    if ( $password0 ne $md5pw ) {
        WebUtil::webLog "password0='$password0'\n" if $verbose >= 2;
        WebUtil::webLog("changePassword: Incorrect old password\n")
          if $verbose >= 1;
        print "<p>\n";
        WebUtil::webError("Incorrect old password.  Please try again.");
        print "</p>\n";

        #$dbh->disconnect();
        return 0;
    }

    if ( $newPassword1 ne $newPassword2 ) {
        print "<p>\n";
        WebUtil::webError("New password does not match.  Please try again.");
        print "</p>\n";

        #$dbh->disconnect();
        return 0;
    }

    my $md5pw = md5_base64($newPassword1);
    my $sql   = qq{
        update contact
        set password = ?
        where contact_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $md5pw, $contact_oid );
    $cur->finish();

    #$dbh->disconnect();

    print qq{
        <div id='message'> <p>
            Password successfully changed.
        </p> </div>
    };

    return 1;

}

############################################################################
# printUploadAnnotationFileForm
############################################################################
sub printUploadAnnotationFileForm {
    print "<h1>Upload MyIMG Annotations from File</h1>\n";

    # need a different ENCTYPE for file upload
    print start_form(
        -name    => "mainForm",
        -enctype => "multipart/form-data",
        -action  => "$section_cgi"
    );

    # check log in
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::printStatusLine( "Aborted", 2 );
        WebUtil::webError("You are not logged in.");
    }

    # print messages
    print qq{
        <p>
        The input file must be a plain tab-delimited text file
        with no more than $max_upload_line_count lines.
        The first line of file contains the field names.        
        Each of the following lines contains a user annotation.
        </p>
        <p>The file contains the following fields:</p>
        <ul>\n
          <li>Gene ID or OID (<font color='red'>required</font>): gene object ID</li>\n
          <li>
            Annotated Product Name (<font color='red'>required</font>):
            my annotated product name(s); separate multiple product names using ';'
          </li>\n
          <li>Annotated Prot Desc (optional): my annotated prot description</li>\n
          <li>
            Annotated EC Number (optional): my annotated EC number(s);
            separate multiple EC numbers using space or ';'
          </li>\n
          <li>
            Annotated PUBMED ID (optional): my annotated PUBMED ID(s);
            separate multiple PUBMED ID's using space or ';'
          </li>\n
          <li>Inference (optional): my annotated inference</li>\n
          <li>Is Pseudo Gene? (optional): is pseudo gene? (Yes, No)</li>\n
          <li>Notes (optional): my annotated free text notes</li>\n
          <li>Annotated Gene Symbol (optional): my annotated gene symbol</li>\n
          <li>Remove Gene from Genome? (optional): remove gene from genome? (Yes, No)</li>\n
          <li>Is Public? (optional): is this annotation public? (Yes, No)</li>\n
        </ul>
        <p>
          File Name:&nbsp; 
          <input type='file' id='fileselect' name='fileselect' size='100' />\n
        </p>
    };

    # set buttons
    print "<p>\n";
    my $name = "_section_${section}_validateAnnotFile";
    print submit(
        -name  => $name,
        -value => 'Open',
        -class => 'smdefbutton'
    );
    print nbsp(1);
    my $name = "_section_${section}_index";
    print submit(
        -name  => $name,
        -value => 'Cancel',
        -class => 'smbutton'
    );
    print "</p>\n";

    print end_form();
}

############################################################################
# printValidateAnnotResultForm
############################################################################
sub printValidateAnnotResultForm {
    print "<h1>File Validation Result</h1>\n";
    WebUtil::printMainForm();

    # check log in
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::printStatusLine( "Aborted", 2 );
        WebUtil::webError("You are not logged in.");
    }

    my $filename = param("fileselect");
    if ( blankStr($filename) ) {
        WebUtil::webError("No file name is provided.");
        return;
    }

    print "<h2>File Name: $filename</h2>\n";
    print "<p>\n";    # paragraph section puts text in proper font.

    # tmp file name for file upload
    my $sessionId       = WebUtil::getSessionId();
    my $tmp_upload_file = $cgi_tmp_dir . "/upload_annot." . $sessionId . ".txt";

    ## Set parameters.
    print WebUtil::hiddenVar( "section",            $section );
    print WebUtil::hiddenVar( "tmpAnnotUploadFile", $tmp_upload_file );

    # save the uploaded file to a tmp file, because we need to parse the file
    # more than once
    if ( !open( FILE, '>', $tmp_upload_file ) ) {
        WebUtil::webError("Cannot open tmp file $tmp_upload_file.");
        return;
    }

    # show message
    WebUtil::printStatusLine( "Validating ...", 1 );

    my $line;
    my $line_no   = 0;
    my @fld_names = ();
    my $msg       = "";
    my $hasError  = 0;

    while ( $line = <$filename> ) {

        # we don't want to process large files
        if ( $line_no <= $max_upload_line_count ) {
            print FILE $line;
        }

        $line_no++;

        if ( $line_no == 1 ) {
            chomp($line);
            my @flds = split( /\t/, $line );

            # header line
            for my $s1 (@flds) {
                $s1 = WebUtil::strTrim($s1);
                if ( WebUtil::inArray_ignoreCase( $s1, @fld_names ) ) {
                    $hasError = 99;
                    $msg      = "The file contains duplicate fields '$s1'.";
                    last;
                }

                # save field name
                push @fld_names, ($s1);
            }

            last if ( $hasError == 99 );

            if (   WebUtil::inArray_ignoreCase( 'gene_oid', @fld_names ) == 0
                && WebUtil::inArray_ignoreCase( 'Gene OID', @fld_names ) == 0 )
            {

                $hasError = 99;
                $msg      = "The file does not have 'Gene OID' field.";
                last;
            }

            if (   WebUtil::inArray_ignoreCase( 'myimg_annotation', @fld_names ) == 0
                && WebUtil::inArray_ignoreCase( 'Annotated Product Name', @fld_names ) == 0 )
            {
                $hasError = 99;
                $msg      = "The file does not have 'Annotated Product Name' field.";
                last;
            }
        }
    }
    close(FILE);

    if ( $hasError == 99 ) {

        # stop processing
        WebUtil::webError($msg);
        print "<br/>\n";
        return;
    }

    ## buttons
    my $name = "_section_${section}_dbAnnotFileUpload";
    print submit(
        -name  => $name,
        -value => 'Upload',
        -class => 'smdefbutton'
    );
    print nbsp(1);
    my $name = "_section_${section}_index";
    print submit(
        -name  => $name,
        -value => 'Cancel',
        -class => 'smbutton'
    );
    print "</p>\n";

    # now read from tmp file
    if ( !open( FILE, $tmp_upload_file ) ) {
        WebUtil::printStatusLine( "Failed.", 2 );
        WebUtil::webError("Cannot open tmp file $tmp_upload_file.");
        return;
    }

    my $dbh = WebUtil::dbLogin();
    my $it  = new InnerTable( 1, "MyAnnotations$$", "MyAnnotations", 2 );
    my $sd  = $it->getSdDelim();                                            # sort delimiter
    $it->addColSpec("Line No.");
    $it->addColSpec( "Gene ID",                  "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated Product Name",   "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated Prot Desc",      "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated EC Number",      "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated PUBMED ID",      "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Inference",                "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Is Pseudo Gene?",          "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Notes",                    "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated Gene Symbol",    "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Remove Gene from Genome?", "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Message",                  "char desc", "left", "", "", "wrap" );

    $line_no  = 0;
    $msg      = "";
    $hasError = 0;
    while ( $line = <FILE> ) {
        chomp($line);
        my @flds = split( /\t/, $line );
        $line_no++;

        next if ( $line_no == 1 );

        # we don't want to process large files
        last if ( $line_no > $max_upload_line_count );

        my $row = $line_no . $sd . $line_no . "\t";

        # process this line
        $hasError = 0;
        $msg      = "";
        my $gene_oid = "";
        my %fld_vals;

        my $j = 0;
        for my $fld_name (@fld_names) {

            # get field value
            last if ( $j >= scalar(@flds) );

            my $lc_fld_name = lc($fld_name);
            $fld_vals{$lc_fld_name} = WebUtil::strTrim( $flds[$j] );

            #print "<p>$lc_fld_name, $j, $flds[$j]</p>\n";

            if ( $lc_fld_name eq 'gene_oid' || $lc_fld_name eq lc('Gene OID') ) {
                $gene_oid = $flds[$j];
            }

            # next
            $j++;
        }

        # check user input
        # check gene_oid
        if ( isInt($gene_oid) ) {
            require GeneCartDataEntry;
            my ( $found, $product, $new_gene_oid ) = GeneCartDataEntry::checkGeneOid( $dbh, $gene_oid );
            if ( !$found ) {
                $msg      = "Error: Gene ID (or 'Gene OID') '$gene_oid' does not exist.";
                $hasError = 1;
            } elsif ( $new_gene_oid ne $gene_oid ) {
                $msg      = "Warning: Input Gene ID '$gene_oid' is mapped to '$new_gene_oid'.";
                $gene_oid = $new_gene_oid;
            }
        } else {
            $msg      = "Error: Gene ID must be an integer.";
            $hasError = 1;
        }
        if ($hasError) {

            # incorrect gene OID
            $row .= $gene_oid . $sd . $gene_oid . "\t";
        } else {

            # correct gene OID
            my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
            $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        }

        # annotated product_name
        my $product_name = $fld_vals{ lc('Annotated Product Name') };
        if ( blankStr($product_name) ) {
            $product_name = $fld_vals{'myimg_annotation'};
        }
        $row .= $product_name . $sd . WebUtil::escHtml($product_name) . "\t";
        if ( blankStr($product_name) ) {
            $msg .= "; " if ( !blankStr($msg) );
            $msg .= "Error: 'Annotated Product Name' cannot be blank.";
            $hasError = 1;
        }

        # prot_desc
        my $prot_desc = $fld_vals{ lc('Annotated Prot Desc') };
        if ( blankStr($prot_desc) ) {
            $prot_desc = $fld_vals{'myimg_prot_desc'};
        }
        $row .= $prot_desc . $sd . WebUtil::escHtml($prot_desc) . "\t";

        # ec_number
        my $ec_number = $fld_vals{ lc('Annotated EC Number') };
        if ( blankStr($ec_number) ) {
            $ec_number = $fld_vals{'myimg_ec_number'};
        }
        $row .= $ec_number . $sd . WebUtil::escHtml($ec_number) . "\t";
        my $res = DataEntryUtil::checkECNumber($ec_number);
        if ( !blankStr($res) ) {

            # has error
            $msg .= "; " if ( !blankStr($msg) );
            $msg .= "Error: $res.";
            $hasError = 1;
        }

        # pubmed_id
        my $pubmed_id = $fld_vals{ lc('Annotated PUBMED ID') };
        if ( blankStr($pubmed_id) ) {
            $pubmed_id = $fld_vals{'myimg_pubmed_id'};
        }
        $row .= $pubmed_id . $sd . WebUtil::escHtml($pubmed_id) . "\t";
        my $res = DataEntryUtil::checkPubmedId($pubmed_id);
        if ( !blankStr($res) ) {

            # has error
            $msg .= "; " if ( !blankStr($msg) );
            $msg .= "Error: $res.";
            $hasError = 1;
        }

        # inference
        my $inference = $fld_vals{ lc('Inference') };
        if ( blankStr($inference) ) {
            $inference = $fld_vals{'myimg_inference'};
        }
        $row .= $inference . $sd . WebUtil::escHtml($inference) . "\t";

        # is_pseudogene
        my $is_pseudogene = $fld_vals{ lc('Is Pseudo Gene?') };
        if ( blankStr($is_pseudogene) ) {
            $is_pseudogene = $fld_vals{'myimg_is_pseudogene'};
        }
        $row .= $is_pseudogene . $sd . WebUtil::escHtml($is_pseudogene) . "\t";
        if (   !blankStr($is_pseudogene)
            && lc($is_pseudogene) ne 'yes'
            && lc($is_pseudogene) ne 'no' )
        {
            $msg .= "; " if ( !blankStr($msg) );
            $msg .= "Error: 'Is Pseudo Gene?' value must be 'Yes' or 'No'.";
            $hasError = 1;
        }

        # notes
        my $notes = $fld_vals{ lc('Notes') };
        if ( blankStr($notes) ) {
            $notes = $fld_vals{'myimg_notes'};
        }
        $row .= $notes . $sd . WebUtil::escHtml($notes) . "\t";

        # gene symbol
        my $gene_symbol = $fld_vals{ lc('Annotated Gene Symbol') };
        if ( blankStr($gene_symbol) ) {
            $gene_symbol = $fld_vals{'myimg_gene_symbol'};
        }
        $row .= $gene_symbol . $sd . WebUtil::escHtml($gene_symbol) . "\t";

        # obsolete_flag
        my $obsolete_flag = $fld_vals{ lc('Remove Gene from Genome?') };
        if ( blankStr($obsolete_flag) ) {
            $obsolete_flag = $fld_vals{'myimg_obsolete_flag'};
        }
        $row .= $obsolete_flag . $sd . WebUtil::escHtml($obsolete_flag) . "\t";
        if (   !blankStr($obsolete_flag)
            && lc($obsolete_flag) ne 'yes'
            && lc($obsolete_flag) ne 'no' )
        {
            $msg .= "; " if ( !blankStr($msg) );
            $msg .= "Error: 'Remove Gene from Genome?' value must be 'Yes' or 'No'.";
            $hasError = 1;
        }

        # print message
        if ($hasError) {
            $row .= $msg . $sd . "<font color='red'>" . WebUtil::escHtml($msg) . "</font>\t";
        } else {
            $row .= $msg . $sd . WebUtil::escHtml($msg) . "\t";
        }

        $it->addRow($row);
    }    # end while line

    $it->printOuterTable(1);

    #$dbh->disconnect();
    close(FILE);
    if ( $hasError == 99 ) {
        WebUtil::webError($msg);
        print "<br/>\n";
        return;
    }
    print "<br/>\n";

    my $msg = "Done";
    if ( $line_no > $max_upload_line_count ) {
        $msg = "File is too large. Only $max_upload_line_count lines were processed.";
    }
    WebUtil::printStatusLine( $msg, 2 );

    ## buttons
    my $name = "_section_${section}_dbAnnotFileUpload";
    print submit(
        -name  => $name,
        -value => 'Upload',
        -class => 'smdefbutton'
    );
    print nbsp(1);
    my $name = "_section_${section}_index";
    print submit(
        -name  => $name,
        -value => 'Cancel',
        -class => 'smbutton'
    );

    print "</p>\n";
    print end_form();

}

############################################################################
# dbAnnotFileUpload - Actual upload into database
############################################################################
sub dbAnnotFileUpload {

    # check log in
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::printStatusLine( "Aborted", 2 );
        WebUtil::webError("You are not logged in.");
    }

    ## Get parameters.
    my $session         = param("section");
    my $tmp_upload_file = param("tmpAnnotUploadFile");

    # open file
    if ( !open( FILE, $tmp_upload_file ) ) {
        WebUtil::webError("Cannot open tmp file $tmp_upload_file.");
        return 0;
    }

    my $dbh = WebUtil::dbLogin();

    my $line_no = 0;
    my $line;

    my @fld_names = ();
    my $hasError  = 0;

    my @sqlList = ();
    my $sql     = "";

    my @taxons        = ();
    my $gene_oid_list = "";

    while ( $line = <FILE> ) {
        chomp($line);
        my @flds = split( /\t/, $line );
        $line_no++;

        if ( $line_no == 1 ) {

            # header line
            for my $s1 (@flds) {
                $s1 = WebUtil::strTrim($s1);
                if ( WebUtil::inArray_ignoreCase( $s1, @fld_names ) ) {
                    $hasError = 99;
                    last;
                }

                # save field name
                push @fld_names, ($s1);
            }
            last if ( $hasError == 99 );

            if (   WebUtil::inArray_ignoreCase( 'gene_oid', @fld_names ) == 0
                && WebUtil::inArray_ignoreCase( 'Gene OID', @fld_names ) == 0 )
            {
                $hasError = 99;
                last;
            }

            if (   WebUtil::inArray_ignoreCase( 'MyIMG_Annotation', @fld_names ) == 0
                && WebUtil::inArray_ignoreCase( 'Annotated Product Name', @fld_names ) == 0 )
            {
                $hasError = 99;
                last;
            }

            next;
        }

        # we don't want to process large files
        last if ( $line_no > $max_upload_line_count );

        # process this line
        $hasError = 0;
        my $gene_oid = "";
        my %fld_vals;

        my $j = 0;
        for my $fld_name (@fld_names) {

            # get field value
            last if ( $j >= scalar(@flds) );

            my $lc_fld_name = lc($fld_name);
            $fld_vals{$lc_fld_name} = WebUtil::strTrim( $flds[$j] );

            if ( $lc_fld_name eq 'gene_oid' || $lc_fld_name eq lc('Gene OID') ) {
                $gene_oid = $flds[$j];
            }

            # next
            $j++;
        }

        # check user input
        # check gene_oid
        if ( isInt($gene_oid) ) {
            require GeneCartDataEntry;
            my ( $found, $product, $new_gene_oid ) = GeneCartDataEntry::checkGeneOid( $dbh, $gene_oid );
            if ( !$found ) {
                $hasError = 1;
            } elsif ( $new_gene_oid ne $gene_oid ) {
                $gene_oid = $new_gene_oid;
            }
        } else {
            $hasError = 1;
        }

        # incorrect gene OID
        next if ($hasError);

        # product_name
        my $product_name = $fld_vals{ lc('Annotated Product Name') };
        if ( blankStr($product_name) ) {
            $product_name = $fld_vals{'myimg_annotation'};
        }

        next if ( blankStr($product_name) );

        if ( length($product_name) > 1000 ) {
            $product_name = substr( $product_name, 0, 1000 );
        }

        # prot_desc
        my $prot_desc = $fld_vals{ lc('Annotated Prot Desc') };
        if ( blankStr($prot_desc) ) {
            $prot_desc = $fld_vals{'myimg_prot_desc'};
        }
        if ( length($prot_desc) > 1000 ) {
            $prot_desc = substr( $prot_desc, 0, 1000 );
        }

        # ec_number
        my $ec_number = $fld_vals{ lc('Annotated EC Number') };
        if ( blankStr($ec_number) ) {
            $ec_number = $fld_vals{'myimg_ec_number'};
        }
        my $res = DataEntryUtil::checkECNumber($ec_number);
        if ( !blankStr($res) ) {
            next;
        }
        if ( length($ec_number) > 1000 ) {
            $ec_number = substr( $ec_number, 0, 1000 );
        }

        # pubmed_id
        my $pubmed_id = $fld_vals{ lc('Annotated PUBMED ID') };
        if ( blankStr($pubmed_id) ) {
            $pubmed_id = $fld_vals{'myimg_pubmed_id'};
        }
        my $res = DataEntryUtil::checkPubmedId($pubmed_id);
        if ( !blankStr($res) ) {
            next;
        }
        if ( length($pubmed_id) > 1000 ) {
            $pubmed_id = substr( $pubmed_id, 0, 1000 );
        }

        # inference
        my $inference = $fld_vals{ lc('Inference') };
        if ( blankStr($inference) ) {
            $inference = $fld_vals{'myimg_inference'};
        }
        if ( length($inference) > 500 ) {
            $inference = substr( $inference, 0, 500 );
        }

        # is_pseudogene
        my $is_pseudogene = $fld_vals{ lc('Is Pseudo Gene?') };
        if ( blankStr($is_pseudogene) ) {
            $is_pseudogene = $fld_vals{'myimg_is_pseudogene'};
        }
        if ( blankStr($is_pseudogene) ) {

            # null
        } elsif ( lc($is_pseudogene) eq 'yes' ) {
            $is_pseudogene = 'Yes';
        } elsif ( lc($is_pseudogene) eq 'no' ) {
            $is_pseudogene = 'No';
        } else {
            next;
        }

        # notes
        my $notes = $fld_vals{ lc('Notes') };
        if ( blankStr($notes) ) {
            $notes = $fld_vals{'myimg_notes'};
        }
        if ( length($notes) > 1000 ) {
            $notes = substr( $notes, 0, 1000 );
        }

        # gene_symbol
        my $gene_symbol = $fld_vals{ lc('Annotated Gene Symbol') };
        if ( blankStr($gene_symbol) ) {
            $gene_symbol = $fld_vals{'myimg_gene_symbol'};
        }
        if ( length($gene_symbol) > 100 ) {
            $notes = substr( $gene_symbol, 0, 100 );
        }

        # obsolete_flag
        my $obsolete_flag = $fld_vals{ lc('Remove Gene from Genome?') };
        if ( blankStr($obsolete_flag) ) {
            $obsolete_flag = $fld_vals{'myimg_obsolete_flag'};
        }
        if ( blankStr($obsolete_flag) ) {

            # null
        } elsif ( lc($obsolete_flag) eq 'yes' ) {
            $obsolete_flag = 'Yes';
        } elsif ( lc($obsolete_flag) eq 'no' ) {
            $obsolete_flag = 'No';
        } else {
            next;
        }

        # is_public
        my $is_public_flag = $fld_vals{ lc('Is Public?') };
        if ( blankStr($is_public_flag) ) {
            $is_public_flag = $fld_vals{'myimg_is_public'};
        }
        if ( blankStr($is_public_flag) ) {

            # null
        } elsif ( lc($is_public_flag) eq 'yes' ) {
            $is_public_flag = 'Yes';
        } elsif ( lc($is_public_flag) eq 'no' ) {
            $is_public_flag = 'No';
        } else {
            next;
        }

        # update MyIMG annotation for this gene
        $gene_oid_list .= "$gene_oid ";
        print WebUtil::hiddenVar( "gene_oid", $gene_oid );
        my $taxon_oid = DataEntryUtil::db_findVal( $dbh, 'GENE', 'gene_oid', $gene_oid, 'taxon', "" );
        if ( !WebUtil::inIntArray( $taxon_oid, @taxons ) ) {
            push @taxons, ($taxon_oid);
        }

        # generate SQL
        $sql = "delete from Gene_MyIMG_functions " . "where gene_oid = $gene_oid and modified_by = $contact_oid";
        push @sqlList, ($sql);

        $sql =
            "insert into Gene_MyIMG_functions "
          . "(gene_oid, product_name, prot_desc, ec_number, "
          . "pubmed_id, inference, is_pseudogene, notes, gene_symbol, "
          . "obsolete_flag, is_public, modified_by, mod_date) "
          . "values ($gene_oid, ";

        # product_name
        $product_name =~ s/'/''/g;    # replace ' with ''
        $sql .= "'$product_name', ";

        # prot_desc
        $prot_desc =~ s/'/''/g;       # replace ' with ''
        if ( blankStr($prot_desc) ) {
            $sql .= "null, ";
        } else {
            $sql .= "'$prot_desc', ";
        }

        # ec_number
        $ec_number =~ s/'/''/g;       # replace ' with ''
        if ( blankStr($ec_number) ) {
            $sql .= "null, ";
        } else {
            $sql .= "'$ec_number', ";
        }

        # pubmed_id
        $pubmed_id =~ s/'/''/g;       # replace ' with ''
        if ( blankStr($pubmed_id) ) {
            $sql .= "null, ";
        } else {
            $sql .= "'$pubmed_id', ";
        }

        # inference
        $inference =~ s/'/''/g;       # replace ' with ''
        if ( blankStr($prot_desc) ) {
            $sql .= "null, ";
        } else {
            $sql .= "'$inference', ";
        }

        # is_pseudogene
        $is_pseudogene =~ s/'/''/g;    # replace ' with ''
        if ( blankStr($is_pseudogene) ) {
            $sql .= "null, ";
        } else {
            $sql .= "'$is_pseudogene', ";
        }

        # notes
        $notes =~ s/'/''/g;            # replace ' with ''
        if ( blankStr($notes) ) {
            $sql .= "null, ";
        } else {
            $sql .= "'$notes', ";
        }

        # gene_symbol
        $gene_symbol =~ s/'/''/g;      # replace ' with ''
        if ( blankStr($gene_symbol) ) {
            $sql .= "null, ";
        } else {
            $sql .= "'$gene_symbol', ";
        }

        # obsolete_flag
        $obsolete_flag =~ s/'/''/g;    # replace ' with ''
        if ( blankStr($obsolete_flag) ) {
            $sql .= "null, ";
        } else {
            $sql .= "'$obsolete_flag', ";
        }

        # is_public_flag
        if ( lc($is_public_flag) eq 'yes' ) {
            $sql .= "'Yes', ";
        } else {
            $sql .= "'No', ";
        }

        # modified_by and mod_date
        $sql .= "$contact_oid, sysdate) ";
        push @sqlList, ($sql);

        ## insert into Gene_MyIMG_Enzymes
        $ec_number =~ s/;/ /g;    # replace ; with space
        my @ecs = split( / /, $ec_number );
        for my $ec1 (@ecs) {
            if ( db_findCount( $dbh, 'ENZYME', "ec_number = '$ec1'" ) > 0 ) {

                # insert
                $sql =
                    "insert into Gene_MyIMG_Enzymes "
                  . "(gene_oid, ec_number, modified_by, mod_date) "
                  . "values ($gene_oid, '$ec1', $contact_oid, sysdate)";
                push @sqlList, ($sql);
            }
        }
    }

    if ( $hasError == 99 ) {

        # stop processing
        #$dbh->disconnect();
        close(FILE);
        return;
    }

    #$dbh->disconnect();
    close(FILE);

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        WebUtil::webError("SQL Error: $sql");
        return "";
    }

    # recompute statistics for taxon_stats
    my $dbh = WebUtil::dbLogin();
    for my $k (@taxons) {
        updateTaxonAnnStatistics( $dbh, $k );
    }

    #$dbh->disconnect();

    return strTrim($gene_oid_list);
}

############################################################################
# uploadAnnotationFile - Process handling of uploading the gene annotation
#   file.
############################################################################
sub uploadAnnotationFile {
    print start_multipart_form(
        -name   => "uploadAnnotationForm",
        -action => "$section_cgi"
    );
    print "<h1>Upload Annotation File</h1>\n";

    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::printStatusLine( "Aborted", 2 );
        WebUtil::webError("You are not logged in.");
    }

    my $fh = upload("uploadFile");
    if ( $fh && cgi_error() ) {
        WebUtil::webError( header( -status => cgi_error() ) );
    }

    # Need line broken buffer through tmpFile.
    my $tmpFile   = "$cgi_tmp_dir/upload$$.tab.txt";
    my $wfh       = newWriteFileHandle( $tmpFile, "uploadAnnotationFile" );
    my $file_size = 0;
    while ( my $s = <$fh> ) {
        $s =~ s/\r/\n/g;
        $file_size += length($s);
        if ( $file_size > $max_upload_size ) {
            WebUtil::webError("Maximum file size $max_upload_size bytes exceeded.");
            close $wfh;
            wunlink($tmpFile);
            return 0;
        }
        print $wfh $s;
    }
    close $wfh;
    if ( $file_size == 0 ) {
        close $wfh;
        wunlink($tmpFile);
        WebUtil::webError("No contents were found to upload.");
        return 0;
    }

    my $rfh = newReadFileHandle( $tmpFile, "uploadAnnotationFile" );
    my $s = $rfh->getline();
    chomp $s;
    my (@fields) = split( /\t/, $s );
    my $nFields = @fields;
    my $gene_oid_idx        = -1;
    my $myIMGAnnotation_idx = -1;
    for ( my $i = 0 ; $i < $nFields ; $i++ ) {
        my $fieldName = $fields[$i];
        if ( $fieldName eq "gene_oid" ) {
            $gene_oid_idx = $i;
        } elsif ( $fieldName eq "MyIMG_Annotation" ) {
            $myIMGAnnotation_idx = $i;
        }
    }
    if ( $gene_oid_idx < 0 ) {
        wunlink($tmpFile);
        WebUtil::printStatusLine( "Aborted", 2 );
        ## --es 05/05/2005 Better error message.
        my $x = $tabDelimErrMsg;
        WebUtil::webError( "The file requires a column header with the keyword " . "'gene_oid'. $x\n" );
    }
    if ( $myIMGAnnotation_idx < 0 ) {
        wunlink($tmpFile);
        WebUtil::printStatusLine( "Aborted", 2 );
        ## --es 05/05/2005 Better error message.
        my $x = $tabDelimErrMsg;
        WebUtil::webError( "The file requires a column header with the keyword " . "'MyIMG_Annotation'. $x\n" );
    }
    WebUtil::printStatusLine( "Loading ...", 1 );

    my $dbh = WebUtil::dbLogin();
    my $sql = qq{
	    select max( annot_oid )
	    from annotation
	};
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($annot_oid) = $cur->fetchrow();
    $cur->finish();
    $annot_oid++;
    WebUtil::webLog "next annot_oid=$annot_oid\n" if $verbose >= 1;
    print "<p>\n";
    my $count = 0;

    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my (@vals) = split( /\t/, $s );
        my $gene_oid        = $vals[$gene_oid_idx];
        my $myIMGAnnotation = $vals[$myIMGAnnotation_idx];
        if ( $myIMGAnnotation =~ /^".*"$/ ) {
            $myIMGAnnotation =~ s/^"//;
            $myIMGAnnotation =~ s/"$//;
        }
        next if blankStr($gene_oid);
        next if blankStr($myIMGAnnotation);
        if ( !updateAnnotation( $dbh, $contact_oid, $gene_oid, $myIMGAnnotation, $annot_oid ) ) {
            next;
        }
        $annot_oid++;
        $count++;
    }
    close $rfh;
    updateAnnStatistics($dbh);
    print "<br/>\n";
    print "$count gene(s) annotated.\n";
    print "</p>\n";

    #$dbh->disconnect();
    wunlink($tmpFile);
    WebUtil::printStatusLine( "$count gene(s) annotated", 2 );
    print WebUtil::hiddenVar( "page", "myIMG" );
    print WebUtil::hiddenVar( "form", "uploadGeneAnnotations" );
    print end_form();
}

############################################################################
# updateAnnotation - Do actual of updating one annotation on a gene.
############################################################################
sub updateAnnotation {
    my ( $dbh, $contact_oid, $gene_oid, $myIMGAnnotation, $annot_oid ) = @_;
    $myIMGAnnotation =~ s/\s+/ /g;
    $myIMGAnnotation =~ s/'/''/g;

    checkGenePerm( $dbh, $gene_oid );

    my $taxon_oid = geneOid2TaxonOid( $dbh, $gene_oid );

    ## --es 05/05/2005 Avoid Oracle hard limit for SQL statement for
    ## insert text length. Use a reasonable lower limit.
    my $len = length($myIMGAnnotation);
    if ( $len > $max_annotation_size ) {
        print "<font color='red'>\n";
        print "Skipping gene_oid='$gene_oid'. ";
        print "Annotation '$myIMGAnnotation' is too long (length=$len).\n";
        print "Please try again with text < $max_annotation_size characters.\n";
        print "</font>\n";
        print "<br/>\n";
        return 0;
    }
    ## --es 05/05/2005 more checks for garbage.
    if ( $gene_oid <= 0 || !$taxon_oid ) {
        print "<font color='red'>\n";
        print "Invalid gene_oid='$gene_oid'.  Skipping ...\n";
        print "</font>\n";
        print "<br/>\n";
        return 0;
    }
    ## --es 05/05/2005 Check for valid gene_oid
    my $gene_oid2 = geneOidMap( $dbh, $gene_oid );
    if ( $gene_oid2 eq "" ) {
        print "<font color='red'>\n";
        print "gene_oid='$gene_oid' not found in system.  Skipping ...\n";
        print "</font>\n";
        print "<br/>\n";
        return 0;
    }

    ## --es 05/05/2005 Enforce limit on annotations per gene per user.
    if ( $rdbms eq "oracle" ) {
        my $cur = execSql( $dbh, "set transaction read write", $verbose );
        $cur->finish();
    }

    ## Implement update with replacement policy.
    #  Delete old annotations first.
    my $sql = qq{
       select ann.annot_oid
       from annotation ann, annotation_genes ag
       where ann.author = ?
       and ag.annot_oid = ann.annot_oid
       and ag.genes = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $gene_oid );
    my @deleteAnnotOids;
    for ( ; ; ) {
        my ($annot_oid) = $cur->fetchrow();
        last if !$annot_oid;
        push( @deleteAnnotOids, $annot_oid );
    }
    $cur->finish();
    for my $annot_oid (@deleteAnnotOids) {
        my $sql = qq{
          delete from annotation_genes
          where annot_oid = ?
          and genes = ?
      };
        my $cur = execSql( $dbh, $sql, $verbose, $annot_oid, $gene_oid );
        $cur->finish();
        my $cur = execSql( $dbh, "delete from annotation where annot_oid = ?", $verbose, $annot_oid );
        $cur->finish();
    }

    my $x = WebUtil::escHtml($myIMGAnnotation);
    print "Update gene_oid=$gene_oid with '$x'";
    print "<br/>\n";

    my $sql_mysql = qq{
      insert into annotation( annot_oid, annotation_text, author, add_date )
      values( $annot_oid, ?, $contact_oid, sysdate() )
   };
    my $sql_oracle = qq{
      insert into annotation( annot_oid, annotation_text, author, add_date )
      values( $annot_oid, ?, $contact_oid, sysdate )
   };
    my $sql;
    $sql = $sql_mysql  if $rdbms eq "mysql";
    $sql = $sql_oracle if $rdbms eq "oracle";
    my $cur = prepSql( $dbh, $sql, $verbose );
    execStmt( $cur, $myIMGAnnotation );
    $cur->finish();

    #my $cur = execSql( $dbh, $sql, $verbose );
    #$cur->finish( );

    my $sql = qq{
      insert into annotation_genes( annot_oid, genes )
      values( ?, ? )
   };
    my $cur = execSql( $dbh, $sql, $verbose, $annot_oid, $gene_oid );
    $cur->finish();

    if ( $rdbms eq "oracle" ) {
        my $cur = execSql( $dbh, "commit work", $verbose );
        $cur->finish();
    }

    return 1;
}

############################################################################
# updateAnnStatistics - Update community annotation statistics
############################################################################
sub updateAnnStatistics {
    my ($dbh) = @_;

    print "<br/>\n";
    print "Updating statistics\n";
    print "<br/>\n";

    # Revised to avoid oracle redo log and possible locking.
    #my $cur = execSql( $dbh, $sql, $verbose );
    #$cur->finish( );
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
		select g.taxon, count( distinct g.gene_oid )
		from gene g, annotation_genes ag
		where g.gene_oid = ag.genes
		    $rclause
		    $imgClause
		    and g.obsolete_flag = 'No'
		group by g.taxon
		order by g.taxon
	};
    my $cur = execSql( $dbh, $sql, $verbose );
    my @recs;
    for ( ; ; ) {
        my ( $taxon, $cnt ) = $cur->fetchrow();
        last if !$taxon;
        my $rec = "$taxon\t";
        $rec .= "$cnt";
        push( @recs, $rec );
    }
    $cur->finish();
    my $sql = qq{
       update taxon_stats set genes_in_myimg = 0
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();
    for my $r (@recs) {
        my ( $taxon, $cnt ) = split( /\t/, $r );
        my $sql = "update taxon_stats set genes_in_myimg = ? ";
        $sql .= "where taxon_oid = ? ";
        my $cur = execSql( $dbh, $sql, $verbose, $cnt, $taxon );
        $cur->finish();

        #my $cur = execSql( $dbh, "commit work", 0 );
        #$cur->finish( );
    }
    my $sql = qq{
       update taxon_stats dgs
         set genes_in_myimg_pc = 
	     genes_in_myimg / total_gene_count * 100
         where total_gene_count > 0
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();
}

############################################################################
# updateTaxonAnnStatistics - Update community annotation statistics
#                            for a particular taxon only
############################################################################
sub updateTaxonAnnStatistics {
    my ( $dbh, $taxon_oid ) = @_;

    # Revised to avoid oracle redo log and possible locking.
    #my $cur = execSql( $dbh, $sql, $verbose );
    #$cur->finish( );
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select count ( distinct g.gene_oid )
	from gene g, gene_myimg_functions gmf
	where g.gene_oid = gmf.gene_oid
	$rclause
	$imgClause
	and g.obsolete_flag = 'No'
	and g.taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $cnt = 0;
    for ( ; ; ) {
        my ($v1) = $cur->fetchrow();
        last if !$v1;
        $cnt = $v1;
    }
    $cur->finish();

    my $sql = "update taxon_stats set genes_in_myimg = ? ";
    $sql .= "where taxon_oid = ? ";
    my $cur = execSql( $dbh, $sql, $verbose, $cnt, $taxon_oid );
    $cur->finish();

    my $sql = qq{
       update taxon_stats dgs
         set genes_in_myimg_pc = 
	     genes_in_myimg / total_gene_count * 100
         where taxon_oid = $taxon_oid and total_gene_count > 0
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();
}

############################################################################
# printViewMyAnnotationsForm - Print the form for "view my annotations".
############################################################################
sub printViewMyAnnotationsForm {
    print start_form(
        -name   => "viewAnnotationsForm",
        -action => $section_cgi
    );

    my @groups = DataEntryUtil::db_getImgGroups($contact_oid);
    if ( scalar(@groups) > 0 ) {
        WebUtil::printHint(
"IMG users can now create their own annotation groups and participate in multiple annotation groups. They can also selectively share their MyIMG annotations to certain annotation groups only. Please pay attention to the group sharing options of your MyIMG and Missing Gene annotations."
        );
    }

    print pageAnchor("View Annotations");
    print qq{
        <h3>View Annotations</h3>\n
        <p>\n
        <input type='radio' name='view_type' value='all' checked />
        View all annotations<br/>\n
        <input type='radio' name='view_type' value='genome' />
        View annotations by genomes<br/>\n
        <input type='radio' name='view_type' value='cart' />
        View annotations for all genes in gene cart\n
        </p>\n
    };

    # print WebUtil::hiddenVar( "form", "uploadGeneAnnotations" );
    my $name = "_section_${section}_viewMyAnnotations";
    print submit(
        -name  => $name,
        -value => "View My Annotations",
        -class => 'meddefbutton'
    );

    # group annotations
    my $contact_oid = WebUtil::getContactOid();
    if ( scalar(@groups) > 0 ) {
        print nbsp(2);
        my $name = "_section_${section}_viewGroupAnnotations";
        print submit(
            -name  => $name,
            -value => "View Group Annotations",
            -class => 'medbutton'
        );
    }

    my $super_user_flag = "";
    if ( $contact_oid > 0 ) {
        $super_user_flag = getSuperUser();
    }

    if ( $super_user_flag eq 'Yes' ) {

        # super user can view all
        print nbsp(2);
        my $name = "_section_${section}_viewAllUserAnnotations";
        print submit(
            -name  => $name,
            -value => "View Annotations by All Users",
            -class => 'medbutton'
        );
    }

    print "<h3>Upload Annotations from File</h3>\n";
    print "<p>Upload your own annotations from a tab-delimited file.</p>\n";
    my $name = "_section_${section}_uploadAnnotations";
    print submit(
        -name  => $name,
        -value => "Upload Annotations",
        -class => 'medbutton'
    );

    if ($show_mygene) {
        print "<h3>View Missing Gene Annotations</h3>\n";
        if ( $super_user_flag eq 'Yes' ) {
            print "<p>View all missing gene annotations in IMG.\n";
        } elsif ( scalar(@groups) > 0 ) {
            print "<p>View my missing gene annotations and group missing gene annotations.\n";
        } else {
            print "<p>View my missing gene annotations in IMG.\n";
        }
        print "<p>\n";

        my $name = "_section_${section}_viewMyMissingGenes";
        print submit(
            -name  => $name,
            -value => "View My Missing Genes",
            -class => 'meddefbutton'
        );

        if ( scalar(@groups) > 0 ) {
            print nbsp(2);
            my $name = "_section_${section}_viewGroupMissingGenes";
            print submit(
                -name  => $name,
                -value => "View Group Missing Genes",
                -class => 'medbutton'
            );
        }

        if ( $super_user_flag eq 'Yes' ) {
            print nbsp(2);
            my $name = "_section_${section}_viewAllMissingGenes";
            print submit(
                -name  => $name,
                -value => "View All Missing Genes",
                -class => 'medbutton'
            );
        }
    }

    print end_form();
}

############################################################################
# printViewMyAnnotationResults - Show results from ViewMyAnnotationForm
#   submit button.
############################################################################
sub printViewMyAnnotationResults {
    my ($gene_oid_list) = @_;

    WebUtil::printMainForm();

    # get contact_oid
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }
    my $super_user_flag = getSuperUser();
    my @my_groups       = DataEntryUtil::db_getImgGroups($contact_oid);

    my $user_id     = param('user_id');
    my @user_groups = ();
    if ( $user_id && isInt($user_id) ) {
        @user_groups = DataEntryUtil::db_getImgGroups($user_id);
    }

    if ( blankStr($user_id) ) {
        $user_id = $contact_oid;
    } else {

        # save user id as hidden param
        print WebUtil::hiddenVar( "user_id", $user_id );
    }

    print WebUtil::hiddenVar( 'source_page', 'viewMyAnnotations' );

    my @taxon_oids = param('taxon_oid');
    if ( scalar(@taxon_oids) > 100 ) {
        WebUtil::webError("You cannot select more than 100 genomes.");
    }

    my @gene_oids = ();
    if ( !blankStr($gene_oid_list) ) {
        @gene_oids = split( / /, $gene_oid_list );
    } else {
        @gene_oids = param('gene_oid');
    }

    my $dbh = WebUtil::dbLogin();

    my $is_my_annot = 0;
    my $rclause     = "";
    if ( $user_id == $contact_oid ) {
        $is_my_annot = 1;
        print "<h2>My Annotations</h2>\n";
    } else {
        if (
            $super_user_flag ne 'Yes'
            && (   scalar(@my_groups) == 0
                || scalar(@user_groups) == 0
                || scalar( groupIntersections( \@my_groups, \@user_groups ) ) == 0 )
          )
        {
            WebUtil::webError("You cannot view MyIMG annotations by this user.");
        }

        my $u_name = DataEntryUtil::db_findVal( $dbh, 'CONTACT', 'contact_oid', $user_id, 'username', "" );
        print "<h2>Annotations by User " . escapeHTML($u_name) . "</h2>\n";
        $rclause = WebUtil::urClause('tx');
    }

    if ( scalar(@taxon_oids) == 1 ) {
        my $taxon_oid = $taxon_oids[0];
        my $taxon_name = DataEntryUtil::db_findVal( $dbh, 'TAXON', 'taxon_oid', $taxon_oid, 'taxon_name', "" );
        print "<h3>Genome $taxon_oid: " . escapeHTML($taxon_name) . "</h3>\n";
    }

    my $taxon_cond = "";
    if ( scalar(@taxon_oids) > 0 ) {
        for my $taxon_oid (@taxon_oids) {
            if ( blankStr($taxon_cond) ) {
                $taxon_cond = " and g.taxon in ( $taxon_oid ";
            } else {
                $taxon_cond .= ", $taxon_oid";
            }
        }

        $taxon_cond .= ") ";
    }

    WebUtil::printStatusLine( "Loading ...", 1 );

    if ( paramMatch("removeMyAnnotations") ne "" ) {
        deleteMyAnnotations();
    }
    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    my $annSortAttr = param("annSortAttr");
    my $sortClause  = " order by tx.taxon_display_name, g.gene_oid";
    $sortClause = " order by ann.mod_date desc, g.gene_oid"
      if $annSortAttr eq "add_date";
    $sortClause = " order by to_char( g.product_name )"
      if $annSortAttr eq "gene_product_name";
    $sortClause = " order by to_char( ann.product_name )"
      if $annSortAttr eq "product_name";
    $sortClause = " order by g.gene_oid"
      if $annSortAttr eq "gene_oid";
    $sortClause = " order by ann.annot_oid"
      if $annSortAttr eq "annot_oid";
    $sortClause = " order by ann.prot_desc"
      if $annSortAttr eq "prot_desc";
    $sortClause = " order by ann.ec_number"
      if $annSortAttr eq "ec_number";
    $sortClause = " order by ann.pubmed_id"
      if $annSortAttr eq "pubmed_id";
    $sortClause = " order by ann.inference"
      if $annSortAttr eq "inference";
    $sortClause = " order by ann.is_pseudogene"
      if $annSortAttr eq "is_pseudogene";
    $sortClause = " order by ann.notes"
      if $annSortAttr eq "notes";
    $sortClause = " order by ann.gene_symbol"
      if $annSortAttr eq "gene_symbol";
    $sortClause = " order by ann.obsolete_flag"
      if $annSortAttr eq "obsolete_flag";
    $sortClause = " order by ann.is_public"
      if $annSortAttr eq "is_public";

    my $imgClause = WebUtil::imgClause('tx');
    my $sql_part1 = qq{
                select ann.gene_oid, g.gene_oid, 
                    ann.product_name, ann.prot_desc, ann.ec_number,
                    ann.pubmed_id, ann.inference, ann.is_pseudogene,
                    ann.notes, ann.gene_symbol, ann.obsolete_flag,
                    g.product_name, tx.taxon_display_name, ann.is_public, 
	};
    my $sql_part2 = qq{
                from gene g, taxon tx, gene_myimg_functions ann
                where g.gene_oid = ann.gene_oid
                    and g.taxon = tx.taxon_oid
                    and ann.modified_by = ?
                    and g.obsolete_flag = 'No' 
                    $rclause
                    $imgClause
                    $taxon_cond
                $sortClause
	};
    my $sql_mysql = qq{
		$sql_part1
		date_format( ann.mod_date, '%d-%m-%Y %k:%i:%s' )
                $sql_part2
	};
    my $sql_oracle = qq{
		$sql_part1		    
		to_char( ann.mod_date, 'yyyy-mm-dd HH24:MI:SS' )
		$sql_part2
	};
    my $sql;
    $sql = $sql_mysql  if $rdbms eq "mysql";
    $sql = $sql_oracle if $rdbms eq "oracle";
    my $cur = execSql( $dbh, $sql, $verbose, $user_id );
    my @recs;
    my $count = 0;
    my $trunc = 0;

    for ( ; ; ) {
        my (
            $annot_oid,     $gene_oid,          $annotation_text,    $prot_desc, $ec_number,
            $pubmed_id,     $inference,         $is_pseudogene,      $notes,     $gene_symbol,
            $obsolete_flag, $gene_product_name, $taxon_display_name, $is_public, $add_date
          )
          = $cur->fetchrow();
        last if !$annot_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        my $rec = "$annot_oid\t";
        $rec .= "$gene_oid\t";
        $annotation_text =~ s/\t\r/ /g;
        $rec .= "$annotation_text\t";
        $prot_desc =~ s/\t\r/ /g;
        $rec .= "$prot_desc\t";
        $ec_number =~ s/\t\r/ /g;
        $rec .= "$ec_number\t";
        $pubmed_id =~ s/\t\r/ /g;
        $rec .= "$pubmed_id\t";
        $inference =~ s/\t\r/ /g;
        $rec .= "$inference\t";
        $rec .= "$is_pseudogene\t";
        $notes =~ s/\t\r/ /g;
        $rec .= "$notes\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$obsolete_flag\t";
        $rec .= "$gene_product_name\t";
        $rec .= "$taxon_display_name\t";
        $rec .= "$is_public\t";
        $rec .= "$add_date";
        push( @recs, $rec );
    }
    $cur->finish();
    my $nRecs = @recs;
    if ( $nRecs == 0 ) {
        print "<p>0 genes retrieved</p>\n";
        WebUtil::printStatusLine( "0 genes retrieved", 2 );

        #$dbh->disconnect();
        return;
    }
    printAnnotFooter( $is_my_annot, $is_my_annot );
    print "<p>\n";
    print "Click on column name to sort.\n";
    print "</p>\n";

    my $it = new InnerTable( 1, "MyAnnotations$$", "MyAnnotations", 2 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",                  "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Genome",                   "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Original Product Name",    "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated Product Name",   "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated Prot Desc",      "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated EC Number",      "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated PUBMED ID",      "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Inference",                "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Is Pseudo Gene?",          "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Notes",                    "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated Gene Symbol",    "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Remove Gene from Genome?", "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Is Public?",               "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Last Modified Date",       "char desc", "left", "", "", "wrap" );
    $it->addColSpec( "IMG Term Count", "char asc", "left" );

    for my $r (@recs) {
        my (
            $annot_oid,     $gene_oid,          $annotation_text,    $prot_desc, $ec_number,
            $pubmed_id,     $inference,         $is_pseudogene,      $notes,     $gene_symbol,
            $obsolete_flag, $gene_product_name, $taxon_display_name, $is_public, $add_date
          )
          = split( /\t/, $r );
        my $row = $sd . "<input type='checkbox' name='gene_oid' value='$annot_oid' ";
        if ( WebUtil::inIntArray( $gene_oid, @gene_oids ) ) {
            $row .= " checked ";
        }
        $row .= "/>\t";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $row .= WebUtil::escHtml($taxon_display_name) . $sd . WebUtil::escHtml($taxon_display_name) . "\t";
        $row .= WebUtil::escHtml($gene_product_name) . $sd . WebUtil::escHtml($gene_product_name) . "\t";
        $row .= WebUtil::escHtml($annotation_text) . $sd . WebUtil::escHtml($annotation_text) . "\t";
        $row .= WebUtil::escHtml($prot_desc) . $sd . WebUtil::escHtml($prot_desc) . "\t";
        $row .= WebUtil::escHtml($ec_number) . $sd . WebUtil::escHtml($ec_number) . "\t";
        $row .= WebUtil::escHtml($pubmed_id) . $sd . WebUtil::escHtml($pubmed_id) . "\t";
        $row .= WebUtil::escHtml($inference) . $sd . WebUtil::escHtml($inference) . "\t";
        $row .= WebUtil::escHtml($is_pseudogene) . $sd . WebUtil::escHtml($is_pseudogene) . "\t";
        $row .= WebUtil::escHtml($notes) . $sd . WebUtil::escHtml($notes) . "\t";
        $row .= WebUtil::escHtml($gene_symbol) . $sd . WebUtil::escHtml($gene_symbol) . "\t";
        $row .= WebUtil::escHtml($obsolete_flag) . $sd . WebUtil::escHtml($obsolete_flag) . "\t";
        $row .= WebUtil::escHtml($is_public) . $sd . WebUtil::escHtml($is_public) . "\t";
        $row .= WebUtil::escHtml($add_date) . $sd . WebUtil::escHtml($add_date) . "\t";

        my $count1 = DataEntryUtil::db_findCount( $dbh, "gene_img_functions", "gene_oid = ?", $gene_oid );
        my @a2 = ( $gene_oid, $contact_oid );
        my $count2 = DataEntryUtil::db_findCount( $dbh, "gene_myimg_terms", "gene_oid = ? and modified_by = ?", @a2 );
        my $count_txt = "Original: $count1 / Annotated: $count2";
        $row .= $count_txt . $sd . $count_txt . "\t";

        $it->addRow($row);
    }

    $it->printOuterTable(1);
    print WebUtil::hiddenVar( "page", "myIMG" );
    printAnnotFooter( $is_my_annot, $is_my_annot ) if $nRecs > 10;
    $cur->finish();
    if ( !$trunc ) {
        WebUtil::printStatusLine( "$nRecs genes retrieved", 2 );
    } else {
        WebUtil::printTruncatedStatus($maxGeneListResults);
    }

    #$dbh->disconnect();
    print end_form();
}

sub groupIntersections {
    my ( $grp1, $grp2 ) = @_;

    my %all_groups;
    for my $g1 (@$grp1) {
        $all_groups{$g1} = 1;
    }
    for my $g2 (@$grp2) {
        if ( $all_groups{$g2} ) {
            $all_groups{$g2} += 1;
        } else {
            $all_groups{$g2} = 1;
        }
    }

    my @intersect = ();
    for my $k ( keys %all_groups ) {
        if ( $all_groups{$k} > 1 ) {
            push @intersect, ($k);
        }
    }

    return @intersect;
}

############################################################################
# printViewOneTaxonGroupAnnot - group annotations on one taxon
############################################################################
sub printViewOneTaxonGroupAnnot {
    WebUtil::printMainForm();

    # get contact_oid
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }

    my @my_groups = DataEntryUtil::db_getImgGroups($contact_oid);
    if ( scalar(@my_groups) == 0 ) {
        WebUtil::webError("You do not belong to any IMG group.");
        return;
    }

    my $taxon_oid = param('taxon_oid');
    if ( blankStr($taxon_oid) ) {
        WebUtil::webError("No genome has been selected.");
        return;
    } else {

        # save taxon_oid as hidden param
        print WebUtil::hiddenVar( "taxon_oid", $taxon_oid );
    }

    my $dbh = WebUtil::dbLogin();

    my $user_id     = param('user_id');
    my @user_groups = ();
    if ( $user_id && isInt($user_id) ) {
        @user_groups = DataEntryUtil::db_getImgGroups($user_id);
        if ( scalar( groupIntersections( \@my_groups, \@user_groups ) ) == 0 ) {
            WebUtil::webError("You cannot view MyIMG annotations by this user.");
        }
    }

    my $u_name = "";
    if ( !blankStr($user_id) ) {
        $u_name = DataEntryUtil::db_findVal( $dbh, 'CONTACT', 'contact_oid', $user_id, 'username', "" );
    }
    my $user_cond = "";

    my $taxon_name = DataEntryUtil::db_findVal( $dbh, 'TAXON', 'taxon_oid', $taxon_oid, 'taxon_name', "" );
    if ( blankStr($u_name) ) {
        print "<h2>View Group Annotations</h2>\n";
    } else {
        if ( $user_id == $contact_oid ) {
            print "<h2>View My Annotations</h2>\n";
        } else {
            print "<h2>View Annotations by User $u_name</h2>\n";
        }

        if ( !blankStr($user_id) ) {
            $user_cond = " and ann.modified_by = $user_id ";
        }
    }
    print "<h3>Genome $taxon_oid: " . escapeHTML($taxon_name) . "</h3>\n";

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    WebUtil::printStatusLine( "Loading ...", 1 );

    printAnnotFooter( 0, 0 );

    my $it = new InnerTable( 1, "GrpAnnotations$$", "GrpAnnotationis", 2 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",               "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Original Product Name", "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "User ID",               "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated Prot Name",   "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated EC Number",   "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated PUBMED ID",   "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Inference",             "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Is Pseudo Gene?",       "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Notes",                 "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated Gene Symbol", "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Last Modified Date",    "char desc", "left", "", "", "wrap" );

    my $grp      = $my_groups[0];
    my $grp_cond = " and c.img_group = $grp";

    my $dbh        = WebUtil::dbLogin();
    my $sortClause = " order by g.gene_oid, c.username";
    my $rclause    = WebUtil::urClause('g.taxon');
    my $imgClause  = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql_part1  = qq{
		select c.username, g.gene_oid, 
		    ann.product_name, ann.ec_number,
		    ann.pubmed_id, ann.inference, ann.is_pseudogene,
		    ann.notes, ann.gene_symbol, ann.obsolete_flag,
		    g.product_name,
	};
    my $sql_part2 = qq{
		from gene g, gene_myimg_functions ann, contact c
		where g.gene_oid = ann.gene_oid
		    and g.taxon = ?
		    and g.obsolete_flag = 'No'
		    and ann.modified_by = c.contact_oid
                    $rclause
                    $imgClause
		    $grp_cond
		    $user_cond
		$sortClause
	};

    my $sql;
    if ( $rdbms eq "mysql" ) {
        $sql = qq{
		$sql_part1
		date_format( ann.mod_date, '%d-%m-%Y %k:%i:%s' )
		$sql_part2
	};
    } elsif ( $rdbms eq "oracle" ) {
        $sql = qq{
		$sql_part1
		to_char( ann.mod_date, 'yyyy-mm-dd HH24:MI:SS' )
		$sql_part2
	};
    }

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $count         = 0;
    my $trunc         = 0;
    my $prev_gene_oid = 0;

    for ( ; ; ) {
        my (
            $modified_by,   $gene_oid, $annotation_text, $ec_number,     $pubmed_id,         $inference,
            $is_pseudogene, $notes,    $gene_symbol,     $obsolete_flag, $gene_product_name, $add_date
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        my $annot_oid = $gene_oid;
        my $row;
        if ( $gene_oid == $prev_gene_oid ) {

            # annotation on same gene
            $row = $sd . "<input type='checkbox' name='gene_oid' value='$annot_oid' disabled/>\t";
            $row .= $gene_oid . $sd . "<font color='magenta'>$gene_oid</font>\t";
        } else {
            $count++;
            if ( $count > $maxGeneListResults ) {
                $trunc = 1;
                last;
            }

            my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
            $row = $sd . "<input type='checkbox' name='gene_oid' value='$annot_oid' />\t";
            $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";

        }

        $row .= WebUtil::escHtml($gene_product_name) . $sd . WebUtil::escHtml($gene_product_name) . "\t";
        $row .= WebUtil::escHtml($modified_by) . $sd . WebUtil::escHtml($modified_by) . "\t";
        $row .= WebUtil::escHtml($annotation_text) . $sd . WebUtil::escHtml($annotation_text) . "\t";
        $row .= WebUtil::escHtml($ec_number) . $sd . WebUtil::escHtml($ec_number) . "\t";
        $row .= WebUtil::escHtml($pubmed_id) . $sd . WebUtil::escHtml($pubmed_id) . "\t";
        $row .= WebUtil::escHtml($inference) . $sd . WebUtil::escHtml($inference) . "\t";
        $row .= WebUtil::escHtml($is_pseudogene) . $sd . WebUtil::escHtml($is_pseudogene) . "\t";
        $row .= WebUtil::escHtml($notes) . $sd . WebUtil::escHtml($notes) . "\t";
        $row .= WebUtil::escHtml($gene_symbol) . $sd . WebUtil::escHtml($gene_symbol) . "\t";
        $row .= WebUtil::escHtml($add_date) . $sd . WebUtil::escHtml($add_date) . "\t";

        $prev_gene_oid = $gene_oid;
        $it->addRow($row);
    }

    $it->printOuterTable(1);

    $cur->finish();

    print WebUtil::hiddenVar( "page", "myIMG" );
    printAnnotFooter( 0, 0 ) if $count > 10;

    if ( !$trunc ) {
        WebUtil::printStatusLine( "$count genes retrieved", 2 );
    } else {
        printTruncatedStatus($maxGeneListResults);
    }

    #$dbh->disconnect();

    print end_form();
}

############################################################################
# printViewOneTaxonAnnot - annotations on one taxon
############################################################################
sub printViewOneTaxonAnnot {
    WebUtil::printMainForm();

    # get contact_oid
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }
    my $super_user_flag = getSuperUser();
    my @my_groups       = DataEntryUtil::db_getImgGroups($contact_oid);

    my $taxon_oid = param('taxon_oid');
    if ( blankStr($taxon_oid) ) {
        WebUtil::webError("No genome has been selected.");
        return;
    } else {

        # save taxon_oid as hidden param
        print WebUtil::hiddenVar( "taxon_oid", $taxon_oid );
    }

    my $dbh = WebUtil::dbLogin();

    my $user_id     = param('user_id');
    my @user_groups = ();
    if ( $user_id && isInt($user_id) ) {
        @user_groups = DataEntryUtil::db_getImgGroups($user_id);
    }
    my $u_name = "";
    if ( !blankStr($user_id) ) {
        $u_name = DataEntryUtil::db_findVal( $dbh, 'CONTACT', 'contact_oid', $user_id, 'username', "" );
    }
    my $user_cond = "";

    my $taxon_name = DataEntryUtil::db_findVal( $dbh, 'TAXON', 'taxon_oid', $taxon_oid, 'taxon_name', "" );
    if ( blankStr($u_name) ) {
        print "<h2>View Annotations</h2>\n";

        if ( $super_user_flag ne 'Yes' ) {
            WebUtil::webError("You cannot view MyIMG annotations by all users.");
        }
    } else {
        if (   $super_user_flag eq 'Yes'
            || $contact_oid == $user_id
            || groupIntersections( \@my_groups, \@user_groups ) > 0 )
        {

            # you can view
            if ( $user_id == $contact_oid ) {
                print "<h2>View My Annotations</h2>\n";
            } else {
                print "<h2>View Annotations by User $u_name</h2>\n";
            }
            if ( !blankStr($user_id) ) {
                $user_cond = " and ann.modified_by = $user_id ";
            }
        } else {
            WebUtil::webError("You cannot view MyIMG annotations by this user.");
        }
    }
    print "<h3>Genome $taxon_oid: " . escapeHTML($taxon_name) . "</h3>\n";

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    WebUtil::printStatusLine( "Loading ...", 1 );

    printAnnotFooter( 0, 0 );

    my $sortClause = " order by g.gene_oid, c.username";
    my $rclause    = WebUtil::urClause('g.taxon');
    my $imgClause  = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql_part1  = qq{
	select c.username, g.gene_oid, 
	    ann.product_name, ann.ec_number,
	    ann.pubmed_id, ann.inference, ann.is_pseudogene,
	    ann.notes, ann.gene_symbol, ann.obsolete_flag,
	    g.product_name,
	};
    my $sql_part2 = qq{
        from gene g, gene_myimg_functions ann, contact c
        where g.gene_oid = ann.gene_oid
            and g.taxon = ?
            and g.obsolete_flag = 'No'
            and ann.modified_by = c.contact_oid
                   $rclause
                   $imgClause
                   $user_cond
               $sortClause
        };

    my $sql;
    if ( $rdbms eq "mysql" ) {
        $sql = qq{
		$sql_part1
		date_format( ann.mod_date, '%d-%m-%Y %k:%i:%s' )
		$sql_part2
	};
    } elsif ( $rdbms eq "oracle" ) {
        $sql = qq{
		$sql_part1
		to_char( ann.mod_date, 'yyyy-mm-dd HH24:MI:SS' )
		$sql_part2
	};
    }

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $it = new InnerTable( 1, "viewAnnotation$$", "viewAnnotation", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",                  "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Original Product Name",    "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "User ID",                  "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated Product Name",   "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated EC Number",      "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Annotated PUBMED ID",      "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Inference",                "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Is Pseudo Gene?",          "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Notes",                    "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Gene Symbol",              "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Remove Gene from Genome?", "char asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Last Modified Date",       "char desc", "left", "", "", "wrap" );

    my $count         = 0;
    my $trunc         = 0;
    my $prev_gene_oid = 0;

    for ( ; ; ) {
        my (
            $modified_by,   $gene_oid, $annotation_text, $ec_number,     $pubmed_id,         $inference,
            $is_pseudogene, $notes,    $gene_symbol,     $obsolete_flag, $gene_product_name, $add_date
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        my $annot_oid = $gene_oid;

        my $row;
        if ( $gene_oid == $prev_gene_oid ) {

            # annotation on same gene
            $row = $sd . "<input type='checkbox' name='gene_oid' value='$annot_oid' disabled/>\t";
            $row .= $gene_oid . $sd . "<font color='magenta'>$gene_oid</font>\t";
        } else {
            $count++;

            if ( $count > $maxGeneListResults ) {
                $trunc = 1;
                last;
            }

            my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";

            $row = $sd . "<input type='checkbox' name='gene_oid' value='$annot_oid' />\t";
            $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";

        }

        $row .= WebUtil::escHtml($gene_product_name) . $sd . WebUtil::escHtml($gene_product_name) . "\t";
        $row .= WebUtil::escHtml($modified_by) . $sd . WebUtil::escHtml($modified_by) . "\t";
        $row .= WebUtil::escHtml($annotation_text) . $sd . WebUtil::escHtml($annotation_text) . "\t";
        $row .= WebUtil::escHtml($ec_number) . $sd . WebUtil::escHtml($ec_number) . "\t";
        $row .= WebUtil::escHtml($pubmed_id) . $sd . WebUtil::escHtml($pubmed_id) . "\t";
        $row .= WebUtil::escHtml($inference) . $sd . WebUtil::escHtml($inference) . "\t";
        $row .= WebUtil::escHtml($is_pseudogene) . $sd . WebUtil::escHtml($is_pseudogene) . "\t";
        $row .= WebUtil::escHtml($notes) . $sd . WebUtil::escHtml($notes) . "\t";
        $row .= WebUtil::escHtml($gene_symbol) . $sd . WebUtil::escHtml($gene_symbol) . "\t";
        $row .= WebUtil::escHtml($obsolete_flag) . $sd . WebUtil::escHtml($obsolete_flag) . "\t";
        $row .= WebUtil::escHtml($add_date) . $sd . WebUtil::escHtml($add_date) . "\t";

        $it->addRow($row);
        $prev_gene_oid = $gene_oid;
    }

    $it->printOuterTable(1);

    $cur->finish();

    print WebUtil::hiddenVar( "page", "myIMG" );
    printAnnotFooter( 0, 0 ) if $count > 10;

    if ( !$trunc ) {
        WebUtil::printStatusLine( "$count genes retrieved", 2 );
    } else {
        WebUtil::printTruncatedStatus($maxGeneListResults);
    }

    #$dbh->disconnect();

    print end_form();
}

############################################################################
# printAnnotFooter - Print annotation footer.
############################################################################
sub printAnnotFooter {
    my ( $allow_export, $allow_update ) = @_;

    if ($allow_update) {
        my $name = "_section_${section}_updMyGeneAnnot";
        print submit(
            -name  => $name,
            -value => "Change MyIMG Annotations",
            -class => 'meddefbutton'
        );

        print nbsp(2);
        my $name = "_section_${section}_updateMyIMGTermForm";
        print submit(
            -name  => $name,
            -value => "Add/Update IMG Term(s)",
            -class => "medbutton"
        );

        print "<br/>\n";
    }

    #   my $name = "_section_${section}_removeMyAnnotations";
    #   print submit( -name => $name,
    #     -value => "Remove Selected Annotations", -class => 'meddefbutton' );
    my $name = "_section_GeneCartStor_addToGeneCart";
    print submit(
        -name  => $name,
        -value => "Add To Gene Cart",
        -class => 'smdefbutton'
    );
    print nbsp(1);

    if ($allow_export) {
        my $name = "_section_${section}_exportMyAnnotations_noHeader";
        print submit(
            -name    => $name,
            -value   => "Export Annotations",
            -class   => 'smbutton',
            -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button Annotations']);"
        );
        print nbsp(1);
    }

    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";
}

############################################################################
# deleteMyAnnotations - Do deletion of my annotations.
############################################################################
sub deleteMyAnnotations {
    my $dbh        = WebUtil::dbLogin();
    my @annot_oids = param("annot_oid");
    my @batch;
    print "<p>\n";
    print "Removing annotations.\n";
    for my $annot_oid (@annot_oids) {
        if ( scalar(@batch) > $max_batch_size ) {
            flushDeleteMyAnnotations( $dbh, \@batch );
            @batch = ();
        }
        push( @batch, $annot_oid );
    }
    flushDeleteMyAnnotations( $dbh, \@batch );
    updateAnnStatistics($dbh);
    print "</p>\n";

    #$dbh->disconnect();
}

############################################################################
# flushDeleteMyAnnotations - Handle flushing of deletions.
############################################################################
sub flushDeleteMyAnnotations {
    my ( $dbh, $batch_ref ) = @_;
    my $annot_oid_str = join( ',', @$batch_ref );
    if ( blankStr($annot_oid_str) ) {
        return;
    }
    my $sql = qq{
      delete from annotation_genes where annot_oid in( $annot_oid_str )
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();
    my $sql = qq{
      delete from annotation where annot_oid in( $annot_oid_str )
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();
}

############################################################################
# annSortLink - Annotation sort header link.
############################################################################
sub annSortLink {
    my ( $attr, $label, $user_id ) = @_;
    my $url = "$section_cgi&page=myIMG&annSortAttr=$attr&viewMyAnnotations=1";

    if ( !blankStr($user_id) ) {
        $url .= "&user_id=$user_id";
    }

    $url .= "&form=uploadGeneAnnotations";
    return alink( $url, $label );
}

############################################################################
# printGroupAnnotationForm
############################################################################
sub printGroupAnnotationForm {
    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::printStatusLine( "Aborted", 2 );
        WebUtil::webError("You are not logged in.");
    }

    my @my_groups = DataEntryUtil::db_getImgGroups($contact_oid);
    if ( scalar(@my_groups) == 0 ) {
        WebUtil::printStatusLine( "Aborted", 2 );
        WebUtil::webError("You do not belong to any IMG group.");
    }

    my $grp = param('selected_group');
    if ( !$grp ) {
        my @arr = split( /\t/, $my_groups[0] );
        if ( scalar(@arr) > 0 ) {
            $grp = $arr[0];
        }
    }
    if ( !isInt($grp) ) {
        $grp = "";
    }

    my $taxon_oid  = param('taxon_oid');
    my $taxon_cond = "";

    my $user_id     = param('user_id');
    my @user_groups = ();
    if ( $user_id && isInt($user_id) ) {
        @user_groups = DataEntryUtil::db_getImgGroups($user_id);
    }

##    print "<p>*** $contact_oid, $user_id\n";

    my $user_cond = "";

    if ( !blankStr($taxon_oid) ) {
        my $dbh        = WebUtil::dbLogin();
        my $taxon_name = DataEntryUtil::db_findVal( $dbh, 'TAXON', 'taxon_oid', $taxon_oid, 'taxon_name', "" );

        if ( !blankStr($user_id) ) {
            if ( groupIntersections( \@my_groups, \@user_groups ) > 0 ) {
                my $u_name = DataEntryUtil::db_findVal( $dbh, 'CONTACT', 'contact_oid', $user_id, 'username', "" );
                $user_cond = " and ann.modified_by = $user_id ";
                print "<h2>User Annotations on Genome $taxon_oid (";
                print escapeHTML($taxon_name);
                print ")</h2>\n";
                print "<h3>User: $u_name</h3>\n";
            } else {

                #$dbh->disconnect();
                WebUtil::printStatusLine( "Aborted", 2 );
                WebUtil::webError("You cannot user IMG annotation by this user.");
            }
        } else {
            print "<h2>Group Annotations on Genome $taxon_oid (";
            print escapeHTML($taxon_name);
            print ")</h2>\n";
            print WebUtil::hiddenVar( "taxon_oid", $taxon_oid );
        }

        #$dbh->disconnect();

        $taxon_cond = " and g.taxon = $taxon_oid ";
    } else {
        print "<h2>Group Annotations</h2>\n";
    }

    my $view_type = param('view_type');
    my $new_url   = $section_cgi . "&page=viewGroupAnnotations&view_type=$view_type";

    print "<p>IMG Group: \n";
    print qq{
      <select name='selected_group'
          onchange="window.location='$new_url&selected_group=' + this.value;"
          style="width:200px;">
    };

    for my $g1 (@my_groups) {
        my ( $g_id, $g_name ) = split( /\t/, $g1 );
        print "     <option value='$g_id' ";
        if ( $g_id == $grp ) {
            print " selected ";
        }
        print ">$g_id: $g_name</option>\n";
    }
    print "</select><br/>\n";

    if ($grp) {
        print
"<p><b>Note: Only annotations available to group members are listed here. Private user annotations not shared with this group are hidden.</b>\n";
    }

    WebUtil::printStatusLine( "Loading ...", 1 );

    my $it = new InnerTable( 1, "MyGroupAnnotations$$", "MyGroupAnnotations", 2 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "User ID",           "char",       "left", "", "", "wrap" );
    $it->addColSpec( "User Name",         "char",       "left", "", "", "wrap" );
    $it->addColSpec( "User Email",        "char",       "left", "", "", "wrap" );
    $it->addColSpec( "User Organization", "char",       "left", "", "", "wrap" );
    $it->addColSpec( "Genomes",           "number asc", "left", "", "", "wrap" );
    $it->addColSpec( "Genes",             "number",     "left", "", "", "wrap" );

    my %gene_h;
    my %user_h;
    my %name_h;
    my %email_h;
    my %org_h;
    my %genome_h;

    my $dbh = WebUtil::dbLogin();

    # group user info
    my $grp_cond  = "where img_group = $grp";
    my $grp_cond2 =
      "where c.contact_oid in (select g.contact_oid from contact_img_groups\@imgsg_dev g where g.img_group = $grp) ";

    my $sql = "select c.contact_oid, c.username, c.name, c.organization, c.email " . "from contact c " . $grp_cond2;

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $c_oid, $n1, $n2, $org, $em ) = $cur->fetchrow();
        last if !$c_oid;

        $user_h{$c_oid}  = $n1;
        $name_h{$c_oid}  = $n2;
        $org_h{$c_oid}   = $org;
        $email_h{$c_oid} = $em;
    }
    $cur->finish();

    # get permission condition clause
    my @taxon_per = ();
    my $sql       = QueryUtil::getContactTaxonPermissionSql();
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ($t_oid) = $cur->fetchrow();
        last if !$t_oid;

        push @taxon_per, ($t_oid);
    }
    $cur->finish();

    my $super_user_flag = getSuperUser();
    my $rclause         = "";
    if ( $super_user_flag eq 'Yes' ) {

        # super user does not have taxon constraints
        $rclause = " and g.taxon in (select tx.taxon_oid from Taxon tx " . "where tx.obsolete_flag = 'No') ";
    } elsif ( scalar(@taxon_per) == 0 ) {
        $rclause =
          " and g.taxon in (select tx.taxon_oid from Taxon tx " . "where tx.is_public = 'Yes' and tx.obsolete_flag = 'No') ";
    } elsif ( scalar(@taxon_per) <= 1000 ) {
        $rclause =
            " and ( g.taxon in (select tx.taxon_oid from Taxon tx "
          . "where tx.is_public = 'Yes' and tx.obsolete_flag = 'No') "
          . "or g.taxon in (";
        my $is_first = 1;
        for my $t_oid (@taxon_per) {
            if ($is_first) {
                $is_first = 0;
            } else {
                $rclause .= ", ";
            }
            $rclause .= $t_oid;
        }
        $rclause .= ")) ";
    } else {
        $rclause = WebUtil::urClause('g.taxon');
    }

    # user -> gene cnt
    if ($grp) {
        $grp_cond = " and c.img_group = $grp";
        $grp_cond .=
" and (ann.is_public = 'Yes' or exists (select gmg.group_id from gene_myimg_groups\@img_ext gmg where gmg.gene_oid = ann.gene_oid and gmg.contact_oid = ann.modified_by and gmg.group_id = $grp))";
    }

    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
		select ann.modified_by, count(*)
		from gene_myimg_functions ann, gene g, 
                     contact_img_groups\@imgsg_dev c
		where ann.gene_oid = g.gene_oid
		    and ann.modified_by = c.contact_oid
		    $grp_cond
                    $user_cond
                    $taxon_cond
                    $rclause
                    $imgClause
		group by ann.modified_by
		having count(*) > 0
	};

##    print "<p>SQL: $sql</p>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $user_id, $cnt ) = $cur->fetchrow();
        last if !$user_id;

        $gene_h{$user_id} = $cnt;
    }
    $cur->finish();

    my @keys = sort( keys %gene_h );

    # get genome count

    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
		select count(distinct g.taxon)
		from gene g, gene_myimg_functions ann
		where g.gene_oid = ann.gene_oid
		    and ann.modified_by = ?
		    $taxon_cond
                    $rclause
                    $imgClause
	};
    my $cur = prepSql( $dbh, $sql, $verbose );
    for my $k (@keys) {
        execStmt( $cur, $k );
        my ($g_cnt) = $cur->fetchrow();
        $genome_h{$k} = $g_cnt;
    }
    $cur->finish();

    # show results in table format
    my $count = 0;
    for my $k (@keys) {
        my $row;
        $row .= $sd . "<input type='checkbox' name='user_id' value='$k' />\t";

        # user id
        my $u_id = "";
        if ( $user_h{$k} ) {
            $u_id = $user_h{$k};
        }
        $row .= escapeHTML($u_id) . $sd . escapeHTML($u_id) . "\t";

        # user name
        my $u_name = "";
        if ( $name_h{$k} ) {
            $u_name = $name_h{$k};
        }
        $row .= escapeHTML($u_name) . $sd . escapeHTML($u_name) . "\t";

        # user email
        my $u_email = "";
        if ( $email_h{$k} ) {
            $u_email = $email_h{$k};
        }
        $row .= escapeHTML($u_email) . $sd . escapeHTML($u_email) . "\t";

        # user organization
        my $u_org = "";
        if ( $org_h{$k} ) {
            $u_org = $org_h{$k};
        }
        $row .= escapeHTML($u_org) . $sd . escapeHTML($u_org) . "\t";

        # genomes
        if ( !blankStr($taxon_oid) ) {
            $row .= escapeHTML($taxon_oid) . $sd . escapeHTML($taxon_oid) . "\t";
        } elsif ( $genome_h{$k} ) {
            my $url = "$main_cgi?section=MyIMG" . "&page=genomesList&user_id=$k";
            if ( !blankStr($taxon_oid) ) {
                $url .= "&taxon_oid=$taxon_oid";
            }
            $row .= escapeHTML( $genome_h{$k} ) . $sd . alink( $url, $genome_h{$k} ) . "\t";

        } else {
            $row .= "0" . $sd . "0\t";
        }

        # genes
        if ( $gene_h{$k} ) {
            my $url = "$main_cgi?section=MyIMG" . "&page=viewMyAnnotations&user_id=$k";
            if ( !blankStr($taxon_oid) ) {
                $url .= "&taxon_oid=$taxon_oid";
            }
            $row .= escapeHTML( $gene_h{$k} ) . $sd . alink( $url, $gene_h{$k} ) . "\t";
        } else {
            $row .= "0" . $sd . "0\t";
        }

        $it->addRow($row);
        $count++;
    }

    #$dbh->disconnect();

    print "<p>View or Compare different user annotations. ";

    if ( $count > 0 ) {
        print "Select one or more users and click "
          . "the 'View User Annotations' button to see "
          . "annotations entered by selected user(s).</p>\n";

        my $name = "_section_${section}_selectedAnnotations";
        print submit(
            -name  => $name,
            -value => "View User Annotations",
            -class => 'meddefbutton'
        );
        print nbsp(1);
        print "<input type='button' name='selectAll' value='Select All' "
          . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
        print nbsp(1);
        print "<input type='button' name='clearAll' value='Clear All' "
          . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
        print "<br/>\n";

        print "<p>\n";
        $it->printOuterTable(1);
        print "</p>\n";

        if ( $count > 10 ) {
            print submit(
                -name  => $name,
                -value => "View User Annotations",
                -class => 'meddefbutton'
            );
            print nbsp(1);
            print "<input type='button' name='selectAll' value='Select All' "
              . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
            print nbsp(1);
            print "<input type='button' name='clearAll' value='Clear All' "
              . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
            print "<br/>\n";
        }

    } else {
        print "</p><h5>There are no public or shared group annotations.</h5>";
    }

    WebUtil::printStatusLine( "Loaded", 2 );
    print end_form();
}

############################################################################
# printGroupGenomeAnnotationForm
############################################################################
sub printGroupGenomeAnnotationForm {
    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }

    my @my_groups = DataEntryUtil::db_getImgGroups($contact_oid);
    if ( scalar(@my_groups) == 0 ) {
        WebUtil::webError("You do not belong to any IMG group.");
    }

    my $grp = param('selected_group');
    if ( !$grp ) {
        my @arr = split( /\t/, $my_groups[0] );
        if ( scalar(@arr) > 0 ) {
            $grp = $arr[0];
        }
    }

    my $user_id     = param('user_id');
    my $user_grp    = "";
    my @user_groups = ();
    if ( $user_id && isInt($user_id) ) {
        @user_groups = DataEntryUtil::db_getImgGroups($user_id);
    }

    if ( scalar(@user_groups) > 0 && $grp ) {
        for my $user_g (@user_groups) {
            my ( $g2, $name2 ) = split( /\t/, $user_g );
            if ( $g2 == $grp ) {
                $user_grp = $g2;
                last;
            }
        }
    }

    my $u_name     = "";
    my $taxon_oid  = param('taxon_oid');
    my $taxon_cond = "";

    if ( !blankStr($user_id) ) {
        if ( $grp ne $user_grp ) {
            WebUtil::webError("You cannot user IMG annotation by this user.");
        }

        my $dbh = WebUtil::dbLogin();
        $u_name = DataEntryUtil::db_findVal( $dbh, 'CONTACT', 'contact_oid', $user_id, 'username', "" );
        if ( !blankStr($taxon_oid) ) {
            print "<h2>Genome $taxon_oid Annotations by User " . escapeHTML($u_name) . "</h2>\n";
        } else {
            print "<h2>Genomes with Annotations by User " . escapeHTML($u_name) . "</h2>\n";
        }

        #$dbh->disconnect();

        print "<p>\n";

        if ( !blankStr($taxon_oid) ) {
            print WebUtil::hiddenVar( 'taxon_oid', $taxon_oid );
            print "<p>View user annotations on genome $taxon_oid. ";
            $taxon_cond = " and g.taxon = $taxon_oid ";
        } else {
            print "<p>View user annotations on genomes. ";
        }

        print WebUtil::hiddenVar( 'user_id',   $user_id );
        print WebUtil::hiddenVar( 'user_name', $u_name );
    } else {
        print "<h2>Group Genome Annotations</h2>\n";
        print "<p>\n";
##	print "<p>View or Compare different group annotations on genome(s). ";
    }

    my $view_type = param('view_type');
    my $new_url   = $section_cgi . "&page=viewGroupAnnotations&view_type=$view_type";

    print "<p>IMG Group: \n";
    print qq{
      <select name='selected_group'
          onchange="window.location='$new_url&selected_group=' + this.value;"
          style="width:200px;">
    };

    for my $g1 (@my_groups) {
        my ( $g_id, $g_name ) = split( /\t/, $g1 );
        print "     <option value='$g_id' ";
        if ( $g_id == $grp ) {
            print " selected ";
        }
        print ">$g_id: $g_name</option>\n";
    }
    print "</select><br/>\n";

    print "<p>View or Compare different group annotations on genome(s). ";
    print
"Select one or more genomes and click the 'View Annotations on Genome(s)' button to see annotations on selected genome(s).</p>\n";

    WebUtil::printStatusLine( "Loading ...", 1 );

    my $name = "_section_${section}_selectedAnnotations";
    print submit(
        -name  => $name,
        -value => "View Annotations on Genome(s)",
        -class => 'meddefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";
    print "<p>\n";

    my $it = new InnerTable( 1, "MyAnnotations$$", "MyAnnotations", 2 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Taxon ID",    "number asc", "left", "", "", "wrap" );
    $it->addColSpec( "Genome Name", "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "Genes",       "number asc", "left", "", "", "wrap" );
    $it->addColSpec( "Users",       "number asc", "left", "", "", "wrap" );

    my $dbh = WebUtil::dbLogin();

    # genome -> group gene counts
    my $user_cond = "";
    if ( !blankStr($user_id) ) {
        $user_cond = " and ann.modified_by = $user_id ";
    }
    my %gene_h;
    my $grp_cond = " and c.img_group = $grp ";
    $grp_cond .=
" and (ann.is_public = 'Yes' or exists (select gmg.group_id from gene_myimg_groups\@img_ext gmg where gmg.gene_oid = ann.gene_oid and gmg.contact_oid = ann.modified_by and gmg.group_id = $grp))";
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
		select g.taxon, count(distinct ann.gene_oid)
		from gene g, gene_myimg_functions ann, 
                     contact_img_groups\@imgsg_dev c
		where g.gene_oid = ann.gene_oid
		    and ann.modified_by = c.contact_oid
                    $grp_cond
                    $user_cond
                    $taxon_cond
		    $rclause
		    $imgClause
		group by g.taxon
	};

    #    if ( $contact_oid == 312 ) {
    #	print "<p>*** SQL: $sql\n";
    #    }

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $g_cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        $gene_h{$taxon_oid} = $g_cnt;
    }
    $cur->finish();

    # get permission condition clause
    my @taxon_per = ();
    my $sql       = QueryUtil::getContactTaxonPermissionSql();
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ($t_oid) = $cur->fetchrow();
        last if !$t_oid;

        push @taxon_per, ($t_oid);
    }
    $cur->finish();

    my $super_user_flag = getSuperUser();
    my $rclause         = "";
    if ( $super_user_flag eq 'Yes' ) {

        # super user does not have taxon constraints
    } elsif ( scalar(@taxon_per) == 0 ) {
        $rclause = " and tx.is_public = 'Yes' ";
    } elsif ( scalar(@taxon_per) <= 1000 ) {
        $rclause = " and (tx.is_public = 'Yes' or tx.taxon_oid in (";
        my $is_first = 1;
        for my $t_oid (@taxon_per) {
            if ($is_first) {
                $is_first = 0;
            } else {
                $rclause .= ", ";
            }
            $rclause .= $t_oid;
        }
        $rclause .= ")) ";
    } else {
        $rclause = WebUtil::urClause('tx');
    }

    # genome -> group user count
    my $grp_cond = " and c.img_group = $grp ";
    $grp_cond .=
" and (ann.is_public = 'Yes' or exists (select gmg.group_id from gene_myimg_groups\@img_ext gmg where gmg.gene_oid = ann.gene_oid and gmg.contact_oid = ann.modified_by and gmg.group_id = $grp))";

    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
		select tx.taxon_oid, tx.taxon_name, count(distinct ann.modified_by)
		from taxon tx, gene g, gene_myimg_functions ann, 
                contact_img_groups\@imgsg_dev c
		where tx.taxon_oid = g.taxon
		    and g.gene_oid = ann.gene_oid
		    and ann.modified_by = c.contact_oid
                    $grp_cond
                    $user_cond
                    $taxon_cond
                    $rclause
                    $imgClause
		group by tx.taxon_oid, tx.taxon_name
		order by tx.taxon_oid
	};

    #    if ( $contact_oid == 312 ) {
    #	print "<p>*** SQL 2: $sql\n";
    #    }

    my $row;
    my $row_cnt = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        if ( !$cnt ) {
            next;
        }

        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";

        $row = $sd . "<input type='checkbox' name='taxon_oid' value='$taxon_oid' />\t";
        $row .= $taxon_oid . $sd . alink( $url, $taxon_oid ) . "\t";
        $row .= $taxon_name . $sd . escapeHTML($taxon_name) . "\t";

        # gene counts
        if ( $gene_h{$taxon_oid} ) {
            my $url = "$main_cgi?section=MyIMG" . "&page=groupAnnotForGenome&taxon_oid=$taxon_oid";
            $url .= "&user_id=$user_id" if ( !blankStr($user_id) );

            $row .= $gene_h{$taxon_oid} . $sd . alink( $url, $gene_h{$taxon_oid} ) . "\t";
        } else {
            $row .= "0" . $sd . "0\t";
            next;
        }

        # user name or user count
        if ( !blankStr($u_name) ) {
            $row .= $u_name . $sd . "$u_name\t";
        } elsif ( $cnt > 0 ) {
            my $url = "$main_cgi?section=MyIMG" . "&page=groupUsersList&taxon_oid=$taxon_oid";
            if ( !blankStr($user_id) ) {
                $url .= "&user_id=$user_id";
            }
            $row .= $cnt . $sd . alink( $url, $cnt ) . "\t";
        } else {
            $row .= "0" . $sd . "0\t";
        }

        $row_cnt++;
        $it->addRow($row);
    }

    if ($row_cnt) {
        $it->printOuterTable(1);
    } else {
        print "<h5>No available MyIMG annotations for this group</h5>\n";
    }

    $cur->finish();

    #$dbh->disconnect();

    WebUtil::printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printGroupUserAnnotationForm
############################################################################
sub printGroupUserAnnotationForm {
    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::printStatusLine( "Aborted", 2 );
        WebUtil::webError("You are not logged in.");
    }

    my $grp = DataEntryUtil::db_getImgGroup($contact_oid);
    if ( !$grp || blankStr($grp) || $grp == 0 ) {
        WebUtil::webError("You do not belong to any IMG group.");
    }

    my $taxon_oid  = param('taxon_oid');
    my $taxon_cond = "";

    my $user_id  = param('user_id');
    my $user_grp = "";
    if ( $user_id && isInt($user_id) ) {
        $user_grp = DataEntryUtil::db_getImgGroup($user_id);
    }

    my $user_cond = "";

    if ( !blankStr($taxon_oid) ) {
        my $dbh        = WebUtil::dbLogin();
        my $taxon_name = DataEntryUtil::db_findVal( $dbh, 'TAXON', 'taxon_oid', $taxon_oid, 'taxon_name', "" );

        if ( !blankStr($user_id) ) {
            if ( $grp ne $user_grp ) {
                WebUtil::webError("You cannot user IMG annotation by this user.");
            }

            my $u_name = DataEntryUtil::db_findVal( $dbh, 'CONTACT', 'contact_oid', $user_id, 'username', "" );
            $user_cond = " and ann.modified_by = $user_id ";
            print "<h2>Group User Annotations on Genome $taxon_oid (";
            print escapeHTML($taxon_name);
            print ")</h2>\n";
            print "<h3>User: $u_name</h3>\n";
        } else {
            print "<h2>Group User Annotations on Genome $taxon_oid (";
            print escapeHTML($taxon_name);
            print ")</h2>\n";
            print WebUtil::hiddenVar( "taxon_oid", $taxon_oid );
        }

        #$dbh->disconnect();

        $taxon_cond = " and g.taxon = $taxon_oid ";
    } else {
        print "<h2>All Group User Annotations</h2>\n";
    }

    print "<p>View or Compare different user annotations. ";
    print
"Select one or more users and click the 'View User Annotations' button to see annotations entered by selected user(s).</p>\n";

    WebUtil::printStatusLine( "Loading ...", 1 );

    my $name = "_section_${section}_selectedAnnotations";
    print submit(
        -name  => $name,
        -value => "View User Annotations",
        -class => 'meddefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";
    print "<p>\n";

    print "<table class='img' border='1'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>User ID</th>\n";
    print "<th class='img'>Complete Name</th>\n";
    print "<th class='img'>User Organization</th>\n";
    print "<th class='img'>Genomes</th>\n";
    print "<th class='img'>Genes</th>\n";
    print "</tr>\n";

    my %gene_h;
    my %user_h;
    my %name_h;
    my %org_h;
    my %genome_h;

    my $dbh = WebUtil::dbLogin();

    # all user info
    my $sql = "select contact_oid, username, name, organization from contact";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $c_oid, $n1, $n2, $org ) = $cur->fetchrow();
        last if !$c_oid;

        $user_h{$c_oid} = $n1;
        $name_h{$c_oid} = $n2;
        $org_h{$c_oid}  = $org;
    }
    $cur->finish();

    # get permission condition clause
    my @taxon_per = ();
    my $sql       = QueryUtil::getContactTaxonPermissionSql();
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ($t_oid) = $cur->fetchrow();
        last if !$t_oid;

        push @taxon_per, ($t_oid);
    }
    $cur->finish();

    my $super_user_flag = getSuperUser();
    my $rclause         = "";
    if ( $super_user_flag eq 'Yes' ) {

        # super user can view all
    } elsif ( scalar(@taxon_per) == 0 ) {
        $rclause = " and g.taxon in (select tx.taxon_oid from Taxon tx " . "where tx.is_public = 'Yes') ";
    } elsif ( scalar(@taxon_per) <= 1000 ) {
        $rclause =
          " and ( g.taxon in (select tx.taxon_oid from Taxon tx " . "where tx.is_public = 'Yes') " . "or g.taxon in (";
        my $is_first = 1;
        for my $t_oid (@taxon_per) {
            if ($is_first) {
                $is_first = 0;
            } else {
                $rclause .= ", ";
            }
            $rclause .= $t_oid;
        }
        $rclause .= ")) ";
    } else {
        $rclause = WebUtil::urClause('g.taxon');
    }

    # user -> gene cnt
    my $grp_cond = " and c.img_group = $grp ";

    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
		select ann.modified_by, count(*)
		from gene_myimg_functions ann, gene g, contact c
		where ann.gene_oid = g.gene_oid
		    and ann.modified_by = c.contact_oid
                    $grp_cond
                    $user_cond
                    $taxon_cond
                    $rclause
                    $imgClause
		group by ann.modified_by
		having count(*) > 0
	};

    print "<p>SQL: $sql</p>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $user_id, $cnt ) = $cur->fetchrow();
        last if !$user_id;

        $gene_h{$user_id} = $cnt;
    }
    $cur->finish();

    my @keys = sort( keys %gene_h );

    # get genome count
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
	select count(distinct g.taxon)
	from gene g, gene_myimg_functions ann
	where g.gene_oid = ann.gene_oid
	and ann.modified_by = ?
        $taxon_cond
        $rclause
        $imgClause
    };
    my $cur = prepSql( $dbh, $sql, $verbose );
    for my $k (@keys) {
        execStmt( $cur, $k );
        my ($g_cnt) = $cur->fetchrow();
        $genome_h{$k} = $g_cnt;
    }
    $cur->finish();

    # show results in table format
    for my $k (@keys) {
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='user_id' value='$k' />\n";
        print "</td>\n";

        # user id
        my $u_id = "";
        if ( $user_h{$k} ) {
            $u_id = $user_h{$k};
        }
        print "<td class='img'>" . escapeHTML($u_id) . "</td>\n";

        # user name
        my $u_name = "";
        if ( $name_h{$k} ) {
            $u_name = $name_h{$k};
        }
        print "<td class='img'>" . escapeHTML($u_name) . "</td>\n";

        # user organization
        my $u_org = "";
        if ( $org_h{$k} ) {
            $u_org = $org_h{$k};
        }
        print "<td class='img'>" . escapeHTML($u_org) . "</td>\n";

        # genomes
        if ( !blankStr($taxon_oid) ) {
            print "<td class='img'>Genome: $taxon_oid</td>\n";
        } elsif ( $genome_h{$k} ) {
            my $url = "$main_cgi?section=MyIMG" . "&page=genomesList&user_id=$k";
            if ( !blankStr($taxon_oid) ) {
                $url .= "&taxon_oid=$taxon_oid";
            }
            print "<td class='img' >" . alink( $url, $genome_h{$k} ) . "</td>\n";
        } else {
            print "<td class='img'>0</td>\n";
        }

        # genes
        if ( $gene_h{$k} ) {
            my $url = "$main_cgi?section=MyIMG" . "&page=viewMyAnnotations&user_id=$k";
            if ( !blankStr($taxon_oid) ) {
                $url .= "&taxon_oid=$taxon_oid";
            }
            print "<td class='img' >" . alink( $url, $gene_h{$k} ) . "</td>\n";
        } else {
            print "<td class='img'>0</td>\n";
        }

        print "<tr/>\n";
    }

    #$dbh->disconnect();

    print "</table>\n";

    WebUtil::printStatusLine( "Loaded", 2 );
    print end_form();
}

############################################################################
# printAllUserAnnotationForm
############################################################################
sub printAllUserAnnotationForm {
    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::printStatusLine( "Aborted", 2 );
        WebUtil::webError("You are not logged in.");
    }
    my $super_user_flag = getSuperUser();

    my $dbh          = WebUtil::dbLogin();
    my $my_img_group = DataEntryUtil::db_findVal( $dbh, 'CONTACT', 'contact_oid', $contact_oid, 'img_group', "" );

    #$dbh->disconnect();

    my $taxon_oid  = param('taxon_oid');
    my $taxon_cond = "";

    my $user_id   = param('user_id');
    my $user_cond = "";

    if ( !blankStr($taxon_oid) ) {

        # only view annotation on taxon_oid
        my $dbh        = WebUtil::dbLogin();
        my $taxon_name = DataEntryUtil::db_findVal( $dbh, 'TAXON', 'taxon_oid', $taxon_oid, 'taxon_name', "" );

        if ( !blankStr($user_id) ) {
            my $u_name = DataEntryUtil::db_findVal( $dbh, 'CONTACT', 'contact_oid', $user_id, 'username', "" );
            $user_cond = " and ann.modified_by = $user_id ";
            if ( $super_user_flag ne 'Yes' && $contact_oid != $user_id ) {
                $user_cond .= " and ann.is_public = 'Yes' ";
            }
            print "<h2>User Annotations on Genome $taxon_oid (";
            print escapeHTML($taxon_name);
            print ")</h2>\n";
            print "<h3>User: $u_name</h3>\n";
        } else {
            if ( $super_user_flag ne 'Yes' ) {
                WebUtil::webError("You cannot view genome annotations by all users");
            }

            print "<h2>All User Annotations on Genome $taxon_oid (";
            print escapeHTML($taxon_name);
            print ")</h2>\n";
            print WebUtil::hiddenVar( "taxon_oid", $taxon_oid );
        }

        #$dbh->disconnect();

        $taxon_cond = " and g.taxon = $taxon_oid ";
    } else {

        # view summary count
        print "<h2>All User Annotations</h2>\n";
    }

    if ( $super_user_flag ne 'Yes' ) {
        print "<p>You can only see user annotations that you have permissions to view.\n";
    }

    print "<p>View or Compare different user annotations. ";
    print
"Select one or more users and click the 'View User Annotations' button to see annotations entered by selected user(s).</p>\n";

    WebUtil::printStatusLine( "Loading ...", 1 );

    my %gene_h;
    my %user_h;
    my %name_h;
    my %email_h;
    my %org_h;
    my %genome_h;

    my $dbh = WebUtil::dbLogin();

    # all user info
    my $sql = "select contact_oid, username, name, organization, email from contact";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $c_oid, $n1, $n2, $org, $em ) = $cur->fetchrow();
        last if !$c_oid;

        $user_h{$c_oid}  = $n1;
        $name_h{$c_oid}  = $n2;
        $org_h{$c_oid}   = $org;
        $email_h{$c_oid} = $em;
    }
    $cur->finish();

    # get permission condition clause
    my @taxon_per = ();
    my $sql       = QueryUtil::getContactTaxonPermissionSql();
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ($t_oid) = $cur->fetchrow();
        last if !$t_oid;

        push @taxon_per, ($t_oid);
    }
    $cur->finish();

    my $super_user_flag = getSuperUser();
    my $rclause         = "";
    if ( $super_user_flag eq 'Yes' ) {

        # super user can view all
        $rclause = " and g.taxon in (select tx.taxon_oid from Taxon tx " . "where tx.obsolete_flag = 'No') ";
    } elsif ( scalar(@taxon_per) == 0 ) {
        $rclause =
          " and g.taxon in (select tx.taxon_oid from Taxon tx " . "where tx.is_public = 'Yes' and tx.obsolete_flag = 'No') ";
    } elsif ( scalar(@taxon_per) <= 1000 ) {
        $rclause =
            " and ( g.taxon in (select tx.taxon_oid from Taxon tx "
          . "where tx.is_public = 'Yes' and tx.obsolete_flag = 'No') "
          . "or g.taxon in (";
        my $is_first = 1;
        for my $t_oid (@taxon_per) {
            if ($is_first) {
                $is_first = 0;
            } else {
                $rclause .= ", ";
            }
            $rclause .= $t_oid;
        }
        $rclause .= ")) ";
    } else {
        $rclause = WebUtil::urClause('g.taxon');
    }

    # user -> gene cnt
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
		select ann.modified_by, count(*)
		from gene_myimg_functions ann, gene g
		where ann.gene_oid = g.gene_oid
                    $user_cond
                    $taxon_cond
                    $rclause
                    $imgClause
		group by ann.modified_by
		having count(*) > 0
	};

    #   print "<p>SQL: $sql</p>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $user_id, $cnt ) = $cur->fetchrow();
        last if !$user_id;

        $gene_h{$user_id} = $cnt;
    }
    $cur->finish();

    my @keys = sort( keys %gene_h );

    # get genome count
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
		select count(distinct g.taxon)
		from gene g, gene_myimg_functions ann
		where g.gene_oid = ann.gene_oid
		    and ann.modified_by = ?
		    $taxon_cond
		    $rclause
		    $imgClause
    };
    my $cur = prepSql( $dbh, $sql, $verbose );
    for my $k (@keys) {
        execStmt( $cur, $k );
        my ($g_cnt) = $cur->fetchrow();
        $genome_h{$k} = $g_cnt;
    }
    $cur->finish();

    my $it = new InnerTable( 1, "allAnnotation$$", "allAnnotation", 1 );
    $it->addColSpec("Select");
    if ( $super_user_flag eq 'Yes' ) {
        $it->addColSpec( "User ID", "char asc", "left" );
    }
    $it->addColSpec( "User Name",         "char asc",   "left" );
    $it->addColSpec( "User Email",        "char asc",   "left" );
    $it->addColSpec( "User Organization", "char asc",   "left" );
    $it->addColSpec( "Genomes",           "number asc", "right" );
    $it->addColSpec( "Genes",             "number asc", "right" );
    my $sd = $it->getSdDelim();

    my $count = 0;

    # show results in table format
    for my $k (@keys) {
        my $row;
        $row .= $k . $sd . "<input type='checkbox' name='user_id' value='$k' />\t";

        # user id
        my $u_id = "";
        if ( $super_user_flag eq 'Yes' ) {
            $u_id = $user_h{$k} if ( $user_h{$k} );
            $row .= escapeHTML($u_id) . $sd . escapeHTML($u_id) . "\t";
        }

        # user name
        my $u_name = "";
        $u_name = $name_h{$k} if ( $name_h{$k} );
        $row .= escapeHTML($u_name) . $sd . escapeHTML($u_name) . "\t";

        # user email
        my $u_email = "";
        $u_email = $email_h{$k} if ( $email_h{$k} );
        $row .= escapeHTML($u_email) . $sd . escapeHTML($u_email) . "\t";

        # user organization
        my $u_org = "";
        $u_org = $org_h{$k} if ( $org_h{$k} );
        $row .= escapeHTML($u_org) . $sd . escapeHTML($u_org) . "\t";

        # genomes
        if ( !blankStr($taxon_oid) ) {
            $row .= $taxon_oid . $sd . "Genome: $taxon_oid\t";
        } elsif ( $genome_h{$k} ) {
            my $url = "$main_cgi?section=MyIMG" . "&page=genomesList&user_id=$k";
            if ( !blankStr($taxon_oid) ) {
                $url .= "&taxon_oid=$taxon_oid";
            }
            $row .= $genome_h{$k} . $sd . alink( $url, $genome_h{$k} ) . "\t";
        } else {
            $row .= 0 . $sd . "0\t";
        }

        # genes
        if ( $gene_h{$k} ) {
            my $url = "$main_cgi?section=MyIMG" . "&page=viewMyAnnotations&user_id=$k";
            if ( !blankStr($taxon_oid) ) {
                $url .= "&taxon_oid=$taxon_oid";
            }
            $row .= $gene_h{$k} . $sd . alink( $url, $gene_h{$k} ) . "\t";
        } else {
            $row .= 0 . $sd . "0\t";
        }

        $it->addRow($row);
        $count++;

    }

    #$dbh->disconnect();

    my $name = "_section_${section}_selectedAnnotations";
    print submit(
        -name  => $name,
        -value => "View User Annotations",
        -class => 'meddefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";

    print "<p>\n";
    $it->printOuterTable(1);
    print "</p>\n";

    if ( $count > 10 ) {
        my $name = "_section_${section}_selectedAnnotations";
        print submit(
            -name  => $name,
            -value => "View User Annotations",
            -class => 'meddefbutton'
        );
        print nbsp(1);
        print "<input type='button' name='selectAll' value='Select All' "
          . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
        print nbsp(1);
        print "<input type='button' name='clearAll' value='Clear All' "
          . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
        print "<br/>\n";

    }

    WebUtil::printStatusLine( "Loaded", 2 );

    print end_form();
}

############################################################################
# printSelectedAnnotationForm
############################################################################
sub printSelectedAnnotationForm {
    WebUtil::printMainForm();

    my @user_ids   = param('user_id');
    my @taxon_oids = param('taxon_oid');

    my $u_name = "";

    if ( scalar(@taxon_oids) > 0 && scalar(@user_ids) > 0 ) {

        # selected taxons and selected users
        print "<h2>Selected Annotations</h2>";
        $u_name = param('user_name');
        if ( !blankStr($u_name) ) {
            print "<h3>User: $u_name</h3>\n";
        }
    } elsif ( scalar(@taxon_oids) > 0 ) {
        print "<h2>Selected Genome Annotations</h2>";
    } elsif ( scalar(@user_ids) > 0 ) {
        print "<h2>Selected User Annotations</h2>\n";
    } else {
        WebUtil::webError("No selections have been made.");
        return;
    }

    # just in case ...
    if ( scalar(@user_ids) > 1000 ) {
        WebUtil::webError("You cannot select more than 1,000 users.");
        return;
    } elsif ( scalar(@taxon_oids) > 1000 ) {
        WebUtil::webError("You cannot select more than 1,000 genomes.");
        return;
    }

    # get contact_oid
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }
    my $super_user_flag = getSuperUser();
    my $grp             = DataEntryUtil::db_getImgGroup($contact_oid);
    my $group_cond      = "";
    if ( $super_user_flag eq 'Yes' ) {

        # super user
    } elsif ( $grp && isInt($grp) && $grp > 0 ) {
        $group_cond = " and c.img_group = $grp";
    } else {
        $group_cond = " and c.contact_oid = $contact_oid";
    }

    print "<p>This page shows selected gene annotations innitially ordered by Gene ID. ";
    if ( blankStr($u_name) ) {
        print "There can be multiple annotations on the same gene by "
          . "different users. Gene ID values shown in "
          . "<font color='magenta'>this color</font> are 'duplicate entries' "
          . "with different user annotations.</p>\n";
    } else {
        print "</p>\n";
    }
    print "<p>Select genes to add to Gene Cart for further annotations.</p>\n";

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }

    my $select_cond = "";

    # condition on taxon?
    my $is_first = 1;
    if ( scalar(@taxon_oids) > 0 ) {
        for my $k (@taxon_oids) {
            print WebUtil::hiddenVar( 'taxon_oid', $k );
            if ($is_first) {
                $is_first = 0;
                $select_cond .= " and tx.taxon_oid in (" . $k;
            } else {
                $select_cond .= ", " . $k;
            }
        }
        $select_cond .= ") ";
    }

    # condition on user?
    $is_first = 1;
    if ( scalar(@user_ids) > 0 ) {
        for my $k (@user_ids) {
            print WebUtil::hiddenVar( 'user_id', $k );
            if ($is_first) {
                $is_first = 0;
                $select_cond .= " and ann.modified_by in (" . $k;
            } else {
                $select_cond .= ", " . $k;
            }
        }
        $select_cond .= ") ";
    }

    WebUtil::printStatusLine( "Loading ...", 1 );

    printAnnotFooter( 0, 0 );

    my $it = new InnerTable( 1, "myGeneAnnotation$$", "myGeneAnnotation", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",                  "number asc", "left" );
    $it->addColSpec( "Genome",                   "char asc",   "right" );
    $it->addColSpec( "Original Product Name",    "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "User ID",                  "char asc",   "left" );
    $it->addColSpec( "Annotated Product Name",   "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "Annotated EC Number",      "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "Annotated PUBMED ID",      "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "Inference",                "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "Is Pseudo Gene?",          "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "Notes",                    "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "Gene Symbol",              "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "Remove Gene from Genome?", "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "Is Public?",               "char asc",   "left", "", "", "wrap" );
    $it->addColSpec( "Last Modified Date",       "number asc", "left" );
    my $sd = $it->getSdDelim();

    my $dbh        = WebUtil::dbLogin();
    my $sortClause = "order by g.gene_oid, c.username";

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql_part1 = qq{
		select c.username, g.gene_oid, 
		    ann.product_name, ann.ec_number,
		    ann.pubmed_id, ann.inference, ann.is_pseudogene,
		    ann.notes, ann.gene_symbol, ann.obsolete_flag, ann.is_public,
		    g.product_name, tx.taxon_display_name, 
	};
    my $sql_part2 = qq{
		from gene g, taxon tx, gene_myimg_functions ann, contact c
		where g.gene_oid = ann.gene_oid
		    and g.taxon = tx.taxon_oid
		    and g.obsolete_flag = 'No'
		    and ann.modified_by = c.contact_oid
		    $select_cond
		    $group_cond
		    $rclause
		    $imgClause
		$sortClause
	};
    my $sql_mysql = qq{
		$sql_part1
		date_format( ann.mod_date, '%d-%m-%Y %k:%i:%s' )
		$sql_part2
	};
    my $sql_oracle = qq{
		$sql_part1
		to_char( ann.mod_date, 'yyyy-mm-dd HH24:MI:SS' )
		$sql_part2
	};
    my $sql;
    $sql = $sql_mysql  if $rdbms eq "mysql";
    $sql = $sql_oracle if $rdbms eq "oracle";
    my $cur = execSql( $dbh, $sql, $verbose );

    my $count         = 0;
    my $trunc         = 0;
    my $prev_gene_oid = 0;
    for ( ; ; ) {
        my (
            $modified_by, $gene_oid,          $annotation_text,    $ec_number,   $pubmed_id,
            $inference,   $is_pseudogene,     $notes,              $gene_symbol, $obsolete_flag,
            $is_public,   $gene_product_name, $taxon_display_name, $add_date
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        my $row;
        my $annot_oid = $gene_oid;

        if ( $gene_oid == $prev_gene_oid ) {

            # annotation on same gene
            $row .= $annot_oid . $sd . "<input type='checkbox' name='gene_oid' value='$annot_oid' disabled/>\t";
            $row .= $gene_oid . $sd . "<font color='magenta'>$gene_oid</font>\t";

        } else {
            $count++;

            if ( $count > $maxGeneListResults ) {
                $trunc = 1;
                last;
            }

            my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";

            $row .= $annot_oid . $sd . "<input type='checkbox' name='gene_oid' value='$annot_oid' />\t";
            $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";

        }

        $row .= WebUtil::escHtml($taxon_display_name) . $sd . WebUtil::escHtml($taxon_display_name) . "\t";
        $row .= WebUtil::escHtml($gene_product_name) . $sd . WebUtil::escHtml($gene_product_name) . "\t";
        $row .= WebUtil::escHtml($modified_by) . $sd . WebUtil::escHtml($modified_by) . "\t";
        $row .= WebUtil::escHtml($annotation_text) . $sd . WebUtil::escHtml($annotation_text) . "\t";
        $row .= WebUtil::escHtml($ec_number) . $sd . WebUtil::escHtml($ec_number) . "\t";
        $row .= WebUtil::escHtml($pubmed_id) . $sd . WebUtil::escHtml($pubmed_id) . "\t";
        $row .= WebUtil::escHtml($inference) . $sd . WebUtil::escHtml($inference) . "\t";
        $row .= WebUtil::escHtml($is_pseudogene) . $sd . WebUtil::escHtml($is_pseudogene) . "\t";
        $row .= WebUtil::escHtml($notes) . $sd . WebUtil::escHtml($notes) . "\t";
        $row .= WebUtil::escHtml($gene_symbol) . $sd . WebUtil::escHtml($gene_symbol) . "\t";
        $row .= WebUtil::escHtml($obsolete_flag) . $sd . WebUtil::escHtml($obsolete_flag) . "\t";
        $row .= WebUtil::escHtml($is_public) . $sd . WebUtil::escHtml($is_public) . "\t";
        $row .= WebUtil::escHtml($add_date) . $sd . WebUtil::escHtml($add_date) . "\t";
        $it->addRow($row);

        $prev_gene_oid = $gene_oid;
    }
    $cur->finish();
    $it->printOuterTable(1);

    print WebUtil::hiddenVar( "page", "myIMG" );
    printAnnotFooter( 0, 0 ) if $count > 10;

    if ( !$trunc ) {
        WebUtil::printStatusLine( "$count genes retrieved", 2 );
    } else {
        printTruncatedStatus($maxGeneListResults);
    }

    #$dbh->disconnect();

    print end_form();
}

############################################################################
# printGeneCartAnnotationForm
############################################################################
sub printGeneCartAnnotationForm {
    my ($type) = @_;

    WebUtil::printMainForm();

    # get contact_oid
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }
    my $super_user_flag = getSuperUser();

    my @my_groups = DataEntryUtil::db_getImgGroups($contact_oid);
    if ( scalar(@my_groups) == 0 ) {
        WebUtil::webError("You do not belong to any IMG group.");
    }

    my $grp = param('selected_group');
    if ( !$grp ) {
        my @arr = split( /\t/, $my_groups[0] );
        if ( scalar(@arr) > 0 ) {
            $grp = $arr[0];
        }
    }

    if ( $type == 3 && $super_user_flag ne 'Yes' ) {
        $type = 2;
    }
    if ( $type == 2 && !$grp ) {
        $type = 1;
    }

    if ( $type == 3 ) {
        print "<h2>Annotations for All Genes in Gene Carts</h2>";
    } elsif ( $type == 2 ) {
        print "<h2>Group Annotations for All Genes in Gene Carts</h2>";

        my $view_type = param('view_type');
        my $new_url   = $section_cgi . "&page=viewGroupAnnotations&view_type=$view_type";

        print "<p>IMG Group: \n";
        print qq{
          <select name='selected_group'
              onchange="window.location='$new_url&selected_group=' + this.value;"
              style="width:200px;">
        };

        for my $g1 (@my_groups) {
            my ( $g_id, $g_name ) = split( /\t/, $g1 );
            print "     <option value='$g_id' ";
            if ( $g_id == $grp ) {
                print " selected ";
            }
            print ">$g_id: $g_name</option>\n";
        }
        print "</select><br/>\n";
    } else {
        print "<h2>My Annotations for All Genes in Gene Carts</h2>";
    }

    # get all genes in the gene cart
    my $gc = new GeneCartStor();

    #only fetch db genes temporarily
    #	my $recs = $gc->readCartFile();          # get records
    #	my @gene_oids = sort { $a <=> $b } keys(%$recs);
    my @db_gene_oids = $gc->getDbGeneOids();
    my @gene_oids    = sort { $a <=> $b } @db_gene_oids;

    # The keys for the records are gene_oids.
    # But we want them sorted.

    # get selected genes
    my $selectedGenes = param("selectedGenes");
    my @selected_gene_oids = split( / /, $selectedGenes );
    my %selected_gene_oids_h;
    for my $gene_oid (@selected_gene_oids) {
        $selected_gene_oids_h{$gene_oid} = 1;
    }

    # print selected count
    #    my $count = @selected_gene_oids;
    my $count = scalar(@gene_oids);
    print "<p>\n";
    print "$count database gene(s) in cart\n";
    print "</p>\n";

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    if ( $maxGeneListResults > 1000 ) {
        $maxGeneListResults = 1000;
    }

    if ( $count == 0 ) {
        WebUtil::webError("Gene cart does not have any database genes.");
    } elsif ( $count > $maxGeneListResults ) {
        print "<p><font color='red'>Too many genes -- only $maxGeneListResults genes are displayed</font></p>\n";
    }

    print "<p>This page shows selected gene annotations order by Gene ID. ";
    if ( $type > 1 ) {
        print "There can be multiple annotations on the same gene by " . "different users.</p>\n";
    } else {
        print "</p>\n";
    }

    my $select_cond = "";

    # condition on gene_oids
    for my $g1 (@gene_oids) {
        if ( blankStr($select_cond) ) {
            $select_cond = " and g.gene_oid in (" . $g1;
        } else {
            $select_cond .= ", $g1";
        }
    }
    $select_cond .= ") ";

    # condition on user?
    if ( $type == 3 && $super_user_flag eq 'Yes' ) {

        # no condition
    } elsif ( $type == 2 && $grp && !blankStr($grp) && isInt($grp) ) {

        # condition on group
        $select_cond .=
          " and c.contact_oid in (select contact_oid from contact_img_groups\@imgsg_dev where img_group = $grp) ";
    } else {

        # only my own annotations
        $select_cond .= " and c.contact_oid = $contact_oid ";
    }

    WebUtil::printStatusLine( "Loading ...", 1 );

    #   printAnnotFooter( 0, 0 );

    print "<table class='img'  border='1'>\n";

    #   print "<th class='img' >Select</th>\n";
    print "<th class='img' >Gene ID</th>\n";
    print "<th class='img' >Genome</th>\n";
    print "<th class='img' >Original Product Name</th>\n";
    print "<th class='img' >User ID</th>\n";
    print "<th class='img' >Annotated Product Name</th>\n";
    print "<th class='img' >Annotated EC Number</th>\n";
    print "<th class='img' >Annotated PUBMED ID</th>\n";
    print "<th class='img' >Inference</th>\n";
    print "<th class='img' >Is Pseudo Gene?</th>\n";
    print "<th class='img' >Notes</th>\n";
    print "<th class='img' >Annotated Gene Symbol</th>\n";
    print "<th class='img' >Remove Gene from Genomes?</th>\n";
    print "<th class='img' >Is Public?</th>\n";
    print "<th class='img' >Last Modified Date</th>\n";

    my $dbh        = WebUtil::dbLogin();
    my $sortClause = "order by g.gene_oid, c.username";

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql_part1 = qq{
		select c.username, g.gene_oid, 
		    ann.product_name, ann.ec_number,
		    ann.pubmed_id, ann.inference, ann.is_pseudogene,
		    ann.notes, ann.gene_symbol, 
                    ann.obsolete_flag, ann.is_public,
		    g.product_name, tx.taxon_display_name, 
	};
    my $sql_part2 = qq{		
		from gene g, taxon tx, gene_myimg_functions ann, contact c
		where g.gene_oid = ann.gene_oid
		    and g.taxon = tx.taxon_oid
		    and g.obsolete_flag = 'No'
		    and ann.modified_by = c.contact_oid
		    $select_cond
		    $rclause
		    $imgClause
		$sortClause
	};
    my $sql_mysql = qq{
		$sql_part1
		date_format( ann.mod_date, '%d-%m-%Y %k:%i:%s' )
		$sql_part2
	};
    my $sql_oracle = qq{
		$sql_part1
		to_char( ann.mod_date, 'yyyy-mm-dd HH24:MI:SS' )
		$sql_part2
	};
    my $sql;
    $sql = $sql_mysql  if $rdbms eq "mysql";
    $sql = $sql_oracle if $rdbms eq "oracle";

##    print "<p>*** SQL 3: $sql\n";

    my $cur = execSql( $dbh, $sql, $verbose );

    my $count         = 0;
    my $trunc         = 0;
    my $prev_gene_oid = 0;

    for ( ; ; ) {
        my (
            $modified_by, $gene_oid,          $annotation_text,    $ec_number,   $pubmed_id,
            $inference,   $is_pseudogene,     $notes,              $gene_symbol, $obsolete_flag,
            $is_public,   $gene_product_name, $taxon_display_name, $add_date
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        my $annot_oid = $gene_oid;

        if ( $gene_oid == $prev_gene_oid ) {

            # annotation on same gene
            if ( $count % 2 ) {
                print "<tr class='img' bgcolor='lightgrey'>\n";
            } else {
                print "<tr class='img'>\n";
            }
            print "<td class='img'>" . $gene_oid . "</td>\n";
        } else {
            $count++;

            if ( $count > $maxGeneListResults ) {
                $trunc = 1;
                last;
            }

            if ( $count % 2 ) {
                print "<tr class='img' bgcolor='lightgrey'>\n";
            } else {
                print "<tr class='img'>\n";
            }
            my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";

            print "<td class='img' >" . alink( $url, $gene_oid ) . "</td>\n";
        }
        print "<td class='img' >" . WebUtil::escHtml($taxon_display_name) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($gene_product_name) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($modified_by) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($annotation_text) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($ec_number) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($pubmed_id) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($inference) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($is_pseudogene) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($notes) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($gene_symbol) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($obsolete_flag) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($is_public) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($add_date) . "</td>\n";
        print "</tr>\n";

        $prev_gene_oid = $gene_oid;
    }
    print "</table>\n";
    $cur->finish();

    print WebUtil::hiddenVar( "page", "myIMG" );

    if ( !$trunc ) {
        WebUtil::printStatusLine( "$count genes retrieved", 2 );
    } else {
        printTruncatedStatus($maxGeneListResults);
    }

    #$dbh->disconnect();

    print end_form();
}

############################################################################
# printMyGenomeAnnotationForm - show my annotations by genome
############################################################################
sub printMyGenomeAnnotationForm {
    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }

    my $taxon_oid  = param('taxon_oid');
    my $taxon_cond = "";

    print "<h2>My Annotations by Genomes</h2>\n";
    print "<p>\n";
    print "<p>View my annotations on genome(s). ";

    print
"Select one or more genomes and click the 'View Annotations on Genome(s)' button to see annotations on selected genome(s).</p>\n";

    WebUtil::printStatusLine( "Loading ...", 1 );

    my $name = "_section_${section}_mySelectedGenomeAnnotations";
    print submit(
        -name  => $name,
        -value => "View My Annotations on Genome(s)",
        -class => 'lgdefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";
    print "<p>\n";

    print "<table class='img' border='1'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Taxon ID</th>\n";
    print "<th class='img'>Genome Name</th>\n";
    print "<th class='img'>Genes</th>\n";
    print "</tr>\n";

    my $dbh = WebUtil::dbLogin();

    # genome -> gene counts
    my %gene_h;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
		select g.taxon, count(distinct ann.gene_oid)
		    from gene g, gene_myimg_functions ann
		where g.gene_oid = ann.gene_oid
		    and ann.modified_by = ?
		    $taxon_cond
		    $rclause
		    $imgClause
		group by g.taxon
	};
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ( $taxon_oid, $g_cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        $gene_h{$taxon_oid} = $g_cnt;
    }
    $cur->finish();

    # get permission condition clause
    my @taxon_per = ();
    my $sql       = QueryUtil::getContactTaxonPermissionSql();
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ($t_oid) = $cur->fetchrow();
        last if !$t_oid;

        push @taxon_per, ($t_oid);
    }
    $cur->finish();

    # genome -> user count
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
		select tx.taxon_oid, tx.taxon_name, count(distinct ann.modified_by)
		from taxon tx, gene g, gene_myimg_functions ann
		where tx.taxon_oid = g.taxon
		    and g.gene_oid = ann.gene_oid
		    and ann.modified_by = ?
		    $taxon_cond
		    $rclause
		    $imgClause
		group by tx.taxon_oid, tx.taxon_name
		order by tx.taxon_oid
	};

    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my $cnt0 = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        $cnt0++;

        print "<tr class='img' >\n";
        print "<td class='img' >\n";
        print "<input type='checkbox' name='taxon_oid' value='$taxon_oid' />\n";
        print "</td>\n";

        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        print "<td class='img' >" . alink( $url, $taxon_oid ) . "</td>\n";

        print "<td class='img'>" . escapeHTML($taxon_name) . "</td>\n";

        # gene counts
        if ( $gene_h{$taxon_oid} ) {
            my $url =
              "$main_cgi?section=MyIMG" . "&page=annotationsForGenome&taxon_oid=$taxon_oid" . "&user_id=$contact_oid";
            print "<td class='img' >" . alink( $url, $gene_h{$taxon_oid} ) . "</td>\n";
        } else {
            print "<td class='img'>0</td>\n";
        }

        print "<tr/>\n";
    }
    $cur->finish();

    print "</table>\n";

    #$dbh->disconnect();

    my @my_groups = DataEntryUtil::db_getImgGroups($contact_oid);
    if ( $cnt0 > 0 && scalar(@my_groups) > 0 ) {
        print "<h2>Update My Annotation Sharing in Selected Genome(s)</h2>\n";
        print
"<p>Share or remove sharing of all my annotations in selected genome(s). <b>(Note: You will have to select <u>all</u> groups included in your previous sharing; otherwise the sharing will be removed.)</b>\n";
        print "<p>\n";

        print
"<p><b>Option:</b> <input type='radio' name='taxon_myimg_mode' value='private' checked />Remove group sharing for all my private annotations<br/>\n";
        print nbsp(6)
          . "<input type='radio' name='taxon_myimg_mode' value='group' />Share all my annotations with selected group(s)<br/>\n";
        for my $g1 (@my_groups) {
            my ( $g_id, $g_name ) = split( /\t/, $g1 );
            print nbsp(10) . "<input type='checkbox' name='share_w_group' value='$g_id'>$g_name<br/>\n";
        }

        my $name = "_section_${section}_dbShareTaxonMyIMG";
        print submit(
            -name  => $name,
            -value => "Update Sharing",
            -class => "medbutton"
        );
    }

    WebUtil::printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printAllGenomeAnnotationForm
############################################################################
sub printAllGenomeAnnotationForm {
    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }
    my $super_user_flag = getSuperUser();

    my $user_id    = param('user_id');
    my $u_name     = "";
    my $taxon_oid  = param('taxon_oid');
    my $taxon_cond = "";

    if ( !blankStr($user_id) ) {
        my $dbh = WebUtil::dbLogin();
        $u_name = DataEntryUtil::db_findVal( $dbh, 'CONTACT', 'contact_oid', $user_id, 'username', "" );
        if ( !blankStr($taxon_oid) ) {
            print "<h2>Genome $taxon_oid Annotations by User " . escapeHTML($u_name) . "</h2>\n";
        } else {
            print "<h2>Genomes with Annotations by User " . escapeHTML($u_name) . "</h2>\n";
        }

        #$dbh->disconnect();

        print "<p>\n";

        if ( !blankStr($taxon_oid) ) {
            print WebUtil::hiddenVar( 'taxon_oid', $taxon_oid );
            print "<p>View user annotations on genome $taxon_oid. ";
            $taxon_cond = " and g.taxon = $taxon_oid ";
        } else {
            print "<p>View user annotations on genomes. ";
        }

        print WebUtil::hiddenVar( 'user_id',   $user_id );
        print WebUtil::hiddenVar( 'user_name', $u_name );
    } else {
        if ( $super_user_flag ne 'Yes' ) {
            WebUtil::webError("You cannot view genome annotations by all users");
        }

        print "<h2>All Genome Annotations</h2>\n";
        print "<p>\n";
        print "<p>View or Compare different user annotations on genome(s). ";
    }

    print
"Select one or more genomes and click the 'View Annotations on Genome(s)' button to see annotations on selected genome(s).</p>\n";

    WebUtil::printStatusLine( "Loading ...", 1 );

    my $name = "_section_${section}_selectedAnnotations";
    print submit(
        -name  => $name,
        -value => "View Annotations on Genome(s)",
        -class => 'meddefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";
    print "<p>\n";

    print "<table class='img' border='1'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Taxon ID</th>\n";
    print "<th class='img'>Genome Name</th>\n";
    print "<th class='img'>Genes</th>\n";
    print "<th class='img'>Users</th>\n";
    print "</tr>\n";

    my $dbh = WebUtil::dbLogin();

    # genome -> gene counts
    my $user_cond = "";
    if ( !blankStr($user_id) ) {
        $user_cond = " and ann.modified_by = $user_id ";
    }
    my %gene_h;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
		select g.taxon, count(distinct ann.gene_oid)
		from gene g, gene_myimg_functions ann
		where g.gene_oid = ann.gene_oid
		    $user_cond
		    $taxon_cond
		    $rclause
		    $imgClause
		group by g.taxon
	};
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $g_cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        $gene_h{$taxon_oid} = $g_cnt;
    }
    $cur->finish();

    # get permission condition clause
    my @taxon_per = ();
    my $sql       = QueryUtil::getContactTaxonPermissionSql();
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ($t_oid) = $cur->fetchrow();
        last if !$t_oid;

        push @taxon_per, ($t_oid);
    }
    $cur->finish();

    my $super_user_flag = getSuperUser();
    my $rclause         = "";
    if ( $super_user_flag eq 'Yes' ) {

        # super user can view all
    } elsif ( scalar(@taxon_per) == 0 ) {
        $rclause = " and tx.is_public = 'Yes' ";
    } elsif ( scalar(@taxon_per) <= 1000 ) {
        $rclause = " and (tx.is_public = 'Yes' or tx.taxon_oid in (";
        my $is_first = 1;
        for my $t_oid (@taxon_per) {
            if ($is_first) {
                $is_first = 0;
            } else {
                $rclause .= ", ";
            }
            $rclause .= $t_oid;
        }
        $rclause .= ")) ";
    } else {
        $rclause = WebUtil::urClause('tx');
    }

    # genome -> user count
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
		select tx.taxon_oid, tx.taxon_name, count(distinct ann.modified_by)
		from taxon tx, gene g, gene_myimg_functions ann
		where tx.taxon_oid = g.taxon
		    and g.gene_oid = ann.gene_oid
                    $user_cond
                    $taxon_cond
                    $rclause
                    $imgClause
		group by tx.taxon_oid, tx.taxon_name
		order by tx.taxon_oid
	};

    #   print "<p>SQL: $sql</p>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        print "<tr class='img' >\n";
        print "<td class='img' >\n";
        print "<input type='checkbox' name='taxon_oid' value='$taxon_oid' />\n";
        print "</td>\n";

        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        print "<td class='img' >" . alink( $url, $taxon_oid ) . "</td>\n";

        print "<td class='img'>" . escapeHTML($taxon_name) . "</td>\n";

        # gene counts
        if ( $gene_h{$taxon_oid} ) {
            my $url = "$main_cgi?section=MyIMG" . "&page=annotationsForGenome&taxon_oid=$taxon_oid";
            if ( !blankStr($user_id) ) {
                $url .= "&user_id=$user_id";
            }
            print "<td class='img' >" . alink( $url, $gene_h{$taxon_oid} ) . "</td>\n";
        } else {
            print "<td class='img'>0</td>\n";
        }

        # user name or user count
        if ( !blankStr($u_name) ) {
            print "<td class='img'>$u_name</td>\n";
        } elsif ( $cnt > 0 ) {
            my $url = "$main_cgi?section=MyIMG" . "&page=usersList&taxon_oid=$taxon_oid";
            if ( !blankStr($user_id) ) {
                $url .= "&user_id=$user_id";
            }
            print "<td class='img' >" . alink( $url, $cnt ) . "</td>\n";
        } else {
            print "<td class='img'>0</td>\n";
        }

        print "<tr/>\n";
    }
    $cur->finish();

    print "</table>\n";

    #$dbh->disconnect();

    WebUtil::printStatusLine( "Loaded.", 2 );

    print end_form();
}

############################################################################
# printShowGeneAnnotationForm  ???????
############################################################################
sub printShowGeneAnnotationForm {
    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }
    my $super_user_flag = getSuperUser();

    # get gene_oid
    my $gene_oid = param('gene_oid');
    print "<h2>All User Annotations on Gene $gene_oid</h2>\n";
    if ( $super_user_flag ne 'Yes' ) {
        print "<p>You can also view public MyIMG annotations by other users.\n";
    }

    my $dbh = WebUtil::dbLogin();

    # basic gene information
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
	select g.gene_oid, g.gene_symbol, 
	    g.gene_display_name,
	    g.locus_tag, g.is_pseudogene
	from gene g
	where g.gene_oid = ?
	    $rclause
	    $imgClause
	};
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $g_oid, $g_symbol, $g_disp_name, $g_locus_tag, $g_is_pseudo ) = $cur->fetchrow();
    $cur->finish();

    print "<h3>Gene Information</h3>\n";
    print "<table class='img' border='1'>\n";
    printAttrRowRaw( "Gene ID",               $gene_oid );
    printAttrRowRaw( "Gene Symbol",           nbspWrap($g_symbol) );
    printAttrRowRaw( "Locus Tag",             WebUtil::escHtml($g_locus_tag) );
    printAttrRowRaw( "Original Product Name", WebUtil::escHtml($g_disp_name) );
    printAttrRowRaw( "Is Pseudo Gene?",       WebUtil::escHtml($g_is_pseudo) );
    require GeneDetail;
    GeneDetail::printEnzymes( $dbh, $gene_oid );
    print "</table>\n";

    # find annotation counts
    my $sql = "select count(*) from gene_myimg_functions " . "where gene_oid = ?";
    if ( $super_user_flag ne 'Yes' ) {
        $sql .= " and (is_public = 'Yes' or modified_by = $contact_oid) ";
    }

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($count_all) = $cur->fetchrow();
    $cur->finish();
    if ( $count_all == 0 ) {

        # no annotations
        print "<h3>There are no user annotation on this gene.</h3>\n";

        #$dbh->disconnect();
        print end_form();
        return;
    }

    WebUtil::printStatusLine( "Loading ...", 1 );

    print "<h3>User Annotations</h3>\n";

    # my annotations or public annotations, if any
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql_part1 = qq{
	select c.name, c.email, ann.gene_oid, 
	    ann.product_name, ann.ec_number,
	    ann.pubmed_id, ann.inference, ann.is_pseudogene,
	    ann.notes, ann.gene_symbol, ann.obsolete_flag, ann.is_public, 
        };
    my $sql_part2 = qq{
	from gene g, gene_myimg_functions ann, contact c
	where g.gene_oid = ann.gene_oid
	    and g.obsolete_flag = 'No'
	    and ann.modified_by = c.contact_oid
	    and ann.gene_oid = ?
	    and ann.modified_by = ?
	    $rclause
	    $imgClause
	};
    my $sql_mysql = qq{
	$sql_part1
	date_format( ann.mod_date, '%d-%m-%Y %k:%i:%s' )
	$sql_part2
	};
    my $sql_oracle = qq{
	$sql_part1
	to_char( ann.mod_date, 'yyyy-mm-dd HH24:MI:SS' )
	$sql_part2
	};
    my $sql;
    $sql = $sql_mysql  if $rdbms eq "mysql";
    $sql = $sql_oracle if $rdbms eq "oracle";
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $contact_oid );

    my (
        $my_modified_by,   $my_email,     $my_gene_oid,      $my_annotation_text, $my_ec_number,
        $my_pubmed_id,     $my_inference, $my_is_pseudogene, $my_notes,           $my_gene_symbol,
        $my_obsolete_flag, $my_is_public, $my_add_date
      )
      = $cur->fetchrow();
    $cur->finish();

    my $count = 0;
    if ( $gene_oid && !blankStr($my_annotation_text) ) {

        # there is my annotation
        $count = 1;

        print "<p>Your annotation on this gene will be displayed in the first entry.</p>\n";

        print
"<p>If the gene has MyIMG annotations by you and by other users, other users' annoations will be displayed in <font color='red'>color red</font> if the annotations are different from yours.</p>\n";
    } else {
        print "<h4>You have not entered MyIMG annotation on this gene.</h4>\n";

        print "<p>The following lists MyIMG annotations by other user(s).</p>\n";
    }

    # print table header
    print "<table class='img'  border='1'>\n";
    print "<th class='img' >IMG Contact</th>\n";
    print "<th class='img' >Annotated Product Name</th>\n";
    print "<th class='img' >Annotated EC Number</th>\n";
    print "<th class='img' >Annotated PUBMED ID</th>\n";
    print "<th class='img' >Inference</th>\n";
    print "<th class='img' >Is Pseudo Gene?</th>\n";
    print "<th class='img' >Notes</th>\n";
    print "<th class='img' >Gene Symbol</th>\n";
    print "<th class='img' >Is Obsolete?</th>\n";
    print "<th class='img' >Is Public?</th>\n";
    print "<th class='img' >Last Modified Date</th>\n";
    print "<tr/>\n";

    if ( $count > 0 ) {

        # print my annotation
        if ($my_email) {
            $my_modified_by .= " ($my_email)";
        }
        print "<tr class='img' bgcolor='lightblue'>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_modified_by) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_annotation_text) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_ec_number) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_pubmed_id) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_inference) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_is_pseudogene) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_notes) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_gene_symbol) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_obsolete_flag) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_is_public) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($my_add_date) . "</td>\n";
        print "</tr>\n";
    }

    # get others' annotations
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql_part1 = qq{
	select c.name, c.email, ann.gene_oid, 
	    ann.product_name, ann.ec_number,
	    ann.pubmed_id, ann.inference, ann.is_pseudogene,
	    ann.notes, ann.gene_symbol, ann.obsolete_flag, ann.is_public,
	};
    my $public_clause = " and ann.is_public = 'Yes' ";
    if ( $super_user_flag eq 'Yes' ) {
        $public_clause = " ";
    }
    my $sql_part2 = qq{
	from gene g, gene_myimg_functions ann, contact c
	where g.gene_oid = ann.gene_oid
	    and g.obsolete_flag = 'No'
	    and ann.modified_by = c.contact_oid
	    and ann.gene_oid = ?
	    and ann.modified_by <> ?
            $public_clause
	    $rclause
	    $imgClause
	};
    my $sql_mysql = qq{
	$sql_part1
	date_format( ann.mod_date, '%d-%m-%Y %k:%i:%s' )
	$sql_part2
	};
    my $sql_oracle = qq{
	$sql_part1
	to_char( ann.mod_date, 'yyyy-mm-dd HH24:MI:SS' )
	$sql_part2
	};
    my $sql;
    $sql = $sql_mysql  if $rdbms eq "mysql";
    $sql = $sql_oracle if $rdbms eq "oracle";
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $contact_oid );

    for ( ; ; ) {
        my (
            $modified_by,   $c_email,   $gene_oid,      $annotation_text, $ec_number,
            $pubmed_id,     $inference, $is_pseudogene, $notes,           $gene_symbol,
            $obsolete_flag, $is_public, $add_date
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        if ($c_email) {
            $modified_by .= " ($c_email)";
        }
        print "<td class='img' >" . WebUtil::escHtml($modified_by) . "</td>\n";

        # product name
        if ( $count > 0 ) {
            printCompareAnnotField( $annotation_text, $my_annotation_text, 1 );
        } else {
            print "<td class='img' >" . WebUtil::escHtml($annotation_text) . "</td>\n";
        }

        # ec_number
        if ( $count > 0 ) {
            printCompareAnnotField( $ec_number, $my_ec_number, 2 );
        } else {
            print "<td class='img' >" . WebUtil::escHtml($ec_number) . "</td>\n";
        }

        # pubmed_id
        if ( $count > 0 ) {
            printCompareAnnotField( $pubmed_id, $my_pubmed_id, 2 );
        } else {
            print "<td class='img' >" . WebUtil::escHtml($pubmed_id) . "</td>\n";
        }

        # inference
        if (   $count > 0
            && !blankStr($inference)
            && $inference ne $my_inference )
        {
            print "<td class='img' ><font color='red'>" . WebUtil::escHtml($inference) . "</font></td>\n";
        } else {
            print "<td class='img' >" . WebUtil::escHtml($inference) . "</td>\n";
        }

        # is pseudo gene
        if (   $count > 0
            && !blankStr($is_pseudogene)
            && $is_pseudogene ne $my_is_pseudogene )
        {
            print "<td class='img' ><font color='red'>" . WebUtil::escHtml($is_pseudogene) . "</font></td>\n";
        } else {
            print "<td class='img' >" . WebUtil::escHtml($is_pseudogene) . "</td>\n";
        }

        # notes
        if (   $count > 0
            && !blankStr($notes)
            && $notes ne $my_notes )
        {
            print "<td class='img' ><font color='red'>" . WebUtil::escHtml($notes) . "</font></td>\n";
        } else {
            print "<td class='img' >" . WebUtil::escHtml($notes) . "</td>\n";
        }

        # gene_symbol
        if (   $count > 0
            && !blankStr($gene_symbol)
            && $gene_symbol ne $my_gene_symbol )
        {
            print "<td class='img' ><font color='red'>" . WebUtil::escHtml($gene_symbol) . "</font></td>\n";
        } else {
            print "<td class='img' >" . WebUtil::escHtml($gene_symbol) . "</td>\n";
        }

        # obsolete_flag
        if (   $count > 0
            && !blankStr($obsolete_flag)
            && $obsolete_flag ne $my_obsolete_flag )
        {
            print "<td class='img' ><font color='red'>" . WebUtil::escHtml($obsolete_flag) . "</font></td>\n";
        } else {
            print "<td class='img' >" . WebUtil::escHtml($obsolete_flag) . "</td>\n";
        }

        print "<td class='img' >" . WebUtil::escHtml($is_public) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($add_date) . "</td>\n";
        print "</tr>\n";
    }
    $cur->finish();

    print "</table>\n";

    #$dbh->disconnect();

    WebUtil::printStatusLine( "Loaded.", 2 );

    print end_form();
}

############################################################################
# printCompareAnnotField
# annot_type: 1 (product name), 2 (others)
############################################################################
sub printCompareAnnotField {
    my ( $other_annot, $my_annot, $annot_type ) = @_;

    if ( blankStr($other_annot) ) {

        # no user annotation
        print "<td class='img' ></td>\n";
        return;
    }

    if ( blankStr($my_annot) ) {

        # no my annotation
        print "<td class='img' ><font color='red'>" . WebUtil::escHtml($other_annot) . "</font></td>\n";
        return;
    }

    my @other_annot_arr = ();
    my @my_annot_arr    = ();

    if ( $annot_type == 1 ) {
        @other_annot_arr = split( /;/, $other_annot );
        @my_annot_arr    = split( /;/, $my_annot );
    } else {
        $other_annot =~ s/;/ /g;
        $my_annot    =~ s/;/ /g;
        @other_annot_arr = split( / /, $other_annot );
        @my_annot_arr    = split( / /, $my_annot );
    }

    print "<td class='img' >";
    my $count = 0;
    for my $s1 (@other_annot_arr) {
        next if ( blankStr($s1) );

        $s1 = WebUtil::strTrim($s1);
        my $found = 0;
        for my $s2 (@my_annot_arr) {
            if ( blankStr($s2) ) {
                next;
            }
            $s2 = WebUtil::strTrim($s2);
            if ( $s1 eq $s2 ) {
                $found = 1;
                last;
            }
        }

        if ( $count > 0 ) {
            print "; ";
        }

        if ($found) {

            # same
            print escapeHTML($s1) . ' ';
        } else {

            # different
            print "<font color='red'>" . escapeHTML($s1) . "</font> ";
        }

        $count++;
    }
    print "</td>\n";
}

############################################################################
# exportMyAnnotations
############################################################################
sub exportMyAnnotations {
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("Your login has expired.");
        return;
    }

    my @gene_oids = param('gene_oid');
    if ( scalar(@gene_oids) == 0 ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("No genes have been selected.");
        return;
    }

    # print Excel Header
    printExcelHeader("myimg_export$$.xls");

    # print attribute names
    print "Gene ID\t";
    print "Genome\t";
    print "Original Product Name\t";
    print "Annotated Product Name\t";
    print "Annotated Prot Desc\t";
    print "Annotated EC Number\t";
    print "Annotated PUBMED ID\t";
    print "Inference\t";
    print "Is Pseudo Gene?\t";
    print "Notes\t";
    print "Annotated Gene Symbol\t";
    print "Remove Gene from Genome?\t";
    print "Last Modified Date\n";

    # export data
    my $dbh = WebUtil::dbLogin();
    for my $gene_oid (@gene_oids) {
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql       = qq{
			select ann.gene_oid, ann.product_name, 
			    ann.prot_desc, ann.ec_number,
			    ann.pubmed_id, ann.inference, 
			    ann.is_pseudogene, ann.notes, 
			    ann.gene_symbol, ann.obsolete_flag,
			    to_char( ann.mod_date, 'yyyy-mm-dd HH24:MI:SS' ),
			    g.product_name, tx.taxon_display_name 
			from gene g, taxon tx, gene_myimg_functions ann
			where ann.gene_oid = ? and ann.modified_by = ?
			    and ann.gene_oid = g.gene_oid
			    and g.taxon = tx.taxon_oid
			    $rclause
			    $imgClause
		};
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $contact_oid );
        my (
            $gene_oid,  $product_name,      $prot_desc, $ec_number,   $pubmed_id,
            $inference, $is_pseudogene,     $notes,     $gene_symbol, $obsolete_flag,
            $add_date,  $gene_product_name, $taxon_display_name
          )
          = $cur->fetchrow();
        if ($gene_oid) {
            print "$gene_oid\t$taxon_display_name\t$gene_product_name\t$product_name\t$prot_desc\t$ec_number\t"
              . "$pubmed_id\t$inference\t$is_pseudogene\t$notes\t"
              . "$gene_symbol\t$obsolete_flag\t$add_date\n";
        }
        $cur->finish();
    }

    #$dbh->disconnect();
    WebUtil::webExit(0);
}

############################################################################
# printLogout - Print logout form.
############################################################################
sub printLogout {
    print start_form( -action => "$section_cgi", -name => "logoutForm" );
    print WebUtil::hiddenVar( "page", "myIMG" );
    print pageAnchor("Logout");
    print "<h3>Logout</h3>\n";
    print "<p>\n";
    print "Log out of MyIMG.\n";
    print "</p>\n";

    my $contact_oid = WebUtil::getContactOid();
    # my $name = "_section_${section}_logout";
    my $name = "logout";
    print submit(
        -name  => $name,
        -value => "Logout",
        -class => "smbutton"
    );

    my $oldLogin = getSessionParam("oldLogin");
    my $url      = "$section_cgi&page=changePasswordForm";
    print "<h3>Update Information</h3>\n";
    print "<p>\n";
    if ($oldLogin) {

        if ( $contact_oid eq "" || $contact_oid < 1 ||  $contact_oid eq '901') {
            print qq{
              <p>You are using a public account.</p>  
            };
        } else {        
        
        print alink( $url, "Change Password" ) . " &nbsp;&nbsp;";
        print qq{
            <a href="$section_cgi&page=updateContactForm"> Update Contact Information </a>
        };
        }
    } else {

        # sso
        print "JGI single sign-on &nbsp;&nbsp; \n";
        my $url = 'https://signon.jgi-psf.org/password_resets';
        print alink( $url, "Change Password" ) . " &nbsp;&nbsp;";
        my $url = 'https://signon.jgi-psf.org/user/contacts/edit';
        print alink( $url, "Update Contact Information" );
    }
    print "</p>\n";
    print WebUtil::hiddenVar( "page", "myIMG" );
    print WebUtil::hiddenVar( "form", "uploadGeneAnnotations" );
    print end_form();
}

############################################################################
# Remember cgi cache uses session params for caching see HtmlUtil.pm - ken
# gets hash of session param: sesison param => value,
############################################################################
sub getSessionParamHash {
    my $hideViruses               = getSessionParam("hideViruses");
    my $hidePlasmids              = getSessionParam("hidePlasmids");
    my $hideGFragment             = getSessionParam("hideGFragment");
    my $hideZeroStats             = getSessionParam("hideZeroStats");
    my $maxOrthologGroups         = getSessionParam("maxOrthologGroups");
    my $maxParalogGroups          = getSessionParam("maxParalogGroups");
    my $maxGeneListResults        = getSessionParam("maxGeneListResults");
    my $maxHomologResults         = getSessionParam("maxHomologResults");
    my $maxNeighborhoods          = getSessionParam("maxNeighborhoods");
    my $maxProfileCandidateTaxons = getSessionParam("maxProfileCandidateTaxons");
    my $maxProfileRows            = getSessionParam("maxProfileRows");
    my $minHomologPercentIdentity = getSessionParam("minHomologPercentIdentity");
    my $minHomologAlignPercent    = getSessionParam("minHomologAlignPercent");
    my $genePageDefaultHomologs   = getSessionParam("genePageDefaultHomologs");
    my $newGenePageDefault        = getSessionParam("newGenePageDefault");
    my $hideObsoleteTaxon         = getSessionParam("hideObsoleteTaxon");
    my $topHomologHideMetag       = getSessionParam("topHomologHideMetag");

    $hideViruses               = "Yes" if $hideViruses               eq "";
    $hidePlasmids              = "Yes" if $hidePlasmids              eq "";
    $hideGFragment             = "Yes" if $hideGFragment             eq "";
    $hideZeroStats             = "Yes" if $hideZeroStats             eq "";
    $maxGeneListResults        = 1000  if $maxGeneListResults        eq "";
    $maxHomologResults         = 200   if $maxHomologResults         eq "";
    $maxNeighborhoods          = 15    if $maxNeighborhoods          eq "";
    $maxProfileRows            = 1000  if $maxProfileRows            eq "";
    $minHomologPercentIdentity = 30    if $minHomologPercentIdentity eq "";
    $minHomologAlignPercent    = 10    if $minHomologAlignPercent    eq "";
    $newGenePageDefault        = "No"  if $newGenePageDefault        eq "";
    $hideObsoleteTaxon         = "Yes" if $hideObsoleteTaxon         eq "";
    $topHomologHideMetag       = "No"  if $topHomologHideMetag       eq "";

    # userCacheEnable param was skipped on purpose - ken
    # genomeListColPrefs param was skipped on purpose - ken

    my %sessionParamHash = (
        "hideViruses"               => $hideViruses,
        "hidePlasmids"              => $hidePlasmids,
        "hideGFragment"             => $hideGFragment,
        "hideZeroStats"             => $hideZeroStats,
        "maxOrthologGroups"         => $maxOrthologGroups,
        "maxParalogGroups"          => $maxParalogGroups,
        "maxGeneListResults"        => $maxGeneListResults,
        "maxHomologResults"         => $maxHomologResults,
        "maxNeighborhoods"          => $maxNeighborhoods,
        "maxProfileCandidateTaxons" => $maxProfileCandidateTaxons,
        "maxProfileRows"            => $maxProfileRows,
        "minHomologPercentIdentity" => $minHomologPercentIdentity,
        "minHomologAlignPercent"    => $minHomologAlignPercent,
        "genePageDefaultHomologs"   => $genePageDefaultHomologs,
        "newGenePageDefault"        => $newGenePageDefault,
        "hideObsoleteTaxon"         => $hideObsoleteTaxon,
        "topHomologHideMetag"       => $topHomologHideMetag,
    );
    return \%sessionParamHash;
}

############################################################################
# printPreferences - Show preferences form.
############################################################################
sub printPreferences {
    my $maxOrthologGroups         = getSessionParam("maxOrthologGroups");
    my $maxParalogGroups          = getSessionParam("maxParalogGroups");
    my $maxGeneListResults        = getSessionParam("maxGeneListResults");
    my $maxHomologResults         = getSessionParam("maxHomologResults");
    my $maxNeighborhoods          = getSessionParam("maxNeighborhoods");
    my $maxProfileCandidateTaxons = getSessionParam("maxProfileCandidateTaxons");
    my $maxProfileRows            = getSessionParam("maxProfileRows");
    my $minHomologPercentIdentity = getSessionParam("minHomologPercentIdentity");
    my $minHomologAlignPercent    = getSessionParam("minHomologAlignPercent");
    my $genePageDefaultHomologs   = getSessionParam("genePageDefaultHomologs");
    my $hideViruses               = getSessionParam("hideViruses");
    my $hidePlasmids              = getSessionParam("hidePlasmids");
    my $hideGFragment             = getSessionParam("hideGFragment");
    my $newGenePageDefault        = getSessionParam("newGenePageDefault");

    # for taxon editor
    my $hideObsoleteTaxon = getSessionParam("hideObsoleteTaxon");

    # Hide rows with zeroes in Genome browser > Genome Statistics
    my $hideZeroStats = getSessionParam("hideZeroStats");

    $maxGeneListResults        = 1000  if $maxGeneListResults        eq "";
    $maxHomologResults         = 200   if $maxHomologResults         eq "";
    $maxNeighborhoods          = 5     if $maxNeighborhoods          eq "";
    $maxProfileRows            = 1000  if $maxProfileRows            eq "";
    $minHomologPercentIdentity = 30    if $minHomologPercentIdentity eq "";
    $minHomologAlignPercent    = 10    if $minHomologAlignPercent    eq "";
    $hideViruses               = "Yes" if $hideViruses               eq "";
    $hidePlasmids              = "Yes" if $hidePlasmids              eq "";
    $hideGFragment             = "Yes" if $hideGFragment             eq "";
    $newGenePageDefault        = "No"  if $newGenePageDefault        eq "";

    #$includeObsoleteGenes      = "No"  if $includeObsoleteGenes      eq "";
    $hideObsoleteTaxon = "Yes" if $hideObsoleteTaxon eq "";
    $hideZeroStats     = "Yes" if $hideZeroStats     eq "";

    # cgi cache a preferenc to turn off iff on
    # users cannot turn it on if off in config - ken
    my $userCacheEnable;
    if ($cgi_cache_enable) {
        $userCacheEnable = getSessionParam("userCacheEnable");
        $userCacheEnable = "Yes"
          if ( $userCacheEnable eq "" );    # it was never set
    }

    my $genomeListColPrefs;
    if ($user_restricted_site) {
        $genomeListColPrefs = getSessionParam("genomeListColPrefs");
        $genomeListColPrefs = "No" if ( $genomeListColPrefs eq "" );
    }

    my $topHomologHideMetag;
    if ( $include_metagenomes && $img_internal ) {
        $topHomologHideMetag = getSessionParam("topHomologHideMetag");
        $topHomologHideMetag = "No"
          if ( $topHomologHideMetag eq "" );    # it was never set
    }

    print pageAnchor("Preferences");
    print start_form( -name => "preferencesForm", -action => "$section_cgi" );
    print "<h2>Preferences</h2>\n";
    if ($user_restricted_site) {
        print qq{
            <p>
            Your preferences will be saved in the Workspace and it will be used the next time
            you login.
            </p>
        };
    }

    # Use YUI css
    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

	    <div class='yui-dt'>
	    <table style='font-size:12px'>
	    <th>
 	    <div class='yui-dt-liner'>
	    <span>Parameter</span>
	    </div>
	    </th>
	    <th>
 	    <div class='yui-dt-liner'>
	    <span>Current Setting</span>
	    </div>
	    </th>

YUI
    } else {
        print "<table class='img' border='1'>\n";
    }

    my $idx = 0;
    my $classStr;

    if ($yui_tables) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    } else {
        $classStr = "img";
    }

    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "Max. Paralog Groups";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print popup_menu(
        -name    => "maxParalogGroups",
        -values  => [ "500", "1000", "2000", "10000" ],
        -default => "$maxParalogGroups"
    );
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    $idx++;
    if ($yui_tables) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    } else {
        $classStr = "img";
    }

    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "Max. Gene / Scaffold List Results";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print popup_menu(
        -name    => "maxGeneListResults",
        -values  => [ "100", "200", "1000", "2000", "5000", "10000", "20000" ],
        -default => "$maxGeneListResults"
    );
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    $idx++;
    if ($yui_tables) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    } else {
        $classStr = "img";
    }

    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "Max. Homolog Results";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print popup_menu(
        -name    => "maxHomologResults",
        -values  => [ "100", "200", "1000", "2000", "5000", "10000", "20000" ],
        -default => "$maxHomologResults"
    );
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    $idx++;
    if ($yui_tables) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    } else {
        $classStr = "img";
    }

    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "Max. Taxon Gene Neighborhoods";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print popup_menu(
        -name    => "maxNeighborhoods",
        -values  => [ "3", "5", "10", "15", "20", "40" ],
        -default => "$maxNeighborhoods"
    );
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    $idx++;
    if ($yui_tables) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    } else {
        $classStr = "img";
    }

    $idx++;
    if ($yui_tables) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    } else {
        $classStr = "img";
    }

    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "Min. Homolog Percent Identity";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print popup_menu(
        -name    => "minHomologPercentIdentity",
        -values  => [ "10", "20", "30", "40", "50", "60", "70", "80", "90" ],
        -default => "$minHomologPercentIdentity"
    );
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    $idx++;
    if ($yui_tables) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    } else {
        $classStr = "img";
    }

    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "Hide Viruses From Genome Lists";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print popup_menu(
        -name    => "hideViruses",
        -values  => [ "Yes", "No" ],
        -default => "$hideViruses"
    );
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    if ($include_plasmids) {
        $idx++;
        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        print "<tr class='$classStr' >\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "Hide Plasmids From Genome Lists";
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print popup_menu(
            -name    => "hidePlasmids",
            -values  => [ "Yes", "No" ],
            -default => "$hidePlasmids"
        );
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";
    }

    $idx++;
    if ($yui_tables) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    } else {
        $classStr = "img";
    }

    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "Hide GFragment From Genome Lists";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print popup_menu(
        -name    => "hideGFragment",
        -values  => [ "Yes", "No" ],
        -default => "$hideGFragment"
    );
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    if ($img_taxon_edit) {
        $idx++;
        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        # $hideObsoleteTaxon
        print "<tr class='$classStr' >\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "Hide Obsolete Genomes";
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print popup_menu(
            -name    => "hideObsoleteTaxon",
            -values  => [ "Yes", "No" ],
            -default => "$hideObsoleteTaxon"
        );
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";
    }

    # Option to hide rows with zeroes in Genome browser > Genome Statistics
    $idx++;
    if ($yui_tables) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    } else {
        $classStr = "img";
    }
    print "<tr class='$classStr' >\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "Hide Zeroes in Genome Statistics";
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print popup_menu(
        -name    => "hideZeroStats",
        -values  => [ "Yes", "No" ],
        -default => "$hideZeroStats"
    );
    print "</div>\n" if $yui_tables;
    print "</td>\n";
    print "</tr>\n";

    # hide metagenomes in top homolog results
    if ( $include_metagenomes && $img_internal ) {
        $idx++;
        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }
        print "<tr class='$classStr' >\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "Hide Metagenomes in Top Homologs Results";
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print popup_menu(
            -name    => "topHomologHideMetag",
            -values  => [ "Yes", "No" ],
            -default => "$topHomologHideMetag"
        );
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";
    }

    # let user turn off cache if enable in config file
    if ($cgi_cache_enable) {
        $idx++;
        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }
        print "<tr class='$classStr' >\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "Session Cache On (Yes recommended)";
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print popup_menu(
            -name    => "userCacheEnable",
            -values  => [ "Yes", "No" ],
            -default => "$userCacheEnable"
        );
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";
    }

    if ($user_restricted_site) {
        $idx++;
        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }
        print "<tr class='$classStr' >\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "Save Genome List Column Prefs";
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print popup_menu(
            -name    => "genomeListColPrefs",
            -values  => [ "Yes", "No" ],
            -default => "$genomeListColPrefs"
        );
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";
    }

    print "</table>\n";
    print "</div>\n" if $yui_tables;

    print "<p>\n";

    #print WebUtil::hiddenVar( "page", "preferencesForm" );
    #print WebUtil::hiddenVar( "page", "message" );
    print WebUtil::hiddenVar( "message",       "Preferences saved." );
    print WebUtil::hiddenVar( "menuSelection", "Preferences" );
    my $name = "_section_${section}_setPreferences";
    print submit(
        -name  => $name,
        -value => "Save Preferences",
        -class => 'smdefbutton'
    );

    #print reset( );
    print nbsp(1);

    #print reset( -value => "Reset", -class => "smbutton" );

    # js code in header.js
    print "<input type='button' value='Default Settings' " . "onClick='resetPreferences()' class='smbutton' />\n";
    print "<p>\n";
    my $s = "For faster processing, adjust to lower numbers.\n";
    $s .= "For more complete result lists, adjust to higher numbers.\n";
    $s .= "The default settings should work well for most users.\n";
    printHint($s);

    #	my $contact_oid = WebUtil::getContactOid();
    #	if ( $show_myimg_login && $contact_oid > 0 ) {
    #		printMyIMGPreferences();
    #	}

    print end_form();
}

############################################################################
# doSetPreferences - Handle settting of preferences after submission.
############################################################################
sub doSetPreferences {
    my $maxOrthologGroups         = param("maxOrthologGroups");
    my $maxParalogGroups          = param("maxParalogGroups");
    my $maxGeneSearchResults      = param("maxGeneSearchResults");
    my $maxGeneListResults        = param("maxGeneListResults");
    my $maxHomologResults         = param("maxHomologResults");
    my $maxNeighborhoods          = param("maxNeighborhoods");
    my $maxProfileCandidateTaxons = param("maxProfileCandidateTaxons");
    my $maxProfileRows            = param("maxProfileRows");
    my $minHomologPercentIdentity = param("minHomologPercentIdentity");
    my $minHomologAlignPercent    = param("minHomologAlignPercent");
    my $genePageDefaultHomologs   = param("genePageDefaultHomologs");
    my $hideViruses               = param("hideViruses");
    my $hidePlasmids              = param("hidePlasmids");
    my $hideGFragment             = param("hideGFragment");
    my $hideObsoleteTaxon         = param("hideObsoleteTaxon");
    my $newGenePageDefault        = param("newGenePageDefault");
    my $hideZeroStats             = param("hideZeroStats");

    #my $includeObsoleteGenes = param( "includeObsoleteGenes" );
    setSessionParam( "maxOrthologGroups",         $maxOrthologGroups );
    setSessionParam( "maxParalogGroups",          $maxParalogGroups );
    setSessionParam( "maxGeneSearchResults",      $maxGeneSearchResults );
    setSessionParam( "maxGeneListResults",        $maxGeneListResults );
    setSessionParam( "maxHomologResults",         $maxHomologResults );
    setSessionParam( "maxNeighborhoods",          $maxNeighborhoods );
    setSessionParam( "maxProfileCandidateTaxons", $maxProfileCandidateTaxons );
    setSessionParam( "maxProfileRows",            $maxProfileRows );
    setSessionParam( "minHomologPercentIdentity", $minHomologPercentIdentity );
    setSessionParam( "minHomologAlignPercent",    $minHomologAlignPercent );
    setSessionParam( "genePageDefaultHomologs",   $genePageDefaultHomologs );
    setSessionParam( "hideViruses",               $hideViruses );
    setSessionParam( "hidePlasmids",              $hidePlasmids );
    setSessionParam( "hideGFragment",             $hideGFragment );
    setSessionParam( "hideObsoleteTaxon",         $hideObsoleteTaxon );
    setSessionParam( "newGenePageDefault",        $newGenePageDefault );
    setSessionParam( "hideZeroStats",             $hideZeroStats );

    my $hashPrefs = getSessionParamHash();

    if ($cgi_cache_enable) {
        my $userCacheEnable = param("userCacheEnable");
        setSessionParam( "userCacheEnable", $userCacheEnable );
        $hashPrefs->{"userCacheEnable"} = $userCacheEnable;
    }

    if ($user_restricted_site) {
        my $genomeListColPrefs = param("genomeListColPrefs");
        setSessionParam( "genomeListColPrefs", $genomeListColPrefs );
        $hashPrefs->{"genomeListColPrefs"} = $genomeListColPrefs;
    }

    if ( $include_metagenomes && $img_internal ) {
        my $topHomologHideMetag = param("topHomologHideMetag");
        setSessionParam( "topHomologHideMetag", $topHomologHideMetag );
        $hashPrefs->{"topHomologHideMetag"} = $topHomologHideMetag;
    }

    if ( $env->{user_restricted_site} ) {
        require Workspace;
        Workspace::saveUserPreferences($hashPrefs);
    }

    #setSessionParam( "includeObsoleteGenes", $includeObsoleteGenes );

    print "<div id='message'>\n";
    print "<p>\n";
    print "Preferences set. <span style='color:red'>Reload relevant " . "pages for new settings to take effect.</span>\n";
    print "</p>\n";
    print "</div>\n";

    printPreferences();
}

# load user prefs from workspace
sub loadUserPreferences {
    if ( $env->{user_restricted_site} ) {
        require Workspace;
        my $href = Workspace::loadUserPreferences();
        foreach my $key ( keys %$href ) {
            my $value = $href->{$key};
            setSessionParam( $key, $value );
        }
    }
}

############################################################################
# printMyIMGPreferences - MyIMG preference
#                         (for gene product name display)
############################################################################
sub printMyIMGPreferences {
    if ( !$show_myimg_login ) {
        return;
    }

    my $contact_oid = WebUtil::getContactOid();
    if ( DataEntryUtil::db_isPublicUser($contact_oid) ) {
        return;
    }

    print "<h2>MyIMG Preference</h2>\n";

    # get preference from database
    my $dbh      = WebUtil::dbLogin();
    my $userPref = WebUtil::getMyIMGPref( $dbh, "MYIMG_PROD_NAME" );

    #$dbh->disconnect();

    print "<p>\n";

    # select
    print "<input type='checkbox' ";
    print "name='MYIMG_PROD_NAME' value='MYIMG_PROD_NAME' ";
    if ( blankStr($userPref) || lc($userPref) eq 'yes' ) {
        print "checked ";
    }
    print "/>\n";
    print nbsp(1);
    print "Display my annotated Product Name as Gene Product Name (if applicable).\n";
    print "<br/>\n";

    print "</p>\n";
    my $name = "_section_${section}_saveMyIMGPref";
    print submit(
        -name  => $name,
        -value => "Save MyIMG Preference to Database",
        -class => 'lgdefbutton'
    );

}

############################################################################
# doSaveMyIMGPref - save MyIMG Preference to database
############################################################################
#sub doSaveMyIMGPref {
#    my $contact_oid = WebUtil::getContactOid();
#    if ( blankStr($contact_oid) ) {
#	WebUtil::webError("Your login has expired.");
#    }
#
#    # get preference from database
#    my $tag = 'MYIMG_PROD_NAME';
#    my $dbh = WebUtil::dbLogin();
#    my $dbPref =
#	DataEntryUtil::db_findVal( $dbh, 'CONTACT_MYIMG_PREFS', 'contact_oid', $contact_oid,
#		    'value', "tag = '$tag'" );
#    #$dbh->disconnect();
#    if ( blankStr($dbPref) ) {
#
#	# set default
#	$dbPref = 'Yes';
#    }
#
#    # get user's current selection
#    my $userPref;
#    if ( param($tag) ) {
#	$userPref = 'Yes';
#    }
#    else {
#	$userPref = 'No';
#    }
#
#    if ( $dbPref eq $userPref ) {
#	return 0;
#    }
#
#    # update database
#    my @sqlList = ();
#    my $sql     = "delete from CONTACT_MYIMG_PREFS "
#	. "where contact_oid = $contact_oid and tag = 'MYIMG_PROD_NAME'";
#    push @sqlList, ($sql);
#
#    $sql =
#	"insert into CONTACT_MYIMG_PREFS "
#	. "(contact_oid, tag, value) "
#	. "values ($contact_oid, 'MYIMG_PROD_NAME', '$userPref')";
#    push @sqlList, ($sql);
#
#    # perform database update
#    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
#    if ($err) {
#	$sql = $sqlList[ $err - 1 ];
#	WebUtil::webError("SQL Error: $sql");
#	return 0;
#    }
#
#    # need to update gene cart
#    my $gc        = new GeneCartStor();
#    my $recs      = $gc->readCartFile(); # get records
#    my @gene_oids = sort { $a <=> $b } keys(%$recs);
#    if ( scalar(@gene_oids) == 0 ) {
#	return 1;
#    }
#
#    # update product names in gene carts
#    $gc->addGeneBatch( \@gene_oids );
#
#    return 1;
#}

############################################################################
# printGeneCartUploadForm - Print gene cart upload form.
############################################################################
sub printGeneCartUploadForm {
    print start_multipart_form(
        -name   => "geneCartUploadForm",
        -action => "$section_cgi"
    );
    print pageAnchor("Upload Gene Cart");
    print "<h2>My Genes: Upload Gene Cart</h2>\n";

    print "<p>\n";
    print "You may upload a tab delimited file containing genes\n";
    print "into the gene cart.<br/>\n";
    print "The file should have the column header 'gene_oid'.<br/>\n";
    print "(This file may initially be obtained " . "from the gene cart export to Excel.)<br/>\n";
    print "<br/>\n";

    print "File to upload:<br/>\n";
    print "<input type='file' name='uploadFile' size='45'/>\n";

    print "<br/>\n";
    my $name = "_section_GeneCartStor_uploadGeneCart";
    print submit(
        -name  => $name,
        -value => "Upload Gene Cart",
        -class => "medbutton"
    );
    print "</p>\n";
    print end_form();
}

############################################################################
# printFuncCartUploadForm - Print function cart upload form.
############################################################################
sub printFuncCartUploadForm {
    print start_multipart_form(
        -name   => "funcCartUploadForm",
        -action => "$section_cgi"
    );
    print pageAnchor("Upload Function Cart");
    print "<h2>My Functions: Upload Function Cart</h2>\n";

    print "<p>\n";
    print "You may upload a tab delimited file containing functions\n";
    print "into the function cart.<br/>\n";
    print "The file should have the column header 'func_id'<br/>\n";
    print "(This file may initially be obtained " . "from the function cart export to Excel.)<br/>\n";
    print "<br/>\n";

    print "File to upload:<br/>\n";
    print "<input type='file' name='uploadFile' size='45'/>\n";

    print "<br/>\n";
    my $name = "_section_FuncCartStor_uploadFuncCart";
    print submit(
        -name  => $name,
        -value => "Upload Function Cart",
        -class => "medbutton"
    );
    print "</p>\n";
    print end_form();
}

############################################################################
# printMyAnnotationsForm
############################################################################
sub printMyAnnotationsForm {
    print "<br>";
    print "<h1>IMG User Annotations</h1>\n";

    my $contact_oid = WebUtil::getContactOid();

    if ( DataEntryUtil::db_isPublicUser($contact_oid) ) {

        # public user
        print qq{
            <h4>Public User cannot add or view MyIMG annotations.</h4>\n
            <p>(If you want to become a registered user, 
            <A href="main.cgi?page=requestAcct">request an account here</A>\n
           )</p>\n
        };
    } else {

        # registered user
        print "<p>You can view annotations, or upload annotations from flat files.</p>\n";
        printViewMyAnnotationsForm();
    }
}

############################################################################
# uploadOidsFromFile - Upload oids from file and return oid list.
#
# $oid_attr2, $oids_href2 - for scaffold cart cart name and return hash- ken
############################################################################
sub uploadOidsFromFile {
    my ( $oid_attrs_str, $oids_ref, $errmsg_ref, $oid_attr2, $oids_href2 ) = @_;

    # split ',' separated multiple attrs:
    my @oid_attrs = processParamValue($oid_attrs_str);

    my $fh = upload("uploadFile");
    if ( $fh && cgi_error() ) {
        WebUtil::webError( header( -status => cgi_error() ) );
    }
    my $mimetype = uploadInfo($fh);

    #webLog Dumper $mimetype;
    # Need line broken buffer through tmpFile.
    my $tmpFile   = "$cgi_tmp_dir/upload$$.tab.txt";
    my $wfh       = newWriteFileHandle( $tmpFile, "uploadOidsFromFile" );
    my $file_size = 0;
    while ( my $s = <$fh> ) {
        $s =~ s/\r/\n/g;
        $file_size += length($s);
        if ( $file_size > $max_upload_size ) {
            $$errmsg_ref = "Maximum file size $max_upload_size bytes exceeded.";
            close $wfh;
            wunlink($tmpFile);
            return 0;
        }
        print $wfh $s;
    }
    close $wfh;
    if ( $file_size == 0 ) {
        $$errmsg_ref = "No contents were found to upload. (File: $tmpFile)";
        close $wfh;
        wunlink($tmpFile);
        return 0;
    }
    my $rfh = newReadFileHandle( $tmpFile, "uploadOidsFromFile" );
    my $s = $rfh->getline();
    chomp $s;
    my (@fields) = split( /\t/, $s );
    my $nFields = @fields;
    my $oid_idx  = -1;    # locating of the oid column
    my $oid_attr = '';

    for ( my $i = 0 ; $i < $nFields ; $i++ ) {
        my $fieldName = $fields[$i];

        #print "uploadOidsFromFile() fieldName: $fieldName<br/>\n";
        if ( scalar(@oid_attrs) > 0 ) {
            foreach my $oidAttr (@oid_attrs) {
                if ( $oidAttr ne '' && lc($fieldName) eq lc($oidAttr) ) {
                    $oid_idx  = $i;
                    $oid_attr = $oidAttr;
                    last;
                }
            }
        }
        last if ( $oid_idx >= 0 );
    }

    # scaffold cart name
    my $cart_name_idx = -1;
    if ( $oid_attr2 ne "" ) {
        for ( my $i = 0 ; $i < $nFields ; $i++ ) {
            my $fieldName = $fields[$i];
            if ( $fieldName eq $oid_attr2 ) {
                $cart_name_idx = $i;
                last;
            }
        }
    }

    if ( $oid_idx < 0 ) {
        wunlink($tmpFile);
        my $oid_attrs_or = '';
        if ( scalar(@oid_attrs) > 0 ) {
            foreach my $oidAttr (@oid_attrs) {
                $oid_attrs_or .= ' or ' if ( $oid_attrs_or ne '' );
                $oid_attrs_or .= "'$oidAttr'";
            }
        }
        ## --es 05/05/2005 More notes on error message.
        my $x = $tabDelimErrMsg;
        $$errmsg_ref = "The file requires a column header " . "with the keyword $oid_attrs_or.<br/>$x\n";
        return 0;
    }

    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my (@vals) = split( /\t/, $s );
        my $oid_val = $vals[$oid_idx];
        next if blankStr($oid_val);
        if ( !isInt($oid_val) || $oid_val <= 0 ) {
            close $rfh;
            wunlink($tmpFile);
            $$errmsg_ref = "Invalid value for '$oid_val' for '$oid_attr'\n";
            return 0;
        }
        push( @$oids_ref, $oid_val );
        if ( $cart_name_idx > -1 ) {

            # scaffold cart name
            my $cart_name = $vals[$cart_name_idx];
            $oids_href2->{$oid_val} = $cart_name;
        }
    }
    close $rfh;
    wunlink($tmpFile);
    ## --es 05/05/2005 Check that import has at least one entry.
    if ( scalar(@$oids_ref) == 0 ) {
        $$errmsg_ref = "No values were uploaded.";
        return 0;
    }
    return 1;
}

############################################################################
# uploadIdsFromFile - Upload string ID's from file and return id list.
############################################################################
sub uploadIdsFromFile {
    my ( $id_attrs_str, $ids_ref, $errmsg_ref ) = @_;

    # split ',' separated multiple attrs:
    my @id_attrs = processParamValue($id_attrs_str);

    my $fh = upload("uploadFile");
    if ( $fh && cgi_error() ) {
        WebUtil::webError( header( -status => cgi_error() ) );
    }
    my $mimetype = uploadInfo($fh);

    #webLog Dumper $mimetype;
    # Need line broken buffer through tmpFile.
    my $tmpFile   = "$cgi_tmp_dir/upload$$.tab.txt";
    my $wfh       = newWriteFileHandle( $tmpFile, "uploadOidsFromFile" );
    my $file_size = 0;
    while ( my $s = <$fh> ) {
        $s =~ s/\r/\n/g;
        $file_size += length($s);
        if ( $file_size > $max_upload_size ) {
            $$errmsg_ref = "Maximum file size $max_upload_size bytes exceeded.";
            close $wfh;
            wunlink($tmpFile);
            return 0;
        }
        print $wfh $s;
    }
    close $wfh;
    if ( $file_size == 0 ) {
        $$errmsg_ref = "No contents were found to upload.";
        close $wfh;
        wunlink($tmpFile);
        return 0;
    }
    my $rfh = newReadFileHandle( $tmpFile, "uploadIdsFromFile" );
    my $s = $rfh->getline();
    chomp $s;
    my (@fields) = split( /\t/, $s );
    my $nFields  = @fields;
    my $id_idx   = -1;
    for ( my $i = 0 ; $i < $nFields ; $i++ ) {
        my $fieldName = $fields[$i];

        #print "uploadIdsFromFile() fieldName: $fieldName<br/>\n";
        if ( scalar(@id_attrs) > 0 ) {
            foreach my $idAttr (@id_attrs) {
                if ( $idAttr ne '' && lc($fieldName) eq lc($idAttr) ) {
                    $id_idx = $i;

                    #$id_attr = $idAttr;
                    last;
                }
            }
        }
        last if ( $id_idx >= 0 );
    }

    if ( $id_idx < 0 ) {
        wunlink($tmpFile);
        my $id_attrs_or = '';
        if ( scalar(@id_attrs) > 0 ) {
            foreach my $idAttr (@id_attrs) {
                $id_attrs_or .= ' or ' if ( $id_attrs_or ne '' );
                $id_attrs_or .= "'$idAttr'";
            }
        }
        ## --es 05/05/2005 More notes on error message.
        my $x = $tabDelimErrMsg;
        $$errmsg_ref = "The file requires a column header " . "with the keyword $id_attrs_or.<br/>$x\n";
        return 0;
    }

    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my (@vals) = split( /\t/, $s );
        my $id_val = $vals[$id_idx];

        #print "uploadIdsFromFile() id_idx=$id_idx, s=$s, vals=@vals<br/>\n";
        next if blankStr($id_val);
        push( @$ids_ref, $id_val );
    }
    close $rfh;
    wunlink($tmpFile);
    ## --es 05/05/2005 Check that import has at least one entry.
    if ( scalar(@$ids_ref) == 0 ) {
        $$errmsg_ref = "No values were uploaded.";
        return 0;
    }
    return 1;
}

############################################################################
# dbUpdateAnnotation - update MyIMG annotation in the database
#
# (This procedure replaces updateGenePageAnnotations.)
############################################################################
sub dbUpdateAnnotation {

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("Session expired.  Please log in again.");
        return;
    }

    my @gene_oids = param("gene_oid");
    my $nGenes    = @gene_oids;
    if ( $nGenes == 0 ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError( "No gene selected for update. " . "Please select at least one gene." );
        return;
    }
    if ( $nGenes > $max_gene_annotation_batch ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError( "Number of genes in batch to annotate exceeded. "
              . "Please enter no more than $max_gene_annotation_batch genes." );
        return;
    }

    ## sharing only?
    my $update_ann_type = param('update_ann_type');
    if ( $update_ann_type eq 'share_only' ) {
        dbUpdateMyIMGSharing();
        return;
    }

    # process user input
    my %new_vals;
    for my $fld (
        'product_name', 'prot_desc',   'ec_number',     'pubmed_id', 'inference', 'is_pseudogene',
        'notes',        'gene_symbol', 'obsolete_flag', 'is_public'
      )
    {
        my $val = param($fld);

        # format space
        $val =~ s/^\s+//;
        $val =~ s/\s+$//;
        $val =~ s/\s+/ /g;

        if ( !blankStr($val) ) {

            # check input values
            if ( $fld eq 'ec_number' ) {
                my $res = DataEntryUtil::checkECNumber($val);
                if ( !blankStr($res) ) {
                    main::printAppHeader("MyIMG");
                    WebUtil::webError( "ERROR: " . $res );
                    return;
                }
            } elsif ( $fld eq 'pubmed_id' ) {
                my $res = DataEntryUtil::checkPubmedId($val);
                if ( !blankStr($res) ) {
                    main::printAppHeader("MyIMG");
                    WebUtil::webError( "ERROR: " . $res );
                    return;
                }
            }

            # save the value
            $new_vals{$fld} = $val;
        }
    }

    # prepare database update statements
    my $dbh = WebUtil::dbLogin();
    my @taxons;
    my @sqlList = ();
    my $sql;
    my $cur;
    my $total_update = 0;

    for my $gene_oid (@gene_oids) {

        # check gene information
        my $taxon_oid;
        my $obsolete_flag;
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        $sql = qq{
			select g.gene_oid, g.taxon, g.obsolete_flag 
			from gene g 
			where g.gene_oid = ?
			    $rclause
			    $imgClause
		};

        $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        for ( ; ; ) {
            my ( $v1, $v2, $v3 ) = $cur->fetchrow();
            last if !$v1;

            $taxon_oid     = $v2;
            $obsolete_flag = $v3;
        }
        $cur->finish();

        # update taxon_stats?
        if ( !WebUtil::inIntArray( $taxon_oid, @taxons ) ) {
            push @taxons, ($taxon_oid);
        }

        # generate delete statements
        $sql = "delete from Gene_MyIMG_functions " . "where gene_oid = $gene_oid and modified_by = $contact_oid";
        push @sqlList, ($sql);
        $sql = "delete from Gene_MyIMG_enzymes " . "where gene_oid = $gene_oid and modified_by = $contact_oid";
        push @sqlList, ($sql);

        # generate insert Gene_MyIMG_functions
        $total_update++;
        my $new_ec_number = "";
        my $ins_st        = "insert into Gene_MyIMG_functions (gene_oid";
        my $val_st        = " values ($gene_oid";

        for my $fld (
            'product_name', 'prot_desc',   'ec_number', 'pubmed_id', 'inference', 'is_pseudogene',
            'notes',        'gene_symbol', 'obsolete_flag'
          )
        {
            if ( $fld eq 'ec_number' ) {
                if ( $new_vals{$fld} ) {
                    $new_ec_number = $new_vals{$fld};
                }
            }

            if ( $new_vals{$fld} ) {
                my $val = $new_vals{$fld};
                $val =~ s/'/''/g;    # replace ' with ''
                $ins_st .= ", $fld";
                $val_st .= ", '$val'";
            } elsif ( $fld eq 'product_name' ) {

                # use gene display name
                my $val = DataEntryUtil::db_findVal( $dbh, 'gene', 'gene_oid', $gene_oid, 'gene_display_name', '' );
                $val =~ s/'/''/g;    # replace ' with ''
                $ins_st .= ", $fld";
                $val_st .= ", '$val'";
            }
        }
        $sql = $ins_st . ", modified_by, mod_date) " . $val_st . ", $contact_oid, sysdate)";
        push @sqlList, ($sql);

        if ( !blankStr($new_ec_number) ) {
            $new_ec_number =~ s/;/ /g;
            my @ecs = split( / /, $new_ec_number );
            for my $ec1 (@ecs) {
                if ( blankStr($ec1) ) {
                    next;
                }

                $ec1 =~ s/'/''/g;    # replace ' with ''
                if ( DataEntryUtil::db_findCount( $dbh, 'ENZYME', "ec_number = '$ec1'" ) > 0 ) {
                    $sql =
                        "insert into Gene_MyIMG_enzymes "
                      . "(gene_oid, ec_number, modified_by, mod_date) "
                      . "values ($gene_oid, '$ec1', $contact_oid, sysdate)";
                    push @sqlList, ($sql);
                }
            }
        }
    }

    #$dbh->disconnect();

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        main::printAppHeader("MyIMG");
        WebUtil::webError("SQL Error: $sql");
        return -1;
    }

    if ( $update_ann_type eq 'both' ) {
        dbUpdateMyIMGSharing();
    }

    # recompute statistics for taxon_stats
    my $dbh = WebUtil::dbLogin();
    for my $k (@taxons) {
        updateTaxonAnnStatistics( $dbh, $k );
    }

    #$dbh->disconnect();

    return $total_update;
}

sub dbUpdateMyIMGSharing {
    my $contact_oid = WebUtil::getContactOid();
    my @genes       = param("gene_oid");
    my @groups      = param("share_w_group");

    if ( !$contact_oid ) {
        return;
    }

    if ( scalar(@genes) == 0 ) {
        return;
    }

    my @sqlList = ();
    for my $gene_oid (@genes) {
        my $sql = "delete from gene_myimg_groups\@img_ext where gene_oid = $gene_oid and contact_oid = $contact_oid";
        push @sqlList, ($sql);

        for my $grp (@groups) {
            $sql =
"insert into gene_myimg_groups\@img_ext (gene_oid, contact_oid, group_id) values ($gene_oid, $contact_oid, $grp)";
            push @sqlList, ($sql);
        }
    }

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        my $sql = $sqlList[ $err - 1 ];
        main::printAppHeader("MyIMG");
        WebUtil::webError("SQL Error: $sql");
        return -1;
    }
}

############################################################################
# dbDeleteAnnotation - delete MyIMG annotation in the database
############################################################################
sub dbDeleteAnnotation {

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("Session expired.  Please log in again.");
    }

    my @gene_oids = param("gene_oid");
    my $nGenes    = @gene_oids;
    if ( $nGenes == 0 ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError( "No gene selected for update. " . "Please select at least one gene." );
    }
    if ( $nGenes > $max_gene_annotation_batch ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError( "Number of genes in batch to annotate exceeded. "
              . "Please enter no more than $max_gene_annotation_batch genes." );
    }

    my $dbh = WebUtil::dbLogin();
    my @taxons;
    my @sqlList = ();
    my $sql;
    my $cur;
    my $total_update = 0;

    for my $gene_oid (@gene_oids) {

        # check gene information
        my $taxon_oid;
        my $obsolete_flag;
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        $sql = qq{
			select g.gene_oid, g.taxon, g.obsolete_flag
			from gene g
			where g.gene_oid = ?
			    $rclause
			    $imgClause
		};

        $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        for ( ; ; ) {
            my ( $v1, $v2, $v3 ) = $cur->fetchrow();
            last if !$v1;

            $taxon_oid     = $v2;
            $obsolete_flag = $v3;
        }
        $cur->finish();

        # update taxon_stats?
        if ( !WebUtil::inIntArray( $taxon_oid, @taxons ) ) {
            push @taxons, ($taxon_oid);
        }

        # get existing annotation count
        my $cnt1 =
          DataEntryUtil::db_findCount( $dbh, 'Gene_MyIMG_functions', "gene_oid = $gene_oid and modified_by = $contact_oid" );

        if ( $cnt1 > 0 ) {

            # generate delete from Gene_MyIMG_functions
            $total_update++;
            $sql = "delete from gene_myimg_groups\@img_ext where gene_oid = $gene_oid and contact_oid = $contact_oid";
            push @sqlList, ($sql);

            $sql = "delete from Gene_MyIMG_functions " . "where gene_oid = $gene_oid and modified_by = $contact_oid";
            push @sqlList, ($sql);

            $sql = "delete from Gene_MyIMG_enzymes " . "where gene_oid = $gene_oid and modified_by = $contact_oid";
            push @sqlList, ($sql);
        }
    }

    #$dbh->disconnect();

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        main::printAppHeader("MyIMG");
        WebUtil::webError("SQL Error: $sql");
        return -1;
    }

    # recompute statistics for taxon_stats
    my $dbh = WebUtil::dbLogin();
    for my $k (@taxons) {
        updateTaxonAnnStatistics( $dbh, $k );
    }

    #$dbh->disconnect();

    return $total_update;
}

############################################################################
# updateGenePageAnnotations - Add annotations for selected gene_oid's.
############################################################################
sub updateGenePageAnnotations {
    my $genePageGeneOid = param("genePageGeneOid");
    my $homologs        = param("homologs");
    my $annotation_text = param("annotation_text");

    ## Pre-format spaces
    $annotation_text =~ s/^\s+//;
    $annotation_text =~ s/\s+$//;
    $annotation_text =~ s/\s+/ /g;

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        WebUtil::webError("Session expired.  Please log in again.");
    }
    print "<h1>Update Annotations</h1>\n";

    my $len = length($annotation_text);
    if ( $len > $max_annotation_size ) {
        WebUtil::webError( "Annotation '$annotation_text' is too long (length=$len).\n"
              . "Please try again with text < $max_annotation_size characters.\n" );
    }

    my $dbh = WebUtil::dbLogin();

    my @gene_oids = param("gene_oid");
    my $nGenes    = @gene_oids;
    if ( $nGenes == 0 ) {
        WebUtil::webError( "No gene selected for update. " . "Please select at least one gene." );
    }
    if ( $nGenes > $max_gene_annotation_batch ) {
        WebUtil::webError( "Number of genes in batch to annotate exceeded. "
              . "Please enter no more than $max_gene_annotation_batch genes." );
    }
    WebUtil::printMainForm();

    WebUtil::printStatusLine( "Loading ...", 1 );

    require GeneCartStor;
    print "<p>\n";
    if ( blankStr($annotation_text) ) {
        deleteGeneAnnotations( $dbh, $contact_oid, \@gene_oids );
    } else {
        addGeneAnnotations( $dbh, $contact_oid, \@gene_oids, $annotation_text );
    }
    updateAnnStatistics($dbh);
    print "</p>\n";

    #$dbh->disconnect();
    WebUtil::printStatusLine( "Loaded.", 2 );

    print "<br>\n";
    print WebUtil::hiddenVar( "gene_oid", $genePageGeneOid );
    for my $gene_oid (@gene_oids) {
        print WebUtil::hiddenVar( "selected_gene_oid", $gene_oid );
    }
    print WebUtil::hiddenVar( "homologs",     $homologs );
    print WebUtil::hiddenVar( "clobberCache", 1 );
    my $name = "_section_GeneDetail_refreshGenePage";
    print submit(
        -name  => $name,
        -value => "Refresh Gene Page",
        -class => "meddefbutton"
    );

    print end_form();
}

############################################################################
# updateGeneCartAnnotations - Update annotations for gene cart.
############################################################################
sub updateGeneCartAnnotations {
    my @gene_oids       = param("gene_oid");
    my $annotation_text = param("annotation_text");

    ## Pre-format spaces
    $annotation_text =~ s/^\s+//;
    $annotation_text =~ s/\s+$//;
    $annotation_text =~ s/\s+/ /g;

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        WebUtil::webError("Session expired.  Please log in again.");
    }
    print "<h1>Update Annotations</h1>\n";

    my $len = length($annotation_text);
    if ( $len > $max_annotation_size ) {
        WebUtil::webError( "Annotation '$annotation_text' is too long (length=$len).\n"
              . "Please try again with text < $max_annotation_size characters.\n" );
    }

    my $dbh = WebUtil::dbLogin();

    my $nGenes = @gene_oids;
    if ( $nGenes == 0 ) {
        WebUtil::webError( "No gene selected for update. " . "Please select at least one gene." );
    }
    if ( $nGenes > $max_gene_annotation_batch ) {
        WebUtil::webError( "Number of genes in batch to annotate exceeded. "
              . "Please enter no more than $max_gene_annotation_batch genes." );
    }
    WebUtil::printMainForm();

    WebUtil::printStatusLine( "Loading ...", 1 );

    require GeneCartStor;
    print "<p>\n";
    if ( blankStr($annotation_text) ) {
        deleteGeneAnnotations( $dbh, $contact_oid, \@gene_oids );
    } else {
        addGeneAnnotations( $dbh, $contact_oid, \@gene_oids, $annotation_text );
    }
    updateAnnStatistics($dbh);
    print "</p>\n";

    #$dbh->disconnect();
    WebUtil::printStatusLine( "Loaded.", 2 );

    my $gc = new GeneCartStor();
    $gc->addGeneBatch( \@gene_oids );
    my $name = "_section_GeneCartStor_refreshGeneCart";
    print submit(
        -name  => $name,
        -value => "Refresh Gene Cart",
        -class => "medbutton"
    );

    print end_form();
}

############################################################################
# printGeneAnnotationForm - print MyIMG annotation for selected
#                           genes in Gene Cart.
#
# (This procedure replaces updateGeneCartAnnotations in old version
#  of IMG.)
############################################################################
sub printGeneAnnotationForm {
    print "<h1>MyIMG Annotation for Selected Genes in Gene Cart</h1>\n";
    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        WebUtil::webError("Session expired.  Please log in again.");
    } elsif ( DataEntryUtil::db_isPublicUser($contact_oid) ) {
        print "<h4>Public User cannot add or view MyIMG annotations.</h4>\n";

        print "<p>(If you want to become a registered user, ";
        print '<A href="main.cgi?page=requestAcct">' . 'request an account here</A>';
        print ".)</p>\n";

        print end_form();
        return;
    }

    my $gc = new GeneCartStor();

    my $recs         = $gc->readCartFile();                # get records
                                                           #my @gene_oids = sort { $a <=> $b } keys(%$recs);
    my @db_gene_oids = $gc->getDbGeneOids();
    my @gene_oids    = sort { $a <=> $b } @db_gene_oids;

    my @selected_gene_oids = param("gene_oid");
    my %selected_gene_oids_h;
    for my $gene_oid (@selected_gene_oids) {
        $selected_gene_oids_h{$gene_oid} = 1;
    }

    # print count
    my $count = 0;
    for my $g1 (@gene_oids) {
        if ( $selected_gene_oids_h{$g1} ) {
            $count++;
        }
    }
    print "<p>\n";
    print "$count database gene(s) selected\n";
    print "</p>\n";

    #temp block none-database genes
    if ( $count == 0 && scalar(@selected_gene_oids) > 0 ) {
        print "<p>selected genes: " . join( ", ", @selected_gene_oids ) . "\n";
        webError("You have selected file-based genes.  Please select at least one database gene.");
    }

    if ( $count == 0 ) {
        WebUtil::webError("No genes have been selected for annotation.");
        return;
    }

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Locus Tag</th>\n";
    print "<th class='img'>Original Product Name</th>\n";
    print "<th class='img'>Annotated Product Name</th>\n";
    print "<th class='img'>Genome</th>\n";
    print "<th class='img'>Batch</th>\n";
    my $dbh = WebUtil::dbLogin();

    for my $gene_oid (@gene_oids) {
        my $r = $recs->{$gene_oid};
        my ( $gene_oid, $locus_tag, $desc, $desc_orig, $taxon_oid, $taxon_display_name, $batch_id, $scaffold, @outColVals ) =
          split( /\t/, $r );

        # skip un-selected ones
        if ( !$selected_gene_oids_h{$gene_oid} ) {
            next;
        }

        print "<tr class='img'>\n";

        ## --es 09/30/2006 add checkbox and illustration
        #   for selected genes from cart.  Previous selections
        #   are checked.
        my $ck;
        $ck = "checked" if $selected_gene_oids_h{$gene_oid};
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='gene_oid' value='$gene_oid' $ck />\n";
        print "</td>\n";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";

        # Locus Tag
        print "<td class='img'>" . escapeHTML($locus_tag) . "</td>\n";

        # Original Product Name
        print "<td class='img'>" . escapeHTML($desc_orig) . "</td>\n";

        # Annotated product name
        my $annot_prod_name =
          DataEntryUtil::db_findVal( $dbh, 'GENE_MYIMG_FUNCTIONS', 'gene_oid', $gene_oid, 'product_name',
            "modified_by = $contact_oid" );
        print "<td class='img'>" . escapeHTML($annot_prod_name) . "</td>\n";

        # Genome
        print "<td class='img'>" . escapeHTML($taxon_display_name) . "</td>\n";

        # Batch
        print "<td class='img'>" . escapeHTML($batch_id) . "</td>\n";
        print "</tr>\n";
    }
    print "</table>\n";

    #$dbh->disconnect();

    # MyIMG annotation data
    # data in a table format
    print "<h2>MyIMG Annotation</h2>\n";

    my $load_gene_oid = param("load_gene_oid");
    if ( !$load_gene_oid && scalar(@gene_oids) > 0 ) {

        # skip un-selected ones
        for my $g2 (@gene_oids) {
            if ( !$selected_gene_oids_h{$g2} ) {
                next;
            }

            $load_gene_oid = $g2;
            last;
        }
    }

    #    print "<p>Load gene: $load_gene_oid</p>\n";

    print "<p>Upload existing MyIMG annotation for gene: \n";
    print nbsp(1);
    print "     <select name='load_gene_oid' class='img' size='1'>\n";

    #    print "        <option value=' '> </option>\n";
    for my $gene_oid (@gene_oids) {
        if ( !$selected_gene_oids_h{$gene_oid} ) {
            next;
        }
        print "        <option value='$gene_oid' ";
        if ( $gene_oid == $load_gene_oid ) {
            print "selected ";
        }
        print ">$gene_oid</option>\n";
    }
    print "     </select>\n";
    my $name = "_section_${section}_geneCartAnnotations";
    print nbsp(2);
    print submit(
        -name  => $name,
        -value => "Load Gene Annotation",
        -class => "medbutton"
    );

    my $db_gene_oid      = "";
    my $db_product_name  = "";
    my $db_prot_desc     = "";
    my $db_ec_number     = "";
    my $db_pubmed_id     = "";
    my $db_inference     = "";
    my $db_is_pseudogene = "";
    my $db_notes         = "";
    my $db_gene_symbol   = "";
    my $db_obsolete_flag = "";

    if ( !blankStr($load_gene_oid) ) {

        # select existing annotation from database
        my $contact_oid = WebUtil::getContactOid();
        my $dbh         = WebUtil::dbLogin();

        # get original gene definition
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql       = qq{
			select g.gene_oid, g.gene_display_name, 
			    g.is_pseudogene, g.gene_symbol, g.obsolete_flag
			from gene g
			where g.gene_oid = ?
			    $rclause
			    $imgClause
		};
        my $cur = execSql( $dbh, $sql, $verbose, $load_gene_oid );
        ( $db_gene_oid, $db_product_name, $db_is_pseudogene, $db_gene_symbol, $db_obsolete_flag ) = $cur->fetchrow();
        $cur->finish();

        $sql = "select enzymes from gene_ko_enzymes where gene_oid = $load_gene_oid and enzymes is not null";
        $cur = execSql( $dbh, $sql, $verbose );
        my $ec_cnt = 0;
        for ( ; ; ) {
            my ($ec2) = $cur->fetchrow();
            last if !$ec2;

            $ec_cnt++;
            if ( $ec_cnt > 20 ) {
                last;
            }

            $db_ec_number .= $ec2 . ' ';
        }
        $cur->finish();

        # override with MyIMG annotations if any
        $sql = qq{
	    select gene_oid, product_name, prot_desc, ec_number, pubmed_id,
	    inference, is_pseudogene, notes, gene_symbol, obsolete_flag
		from gene_myimg_functions
		where gene_oid = ? and modified_by = ?
	    };
        $cur = execSql( $dbh, $sql, $verbose, $load_gene_oid, $contact_oid );
        my (
            $my_gene_oid,  $my_product_name,  $my_prot_desc, $my_ec_number,   $my_pubmed_id,
            $my_inference, $my_is_pseudogene, $my_notes,     $my_gene_symbol, $my_obsolete_flag
          )
          = $cur->fetchrow();
        $cur->finish();

        if ($my_gene_oid) {
            if ( !blankStr($my_product_name) ) {
                $db_product_name = $my_product_name;
            }
            if ( !blankStr($my_prot_desc) ) {
                $db_prot_desc = $my_prot_desc;
            }
            if ( !blankStr($my_pubmed_id) ) {
                $db_pubmed_id = $my_pubmed_id;
            }
            if ( !blankStr($my_is_pseudogene) ) {
                $db_is_pseudogene = $my_is_pseudogene;
            }
            if ( !blankStr($my_gene_symbol) ) {
                $db_gene_symbol = $my_gene_symbol;
            }
            if ( !blankStr($my_obsolete_flag) ) {
                $db_obsolete_flag = $my_obsolete_flag;
            }
            if ( !blankStr($my_ec_number) ) {
                $db_ec_number = $my_ec_number;
            }
            if ( !blankStr($my_inference) ) {
                $db_inference = $my_inference;
            }
            if ( !blankStr($my_notes) ) {
                $db_notes = $my_notes;
            }
        }

        #$dbh->disconnect();
    }

    print "<p>Enter or update MyIMG annotation for selected gene(s).</p>\n";

    print "<ul>\n";
    print
"<li>Use ';' to separate multiple product names. If product name is not provided, then the original product name will be used.</li>\n";
    print "<li>EC Number can contain multiple EC numbers separated by blank or ';' (e.g., EC:1.2.3.4 EC:4.3.-.-).</li>\n";
    print "<li>PUBMED ID can contain multiple ID values separated by blank or ';'.</li>\n";
    print "</ul>\n";

    print "<table class='img' border='1'>\n";

    # Product Name
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Product Name</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='product_name' value='"
      . escapeHTML($db_product_name)
      . "' size='80' maxLength='1000'/>"
      . "</td>\n";
    print "</tr>\n";

    # Prot Desc
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Prot Description</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='prot_desc' value='"
      . escapeHTML($db_prot_desc)
      . "' size='80' maxLength='1000'/>"
      . "</td>\n";
    print "</tr>\n";

    # EC number
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>EC Number</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='ec_number' value='"
      . escapeHTML($db_ec_number)
      . "' size=80' maxLength='1000'/>"
      . "</td>\n";
    print "</tr>\n";

    # PUBMED ID
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>PUBMED ID</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='pubmed_id' value='"
      . escapeHTML($db_pubmed_id)
      . "' size='80' maxLength='1000'/>"
      . "</td>\n";
    print "</tr>\n";

    # Inference
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Inference</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='inference' value='"
      . escapeHTML($db_inference)
      . "' size='80' maxLength='500'/>"
      . "</td>\n";
    print "</tr>\n";

    # is pseudo gene?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Pseudo Gene?</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='is_pseudogene' class='img' size='2'>\n";
    if ( blankStr($db_is_pseudogene) || lc($db_is_pseudogene) ne 'yes' ) {
        $db_is_pseudogene = 'No';
    }
    for my $tt ( 'No', 'Yes' ) {
        print "        <option value='$tt' ";
        if ( lc($tt) eq lc($db_is_pseudogene) ) {
            print "selected ";
        }
        print ">$tt</option>\n";
    }
    print "     </select></td>\n";
    print "</tr>\n";

    # Notes
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Notes</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='notes' value='"
      . escapeHTML($db_notes)
      . "' size='80' maxLength='1000'/>"
      . "</td>\n";
    print "</tr>\n";

    # Gene Symbol
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Gene Symbol</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='gene_symbol' value='"
      . escapeHTML($db_gene_symbol)
      . "' size='80' maxLength='100'/>"
      . "</td>\n";
    print "</tr>\n";

    # obsolete_flag
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Remove Gene from Genome?</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='obsolete_flag' class='img' size='2'>\n";
    if ( blankStr($db_obsolete_flag) || lc($db_obsolete_flag) ne 'yes' ) {
        $db_obsolete_flag = 'No';
    }
    for my $tt ( 'No', 'Yes' ) {
        print "        <option value='$tt' ";
        if ( lc($tt) eq lc($db_obsolete_flag) ) {
            print "selected ";
        }
        print ">$tt</option>\n";
    }
    print "     </select></td>\n";
    print "</tr>\n";

    # is public?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Public?</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='is_public' class='img' size='2'>\n";
    my $db_is_public = 'No';
    for my $tt ( 'No', 'Yes' ) {
        print "        <option value='$tt' ";
        if ( lc($tt) eq lc($db_is_public) ) {
            print "selected ";
        }
        print ">$tt</option>\n";
    }
    print "     </select></td>\n";
    print "</tr>\n";

    print "</table>\n";

    ## share with group?
    my $sql =
        "select cig.img_group, g.group_name "
      . "from contact_img_groups\@imgsg_dev cig, img_group\@imgsg_dev g "
      . "where cig.contact_oid = ? and cig.img_group = g.group_id ";
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my %group_h;
    for ( ; ; ) {
        my ( $g_id, $g_name ) = $cur->fetchrow();
        last if !$g_id;

        $group_h{$g_id} = $g_name;
    }
    $cur->finish();

    my @groups = ( keys %group_h );
    if ( scalar(@groups) > 0 ) {
        print "<h4>Share Annotation with Group</h4>\n";
        print
"<p>This annotation will not be visiable by other group members if it is a private annotation and no group is selected.\n";
        for my $g1 (@groups) {
            my $ck = " ";
            print "<p>" . nbsp(3) . "<input type='checkbox' ";
            print "name='share_w_group' value='$g1' $ck />" . nbsp(1) . $group_h{$g1} . "\n";
        }
    }

    # buttons
    print "<p>\n";
    my $name = "_section_${section}_updateAnnotations_noHeader";
    print submit(
        -name  => $name,
        -value => "Update Annotation",
        -class => "meddefbutton"
    );
    print nbsp(1);
    my $name = "_section_${section}_deleteAnnotations_noHeader";
    print submit(
        -name  => $name,
        -value => "Delete Annotation",
        -class => "medbutton"
    );
    print nbsp(1);
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print nbsp(1);
    my $name = "_section_GeneCartStor_geneCart";
    print submit(
        -name  => $name,
        -value => 'Cancel',
        -class => 'smbutton'
    );

    print "<p>\n";
    print end_form();
}

############################################################################
# transferGenePageAnnotations - Add annotations for selected gene_oid's.
#   with an existing gene annotation.
############################################################################
sub transferGenePageAnnotations {
    my ($genePageGeneOid) = @_;
    $genePageGeneOid = param("genePageGeneOid") if $genePageGeneOid eq "";

    print "<h1>Update Annotations</h1>\n";
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        WebUtil::webError("Session expired.  Please log in again.");
    }

    my $dbh = WebUtil::dbLogin();
    my $annotation_text = getAnnotation( $dbh, $genePageGeneOid, $contact_oid );
    ## Pre-format spaces
    $annotation_text =~ s/^\s+//;
    $annotation_text =~ s/\s+$//;
    $annotation_text =~ s/\s+/ /g;

    my @gene_oids = param("gene_oid");
    my $nGenes    = @gene_oids;
    if ( $nGenes == 0 ) {
        WebUtil::webError( "No gene selected for update. " . "Please select at least one gene." );
    }
    if ( $nGenes > $max_gene_annotation_batch ) {
        WebUtil::webError( "Number of genes in batch to annotate exceeded. "
              . "Please enter no more than $max_gene_annotation_batch genes." );
    }
    WebUtil::printMainForm();

    WebUtil::printStatusLine( "Loading ...", 1 );

    require GeneCartStor;
    print "<p>\n";
    if ( blankStr($annotation_text) ) {
        deleteGeneAnnotations( $dbh, $contact_oid, \@gene_oids );
    } else {
        addGeneAnnotations( $dbh, $contact_oid, \@gene_oids, $annotation_text );
    }
    updateAnnStatistics($dbh);
    print "</p>\n";

    #$dbh->disconnect();
    WebUtil::printStatusLine( "Loaded.", 2 );

    print end_form();
}

############################################################################
# deleteGeneAnnotations  - Delete annotations for blank entry.
############################################################################
sub deleteGeneAnnotations {
    my ( $dbh, $contact_oid, $geneOids_ref ) = @_;

    for my $gene_oid (@$geneOids_ref) {

        print "Delete annotation for gene_oid=$gene_oid<br/>\n";

        ## Begin transaction
        my $cur = execSql( $dbh, "set transaction read write", $verbose );
        $cur->finish();

        deleteAnnotation4OneGene( $dbh, $contact_oid, $gene_oid );

        ## End transaction
        my $cur = execSql( $dbh, "commit work", $verbose );
        $cur->finish();
    }
    require GeneCartStor;
    my $gc = new GeneCartStor();
    print "Updating relevant genes in gene cart " . "with original description.<br/>\n";
    $gc->restoreOrigDesc($geneOids_ref);
}

############################################################################
# deleteAnnotion4OneGene - Delete anontation for one gene.
############################################################################
sub deleteAnnotation4OneGene {
    my ( $dbh, $contact_oid, $gene_oid ) = @_;

    my $sql = qq{
        select distinct a.annot_oid
        from annotation_genes ag, annotation a
        where ag.genes = ?
        and ag.annot_oid = a.annot_oid
        and a.author = ?
    };
    my @annot_oids;
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $contact_oid );
    for ( ; ; ) {
        my ($annot_oid) = $cur->fetchrow();
        last if !$annot_oid;
        push( @annot_oids, $annot_oid );
    }
    $cur->finish();

    for my $annot_oid (@annot_oids) {
        my $sql = qq{
	   delete from annotation_genes
	   where genes = ?
	   and annot_oid = ?
	};
        execSql( $dbh, $sql, $verbose, $gene_oid, $annot_oid );
        $cur->finish();
        my $sql = qq{
            delete from annotation
   	    where annot_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $annot_oid );
        $cur->finish();
    }
}

############################################################################
# addGeneAnnotations - Add annotation for selected genes.  We do
#   "deep copy" semantics here, since these are not really
#   controlled values, and invidual gene annotations may be modified
#   later on.  (IMG Terms may use "shallow" or pointer semantics.)
############################################################################
sub addGeneAnnotations {
    my ( $dbh, $contact_oid, $geneOids_ref, $annotation_text ) = @_;

    for my $gene_oid (@$geneOids_ref) {

        my $x = WebUtil::escHtml($annotation_text);
        print "Update gene_oid=$gene_oid with '$x'<br/>\n";

        ## Begin transaction
        my $cur = execSql( $dbh, "set transaction read write", $verbose );
        $cur->finish();

        deleteAnnotation4OneGene( $dbh, $contact_oid, $gene_oid );

        ## Get next annotation_oid
        my $sql = qq{
	    select max( annot_oid ) from annotation 
	};
        my $cur = execSql( $dbh, $sql, $verbose );
        my ($annot_oid) = $cur->fetchrow();
        $cur->finish();
        $annot_oid++;

        ## Insert into annotation
        my $sql_mysql = qq{
	     insert into annotation( annot_oid, annotation_text,
	        author, add_date )
	     values( $annot_oid, ?, $contact_oid, sysdate() )
	};
        my $sql_oracle = qq{
	     insert into annotation( annot_oid, annotation_text,
	        author, add_date )
	     values( $annot_oid, ?, $contact_oid, sysdate )
	};
        my $sql;
        $sql = $sql_oracle if $rdbms eq "oracle";
        $sql = $sql_mysql  if $rdbms eq "mysql";
        my $cur = prepSql( $dbh, $sql );
        execStmt( $cur, $annotation_text );
        $cur->finish();

        #my $cur = execSql( $dbh, $sql, $verbose );
        #$cur->finish( );

        ## Insert into annotation_genes
        my $sql = qq{
	     insert into annotation_genes( annot_oid, genes )
	     values( ?, ? )
	};
        my $cur = execSql( $dbh, $sql, $verbose, $annot_oid, $gene_oid );
        $cur->finish();

        ## End transaction
        my $cur = execSql( $dbh, "commit work", $verbose );
        $cur->finish();
    }
    require GeneCartStor;
    my $gc = new GeneCartStor();
    print "Updating relevant genes in gene cart  " . "with '$annotation_text'.<br/>\n";
    $gc->setNewDesc( $geneOids_ref, $annotation_text );
}

############################################################################
# viewNewAnnotations
#
# (from taxon gene-enzyme PRIAM annotations)
############################################################################
sub viewNewAnnotations {
    WebUtil::printMainForm();

    # get contact_oid
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }

    print "<h1>New Annotations</h1>\n";
    my $taxon_oid  = param('taxon_oid');
    my $dbh        = WebUtil::dbLogin();
    my $taxon_name = DataEntryUtil::db_findVal( $dbh, 'taxon', 'taxon_oid', $taxon_oid, 'taxon_name', "" );

    print "<h2>Genome ($taxon_oid): " . escapeHTML($taxon_name) . "</h2>\n";
    print WebUtil::hiddenVar( 'taxon_oid', $taxon_oid );

    my @gene_ecs = param('tax_gene_enzyme');
    if ( scalar(@gene_ecs) == 0 ) {

        #$dbh->disconnect();
        WebUtil::webError("No genes have been selected.");
        return;
    }

    WebUtil::printStatusLine( "Loading ...", 1 );

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    my $gene_oid_clause = '';
    my $cnt0            = 0;
    for my $gene_ec (@gene_ecs) {
        my ( $gene_oid, $ec_number ) = split( /\,/, $gene_ec );

        if ( blankStr($gene_oid_clause) ) {
            $gene_oid_clause = " and g.gene_oid in ($gene_oid";
        } else {
            $gene_oid_clause .= ", " . $gene_oid;
        }

        $cnt0++;
        if ( $cnt0 >= $maxGeneListResults ) {
            last;
        }
    }
    if ( !blankStr($gene_oid_clause) ) {
        $gene_oid_clause .= ")";
    }

    my $annSortAttr = param("annSortAttr");
    my $sortClause  = " order by g.gene_oid";
    $sortClause = " order by ann.mod_date desc, g.gene_oid"
      if $annSortAttr eq "add_date";
    $sortClause = " order by to_char( g.product_name )"
      if $annSortAttr eq "gene_product_name";
    $sortClause = " order by to_char( ann.product_name )"
      if $annSortAttr eq "product_name";
    $sortClause = " order by g.gene_oid"
      if $annSortAttr eq "gene_oid";
    $sortClause = " order by ann.annot_oid"
      if $annSortAttr eq "annot_oid";
    $sortClause = " order by ann.prot_desc"
      if $annSortAttr eq "prot_desc";
    $sortClause = " order by ann.ec_number"
      if $annSortAttr eq "ec_number";
    $sortClause = " order by ann.pubmed_id"
      if $annSortAttr eq "pubmed_id";
    $sortClause = " order by ann.inference"
      if $annSortAttr eq "inference";
    $sortClause = " order by ann.is_pseudogene"
      if $annSortAttr eq "is_pseudogene";
    $sortClause = " order by ann.notes"
      if $annSortAttr eq "notes";
    $sortClause = " order by ann.obsolete_flag"
      if $annSortAttr eq "obsolete_flag";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql_part1 = qq{
		select ann.gene_oid, g.gene_oid, 
		    ann.product_name, ann.prot_desc, ann.ec_number,
		    ann.pubmed_id, ann.inference, ann.is_pseudogene,
		    ann.notes, ann.gene_symbol, ann.obsolete_flag,
		    g.product_name,
	};
    my $sql_part2 = qq{
		from gene g, gene_myimg_functions ann
		where g.gene_oid = ann.gene_oid
		    and ann.modified_by = ?
		    and g.obsolete_flag = 'No' 
		    $gene_oid_clause
		    $rclause
		    $imgClause
		$sortClause
	};
    my $sql_mysql = qq{
		$sql_part1
		date_format( ann.mod_date, '%d-%m-%Y %k:%i:%s' )
		$sql_part2
	};
    my $sql_oracle = qq{
		$sql_part1
		    to_char( ann.mod_date, 'yyyy-mm-dd HH24:MI:SS' )
		$sql_part2
	};
    my $sql;
    $sql = $sql_mysql  if $rdbms eq "mysql";
    $sql = $sql_oracle if $rdbms eq "oracle";

    #   print "<p>SQL: $sql</p>\n";

    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my @recs;
    my $count = 0;
    my $trunc = 0;
    for ( ; ; ) {
        my (
            $annot_oid,     $gene_oid,          $annotation_text, $prot_desc, $ec_number,
            $pubmed_id,     $inference,         $is_pseudogene,   $notes,     $gene_symbol,
            $obsolete_flag, $gene_product_name, $add_date
          )
          = $cur->fetchrow();
        last if !$annot_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        my $rec = "$annot_oid\t";
        $rec .= "$gene_oid\t";
        $annotation_text =~ s/\t\r/ /g;
        $rec .= "$annotation_text\t";
        $prot_desc =~ s/\t\r/ /g;
        $rec .= "$prot_desc\t";
        $ec_number =~ s/\t\r/ /g;
        $rec .= "$ec_number\t";
        $pubmed_id =~ s/\t\r/ /g;
        $rec .= "$pubmed_id\t";
        $inference =~ s/\t\r/ /g;
        $rec .= "$inference\t";
        $rec .= "$is_pseudogene\t";
        $notes =~ s/\t\r/ /g;
        $rec .= "$notes\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$obsolete_flag\t";
        $rec .= "$gene_product_name\t";
        $rec .= "$add_date";
        push( @recs, $rec );
    }
    $cur->finish();
    my $nRecs = @recs;
    if ( $nRecs == 0 ) {
        print "<p>0 genes retrieved</p>\n";
        WebUtil::printStatusLine( "0 genes retrieved", 2 );

        #$dbh->disconnect();
        return;
    }

    my $is_my_annot = 1;
    printAnnotFooter( $is_my_annot, $is_my_annot );
    print "<p>\n";
    print "Click on column name to sort.\n";
    print "</p>\n";
    my $user_id = $contact_oid;
    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Select</th>\n";
    print "<th class='img' >" . annSortLink( "gene_oid",          "Gene ID",                  $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "gene_product_name", "Original Product Name",    $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "product_name",      "Annotated Product Name",   $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "prot_desc",         "Annotated Prot Desc",      $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "ec_number",         "Annotated EC Number",      $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "pubmed_id",         "Annotated PUBMED ID",      $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "inference",         "Inference",                $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "is_pseudogene",     "Is Pseudo Gene?",          $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "notes",             "Notes",                    $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "gene_symbol",       "Annotated Gene Symbol",    $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "obsolete_flag",     "Remove Gene from Genome?", $user_id ) . "</th>\n";
    print "<th class='img' >" . annSortLink( "add_date",          "Last Modified Date",       $user_id ) . "</th>\n";

    for my $r (@recs) {
        my (
            $annot_oid,     $gene_oid,          $annotation_text, $prot_desc, $ec_number,
            $pubmed_id,     $inference,         $is_pseudogene,   $notes,     $gene_symbol,
            $obsolete_flag, $gene_product_name, $add_date
          )
          = split( /\t/, $r );
        print "<tr class='img' >\n";
        print "<td class='img' >\n";

        #      print "<input type='checkbox' name='annot_oid' value='$annot_oid' />\n";
        print "<input type='checkbox' name='gene_oid' value='$annot_oid' ";
        print "/>\n";
        print "</td>\n";

        #print "<td class='img' >$annot_oid</th>\n";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        print "<td class='img' >" . alink( $url, $gene_oid ) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($gene_product_name) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($annotation_text) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($prot_desc) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($ec_number) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($pubmed_id) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($inference) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($is_pseudogene) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($notes) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($gene_symbol) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($obsolete_flag) . "</td>\n";
        print "<td class='img' >" . WebUtil::escHtml($add_date) . "</td>\n";
        print "</tr>\n";
    }
    print "</table>\n";
    print WebUtil::hiddenVar( "page", "myIMG" );
    printAnnotFooter( $is_my_annot, $is_my_annot ) if $nRecs > 10;
    $cur->finish();
    if ( !$trunc ) {
        WebUtil::printStatusLine( "$nRecs genes retrieved", 2 );
    } else {
        printTruncatedStatus($maxGeneListResults);
    }

    #$dbh->disconnect();
    print end_form();
}

############################################################################
# printUpdateGeneAnnotForm - print MyIMG annotation for selected
#                           genes in param('gene_oid')
############################################################################
sub printUpdateGeneAnnotForm {
    my @gene_list = param("gene_oid");

    # remove duplicate from gene_list
    my @gene_oids = ();
    for my $g2 (@gene_list) {
        if ( WebUtil::inArray( $g2, @gene_oids ) ) {
            next;
        }

        push @gene_oids, ($g2);
    }

    print "<h1>MyIMG Annotation for Selected Genes</h1>\n";

    WebUtil::printMainForm();

    # print count
    my $count = scalar(@gene_oids);
    print "<p>\n";
    print "$count gene(s) selected\n";
    print "</p>\n";

    if ( $count == 0 ) {
        WebUtil::webError("No genes have been selected for annotation.");
        return;
    }

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        WebUtil::webError("Session expired.  Please log in again.");
    } elsif ( DataEntryUtil::db_isPublicUser($contact_oid) ) {
        print "<h4>Public User cannot add or view MyIMG annotations.</h4>\n";

        print "<p>(If you want to become a registered user, ";
        print '<A href="main.cgi?page=requestAcct">' . 'request an account here</A>';
        print ".)</p>\n";

        print end_form();
        return;
    }

    # save param
    print WebUtil::hiddenVar( 'source_page', 'selected_gene_annot' );

    ### Print the records out in a table.
    print "<table class='img'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Original Product Name</th>\n";
    print "<th class='img'>Annotated Product Name</th>\n";
    print "<th class='img'>Prot Description</th>\n";
    print "<th class='img'>EC Number</th>\n";
    print "<th class='img'>PUBMED ID</th>\n";
    print "<th class='img'>Inference</th>\n";
    print "<th class='img'>Annotated Gene Symbol</th>\n";
    print "<th class='img'>Is Pseudo gene?</th>\n";
    print "<th class='img'>Notes</th>\n";
    print "<th class='img'>Remove Gene from Genome?</th>\n";
    print "<th class='img'>Is Public?</th>\n";
    print "<th class='img'>Annot Date</th>\n";

    my $dbh                = WebUtil::dbLogin();
    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    my $gene_oid_clause = '';
    my $cnt0            = 0;
    for my $gene_oid (@gene_oids) {
        if ( blankStr($gene_oid_clause) ) {
            $gene_oid_clause = " and g.gene_oid in ($gene_oid";
        } else {
            $gene_oid_clause .= ", " . $gene_oid;
        }

        $cnt0++;
        if ( $cnt0 >= $maxGeneListResults ) {
            last;
        }
    }
    if ( !blankStr($gene_oid_clause) ) {
        $gene_oid_clause .= ")";
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql_part1 = qq{
		select ann.gene_oid, g.gene_oid, 
		    ann.product_name, ann.prot_desc, ann.ec_number,
		    ann.pubmed_id, ann.inference, ann.is_pseudogene,
		    ann.notes, ann.gene_symbol, ann.obsolete_flag, ann.is_public,
                    g.product_name,
	};
    my $sql_part2 = qq{
		from gene g, gene_myimg_functions ann, contact c
		where g.gene_oid = ann.gene_oid
		    and ann.modified_by = ?
                    and ann.modified_by = c.contact_oid
		    and g.obsolete_flag = 'No' 
		    $gene_oid_clause
		    $rclause
		    $imgClause
		order by g.gene_oid
	};
    my $sql_mysql = qq{
		$sql_part1
		date_format( ann.mod_date, '%d-%m-%Y %k:%i:%s' )
		$sql_part2
	};
    my $sql_oracle = qq{
		$sql_part1
		to_char( ann.mod_date, 'yyyy-mm-dd HH24:MI:SS' )
		$sql_part2
	};
    my $sql;
    $sql = $sql_mysql  if $rdbms eq "mysql";
    $sql = $sql_oracle if $rdbms eq "oracle";

    #   print "<p>SQL: $sql</p>\n";

    my $cur   = execSql( $dbh, $sql, $verbose, $contact_oid );
    my $count = 0;
    my $trunc = 0;
    for ( ; ; ) {
        my (
            $annot_oid,     $gene_oid,  $annotation_text,   $prot_desc, $ec_number,
            $pubmed_id,     $inference, $is_pseudogene,     $notes,     $gene_symbol,
            $obsolete_flag, $is_public, $gene_product_name, $add_date
          )
          = $cur->fetchrow();
        last if !$annot_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }

        print "<tr class='img'>\n";

        my $ck = "checked";
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='gene_oid' value='$gene_oid' $ck />\n";
        print "</td>\n";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        print "<td class='img'>" . alink( $url, $gene_oid ) . "</td>\n";

        # g.product_name,
        print "<td class='img'>" . escapeHTML($gene_product_name) . "</td>\n";

        # ann.product_name,
        print "<td class='img'>" . escapeHTML($annotation_text) . "</td>\n";

        # ann.prot_desc,
        print "<td class='img'>" . escapeHTML($prot_desc) . "</td>\n";

        # ann.ec_number,
        print "<td class='img'>" . escapeHTML($ec_number) . "</td>\n";

        # ann.pubmed_id,
        print "<td class='img'>" . escapeHTML($pubmed_id) . "</td>\n";

        # ann.inference,
        print "<td class='img'>" . escapeHTML($inference) . "</td>\n";

        # ann.is_pseudogene,
        print "<td class='img'>" . escapeHTML($is_pseudogene) . "</td>\n";

        # ann.notes,
        print "<td class='img'>" . escapeHTML($notes) . "</td>\n";

        # ann.gene_symbol
        print "<td class='img'>" . escapeHTML($gene_symbol) . "</td>\n";

        # ann.obsolete_flag
        print "<td class='img'>" . escapeHTML($obsolete_flag) . "</td>\n";

        # ann.is_public
        print "<td class='img'>" . escapeHTML($is_public) . "</td>\n";

        # mod date
        print "<td class='img'>" . escapeHTML($add_date) . "</td>\n";

        print "</tr>\n";
    }
    print "</table>\n";

    #$dbh->disconnect();

    # MyIMG annotation data
    # data in a table format
    print "<h2>MyIMG Annotation</h2>\n";

    my $load_gene_oid = param("load_gene_oid");
    if ( !$load_gene_oid && scalar(@gene_oids) > 0 ) {
        $load_gene_oid = $gene_oids[0];
    }

    print "<p>Upload existing MyIMG annotation for gene: \n";
    print nbsp(1);
    print "     <select name='load_gene_oid' class='img' size='1'>\n";

    #    print "        <option value=' '> </option>\n";
    for my $gene_oid (@gene_oids) {
        print "        <option value='$gene_oid' ";
        if ( $gene_oid == $load_gene_oid ) {
            print "selected ";
        }
        print ">$gene_oid</option>\n";
    }
    print "     </select>\n";

    #    my $name = "_section_${section}_geneCartAnnotations";
    my $name = "_section_${section}_updMyGeneAnnot";
    print nbsp(2);
    print submit(
        -name  => $name,
        -value => "Load Gene Annotation",
        -class => "medbutton"
    );

    my $db_gene_oid      = "";
    my $db_product_name  = "";
    my $db_prot_desc     = "";
    my $db_ec_number     = "";
    my $db_pubmed_id     = "";
    my $db_inference     = "";
    my $db_is_pseudogene = "";
    my $db_notes         = "";
    my $db_gene_symbol   = "";
    my $db_obsolete_flag = "";
    my $db_is_public     = "";

    if ( !blankStr($load_gene_oid) ) {

        # select existing annotation from database
        my $contact_oid = WebUtil::getContactOid();
        my $dbh         = WebUtil::dbLogin();

        # get original gene definition
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql       = qq{
			select g.gene_oid, g.gene_display_name, 
			    g.is_pseudogene, g.gene_symbol, g.obsolete_flag
			from gene g
			where g.gene_oid = ?
			    $rclause
			    $imgClause
		};
        my $cur = execSql( $dbh, $sql, $verbose, $load_gene_oid );
        ( $db_gene_oid, $db_product_name, $db_is_pseudogene, $db_gene_symbol, $db_obsolete_flag ) = $cur->fetchrow();
        $cur->finish();

        $sql = "select enzymes from gene_ko_enzymes where gene_oid = $load_gene_oid and enzymes is not null";
        $cur = execSql( $dbh, $sql, $verbose );
        my $ec_cnt = 0;
        for ( ; ; ) {
            my ($ec2) = $cur->fetchrow();
            last if !$ec2;

            $ec_cnt++;
            if ( $ec_cnt > 20 ) {
                last;
            }

            $db_ec_number .= $ec2 . ' ';
        }
        $cur->finish();

        # override with MyIMG annotations if any
        $sql = qq{
	    select gene_oid, product_name, prot_desc, ec_number, pubmed_id,
	    inference, is_pseudogene, notes, gene_symbol, obsolete_flag, is_public
		from gene_myimg_functions
		where gene_oid = ? and modified_by = ?
	    };
        $cur = execSql( $dbh, $sql, $verbose, $load_gene_oid, $contact_oid );
        my (
            $my_gene_oid,    $my_product_name,  $my_prot_desc,     $my_ec_number,
            $my_pubmed_id,   $my_inference,     $my_is_pseudogene, $my_notes,
            $my_gene_symbol, $my_obsolete_flag, $my_is_public
          )
          = $cur->fetchrow();
        $cur->finish();

        if ($my_gene_oid) {
            if ( !blankStr($my_product_name) ) {
                $db_product_name = $my_product_name;
            }
            if ( !blankStr($my_is_pseudogene) ) {
                $db_is_pseudogene = $my_is_pseudogene;
            }
            if ( !blankStr($my_prot_desc) ) {
                $db_prot_desc = $my_prot_desc;
            }
            if ( !blankStr($my_pubmed_id) ) {
                $db_pubmed_id = $my_pubmed_id;
            }
            if ( !blankStr($my_gene_symbol) ) {
                $db_gene_symbol = $my_gene_symbol;
            }
            if ( !blankStr($my_obsolete_flag) ) {
                $db_obsolete_flag = $my_obsolete_flag;
            }
            if ( !blankStr($my_is_public) ) {
                $db_is_public = $my_is_public;
            }
            if ( !blankStr($my_ec_number) ) {
                $db_ec_number = $my_ec_number;
            }
            if ( !blankStr($my_inference) ) {
                $db_inference = $my_inference;
            }
            if ( !blankStr($my_notes) ) {
                $db_notes = $my_notes;
            }
        }

        #$dbh->disconnect();
    }

    print "<p>Enter or update MyIMG annotation for selected gene(s).</p>\n";

    print "<ul>\n";
    print
"<li>Use ';' to separate multiple product names. If product name is not provided, then the original product name will be used.</li>\n";
    print "<li>EC Number can contain multiple EC numbers separated by blank or ';' (e.g., EC:1.2.3.4 EC:4.3.-.-).</li>\n";
    print "<li>PUBMED ID can contain multiple ID values separated by blank or ';'.</li>\n";
    print "</ul>\n";

    print "<table class='img' border='1'>\n";

    # Product Name
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Product Name</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='product_name' value='"
      . escapeHTML($db_product_name)
      . "' size='80' maxLength='1000'/>"
      . "</td>\n";
    print "</tr>\n";

    # Prot Desc
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Prot Description</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='prot_desc' value='"
      . escapeHTML($db_prot_desc)
      . "' size='80' maxLength='1000'/>"
      . "</td>\n";
    print "</tr>\n";

    # EC number
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>EC Number</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='ec_number' value='"
      . escapeHTML($db_ec_number)
      . "' size=80' maxLength='1000'/>"
      . "</td>\n";
    print "</tr>\n";

    # PUBMED ID
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>PUBMED ID</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='pubmed_id' value='"
      . escapeHTML($db_pubmed_id)
      . "' size='80' maxLength='1000'/>"
      . "</td>\n";
    print "</tr>\n";

    # Inference
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Inference</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='inference' value='"
      . escapeHTML($db_inference)
      . "' size='80' maxLength='500'/>"
      . "</td>\n";
    print "</tr>\n";

    # is pseudo gene?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Pseudo Gene?</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='is_pseudogene' class='img' size='2'>\n";
    if ( blankStr($db_is_pseudogene) || lc($db_is_pseudogene) ne 'yes' ) {
        $db_is_pseudogene = 'No';
    }
    for my $tt ( 'No', 'Yes' ) {
        print "        <option value='$tt' ";
        if ( lc($tt) eq lc($db_is_pseudogene) ) {
            print "selected ";
        }
        print ">$tt</option>\n";
    }
    print "     </select></td>\n";
    print "</tr>\n";

    # Notes
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Notes</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='notes' value='"
      . escapeHTML($db_notes)
      . "' size='80' maxLength='1000'/>"
      . "</td>\n";
    print "</tr>\n";

    # Gene Symbol
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Gene Symbol</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='gene_symbol' value='"
      . escapeHTML($db_gene_symbol)
      . "' size='80' maxLength='100'/>"
      . "</td>\n";
    print "</tr>\n";

    # obsolete flag
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Remove Gene from Genome?</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='obsolete_flag' class='img' size='2'>\n";
    if ( blankStr($db_obsolete_flag) || lc($db_obsolete_flag) ne 'yes' ) {
        $db_obsolete_flag = 'No';
    }
    for my $tt ( 'No', 'Yes' ) {
        print "        <option value='$tt' ";
        if ( lc($tt) eq lc($db_obsolete_flag) ) {
            print "selected ";
        }
        print ">$tt</option>\n";
    }
    print "     </select></td>\n";
    print "</tr>\n";

    # is public?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Public?</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='is_public' class='img' size='2'>\n";
    if ( blankStr($db_is_public) || lc($db_is_public) ne 'yes' ) {
        $db_is_public = 'No';
    }
    for my $tt ( 'No', 'Yes' ) {
        print "        <option value='$tt' ";
        if ( lc($tt) eq lc($db_is_public) ) {
            print "selected ";
        }
        print ">$tt</option>\n";
    }
    print "     </select></td>\n";
    print "</tr>\n";

    print "</table>\n";

    ## share with group?
    my $sql =
        "select cig.img_group, g.group_name "
      . "from contact_img_groups\@imgsg_dev cig, img_group\@imgsg_dev g "
      . "where cig.contact_oid = ? and cig.img_group = g.group_id ";
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my %group_h;
    for ( ; ; ) {
        my ( $g_id, $g_name ) = $cur->fetchrow();
        last if !$g_id;

        $group_h{$g_id} = $g_name;
    }
    $cur->finish();

    my @groups = ( keys %group_h );
    if ( scalar(@groups) > 0 ) {
        ## check existing sharing
        $sql =
            "select gene_oid, contact_oid, group_id "
          . "from gene_myimg_groups\@img_ext where gene_oid = ? "
          . "and contact_oid = ? ";
        $cur = execSql( $dbh, $sql, $verbose, $load_gene_oid, $contact_oid );
        my %share_h;
        for ( ; ; ) {
            my ( $g_id, $c_id, $grp ) = $cur->fetchrow();
            last if !$g_id;

            $share_h{$grp} = "checked";
        }
        $cur->finish();

        print "<h4>Share Annotation with Group</h4>\n";
        print
"<p>This annotation will not be visiable by other group members if it is a private annotation and no group is selected.\n";
        for my $g1 (@groups) {
            my $ck = $share_h{$g1};
            print "<p>" . nbsp(3) . "<input type='checkbox' ";
            print "name='share_w_group' value='$g1' $ck />" . nbsp(1) . $group_h{$g1} . "\n";
        }

        print
"<p><b>Update Mode:</b> <input type='radio' name='update_ann_type' value='both' checked />Update both annotation and sharing<br/>\n";
        print nbsp(12) . "<input type='radio' name='update_ann_type' value='ann_only' />Update annotation only<br/>\n";
        print nbsp(12) . "<input type='radio' name='update_ann_type' value='share_only' />Update sharing only<br/>\n";
    }

    # buttons
    print "<p>\n";
    my $name = "_section_${section}_updateAnnotations_noHeader";
    print submit(
        -name  => $name,
        -value => "Update Annotation",
        -class => "meddefbutton"
    );
    print nbsp(1);
    my $name = "_section_${section}_deleteAnnotations_noHeader";
    print submit(
        -name  => $name,
        -value => "Delete Annotation",
        -class => "medbutton"
    );
    print nbsp(1);
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print nbsp(1);
    my $name = "_section_GeneCartStor_geneCart";
    print submit(
        -name  => $name,
        -value => 'Cancel',
        -class => 'smbutton'
    );

    print "<p>\n";
    print end_form();
}

############################################################################
# printMyMissingGenesForm
############################################################################
sub printMyMissingGenesForm {
    WebUtil::printMainForm();

    print "<h1>My Missing Gene Annotations</h1>\n";

    print WebUtil::hiddenVar( 'source_page', 'my_missing_gene' );

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return;
    }
    my $dbh = WebUtil::dbLogin();

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
		select t.taxon_oid, t.taxon_display_name, 
		    t.domain, t.seq_status, count(*)
		from taxon t, mygene g
		where g.created_by = ?
		    and g.taxon = t.taxon_oid
		    $rclause
		    $imgClause
		group by t.taxon_oid, t.taxon_display_name, t.domain, t.seq_status
		having count(*) > 0
		order by t.taxon_display_name
	};
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );

    my $cnt0 = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name, $domain, $seq_status, $g_cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        if ( $cnt0 == 0 ) {
            print "<table class='img'>\n";
            print "<th class='img'>Select</th>\n";
            print "<th class='img'>Taxon Display Name</th>\n";
            print "<th class='img'>Count</th>\n";
        }

        print "<tr class='img'>\n";

        my $ck = "checked";
        print "<td class='checkbox'>\n";
        print "<input type='checkbox' ";
        print "name='taxon_oid' value='$taxon_oid' $ck />\n";
        print "</td>\n";

        if ( length($domain) > 0 ) {
            $domain = substr( $domain, 0, 1 );
        }
        if ( length($seq_status) > 0 ) {
            $seq_status = substr( $seq_status, 0, 1 );
        }
        $taxon_name .= " [$domain][$seq_status]";

        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        print "<td class='img' >" . alink( $url, $taxon_name ) . "</td>\n";

        print "<td class='img'>" . $g_cnt . "</td>\n";
        print "</td>\n";
        $cnt0++;
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( $cnt0 == 0 ) {
        print "<h4>No My Missing Gene Annotations.</h4>\n";
    } else {
        print "</table>\n";
    }

    print "<p>\n";
    my $name = "_section_${section}_viewMyTaxonMissingGenes";
    print submit(
        -name  => $name,
        -value => "View Missing Gene Annotations",
        -class => "meddefbutton"
    );
    print nbsp(2);
    my $name = "_section_${section}_selectTaxonForMissingGene";
    print submit(
        -name  => $name,
        -value => "Add Missing Gene Annotation",
        -class => "medbutton"
    );

    print nbsp(2);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(2);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    my @my_groups = DataEntryUtil::db_getImgGroups($contact_oid);
    if ( $cnt0 > 0 && scalar(@my_groups) > 0 ) {
        print "<h2>Update Missing Gene Sharing in Selected Genome(s)</h2>\n";
        print
"<p>Share or remove sharing of all missing genes in selected genome(s). <b>(Note: You will have to select <u>all</u> groups included in your previous sharing; otherwise the sharing will be removed.)</b>\n";
        print "<p>\n";

        print
"<p><b>Option:</b> <input type='radio' name='taxon_missing_gene_mode' value='private' checked />Remove group sharing for all my missing gene annotations<br/>\n";
        print nbsp(6)
          . "<input type='radio' name='taxon_missing_gene_mode' value='group' />Share all missing genes with selected group(s)<br/>\n";
        for my $g1 (@my_groups) {
            my ( $g_id, $g_name ) = split( /\t/, $g1 );
            print nbsp(10) . "<input type='checkbox' name='share_w_group' value='$g_id'>$g_name<br/>\n";
        }

        my $name = "_section_${section}_dbShareTaxonMissingGene";
        print submit(
            -name  => $name,
            -value => "Update Sharing",
            -class => "medbutton"
        );
    }

    print end_form();
}

############################################################################
# printMyTaxonMissingGenesForm
############################################################################
sub printMyTaxonMissingGenesForm {
    print "<h1>My Missing Gene Annotations for Selected Genomes</h1>\n";

    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return;
    }
    my @taxon_oids = param('taxon_oid');
    if ( scalar(@taxon_oids) == 0 ) {
        WebUtil::webError( "There are no genome selections. Please select at least one genome." );
        return;
    }

    print WebUtil::hiddenVar( 'source_page', 'viewMyTaxonMissingGenes' );

    my $taxon_cond = "t.taxon_oid in (";
    my $max_in_cnt = 1000;
    if ( scalar(@taxon_oids) > $max_in_cnt ) {
        $taxon_cond = "(t.taxon_oid in (";
    }
    my $cnt1 = 0;
    for my $taxon_oid (@taxon_oids) {
        print WebUtil::hiddenVar( 'taxon_oid', $taxon_oid );
        $cnt1++;

        if ( ( $cnt1 % $max_in_cnt ) == 1 ) {
            if ( $cnt1 > $max_in_cnt ) {
                $taxon_cond .= ") or t.taxon_oid in ($taxon_oid";
            } else {
                $taxon_cond .= $taxon_oid;
            }
        } else {
            $taxon_cond .= ", $taxon_oid";
        }
    }
    $taxon_cond .= ")";
    if ( scalar(@taxon_oids) > $max_in_cnt ) {
        $taxon_cond .= ")";
    }

    ## get my gene img term count
    #    my $dbh2 = Connect_IMG_EXT();
    my $dbh = WebUtil::dbLogin();
    my %term_cnt_h;
    my $sql = qq{
            select mt.mygene_oid, count(*)
            from mygene_terms mt
            where mt.modified_by = ?
            group by mt.mygene_oid
            };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ( $mygene_oid, $cnt ) = $cur->fetchrow();
        last if !$mygene_oid;
        $term_cnt_h{$mygene_oid} = $cnt;
    }
    $cur->finish();

    #    $dbh2->disconnect();

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    ## get my gene definition
    $sql = qq{
		select t.taxon_oid, t.taxon_display_name, 
		    t.domain, t.seq_status, g.mygene_oid, g.product_name,
		    g.locus_type, g.locus_tag, s.ext_accession,
		    g.dna_coords, g.strand, g.hitgene_oid, g.is_public,
                    g.replacing_gene
		from taxon t, mygene g, scaffold s
		where g.created_by = ?
		    $rclause
		    $imgClause
		    and $taxon_cond
		    and g.taxon = t.taxon_oid
		    and g.scaffold = s.scaffold_oid (+)
		order by t.taxon_display_name, g.mygene_oid
	};
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid );

    my $it = new InnerTable( 1, "myMissingGene$$", "myMissingGene", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Genome Name",       "char asc",   "left" );
    $it->addColSpec( "Missing Gene ID",   "number asc", "right" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Locus Type",        "char asc",   "left" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Scaffold",          "char asc",   "left" );
    $it->addColSpec( "DNA Coordinates",   "char asc",   "left" );
    $it->addColSpec( "Strand",            "char asc",   "left" );
    $it->addColSpec( "Is Public?",        "char asc",   "left" );
    $it->addColSpec( "Hit Gene",          "number asc", "right" );
    $it->addColSpec( "Replacing Gene(s)", "number asc", "right" );
    $it->addColSpec( "IMG Term Count",    "number asc", "right" );
    my $sd = $it->getSdDelim();

    my $cnt0 = 0;
    for ( ; ; ) {
        my (
            $taxon_oid, $taxon_name, $domain,     $seq_status, $mygene_oid,  $prod_name, $locus_type,
            $locus_tag, $scaffold,   $dna_coords, $strand,     $hitgene_oid, $is_public, $replacing_gene
          )
          = $cur->fetchrow();
        last if !$taxon_oid;

        my $r = $sd . "<input type='radio' name='mygene_oid' value='$mygene_oid' /> \t";

        if ( length($domain) > 0 ) {
            $domain = substr( $domain, 0, 1 );
        }
        if ( length($seq_status) > 0 ) {
            $seq_status = substr( $seq_status, 0, 1 );
        }
        $taxon_name .= " [$domain][$seq_status]";

        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_name . $sd . alink( $url, $taxon_name ) . "\t";

        #	my $url =  "$main_cgi?section=MyIMG" .
        #	    "&page=displayMissingGeneInfo&mygene_oid=$mygene_oid";
        my $url = "$main_cgi?section=MyGeneDetail" . "&page=geneDetail&gene_oid=$mygene_oid";
        $r .= $mygene_oid . $sd . alink( $url, $mygene_oid ) . "\t";
        $r .= $prod_name . $sd . $prod_name . "\t";
        $r .= $locus_type . $sd . $locus_type . "\t";
        $r .= $locus_tag . $sd . $locus_tag . "\t";
        $r .= $scaffold . $sd . $scaffold . "\t";
        $r .= $dna_coords . $sd . $dna_coords . "\t";
        $r .= $strand . $sd . $strand . "\t";
        $r .= $is_public . $sd . $is_public . "\t";

        if ($hitgene_oid) {
            my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$hitgene_oid";
            $r .= $hitgene_oid . $sd . alink( $url, $hitgene_oid ) . "\t";
        } else {
            $r .= $sd . " \t";
        }

        if ($replacing_gene) {
            $r .= $replacing_gene . $sd;
            my @old_genes = split( /\,/, $replacing_gene );
            for my $g2 (@old_genes) {
                $g2 = strTrim($g2);
                if ( $g2 && isInt($g2) ) {
                    my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$g2";
                    $r .= alink( $url, $g2 ) . "<br/>";
                }
            }    # end for $g2
            $r .= "\t";
        } else {
            $r .= $sd . " \t";
        }

        if ( $term_cnt_h{$mygene_oid} ) {
            $r .= $term_cnt_h{$mygene_oid} . $sd . $term_cnt_h{$mygene_oid} . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }

        $it->addRow($r);
        $cnt0++;
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( $cnt0 == 0 ) {
        print "<h4>No My Missing Gene Annotations.</h4>\n";
    } else {
        $it->printOuterTable(1);
    }

    print "<p>\n";
    my $name = "_section_${section}_updateMyTaxonMissingGenes";
    print submit(
        -name  => $name,
        -value => "Update Missing Gene Annotation",
        -class => "meddefbutton"
    );
    print nbsp(2);
    my $name = "_section_${section}_deleteMyTaxonMissingGene";
    print submit(
        -name  => $name,
        -value => "Delete Missing Gene Annotation",
        -class => "medbutton"
    );
    print nbsp(2);
    my $name = "_section_${section}_selectTaxonForMissingGene";
    print submit(
        -name  => $name,
        -value => "Add Missing Gene Annotation",
        -class => "medbutton"
    );

    print nbsp(2);
    my $name = "_section_${section}_updateTermForm";
    print submit(
        -name  => $name,
        -value => "Add/Update IMG Term(s)",
        -class => "medbutton"
    );

    my @my_groups = DataEntryUtil::db_getImgGroups($contact_oid);
    if ( $cnt0 > 0 && scalar(@my_groups) > 0 ) {
        print "<h2>Update Group Sharing</h2>\n";
        print
"<p>Share or remove sharing of selected missing gene. <b>(Note: You will have to select <u>all</u> groups included in your previous sharing; otherwise the sharing will be removed.)</b>\n";
        print "<p>\n";

        my $name = "_section_${section}_shareMissingGene";
        print submit(
            -name  => $name,
            -value => "Update Sharing",
            -class => "medbutton"
        );
    }

    print end_form();
}

############################################################################
# dbShareTaxonMyIMGAnnotations
############################################################################
sub dbShareTaxonMyIMGAnnotations {

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return "Session expired.  Please log in again.";
    }

    my @taxon_oids = param('taxon_oid');
    if ( scalar(@taxon_oids) == 0 ) {
        return "No genome is selected.";
    } elsif ( scalar(@taxon_oids) > 1000 ) {
        return "Please select no more than 1000 genomes.";
    }
    my $taxon_list = join( ", ", @taxon_oids );

    my $option = param('taxon_myimg_mode');
    my @groups = param('share_w_group');

    my $sql = qq{
        delete from gene_myimg_groups\@img_ext 
        where contact_oid = $contact_oid 
        and gene_oid in (select f.gene_oid 
            from gene_myimg_functions f, gene g
            where f.modified_by = $contact_oid 
            and f.gene_oid = g.gene_oid
            and g.taxon in ($taxon_list))
        };
    my @sqlList = ($sql);

    if ( $option eq 'group' ) {
        for my $g1 (@groups) {
            $sql =
                "insert into gene_myimg_groups\@img_ext (gene_oid, contact_oid, group_id) "
              . "select distinct f.gene_oid, $contact_oid, $g1 "
              . "from gene_myimg_functions f, gene g "
              . "where g.taxon in ($taxon_list) "
              . "and g.gene_oid = f.gene_oid "
              . "and f.modified_by = $contact_oid ";
            push @sqlList, ($sql);
        }
    }

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        return "SQL Error: $sql";
    }

    return "";
}

############################################################################
# dbShareTaxonMissingGene
############################################################################
sub dbShareTaxonMissingGene {

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return "Session expired.  Please log in again.";
    }

    my @taxon_oids = param('taxon_oid');
    if ( scalar(@taxon_oids) == 0 ) {
        return "No genome is selected.";
    } elsif ( scalar(@taxon_oids) > 1000 ) {
        return "Please select no more than 1000 genomes.";
    }
    my $taxon_list = join( ", ", @taxon_oids );

    my $option = param('taxon_missing_gene_mode');
    my @groups = param('share_w_group');

    my $sql =
"delete from mygene_img_groups\@img_ext where contact_oid = $contact_oid and mygene_oid in (select mygene_oid from mygene where created_by = $contact_oid and taxon in ($taxon_list))";
    my @sqlList = ($sql);

    if ( $option eq 'group' ) {
        for my $g1 (@groups) {
            $sql =
                "insert into mygene_img_groups\@img_ext (mygene_oid, contact_oid, group_id) "
              . "select g.mygene_oid, g.created_by, $g1 "
              . "from mygene g where g.taxon in ($taxon_list) ";
            push @sqlList, ($sql);
        }
    }

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        return "SQL Error: $sql";
    }

    return "";
}

############################################################################
# shareMissingGeneForm
############################################################################
sub shareMissingGeneForm {
    print "<h1>Share Missing Gene Annotation</h1>\n";

    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        WebUtil::webError("Session expired.  Please log in again.");
        return;
    }

    ## save selected taxons
    my @taxon_oids = param('taxon_oid');
    for my $taxon_oid (@taxon_oids) {
        print WebUtil::hiddenVar( 'taxon_oid', $taxon_oid );
    }

    my $gene_oid = param('mygene_oid');
    if ( !$gene_oid ) {
        WebUtil::webError( "There is no gene selection. Please select one gene." );
        return;
    }

    my $dbh = dbLogin();
    my $sql = "select mygene_oid, product_name, is_public from mygene where mygene_oid = ? and modified_by = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $contact_oid );
    my ( $g2, $g_name, $is_public ) = $cur->fetchrow();
    $cur->finish();

    if ( !$g2 ) {
        WebUtil::webError("Incorrect gene ID $gene_oid");
        return;
    }

    print "<h3>Gene $g2: $g_name (Is Public? $is_public)</h3>\n";
    print WebUtil::hiddenVar( 'mygene_oid', $gene_oid );
    print "<p>This annotation will not be visiable by other group members if it is private and no group is selected.\n";
    print "Please select all the groups that you wish to share this missing gene information:</p>\n";

    ## share with group?
    my @my_groups = DataEntryUtil::db_getImgGroups($contact_oid);
    my $sql       =
        "select mig.group_id from mygene_img_groups\@img_ext mig "
      . "where mig.contact_oid = ? and mig.mygene_oid = ? "
      . "and mig.group_id is not null";
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $gene_oid );
    my %group_h;
    for ( ; ; ) {
        my ($g_id) = $cur->fetchrow();
        last if !$g_id;

        $group_h{$g_id} = "checked";
    }
    $cur->finish();

    for my $g1 (@my_groups) {
        my ( $g_id, $g_name ) = split( /\t/, $g1 );
        my $ck = $group_h{$g_id};
        print "<p>" . nbsp(3) . "<input type='checkbox' ";
        print "name='share_w_group' value='$g_id' $ck />" . nbsp(1) . $g_name . "\n";
    }

    print "<p>\n";

    my $name = "_section_${section}_dbUpdateMissingGeneSharing";
    print submit(
        -name  => $name,
        -value => "Update Sharing",
        -class => "medbutton"
    );
    print nbsp(1);
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print nbsp(1);
    my $name = "_section_${section}_viewMyTaxonMissingGenes";
    print submit(
        -name  => $name,
        -value => 'Cancel',
        -class => 'smbutton'
    );

    print "<p>\n";

    print end_form();
}

############################################################################
# dbUpdateMissingGeneSharing
############################################################################
sub dbUpdateMissingGeneSharing {

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return "Session expired.  Please log in again.";
        return;
    }

    my $gene_oid = param('mygene_oid');
    if ( !$gene_oid ) {
        return "No gene is selected.";
    }

    my @groups  = param('share_w_group');
    my $sql     = "delete from mygene_img_groups\@img_ext where mygene_oid = $gene_oid and contact_oid = $contact_oid";
    my @sqlList = ($sql);
    for my $g1 (@groups) {
        $sql =
            "insert into mygene_img_groups\@img_ext (mygene_oid, contact_oid, group_id) "
          . "values ($gene_oid, $contact_oid, $g1)";
        push @sqlList, ($sql);
    }

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        return "SQL Error: $sql";
    }

    return "";
}

############################################################################
# printPublicTaxonMissingGenesForm
############################################################################
sub printPublicTaxonMissingGenesForm {
    print "<h1>All Public Missing Gene Annotations for Selected Genomes</h1>\n";

    WebUtil::printMainForm();

    my $contact_oid = WebUtil::getContactOid();
    my @taxon_oids  = param('taxon_oid');
    if ( scalar(@taxon_oids) == 0 ) {
        WebUtil::webError( "There are no genome selections. Please select at least one genome." );
        return;
    }

    my $dbh = WebUtil::dbLogin();
    my %loaded_genes;

    my $taxon_cond = "t.taxon_oid in (";
    my $max_in_cnt = 1000;
    if ( scalar(@taxon_oids) > $max_in_cnt ) {
        $taxon_cond = "(t.taxon_oid in (";
    }
    my $cnt1 = 0;
    for my $taxon_oid (@taxon_oids) {
        $cnt1++;

        if ( ( $cnt1 % $max_in_cnt ) == 1 ) {
            if ( $cnt1 > $max_in_cnt ) {
                $taxon_cond .= ") or t.taxon_oid in ($taxon_oid";
            } else {
                $taxon_cond .= $taxon_oid;
            }
        } else {
            $taxon_cond .= ", $taxon_oid";
        }

        my $sql2 =
          "select g.gene_oid from gene g where g.gene_oid < 600000000 " . "and g.obsolete_flag = 'No' and g.taxon = ?";
        my $cur2 = execSql( $dbh, $sql2, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ($gid2) = $cur2->fetchrow();
            last if !$gid2;

            $loaded_genes{$gid2} = $gid2;
        }
        $cur2->finish();
    }
    $taxon_cond .= ")";
    if ( scalar(@taxon_oids) > $max_in_cnt ) {
        $taxon_cond .= ")";
    }

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
		select t.taxon_oid, t.taxon_display_name, 
		    t.domain, t.seq_status, g.mygene_oid, g.product_name,
		    g.locus_type, g.locus_tag, s.ext_accession,
		    g.dna_coords, g.strand, g.hitgene_oid, g.is_public,
                    g.replacing_gene, c.name, c.email
		from taxon t, mygene g, scaffold s, contact c
		where g.is_public = 'Yes'
		    $rclause
		    $imgClause
		    and $taxon_cond
		    and g.taxon = t.taxon_oid
                    and g.created_by = c.contact_oid
		    and g.scaffold = s.scaffold_oid (+)
		order by t.taxon_display_name, g.mygene_oid
	};
    my $cur = execSql( $dbh, $sql, $verbose );

    my $it = new InnerTable( 1, "groupMissingGene$$", "groupMissingGene", 1 );
    $it->addColSpec( "Genome Name",       "char asc",   "left" );
    $it->addColSpec( "IMG Contact",       "char asc",   "left" );
    $it->addColSpec( "Missing Gene ID",   "number asc", "right" );
    $it->addColSpec( "Added in IMG?",     "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Locus Type",        "char asc",   "left" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Scaffold",          "char asc",   "left" );
    $it->addColSpec( "DNA Coordinates",   "char asc",   "left" );
    $it->addColSpec( "Strand",            "char asc",   "left" );
    $it->addColSpec( "Is Public?",        "char asc",   "left" );
    $it->addColSpec( "Hit Gene",          "number asc", "right" );
    $it->addColSpec( "Replacing Gene(s)", "number asc", "right" );
    my $sd = $it->getSdDelim();

    my $cnt0 = 0;
    for ( ; ; ) {
        my (
            $taxon_oid,  $taxon_name,     $domain,   $seq_status, $mygene_oid, $prod_name,
            $locus_type, $locus_tag,      $scaffold, $dna_coords, $strand,     $hitgene_oid,
            $is_public,  $replacing_gene, $c_name,   $c_email
          )
          = $cur->fetchrow();
        last if !$taxon_oid;

        if ( length($domain) > 0 ) {
            $domain = substr( $domain, 0, 1 );
        }
        if ( length($seq_status) > 0 ) {
            $seq_status = substr( $seq_status, 0, 1 );
        }
        $taxon_name .= " [$domain][$seq_status]";

        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $r .= $taxon_name . $sd . alink( $url, $taxon_name ) . "\t";

        if ($c_email) {
            $c_name .= " ($c_email)";
        }
        $r .= $c_name . $sd . $c_name . "\t";

        $url = "$main_cgi?section=MyGeneDetail" . "&page=geneDetail&gene_oid=$mygene_oid";
        $r .= $mygene_oid . $sd . alink( $url, $mygene_oid ) . "\t";

        if ( $loaded_genes{$mygene_oid} ) {
            my $url2 = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$mygene_oid";
            $r .= "Yes" . $sd . alink( $url2, "Yes" ) . "\t";
        } else {
            $r .= "No" . $sd . "No" . "\t";
        }
        $r .= $prod_name . $sd . $prod_name . "\t";
        $r .= $locus_type . $sd . $locus_type . "\t";
        $r .= $locus_tag . $sd . $locus_tag . "\t";
        $r .= $scaffold . $sd . $scaffold . "\t";
        $r .= $dna_coords . $sd . $dna_coords . "\t";
        $r .= $strand . $sd . $strand . "\t";
        $r .= $is_public . $sd . $is_public . "\t";

        if ($hitgene_oid) {
            my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$hitgene_oid";
            $r .= $hitgene_oid . $sd . alink( $url, $hitgene_oid ) . "\t";
        } else {
            $r .= " " . $sd . " \t";
        }

        if ($replacing_gene) {
            $r .= $replacing_gene . $sd;
            my @old_genes = split( /\,/, $replacing_gene );
            for my $g2 (@old_genes) {
                $g2 = strTrim($g2);
                if ( $g2 && isInt($g2) ) {
                    my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$g2";
                    $r .= alink( $url, $g2 ) . "<br/>";
                }
            }    # end for $g2
            $r .= "\t";
        } else {
            $r .= $sd . " \t";
        }

        $it->addRow($r);
        $cnt0++;
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( $cnt0 == 0 ) {
        print "<h4>No Public Missing Gene Annotations.</h4>\n";
    } else {
        $it->printOuterTable(1);
    }

    print end_form();
}

############################################################################
# printGroupMissingGenesForm
############################################################################
sub printGrpAllMissingGenesForm {
    my ($view_type) = @_;

    WebUtil::printMainForm();

    my @my_groups = DataEntryUtil::db_getImgGroups($contact_oid);
    if ( scalar(@my_groups) == 0 ) {
        WebUtil::webError("You do not belong to any IMG group.");
    }

    my $grp = param('selected_group');
    if ( !$grp ) {
        my @arr = split( /\t/, $my_groups[0] );
        if ( scalar(@arr) > 0 ) {
            $grp = $arr[0];
        }
    }

    if ( $view_type eq 'all' ) {
        print "<h1>All Missing Gene Annotations</h1>\n";
        print WebUtil::hiddenVar( 'source_page', 'all_missing_gene' );
    } else {
        print "<h1>Group Missing Gene Annotations</h1>\n";
        print WebUtil::hiddenVar( 'source_page', 'group_missing_gene' );

        print
"<p><b>Note: Only annotations available to group members are listed here. Private user annotations not shared with this group are hidden.</b>\n";

        my $view_type = param('view_type');
        my $new_url   =
          $section_cgi . "&page=viewGroupMissingGenes" . "&view_type=$view_type" . "&source_page=group_missing_gene";

        print "<p>IMG Group: \n";
        print qq{
          <select name='selected_group'
              onchange="window.location='$new_url&selected_group=' + this.value;"
              style="width:200px;">
        };

        for my $g1 (@my_groups) {
            my ( $g_id, $g_name ) = split( /\t/, $g1 );
            print "     <option value='$g_id' ";
            if ( $g_id == $grp ) {
                print " selected ";
            }
            print ">$g_id: $g_name</option>\n";
        }
        print "</select><br/>\n";
    }

    print "<p>\n";

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return;
    }
    my $super_user_flag = getSuperUser();
    if ( $view_type eq 'all' && $super_user_flag ne 'Yes' ) {
        WebUtil::webError("You cannot view all missing gene annotations.");
        return;
    } elsif ( !$grp ) {
        WebUtil::webError("No group has been selected.");
        return;
    }

    print "<p>\n";
    my $name = "_section_${section}_viewGroupTaxonMissingGenes";
    if ( $view_type eq 'all' ) {
        $name = "_section_${section}_viewAllTaxonMissingGenes";
    }
    print submit(
        -name  => $name,
        -value => "View Missing Gene Annotations",
        -class => "meddefbutton"
    );
    print nbsp(2);
    my $name = "_section_${section}_selectTaxonForMissingGene";
    print submit(
        -name  => $name,
        -value => "Add Missing Gene Annotation",
        -class => "medbutton"
    );

    print nbsp(2);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(2);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    my $grp_cond =
" and c.contact_oid in (select cig.contact_oid from contact_img_groups\@imgsg_dev cig where cig.img_group = $grp) and (g.is_public = 'Yes' or g.mygene_oid in (select mig.mygene_oid from mygene_img_groups\@img_ext mig where mig.group_id = $grp)) ";
    if ( $view_type eq 'all' ) {
        $grp_cond = " ";
    }

    my $dbh       = WebUtil::dbLogin();
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
		select t.taxon_oid, t.taxon_display_name, 
		    t.domain, t.seq_status, 
		    c.contact_oid, c.name, c.email, count(*)
		from taxon t, mygene g, contact c
		where g.created_by = c.contact_oid
		    $grp_cond
		    $rclause
		    $imgClause
		    and g.taxon = t.taxon_oid
		group by t.taxon_oid, t.taxon_display_name, 
		    t.domain, t.seq_status, 
		    c.contact_oid, c.name, c.email
		having count(*) > 0
		order by t.taxon_display_name, c.name
	};
    my $cur = execSql( $dbh, $sql, $verbose );

    my $cnt0       = 0;
    my $prev_taxon = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_name, $domain, $seq_status, $c_oid, $c_name, $c_email, $g_cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        if ( $cnt0 == 0 ) {
            print "<table class='img'>\n";
            print "<th class='img'>Select</th>\n";
            print "<th class='img'>Taxon Display Name</th>\n";
            print "<th class='img'>IMG Contact</th>\n";
            print "<th class='img'>Count</th>\n";
        }

        print "<tr class='img'>\n";

        if ( $taxon_oid != $prev_taxon ) {
            print "<td class='checkbox'>\n";
            print "<input type='checkbox' ";
            print "name='taxon_oid' value='$taxon_oid' checked />\n";
            print "</td>\n";
            $prev_taxon = $taxon_oid;
        } else {
            print "<td class='img'></td>\n";
        }

        if ( length($domain) > 0 ) {
            $domain = substr( $domain, 0, 1 );
        }
        if ( length($seq_status) > 0 ) {
            $seq_status = substr( $seq_status, 0, 1 );
        }
        $taxon_name .= " [$domain][$seq_status]";

        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        print "<td class='img' >" . alink( $url, $taxon_name ) . "</td>\n";

        my $img_user = $c_name;
        if ($c_email) {
            $img_user .= " ($c_email)";
        }
        print "<td class='img'>" . escapeHTML($img_user) . "</td>\n";
        print "<td class='img'>" . $g_cnt . "</td>\n";
        print "</td>\n";
        $cnt0++;
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( $cnt0 == 0 ) {
        print "<h4>No Group Missing Gene Annotations.</h4>\n";
    } else {
        print "</table>\n";
    }

    print "<p>\n";
    my $name = "_section_${section}_viewGroupTaxonMissingGenes";
    if ( $view_type eq 'all' ) {
        $name = "_section_${section}_viewAllTaxonMissingGenes";
    }
    print submit(
        -name  => $name,
        -value => "View Missing Gene Annotations",
        -class => "meddefbutton"
    );
    print nbsp(2);
    my $name = "_section_${section}_selectTaxonForMissingGene";
    print submit(
        -name  => $name,
        -value => "Add Missing Gene Annotation",
        -class => "medbutton"
    );

    print nbsp(2);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(2);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    print end_form();
}

############################################################################
# printGrpAllTaxonMissingGenesForm
############################################################################
sub printGrpAllTaxonMissingGenesForm {
    my ($view_type) = @_;

    WebUtil::printMainForm();

    my @my_groups = DataEntryUtil::db_getImgGroups($contact_oid);
    if ( scalar(@my_groups) == 0 ) {
        WebUtil::webError("You do not belong to any IMG group.");
    }

    my $grp = param('selected_group');
    if ( !$grp ) {
        my @arr = split( /\t/, $my_groups[0] );
        if ( scalar(@arr) > 0 ) {
            $grp = $arr[0];
        }
    }

    if ( $view_type eq 'all' ) {
        print "<h1>All Missing Gene Annotations for Selected Genomes</h1>\n";
        print WebUtil::hiddenVar( 'source_page', 'all_missing_gene' );
    } else {
        print "<h1>Group Missing Gene Annotations for Selected Genomes</h1>\n";
        print WebUtil::hiddenVar( 'source_page', 'group_missing_gene' );

        print "<h4>IMG Group: \n";
        for my $g1 (@my_groups) {
            my ( $g_id, $g_name ) = split( /\t/, $g1 );
            if ( $g_id == $grp ) {
                print "$g_name</h4>\n";
                last;
            }
        }

        print
"<p><b>Note: Only annotations available to group members are listed here. Private user annotations not shared with this group are hidden.</b>\n";
    }

    print
"<p>You can only update or delete your own missing gene annotations. Click 'Missing Gene OID' value to view missing gene annotations by other users.</p>\n";

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return;
    }
    my $super_user_flag = getSuperUser();

    if ( $super_user_flag eq 'Yes' ) {
        print "<p><b>Super users:</b> You can update any public mssing gene annotations. "
          . "However, you cannot delete others' annotations. "
          . "If you do not agree with the annotations, mark them private instead.</p>\n";
    }

    if ( $view_type eq 'all' && $super_user_flag ne 'Yes' ) {
        WebUtil::webError("You cannot view all missing gene annotations.");
        return;
    } elsif ( !$grp ) {
        WebUtil::webError("No group has been selected.");
        return;
    }

    my $grp_cond =
" and c.contact_oid in (select cig.contact_oid from contact_img_groups\@imgsg_dev cig where cig.img_group = $grp) and (g.is_public = 'Yes' or g.mygene_oid in (select mig.mygene_oid from mygene_img_groups\@img_ext mig where mig.group_id = $grp)) ";
    if ( $view_type eq 'all' ) {
        $grp_cond = " ";
    }

    my @taxon_oids = param('taxon_oid');
    if ( scalar(@taxon_oids) == 0 ) {
        WebUtil::webError( "There are no genome selections. Please select at least one genome." );
        return;
    }
    my $taxon_cond = "t.taxon_oid in (";
    my $max_in_cnt = 1000;
    if ( scalar(@taxon_oids) > $max_in_cnt ) {
        $taxon_cond = "(t.taxon_oid in (";
    }
    my $cnt1 = 0;
    for my $taxon_oid (@taxon_oids) {
        $cnt1++;

        if ( ( $cnt1 % $max_in_cnt ) == 1 ) {
            if ( $cnt1 > $max_in_cnt ) {
                $taxon_cond .= ") or t.taxon_oid in ($taxon_oid";
            } else {
                $taxon_cond .= $taxon_oid;
            }
        } else {
            $taxon_cond .= ", $taxon_oid";
        }
    }
    $taxon_cond .= ")";
    if ( scalar(@taxon_oids) > $max_in_cnt ) {
        $taxon_cond .= ")";
    }

    my $dbh = WebUtil::dbLogin();
    my $sql = "select c.contact_oid, c.name, c.email from contact c";
    my $cur = execSql( $dbh, $sql, $verbose );
    my %contact_list_h;
    for ( ; ; ) {
        my ( $c_oid, $c_name, $c_email ) = $cur->fetchrow();
        last if !$c_oid;
        $contact_list_h{$c_oid} = $c_name;
        if ($c_email) {
            $contact_list_h{$c_oid} .= " (" . $c_email . ")";
        }
    }
    $cur->finish();

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
		select t.taxon_oid, t.taxon_display_name, 
		    t.domain, t.seq_status, g.created_by, g.modified_by,
		    g.mygene_oid, g.product_name, g.locus_type, g.locus_tag,
		    s.ext_accession, g.dna_coords, g.strand,
		    g.hitgene_oid, g.is_public, g.replacing_gene
		from taxon t, mygene g, scaffold s, contact c
		where g.created_by = c.contact_oid
		    $rclause
		    $imgClause
		    $grp_cond
                    and g.taxon = t.taxon_oid
		    and $taxon_cond
		    and g.scaffold = s.scaffold_oid (+)
	};
    my $cur = execSql( $dbh, $sql, $verbose );

    my $it = new InnerTable( 1, "groupMissingGene$$", "groupMissingGene", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Genome Name",       "char asc",   "left" );
    $it->addColSpec( "Missing Gene ID",   "number asc", "right" );
    $it->addColSpec( "Created By",        "char asc",   "left" );
    $it->addColSpec( "Last Modified By",  "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Locus Type",        "char asc",   "left" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Scaffold",          "char asc",   "left" );
    $it->addColSpec( "DNA Coordinates",   "char asc",   "left" );
    $it->addColSpec( "Strand",            "char asc",   "left" );
    $it->addColSpec( "Is Public?",        "char asc",   "left" );
    $it->addColSpec( "Hit Gene",          "number asc", "right" );
    $it->addColSpec( "Replacing Gene(s)", "number asc", "right" );

    my $sd = $it->getSdDelim();

    my $cnt0 = 0;
    for ( ; ; ) {
        my (
            $taxon_oid,  $taxon_name,  $domain,     $seq_status, $created_by, $modified_by,
            $mygene_oid, $prod_name,   $locus_type, $locus_tag,  $scaffold,   $dna_coords,
            $strand,     $hitgene_oid, $is_public,  $replacing_gene
          )
          = $cur->fetchrow();
        last if !$taxon_oid;

        my $r;

        if ( $contact_oid == $created_by ) {

            # same user
            $r = $sd . "<input type='radio' name='mygene_oid' value='$mygene_oid' /> \t";
        } elsif ( $super_user_flag eq 'Yes' && $is_public eq 'Yes' ) {

            # super user can edit all public missing genes
            $r = $sd . "<input type='radio' name='mygene_oid' value='$mygene_oid' /> \t";
        } else {
            $r = $sd . " \t";
        }

        if ( length($domain) > 0 ) {
            $domain = substr( $domain, 0, 1 );
        }
        if ( length($seq_status) > 0 ) {
            $seq_status = substr( $seq_status, 0, 1 );
        }
        $taxon_name .= " [$domain][$seq_status]";

        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_name . $sd . alink( $url, $taxon_name ) . "\t";

        my $url = "$main_cgi?section=MyGeneDetail" . "&page=geneDetail&gene_oid=$mygene_oid";
        $r .= $mygene_oid . $sd . alink( $url, $mygene_oid ) . "\t";

        my $c_name = $contact_list_h{$created_by};
        $r .= $c_name . $sd . $c_name . "\t";

        my $c2_name = $contact_list_h{$modified_by};
        $r .= $c2_name . $sd . $c2_name . "\t";

        $r .= $prod_name . $sd . $prod_name . "\t";
        $r .= $locus_type . $sd . $locus_type . "\t";
        $r .= $locus_tag . $sd . $locus_tag . "\t";
        $r .= $scaffold . $sd . $scaffold . "\t";
        $r .= $dna_coords . $sd . $dna_coords . "\t";
        $r .= $strand . $sd . $strand . "\t";
        $r .= $is_public . $sd . $is_public . "\t";

        if ($hitgene_oid) {
            my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$hitgene_oid";
            $r .= $hitgene_oid . $sd . alink( $url, $hitgene_oid ) . "\t";
        } else {
            $r .= " " . $sd . " \t";
        }

        if ($replacing_gene) {
            $r .= $replacing_gene . $sd;
            my @old_genes = split( /\,/, $replacing_gene );
            for my $g2 (@old_genes) {
                $g2 = strTrim($g2);
                if ( $g2 && isInt($g2) ) {
                    my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$g2";
                    $r .= alink( $url, $g2 ) . "<br/>";
                }
            }    # end for $g2
            $r .= "\t";
        } else {
            $r .= $sd . " \t";
        }

        $it->addRow($r);
        $cnt0++;
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( $cnt0 == 0 ) {
        print "<h4>No My Missing Gene Annotations.</h4>\n";
    } else {
        $it->printOuterTable(1);
    }

    print "<p>\n";
    my $name = "_section_${section}_updateMyTaxonMissingGenes";
    print submit(
        -name  => $name,
        -value => "Update Missing Gene Annotation",
        -class => "meddefbutton"
    );
    print nbsp(2);
    my $name = "_section_${section}_deleteMyTaxonMissingGene";
    print submit(
        -name  => $name,
        -value => "Delete Missing Gene Annotation",
        -class => "medbutton"
    );
    print nbsp(2);
    my $name = "_section_${section}_addMyTaxonMissingGene";
    print submit(
        -name  => $name,
        -value => "Add Missing Gene Annotation",
        -class => "medbutton"
    );
    print nbsp(2);
    my $name = "_section_${section}_updateTermForm";
    print submit(
        -name  => $name,
        -value => "Add/Update IMG Term(s)",
        -class => "medbutton"
    );

    print end_form();
}

############################################################################
# selectTaxonForMissingGeneForm
############################################################################
sub selectTaxonForMissingGeneForm {
    my ($selected_taxon) = @_;

    WebUtil::printMainForm();

    print "<h1>Select Genome for Missing Gene</h1>\n";

    my $source_page = param('source_page');
    if ($source_page) {
        print WebUtil::hiddenVar( 'source_page', 'my_missing_gene' );
    }

    print "<p><font color='blue'>" . "Please select a genome from the list below:</font></p>\n";

    my $dbh = WebUtil::dbLogin();
    GenomeListFilter::appendGenomeListFilter( $dbh, '', 0, '', '', 'No', 0, 0, 1 );

    #$dbh->disconnect();

    # any selected taxon?
    #	my $rclause   = WebUtil::urClause('t');
    #	my $imgClause = WebUtil::imgClause('t');
    #	my $sql = qq{
    #		select t.taxon_oid, t.taxon_display_name,
    #		    t.domain, t.seq_status
    #		from taxon t
    #		where 1 = 1
    #		    $rclause
    #		    $imgClause
    #		order by t.domain, t.taxon_display_name
    #	};
    #	my $cur = execSql( $dbh, $sql, $verbose );

    #	my $cnt0 = 0;
    #	for ( ; ; ) {
    #		my ( $taxon_oid, $taxon_name, $domain, $seq_status ) = $cur->fetchrow();
    #		last if !$taxon_oid;
    #
    #		if ( length($domain) > 0 ) {
    #			$domain = substr( $domain, 0, 1 );
    #		}
    #		if ( length($seq_status) > 0 ) {
    #			$seq_status = substr( $seq_status, 0, 1 );
    #		}
    #
    #		print "<option value='$taxon_oid'";
    #		if ( $taxon_oid == $selected_taxon ) {
    #			print " selected";
    #		}
    #		print ">$taxon_name [$domain][$seq_status]</option>\n";
    #	}
    #	print "</select>\n";

    my $name = "_section_${section}_addMyTaxonMissingGene";
    print submit(
        -name  => $name,
        -value => "Select to Add My Missing Gene",
        -class => "lgdefbutton"
    );

    print end_form();
}

############################################################################
# printTaxonMissingGeneForm
############################################################################
sub printTaxonMissingGeneForm {
    my (
        $mygene_oid,  $taxon_oid, $product,     $ec_number, $locus_type,
        $locus_tag,   $scaffold,  $dna_coords,  $strand,    $ispseudo,
        $description, $symbol,    $hitgene_oid, $ispublic,  $replacing_gene
      )
      = @_;

    print "<script src='$base_url/chart.js'></script>\n";
    print "<script src='$base_url/overlib.js'></script>\n";    ## for tooltips
    print toolTipCode();
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

    WebUtil::printMainForm();

    if ($mygene_oid) {
        use TabHTML;
        TabHTML::printTabAPILinks("mygeneTab");
        my @tabIndex = ( "#mygenetab1", "#mygenetab2" );
        my @tabNames = ( "Update Missing Gene Annotation", "Sequence Viewer" );

        TabHTML::printTabDiv( "mygeneTab", \@tabIndex, \@tabNames );
        print "<div id='mygenetab1'>";
        print "<h2>Missing Gene OID: $mygene_oid</h2>\n";
        print WebUtil::hiddenVar( 'mygene_oid', $mygene_oid );
    } else {
        print "<h1>New Missing Gene Annotation</h1>\n";
        if ( !$taxon_oid ) {
            WebUtil::webError("No genome has been selected.");
            return;
        }
    }

    my $source_page = param('source_page');
    if ($source_page) {
        print WebUtil::hiddenVar( 'source_page', 'my_missing_gene' );
    }

    my $hint_msg = qq{ 
           (1) Fields with (*) are required.</br> 
           (2) Use comma to separate DNA coordinate ranges; e.g., 3146..3680,5982..8922</br>
           (3) Use '<' or '>' to indicate DNA coordinates in partial gene; e.g., <1..30,25..>75</br>
           (4) Missing genes with 'Is Public?' set to Yes will be visible to all users, 
               <font color=red>and may be modified by JGI experts.</font><br/>
           (5) If this missing gene is replacing one or more existing genes, enter Gene OID(s) in the 'Replacing Gene(s)' field (comma delimited).
           };

    printHint($hint_msg);

    my $dbh        = WebUtil::dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
    my $url        = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p style='width: 650px;'>";
    print alink( $url, $taxon_name ) . "</p>\n";

    print WebUtil::hiddenVar( 'taxon_oid', $taxon_oid );

    print "<table class='img' border='1'>\n";

    # Product Name
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Product Name (*)</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='product_name' value='"
      . escapeHTML($product)
      . "' size='80' maxLength='1000'/></td>\n";
    print "</tr>\n";

    # is pseudo gene?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Locus Type (*)</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='locus_type' class='img' size='1'>\n";
    for my $tt ( 'CDS', 'tRNA', 'rRNA', 'miscRNA', 'misc_feature' ) {
        print "        <option value='$tt' ";
        if ( lc($tt) eq lc($locus_type) ) {
            print "selected ";
        }
        print ">$tt</option>\n";
    }
    print "     </select></td>\n";
    print "</tr>\n";

    # Locus Tag
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Locus Tag (*)</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='locus_tag' value='"
      . escapeHTML($locus_tag)
      . "' size=80' maxLength='255'/></td>\n";
    print "</tr>\n";

    # EC number
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>EC Number</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='ec_number' value='"
      . escapeHTML($ec_number)
      . "' size=80' maxLength='1000'/></td>\n";
    print "</tr>\n";

    # scaffold
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Scaffold</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='scaffold' class='img' size='1'>\n";

    my $accession;
    my $rclause   = WebUtil::urClause('scf.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');
    my $sql       = qq{
		select scf.scaffold_oid, scf.ext_accession 
		from scaffold scf
		where scf.taxon = $taxon_oid 
		    and scf.ext_accession is not null
		    $rclause
		    $imgClause
	};
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( my $cnt0 = 0 ; $cnt0 < 100000 ; $cnt0++ ) {
        my ( $scaffold_oid, $ext_accession ) = $cur->fetchrow();
        last if !$scaffold_oid;

        print "        <option value='$scaffold_oid' ";
        if ( $scaffold_oid == $scaffold ) {
            print "selected ";
            $accession = $ext_accession;
        }
        print ">$ext_accession</option>\n";
    }
    $cur->finish();
    print "     </select></td>\n";
    print "</tr>\n";

    # DNA coord
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>DNA Coordinates (*)</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='dna_coords' value='"
      . escapeHTML($dna_coords)
      . "' size='80' maxLength='800'/></td>\n";
    print "</tr>\n";

    my ( $start, $end, $partial_gene, $error_msg ) = WebUtil::parseDNACoords($dna_coords);

    # strand

    # there are two strand fields
    # I Ken named this one strand1 2009-04-24
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Strand</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='strand1' class='img' size='1'>\n";
    print "        <option value=' '> </option>\n";

    my %strand_convert;
    $strand_convert{'+'} = 1;
    $strand_convert{'-'} = 2;
    $strand_convert{'?'} = 3;

    for my $tt ( '+', '-', '?' ) {
        print "        <option value='" . $strand_convert{$tt} . "' ";
        if ( lc($tt) eq lc($strand) ) {
            print "selected ";
        }
        print ">$tt</option>\n";
    }
    print "     </select></td>\n";
    print "</tr>\n";

    # is pseudo gene?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Pseudo Gene?</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='is_pseudogene' class='img' size='2'>\n";
    if ( blankStr($ispseudo) || lc($ispseudo) ne 'yes' ) {
        $ispseudo = 'No';
    }
    for my $tt ( 'No', 'Yes' ) {
        print "        <option value='$tt' ";
        if ( lc($tt) eq lc($ispseudo) ) {
            print "selected ";
        }
        print ">$tt</option>\n";
    }
    print "     </select></td>\n";
    print "</tr>\n";

    # description
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Description</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='description' value='"
      . escapeHTML($description)
      . "' size='80' maxLength='1000'/></td>\n";
    print "</tr>\n";

    # Gene Symbol
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Gene Symbol</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='gene_symbol' value='"
      . escapeHTML($symbol)
      . "' size='80' maxLength='100'/></td>\n";
    print "</tr>\n";

    # hit gene oid
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Hit Gene ID</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='hitgene_oid' value='"
      . escapeHTML($hitgene_oid)
      . "' size='40' maxLength='40'/></td>\n";
    print "</tr>\n";

    # is public?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Public?</th>\n";
    print "  <td class='img'   align='left'>\n";
    print "     <select name='is_public' class='img' size='2'>\n";
    if ( blankStr($ispublic) || lc($ispublic) ne 'yes' ) {
        $ispublic = 'No';
    }
    for my $tt ( 'No', 'Yes' ) {
        print "        <option value='$tt' ";
        if ( lc($tt) eq lc($ispublic) ) {
            print "selected ";
        }
        print ">$tt</option>\n";
    }
    print "     </select></td>\n";

    # replacing gene
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Replacing Gene(s)</th>\n";
    print "  <td class='img'   align='left'>"
      . "<input type='text' name='replacing_gene' value='"
      . escapeHTML($replacing_gene)
      . "' size='80' maxLength='1000'/></td>\n";
    print "</tr>\n";

    print "</tr>\n";

    print "</table>\n";

    # script to show neighborhood
    print qq { 
        <script language="javascript" type="text/javascript"> 
	YAHOO.namespace("example.container");
	if (!YAHOO.example.container.wait) {
	    initializeWaitPanel();
	}
        function initPanel() { 
	    if (!YAHOO.example.container.panelA) {
		YAHOO.example.container.panelA = new YAHOO.widget.Panel
		    ("panelA", { 
		      visible:false, 
		      //draggable:true, 
		      fixedcenter:true,
		      dragOnly:true,
		      underlay:"none",
		      zindex:"10",
		      //context:['nbhood','bl','tr']
		      } ); 
		YAHOO.example.container.panelA.setHeader
                    ("My Missing Gene Neighborhood");
		YAHOO.example.container.panelA.render("container");
	    } 
        }
	YAHOO.util.Event.addListener(window, "load", initPanel);

	function handleSuccess(req) { 
            try { 
                response = req.responseXML.documentElement;
                var html = response.getElementsByTagName 
                    ('div')[0].firstChild.data; 
                YAHOO.example.container.panelA.setBody(html); 
                YAHOO.example.container.panelA.render("container"); 
                YAHOO.example.container.panelA.show();
            } catch(e) { 
                alert("exception: "+req.responseXML+" "+req.responseText); 
            } 
	    YAHOO.example.container.wait.hide();
	} 
 
        function neighborhood() { 
            var f = document.mainForm; 
            if (document.readyState != "complete") {
                alert("Please wait for the document to finish loading.");
                return;
            }
            var start = $start;
            var end = $end;
            var dna_coords = f.dna_coords.value; 
            var scaffold = f.scaffold.value; 
            var strand = f.strand1.value; 
            var gene_oid = $mygene_oid; 

            var url = "xml.cgi?section=GeneDetail&page=mygeneNeighborhood"; 
            url = url + "&gene_oid=$mygene_oid"; 
            url = url + "&dna_coords=" + dna_coords; 
            url = url + "&scaffold=" + scaffold; 
            url = url + "&strand=" + strand; 
 
            var callback = { 
              success: handleSuccess, 
              failure: function(req) { 
		  alert("failure : "+req); 
                  YAHOO.example.container.wait.hide();
              } 
            }; 
  
            if (url != null && url != "") { 
		YAHOO.example.container.wait.show();
                var request = YAHOO.util.Connect.asyncRequest 
                    ('GET', url, callback); 
            } 
        } 
	</script>
    };

    # buttons
    print qq{
        <div id='container' class='yui-skin-sam'>
        <input type="button" id="nbhood" onclick=neighborhood() 
	value="View Neighborhood" class="medbutton"/>
    };

    print nbsp(1);
    if ($mygene_oid) {
        my $name = "_section_${section}_dbUpdateMyGene_noHeader";
        print submit(
            -name  => $name,
            -value => "Update My Missing Gene Annotation",
            -class => "lgdefbutton"
        );

        print nbsp(1);
        my $name = "_section_${section}_refreshViewer";
        print submit(
            -name  => $name,
            -value => "Update Viewers",
            -class => "medbutton"
        );

        print "</div>";    # yui container
        print "</div>";    # end mygenetab1
        print "<div id='mygenetab2'><p>";
        Sequence::findSequence( $taxon_oid, $scaffold, $accession, $start, $end, $strand );
        print "</div>";    # end mygenetab2
        TabHTML::printTabDivEnd();
    } else {
        my $name = "_section_${section}_dbAddMyGene_noHeader";
        print submit(
            -name  => $name,
            -value => "Add My Missing Gene Annotation",
            -class => "lgdefbutton"
        );
        print "</div>";    # yui container
    }

    print end_form();
}

############################################################################
# addUpdateMyTaxonMissingGeneForm
############################################################################
sub addUpdateMyTaxonMissingGeneForm {
    my ($mygene_oid) = @_;

    my $selected_taxon = param('taxon_oid');
    if ( !$selected_taxon ) {
        $selected_taxon = param("genomeFilterSelections");
    }

    if ( !$mygene_oid && !$selected_taxon ) {
        WebUtil::webError("No genome has been selected.");
        return;
    }

    my $source_page = param('source_page');
    if ($source_page) {
        print WebUtil::hiddenVar( 'source_page', 'my_missing_gene' );
    }

    my $db_product_name   = "";
    my $db_ec_number      = "";
    my $db_locus_type     = "";
    my $db_locus_tag      = "";
    my $db_scaffold       = "";
    my $db_dna_coords     = "";
    my $db_strand         = "";
    my $db_is_pseudogene  = "";
    my $db_description    = "";
    my $db_gene_symbol    = "";
    my $db_hitgene_oid    = "";
    my $db_is_public      = "";
    my $db_replacing_gene = "";

    my $dbh = WebUtil::dbLogin();
    if ($mygene_oid) {
        my $sql = qq{
	    select g.product_name, g.ec_number, g.locus_type, g.locus_tag,
	           g.scaffold, g.dna_coords, g.strand,
	           g.is_pseudogene, g.description, g.gene_symbol,
  	           g.hitgene_oid, g.taxon, g.is_public, g.replacing_gene
	      from mygene g
	     where g.mygene_oid = $mygene_oid
        };

        my $cur = execSql( $dbh, $sql, $verbose );
        (
            $db_product_name, $db_ec_number,   $db_locus_type,    $db_locus_tag,   $db_scaffold,
            $db_dna_coords,   $db_strand,      $db_is_pseudogene, $db_description, $db_gene_symbol,
            $db_hitgene_oid,  $selected_taxon, $db_is_public,     $db_replacing_gene
          )
          = $cur->fetchrow();

        $cur->finish();
    }

    printTaxonMissingGeneForm(
        $mygene_oid,     $selected_taxon, $db_product_name, $db_ec_number, $db_locus_type,
        $db_locus_tag,   $db_scaffold,    $db_dna_coords,   $db_strand,    $db_is_pseudogene,
        $db_description, $db_gene_symbol, $db_hitgene_oid,  $db_is_public, $db_replacing_gene
    );
}

############################################################################
# dbAddUpdateMyGene
############################################################################
sub dbAddUpdateMyGene {
    my ($mygene_oid) = @_;

    my $to_update = 0;
    if ($mygene_oid) {
        $to_update = 1;
    }

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("Session expired.  Please log in again.");
        return;
    }

    # check taxon selection
    my $taxon_oid = param('taxon_oid');
    if ( !$taxon_oid ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("Please select a genome.");
        return;
    }

    # process user input
    for my $fld (
        'product_name', 'ec_number',     'locus_type',  'locus_tag',   'scaffold',    'dna_coords',
        'strand',       'is_pseudogene', 'description', 'gene_symbol', 'hitgene_oid', 'is_public',
        'replacing_gene'
      )
    {
        my $val = param($fld);

        # format space
        $val =~ s/^\s+//;
        $val =~ s/\s+$//;
        $val =~ s/\s+/ /g;

        if ( blankStr($val) ) {
            if (   $fld eq 'product_name'
                || $fld eq 'locus_type'
                || $fld eq 'locus_tag'
                || $fld eq 'start_coord'
                || $fld eq 'end_coord'
                || $fld eq 'dna_coords' )
            {
                my $fld_display = $fld;
                if ( $fld eq 'product_name' ) {
                    $fld_display = "Product Name";
                } elsif ( $fld eq 'locus_type' ) {
                    $fld_display = "Locus Type";
                } elsif ( $fld eq 'locus_tag' ) {
                    $fld_display = "Locus Tag";
                } elsif ( $fld eq 'dna_coords' ) {
                    $fld_display = "DNA Coordinates";
                }

                main::printAppHeader("MyIMG");
                WebUtil::webError( "ERROR: Please enter a value for " . $fld_display );
                return;
            } elsif ( $fld eq 'scaffold' ) {
                main::printAppHeader("MyIMG");
                WebUtil::webError( "ERROR: Please select a value for " . $fld );
                return;
            }
        } else {

            # check input values
            if ( $fld eq 'ec_number' ) {
                my $res = DataEntryUtil::checkECNumber($val);
                if ( !blankStr($res) ) {
                    main::printAppHeader("MyIMG");
                    WebUtil::webError( "ERROR: " . $res );
                    return;
                }
            } elsif ( $fld eq 'start_coord' || $fld eq 'end_coord' ) {
                if ( !isInt($val) ) {
                    main::printAppHeader("MyIMG");
                    WebUtil::webError("ERROR: $fld must be an integer.");
                    return;
                }
            } elsif ( $fld eq 'dna_coords' ) {

                #		my $s2 = checkDNACoords($val);
                my ( $s_coord, $e_coord, $partial_gene, $s2 ) = WebUtil::parseDNACoords($val);
                if ($s2) {
                    main::printAppHeader("MyIMG");
                    WebUtil::webError("ERROR: $s2.");
                    return;
                }
            } elsif ( $fld eq 'hitgene_oid' ) {
                if ( !isInt($val) ) {
                    main::printAppHeader("MyIMG");
                    WebUtil::webError("ERROR: Hit Gene ID must be an integer.");

                    return;
                }

                my $dbh  = WebUtil::dbLogin();
                my $cnt1 = DataEntryUtil::db_findCount( $dbh, 'gene', "gene_oid = $val" );

                #$dbh->disconnect();
                if ( !$cnt1 ) {
                    main::printAppHeader("MyIMG");
                    WebUtil::webError("ERROR: Hit Gene ID is incorrect (not such gene).");

                    return;
                }
            } elsif ( $fld eq 'replacing_gene' ) {
                my @old_genes = split( /\,/, $val );
                my $dbh       = WebUtil::dbLogin();

                for my $g2 (@old_genes) {
                    $g2 = strTrim($g2);
                    if ( !$g2 ) {
                        next;
                    }

                    if ( !isInt($g2) ) {

                        #$dbh->disconnect();
                        main::printAppHeader("MyIMG");
                        WebUtil::webError("ERROR: Replacing Gene ID must be an integer.");
                        return;
                    }

                    my $cnt1 = DataEntryUtil::db_findCount( $dbh, 'gene', "gene_oid = $g2" );

                    if ( !$cnt1 ) {

                        #$dbh->disconnect();
                        main::printAppHeader("MyIMG");
                        WebUtil::webError("ERROR: Gene ID $g2 is incorrect (not such gene).");

                        return;
                    }
                }    # end for g2

                #$dbh->disconnect();
            }
        }
    }

    # prepare database update statement
    my $dbh     = WebUtil::dbLogin();
    my @sqlList = ();
    my $sql;
    my $cur;

    # generate insert Gene_MyIMG_functions
    if ( !$mygene_oid ) {
        $mygene_oid = db_findMaxID( $dbh, 'mygene', 'mygene_oid' ) + 1;
    }
    my $ins_st = "insert into mygene (mygene_oid, taxon";
    my $val_st = " values ($mygene_oid, $taxon_oid";
    my $upd_st = "update mygene set taxon = $taxon_oid";

    # update the form name fields from strand to strand1
    # ken 2009-04-24
    for my $fld (
        'product_name', 'ec_number',     'locus_type',  'locus_tag',   'scaffold',    'dna_coords',
        'strand',       'is_pseudogene', 'description', 'gene_symbol', 'hitgene_oid', 'is_public',
        'replacing_gene'
      )
    {
        my $val = param($fld);

        # ken bug fix for strand1
        $val = param("strand1") if ( $fld eq "strand" );

        # format space
        $val =~ s/^\s+//;
        $val =~ s/\s+$//;
        $val =~ s/\s+/ /g;

        $val =~ s/'/''/g;    # replace ' with ''

        if ( $fld =~ /strand/ ) {
            if ( $val == 1 ) {
                $val = '+';
            } elsif ( $val == 2 ) {
                $val = '-';
            } elsif ( $val == 3 ) {
                $val = '?';
            }
        }

        $ins_st .= ", $fld";
        if ( blankStr($val) ) {
            $val_st .= ", null";
            $upd_st .= ", $fld = null";
        } elsif ( $fld eq 'scaffold'
            || $fld eq 'start_coord'
            || $fld eq 'end_coord'
            || $fld eq 'hitgene_oid' )
        {
            $val_st .= ", $val";
            $upd_st .= ", $fld = $val";
        } else {
            $val_st .= ", '$val'";
            $upd_st .= ", $fld = '$val'";
        }
    }

    if ($to_update) {
        $sql = $upd_st . ", mod_date = sysdate, modified_by = $contact_oid" . " where mygene_oid = $mygene_oid";
    } else {
        $sql = $ins_st . ", created_by, modified_by, add_date) " . $val_st . ", $contact_oid, $contact_oid, sysdate)";
    }
    push @sqlList, ($sql);

    #$dbh->disconnect();

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        main::printAppHeader("MyIMG");
        WebUtil::webError("SQL Error: $sql");
        return -1;
    }

}

############################################################################
# confirmDeleteMyTaxonMissingGeneForm
############################################################################
sub confirmDeleteMyTaxonMissingGeneForm {
    my ($mygene_oid) = @_;

    WebUtil::printMainForm();

    if ($mygene_oid) {
        print "<h1>Delete Missing Gene Annotation</h1>\n";
        print "<h2>Missing Gene OID: $mygene_oid</h2>\n";
        print WebUtil::hiddenVar( 'mygene_oid', $mygene_oid );
    } else {
        return;
    }

    my $created_by        = "";
    my $db_product_name   = "";
    my $db_ec_number      = "";
    my $db_locus_type     = "";
    my $db_locus_tag      = "";
    my $db_scaffold       = "";
    my $db_dna_coords     = "";
    my $db_strand         = "";
    my $db_is_pseudogene  = "";
    my $db_description    = "";
    my $db_gene_symbol    = "";
    my $db_add_date       = "";
    my $db_mod_date       = "";
    my $db_is_public      = "";
    my $db_replacing_gene = "";
    my $selected_taxon    = 0;
    my $taxon_name        = "";
    my $hitgene_oid       = "";

    my $dbh       = WebUtil::dbLogin();
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
	select g.created_by, g.product_name, g.ec_number, 
               g.locus_type, g.locus_tag,
	       s.ext_accession, g.dna_coords, g.strand,
	       g.is_pseudogene, g.description, g.gene_symbol,
	       to_char(g.add_date, 'yyyy-mm-dd'), 
	       to_char(g.mod_date, 'yyyy-mm-dd'), g.hitgene_oid,
	       g.taxon, t.taxon_display_name, g.is_public, g.replacing_gene
	from mygene g, taxon t, scaffold s
	where g.mygene_oid = ?
	and g.scaffold = s.scaffold_oid (+)
	$rclause
	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $mygene_oid );
    (
        $created_by,     $db_product_name, $db_ec_number, $db_locus_type,    $db_locus_tag,
        $db_scaffold,    $db_dna_coords,   $db_strand,    $db_is_pseudogene, $db_description,
        $db_gene_symbol, $db_add_date,     $db_mod_date,  $hitgene_oid,      $selected_taxon,
        $taxon_name,     $db_is_public,    $db_replacing_gene
      )
      = $cur->fetchrow();

    my $contact_oid = WebUtil::getContactOid();
    if ( $contact_oid != $created_by ) {
        WebUtil::webError("You cannot delete this missing gene annotation.");
        return;
    }

    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$selected_taxon";
    print "<p style='width: 650px;'>";
    print alink( $url, $taxon_name ) . "</p>\n";

    print "<table class='img' border='1'>\n";

    # Product Name
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Product Name</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_product_name) . "</td>\n";
    print "</tr>\n";

    # locus_type
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Locus Type</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_locus_type) . "</td>\n";
    print "</tr>\n";

    # locus_tag
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Locus Tag</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_locus_tag) . "</td>\n";
    print "</tr>\n";

    # EC number
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>EC Number</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_ec_number) . "</td>\n";
    print "</tr>\n";

    # scaffold
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Scaffold</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_scaffold) . "</td>\n";
    print "</tr>\n";

    # DNA coord
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>DNA Coordinates</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_dna_coords) . "</td>\n";
    print "</tr>\n";

    # strand
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Strand</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_strand) . "</td>\n";
    print "</tr>\n";

    # is pseudo gene?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Pseudo Gene?</th>\n";
    print "  <td class='img'   align='left'>\n";
    escapeHTML($db_is_pseudogene) . "</td>\n";
    print "</tr>\n";

    # description
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Description</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_description) . "</td>\n";
    print "</tr>\n";

    # Gene Symbol
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Gene Symbol</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_gene_symbol) . "</td>\n";
    print "</tr>\n";

    # hit genw ois
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Hit Gene</th>\n";
    my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$hitgene_oid";
    print "<td class='img'>" . alink( $url, $hitgene_oid ) . "</td>\n";
    print "</tr>\n";

    # is public?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Public?</th>\n";
    print "  <td class='img'   align='left'>\n";
    escapeHTML($db_is_public) . "</td>\n";
    print "</tr>\n";

    # description
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Replacing Gene(s)</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_replacing_gene) . "</td>\n";
    print "</tr>\n";

    # add date
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Add Date</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_add_date) . "</td>\n";
    print "</tr>\n";

    # Mod Date
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Mod Date</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_mod_date) . "</td>\n";
    print "</tr>\n";

    print "</table>\n";

    # buttons
    print "<p>\n";
    my $name = "_section_${section}_dbDeleteMyGene_noHeader";
    print submit(
        -name  => $name,
        -value => "Delete My Missing Gene Annotation",
        -class => "lgdefbutton"
    );
    print nbsp(1);
    my $name = "_section_${section}_viewMyMissingGenes";
    print submit(
        -name  => $name,
        -value => 'Cancel',
        -class => 'smbutton'
    );

    print end_form();
}

############################################################################
# dbDeleteMyGene
############################################################################
sub dbDeleteMyGene {
    my ($mygene_oid) = @_;

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("Session expired.  Please log in again.");
        return;
    }

    if ( !$mygene_oid ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("Please select a missing gene annotation.");
        return;
    }

    # prepare database update statements
    my @sqlList = ();
    my $sql     = "delete from mygene_img_groups\@img_ext where mygene_oid = $mygene_oid and contact_oid = $contact_oid";
    push @sqlList, ($sql);

    $sql = "delete from mygene where mygene_oid = $mygene_oid " . "and created_by = $contact_oid ";
    push @sqlList, ($sql);

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        main::printAppHeader("MyIMG");
        WebUtil::webError("SQL Error: $sql");
        return -1;
    }

}

############################################################################
# displayMissingGeneInfo
############################################################################
sub displayMissingGeneInfo {
    WebUtil::printMainForm();

    my $mygene_oid = param('mygene_oid');
    if ( !$mygene_oid ) {
        WebUtil::webError("Incorrect Missing Gene ID.");
        return;
    }

    print "<h2>Missing Gene ID: $mygene_oid</h2>\n";
    print WebUtil::hiddenVar( 'mygene_oid', $mygene_oid );

    my $db_product_name  = "";
    my $db_ec_number     = "";
    my $db_locus_type    = "";
    my $db_locus_tag     = "";
    my $db_scaffold      = "";
    my $db_dna_coords    = "";
    my $db_strand        = "";
    my $db_is_pseudogene = "";
    my $db_description   = "";
    my $db_gene_symbol   = "";
    my $db_add_date      = "";
    my $db_mod_date      = "";
    my $db_contact       = "";
    my $selected_taxon   = 0;
    my $taxon_name       = "";
    my $db_is_public     = "";

    my $sc_oid = 0;

    my $dbh       = WebUtil::dbLogin();
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
		select g.product_name, g.ec_number, g.locus_type, g.locus_tag,
		    s.scaffold_oid, s.ext_accession, g.dna_coords, 
		    g.strand, g.is_pseudogene, 
		    g.description, g.gene_symbol,
		    to_char(g.add_date, 'yyyy-mm-dd'), 
		    to_char(g.mod_date, 'yyyy-mm-dd'), c.username,
		    g.taxon, t.taxon_display_name, g.is_public
		from mygene g, taxon t, contact c, scaffold s
		where g.mygene_oid = ?
		    and g.taxon = t.taxon_oid
		    and g.created_by = c.contact_oid
		    and g.scaffold = s.scaffold_oid (+)
		    $rclause
		    $imgClause
	};
    my $cur = execSql( $dbh, $sql, $verbose, $mygene_oid );
    (
        $db_product_name, $db_ec_number, $db_locus_type,    $db_locus_tag,   $sc_oid,         $db_scaffold,
        $db_dna_coords,   $db_strand,    $db_is_pseudogene, $db_description, $db_gene_symbol, $db_add_date,
        $db_mod_date,     $db_contact,   $selected_taxon,   $taxon_name,     $db_is_public
      )
      = $cur->fetchrow();
    $cur->finish();

    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$selected_taxon";
    print "<p style='width: 650px;'>";
    print alink( $url, $taxon_name ) . "</p>\n";

    print "<table class='img' border='1'>\n";

    # Product Name
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Product Name</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_product_name) . "</td>\n";
    print "</tr>\n";

    # locus type
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Locus Type</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_locus_type) . "</td>\n";
    print "</tr>\n";

    # locus tag
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Locus Tag</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_locus_tag) . "</td>\n";
    print "</tr>\n";

    # EC number
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>EC Number</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_ec_number) . "</td>\n";
    print "</tr>\n";

    # scaffold
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Scaffold</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_scaffold) . "</td>\n";
    print "</tr>\n";

    # DNA coord
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>DNA Coordinates</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_dna_coords) . "</td>\n";
    print "</tr>\n";

    # strand
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Strand</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_strand) . "</td>\n";
    print "</tr>\n";

    # is pseudo gene?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Pseudo Gene?</th>\n";
    print "  <td class='img'   align='left'>\n";
    escapeHTML($db_is_pseudogene) . "</td>\n";
    print "</tr>\n";

    # description
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Description</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_description) . "</td>\n";
    print "</tr>\n";

    # Gene Symbol
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Gene Symbol</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_gene_symbol) . "</td>\n";
    print "</tr>\n";

    # is public?
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Is Public?</th>\n";
    print "  <td class='img'   align='left'>\n";
    escapeHTML($db_is_public) . "</td>\n";
    print "</tr>\n";

    # add date
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Add Date</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_add_date) . "</td>\n";
    print "</tr>\n";

    # Mod Date
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>Mod Date</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_mod_date) . "</td>\n";
    print "</tr>\n";

    # Mod Date
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>IMG Contact</th>\n";
    print "  <td class='img'   align='left'>" . escapeHTML($db_contact) . "</td>\n";
    print "</tr>\n";

    print "</table>\n";

    my $db_start_coord = 0;
    my $db_end_coord   = 0;
    if ($db_dna_coords) {
        my @coords = split( /\,/, $db_dna_coords );
        my $coord0 = $coords[0];
        my ( $s1, $e1 ) = split( /\.\./, $coord0 );
        if ( isInt($s1) ) {
            $db_start_coord = $s1;
        }
        $coord0 = $coords[-1];
        my ( $s1, $e1 ) = split( /\.\./, $coord0 );
        if ( isInt($e1) ) {
            $db_end_coord = $e1;
        }

        if ( $db_end_coord < $db_start_coord ) {
            my $tmp = $db_end_coord;
            $db_end_coord   = $db_start_coord;
            $db_start_coord = $tmp;
        }
    }

    # show sequence viewer
    if (   $sc_oid
        && $db_scaffold
        && $db_start_coord
        && $db_end_coord
        && $db_strand )
    {
        Sequence::findSequence( $selected_taxon, $sc_oid, $db_scaffold, $db_start_coord, $db_end_coord, $db_strand );
    } else {
        print "<h5>Not enough information to display sequence viewer</h5>\n";
    }

    print end_form();
}

sub checkDNACoords {
    my ($dna_coords) = @_;

    if ( !$dna_coords ) {
        return "No DNA coordinates";
    }

    my @coords = split( /\,/, $dna_coords );
    for my $coord0 (@coords) {
        my ( $s1, $e1 ) = split( /\.\./, $coord0 );
        if ( !$s1 || !isInt($s1) || $s1 < 0 ) {
            return "Incorrect coordinate range $coord0";
        }
        if ( !$e1 || !isInt($e1) || $e1 < 0 ) {
            return "Incorrect coordinate range $coord0";
        }

        if ( $e1 < $s1 ) {
            return "Incorrect coordinate range $coord0 ($e1 is smaller than $s1)";
        }
    }

    return "";
}

############################################################################
# listPotentialMissingGeneInfo
############################################################################
sub listPotentialMissingGenes {
    WebUtil::printMainForm();
    print "<h1>List of Potential Missing Genes</h1>\n";

    my @coords = param('coords');
    if ( scalar(@coords) == 0 ) {
        WebUtil::webError("No potential missing genes have been found.");
        return;
    }

    my $dbh = WebUtil::dbLogin();

    my %taxon_names;
    my $cnt = 0;
    for my $s1 (@coords) {
        if ( $cnt == 0 ) {
            print "<table class='img'>\n";
            print "<th class='img'>Select</th>\n";
            print "<th class='img'>Query Gene ID</th>\n";
            print "<th class='img'>Query Start Coord</th>\n";
            print "<th class='img'>Query End Coord</th>\n";
            print "<th class='img'>Subject Taxon ID</th>\n";
            print "<th class='img'>Subject Taxon Name</th>\n";
            print "<th class='img'>Subject Start Coord</th>\n";
            print "<th class='img'>Subject End Coord</th>\n";
            print "<th class='img'>Frame</th>\n";
            print "<th class='img'>Scaffold</th>\n";
            print "<th class='img'>Bit Score</th>\n";
            print "<th class='img'>E-value</th>\n";
            print "<th class='img'>Calc Start Coord</th>\n";
            print "<th class='img'>Calc End Coord</th>\n";
        }

        $cnt++;
        my ( $g_oid, $start1, $end1, $t_oid, $start2, $end2, $frame, $scaffold, $bit_score, $e_value, $start3, $end3 ) =
          split( /\,/, $s1 );

        print "<tr class='img'>\n";

        # select
        print "<td class='img'>\n";
        print "<input type='radio' ";
        print "name='coords' value='$s1' />\n";
        print "</td>\n";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$g_oid";
        print "<td class='img'>" . alink( $url, $g_oid ) . "</td>\n";

        print "<td class='img'>" . $start1 . "</td>\n";
        print "<td class='img'>" . $end1 . "</td>\n";

        $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$t_oid";
        print "<td class='img' >" . alink( $url, $t_oid ) . "</td>\n";

        my $taxon_name = $taxon_names{$t_oid};
        if ( blankStr($taxon_name) ) {
            $taxon_name = taxonOid2Name( $dbh, $t_oid, 0 );
            $taxon_names{$t_oid} = $taxon_name;
        }
        print "<td class='img'>" . escapeHTML($taxon_name) . "</td>\n";

        print "<td class='img'>" . $start2 . "</td>\n";
        print "<td class='img'>" . $end2 . "</td>\n";

        print "<td class='img'>" . $frame . "</td>\n";
        my ( $t_oid2, $scaffold_ext_acc ) = split( /\./, $scaffold );
        print "<td class='img'>" . $scaffold_ext_acc . "</td>\n";

        print "<td class='img'>" . $bit_score . "</td>\n";
        print "<td class='img'>" . $e_value . "</td>\n";

        print "<td class='img'>" . $start3 . "</td>\n";
        print "<td class='img'>" . $end3 . "</td>\n";

        print "</tr>\n";
    }

    if ( $cnt > 0 ) {
        print "</table>\n";
    }

    #$dbh->disconnect();

    # add my missing gene
    # buttons
    print "<p>\n";
    my $name = "_section_${section}_dbAddPotentialGene_noHeader";
    print submit(
        -name  => $name,
        -value => "Add My Missing Gene Annotation",
        -class => "lgdefbutton"
    );

    print end_form();
}

############################################################################
# dbAddPotentialGene
############################################################################
sub dbAddPotentialGene {

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return "Session expired.  Please log in again.";
    }

    # check missing gene selection
    my $coords = param('coords');
    if ( blankStr($coords) ) {
        return "Please select a gene to add.";
    }
    my ( $g_oid, $start1, $end1, $t_oid, $start2, $end2, $frame, $scaffold, $bit_score, $e_value, $start3, $end3 ) =
      split( /\,/, $coords );
    my ( $t_oid2, $scaffold_ext_acc ) = split( /\./, $scaffold );
    if ( blankStr($scaffold_ext_acc) ) {
        return "No scaffold information is provided.";
    }

    # prepare database update statements
    my $dbh     = WebUtil::dbLogin();
    my @sqlList = ();
    my $sql;
    my $cur;

    # get my gene oid
    my $mygene_oid = db_findMaxID( $dbh, 'mygene', 'mygene_oid' ) + 1;

    # get scaffold oid
    my $rclause   = WebUtil::urClause('scf.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');
    $sql = qq{
		select scf.scaffold_oid 
		from scaffold scf 
		where scf.ext_accession = ?
		    $rclause
		    $imgClause	
	};
    $cur = execSql( $dbh, $sql, $verbose, $scaffold_ext_acc );
    my ($scaffold_oid) = $cur->fetchrow();
    $cur->finish();

    if ( blankStr($scaffold_ext_acc) ) {
        return "Incorrect scaffold information.";
    }

    # get gene product name
    my $prod_name = "My Missing Gene $mygene_oid";
    if ($g_oid) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        $sql = qq{
	    select g.gene_display_name 
		from gene g 
		where g.gene_oid = ?
		$rclause
		$imgClause
	};
        $cur = execSql( $dbh, $sql, $verbose, $g_oid );
        my ($g_name) = $cur->fetchrow();
        $cur->finish();
        if ( !blankStr($g_name) ) {
            $prod_name = $g_name;
        }
    }

    # check
    if ( !$t_oid ) {
        return "No genome has been selected for missing gene.";
    }

    if ( $start3 =~ /(\d+)\*/ ) {
        $start3 = $1;
    }
    if ( $end3 =~ /(\d+)\*/ ) {
        $end3 = $1;
    }
    if (   blankStr($start3)
        || blankStr($end3)
        || !isInt($start3)
        || !isInt($end3) )
    {
        return "Incorrect start or end coordinate data.";
    }

    # generate insert Gene_MyIMG_functions
    my $g_start = $start3;
    my $g_end   = $end3;
    my $strand  = '+';
    if ( $start3 > $end3 ) {
        $g_start = $end3;
        $g_end   = $start3;
        $strand  = '-';
    }
    $prod_name =~ s/'/''/g;    # replace ' with ''
    my $sql =
        "insert into mygene (mygene_oid, taxon, product_name, "
      . "scaffold, dna_coords, strand, created_by, add_date, "
      . "hitgene_oid) "
      . "values ($mygene_oid, $t_oid, '"
      . $prod_name . "', "
      . "$scaffold_oid, '"
      . $g_start . ".."
      . $g_end . "', '"
      . $strand
      . "', $contact_oid, sysdate, $g_oid)";

    push @sqlList, ($sql);

    #$dbh->disconnect();

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        return "SQL Error: $sql";
    }

    return $mygene_oid;
}

############################################################################
# listScaffoldMissingGeneInfo
############################################################################
sub listScaffoldMissingGenes {
    WebUtil::printMainForm();
    print "<h1>List of Potential Missing Genes on Scaffold</h1>\n";

    my @coords = param('coords');
    if ( scalar(@coords) == 0 ) {
        WebUtil::webError("No potential missing genes have been found.");
        return;
    }

    my $dbh = WebUtil::dbLogin();

    my %taxon_names;
    my $cnt              = 0;
    my $target_taxon_oid = 0;
    my $scaffold_ext_acc = "";

    for my $s1 (@coords) {
        my ( $scaffold, $start1, $end1, $t_oid, $start2, $end2, $frame, $g_oid, $bit_score, $e_value, $start3, $end3 ) =
          split( /\,/, $s1 );
        next if ( !$scaffold );

        if ( $cnt == 0 ) {
            my $rclause   = WebUtil::urClause('scf.taxon');
            my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');
            my $sql       = qq{
		select scf.taxon, scf.ext_accession 
		    from scaffold scf
		    where scf.scaffold_oid = $scaffold
		    $rclause
		    $imgClause
	    };
            my $cur = execSql( $dbh, $sql, $verbose );
            ( $target_taxon_oid, $scaffold_ext_acc ) = $cur->fetchrow();
            $cur->finish();
            my $target_taxon_name = taxonOid2Name( $dbh, $target_taxon_oid, 0 );

            print "<h2>Genome ($target_taxon_oid): " . escapeHTML($target_taxon_name) . "</h2>\n";

            print WebUtil::hiddenVar( 'target_taxon_oid', $target_taxon_oid );

            print "<table class='img'>\n";
            print "<th class='img'>Select</th>\n";
            print "<th class='img'>Scaffold</th>\n";
            print "<th class='img'>Query Start Coord</th>\n";
            print "<th class='img'>Query End Coord</th>\n";
            print "<th class='img'>Subject Taxon ID</th>\n";
            print "<th class='img'>Subject Taxon Name</th>\n";
            print "<th class='img'>Subject Start Coord</th>\n";
            print "<th class='img'>Subject End Coord</th>\n";
            print "<th class='img'>Frame</th>\n";
            print "<th class='img'>Gene</th>\n";
            print "<th class='img'>Bit Score</th>\n";
            print "<th class='img'>E-value</th>\n";
            print "<th class='img'>Calc Start Coord</th>\n";
            print "<th class='img'>Calc End Coord</th>\n";
        }

        $cnt++;

        print "<tr class='img'>\n";

        # select
        my $url;
        print "<td class='img'>\n";
        print "<input type='radio' ";
        print "name='coords' value='$s1' />\n";
        print "</td>\n";

        print "<td class='img'>" . $scaffold_ext_acc . "</td>\n";

        print "<td class='img'>" . $start1 . "</td>\n";
        print "<td class='img'>" . $end1 . "</td>\n";

        $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$t_oid";
        print "<td class='img' >" . alink( $url, $t_oid ) . "</td>\n";

        my $taxon_name = $taxon_names{$t_oid};
        if ( blankStr($taxon_name) ) {
            $taxon_name = taxonOid2Name( $dbh, $t_oid, 0 );
            $taxon_names{$t_oid} = $taxon_name;
        }
        print "<td class='img'>" . escapeHTML($taxon_name) . "</td>\n";

        print "<td class='img'>" . $start2 . "</td>\n";
        print "<td class='img'>" . $end2 . "</td>\n";

        print "<td class='img'>" . $frame . "</td>\n";

        $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$g_oid";
        print "<td class='img'>" . alink( $url, $g_oid ) . "</td>\n";

        print "<td class='img'>" . $bit_score . "</td>\n";
        print "<td class='img'>" . $e_value . "</td>\n";

        print "<td class='img'>" . $start3 . "</td>\n";
        print "<td class='img'>" . $end3 . "</td>\n";

        print "</tr>\n";
    }

    if ( $cnt > 0 ) {
        print "</table>\n";
    }

    #$dbh->disconnect();

    # add my missing gene
    # buttons
    print "<p>\n";
    my $name = "_section_${section}_dbAddScaffoldGene_noHeader";
    print submit(
        -name  => $name,
        -value => "Add My Missing Gene Annotation",
        -class => "lgdefbutton"
    );

    print end_form();
}

############################################################################
# dbAddScaffoldGene
############################################################################
sub dbAddScaffoldGene {

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return "Session expired.  Please log in again.";
    }

    # check missing gene selection
    my $coords = param('coords');
    if ( blankStr($coords) ) {
        return "Please select a gene to add.";
    }

    my ( $scaffold, $start1, $end1, $t_oid, $start2, $end2, $frame, $g_oid, $bit_score, $e_value, $start3, $end3 ) =
      split( /\,/, $coords );

    my $dbh = WebUtil::dbLogin();

    my $mygene_oid = DataEntryUtil::db_findMaxID( $dbh, 'mygene', 'mygene_oid' ) + 1;

    my $rclause   = WebUtil::urClause('scf.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');
    my $sql       = qq{
        select scf.ext_accession 
	from scaffold scf 
	where scf.scaffold_oid = ?
	$rclause
	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold );
    my ($scaffold_ext_acc) = $cur->fetchrow();
    $cur->finish();

    if ( blankStr($scaffold_ext_acc) ) {

        #$dbh->disconnect();
        return "No scaffold information is provided.";
    }

    # get gene product name
    my $prod_name = "My Missing Gene $mygene_oid";
    if ($g_oid) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        $sql = qq{
	    select g.gene_display_name 
	    from gene g
	    where g.gene_oid = ?
	    $rclause
	    $imgClause
	};
        $cur = execSql( $dbh, $sql, $verbose, $g_oid );
        my ($g_name) = $cur->fetchrow();
        $cur->finish();
        if ( !blankStr($g_name) ) {
            $prod_name = $g_name;
        }
    }

    #$dbh->disconnect();

    # check
    my $target_taxon_oid = param('target_taxon_oid');
    if ( !$target_taxon_oid ) {
        return "No genome has been selected for missing gene.";
    }

    if ( $start3 =~ /(\d+)\*/ ) {
        $start3 = $1;
    }
    if ( $end3 =~ /(\d+)\*/ ) {
        $end3 = $1;
    }
    if (   blankStr($start3)
        || blankStr($end3)
        || !isInt($start3)
        || !isInt($end3) )
    {
        return "Incorrect start or end coordinate data.";
    }

    # generate insert Gene_MyIMG_functions
    my $g_start = $start3;
    my $g_end   = $end3;
    my $strand  = '+';
    if ( $start3 > $end3 ) {
        $g_start = $end3;
        $g_end   = $start3;
        $strand  = '-';
    }
    $prod_name =~ s/'/''/g;    # replace ' with ''

    my @sqlList    = ();
    my $dna_coords = $g_start . ".." . $g_end;
    my $sql        = qq{
	insert into mygene (mygene_oid, taxon, product_name, 
			    scaffold, dna_coords, strand, 
			    created_by, add_date, hitgene_oid
	    ) values (
	    $mygene_oid, $target_taxon_oid, '$prod_name',
	    $scaffold, '$dna_coords', '$strand', 
	    $contact_oid, sysdate, $g_oid
	    )
    };
    push @sqlList, ($sql);

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        return "SQL Error: $sql";
    }

    return $mygene_oid;
}

############################################################################
# printMyJobForm
############################################################################
sub printMyJobForm {
    my $contact_oid = WebUtil::getContactOid();
    print "<h1>IMG User Computation Jobs</h1>\n";

    if ( DataEntryUtil::db_isPublicUser($contact_oid) ) {

        # public user
        print qq{
            <h4>Public User cannot request recomputations.</h4>
	    <p>
                (If you want to become a registered user, 
	        <A href="main.cgi?page=requestAcct">
	        request an account here</A>.)
            </p>
        };
    } else {

        # registered user
        my $workspace_dir = $env->{workspace_dir};
        print qq{
	    <h3>Computation Jobs Using Message System</h3>
	    <p>
                You can view and track all your computation jobs using Message System.<br/>
	        (Click on the count to view the full list of jobs.)
	    </p>
	};

        my $sid = $contact_oid;
        my $cnt = 0;
        if ( -e "$workspace_dir/$sid/job" ) {
            opendir( DIR, "$workspace_dir/$sid/job" )
              or return;
            my @files = readdir(DIR);

            print "<table class='img'>\n";
            print "<tr class='img'>\n";
            print "<td class='img'>Computation Jobs</td>\n";

            foreach my $x ( sort @files ) {

                # remove files "."  ".." "~$"
                next if ( $x eq "." || $x eq ".." || $x =~ /~$/ );
                $cnt++;
            }
            closedir(DIR);

            print "<td class='img'>";
            if ( $cnt == 0 ) {
                print $cnt;
            } else {
                my $url = "$main_cgi?section=WorkspaceJob&page=workspaceJobMain";
                print alink( $url, $cnt );
            }
            print "</td>\n";
            print "</tr>\n";
            print "</table>\n";
        }

        if ( $cnt == 0 ) {
            print "<h5>You do not have any computation jobs using Message System.</h5>\n";
        }

        print qq{
	    <hr>
	    <h3>Requested Recomputation Jobs</h3>
	    <p>
	    You can view and track all your requested recomputation jobs.<br/>
	    (Click on Job ID link after job is finished to 
	     view results of computation.)
	    </p>\n
	};
        printViewMyJobForm();
    }
}

############################################################################
# printViewMyJobForm - view all my requested jobs
############################################################################
sub printViewMyJobForm {
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }
    my $super_user_flag = WebUtil::getSuperUser();
    my $cond;
    if ( $super_user_flag ne 'Yes' ) {
        $cond =
            " and j.contact = $contact_oid "
          . " or j.contact in "
          . "(select u.users from myimg_job_users u "
          . "where u.img_job_id = j.img_job_id)";
    }

    # connect to database
    my $dbh = WebUtil::dbLogin();
    WebUtil::printStatusLine( "Loading ...", 1 );
    my $sql = qq{
            select j.img_job_id, c.username, j.job_type, 
                jtcv.description,  j.database, j.status,
                to_char( j.add_date, 'yyyy-mm-dd HH24:MI:SS' ),
                j.user_notes
            from myimg_job j, contact c, img_job_typecv jtcv
            where j.contact = c.contact_oid
            and j.database = '$ora_db_user'
            and j.job_type = jtcv.cv_term
            $cond
            order by 1
	};
    my $cur = execSql( $dbh, $sql, $verbose );

    my $it = new InnerTable( 1, "myJob$$", "myjobtable", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Job ID",     "char desc", "left" );
    $it->addColSpec( "Submitter",  "char asc",  "left" );
    $it->addColSpec( "Job Type",   "char asc",  "left" );
    $it->addColSpec( "Job Status", "char asc",  "left" );
    $it->addColSpec( "Add Date",   "char asc",  "left" );
    $it->addColSpec( "User Notes", "char asc",  "left" );

    my $count = 0;
    for ( ; ; ) {
        my ( $my_job_id, $username, $job_type, $jt_description, $database, $status, $add_date, $notes ) = $cur->fetchrow();
        last if !$my_job_id;
        $count++;

        my $my_job_link = getJobLink( $dbh, $job_type, $my_job_id, $status );
        my $r .= $sd . "<input type='radio' name='my_job_id' value='$my_job_id' />\t";
        $r    .= $my_job_id . $sd . "$my_job_link\t";
        $r    .= $username . "\t";
        $r    .= $job_type . "\t";
        $r    .= $status . "\t";
        $r    .= $add_date . "\t";
        $r    .= $notes . "\t";
        $it->addRow($r);
    }
    $cur->finish();

    #$dbh->disconnect();

    WebUtil::printStatusLine( "loaded", 2 );

    if ( $count == 0 ) {
        print "<h5>You do not have any requested recomputation jobs.</h5>\n";
    } else {
        WebUtil::printMainForm();

        $it->printOuterTable(1);

        my $name = "_section_${section}_viewJobDetail";
        print submit(
            -name  => $name,
            -value => "View Job Submission Detail",
            -class => "meddefbutton"
        );

        print nbsp(1);
        $name = "_section_${section}_cancelImgJob";
        print submit(
            -name  => $name,
            -value => 'Cancel Request',
            -class => 'medbutton'
        );

        print end_form();
    }
}

############################################################################
# getJobLink - Get link to method/tool page when job is finished.
############################################################################
sub getJobLink {
    my ( $dbh, $job_type, $img_job_id, $status ) = @_;

    if ( $status ne "finished" ) {
        my $url = "$section_cgi&viewJobDetail&my_job_id=$img_job_id";
        return alink( $url, $img_job_id );
    } elsif ( $job_type eq "phyloDist" ) {
        my $sql = qq{
            select p.param_value
            from myimg_job_parameters p
	    where p.param_type = 'taxon_oid'
            and p.img_job_id = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $img_job_id );
        my ($taxon_oid) = $cur->fetchrow();
        $cur->finish();
        return "" if $taxon_oid eq "";

        my $url = "$main_cgi?section=MetagenomeHits" . "&page=metagenomeStats&taxon_oid=$taxon_oid";
        return alink( $url, $img_job_id );
    } elsif ( $job_type eq "phyloProf" ) {
        my $url = "$main_cgi?section=PhylogenProfiler" . "&page=phyloProfileFormJob&my_job_id=$img_job_id";
        return alink( $url, $img_job_id );
    }
}

############################################################################
# computePhyloDistOnDemand
############################################################################
sub computePhyloDistOnDemand {
    my $contact_oid = WebUtil::getContactOid();
    my $msg;

    if ( DataEntryUtil::db_isPublicUser($contact_oid) ) {
        $msg = "Public User cannot request recomputations.";
        return $msg;
    }

    # taxon_oid
    my $taxon_oid = param('taxon_oid');
    if ( !$taxon_oid ) {
        $msg = "No Taxon ID has been selected.";
        return $msg;
    }

    # user_notes
    my $user_notes = param('user_notes');
    $user_notes =~ s/'/''/g;    # replace ' with ''
    if ( length($user_notes) > 1000 ) {
        $user_notes = substr( $user_notes, 0, 1000 );
    }

    # connect to database
    my $dbh    = WebUtil::dbLogin();
    my $job_id = DataEntryUtil::db_findMaxID( $dbh, 'myimg_job', 'img_job_id' ) + 1;

    #$dbh->disconnect();

    ### start preparing sqlList
    my @sqlList = ();

    # add a new job
    my $sql = qq{
            insert into myimg_job(
                img_job_id, contact, add_date,
                status, is_public, job_type, 
                database, user_notes
            ) values (
                $job_id, $contact_oid, sysdate, 
                'submitted', 'Yes', 'phyloDist', 
                '$ora_db_user', '$user_notes'
            )
        };
    push @sqlList, ($sql);

    $sql = qq{
            insert into myimg_job_parameters(
                img_job_id, param_type, param_value
            ) values (
                $job_id, 'taxon_oid', '$taxon_oid'
            )
        };
    push @sqlList, ($sql);

    my @private_taxon_oids = param('private_taxon_oid');
    for my $p2 (@private_taxon_oids) {
        $sql = qq{
                    insert into myimg_job_parameters(
                        img_job_id, param_type, param_value
                    ) values (
                        $job_id, 'private_taxon_oid', '$p2'
                    )
                };
        push @sqlList, ($sql);
    }

    # finish preparing sqlList

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        return "SQL Error: $sql";
    }

    return $msg;
}

############################################################################
# computePhyloProfOnDemand
############################################################################
sub computePhyloProfOnDemand {
    my $contact_oid = WebUtil::getContactOid();
    my $msg;

    if ( DataEntryUtil::db_isPublicUser($contact_oid) ) {
        $msg = "Public User cannot request recomputations.";
        return $msg;
    }

    my @all_taxon_bin_oids0 = ();
    my @bindList            = ();
    my $dbh                 = WebUtil::dbLogin();

    my $taxonClause = WebUtil::txsClause( "tx", $dbh );
    my $rclause     = WebUtil::urClause('tx');
    my $imgClause   = WebUtil::imgClause('tx');
    my $sql         = qq{ 
	select distinct tx.taxon_oid 
	from taxon tx 
	where 1 = 1 
	$taxonClause 
	$rclause
	$imgClause
	order by tx.taxon_oid 
    };

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        my $taxon_bin_oid = "$taxon_oid.0";
        push( @all_taxon_bin_oids0, $taxon_bin_oid );
    }
    $cur->finish();

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    $sql = qq{
	select distinct tx.taxon_oid, b.bin_oid 
	    from taxon tx, env_sample_gold es, bin b 
	    where tx.env_sample = es.sample_oid
	    and es.sample_oid = b.env_sample 
	    and b.bin_oid > 0 
	    and b.is_default = ? 
	    $rclause
	    $imgClause
	    order by tx.taxon_oid, b.bin_oid
    };

    $cur = execSql( $dbh, $sql, $verbose, 'Yes' );
    for ( ; ; ) {
        my ( $taxon_oid, $bin_oid ) = $cur->fetchrow();
        last if !$taxon_oid;
        my $taxon_bin_oid = "$taxon_oid.$bin_oid";
        push( @all_taxon_bin_oids0, $taxon_bin_oid );
    }
    $cur->finish();

    #$dbh->disconnect();

    my $toi;
    my @all_taxon_bin_oids;
    my @posProfileTaxonBinOids;
    my @negProfileTaxonBinOids;
    for my $taxon_bin_oid (@all_taxon_bin_oids0) {
        my $profileVal = param("profile$taxon_bin_oid");
        next if $profileVal eq "0" || $profileVal eq "";
        WebUtil::webLog "profileVal='$profileVal' taxon_bin_oid='$taxon_bin_oid'\n"
          if $verbose >= 1;
        push( @all_taxon_bin_oids,     $taxon_bin_oid );
        push( @posProfileTaxonBinOids, $taxon_bin_oid ) if $profileVal eq "P";
        push( @negProfileTaxonBinOids, $taxon_bin_oid ) if $profileVal eq "N";
        if ( $toi eq "" && $profileVal eq "toi" ) {
            $toi = $taxon_bin_oid;
        } elsif ( $toi ne "" && $profileVal eq "toi" ) {
            $msg = "Please select only one genome " . "in the \"Find Genes In\" column.";
        }
    }
    if ( $toi eq "" ) {
        $msg = "Please select exactly one genome " . "in the \"Find Genes In\" column.";
    }

    return $msg if ($msg);

    my $evalue     = param("evalue");
    my $percIdent  = param("percIdent");
    my $user_notes = param('user_notes');
    $user_notes =~ s/'/''/g;    # replace ' with ''
    if ( length($user_notes) > 1000 ) {
        $user_notes = substr( $user_notes, 0, 1000 );
    }

    my $dbh    = WebUtil::dbLogin();
    my $job_id = DataEntryUtil::db_findMaxID( $dbh, 'myimg_job', 'img_job_id' ) + 1;

    #$dbh->disconnect();

    ### start preparing sqlList
    my @sqlList = ();

    # add a new job
    my $sql = qq{
	insert into myimg_job(
	    img_job_id, contact, 
	    add_date, status, is_public, job_type, 
	    database, user_notes
            ) values (
	    $job_id,  $contact_oid, 
	    sysdate, 'submitted', 'Yes', 'phyloProf', 
	    '$ora_db_user', '$user_notes'
            )
    };
    push @sqlList, ($sql);

    # taxon of interest
    if ( $toi ne "" ) {
        $sql = qq{
	    insert into myimg_job_parameters(
		img_job_id, param_type, param_value
		) values (
		$job_id, 'toi', '$toi'
		)
	};
        push @sqlList, ($sql);
    }

    # insert parameters
    for my $t1 (@all_taxon_bin_oids) {
        $sql = qq{
	    insert into myimg_job_parameters(
		img_job_id, param_type, param_value
		) values (
		$job_id, 'all_taxon_bin_oids', '$t1'
		)
	};
        push @sqlList, ($sql);
    }
    for my $t2 (@posProfileTaxonBinOids) {
        $sql = qq{
	    insert into myimg_job_parameters(
		img_job_id, param_type, param_value
		) values (
		$job_id, 'posProfileTaxonBinOids', '$t2'
		)
	};
        push @sqlList, ($sql);
    }
    for my $t3 (@negProfileTaxonBinOids) {
        $sql = qq{
	    insert into myimg_job_parameters(
		img_job_id, param_type, param_value
		) values (
		$job_id, 'negProfileTaxonBinOids', '$t3'
		)
	};
        push @sqlList, ($sql);
    }

    # evalue
    $sql = qq{
	insert into myimg_job_parameters(
	    img_job_id, param_type, param_value
            ) values (
	    $job_id, 'evalue', '$evalue'
            )
    };
    push @sqlList, ($sql);

    # precIdent
    $sql = qq{
	insert into myimg_job_parameters(
	    img_job_id, param_type, param_value
            ) values (
	    $job_id, 'percIdent', '$percIdent'
            )
    };
    push @sqlList, ($sql);
    ### finish preparing sqlList

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        return "SQL Error: $sql";
    }

    return $msg;
}

############################################################################
# printViewJobDetail
############################################################################
sub printViewJobDetail {
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }
    my $super_user_flag = WebUtil::getSuperUser();

    my $my_job_id          = param('my_job_id');
    my $my_job_id_original = $my_job_id;
    my $sql                = qq{
        select j.img_job_id, j.contact, c.username, c.email,
               j.job_type, jtcv.description, j.database, j.status,
               j.log_file, j.data_path,
               to_char( j.add_date, 'yyyy-mm-dd HH24:MI:SS' ),
               j.user_notes, j.mod_date, j.modified_by, j.admin_notes
        from myimg_job j, contact c, img_job_typecv jtcv
        where j.img_job_id = ?
        and j.contact = c.contact_oid
        and j.database = '$ora_db_user'
        and j.job_type = jtcv.cv_term
    };

    if ( $super_user_flag ne 'Yes' ) {
        $sql .= qq{
            and j.contact = $contact_oid or j.contact in
            (select u.users from myimg_job_users u 
            where u.img_job_id = j.img_job_id)
        };
    }
    $sql .= " order by 1";

    my $dbh = WebUtil::dbLogin();
    WebUtil::printStatusLine( "Loading ...", 1 );
    my $cur = execSql( $dbh, $sql, $verbose, $my_job_id );

    my (
        $my_job_id,      $contact,  $username, $email,       $job_type,
        $jt_description, $database, $status,   $log_file,    $data_path,
        $add_date,       $notes,    $mod_date, $modified_by, $admin_notes
      )
      = $cur->fetchrow();
    $cur->finish();
    if ( !$my_job_id ) {
        print "<p>Error: No detail information can be found for job $my_job_id_original</p>\n";

        #$dbh->disconnect();
        return;
    }

    WebUtil::printMainForm();
    print "<h2>Job Detail (ID: $my_job_id)</h2>\n";
    print "<table class='img' border='1'>\n";
    WebUtil::printAttrRow( "Job ID",               $my_job_id );
    WebUtil::printAttrRow( "Submitter",            "$username ($email)" );
    WebUtil::printAttrRow( "Job Type",             $job_type );
    WebUtil::printAttrRow( "Job Type Description", $jt_description );
    WebUtil::printAttrRow( "Database",             $database );
    WebUtil::printAttrRow( "Status",               $status );
    WebUtil::printAttrRow( "Log File",             $log_file ) if ($log_file);
    WebUtil::printAttrRow( "Data Directory",       $data_path ) if ($data_path);
    WebUtil::printAttrRow( "Add Date",             $add_date );
    WebUtil::printAttrRow( "User Notes",           $notes );
    WebUtil::printAttrRow( "Last Mod Date",        $mod_date ) if ($mod_date);
    if ($modified_by) {
        my $name2 = DataEntryUtil::DataEntryUtil::db_findVal( $dbh, 'contact', 'contact_oid', $modified_by, 'username', '' );
        WebUtil::printAttrRow( "Modified By", $name2 );
    }
    WebUtil::printAttrRow( "Admin Notes", $admin_notes ) if ( $admin_notes ne "" );
    WebUtil::printAttrRowRaw( "", "" );

    # parameters
    $sql = qq{
	select img_job_id, param_type, param_value 
        from myimg_job_parameters 
        where img_job_id = ? 
	order by 1, 2, 3
    };
    my $cur = execSql( $dbh, $sql, $verbose, $my_job_id );

    for ( ; ; ) {
        my ( $id2, $param_type, $param_value ) = $cur->fetchrow();
        last if !$id2;
        $param_type  =~ s/'/''/g;    # replace ' with ''
        $param_value =~ s/'/''/g;    # replace ' with ''
        WebUtil::printAttrRow( "Parameter: " . $param_type, $param_value );
    }
    $cur->finish();

    #$dbh->disconnect();
    print "</table>\n";

    if ( $contact eq $contact_oid && $contact ne "" ) {
        print WebUtil::hiddenVar( "img_job_id", $my_job_id );
        print "<h3>Change User Notes</h3>\n";
        print "<input type='text' name='user_notes' " . "size='60' maxLength='800' />\n";
        print nbsp(5);
        my $name = "_section_MyIMG_changeUserNotes";
        print submit(
            -name  => $name,
            -value => "Save Changes",
            -class => "smdefbutton"
        );
    }
    print end_form();
}

############################################################################
# changeUserNotes
############################################################################
sub changeUserNotes {
    my $img_job_id = param("img_job_id");
    my $user_notes = param("user_notes");

    my $dbh = WebUtil::dbLogin();
    my $sql = qq{
        update myimg_job
        set user_notes = ?
        where img_job_id = ?
    };
    WebUtil::execSqlOnly( $dbh, $sql, $verbose, $user_notes, $img_job_id );

    #$dbh->disconnect();

    WebUtil::printMessage("User notes for job ID $img_job_id updated.");

    my $url = "$section_cgi&page=myJobForm";
    print "<br/>\n";
    print WebUtil::buttonUrl( $url, "Go back to MyJobs List", "meddefbutton" );
}

############################################################################
# cancelImgJob
############################################################################
sub cancelImgJob {
    my $contact_oid = WebUtil::getContactOid();
    if ( blankStr($contact_oid) ) {
        WebUtil::webError("Your login has expired.");
    }
    my $super_user_flag = WebUtil::getSuperUser();

    my $my_job_id = param('my_job_id');
    if ( !$my_job_id ) {
        return "No job has been selected.";
    }

    my $dbh = WebUtil::dbLogin();
    my $sql = qq{
        select j.img_job_id, j.contact, j.status 
        from myimg_job j 
        where j.img_job_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $my_job_id );
    my ( $job_id, $submitter, $status ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    if ( !$job_id ) {
        return "No request has been selected";
    }
    if ( $super_user_flag ne 'Yes' && $contact_oid != $submitter ) {
        return "You cannot cancel this request.";
    }
    if (   $status eq 'finished'
        || $status eq 'error'
        || $status eq 'in progress'
        || $status eq 'cancelled' )
    {
        return "You cannot cancel a request with status '$status'.";
    }

    my $dbh     = WebUtil::dbLogin();
    my @sqlList = ();
    my $sql     = qq{
	update myimg_job 
        set status = 'cancelled', 
	modified_by = $contact_oid, 
	mod_date = sysdate 
        where img_job_id = $my_job_id
    };

    push @sqlList, ($sql);

    #$dbh->disconnect();

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        return "SQL Error: $sql";
    }

    return;
}

############################################################################
# printMyIMGGenesTermForm
############################################################################
sub printMyIMGGenesTermForm {
    WebUtil::printMainForm();

    print "<h1>Add/Update IMG Terms to MyIMG Gene Annotations</h1>\n";

    my @gene_oids = param('gene_oid');
    if ( scalar(@gene_oids) == 0 ) {
        WebUtil::webError("No Gene ID has been selected.");
        return;
    }

    for my $gene_oid (@gene_oids) {
        print WebUtil::hiddenVar( 'gene_oid', $gene_oid );
    }
    my $source_page = param('source_page');
    print WebUtil::hiddenVar( 'source_page', $source_page );

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return;
    }

    my $dbh = WebUtil::dbLogin();
    my %term_name_h;
    my $sql = "select term_oid, term from img_term";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $term_oid, $term ) = $cur->fetchrow();
        last if !$term_oid;
        $term_name_h{$term_oid} = $term;
    }
    $cur->finish();

    ## get my gene img terms
    #    my $dbh2 = Connect_IMG_EXT();
    #    $dbh2->disconnect();

    ## show all IMG terms for selection
    my %genes_h;
    my %term_h;
    my %selected_h;
    $sql = "select gene_oid, product_name from gene_myimg_functions where gene_oid = ? " . "and modified_by = ?";
    my $sql2 = qq{
        select g1.gene_oid, g1.function
        from gene_img_functions g1
        where g1.gene_oid = ?
        union
        select g2.gene_oid, g2.term_oid
        from gene_myimg_terms g2
        where g2.gene_oid = ?
        and g2.modified_by = ?
    };

    for my $gene_oid (@gene_oids) {
        $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $contact_oid );
        my ( $gene_oid2, $gene_name ) = $cur->fetchrow();
        if ($gene_oid2) {
            if ( !$gene_name ) {
                $gene_name = WebUtil::geneOid2Name( $dbh, $gene_oid2 );
            }

            $genes_h{$gene_oid2} = $gene_name;
        }
        $cur->finish();

        my $cur2 = execSql( $dbh, $sql2, $verbose, $gene_oid, $gene_oid, $contact_oid );
        for ( ; ; ) {
            my ( $gid2, $term_oid ) = $cur2->fetchrow();
            last if !$gid2;

            if ( $term_h{$gid2} ) {
                $term_h{$gid2} .= "," . $term_oid;
            } else {
                $term_h{$gid2} = $term_oid;
            }

            $selected_h{$term_oid} = 1;
        }
        $cur2->finish();
    }

    if ( scalar( keys %genes_h ) == 0 ) {
        webError("Cannot find the gene(s).");
        return;
    } else {
        print "<h2>Add/Update Terms to MyIMG Annotation</h2>\n";
    }

    for my $gene_oid (@gene_oids) {
        print "<h5>Gene $gene_oid: " . $genes_h{$gene_oid} . "</h5>\n";
        print "<ul>\n";
        my @terms = split( /\,/, $term_h{$gene_oid} );
        if ( scalar(@terms) == 0 ) {
            print "<li>No terms.</li>\n";
        } else {
            for my $tid (@terms) {
                print "<li>Term $tid: " . $term_name_h{$tid} . "</li>\n";
            }
        }
        print "</ul>\n";
    }

    my $it = new InnerTable( 1, "myGeneTerm$$", "myGeneTerm", 2 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Function ID", "char desc", "left" );
    $it->addColSpec( "Name",        "char asc",  "left" );

    for my $term_oid ( keys %term_name_h ) {
        my $term = $term_name_h{$term_oid};

        my $func_id = "ITERM:" . $term_oid;
        my $checked = "";
        if ( $selected_h{$term_oid} ) {
            $checked = "checked";
        }
        my $r   = $sd . "<input type='checkbox' name='func_id' value='$func_id' $checked /> \t";
        my $url = "$main_cgi?section=ImgTermBrowser" . "&page=imgTermDetail&term_oid=$term_oid";
        $r .= $func_id . $sd . alink( $url, $func_id ) . "\t";
        $r .= $term . $sd . $term . "\t";
        $it->addRow($r);
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( scalar( keys %term_h ) > 0 ) {
        print "</ul>\n";
    }

    $it->printOuterTable(1);

    print "<p>\n";
    my $name = "_section_MyIMG_confirmMyIMGGeneTerms";
    print submit(
        -name  => $name,
        -value => "Update Term Association",
        -class => "meddefbutton"
    );
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";

    print end_form();
}

############################################################################
# printConfirmMyIMGGenesTerms
############################################################################
sub printConfirmMyIMGGenesTerms {
    WebUtil::printMainForm();

    print "<h1>Confirm IMG Term Update for MyIMG Annotations</h1>\n";

    my @gene_oids = param('gene_oid');
    if ( scalar(@gene_oids) == 0 ) {
        WebUtil::webError("No Gene ID has been selected.");
        return;
    }

    my $source_page = param('source_page');
    print WebUtil::hiddenVar( 'source_page', $source_page );

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return;
    }

    my $dbh = dbLogin();
    my %genes_h;
    my %term_h;
    my %evid_h;
    my $sql = "select gene_oid, product_name from gene_myimg_functions where gene_oid = ? " . "and modified_by = ?";
    my $cur;
    my $sql2 = qq{
        select g1.gene_oid, g1.function, g1.evidence
        from gene_img_functions g1
        where g1.gene_oid = ?
        union
        select g2.gene_oid, g2.term_oid, g2.evidence
        from gene_myimg_terms g2
        where g2.gene_oid = ?
        and g2.modified_by = ?
    };

    for my $gene_oid (@gene_oids) {
        $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $contact_oid );
        my ( $gene_oid2, $gene_name ) = $cur->fetchrow();
        if ($gene_oid2) {
            if ( !$gene_name ) {
                $gene_name = WebUtil::geneOid2Name( $dbh, $gene_oid2 );
                if ( !$gene_name ) {
                    $gene_name = 'hypothetical protein';
                }
            }

            $genes_h{$gene_oid2} = $gene_name;
        }
        $cur->finish();

        my $cur2 = execSql( $dbh, $sql2, $verbose, $gene_oid, $gene_oid, $contact_oid );
        for ( ; ; ) {
            my ( $gid2, $term_oid, $evid ) = $cur2->fetchrow();
            last if !$gid2;

            if ( $term_h{$gid2} ) {
                $term_h{$gid2} .= "," . $term_oid;
            } else {
                $term_h{$gid2} = $term_oid;
            }

            if ( $evid_h{$term_oid} ) {
                $evid_h{$term_oid} .= "; " . $evid;
            } else {
                $evid_h{$term_oid} = $evid;
            }
        }
        $cur2->finish();
    }

    if ( scalar( keys %genes_h ) == 0 ) {
        webError("Cannot find the gene(s).");
        return;
    } else {
        print "<h2>Add/Update IMG Terms to MyIMG Annotations</h2>\n";
        print "<p>\n";
        for my $g_id ( keys %genes_h ) {
            print "Gene $g_id: " . escapeHTML( $genes_h{$g_id} ) . "<br/>\n";
            print WebUtil::hiddenVar( 'gene_oid', $g_id );
        }
    }

    my @taxon_oids = param('taxon_oid');
    for my $tid (@taxon_oids) {
        print WebUtil::hiddenVar( 'taxon_oid', $tid );
    }

    my @func_ids = param('func_id');

    my $func_list = "";
    if ( scalar(@func_ids) == 0 ) {
        print "<h4>No IMG terms will be associated with the gene(s).</h4>\n";
    } else {
        print "<h4>The gene(s) will be associated with the following IMG term:</h4>\n";
        my $j = 0;
        for my $func_id (@func_ids) {
            $j++;
            if ( $j > 1000 ) {
                print "<p><font color='red'>Too many terms -- only 1000 terms are used.</font>\n";
            }
            my ( $tag, $val ) = split( /\:/, $func_id );
            if ( !isInt($val) ) {
                next;
            }
            if ($func_list) {
                $func_list .= ", " . $val;
            } else {
                $func_list = $val;
            }
        }

        if ( !$func_list ) {
            webError("Incorrect terms.");
            return;
        }

        print "<table class='img'>\n";
        print "<th class='img'>Select</th>\n";
        print "<th class='img'>Term ID</th>\n";
        print "<th class='img'>Term</th>\n";
        print "<th class='img'>Evidence</th>\n";

        $sql = "select term_oid, term from img_term where term_oid in (" . $func_list . ")";
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $term_oid, $term ) = $cur->fetchrow();
            last if !$term_oid;

            my $func_id = "ITERM:" . $term_oid;
            print "<tr class='img'>\n";
            print "<td class='img'>";
            print "<input type='checkbox' name='func_id' value='$func_id' checked /> </td>\n";
            my $url = "$main_cgi?section=ImgTermBrowser" . "&page=imgTermDetail&term_oid=$term_oid";
            print "<td class='img'>" . alink( $url, $func_id ) . "</td>\n";
            print "<td class='img'>" . $term . "</td>\n";
            print "<td class='img'>"
              . "<input type='text' name='evid_"
              . $term_oid
              . "' value='"
              . $evid_h{$term_oid}
              . "' size='40' maxLength='255'/></td>\n";
            print "</tr>\n";
        }
        $cur->finish();

        print "</table>\n";
    }

    #$dbh->disconnect();

    print "<p>\n";
    if ( scalar(@func_ids) > 0 ) {
        print "<input type='checkbox' name='update_gene_prod_name' checked > ";
        print nbsp(1);
        print "Replace gene product name by selected IMG terms (if any)\n";
        print "<p>\n";
    }

    my $name = "_section_MyIMG_updateMyIMGGeneTerms";
    print submit(
        -name  => $name,
        -value => "Update Database",
        -class => "smdefbutton"
    );
    print nbsp(1);
    if ( !$source_page ) {
        $source_page = "showMain";
    }
    my $name = "_section_MyIMG_" . $source_page;
    print submit(
        -name  => $name,
        -value => "Cancel",
        -class => "smbutton"
    );

    print end_form();
}

############################################################################
# dbUpdateMyIMGGeneTerms
############################################################################
sub dbUpdateMyIMGGeneTerms {

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("Session expired.  Please log in again.");
        return;
    }

    my @gene_oids = param('gene_oid');
    if ( scalar(@gene_oids) == 0 ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("No gene has been selected.");
        return;
    }
    my $source_page = param("source_page");

    # show gene definition
    print "<p>\n";
    my %gene_name_h;
    my $dbh = dbLogin();
    my $sql = "select gene_oid, product_name from gene_myimg_functions where gene_oid = ? " . "and modified_by = ?";
    for my $gene_oid (@gene_oids) {
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $contact_oid );
        my ( $gene_oid2, $gene_name ) = $cur->fetchrow();
        if ( !$gene_oid2 ) {
            next;
        }
        if ( !$gene_name ) {

            # name is not important here
            #	    $gene_name = WebUtil::geneOid2Name($dbh, $gene_oid2);
            #	    if ( ! $gene_name ) {
            $gene_name = 'hypothetical protein';

            #	    }
        }
        $gene_name_h{$gene_oid2} = $gene_name;
        $cur->finish();
    }

    #$dbh->disconnect();

    if ( scalar( keys %gene_name_h ) == 0 ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("You cannot update the gene(s).");
        return;
    }

    my @func_ids              = param('func_id');
    my $update_gene_prod_name = param('update_gene_prod_name');
    my $term_names            = "";
    if ( $update_gene_prod_name && scalar(@func_ids) > 0 ) {
        my $sql = "";
        if ( scalar(@func_ids) < 1000 ) {
            for my $func_id (@func_ids) {
                my ( $tag, $val ) = split( /\:/, $func_id );
                if ( !isInt($val) ) {
                    next;
                }
                if ($sql) {
                    $sql .= ", " . $val;
                } else {
                    $sql = "select term_oid, term from img_term where term_oid in (" . $val;
                }
            }
            if ($sql) {
                $sql .= ")";
                my $dbh = dbLogin();
                my $cur = execSql( $dbh, $sql, $verbose );
                for ( ; ; ) {
                    my ( $term_oid2, $term ) = $cur->fetchrow();
                    last if !$term_oid2;
                    if ($term_names) {
                        $term_names .= "/" . $term;
                    } else {
                        $term_names = $term;
                    }
                }
                $cur->finish();

                #$dbh->disconnect();
            }
        }

        $term_names =~ s/'/''/g;    # replace ' by ''
    }

    my @sqlList = ();
    for my $gene_oid ( keys %gene_name_h ) {
        $sql = "delete from gene_myimg_terms where gene_oid = $gene_oid";
        push @sqlList, ($sql);
        for my $func_id (@func_ids) {
            my ( $tag, $val ) = split( /\:/, $func_id );
            if ( !isInt($val) ) {
                next;
            }

            my $evid = "";
            my $tag2 = "evid_" . $val;
            if ( param($tag2) ) {
                $evid = param($tag2);
            }
            $evid =~ s/^\s+//;
            $evid =~ s/\s+$//;
            $evid =~ s/\s+/ /g;
            if ( length($evid) > 255 ) {
                $evid = substr( $evid, 0, 255 );
            }
            $sql =
                "insert into gene_myimg_terms (gene_oid, term_oid, evidence, "
              . "modified_by, mod_date) "
              . "values ($gene_oid, $val, ";
            if ($evid) {
                $sql .= "'" . $evid . "'";
            } else {
                $sql .= "null";
            }
            $sql .= ", $contact_oid, sysdate)";
            push @sqlList, ($sql);
        }

        if ( $update_gene_prod_name && $term_names ) {
            $sql =
                "update gene_myimg_functions set product_name = '"
              . $term_names . "', "
              . "mod_date = sysdate "
              . "where gene_oid = $gene_oid";
            push @sqlList, ($sql);
        }
    }

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        main::printAppHeader("MyIMG");
        WebUtil::webError("SQL Error: $sql");
        return -1;
    }
}

############################################################################
# printMyMissingGenesTermForm
############################################################################
sub printMyMissingGenesTermForm {
    WebUtil::printMainForm();

    my $mygene_oid = param('mygene_oid');
    if ( !$mygene_oid ) {
        print "<h1>Add/Update IMG Terms to Missing Gene Annotations</h1>\n";
        WebUtil::webError("No Gene ID has been selected.");
        return;
    }

    print WebUtil::hiddenVar( 'mygene_oid', $mygene_oid );
    my $source_page = param('source_page');
    print WebUtil::hiddenVar( 'source_page', $source_page );

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return;
    }
    my $super_user_flag = WebUtil::getSuperUser();

    my @taxon_oids = param('taxon_oid');
    for my $tid (@taxon_oids) {
        print WebUtil::hiddenVar( 'taxon_oid', $tid );
    }

    ## get my gene img terms
    my $dbh = WebUtil::dbLogin();
    my $sql = qq{
        select g.mygene_oid, g.product_name, g.created_by, g.is_public
        from mygene g
        where g.mygene_oid = ?
        };
    my $cur = execSql( $dbh, $sql, $verbose, $mygene_oid );
    my ( $gene_oid2, $gene_name, $g_owner2, $g_public2 ) = $cur->fetchrow();
    $cur->finish();
    if ( !$gene_oid2 ) {

        #$dbh->disconnect();
        WebUtil::webError("No Gene ID has been selected.");
    } elsif ( $g_owner2 == $contact_oid ) {
        print "<h1>Add/Update IMG Terms to My Missing Gene Annotations</h1>\n";
    } elsif ( $g_public2 eq 'Yes' && $super_user_flag eq 'Yes' ) {
        print "<h1>Add/Update IMG Terms to Public Missing Gene Annotations</h1>\n";
    } else {

        #$dbh->disconnect();
        WebUtil::webError("No Gene ID has been selected.");
    }
    print WebUtil::hiddenVar( 'created_by', $g_owner2 );

    my %term_h;
    $sql = qq{
            select mt.mygene_oid, mt.term_oid, mt.evidence
            from mygene_terms mt
            where mt.mygene_oid = ?
            };
    $cur = execSql( $dbh, $sql, $verbose, $mygene_oid );
    for ( ; ; ) {
        my ( $mygene_oid, $term_oid, $evidence ) = $cur->fetchrow();
        last if !$mygene_oid;
        if ( !$evidence ) {
            $evidence = "none";
        }
        $term_h{$term_oid} = $evidence;
    }
    $cur->finish();

    ## show all IMG terms for selection
    print "<h2>My Missing Gene $gene_oid2: $gene_name</h2>\n";

    if ( scalar( keys %term_h ) == 0 ) {
        print "<h4>The gene has no associated IMG terms.</h4>\n";
    } elsif ( scalar( keys %term_h ) == 1 ) {
        print "<h4>The gene is associated with the following IMG term:</h4>\n";
        print "<ul>\n";
    } else {
        print "<h4>The gene is associated with the following IMG terms:</h4>\n";
        print "<ul>\n";
    }

    my $it = new InnerTable( 1, "myGeneTerm$$", "myGeneTerm", 2 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Function ID", "char desc", "left" );
    $it->addColSpec( "Name",        "char asc",  "left" );

    $sql = "select term_oid, term from img_term";
    $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $term_oid, $term ) = $cur->fetchrow();
        last if !$term_oid;

        if ( $term_h{$term_oid} ) {
            print "<li>IMG Term $term_oid: $term";
            if ( $term_h{$term_oid} ne 'none' ) {
                print " (evidence: " . $term_h{$term_oid} . ")";
            }
            print "</li>\n";
        }

        my $func_id = "ITERM:" . $term_oid;
        my $checked = "";
        if ( defined $term_h{$term_oid} ) {
            $checked = "checked";
        }
        my $r   = $sd . "<input type='checkbox' name='func_id' value='$func_id' $checked /> \t";
        my $url = "$main_cgi?section=ImgTermBrowser" . "&page=imgTermDetail&term_oid=$term_oid";
        $r .= $func_id . $sd . alink( $url, $func_id ) . "\t";
        $r .= $term . $sd . $term . "\t";
        $it->addRow($r);
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( scalar( keys %term_h ) > 0 ) {
        print "</ul>\n";
    }

    $it->printOuterTable(1);

    print "<p>\n";
    my $name = "_section_MyIMG_confirmMissingGeneTerms";
    print submit(
        -name  => $name,
        -value => "Update Term Association",
        -class => "meddefbutton"
    );

    print end_form();
}

############################################################################
# printConfirmMissingGenesTerms
############################################################################
sub printConfirmMissingGenesTerms {
    WebUtil::printMainForm();

    my $mygene_oid = param('mygene_oid');
    if ( !$mygene_oid ) {
        WebUtil::webError("No Gene ID has been selected.");
        return;
    }

    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        return;
    }
    my $super_user_flag = WebUtil::getSuperUser();

    print WebUtil::hiddenVar( 'mygene_oid', $mygene_oid );

    my $source_page = param('source_page');
    print WebUtil::hiddenVar( 'source_page', $source_page );

    # show my gene definition
    my $dbh = dbLogin();
    my $sql = "select mygene_oid, product_name, created_by, is_public " . "from mygene where mygene_oid = ? ";
    my $cur = execSql( $dbh, $sql, $verbose, $mygene_oid );
    my ( $gene_oid2, $gene_name, $created_by, $is_public ) = $cur->fetchrow();
    $cur->finish();

    print "<h1>Confirm IMG Terms to Missing Gene Annotations</h1>\n";

    if ( !$gene_oid2 ) {

        #$dbh->disconnect();
        webError("Cannot find the gene.");
        return;
    } elsif ( $created_by == $contact_oid ) {
        print "<h2>My Missing Gene $gene_oid2: $gene_name</h2>\n";
    } elsif ( $is_public eq 'Yes' && $super_user_flag eq 'Yes' ) {
        print "<h2>Missing Gene $gene_oid2: $gene_name</h2>\n";
    } else {

        #$dbh->disconnect();
        webError("Cannot find the gene.");
        return;
    }

    # get evidence
    my %evid_h;
    my $sql = "select mygene_oid, term_oid, evidence from mygene_terms where mygene_oid = ? ";
    my $cur = execSql( $dbh, $sql, $verbose, $mygene_oid );
    for ( ; ; ) {
        my ( $gid2, $tid, $evid ) = $cur->fetchrow();
        last if !$gid2;
        $evid_h{$tid} = $evid;
    }
    $cur->finish();

    my @taxon_oids = param('taxon_oid');
    for my $tid (@taxon_oids) {
        print WebUtil::hiddenVar( 'taxon_oid', $tid );
    }

    my @func_ids = param('func_id');

    my $func_list = "";
    if ( scalar(@func_ids) == 0 ) {
        print "<h4>No IMG terms will be associated with the gene.</h4>\n";
    } else {
        print "<h4>The gene will be associated with the following IMG term:</h4>\n";
        my $j = 0;
        for my $func_id (@func_ids) {
            $j++;
            if ( $j > 1000 ) {
                print "<p><font color='red'>Too many terms -- only 1000 terms are used.</font>\n";
            }
            my ( $tag, $val ) = split( /\:/, $func_id );
            if ( !isInt($val) ) {
                next;
            }
            if ($func_list) {
                $func_list .= ", " . $val;
            } else {
                $func_list = $val;
            }
        }

        if ( !$func_list ) {
            webError("Incorrect terms.");
            return;
        }

        print "<table class='img'>\n";
        print "<th class='img'>Select</th>\n";
        print "<th class='img'>Term ID</th>\n";
        print "<th class='img'>Term</th>\n";
        print "<th class='img'>Evidence</th>\n";

        $sql = "select term_oid, term from img_term where term_oid in (" . $func_list . ")";
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $term_oid, $term ) = $cur->fetchrow();
            last if !$term_oid;

            my $func_id = "ITERM:" . $term_oid;
            print "<tr class='img'>\n";
            print "<td class='img'>";
            print "<input type='checkbox' name='func_id' value='$func_id' checked /> </td>\n";
            my $url = "$main_cgi?section=ImgTermBrowser" . "&page=imgTermDetail&term_oid=$term_oid";
            print "<td class='img'>" . alink( $url, $func_id ) . "</td>\n";
            print "<td class='img'>" . $term . "</td>\n";
            print "<td class='img'>"
              . "<input type='text' name='evid_"
              . $term_oid
              . "' value='"
              . $evid_h{$term_oid}
              . "' size='40' maxLength='255'/></td>\n";
            print "</tr>\n";
        }
        $cur->finish();

        print "</table>\n";
    }

    #$dbh->disconnect();

    print "<p>\n";
    if ( scalar(@func_ids) > 0 ) {
        print "<input type='checkbox' name='update_gene_prod_name' checked > ";
        print nbsp(1);
        print "Replace gene product name by selected IMG terms (if any)\n";
        print "<p>\n";
    }

    my $name = "_section_MyIMG_updateMissingGeneTerms";
    print submit(
        -name  => $name,
        -value => "Update Database",
        -class => "smdefbutton"
    );
    print nbsp(1);
    if ( !$source_page ) {
        $source_page = "showMain";
    }
    my $name = "_section_MyIMG_" . $source_page;
    print submit(
        -name  => $name,
        -value => "Cancel",
        -class => "smbutton"
    );

    print end_form();
}

############################################################################
# dbUpdateMissingGeneTerms
############################################################################
sub dbUpdateMissingGeneTerms {

    # check login
    my $contact_oid = WebUtil::getContactOid();
    if ( !$contact_oid ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("Session expired.  Please log in again.");
        return;
    }

    my $mygene_oid = param("mygene_oid");
    if ( !$mygene_oid ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("No gene has been selected.");
        return;
    }
    my $source_page     = param("source_page");
    my $super_user_flag = WebUtil::getSuperUser();

    # show my gene definition
    my $dbh = dbLogin();
    my $sql = "select mygene_oid, product_name, created_by, is_public " . "from mygene where mygene_oid = ? ";
    my $cur = execSql( $dbh, $sql, $verbose, $mygene_oid );
    my ( $gene_oid2, $gene_name, $created_by, $is_public ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    if ( !$gene_oid2 ) {
        main::printAppHeader("MyIMG");
        WebUtil::webError("You cannot update this gene.");
        return;
    } elsif ( $created_by == $contact_oid ) {

        # same user
    } elsif ( $super_user_flag eq 'Yes' && $is_public eq 'Yes' ) {

        # super user can update public missing gene
    } else {
        main::printAppHeader("MyIMG");
        WebUtil::webError("You cannot update this gene.");
        return;
    }

    my @func_ids              = param('func_id');
    my $update_gene_prod_name = param('update_gene_prod_name');
    my $term_names            = "";
    if ( $update_gene_prod_name && scalar(@func_ids) > 0 ) {
        my $sql = "";
        if ( scalar(@func_ids) < 1000 ) {
            for my $func_id (@func_ids) {
                my ( $tag, $val ) = split( /\:/, $func_id );
                if ( !isInt($val) ) {
                    next;
                }
                if ($sql) {
                    $sql .= ", " . $val;
                } else {
                    $sql = "select term_oid, term from img_term where term_oid in (" . $val;
                }
            }
            if ($sql) {
                $sql .= ")";
                my $dbh = dbLogin();
                my $cur = execSql( $dbh, $sql, $verbose );
                for ( ; ; ) {
                    my ( $term_oid2, $term ) = $cur->fetchrow();
                    last if !$term_oid2;
                    if ($term_names) {
                        $term_names .= "/" . $term;
                    } else {
                        $term_names = $term;
                    }
                }
                $cur->finish();

                #$dbh->disconnect();
            }
        }

        $term_names =~ s/'/''/g;    # replace ' by ''
    }

    my @sqlList = ();
    $sql = "delete from mygene_terms where mygene_oid = $mygene_oid";
    push @sqlList, ($sql);
    for my $func_id (@func_ids) {
        my ( $tag, $val ) = split( /\:/, $func_id );
        if ( !isInt($val) ) {
            next;
        }

        my $evid = "";
        my $tag2 = "evid_" . $val;
        if ( param($tag2) ) {
            $evid = param($tag2);
        }
        $evid =~ s/^\s+//;
        $evid =~ s/\s+$//;
        $evid =~ s/\s+/ /g;
        if ( length($evid) > 255 ) {
            $evid = substr( $evid, 0, 255 );
        }
        $sql =
            "insert into mygene_terms (mygene_oid, term_oid, evidence, modified_by, mod_date) "
          . "values ($mygene_oid, $val, ";
        if ($evid) {
            $sql .= "'" . $evid . "'";
        } else {
            $sql .= "null";
        }
        $sql .= ", $contact_oid, sysdate)";
        push @sqlList, ($sql);

        if ( $update_gene_prod_name && $term_names ) {
            $sql =
                "update mygene set product_name = '"
              . $term_names . "', "
              . "modified_by = $contact_oid, mod_date = sysdate "
              . "where mygene_oid = $mygene_oid";
            push @sqlList, ($sql);
        }
    }

    # perform database update
    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ($err) {
        $sql = $sqlList[ $err - 1 ];
        main::printAppHeader("MyIMG");
        WebUtil::webError("SQL Error: $sql");
        return -1;
    }
}

sub Connect_IMG_EXT {

    # use IMG_EXT
    my $user2    = "img_ext";
    my $pw2      = decode_base64("aW1nX2V4dDk4Nw==");
    my $service2 = "muskrat_imgiprd";

    my $ora_host = "muskrat.jgi-psf.org";
    my $ora_port = "1521";
    my $ora_sid  = "imgiprd";

    # my $dsn2 = "dbi:Oracle:host=$service2";
    my $dsn2 = "dbi:Oracle:host=$ora_host;port=$ora_port;sid=$ora_sid";
    my $dbh2 = DBI->connect( $dsn2, $user2, $pw2 );
    if ( !defined($dbh2) ) {
        webDie("cannot login to IMG MER V330\n");
    }
    $dbh2->{LongReadLen} = 50000;
    $dbh2->{LongTruncOk} = 1;
    return $dbh2;
}

1;
