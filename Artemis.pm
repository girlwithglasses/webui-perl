############################################################################
# Artemis.pm - Handle web artemis start up.
#     --es 09/13/2007
# $Id: Artemis.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package Artemis;
use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use Data::Dumper;
use WebUtil;
use WebConfig;
use GenBankFile;
use QueryUtil;
use GenomeListJSON;

$| = 1;
my $section = "Artemis";
my $env                      = getEnv();
my $main_cgi                 = $env->{main_cgi};
my $taxon_lin_fna_dir        = $env->{taxon_lin_fna_dir};
my $taxon_fna_dir            = $env->{taxon_fna_dir};
my $tmp_url                  = $env->{tmp_url};
my $tmp_dir                  = $env->{tmp_dir};
my $cgi_tmp_dir              = $env->{cgi_tmp_dir};
my $cgi_url                  = $env->{cgi_url};
my $cgi_dir                  = $env->{cgi_dir};
my $base_url                 = $env->{base_url};
my $base_dir                 = $env->{base_dir};
my $artemis_url              = $env->{artemis_url};
my $img_internal             = $env->{img_internal};
my $artemis_link             = alink( $artemis_url, "Artemis" );

my $verbose                  = $env->{verbose};
my $max_export_scaffold_list = 1000;
my $include_img_terms        = 0;
my $include_metagenomes      = $env->{include_metagenomes};

# mega blast location
my $megablast_bin = $env->{megablast_bin};
my $formatdb_bin  = $env->{formatdb_bin};
my $fastacmd_bin  = $env->{fastacmd_bin};

my $YUI           = $env->{yui_dir_28};
my $yui_tables    = $env->{yui_tables};
my $USE_YUI = 0;

############################################################################
# dispatch
############################################################################
sub dispatch {
    my ($numTaxon) = @_;
    my $page = param("page");
    timeout( 60 * 20 );    # timeout in 20 minutes (from main.pl)

    if ( paramMatch("processArtemisFile") ) {
        processArtemisFile();
    } elsif ( $page eq "ACT" ) {
        printACTformTest();
    } elsif ( $page eq "ACTForm" ) {
        printACTGenomeForm($numTaxon);
    } elsif ( $page eq "pairwise" ) {
        if ($USE_YUI) {
            printACTPairwise_yui();
        } else {
            printACTPairwise();
        }
    } elsif ( $page eq "processACT" ) {
        processACT();
    } elsif ( $page eq "reorder" ) {
        # reorder contigs
        if ($USE_YUI) {
            printReorderForm_yui();
        } else {
            printReorderForm();
        }
    } else {
        printArtemisForm();
    }
}

sub printACTWebStart {
    my ( $gbk_files_aref, $mblast_files_aref ) = @_;

    my $sid  = getSessionId();
    my $file = "act$$" . "_" . $sid . ".jnlp";
    my $path = "$tmp_dir/$file";
    my $fh   = newWriteFileHandle($path);

    print $fh qq{
<?xml version="1.0" encoding="UTF-8"?>
<jnlp
    spec="1.0+"
    codebase="$base_url">
    <information>
        <title>Artemis Comparison Tool - ACT</title>
        <vendor>Sanger Institute</vendor>
        <homepage href="http://www.sanger.ac.uk/Software/ACT/"/>
        <description>ACT</description>
        <description kind="short">DNA sequence viewer and annotation tool.
        </description>
        <offline-allowed/>
    </information>
    <security>
        <all-permissions/>
    </security>
    <resources>
        <j2se version="1.4+ 1.4.2" initial-heap-size="128m" max-heap-size="900m"/>
        <jar href="act.jar"/>
        <property name="com.apple.mrj.application.apple.menu.about.name" value="ACT" />
        <property name="artemis.environment" value="UNIX" />
        <property name="j2ssh" value="" />
    </resources>
    <application-desc main-class="uk.ac.sanger.artemis.components.ActMain">
    };

    for ( my $i = 0 ; $i <= $#$gbk_files_aref ; $i++ ) {
        my $data_url1 = "$tmp_url/" . $gbk_files_aref->[$i];
        print $fh qq{
          <argument> $data_url1  </argument>
        };

        if ( $i < $#$gbk_files_aref ) {
            my $data_url2 = "$tmp_url/" . $mblast_files_aref->[$i];
            print $fh qq{
              <argument> $data_url2  </argument>
            };
        }
    }

    print $fh qq{
          </application-desc>
       </jnlp>
    };

    close $fh;
    return $file;
}

sub printACTGenomeForm {
    my ($numTaxon) = @_;
    my $act_link =
	"<a href=http://bioinformatics.oxfordjournals.org/cgi/content/"
      . "abstract/21/16/3422>Artemis Comparison Tool</a>";
    my $artemis_link =
	"<a href=http://www.sanger.ac.uk/Software/ACT/>ACT</a>";
    my $webstart =
	"<a href=http://java.sun.com/javase/technologies/desktop/"
      . "javawebstart/index.jsp>Java Web Start</a>";
    my $citation = getActCitation();

    my $text =
	"$act_link (ACT) is a viewer based on Artemis for pairwise genome "
      . "DNA sequence comparisons. Sequence comparisons displayed by ACT "
      . "are the result of running Mega BLAST search. "
      . "Artemis $artemis_link application requires $webstart and 1 GB of RAM.";

    my $description = "$text<br/>$citation";
    if ($include_metagenomes) {
	WebUtil::printHeaderWithInfo
	    ("Artemis Comparison Tool", $description,
	     "show description for this tool", "ACT Info", 1);
    } else {
	WebUtil::printHeaderWithInfo
	    ("Artemis Comparison Tool", $description,
	     "show description for this tool", "ACT Info");
    }

    print "<p style='width: 650px;'>$text</p>";
    print "<p><font color='#003366'>Please select 2 to 5 genomes.</font></p>";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $dbh = dbLogin();
    #$dbh->disconnect();

    printForm();
    my $name = "_section_Artemis_pairwise";
    GenomeListJSON::printHiddenInputType( $section, 'pairwise' );
    my $button = GenomeListJSON::printMySubmitButtonXDiv
	( 'go', $name, 'Next', '', $section,
	  'pairwise', 'meddefbutton', 'selectedGenome1', 2 );
    print $button;

    print hiddenVar( "section", $section );
    print hiddenVar( "page",    "pairwise" );
    print hiddenVar( "from",    "ACT" );

    print end_form();
    printWebstartTest();
    GenomeListJSON::showGenomeCart($numTaxon);
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printForm - genome loader used for selecting genomes
############################################################################
sub printForm {
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ($hideViruses eq "" || $hideViruses eq "Yes") ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ($hidePlasmids eq "" || $hidePlasmids eq "Yes") ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ($hideGFragment eq "" || $hideGFragment eq "Yes") ? 0 : 1;

    my $xml_cgi = $cgi_url . '/xml.cgi';
    my $template = HTML::Template->new
        ( filename => "$base_dir/genomeJsonOneDiv.html" );

    $template->param( gfr          => $hideGFragment );
    $template->param( pla          => $hidePlasmids );
    $template->param( vir          => $hideViruses );
    $template->param( isolate      => 1 );
    $template->param( all          => 0 );
    $template->param( cart         => 1 );
    $template->param( xml_cgi      => $xml_cgi );
    $template->param( prefix       => '' );
    $template->param( maxSelected1 => 5 );
    $template->param( selectedGenome1Title => 'Please select 2 to 5 genomes:' );

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;
}

sub printJS {
    print <<EOF
        <script language="javascript" type="text/javascript">


	function contigSelect(select, taxon_oid) {
	    var f = document.mainForm;
	    for ( var i = 0; i < f.length; i++) {
		var e = f.elements[i];
		if (e.type == "checkbox" &&
		    (e.value.indexOf('_' + taxon_oid) > -1) ) {
		    e.checked = (select == 0 ? false : true);
		}
	    }
        }


        function mySubmit(page) {
	    document.mainForm.page.value = page;
	    document.mainForm.submit();
	}


/*
 * as the user types only allow [0-9] values use it on event onKeyPress="return
 * numbersonly(event)"
 */
function numbersonly(e) {
    var key;
    var keychar;

    if (window.event) {
        key = window.event.keyCode;
    } else if (e) {
        key = e.which;
    } else {
        return true;
    }
    keychar = String.fromCharCode(key);

    // control keys
    if ((key == null) || (key == 0) || (key == 8) || (key == 9) || (key == 13)
            || (key == 27)) {
        return true;
        // } else if ((("-.0123456789").indexOf(keychar) > -1)) {
    } else if ((("0123456789").indexOf(keychar) > -1)) {
        // numbers
        return true;
    } else {
        return false;
    }
}


    </script>

EOF

}

sub printACTPairwise {
    my @taxon_oids = param("selectedGenome1");
    my @order       = param("order");
    my @orderTaxons = param("taxon_oid");
    #print "printACTPairwise \@taxon_oids: @taxon_oids <br\> \@order: @order";

    if ( $#taxon_oids < 1 && $#order < 1 ) {
        webError("Please select at least 2 genomes.\n");
    } elsif ( $#taxon_oids > 4 ) {
        webError("Max. selection of 5 genomes.\n");
    }

    print qq{
        <h1> Pairwise Selection </h1>
        <p>
        Genomes will be compared pairwise.
        E.g. G1, G2, G3 comparison will be (G1 vs G2) and (G2 vs G3)
        <br/>
        Press <i>Update</i> button to update order.
        <br/>
        Press <i>Next</i> button to view Genome's contigs.
        </p>
    };
    printMainForm();
    printJS();

    # Use YUI css
    if ($yui_tables) {
	print <<YUI;

        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
        <style type="text/css">
	   .txtBox {
	       background-color: white;
	       border: 1px solid #99CCFF;
	   }
	</style>

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Order</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Genome ID</span>
	    </div>
	</th>
	<th>
 	    <div class='yui-dt-liner'>
	        <span>Genome Name</span>
	    </div>
	</th>
YUI
    } else {
	print qq{
           <table class='img'>
           <th class='img'>Order</th>
           <th class='img'>Genome ID</th>
           <th class='img'>Genome Name</th>
        };
    }
    if ( $#order > -1 ) {

        # intialize array
        @taxon_oids = @orderTaxons;

        # find order using @order
        # %hash_index - array index => order value
        my %hash_index;
        for ( my $i = 0 ; $i <= $#order ; $i++ ) {
            $hash_index{$i} = $order[$i];
        }

        # now sort the data in the hash by the value user entered
        my $i = 0;
        foreach my $key (
                          sort { $hash_index{$a} <=> $hash_index{$b} }
                          keys %hash_index
          )
        {

            # key is index of the array order or orderTaxons
            $taxon_oids[$i] = $orderTaxons[$key];
            $i++;
        }
    }

    # get genome names
    my $dbh = dbLogin();
    my %taxon_names = QueryUtil::fetchTaxonOid2NameHash($dbh, \@taxon_oids);
    #$dbh->disconnect();

    my $rowcnt = 1;
    foreach my $id (@taxon_oids) {
        my $name = $taxon_names{$id};
    	my $classStr;

    	if ($yui_tables) {
    	    $classStr = !$rowcnt ? "yui-dt-first ":"";
    	    $classStr .= ($rowcnt % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
    	} else {
    	    $classStr = "img";
    	}

    	print "<tr class='$classStr'>\n";

    	# Order
    	print "<td class='$classStr'>\n";
    	print "<div class='yui-dt-liner'>" if $yui_tables;
    	print "<input type='text' onKeyPress='return numbersonly(event)' size='4' name='order' value='$rowcnt' class='txtBox' />";
    	print "</div>\n" if $yui_tables;
    	print "</td>\n";

    	# Genome ID
    	print "<td class='$classStr'>\n";
    	print "<div class='yui-dt-liner'>" if $yui_tables;
    	print "<input type='text' name='taxon_oid' value='$id' readonly='readonly' class='txtBox'/>";
    	print "</div>\n" if $yui_tables;
    	print "</td>\n";

    	# Genome Name
    	print "<td class='$classStr'>\n";
    	print "<div class='yui-dt-liner'>" if $yui_tables;
    	print $name;
    	print "</div>\n" if $yui_tables;
    	print "</td>\n";

        $rowcnt++;
    }

    print "</table>";
    print "</div>\n" if $yui_tables;

    print hiddenVar( "section", $section );
    print hiddenVar( "page",    "pairwise" );    # updated by javascript
    print hiddenVar( "from",    "ACT" );

    print qq{
        <br/>
        <input type="button" class='smbutton' name="Update" value="Update" title="Update order" onclick="javascript:mySubmit('pairwise')"/>
    };
    print nbsp(1);
    print qq{
        <input type="button" class='smbutton' name="Next" value="Next" title="view genome contigs" onclick="javascript:mySubmit('reorder')"/>
    };

    print end_form();

}

sub printACTPairwise_yui {
    printYUI();

    my @taxon_oids = param("selectedGenome1");
    my @order       = param("order");
    my @orderTaxons = param("taxon_oid");

    if ( $#taxon_oids < 1 && $#order < 1 ) {
        webError("Please select at least 2 genomes.\n");
    } elsif ( $#taxon_oids > 4 ) {
        webError("Max. selection of 5 genomes.\n");
    }

    print qq{
        <h1> Pairwise Selection </h1>
        <p>
        Genomes will be compared pairwise.
        E.g. G1, G2, G3 comparison will be (G1 vs G2) and (G2 vs G3)
        <br/>
        Press <i>Update</i> button to update order.
        <br/>
        Press <i>Next</i> button to view Genome's contigs.
        </p>
    };
    printMainForm();
    printJS();

    if ( $#order > -1 ) {
        # intialize array
        @taxon_oids = @orderTaxons;

        # find order using @order
        # %hash_index - array index => order value
        my %hash_index;
        for ( my $i = 0 ; $i <= $#order ; $i++ ) {
            $hash_index{$i} = $order[$i];
        }

        # now sort the data in the hash by the value user entered
        my $i = 0;
        foreach my $key ( sort { $hash_index{$a} <=> $hash_index{$b} }
                          keys %hash_index ) {
            # key is index of the array order or orderTaxons
            $taxon_oids[$i] = $orderTaxons[$key];
            $i++;
        }
    }

    # get genome names
    my $dbh    = dbLogin();
    my %taxon_names = QueryUtil::fetchTaxonOid2NameHash($dbh, \@taxon_oids);
    #$dbh->disconnect();

    my $rowcnt = 1;
    print "<div id='datatable'></div>";
    print "<script language='javascript' type='text/javascript'>\n";
    print "YAHOO.example.genomes = [\n";
    foreach my $id (@taxon_oids) {
        my $name = $taxon_names{$id};

        print qq{
            {genome_id:"<input type='text' name='taxon_oid' value='$id' readonly='readonly' style='background-color:white' />",
                 genome_name:"$name" }
        };

        print ",\n" if ( $rowcnt <= $#taxon_oids );

        $rowcnt++;
    }

    print "];\n";
    print "</script>\n";

    print "<script src = \"$base_url/actPairwise.js\" ></script>\n";

    print hiddenVar( "section", $section );
    print hiddenVar( "page",    "pairwise" );    # updated by javascript
    print hiddenVar( "from",    "ACT" );

    print qq{
        <input type="button" class='smbutton' name="Next" value="Next" title="view genome contigs" onclick="javascript:mySubmit('reorder')"/>
    };

    print end_form();

}

# print "<script src = \"$base_url/datatableDragAndDrop.js\" ></script>\n";

# <link rel="stylesheet" type="text/css" href="$YUI/build/fonts/fonts-min.css" />
sub printYUI {
    print <<EOF;

<link rel="stylesheet" type="text/css" href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
<link rel="stylesheet" type="text/css" href="$YUI/build/paginator/assets/skins/sam/paginator.css" />
<script type="text/javascript" src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script>
<script type="text/javascript" src="$YUI/build/dragdrop/dragdrop-min.js"></script>
<script type="text/javascript" src="$YUI/build/element/element-min.js"></script>
<script type="text/javascript" src="$YUI/build/datasource/datasource-min.js"></script>
<script type="text/javascript" src="$YUI/build/datatable/datatable-min.js"></script>
<script type="text/javascript" src="$YUI/build/paginator/paginator-min.js"></script>

<style type="text/css">
/* custom styles for this example */
.custom-class {
  opacity: 0.6;filter:alpha(opacity=60);
  color:blue;
  border: 2px solid gray;
}

#datatable tr {
   cursor: pointer;
}
</style>

EOF

}

# test to see if java web start is installed
sub printWebstartTest {
    print <<EOF;
<SCRIPT LANGUAGE="JavaScript">
var javawsInstalled = 0;
var javaws142Installed=0;
var javaws150Installed=0;
var javaws160Installed = 0;
isIE = "false";
if (navigator.mimeTypes && navigator.mimeTypes.length) {
   x = navigator.mimeTypes['application/x-java-jnlp-file'];
   if (x) {
      javawsInstalled = 1;
      javaws142Installed=1;
      javaws150Installed=1;
      javaws160Installed = 1;
  }
}
else {
   isIE = "true";
}
</SCRIPT>

<SCRIPT LANGUAGE="VBScript">
on error resume next
If isIE = "true" Then
  If Not(IsObject(CreateObject("JavaWebStart.isInstalled"))) Then
     javawsInstalled = 0
  Else
     javawsInstalled = 1
  End If
  If Not(IsObject(CreateObject("JavaWebStart.isInstalled.1.4.2.0"))) Then
     javaws142Installed = 0
  Else
     javaws142Installed = 1
  End If
  If Not(IsObject(CreateObject("JavaWebStart.isInstalled.1.5.0.0"))) Then
     javaws150Installed = 0
  Else
     javaws150Installed = 1
  End If
  If Not(IsObject(CreateObject("JavaWebStart.isInstalled.1.6.0.0"))) Then
     javaws160Installed = 0
  Else
     javaws160Installed = 1
  End If
End If
</SCRIPT>


<SCRIPT LANGUAGE="JavaScript">
if (javawsInstalled == 0 && javaws142Installed == 0 &&
    javaws150Installed == 0 && javaws160Installed == 0) {
    alert("Please install Java Web Start before continuing.");
}  else {
    //alert(javawsInstalled + " " + javaws142Installed + " " +
    //javaws150Installed + " " + javaws160Installed );
}

</SCRIPT>

EOF

}

#
# reorder
#
sub printReorderForm {
    my @taxon_oids      = param("taxon_oid");
    my @ignore          = param("ignore");
    my $myImgOverride   = param("myImgOverride");
    my $imgTermOverride = param("imgTermOverride");
    my $gene_oid_note   = param("gene_oid_note");

    # list of ext_acc _ taxon oid to ignore
    my %ignore_hash;
    foreach my $i (@ignore) {
        $ignore_hash{$i} = 1;
    }

    # array of arrays of list of orders
    my @orders;
    my @ext_accessions;
    for ( my $i = 0 ; $i <= $#taxon_oids ; $i++ ) {
        my $toid              = $taxon_oids[$i];
        my @tmp_order         = param("order$i");
        my @tmp_ext_accession = param("ext_accession$i");

        my @tmp_order2;
        my @tmp_ext_accession2;
        for ( my $j = 0 ; $j <= $#tmp_order ; $j++ ) {
            my $ignoreid = $tmp_ext_accession[$j] . "_" . $toid;
            if ( !exists $ignore_hash{$ignoreid} ) {
                push( @tmp_order2,         $tmp_order[$j] );
                push( @tmp_ext_accession2, $tmp_ext_accession[$j] );
            }
        }

        push( @orders, \@tmp_order2 ) if ( $#tmp_order2 > -1 );
        push( @ext_accessions, \@tmp_ext_accession2 )
          if ( $#tmp_ext_accession2 > -1 );
    }

    if ( $#orders != $#taxon_oids && $#ignore > -1 ) {
        webError("You cannot remove all the scaffolds from a genome.\n");
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print qq{
        <h1>
        Contig Reorder - Artemis - ACT
        </h1>
        <p>
        Select <i>Ignore</i> to remove contig.
        <br/>
        Press <i>Update</i> button to update order and remove any selected contigs.
        <br/>
        Press <i>Next</i> button to create files for ACT.
        </p>
    };
    printMainForm();
    printJS();

    # hashes  of scaffold oid => ext_accession id
    for ( my $i = 0 ; $i <= $#taxon_oids ; $i++ ) {
        my $toid = $taxon_oids[$i];
        my $taxon_name = taxonOid2Name( $dbh, $toid );
        print "<p> $taxon_name </p>\n";

        #
        # $scaffold_order_aref - order in files
        my ( $taxon_href, $scaffold_order_aref );

        if ( $#orders > -1 ) {

            # this is a reorder
            my $tmp_order_aref = $orders[$i];
            my $tmp_ext_aref   = $ext_accessions[$i];

            # intialize array
            my @tmp_scaffold = ();

            # find order
            # %hash_index - array index => order value
            my %hash_index;
            for ( my $i = 0 ; $i <= $#$tmp_order_aref ; $i++ ) {
                $hash_index{$i} = $tmp_order_aref->[$i];
            }

            # now sort the data in the hash by the value user entered
            my $j = 0;
            foreach my $key (
		sort { $hash_index{$a} <=> $hash_index{$b} }
		keys %hash_index
	    )
            {
                # key is index of the array order or orderTaxons
                $tmp_scaffold[$j] = $tmp_ext_aref->[$key];
                $j++;
            }
            $scaffold_order_aref = \@tmp_scaffold;

        } else {
            if(!-e "$taxon_fna_dir/$toid.fna") {
                webError("$toid.fna file is missing.");
            }

            # get order from file
            ( $taxon_href, $scaffold_order_aref ) =
              loadSeqCount("$taxon_fna_dir/$toid.fna");
        }

        my $sdetail_href = getTaxonScaffoldDetail( $dbh, $toid );
        printReorderTable( $scaffold_order_aref, $i, $sdetail_href, $toid );

        print "<br/>\n";
    }

    print hiddenVar( "section",         $section );
    print hiddenVar( "page",            "processACT" );
    print hiddenVar( "myImgOverride",   $myImgOverride );
    print hiddenVar( "imgTermOverride", $imgTermOverride );
    print hiddenVar( "gene_oid_note",   $gene_oid_note );
    print hiddenVar( "from",            "ACT" );

    foreach my $toid (@taxon_oids) {
        print hiddenVar( "taxon_oid", $toid );
    }

    print qq{
        <input type="button" class='smbutton' name="Update" value="Update"
             title="Update order" onclick="javascript:mySubmit('reorder')"/>
    };
    print nbsp(1);
    print qq{
        <input type="button" class='smbutton' name="Next"
             value="Next" onclick="javascript:mySubmit('processACT')"/>
    };
    print end_form();
    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
}

sub printReorderForm_yui {
    printYUI();

    my @taxon_oids      = param("taxon_oid");
    my @ignore          = param("ignore");
    my $myImgOverride   = param("myImgOverride");
    my $imgTermOverride = param("imgTermOverride");
    my $gene_oid_note   = param("gene_oid_note");


    # list of ext_acc _ taxon oid to ignore
    my %ignore_hash;
    foreach my $i (@ignore) {
        $ignore_hash{$i} = 1;
    }

    # array of arrays of list of orders
    my @orders;
    my @ext_accessions;
    for ( my $i = 0 ; $i <= $#taxon_oids ; $i++ ) {
        my $toid              = $taxon_oids[$i];
        my @tmp_order         = param("order$i");
        my @tmp_ext_accession = param("ext_accession$i");

        my @tmp_order2;
        my @tmp_ext_accession2;
        for ( my $j = 0 ; $j <= $#tmp_order ; $j++ ) {
            my $ignoreid = $tmp_ext_accession[$j] . "_" . $toid;
            if ( !exists $ignore_hash{$ignoreid} ) {
                push( @tmp_order2,         $tmp_order[$j] );
                push( @tmp_ext_accession2, $tmp_ext_accession[$j] );
            }
        }

        push( @orders, \@tmp_order2 ) if ( $#tmp_order2 > -1 );
        push( @ext_accessions, \@tmp_ext_accession2 )
          if ( $#tmp_ext_accession2 > -1 );
    }

print Dumper \@taxon_oids;
print "<br/>";
print Dumper \@ignore;
print "<br/>";
print Dumper \@orders;
print "<br/>";

    if ( $#orders != $#taxon_oids && $#ignore > -1 ) {
        webError("You cannot remove all the scaffolds from a genome.\n");
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print qq{
        <h1>
        Contig Reorder - Artemis - ACT
        </h1>
        <p>
        Select <i>Ignore</i> to remove contig.
        <br/>
        Press <i>Update</i> button to update order and remove any selected contigs.
        <br/>
        Press <i>Next</i> button to create files for ACT.
        </p>
    };
    printMainForm();
    printJS();
    printReorderCommonJS();

    # hashes  of scaffold oid => ext_accession id
    for ( my $i = 0 ; $i <= $#taxon_oids ; $i++ ) {
        my $toid = $taxon_oids[$i];
        my $taxon_name = taxonOid2Name( $dbh, $toid );
        print "<p> $taxon_name </p>\n";

        #
        # $scaffold_order_aref - order in files
        my ( $taxon_href, $scaffold_order_aref );

        if ( $#orders > -1 ) {

            # this is a reorder
            my $tmp_order_aref = $orders[$i];
            my $tmp_ext_aref   = $ext_accessions[$i];

            # intialize array
            my @tmp_scaffold = ();

            # find order
            # %hash_index - array index => order value
            my %hash_index;
            for ( my $i = 0 ; $i <= $#$tmp_order_aref ; $i++ ) {
                $hash_index{$i} = $tmp_order_aref->[$i];
            }

            # now sort the data in the hash by the value user entered
            my $j = 0;
            foreach my $key (
                              sort { $hash_index{$a} <=> $hash_index{$b} }
                              keys %hash_index
              )
            {

                # key is index of the array order or orderTaxons
                $tmp_scaffold[$j] = $tmp_ext_aref->[$key];
                $j++;
            }
            $scaffold_order_aref = \@tmp_scaffold;
        } else {

            # get order from file
            ( $taxon_href, $scaffold_order_aref ) =
              loadSeqCount("$taxon_fna_dir/$toid.fna");
        }

        my $sdetail_href = getTaxonScaffoldDetail( $dbh, $toid );
        printReorderTable_yui( $scaffold_order_aref, $i, $sdetail_href, $toid );

        print "<br/>\n";
    }

    print hiddenVar( "section",         $section );
    print hiddenVar( "page",            "processACT" );
    print hiddenVar( "myImgOverride",   $myImgOverride );
    print hiddenVar( "imgTermOverride", $imgTermOverride );
    print hiddenVar( "gene_oid_note",   $gene_oid_note );
    print hiddenVar( "from",            "ACT" );

    foreach my $toid (@taxon_oids) {
        print hiddenVar( "taxon_oid", $toid );
    }

    print qq{
        <input type="button" class='smbutton' name="Update"
            value="Update" title="Update order" onclick="javascript:mySubmit('reorder')"/>
    };
    print nbsp(1);
    print qq{
        <input type="button" class='smbutton' name="Next" value="Next"
               onclick="javascript:mySubmit('processACT')"/>
    };
    print end_form();
    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
}

sub getTaxonScaffoldDetail {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = getSingleTaxonScaffoldStatSql();

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $scaffold_name, $ext_accession, $seq_length ) =
          $cur->fetchrow();
        last if !$scaffold_oid;
        $hash{$ext_accession} = "$scaffold_oid\t$scaffold_name\t$seq_length";
    }
    $cur->finish();
    return \%hash;
}

sub printReorderTable {
    my ( $scaffold_order_aref, $order, $sdetail_href, $taxon_oid ) = @_;

    print qq{
        <input  class="smbutton" type='button' onclick="contigSelect(1, $taxon_oid)" value='Select All'/>
    };
    print nbsp(1);
    print qq{
        <input  class="smbutton" type='button' onclick="contigSelect(0, $taxon_oid)" value='Clear All'/>
        <br/>
    };

    # Use YUI css
    if ($yui_tables) {
	print <<YUI;
        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
        <style type="text/css">
	   .txtBox {
	       background-color: white;
	       border: 1px solid #99CCFF;
	   }
	</style>

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Ignore</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Order</span>
	    </div>
	</th>
	<th>
 	    <div class='yui-dt-liner'>
	        <span>Ext Accession</span>
	    </div>
	</th>
	<th>
 	    <div class='yui-dt-liner'>
	        <span>Scaffold Name</span>
	    </div>
	</th>
	<th>
 	    <div class='yui-dt-liner'>
	        <span>Seq. Length</span>
	    </div>
	</th>
YUI
    } else {
	print qq{
            <table class='img'>
            <th class='img'>Ignore</th>
            <th class='img'>Order</th>
            <th class='img'>Ext Accession</th>
            <th class='img'>Scaffold Name</th>
            <th class='img'>Seq. Length</th>
        };
    }

    my $rowcnt = 1;
    foreach my $sid (@$scaffold_order_aref) {
        my $ignoreid = $sid . "_" . $taxon_oid;    # ext acc _ taxon oid

        my $line = $sdetail_href->{$sid};
        my ( $scaffold_oid, $scaffold_name, $seq_length ) =
	    split( /\t/, $line );
	my $classStr;

	if ($yui_tables) {
	    $classStr = !$rowcnt ? "yui-dt-first ":"";
	    $classStr .= ($rowcnt % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
	} else {
	    $classStr = "img";
	}

	print "<tr class='$classStr'>\n";

	# Ignore
	print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>" if $yui_tables;
	print "<input type='checkbox' name='ignore' value='$ignoreid' />";
	print "</div>\n" if $yui_tables;
	print "</td>\n";

	# Order
	print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>" if $yui_tables;
	print "<input type='text' onKeyPress='return numbersonly(event)' size='4'
               name='order$order' value='$rowcnt' class='txtBox' />";
	print "</div>\n" if $yui_tables;
	print "</td>\n";

	# Ext Accession
	print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>" if $yui_tables;
	print "<input type='text' name='ext_accession$order' value='$sid'
               readonly='readonly' class='txtBox' />";
	print "</div>\n" if $yui_tables;
	print "</td>\n";

	# Scaffold Name
	print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>" if $yui_tables;
	print $scaffold_name;
	print "</div>\n" if $yui_tables;
	print "</td>\n";

	# Seq. Length
	print "<td class='$classStr'>\n";
	print "<div class='yui-dt-liner'>" if $yui_tables;
	print $seq_length;
	print "</div>\n" if $yui_tables;
	print "</td>\n";

	print "</tr>\n";
        $rowcnt++;
    }

    print "</table>";
    print "</div>\n" if $yui_tables;
}

sub printReorderTable_yui {
    my ( $scaffold_order_aref, $order, $sdetail_href, $taxon_oid ) = @_;

    print "<div id='datatable$order'></div>";
    print "<script language='javascript' type='text/javascript'>\n";
    print "YAHOO.example.genomes$order = [\n";

    my $rowcnt = 1;
    foreach my $sid (@$scaffold_order_aref) {
        my $ignoreid = $sid . "_" . $taxon_oid;    # ext acc _ taxon oid

        my $line = $sdetail_href->{$sid};
        my ( $scaffold_oid, $scaffold_name, $seq_length ) =
          split( /\t/, $line );

        print qq{
            {ignore:"<input type='checkbox' name='ignore' value='$ignoreid' />",
             ext_accession:"<input type='text' name='ext_accession$order' value='$sid' readonly='readonly' style='background-color:white'/> ",
             scaffold_name: "$scaffold_name",
             seq_length: "$seq_length" }
        };

        print ",\n" if ( $rowcnt <= $#$scaffold_order_aref );

        $rowcnt++;
    }

    #print "</table>";
    print "];\n";

    datatableReorder( "datatable$order", $order );
    print "</script>\n";
}

sub printReorderCommonJS {
    print <<EOF;
<script language="javascript" type="text/javascript">

// Override the built-in formatter
YAHOO.widget.DataTable.formatCheckbox = function(elLiner, oRecord, oColumn, oData) {
              elLiner.innerHTML =  oData;
};


</script>
EOF

}

sub datatableReorder {
    my ( $datatable_div, $order ) = @_;

    print <<EOF;

function foo$order() {
    YAHOO.example.ReorderRows$order = function() {

var rowNumbering$order = function(elCell, oRecord, oColumn) {
    var i = this.getRecordIndex(oRecord) + 1;
    var t = "<input type='text' size='4' readonly='readonly' name='order$order' value='"
            + i + "'>"
    elCell.innerHTML = t;
};
YAHOO.widget.DataTable.Formatter.myCustom$order = rowNumbering$order;


var myColumnDefs = [
                {
                    key : "ignore",
                    label : "Ignore",
                    sortable : false
                },
                {
                    key : "order",
                    label : "Order",
                    sortable : false,
                    formatter : "myCustom$order"
                }, {
                    key : "ext_accession",
                    label : "Ext Accession",
                    sortable : true,
                    formatter : "Textbox"
                }, {
                    key : "scaffold_name",
                    label : "Scaffold Name",
                    sortable : true
                }, {
                    key : "seq_length",
                    label : "Seq. Length",
                    sortable : true
                }];


        var Dom = YAHOO.util.Dom, Event = YAHOO.util.Event, DDM = YAHOO.util.DragDropMgr;

        var myDataSource = new YAHOO.util.LocalDataSource(
                YAHOO.example.genomes$order, {
                    responseSchema : {
                        fields : [ "ignore","ext_accession", "scaffold_name", "seq_length" ]
                    }
                });
        var myDataTable = new YAHOO.widget.DataTable(
                "datatable$order", myColumnDefs, myDataSource, {
                    caption : "YUI Datatable/DragDrop",
                    paginator : new YAHOO.widget.Paginator( {
                        rowsPerPage : 5000,
                        alwaysVisible : false
                    }),
                    width : "90%",
                    draggableColumns : false
                });
        var dragger = myDataTable;
        myDTDrags$order = {};

        // ////////////////////////////////////////////////////////////////////////////
        // Custom drag and drop class
        // ////////////////////////////////////////////////////////////////////////////
        YAHOO.example.DDRows$order = function(id, sGroup, config) {
            YAHOO.example.DDRows$order.superclass.constructor.call(
                    this, id, sGroup, config);
            Dom.addClass(this.getDragEl(), "custom-class");
            this.goingUp = false;
            this.lastY = 0;
        };

        // ////////////////////////////////////////////////////////////////////////////
        // DDRows extends DDProxy
        // ////////////////////////////////////////////////////////////////////////////
        YAHOO
                .extend(
                        YAHOO.example.DDRows$order,
                        YAHOO.util.DDProxy,
                        {
                            proxyEl : null,
                            srcEl : null,
                            srcData : null,
                            srcIndex : null,
                            tmpIndex : null,

                            startDrag : function(x, y) {
                                var proxyEl = this.proxyEl = this
                                        .getDragEl(), srcEl = this.srcEl = this
                                        .getEl();

                                this.srcData = myDataTable
                                        .getRecord(this.srcEl)
                                        .getData();
                                this.srcIndex = srcEl.sectionRowIndex;
                                // Make the proxy look like the
                                // source element
                                Dom.setStyle(srcEl,
                                        "visibility", "hidden");
                                proxyEl.innerHTML = "<table><tbody>"
                                        + srcEl.innerHTML
                                        + "</tbody></table>";
                            },

                            endDrag : function(x, y) {
                                var position, srcEl = this.srcEl;

                                Dom.setStyle(this.proxyEl,
                                        "visibility", "hidden");
                                Dom.setStyle(srcEl,
                                        "visibility", "");
                            },

                            onDrag : function(e) {
                                // Keep track of the direction of the drag for use during onDragOver
                            var y = Event.getPageY(e);

                            if (y < this.lastY) {
                                this.goingUp = true;
                            } else if (y > this.lastY) {
                                this.goingUp = false;
                            }

                            this.lastY = y;
                        },

                        onDragOver : function(e, id) {
                            // Reorder rows as user drags
                            var srcIndex = this.srcIndex, destEl = Dom
                                    .get(id), destIndex = destEl.sectionRowIndex, tmpIndex = this.tmpIndex;

                            if (destEl.nodeName.toLowerCase() === "tr") {
                                if (tmpIndex !== null) {
                                    myDataTable
                                            .deleteRow(tmpIndex);
                                } else {
                                    myDataTable
                                            .deleteRow(this.srcIndex);
                                }

                                myDataTable
                                        .addRow(this.srcData,
                                                destIndex);
                                this.tmpIndex = destIndex;

                                DDM.refreshCache();
                            }
                        }
                        });

        // ////////////////////////////////////////////////////////////////////////////
        // Create DDRows instances when DataTable is initialized
        // ////////////////////////////////////////////////////////////////////////////
        myDataTable.subscribe("initEvent", function() {
            var i, id, allRows = this.getTbodyEl().rows;

            for (i = 0; i < allRows.length; i++) {
                id = allRows[i].id;
                // Clean up any existing Drag instances
                if (myDTDrags${order}[id]) {
                    myDTDrags${order}[id].unreg();
                    delete myDTDrags${order}[id];
                }
                // Create a Drag instance for each row
                myDTDrags${order}[id] = new YAHOO.example.DDRows$order(id);
            }
        });

        // ////////////////////////////////////////////////////////////////////////////
        // Create DDRows instances when new row is added
        // ////////////////////////////////////////////////////////////////////////////
        myDataTable.subscribe("rowAddEvent", function(e) {
            var id = e.record.getId();
            myDTDrags${order}[id] = new YAHOO.example.DDRows$order(id);
        })

        function initDragDrop() {
            var i, id, allRows = this.getTbodyEl().rows;

            for (i = 0; i < allRows.length; i++) {
                id = allRows[i].id;
                // Clean up any existing Drag instances
                if (myDTDrags${order}[id]) {
                    myDTDrags${order}[id].unreg();
                    delete myDTDrags${order}[id];
                }
                // Create a Drag instance for each row
                myDTDrags${order}[id] = new YAHOO.example.DDRows$order(id);
            }
        }

        myDataTable.subscribe("cellUpdateEvent", initDragDrop);
        myDataTable.subscribe("columnSortEvent", initDragDrop);
        myDataTable.subscribe("initEvent", initDragDrop);
        myDataTable.subscribe("renderEvent", initDragDrop);

        myDataTable.subscribe("checkboxClickEvent", function(oArgs){
                 var elCheckbox = oArgs.target;
                 var oRecord = this.getRecord(elCheckbox);

                 var checked = "";
                 if(elCheckbox.checked) {
                     checked = "checked='checked'";
                 }

                 var value = elCheckbox.value;
                 var text = "<input type='checkbox' name='ignore' value='" + value + "' " + checked +  "/>"

                 oRecord.setData("ignore",text);
           });

    }();
}

YAHOO.util.Event.addListener(window,"load", foo$order());


EOF

}

# taxon oid
# list of ext_access ids
# list of ext_access_taxon_oid to ignore
# return aref list of ext_access
sub ignoreExtaccession {
    my($taxon_oid, $ext_accession_aref, $ignore_aref) = @_;

    my @array;
    for(my $i=0; $i <= $#$ext_accession_aref; $i++) {
        my $id = $ext_accession_aref->[$i] . "_" . $taxon_oid;
        my $found = 0;
        foreach my $ignore (@$ignore_aref) {
            if($id eq $ignore) {
                $found = 1;
                last;
            }
        }
        if(!$found) {
            push(@array, $ext_accession_aref->[$i]);
        }
    }

    return \@array;
}

# process data for ACT
sub processACT {
    my @taxon_oids = param("taxon_oid");

    my $myImgOverride   = param("myImgOverride");
    my $imgTermOverride = param("imgTermOverride");
    my $gene_oid_note   = param("gene_oid_note");
    # user select some to ignore - no update button pressed
    my @ignore          = param("ignore");

    # array of arrays of list of orders
    my @orders;
    my @ext_accessions;
    my @filter_ext_accessions;
    for ( my $i = 0 ; $i <= $#taxon_oids ; $i++ ) {
        my @tmp_order         = param("order$i");
        my @tmp_ext_accession = param("ext_accession$i");

        push( @orders, \@tmp_order ) if ( $#tmp_order > -1 );
        push( @ext_accessions, \@tmp_ext_accession )
          if ( $#tmp_ext_accession > -1 );

        my $aref = ignoreExtaccession($taxon_oids[$i],\@tmp_ext_accession,\@ignore);
        push(@filter_ext_accessions, $aref);

    }
    if ($USE_YUI) {
        print Dumper \@orders;
        print "<br/>";
        print Dumper \@ext_accessions;
        print "<br/>";
        print Dumper \@filter_ext_accessions;
        WebUtil::webExit(0);
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $sid = getSessionId();

    WebUtil::printHeaderWithInfo
	("Artemis - ACT", getActCitation(),
	 "show citation", "ACT Info");

    printStartWorkingDiv();

    # array of hashes  of scaffold oid => ext_accession id
    my @scaffolds;

    # array of hashes 'NC_010369' => '1,194963'
    my @taxon_coords;
    my @fnafilenames;     # tmp seq file names - reorder
    my @genebankfiles;    # all genbank files
    for ( my $i = 0 ; $i <= $#taxon_oids ; $i++ ) {
        my $toid = $taxon_oids[$i];
        print "Getting $toid scaffolds<br/>\n";
        my $scaffold_href = QueryUtil::fetchSingleTaxonScaffolds( $dbh, $toid );
        push( @scaffolds, $scaffold_href );

        my $ext_order_aref = $ext_accessions[$i];

        my ( $taxon_href, $filename ) =
          loadSeqCount2( "$taxon_fna_dir/$toid.fna", $toid, $ext_order_aref );
        push( @taxon_coords, $taxon_href );
        push( @fnafilenames, $filename );

        my $file    = "act" . $toid . "_" . "$$" . "_" . $sid . ".gbk";
        my $outFile = "$tmp_dir/$file";

        print "create genbank file $outFile <br/>\n";

        createGenBankFile(
                           $dbh,            $toid,
                           $ext_order_aref, $scaffold_href,
                           $taxon_href,     $outFile,
                           $myImgOverride,  $imgTermOverride,
                           $gene_oid_note
        );
        push( @genebankfiles, $file );
    }

    # TODO - create tmp fna files with contigs reordered

# read seq file to get all the contigs start and stop
# hash of
# '>NC_010369 Halobacterium salinarum R1 plasmid PHS2, complete sequence.' => '1,194963'
# 'NC_010369' => '1,194963'
# NC_010369 = ext_accession
# 1,194963 = start, and end coord
#
# 2nd return param
# array of ext_accession ids - used as the order the scaffols cat.

    # create one big fna files  without > s line
    my @mbalstfiles;
    for ( my $i = 0 ; $i < $#fnafilenames ; $i++ ) {
        my $seqFile1      = $fnafilenames[$i];
        my $seqFile2      = $fnafilenames[ $i + 1 ];
        my $mblastoutfile = "mblast$$" . "_" . $i . "_" . $sid;
        print "create mblast $mblastoutfile <br/>\n";
        runMegaBlast( "$tmp_dir/$seqFile1", "$tmp_dir/$seqFile2",
                      $mblastoutfile );
        push( @mbalstfiles, $mblastoutfile );
    }

    printEndWorkingDiv();

    # print links to ACT input files
    # Use YUI css

    if ($yui_tables) {
	print <<YUI;

        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
	    <style type="text/css">
	        .yui-skin-sam .yui-dt td {
		border-bottom-color: #CBCBCB;
		border-bottom-style: solid;
		border-bottom-width: 1px;
	   }
	</style>

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>ACT Data Files</span>
	    </div>
	</th>
YUI
    } else {
	print qq{
          <table class='img'>
          <th class='img'>ACT Data Files</th>
        }
    };

    for ( my $i = 0 ; $i < $#fnafilenames ; $i++ ) {
        my $file1  = $fnafilenames[$i];
        my $file2  = $fnafilenames[ $i + 1 ];
        my $gfile1 = $genebankfiles[$i];
        my $gfile2 = $genebankfiles[ $i + 1 ];

        my $toid1 = $taxon_oids[$i];
        my $toid2 = $taxon_oids[ $i + 1 ];
        my $mfile = $mbalstfiles[$i];

	my $classStr;
	if ($yui_tables) {
	    $classStr = !$i ? "yui-dt-first ":"";
	    $classStr .= ($i % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";
	} else {
	    $classStr = "img";
	}

	print "<tr class='$classStr'>\n";
	print "<td class='$classStr customCell'>\n";
	print "<div class='yui-dt-liner'>" if $yui_tables;
        print qq{
            <a href='$tmp_url/$file1'> $toid1 fna file </a> <br/>
            <a href='$tmp_url/$file2'> $toid2 fna file </a> <br/>
            <a href='$tmp_url/$gfile1'> $toid1 GBK file </a> <br/>
            <a href='$tmp_url/$gfile2'> $toid2 GBK file </a> <br/>
            <a href='$tmp_url/$mfile'> Megablast out file </a>
        };
	print "</div>\n" if $yui_tables;
	print "</td>\n";
	print "</tr>\n";
    }
    print "</table>";
    print "</div>\n" if $yui_tables;

    # create jnlp file
    my $file = printACTWebStart( \@genebankfiles, \@mbalstfiles );

    print qq{
        <p>
        <input class='smdefbutton' type='button' value="Run ACT"
        onclick="window.location.href='$tmp_url/$file'">
        </p>
    };

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
}

sub getActCitation {
    return "<b>ACT: the Artemis Comparison Tool.</b><br/><i>Carver TJ, Rutherford KM, Berriman M, Rajandream MA, Barrell BG, Parkhill J</i><br/>Bioinformatics. 2005;21;3422-3. PMID: <a href=http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&list_uids=15976072&dopt=Abstract target=external>15976072</a> DOI: <a href=http://dx.doi.org/10.1093/bioinformatics/bti553>10.1093/bioinformatics/bti553</a><br/>";
}

# $scaffold_order_aref - array of ext accession
# $scaffold_href - hashes of scaffold oid => ext_accession id
# $taxon_href - 'NC_010369' => '1,194963'
sub createGenBankFile {
    my (
         $dbh,           $taxon_oid,       $scaffold_order_aref,
         $scaffold_href, $taxon_href,      $outFile,
         $myImgOverride, $imgTermOverride, $gene_oid_note
      )
      = @_;

    my $total_basepair = 0;
    foreach my $ext ( keys %$taxon_href ) {
        my $line = $taxon_href->{$ext};
        my ( $start, $end ) = split( /,/, $line );
        $total_basepair += $end;
    }

    my $wfh = newWriteFileHandle( $outFile, "writeScaffold2GenBankFile" );

    my $scaffold_oid =
      getScaffoldOid( $scaffold_order_aref->[0], $scaffold_href );
    #print "createGenBankFile scaffold: $scaffold_oid for " . $scaffold_order_aref->[0] . "<br/>\n";

    # create genbank header
    GenBankFile::writeScaffold2GenBankFile_act_header( $dbh, $wfh,
                      $scaffold_oid, $outFile, $myImgOverride, $imgTermOverride,
                      $gene_oid_note, $total_basepair );

    # create gene section
    my $offset = 0;
    foreach my $ext_accesstion (@$scaffold_order_aref) {
        #print "createGenBankFile ext_accesstion: $ext_accesstion<br/>\n";
        my $scaffold_oid = getScaffoldOid( $ext_accesstion, $scaffold_href );
        #print "createGenBankFile scaffold: $scaffold_oid<br/>\n";
        my $line = $taxon_href->{$ext_accesstion};
        #print "createGenBankFile line: $line<br/>\n";
        my ( $start, $end ) = split( /,/, $line );
        print "Creating gbk for scaffold $scaffold_oid "
          . "$ext_accesstion $start, $end <br/>\n";
        GenBankFile::writeScaffold2GenBankFile_act( $dbh, $wfh, $scaffold_oid,
                     $outFile, $myImgOverride, $imgTermOverride, $gene_oid_note,
                     $offset );
        $offset = $offset + $end;
    }

    # create genbank footer
    GenBankFile::writeScaffold2GenBankFile_act_footer( $dbh, $wfh, $taxon_oid,
                                        $scaffold_order_aref, $total_basepair );
    close $wfh;

}

sub getScaffoldOid {
    my ( $ext_accession, $scaffold_href ) = @_;
    my $id = "";

    foreach my $key ( keys %$scaffold_href ) {
        my $ext = $scaffold_href->{$key};
        if ( $ext_accession eq $ext ) {
            $id = $key;
            last;
        }
    }

    return $id;
}

sub printACTformTest {

    print "<h1> ACT test Java web start</h1>\n";

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();

    print "TODO create gen bank file 1 <br/>\n";
    print "TODO create gen bank file 2 <br/>\n";
    print "TODO create comparison file using megablast <br/>\n";

    # Create data files in tmp dir too now
    # data must be static
    my $data_url  = "http://merced.jgi-psf.org/klchu/artemis/";
    my $data_url1 = $data_url . "AE002098.gbk";
    my $data_url2 = $data_url . "NmA_v_B_crunch_200";
    my $data_url3 = $data_url . "Nm.art";

    # create jnlp file
    my $file = printACTWebStart( $data_url1, $data_url2, $data_url3 );

    # testing
    #printEndWorkingDiv();
    print qq{
       </p>
       </div>
    };

    print qq{


        <p>
        this uses 3 example data files from <a href="http://www.sanger.ac.uk/Software/ACT/Examples/">Sanger</a>
        <br/>
        <a href='$tmp_url/$file'> Run ACT </a>
        </p>

        <p>
<table border="0">
<tr >
<td c><b>ACT: the Artemis Comparison Tool.</b><br /> <i>Carver TJ,
Rutherford KM, Berriman M, Rajandream MA, Barrell BG, Parkhill J</i>
<br />Bioinformatics. 2005;21;3422-3. PMID:
<a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&list_uids=15976072&dopt=Abstract" target="external">15976072</a>
DOI: <a href="http://dx.doi.org/10.1093/bioinformatics/bti553">10.1093/bioinformatics/bti553</a>
<br />
</td></tr>
</table>
        </p>
    };

    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printArtemisForm - Print form for generating GenBank file.
############################################################################
sub printArtemisForm {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();

    print "<h1>Web Artemis</h1>\n";
    print "<p>\n";
    webError("Unable to determine Taxon ID. Please use <b>Find Genomes</b> above
             and select a genome.\n") if $taxon_oid eq "";
    print "<p>\n";
    print "Please select one scaffold to view.<br/>\n";
    print "</p>\n";
    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<table class='img' border='1'>\n";

    ## Scaffold selection
    print "<tr class='img'>\n";
    print "<th class='subhead'>Scaffold</th>\n";
    print "<td class='img'>\n";
    print "<select name='scaffold_oid' size='10'>\n";

    my $sql = getSingleTaxonScaffoldStatSql();
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $count = 0;
    my $trunc = 0;
    for ( ; ; ) {
        my ( $scaffold_oid, $scaffold_name, $ext_accession, $seq_length ) =
          $cur->fetchrow();
        last if !$scaffold_oid;
        $count++;
        if ( $count > $max_export_scaffold_list ) {
            $trunc = 1;
            last;
        }
        print "<option value='$scaffold_oid'>";
        print escHtml("$ext_accession - $scaffold_name (${seq_length}bp)");
        print "</option>\n";
    }
    print "</select>\n";
    $cur->finish();
    print "</td>\n";
    print "</tr>\n";

    ## IMG Term
    if ($include_img_terms) {
        print "<tr class='img'>\n";
        print "<th class='subhead'>IMG Term</th>\n";
        print "<td class='img'>\n";
        print "<input type='checkbox' name='imgTermOverride' />";
        print "Override product name with IMG term.";
        print "</td>\n";
    }
    print hiddenVar( "format", "embl" );

    print "</table>\n";
    if ($trunc) {
        print "<p>\n";
        print "<font color='red'>\n";
        print escHtml(   "Scaffold list truncated to "
                       . "$max_export_scaffold_list scaffolds." )
          . "<br/>\n";
        print "</font>\n";
        print "</p>\n";
    }

    print "<br/>\n";
    my $name = "_section_${section}_processArtemisFile";
    print submit(
                  -name  => $name,
                  -value => "Go",
                  -class => "smdefbutton"
    );
    print nbsp(1);
    print reset( -value => "Reset", -class => "smbutton" );

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    printHint(   "Hold down control key (or command key in the case "
               . "of the Mac)<br/>to select or deselect multiple values."
               . "Drag down the list to select many items.<br/>" );
    print end_form();
}

############################################################################
# printProcessArtemisFile - Process generating an Artemis file,
#   which now is synonymous with generating an output for Genbank
#   or EMBL format.
############################################################################
sub processArtemisFile {
    my $format          = param("format");
    my $myImgOverride   = 0;
    my $imgTermOverride = 0;
    my $gene_oid_note   = 1;

    print "<h1>Web Artemis</h1>\n";
    my $scaffold_oid = param("scaffold_oid");
    if ( $scaffold_oid eq "" ) {
        webError("Please select one scaffold.\n");
    }
    require EmblFile;
    my $outFile = "$tmp_dir/$$.art";
    webLog("processArtemisFile: write '$outFile'\n")
      if $verbose >= 1;
    printMainForm();
    printStatusLine( "Loading ...", 1 );
    EmblFile::writeScaffold2EmblFile(
                                      $scaffold_oid,  $outFile,
                                      $myImgOverride, $imgTermOverride,
                                      $gene_oid_note
    );
    printStatusLine( "Loaded.", 2 );

    my $archive = "$base_url/powmap.jar";
    my $dataUrl = "$base_url/tmp/$$.art";
    my $s       = qq{
      <applet code='DianaApplet.class' archive='$archive'
        width='600' height='300'>
       <param name='entries' value='$$.art'>
       If you are reading this it means your web browser
       doesn't support java or you
       have java disabled.
       <p>
       Artemis on the web needs a web browser that supports java 1.1
       <p>
       Suitable browsers include Netscape Navigator version 4.06 or better and
       Microsoft Internet Explorer version 4 or better.
       <p>
       You might like to try the standalone version of Artemis instead.
       Go to <a href="http://www.sanger.ac.uk/Software/Artemis">
       Sanger</a> for more information.
       </applet>
   };

    #wunlink( $outFile );
    my $artemisUrl  = "$tmp_url/artemis$$.html";
    my $artemisFile = "$tmp_dir/artemis$$.html";
    my $wfh         = newWriteFileHandle( $artemisFile, "processArtemisFile" );
    print $wfh "<html>\n";
    print $wfh "<head>\n";
    print $wfh "<title>Artemis on the Web</title>\n";
    print $wfh "</head>\n";
    print $wfh "<body>\n";
    print $wfh "$s\n";
    close $wfh;
    print buttonUrl( $artemisUrl, "View Results", "medbutton" );
    print end_form();
}

# gets contig name => 1,end coord
sub loadSeqCount {
    my ($inFile) = @_;

    my %hash;
    my @scaffold_order;
    my $lastname   = "";
    my $char_count = 0;

    my $seq;
    my $rfh = newReadFileHandle( $inFile, "tool:loadSeq" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        next if blankStr($s);
        if ( $s =~ /^>/ ) {
            $s =~ s/^>//;
            my @tmp = split( /\s+/, $s );
            push( @scaffold_order, $tmp[0] );

          # there is one extra hash entry where the key is "" and can be ignored
            $hash{$lastname} = "1,$char_count" if ( $lastname ne "" );
            $lastname        = $tmp[0];
            $char_count      = 0;
            next;
        }
        $char_count += length($s);
    }
    close $rfh;

    $hash{$lastname} = "1,$char_count";

    return ( \%hash, \@scaffold_order );
}

# load seq in the correct order and create a new temp fna file
sub loadSeqCount2 {
    my ( $inFile, $taxon_oid, $ext_order_aref ) = @_;

    my %hash;
    my %seq_hash;    # ext => seq
    my $lastname = "";

    my $rfh = newReadFileHandle( $inFile, "tool:loadSeq" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        next if blankStr($s);
        if ( $s =~ /^>/ ) {
            $s =~ s/^>//;
            my @tmp = split( /\s+/, $s );
            $lastname = $tmp[0];
            next;
        }
        $seq_hash{$lastname} .= "$s";
    }
    close $rfh;

    # now create new tmp fna file
    my $sid      = getSessionId();
    my $filename = $taxon_oid . $sid . ".fna";
    my $wfh = newWriteFileHandle( "$tmp_dir/$filename", "create tmp fna file" );

    #    foreach my $ext (@$ext_order_aref) {
    #        my $seq = $seq_hash{$ext};
    #        $hash{$ext} = "1," . length($seq);
    #        $seq = wrapSeq( $seq, 60 );
    #        print $wfh ">$ext\n";
    #        print $wfh $seq;
    #    }

    # bug megablast want one big sequence file without > line
    foreach my $ext (@$ext_order_aref) {
        my $seq = $seq_hash{$ext};
        $hash{$ext} = "1," . length($seq);
        $seq = wrapSeq( $seq, 60 );
        print $wfh $seq;
    }

    close $wfh;

    return ( \%hash, $filename );
}

sub runMegaBlast {
    my ( $inFile1, $inFile2, $outFile ) = @_;

    #print ">>> Load sequence from '$inFile1'<br/>\n";
    #my $seq1 = loadSeq($inFile1);
    print ">>> Load sequence from '$inFile2'<br/>\n";
    my $seq2 = loadSeq($inFile2);

    print ">>> Make BLAST db from '$inFile2'<br/>\n";

    # untaint
    if ( $inFile1 =~ /^(.*)$/ ) { $inFile1 = $1; }
    if ( $inFile2 =~ /^(.*)$/ ) { $inFile2 = $1; }

    my $dbName2 = fileRoot($inFile2);
    my $tmpDir  = "$tmp_dir";
    my $db2     = makeBlastDb( $seq2, $tmpDir, $dbName2 );

    print "<br/> >>> Run megablast <br/>\n";

    runCmd("$megablast_bin -i $inFile1 -d $db2 -m 8 -F F -o $tmp_dir/$outFile");
}

############################################################################
# loadSeq - Load new sequence.  Concatenate contigs.
############################################################################
sub loadSeq {
    my ($inFile) = @_;

    my $seq;
    my $rfh = newReadFileHandle( $inFile, "tool:loadSeq" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        next if blankStr($s);
        next if $s =~ /^>/;
        $s =~ s/\s+//g;
        $seq .= $s;
    }
    close $rfh;
    return $seq;
}

############################################################################
# makeBlastDb - Make blast database.
############################################################################
sub makeBlastDb {
    my ( $seq, $tmpDir, $dbName ) = @_;

    chdir($tmpDir);

    my $sid   = getSessionId();
    my $fpath = "$tmpDir/$dbName" . "_" . "$$" . "_" . $sid . ".fna";

    my $wfh = newWriteFileHandle( $fpath, "tool:makeBlastDb" );
    print $wfh ">$dbName\n";
    my $seq2 = wrapSeq($seq);
    print $wfh "$seq2\n";
    close $wfh;

    runCmd("$formatdb_bin -i $fpath -o T -p F");
    runCmd("$fastacmd_bin -d $fpath -I");

    return $fpath;
}

sub getSingleTaxonScaffoldStatSql {

    my $rclause = WebUtil::urClause("s.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    my $sql = qq{
        select s.scaffold_oid, s.scaffold_name, s.ext_accession, ss.seq_length
        from scaffold s, scaffold_stats ss
        where s.taxon = ?
        and s.taxon = ss.taxon
        and s.scaffold_oid = ss.scaffold_oid
        $rclause
        $imgClause
        order by ss.seq_length desc, s.ext_accession
    };

    return $sql;
}

1;
