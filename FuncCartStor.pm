############################################################################
# Functional cart.  This is a generalization of the COG, KOG, Pfam, enzyme,
#  ... carts.
#  Record fields (tab delimited separator):
#     0: func_id
#     1: func_name
#     2: batch_id
#    --es 01/06/2007
# $Id: FuncCartStor.pm 33902 2015-08-05 01:24:06Z jinghuahuang $
############################################################################
package FuncCartStor;
my $section = "FuncCartStor";

use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;
use DataEntryUtil;
use InnerTable;
use OracleUtil;
use GenomeListFilter;
use MerFsUtil;
use QueryUtil;
use WorkspaceUtil;
use CartUtil;
use FuncUtil;
use GenomeListJSON;
use HtmlUtil;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $base_dir              = $env->{base_dir};
my $base_url              = $env->{base_url};
my $cgi_tmp_dir           = $env->{cgi_tmp_dir};
my $img_internal          = $env->{img_internal};
my $img_lite              = $env->{img_lite};
my $include_metagenomes   = $env->{include_metagenomes};
my $show_private          = $env->{show_private};
my $go_base_url           = $env->{go_base_url};
my $cog_base_url          = $env->{cog_base_url};
my $kog_base_url          = $env->{kog_base_url};
my $pfam_base_url         = $env->{pfam_base_url};
my $tigrfam_base_url      = $env->{tigrfam_base_url};
my $ipr_base_url          = $env->{ipr_base_url};
my $enzyme_base_url       = $env->{enzyme_base_url};
my $tc_base_url           = "http://www.tcdb.org/search/result.php?tc=";
my $kegg_orthology_url    = $env->{kegg_orthology_url};
my $user_restricted_site  = $env->{user_restricted_site};
my $enable_genomelistJson = $env->{enable_genomelistJson};
my $YUI                   = $env->{yui_dir_28};
my $img_ken               = $env->{img_ken};
my $enable_biocluster     = $env->{enable_biocluster};

my $in_file      = $env->{in_file};
my $mer_data_dir = $env->{mer_data_dir};

# tab panel redirect
my $tab_panel    = $env->{tab_panel};
my $content_list = $env->{content_list};

my $verbose = $env->{verbose};

my $max_genome_selections  = 500;
my $max_pathway_selections = 50;
my $max_func_batch         = 900;
my $max_taxon_batch        = 900;
my $maxProfileOccurIds     = 300;

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 30;
}

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {

    timeout( 60 * $merfs_timeout_mins );
    my $page = param("page");

    if (    $page eq "funcCart"
         || paramMatch("addIpwayToFuncCart")    ne ""
         || paramMatch("addMetaCycToFuncCart")    ne ""
         || paramMatch("addToFuncCart")           ne ""
         || paramMatch("deleteSelectedCartFuncs") ne "" )
    {
        setSessionParam( "lastCart", "funcCart" );
        my $fc = new FuncCartStor();
        $fc->webRemoveFuncs()
          if paramMatch("deleteSelectedCartFuncs") ne "";
        my $load;
        if ( paramMatch("addIpwayToFuncCart") ne "" ) {
            param( -name => "only_func", -value => "IPWAY" );
            $load = "add";
        }
        elsif ( paramMatch("addMetaCycToFuncCart") ne "" ) {
            param( -name => "only_func", -value => "MetaCyc" );
            $load = "add";
        }
        elsif ( paramMatch("addToFuncCart") ne "" ) {
            $load = "add";
        }
        $fc->printFuncCartForm($load);
    } elsif ( $page eq "upload" ) {
        my $fc = new FuncCartStor();
        $fc->printTab2();
    } elsif ( $page eq "tools" ) {
        my $fc = new FuncCartStor();
        $fc->printTab3();
    } elsif ( $page eq "allGenes" ) {
        my $fc = new FuncCartStor();
        $fc->printAllGenes();
    } elsif ( paramMatch("showFuncCartProfile_s") ne "" ) {
        my $fc = new FuncCartStor();
        $fc->printFuncCartProfile_s();
    } elsif ( paramMatch("showFuncCartProfile_t") ne "" ) {
        my $fc = new FuncCartStor();
        $fc->printFuncCartProfile_t();
    } elsif ( paramMatch("showPwayAssertionProfile_s") ne "" ) {
        my $fc = new FuncCartStor();
        $fc->printPwayAssertionProfile_s();
    } elsif ( paramMatch("showPwayAssertionProfile_t") ne "" ) {
        my $fc = new FuncCartStor();
        $fc->printPwayAssertionProfile_t();
    } elsif ( paramMatch("funcOccurProfiles") ne "" ) {
        printPhyloOccurProfiles();
    } elsif ( paramMatch("exportFunctions") ne "" ) {
        my $fc = new FuncCartStor();
        $fc->printExportFuncCart();
    } elsif ( paramMatch("uploadFuncCart") ne "" ) {
        my $fc = new FuncCartStor();
        $fc->printFuncCartForm("upload");
    } elsif ( paramMatch("printUploadFuncCartForm") ne "" ) {
        printUploadFuncCartForm();
    } elsif ( paramMatch("addGeneCart") ne "" ) {
        require CartUtil;
        if ( $enable_genomelistJson ) {
            CartUtil::addFuncGenesToGeneCart(1, 'genomeFilterSelections');
        } else {
            CartUtil::addFuncGenesToGeneCart(1);
        }
    } else {
        my $fc = new FuncCartStor();
        $fc->printFuncCartForm();
    }
}

##############################################################
# printFunctionTable - prints the table of functions
##############################################################
sub printFunctionTable {
    my ($self) = @_;
    printJavaScript();
    setSessionParam( "lastCart", "funcCart" );

    my $recs     = $self->{recs};
    my @func_ids = sort( keys(%$recs) );
    my $count    = @func_ids;

    print "<h2>Function List</h2>";
    if ( $count > 0 ) {
    	print "<p>$count function(s) in cart</p>\n";
    	printFuncCartButtons() if $count > 10;
    	$self->printTableList();
    	printFuncCartButtons();

    	print "<p>\n";
    	print "1 - Each time a set of functions is added to the cart, "
    	    . "a new batch number is generated for the set.<br/>\n";
    	print "</p>\n";
    } else {
        printStatusLine( "0 functions in cart", 2 );
        print "<p>0 functions in cart. You need to select / upload functions "
	    . "into the cart.</p>\n";
    }
}

sub printUploadSection {
    print "<h2>Upload Function Cart</h2>";
    printUploadFuncCartFormContent('Yes');
}

sub printFnValidationJS {
    print qq{
        <script language='JavaScript' type='text/javascript'>
        function validateFnSelection(num) {
            var startElement = document.getElementById("funccarttab1");
            var els = startElement.getElementsByTagName('input');

            var count = 0;
            for (var i = 0; i < els.length; i++) {
                var e = els[i];

                if (e.type == "checkbox" &&
                    e.name == "func_id" &&
                    e.checked == true) {
                    count++;
                }
            }

            if (count < num) {
                if (num == 1) {
                    alert("Please select some functions");
                } else {
                    alert("Please select at least "+num+" functions");
                }
                return false;
            }

            return true;
        }

        function validateKeggFnSelection(num) {
            var startElement = document.getElementById("funccarttab1");
            var els = startElement.getElementsByTagName('input');

            var count = 0;
            for (var i = 0; i < els.length; i++) {
                var e = els[i];

                var func = e.value;
                if (e.type == "checkbox" &&
                    e.name == "func_id" &&
                    e.checked == true) {
                    if ( func.startsWith("KO:") ||
                         func.startsWith("EC:") ) {
                        count++;
                        //alert("selected fn: "+e.value);
                    }
                }
            }

            if (count < num) {
                if (num == 1) {
                    alert("Please select some KO or EC functions");
                } else {
                    alert("Please select at least "+num+" KO or EC functions");
                }
                return false;
            }

            return true;
        }
        </script>
    };
}

############################################################################
# printTab2 - Upload & Export
############################################################################
sub printTab2 {
    my ($self) = @_;

    setSessionParam( "lastCart", "funcCart" );
    printUploadSection();

    print "<h2>Export Functions</h2>";
    print "<p>\n";
    print "You may select functions from the cart to export.";
    print "</p>\n";

    my $recs     = $self->{recs};
    my @func_ids = sort( keys(%$recs) );
    my $count    = @func_ids;
    if ( $count == 0 ) {
        print "<p>You have 0 functions to export.</p>\n";
    } else {
        my $name = "_section_${section}_exportFunctions_noHeader";
#        print submit(
#                      -name    => $name,
#                      -value   => "Export Functions",
#                      -class   => "medbutton",
#                      -onclick => "return validateFnSelection(1);"
#        );
        my $contact_oid = WebUtil::getContactOid();
        my $str = HtmlUtil::trackEvent("Export", $contact_oid, "img button $name", "return validateFnSelection(1);");
        print qq{
<input class='meddefbutton' name='$name' type="submit" value="Export Functions" $str>
        };

        WorkspaceUtil::printSaveFunctionToWorkspace('func_id');
    }

}

############################################################################
# printTab3 - Profile & Alignment Tools section
############################################################################
sub printTab3 {
    my ($self) = @_;
    setSessionParam( "lastCart", "funcCart" );

    my $recs     = $self->{recs};
    my @func_ids = sort( keys(%$recs) );
    my $count    = @func_ids;

    if ( $count == 0 ) {
        print "<p>\n";
        print qq{
	    You have 0 functions in cart. In order to compare functions
            you need to select / upload functions into the function cart.};
        print "</p>\n";
        return;
    }

    my $dbh = dbLogin();
    print "<h2>Profile and Alignment Tools</h2>";

    printHint(   "- Hold down the control key (or command key in the case of the Mac) "
               . "to select multiple genomes.<br/>\n"
               . "- Drag down list to select all genomes.<br/>\n"
               . "- More genome and function selections result in slower query.\n" );
    print "<br/>";

    if ( $enable_genomelistJson ) {
        GenomeListJSON::printHiddenInputType();
        GenomeListJSON::printGenomeListJsonDiv('t:');
    } else {
        if ($include_metagenomes) {
            GenomeListFilter::appendGenomeListFilter( $dbh, '', 1, '', 'Yes', '', 1 );
        } else {
            GenomeListFilter::appendGenomeListFilter( $dbh, '', 1, '', 'Yes', '' );
        }
    }

    HtmlUtil::printMetaDataTypeChoice();

    print "<h2>Function Profile</h2>";

    print "<p>\n";
    print "View selected function(s) against selected genomes. ";
    print "<u>GO, Interpro and IMG Network are not supported</u>.<br/>";
    if ( $include_metagenomes ) {
        print "MER-FS metagenomes only suppport COG, EC, Pfam, TIGRfam, KO and MetaCyc.<br/>";
    }
    print "Use the <font color='blue'><u>Genome Filter</u></font> above "
      . "to select 1 to $max_genome_selections genome(s).";
    print "</p>\n";
    print hiddenVar( "type", "func" );
    my $name = "_section_${section}_showFuncCartProfile_s";

    if ( $enable_genomelistJson ) {
        GenomeListJSON::printMySubmitButton
	    ( "go1", $name, "View Functions vs. Genomes",
	      '', $section, 'showFuncCartProfile_s', 'meddefbutton' );

    } else {
        print submit(
              -id      => "go1",
              -name    => $name,
              -value   => "View Functions vs. Genomes",
              -class   => "meddefbutton",
              -onclick => "return validateFnSelection(1);"
        );
    }

    print nbsp(1);
    my $name = "_section_${section}_showFuncCartProfile_t";
    if ( $enable_genomelistJson ) {
        GenomeListJSON::printMySubmitButton
	    ( "go2", $name, "View Genomes vs. Functions",
	      '', $section, 'showFuncCartProfile_t', 'medbutton' );
    } else {
        print submit(
              -id      => "go2",
              -name    => $name,
              -value   => "View Genomes vs. Functions",
              -class   => "medbutton",
              -onclick => "return validateFnSelection(1);"
        );
    }
    my $contact_oid  = getContactOid();
    my $isPwayEditor = canEditPathway( $dbh, $contact_oid );

    # Experimental: pathway assertion
    # --es 01/18/08
    print "<h2>IMG Pathway Profile</h2>";
    print "<p>\n";
    print "View profile for selected IMG pathway functions. ";
    if ($include_metagenomes) {
        print "<u>MER-FS metagenomes are not supported.</u>";
    }
    print "<br/>";
    print "Use the <font color='blue'><u>Genome Filter</u></font> above to "
      . "restrict profile to selected genomes.<br/>\n";
    print "</p>\n";

    my $name = "_section_${section}_showPwayAssertionProfile_s";
    if ( $enable_genomelistJson ) {
        GenomeListJSON::printMySubmitButton
	    ( "go4", $name, "View IMG Pathways vs. Genomes",
	      '', $section, 'showPwayAssertionProfile_s', 'lgdefbutton' );
    } else {
        print submit(
              -id      => "go4",
              -name    => $name,
              -value   => "View IMG Pathways vs. Genomes",
              -class   => "lgdefbutton",
              -onclick => "return validateFnSelection(1);"
        );
    }
    print nbsp(1);

    my $name = "_section_${section}_showPwayAssertionProfile_t";
    if ( $enable_genomelistJson ) {
        GenomeListJSON::printMySubmitButton
	    ( "go5", $name, "View Genomes vs. IMG Pathways",
	      '', $section, 'showPwayAssertionProfile_t', 'lgbutton' );
    } else {
        print submit(
              -id      => "go5",
              -name    => $name,
              -value   => "View Genomes vs. IMG Pathways",
              -class   => "lgbutton",
              -onclick => "return validateFnSelection(1);"
        );
    }

    print "<h2>Occurrence Profile</h2>";
    print "<p>\n";
    print "Show phylogenetic occurrence profile for selected functions.  ";
    print "<u>GO, Interpro and IMG Network are not supported</u>.<br/>";
    print "Use the <font color='blue'><u>Genome Filter</u></font> above to "
	. "restrict profile to selected genomes.  Metagenomes are not supported.<br/>\n";
    print "</p>\n";
    my $name = "_section_${section}_funcOccurProfiles";
    if ( $enable_genomelistJson ) {
        GenomeListJSON::printMySubmitButton
	    ( "", $name, "View Phylogenetic Occurrence Profiles",
	      '',  $section, 'funcOccurProfiles', 'lgbutton' );
    } else {
        print submit(
              -name    => $name,
              -value   => "View Phylogenetic Occurrence Profiles",
              -class   => 'lgbutton',
              -onclick => "return validateFnSelection(1);"
        );
    }

    print "<h2>Function Alignment</h2>";
    print "<p>\n";
    print "List alignments of function prediction for genes of selected "
        . "functions (limit to COG, KOG and pfam).<br/>\n";
    print "Use the <font color='blue'><u>Genome Filter</u></font> above to "
        . "restrict genes to selected genomes.  ";
    if ( $include_metagenomes ) {
        print "Metagenomes are not supported.<br/>\n";
    }
    print "</p>\n";
    my $name = "_section_FunctionAlignment_showAlignmentForFunc";
    if ( $enable_genomelistJson ) {
        GenomeListJSON::printMySubmitButton
	    ( "", $name, "Function Alignment",
	      '', 'FunctionAlignment', 'showAlignmentForFunc', 'medbutton' );
    } else {
        print submit(
              -id      => "go",
              -name    => $name,
              -value   => "Function Alignment",
              -class   => "medbutton",
              -onclick => "return validateFnSelection(1);"
        );
    }

    # add to gene cart
    print "<h2>Gene Cart</h2>";
    print "<p>\n";
    print "Add the genes of selected functions to the Gene Cart. <br/>"
      . "Use the <font color='blue'><u>Genome Filter</u></font> above "
      . "to restrict genes to selected genomes.";
    print "</p>\n";
    my $name = "_section_${section}_addGeneCart";
    if ( $enable_genomelistJson ) {
        GenomeListJSON::printMySubmitButton
	    ( "go3", $name, "Add to Gene Cart",
	      '', $section, 'addGeneCart', 'medbutton' );
    } else {
        print submit(
              -id      => "go3",
              -name    => $name,
              -value   => "Add to Gene Cart",
              -class   => "medbutton",
              -onclick => "return validateFnSelection(1);"
        );
    }
}

sub printAnalysis {
    # functional closure
    print "<h2>Functional Closure</h2>\n";
    print "<p>";
    print "Link the first selected function in the cart to an associated " . "function of a different type:";

    print nbsp(1);
    print "<select name='new_func' class='img' size=1>\n";
    print "<option value='COG'>COG</option>\n";
    print "<option value='EC'>EC</option>\n";
    print "<option value='KO'>KO</option>\n";
    print "<option value='Pfam'>Pfam</option>\n";
    print "<option value='TIGRfam'>TIGRfam</option>\n";
    print "<option value='IMG Term'>IMG Term</option>\n";
    print "<option value='InterPro'>InterPro</option>\n";

    #print "<option value='SEED'>SEED</option>\n";
    print "</select>\n";

    print "<p>\n";
    my $name = "_section_FindClosure_showMain";
    print submit(
                  -id      => "findClosure",
                  -name    => $name,
                  -value   => "Find Closure",
                  -class   => "medbutton",
                  -onclick => "return validateFnSelection(1);"
    );
}

sub printKeggPathways {
    print "<h2>KEGG Pathways</h2>";
    print "<p>You may view pathways for selected KO or EC functions.</p>";
    my $name = "_section_PathwayMaps_selectedFns";
    print submit(
                  -id      => "keggPathways",
                  -name    => $name,
                  -value   => "KEGG Pathways",
                  -class   => "medbutton",
                  -onclick => "return validateKeggFnSelection(1);"
    );
}

############################################################################
# new - New instance.
############################################################################
sub new {
    my ( $myType, $baseUrl ) = @_;

    $baseUrl = "$section_cgi&page=funcCart" if $baseUrl eq "";
    my $self = {};
    bless( $self, $myType );
    my $stateFile = $self->getStateFile();
    if ( -e $stateFile ) {
        $self = retrieve($stateFile);
        $self->{baseUrl} = $baseUrl;
    } else {
        my %h1;
        my %h2;
        $self->{recs}     = \%h1;
        $self->{selected} = \%h2;
        $self->{baseUrl}  = $baseUrl;
        $self->save();
    }
    bless( $self, $myType );
    return $self;
}

############################################################################
# getStateFile - Get state file for persistence.
############################################################################
sub getStateFile {
    my ($self) = @_;
    my ( $cartDir, $sessionId ) = WebUtil::getCartDir();
    my $sessionFile = "$cartDir/funcCart.$sessionId.stor";
    return $sessionFile;
}

############################################################################
# save - Save in persistent state.
############################################################################
sub save {
    my ($self) = @_;
    store( $self, checkTmpPath( $self->getStateFile() ) );
}

############################################################################
# webAddFuncs - Load func cart from selections.
############################################################################
sub webAddFuncs {
    my ($self) = @_;

    my @func_ids = ();

    my @netfuncs_ids = param("func_id");
    @netfuncs_ids = removeDuplicate(@netfuncs_ids);

    my $only_func = param("only_func");
    if ( $only_func eq "MetaCyc" ) {
        foreach my $i (@netfuncs_ids) {
            if ( $i =~ /^MetaCyc:/ ) {
                push( @func_ids, $i );
            }
        }
    }
    elsif ( $only_func eq "IPWAY" ) {
        my @pway_oids = param("pway_oid");
        for my $i (@pway_oids) {
            $i = WebUtil::trimIntLeadingZero($i);
            push( @func_ids, "IPWAY:$i" );
        }

        foreach my $i (@netfuncs_ids) {
            if ( $i =~ /^IPWAY:/ ) {
                push( @func_ids, $i );
            }
        }
    }
    else {

        my @go_ids = param("go_id");
        for my $i (@go_ids) {
            push( @func_ids, $i );
        }

        my @cog_ids = param("cog_id");
        for my $i (@cog_ids) {
            push( @func_ids, $i );
        }

        my @kog_ids = param("kog_id");
        for my $i (@kog_ids) {
            push( @func_ids, $i );
        }

        my @ec_numbers = param("ec_number");
        for my $i (@ec_numbers) {
            push( @func_ids, $i );
        }

        my @ko_ids = param("ko_id");
        for my $i (@ko_ids) {
            push( @func_ids, $i );
        }

        my @pfam_ids = param("pfam_id");
        for my $i (@pfam_ids) {
            push( @func_ids, $i );
        }

        my @tigrfam_ids = param("tigrfam_id");
        for my $i (@tigrfam_ids) {
            push( @func_ids, $i );
        }

        my @ipr_ids = param("ipr_id");
        for my $i (@ipr_ids) {
            push( @func_ids, $i );
        }

        my @tc_fam_nums = param("tc_fam_num");
        for my $i (@tc_fam_nums) {
            push( @func_ids, $i );
        }

        my @term_oids = param("term_oid");
        for my $i (@term_oids) {
            $i = WebUtil::trimIntLeadingZero($i);
            push( @func_ids, "ITERM:$i" );
        }

        my @pway_oids = param("pway_oid");
        for my $i (@pway_oids) {
            $i = WebUtil::trimIntLeadingZero($i);
            push( @func_ids, "IPWAY:$i" );
        }

        my @parts_list_oids = param("parts_list_oid");
        for my $i (@parts_list_oids) {
            $i = WebUtil::trimIntLeadingZero($i);
            push( @func_ids, "PLIST:$i" );
        }

        # ids from the network browser
        # - ken
        foreach my $i (@netfuncs_ids) {
            if ( $i =~ /^ITERM/ ) {
                my $id = $i;
                $id =~ s/ITERM://;
                $id = WebUtil::trimIntLeadingZero($id);
                push( @func_ids, "ITERM:$id" );
            } elsif ( $i =~ /^IPWAY/ ) {
                my $id = $i;
                $id =~ s/IPWAY://;
                $id = WebUtil::trimIntLeadingZero($id);
                push( @func_ids, "IPWAY:$id" );
            } elsif ( $i =~ /^PLIST/ ) {
                my $id = $i;
                $id =~ s/PLIST://;
                $id = WebUtil::trimIntLeadingZero($id);
                push( @func_ids, "PLIST:$id" );
            } elsif ( $i =~ /^NETWK/ ) {
                my $id = $i;
                $id =~ s/NETWK://;
                $id = WebUtil::trimIntLeadingZero($id);
                push( @func_ids, "NETWK:$id" );
            } elsif ( $i =~ /^ICMPD/ ) {
                my $id = $i;
                $id =~ s/ICMPD://;
                $id = WebUtil::trimIntLeadingZero($id);
                push( @func_ids, "ICMPD:$id" );
            } elsif ( $i =~ /^IREXN/ ) {
                my $id = $i;
                $id =~ s/IREXN://;
                $id = WebUtil::trimIntLeadingZero($id);
                push( @func_ids, "IREXN:$id" );
            } elsif ( $i =~ /^PRULE/ ) {
                my $id = $i;
                $id =~ s/PRULE://;
                $id = WebUtil::trimIntLeadingZero($id);
                push( @func_ids, "PRULE:$id" );
            } else {
                push( @func_ids, $i );
            }
        }
    }
    #print "webAddFuncs() netfuncs_ids=@netfuncs_ids <br/> func_ids:@func_ids<br/>\n";

    $self->addFuncBatch( \@func_ids );

}

############################################################################
# addFuncBatch - Add genes in a batch.
############################################################################
sub addFuncBatch {
    my ( $self, $func_ids_ref ) = @_;

    return if ( scalar(@$func_ids_ref) == 0 );

    my $dbh = dbLogin();

    my @bad_ids;
    my $batch_id = getNextBatchId("func");

    my $recs = $self->{recs};
    $self->{selected} = {};
    my $selected = $self->{selected};

    my $recsNum = scalar(keys %$recs);
    #print "addFuncBatch() 0 recsNum=$recsNum<br/>\n";
    if ( !$recsNum || $recsNum < CartUtil::getMaxDisplayNum() ) {
        my %funcId2Name = QueryUtil::fetchFuncIdAndName( $dbh, $func_ids_ref );
        for my $func_id (@$func_ids_ref) {
            #print "addFuncBatch() func_id: $func_id<br/>\n";
            if ( exists $funcId2Name{$func_id} ) {
                my $func_name = $funcId2Name{$func_id};

                my $r = "$func_id\t";
                $r .= "$func_name\t";
                $r .= "$batch_id\t";
                #print "addFuncBatch() r: $r<br/>\n";
                $recs->{$func_id} = $r;
                $selected->{$func_id} = 1;

                $recsNum = scalar(keys %$recs);
                if ( $recsNum >= CartUtil::getMaxDisplayNum() ) {
                    last;
                }
            }
            else {
                push( @bad_ids, $func_id );
            }
        }
    }
    $self->save();

    if ( scalar(@bad_ids) > 0 ) {
        my $bad_id_str = join( ',', @bad_ids );
        param( -name => "bad_id_str", -value => $bad_id_str );
    }

}

############################################################################
# addImgTermBatch - Add genes in a batch.
############################################################################
sub addImgTermBatch {
    my ( $self, $term_oids_ref ) = @_;

    return if scalar(@$term_oids_ref) == 0;

    my $dbh = dbLogin();
    my $batch_id = getNextBatchId("func");
    $self->{selected} = {};
    my $selected = $self->{selected};
    $self->flushImgTermBatch( $dbh, $term_oids_ref, $batch_id );
    $self->save();
}

############################################################################
# flushImgTermBatch  - Flush one batch.
############################################################################
sub flushImgTermBatch {
    my ( $self, $dbh, $term_oids_ref, $batch_id ) = @_;

    return if ( scalar(@$term_oids_ref) == 0 );

    my $recs = $self->{recs};
    my $selected = $self->{selected};

    my $recsNum = scalar(keys %$recs);
    #print "flushImgTermBatch() recsNum=$recsNum<br/>\n";
    if ( !$recsNum || $recsNum < CartUtil::getMaxDisplayNum() ) {

        my $term_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$term_oids_ref );
        my $sql = qq{
            select it.term_oid, it.term
        	from img_term it
        	where it.term_oid in ( $term_oid_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose );

        my $count = 0;
        for ( ; ; ) {
            my ( $term_oid, $term ) = $cur->fetchrow();
            last if !$term_oid;
            $term_oid = FuncUtil::termOidPadded($term_oid);
            $count++;
            my $id = "ITERM:$term_oid";
            my $r  = "$id\t";
            $r .= "$term\t";
            $r .= "$batch_id\t";
            $recs->{$id}     = $r;
            $selected->{$id} = 1;

            $recsNum = scalar(keys %$recs);
            if ( $recsNum >= CartUtil::getMaxDisplayNum() ) {
                last;
            }
        }

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
            if ( $term_oid_str =~ /gtt_num_id/i );
    }
}

############################################################################
# addImgPwayBatch - Add genes in a batch.
############################################################################
sub addImgPwayBatch {
    my ( $self, $pway_oids_ref ) = @_;
    return if scalar(@$pway_oids_ref) == 0;

    my $dbh = dbLogin();
    my $batch_id = getNextBatchId("func");
    $self->{selected} = {};
    my $selected = $self->{selected};
    $self->flushImgPwayBatch( $dbh, $pway_oids_ref, $batch_id );
    $self->save();
}

############################################################################
# flushImgPwayBatch  - Flush one batch.
############################################################################
sub flushImgPwayBatch {
    my ( $self, $dbh, $pway_oids_ref, $batch_id ) = @_;

    return if ( scalar(@$pway_oids_ref) == 0 );

    my $recs = $self->{recs};
    my $selected = $self->{selected};
    my $recsNum = scalar(keys %$recs);
    #print "flushImgPwayBatch() recsNum=$recsNum<br/>\n";
    if ( !$recsNum || $recsNum < CartUtil::getMaxDisplayNum() ) {

        my $pway_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$pway_oids_ref );
        my $sql = qq{
            select ipw.pathway_oid, ipw.pathway_name
        	from img_pathway ipw
        	where ipw.pathway_oid in ( $pway_oid_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose );

        my $count = 0;
        for ( ; ; ) {
            my ( $pway_oid, $pway ) = $cur->fetchrow();
            last if !$pway_oid;
            $pway_oid = FuncUtil::pwayOidPadded($pway_oid);
            $count++;
            my $id = "IPWAY:$pway_oid";
            my $r  = "$id\t";
            $r .= "$pway\t";
            $r .= "$batch_id\t";
            $recs->{$id}     = $r;
            $selected->{$id} = 1;

            $recsNum = scalar(keys %$recs);
            if ( $recsNum >= CartUtil::getMaxDisplayNum() ) {
                last;
            }

        }

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
            if ( $pway_oid_str =~ /gtt_num_id/i );
    }

}

############################################################################
# addImgPartsListBatch - Add genes in a batch.
############################################################################
sub addImgPartsListBatch {
    my ( $self, $parts_list_oids_ref ) = @_;
    return if scalar(@$parts_list_oids_ref) == 0;

    my $dbh = dbLogin();
    my $batch_id = getNextBatchId("func");
    $self->{selected} = {};
    my $selected = $self->{selected};
    $self->flushImgPartsListBatch( $dbh, $parts_list_oids_ref, $batch_id );
    $self->save();
}

############################################################################
# flushImgPartsListBatch  - Flush one batch.
############################################################################
sub flushImgPartsListBatch {
    my ( $self, $dbh, $parts_list_oids_ref, $batch_id ) = @_;

    return if ( scalar(@$parts_list_oids_ref) == 0 );

    my $recs = $self->{recs};
    my $selected = $self->{selected};
    my $recsNum = scalar(keys %$recs);
    #print "flushImgPartsListBatch() recsNum=$recsNum<br/>\n";
    if ( !$recsNum || $recsNum < CartUtil::getMaxDisplayNum() ) {

        my $parts_list_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$parts_list_oids_ref );
        my $sql = qq{
            select ipl.parts_list_oid, ipl.parts_list_name
        	from img_parts_list ipl
        	where ipl.parts_list_oid in ( $parts_list_oid_str )
        };
        my $cur      = execSql( $dbh, $sql, $verbose );
        my $count    = 0;
        for ( ; ; ) {
            my ( $parts_list_oid, $parts_list_name ) = $cur->fetchrow();
            last if !$parts_list_oid;
            $parts_list_oid = FuncUtil::partsListOidPadded($parts_list_oid);
            $count++;
            my $id = "PLIST:$parts_list_oid";
            my $r  = "$id\t";
            $r .= "$parts_list_name\t";
            $r .= "$batch_id\t";
            $recs->{$id}     = $r;
            $selected->{$id} = 1;

            $recsNum = scalar(keys %$recs);
            if ( $recsNum >= CartUtil::getMaxDisplayNum() ) {
                last;
            }
        }

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
            if ( $parts_list_oid_str =~ /gtt_num_id/i );
    }

}

############################################################################
# webRemoveFuncs - Remove functions from cart.
############################################################################
sub webRemoveFuncs {
    my ($self)   = @_;
    my @func_ids = param("func_id");
    @func_ids = removeDuplicate(@func_ids);
    my $recs     = $self->{recs};
    my $selected = $self->{selected};
    if ( scalar(@func_ids) == 0 ) {
        webError("No functions have been selected.");
        return;
    }
    for my $func_id (@func_ids) {
        delete $recs->{$func_id};
        delete $selected->{$func_id};
    }
    $self->save();
}

############################################################################
# saveSelected - Save selections.
############################################################################
sub saveSelected {
    my ($self) = @_;
    my @func_ids = param("func_id");
    @func_ids = removeDuplicate(@func_ids);
    $self->{selected} = {};
    my $selected = $self->{selected};
    for my $func_id (@func_ids) {
        $selected->{$func_id} = 1;
    }
    $self->save();
}

############################################################################
# printFuncCartForm - Print function cart
#  form with list of genes and operations
#  that can be done on them.
############################################################################
sub printFuncCartForm {
    my ( $self, $load, $needGenomeJson ) = @_;

    # link is from the function tools page - ken 2008-06-12
    my $from = param("from");

    if ( $load eq "add" ) {
        printStatusLine( "Loading ...", 1 );
        $self->webAddFuncs();
    }
    if ( $load eq "upload" ) {
        printStatusLine( "Loading ...", 1 );
        $self->uploadFuncCart();
    }

    #print "printFuncCartForm() needGenomeJson: $needGenomeJson<br/>\n";
    if ( $needGenomeJson ) {
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;
        print qq{
            $js
        };
    }
    printJavaScript();

    setSessionParam( "lastCart", "funcCart" );
    my $contact_oid = getContactOid();

    printMainForm();
    print "<h1>Function Cart</h1>\n";
    CartUtil::printMaxNumMsg('functions');

    my $recs     = $self->{recs};
    my @func_ids = sort( keys(%$recs) );
    my $count    = @func_ids;

    if ( $count == 0 ) {
        print "<p>\n";
        print "0 functions in cart.\n";
        print qq{
    	    In order to compare functions you need to
    	    select / upload functions into the function cart.
	    };
        if ( $from ne "" ) {
            my $url = "main.cgi?section=FindFunctions&page=cogList";
            print "<br>For example, you can add ";
            print alink( $url, "COG" );
            $url = "main.cgi?section=FindFunctions&page=pfamList";
            print " and/or " . alink( $url, "Pfam" ) . ".";
        }

        print "</p>\n";
        printStatusLine( "0 functions in cart", 2 );

        if ( $from eq "" ) {
            # upload function cart from file
            print "<h2>Upload Function Cart</h2>\n";
            printUploadFuncCartFormContent();
        }

        print end_form();
        return;
    }

    print "<p>\n";
    print "$count function(s) in cart\n";
    print "</p>\n";

    printFnValidationJS();

    use TabHTML;
    TabHTML::printTabAPILinks("funccartTab");

    my $idx      = 1;
    my @tabIndex = ("#funccarttab1");
    $idx++;
    my @tabNames = ("Functions in Cart");
    if ( $from eq "" ) {
        push @tabIndex, "#funccarttab" . $idx;
        push @tabNames, "Upload & Export & Save";
        $idx++;
    }

    # if ( $include_metagenomes && $contact_oid > 0 && $contact_oid != 901) {
    #      push @tabIndex, "#funccarttab" . $idx;
    #      push @tabNames, "My Function Categories";
    #      $idx++;
    # }
    push @tabIndex, "#funccarttab" . $idx;
    push @tabNames, "Profile & Alignment";
    $idx++;

    push @tabIndex, "#funccarttab" . $idx;
    push @tabNames, "KEGG Pathways";
    push @tabIndex, "#funccarttab" . $idx;
    push @tabNames, "Analysis";

    TabHTML::printTabDiv( "funccartTab", \@tabIndex, \@tabNames );

    print "<div id='funccarttab1'>";

    printFuncCartButtons() if $count > 10;
    $self->printTableList();
    printFuncCartButtons();

    print "<p>\n";
    print "1 - Each time a set of functions is added to the cart, "
	. "a new batch number is generated for the set.<br/>\n";
    print "</p>\n";

    my $bad_id_str = param("bad_id_str");
    if ( !blankStr($bad_id_str) ) {
        print "<p>\n";
        print "<font color='red'>\n";
        print "Unmapped ID's $bad_id_str<br/>.\n";
        print "</font>\n";
        print "</p>\n";
    }
    print "</div>";    # end funccarttab1

    my $idx = 2;

    # upload and export
    if ( $from eq "" ) {
        print "<div id='funccarttab$idx'>";
        $self->printTab2();
        print "</div>";    # end funccarttab2
        $idx++;
    }

    #if ( $include_metagenomes && $contact_oid > 0 && $contact_oid != 901) {
    #print "<div id='funccarttab$idx'>";
    # # function categories
    #$self->printMyFuncCat();
    #print "</div>";    # end funccarttab3
    #$idx++;
    #}

    print "<div id='funccarttab$idx'>";

    # tools
    $self->printTab3();
    print "</div>";    # end funccarttab4
    $idx++;

    print "<div id='funccarttab$idx'>";

    # kegg pathways
    printKeggPathways();
    print "</div>";    # end funccarttab4
    $idx++;

    print "<div id='funccarttab$idx'>";

    # analysis
    printAnalysis();
    print "</div>";    # end funccarttab5
    $idx++;

    TabHTML::printTabDivEnd();
    print end_form();
    $self->save();

    printStatusLine( "$count function(s) in cart", 2 );
}

sub printTableList {
    my ($self) = @_;

    my $it = new InnerTable( 1, "FunctionCart$$", "FunctionCart", 3 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Selection");
    $it->addColSpec( "Function ID",       "char asc",    "left" );
    $it->addColSpec( "Name",              "char asc",    "left" );
    $it->addColSpec( "Batch<sup>1</sup>", "number desc", "left" );

    my @sortedRecs;
    my $sortIdx = param("sortIdx");
    $sortIdx = 2 if $sortIdx eq "";
    $self->sortedRecsArray( $sortIdx, \@sortedRecs );
    my $selected = $self->{selected};

    for my $r (@sortedRecs) {
        my ( $func_id, $func_name, $batch_id ) = split( /\t/, $r );

        my $ck;
        $ck = "checked='checked'" if $selected->{$func_id} ne "";

        my $row;
        $row .= $sd . "<input type='checkbox' " . "name='func_id' value='$func_id' $ck />\t";

        my $link = $func_id;
        my $url  = '';
        if ( $func_id =~ /^GO/ ) {
            $url = "$go_base_url$func_id";
        } elsif ( $func_id =~ /^COG/ ) {
            $url = "$cog_base_url$func_id";
        } elsif ( $func_id =~ /^KOG/ ) {
            $url = "$kog_base_url$func_id";
        } elsif ( $func_id =~ /^pfam/ ) {
            my $func_id2 = $func_id;
            $func_id2 =~ s/pfam/PF/;
            $url = "$pfam_base_url$func_id2";
        } elsif ( $func_id =~ /^TIGR/ ) {
            $url = "$tigrfam_base_url$func_id";
        } elsif ( $func_id =~ /^IPR/ ) {
            $url = "$ipr_base_url$func_id";
        } elsif ( $func_id =~ /^EC:/ ) {
            my $func_id2 = $func_id;
            $func_id2 =~ s/EC://;
            $url = "$enzyme_base_url$func_id";
        } elsif ( $func_id =~ /^TC:/ ) {
            my $id = $func_id;
            $id =~ s/TC://;
            $url = $tc_base_url . $id;
        } elsif ( $func_id =~ /^KO:/ ) {
            $url = $kegg_orthology_url . $func_id;
        } elsif ( $func_id =~ /^NP:/ ) {
            my $id = $func_id;
            $id =~ s/NP://;
            $url = "$main_cgi?section=NaturalProd&page=naturalProd&np_id=$id";
        } elsif ( $func_id =~ /^MetaCyc:/ ) {
            my $id = $func_id;
            $id =~ s/MetaCyc://;
            $url = "$main_cgi?section=MetaCyc&page=detail&pathway_id=$id";
        } elsif ( $func_id =~ /ITERM/ ) {
            my $term_oid = $func_id;
            $term_oid =~ s/ITERM://;
            $url = "$main_cgi?section=ImgTermBrowser";
            $url .= "&page=imgTermDetail";
            $url .= "&term_oid=$term_oid";
        } elsif ( $func_id =~ /IPWAY/ ) {
            my $pway_oid = $func_id;
            $pway_oid =~ s/IPWAY://;
            $url = "$main_cgi?section=ImgPwayBrowser";
            $url .= "&page=imgPwayDetail";
            $url .= "&pway_oid=$pway_oid";
        } elsif ( $func_id =~ /PLIST/ ) {
            my $parts_list_oid = $func_id;
            $parts_list_oid =~ s/PLIST://;
            $url = "$main_cgi?section=ImgPartsListBrowser";
            $url .= "&page=partsListDetail";
            $url .= "&parts_list_oid=$parts_list_oid";
        } elsif ( $func_id =~ /NETWK/ ) {
            my $network_oid = $func_id;
            $network_oid =~ s/NETWK://;
            $url = "$main_cgi?section=ImgNetworkBrowser";
            $url .= "&page=pathwayNetworkDetail";
            $url .= "&network_oid=$network_oid";
        }
        $link = alink( $url, $func_id ) if ( $url ne '' );

        $row .= $func_id . $sd . $link . "\t";
        if ( $func_id =~ /^\d+\.[A-Z]\.\d+/ ) {    #tc
            $row .= $func_name . $sd . $func_name . "\t";
        } else {
            $row .= $func_name . $sd . escHtml($func_name) . "\t";
        }
        $row .= $batch_id . $sd . $batch_id . "\t";
        $it->addRow($row);
    }
    $it->printOuterTable(1);
}

sub printFuncCartButtons {

    WebUtil::printButtonFooterInLineWithToggle();

    my $name = "_section_${section}_deleteSelectedCartFuncs";
    print submit(
          -name  => $name,
          -value => "Remove Selected",
          -class => 'smdefbutton'
    );
}

## Experimental: my functional categories.
#  --es 01/19/98
sub printMyFuncCat {
    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();

    if (    $include_metagenomes
         && $contact_oid > 0
         && $contact_oid != 901
         && WebUtil::tableExists( $dbh, "myfunc_cat" ) )
    {
        print "<h2>My Function Categories</h2>";
        print "<p>\n";
        print "Select COG, KOG, Pfam, enzymes, or TIGRfam.<br/>\n";
        print "You may group these into your own custom function categories.\n";
        print "</p>\n";
        my $name = "_section_MyFuncCat_editForm";
        print submit(
                      -name  => $name,
                      -value => "Edit My Function Categories",
                      -class => "lgbutton"
        );
    }

    #$dbh->disconnect();
}

# this is required when it was separate pages for export
sub printHiddenList {
    my ($self) = @_;

    my @sortedRecs;
    my $sortIdx = param("sortIdx");
    $sortIdx = 2 if $sortIdx eq "";
    $self->sortedRecsArray( $sortIdx, \@sortedRecs );
    my $selected = $self->{selected};
    for my $r (@sortedRecs) {
        my ( $func_id, $func_name, $batch_id ) = split( /\t/, $r );

        print "<input type='hidden' " . "name='func_id' value='$func_id' />\n";

    }
}

############################################################################
# printSortHeaderLink - Print sorted header link.
############################################################################
sub printSortHeaderLink {
    my ( $self, $name, $sortIdx ) = @_;

    my $baseUrl = $self->{baseUrl};
    my $url     = $baseUrl;
    $url .= "&sortIdx=$sortIdx";
    print "<th class='img'>";
    print alink( $url, $name, "", 1 );
    print "</th>\n";
}

############################################################################
# sortedRecsArray - Return sorted records array.
#   sortIdx - is column index to sort on, starting from 0.
############################################################################
sub sortedRecsArray {
    my ( $self, $sortIdx, $outRecs_ref ) = @_;
    my $recs     = $self->{recs};
    my @func_ids = keys(%$recs);
    my @a;
    my @idxVals;
    for my $func_id (@func_ids) {
        my $rec = $recs->{$func_id};
        my @fields = split( /\t/, $rec );
        my $sortRec;
        my $sortFieldVal = $fields[$sortIdx];
        if ( $sortIdx == 0 || $sortIdx == 2 ) {
            $sortRec = sprintf( "%09d\t%s", $sortFieldVal, $func_id );
        } else {
            $sortRec = sprintf( "%s\t%s", $sortFieldVal, $func_id );
        }
        push( @idxVals, $sortRec );
    }
    my @idxValsSorted = sort(@idxVals);
    for my $i (@idxValsSorted) {
        my ( $idxVal, $func_id ) = split( /\t/, $i );
        my $r = $recs->{$func_id};
        push( @$outRecs_ref, $r );
    }
}

############################################################################
# printUploadFuncCartForm
############################################################################
sub printUploadFuncCartForm {
    print "<h1>Upload Function Cart</h1>\n";

    # need a different ENCTYPE for file upload
    print start_form(
                      -name    => "mainForm",
                      -enctype => "multipart/form-data",
                      -action  => "$section_cgi"
    );
    printUploadFuncCartFormContent();
    print end_form();
}

sub printUploadFuncCartFormContent {
    my ($fromUploadSection) = @_;

    print "<p>\n";
    print "You may upload a function cart from a tab-delimited file.<br/>";
    print "The file should have a column header 'func_id'.<br/>\n";
    if ( $fromUploadSection eq 'Yes' ) {
        print qq{
            (This file can be created using the
            <font color="blue"><u>Export Functions</u></font> section below.)<br/>\n
        };
    } else {
        print "(This file may initially be obtained by " . "exporting genes in a function cart to Excel.)<br/>\n";
    }
    print "<br/>\n";

    my $textFieldId = "cartUploadFile";
    print "File to upload:<br/>\n";
    print "<input id='$textFieldId' type='file' name='uploadFile' size='45'/>\n";

    print "<br/>\n";
    my $name = "_section_FuncCartStor_uploadFuncCart";
    print submit(
                  -name    => $name,
                  -value   => "Upload from File",
                  -class   => "medbutton",
                  -onClick => "return uploadFileName('$textFieldId');",
    );

    if ($user_restricted_site) {
        print nbsp(1);
        my $url = "$main_cgi?section=WorkspaceFuncSet&page=home";
        print buttonUrl( $url, "Upload from Workspace", "medbutton" );
    }

    print "</p>\n";
}

############################################################################
# printFuncCartProfile_s - Show profile for functions in cart, "straight".
############################################################################
sub printFuncCartProfile_s {
    my ( $self, $type, $procId, $sortIdx, $minPercIdent, $maxEvalue, $oids ) = @_;
    my $baseUrl = $self->{baseUrl};

    $type         = param("type")         if $type         eq "";
    $procId       = param("procId")       if $procId       eq "";
    $sortIdx      = param("sortIdx")      if $sortIdx      eq "";
    $minPercIdent = param("minPercIdent") if $minPercIdent eq "";
    $maxEvalue    = param("maxEvalue")    if $maxEvalue    eq "";
    my $znorm = param("znorm");

    my $data_type = param("data_type");
    if ( !$data_type ) {
        $data_type = param("q_data_type");
    }

    print "<h1>Function Profile</h1>\n";

    #featureLockCheck("funcCartLock");

    require PhyloProfile;
    if ( $procId ne "" ) {
        my $pp = new PhyloProfile( $type, $procId );
        $pp->printProfile();
        printAllGenesLink( "PhyloProfile", $type, $procId );
        print "<br/>\n";
        print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );
        return;
    }

    my @func_ids = param("func_id");
    @func_ids = removeDuplicate(@func_ids);
    #print "printFuncCartProfile_s() func_ids: @func_ids<br/>\n";
    my $nFuncs = scalar(@func_ids);
    if ( $nFuncs == 0 ) {
        # 1000 limit remove?
        webError("Please select at least 1 function.");
    }

    my @taxon_oids = OracleUtil::processTaxonBinOids("t");
    if($enable_genomelistJson) {
        @taxon_oids = param('genomeFilterSelections');
        @taxon_oids = GenomeListJSON::cleanTaxonOid(@taxon_oids);
    }

    if ( $oids && $oids ne "" ) {
        @taxon_oids = @$oids;
    }
    my @bin_oids    = OracleUtil::processTaxonBinOids("b");
    my $nSelections = scalar(@taxon_oids) + scalar(@bin_oids);
    if ( $nSelections == 0 || $nSelections > $max_genome_selections ) {
        webError("Please select 1 to $max_genome_selections genome(s).");
    }

    print "<p>";
    print "$nFuncs functions and $nSelections genomes are selected.";
    print "</p>";

    $self->{selected} = {};
    my $selected = $self->{selected};
    for my $func_id (@func_ids) {
        $selected->{$func_id} = 1;
    }
    $self->save();

    my (
         $cog_ids_ref,   $kog_ids_ref,   $pfam_ids_ref,    $tigr_ids_ref,
         $ec_ids_ref,    $ko_ids_ref,    $tc_fam_nums_ref, $bc_ids_ref, $metacyc_ids_ref,
         $iterm_ids_ref, $ipway_ids_ref, $plist_ids_ref,   $unrecognized_ids_ref,
         $unsurported_func_ids_ref
      )
      = CartUtil::separateFuncIds(@func_ids);

    if (    scalar(@$cog_ids_ref) <= 0
         && scalar(@$kog_ids_ref) <= 0
         && scalar(@$pfam_ids_ref) <= 0
         && scalar(@$tigr_ids_ref) <= 0
         && scalar(@$ec_ids_ref) <= 0
         && scalar(@$ko_ids_ref) <= 0
         && scalar(@$tc_fam_nums_ref) <= 0
         && ( scalar(@$bc_ids_ref) <= 0 && $enable_biocluster )
         && scalar(@$metacyc_ids_ref) <= 0
         && scalar(@$iterm_ids_ref) <= 0
         && scalar(@$ipway_ids_ref) <= 0
         && scalar(@$plist_ids_ref) <= 0
         && ( scalar(@$unrecognized_ids_ref) > 0 || scalar(@$unsurported_func_ids_ref) ) > 0 )
    {
        webError("Unspported (such as GO and Interpro) or unrecognized functions in Function Profile.");
    }

    if ( scalar(@$unsurported_func_ids_ref) > 0 ) {
        print "<h5>Unspported functions: @$unsurported_func_ids_ref</h5>";
    }

    if ( scalar(@$unrecognized_ids_ref) > 0 ) {
        print "<h5>Unrecognized functions: @$unrecognized_ids_ref</h5>";
    }

    my $contact_oid = getContactOid();
    if ( scalar(@$ec_ids_ref) > 0 && $contact_oid ) {
        print "<h5>Note: MyIMG gene-enzyme annotations (if any) "
          . "will replace default IMG gene-enzyme associations.</h5>\n";
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    ##
    #  z-norm set up
    #
    my %taxonOid2GeneCount;
    my %binOid2GeneCount;
    my %clusterScaleMeanStdDev;

    #    if ($znorm) {
    #        WebUtil::arrayRef2HashRef( \@taxon_oids, \%taxonOid2GeneCount,     0 );
    #        WebUtil::arrayRef2HashRef( \@bin_oids,   \%binOid2GeneCount,       0 );
    #        WebUtil::arrayRef2HashRef( \@func_ids,   \%clusterScaleMeanStdDev, "" );
    #        getTaxonGeneCount( $dbh, \%taxonOid2GeneCount );
    #        getBinGeneCount( $dbh, \%binOid2GeneCount );
    #
    #        # use oracle gtt to solve 1000 limit
    #        if ( OracleUtil::useTempTable($size) ) {
    #            getClusterScaleMeanStdDev
    #       ( $dbh, "dt_func_abundance", "func_id",
    #         \%clusterScaleMeanStdDev, $func_id_str );
    #        } else {
    #            getClusterScaleMeanStdDev
    #       ( $dbh, "dt_func_abundance", "func_id",
    #         \%clusterScaleMeanStdDev );
    #        }
    #    }
    #    OracleUtil::truncTable( $dbh, "gtt_func_id" );

    ## get MER-FS taxons
    my ( $dbTaxons_ref, $metaTaxons_ref ) = MerFsUtil::findTaxonsInFile( $dbh, @taxon_oids );
    my @dbTaxons   = @$dbTaxons_ref;
    my @metaTaxons = @$metaTaxons_ref;

    #    my $rclause   = WebUtil::urClause('g.taxon_oid');
    #    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');
    #    my $rclause2   = WebUtil::urClause('g.taxon');
    #    my $imgClause2 = WebUtil::imgClauseNoTaxon('g.taxon');

    my %funcId2Name = QueryUtil::fetchFuncIdAndName( $dbh, \@func_ids );
    my @recs;
    if ( scalar(@dbTaxons) > 0 ) {
        my $db_taxon_oid_str = join( ',', @dbTaxons );

        if ( scalar(@$cog_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'COG', $cog_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't' );
        }

        if ( scalar(@$kog_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'KOG', $kog_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't' );
        }

        if ( scalar(@$pfam_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'pfam', $pfam_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't' );
        }

        if ( scalar(@$tigr_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'TIGR', $tigr_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't' );
        }

        if ( scalar(@$ec_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'EC', $ec_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't' );
        }

        if ( scalar(@$ko_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'KO', $ko_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't' );
        }

        if ( scalar(@$tc_fam_nums_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'TC', $tc_fam_nums_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't' );
        }

        if ( scalar(@$bc_ids_ref) > 0 && $enable_biocluster ) {
            processProfileForCharFunc_s( $dbh, 'BC', $bc_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't',
                                         'BC:' );
        }

        if ( scalar(@$metacyc_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'MetaCyc', $metacyc_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't',
                                         'MetaCyc:' );
        }

        if ( scalar(@$iterm_ids_ref) > 0 ) {
            processProfileForNumFunc_s( $dbh, 'ITERM', $iterm_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                        \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't',
                                        'ITERM:' );
        }

        if ( scalar(@$ipway_ids_ref) > 0 ) {
            processProfileForNumFunc_s( $dbh, 'IPWAY', $ipway_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                        \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't',
                                        'IPWAY:' );
        }

        if ( scalar(@$plist_ids_ref) > 0 ) {
            processProfileForNumFunc_s( $dbh, 'PLIST', $plist_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                                        \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 't',
                                        'PLIST:' );
        }

    }

    ## Bin selection
    if ( scalar(@bin_oids) > 0 ) {
        my @bin2taxon_oids = QueryUtil::fetchTaxonOidsFromBinOids( $dbh, @bin_oids );
        my $bin2taxon_str  = OracleUtil::getNumberIdsInClause1( $dbh,    @bin2taxon_oids );

        if ( scalar(@$cog_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'COG', $cog_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b' );
        }

        if ( scalar(@$kog_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'KOG', $kog_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b' );
        }

        if ( scalar(@$pfam_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'pfam', $pfam_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b' );
        }

        if ( scalar(@$tigr_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'TIGR', $tigr_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b' );
        }

        if ( scalar(@$ec_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'EC', $ec_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b' );
        }

        if ( scalar(@$ko_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'KO', $ko_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b' );
        }

        if ( scalar(@$tc_fam_nums_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'TC', $tc_fam_nums_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b' );
        }

        if ( scalar(@$bc_ids_ref) > 0 && $enable_biocluster ) {
            processProfileForCharFunc_s( $dbh, 'BC', $bc_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b',
                                         'BC:' );
        }

        if ( scalar(@$metacyc_ids_ref) > 0 ) {
            processProfileForCharFunc_s( $dbh, 'MetaCyc', $metacyc_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                         \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b',
                                         'MetaCyc:' );
        }

        if ( scalar(@$iterm_ids_ref) > 0 ) {
            processProfileForNumFunc_s( $dbh, 'ITERM', $iterm_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                        \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b',
                                        'ITERM:' );
        }

        if ( scalar(@$ipway_ids_ref) > 0 ) {
            processProfileForNumFunc_s( $dbh, 'IPWAY', $ipway_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                        \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b',
                                        'IPWAY:' );
        }

        if ( scalar(@$plist_ids_ref) > 0 ) {
            processProfileForNumFunc_s( $dbh, 'PLIST', $plist_ids_ref, $bin2taxon_str, \%taxonOid2GeneCount,
                                        \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%funcId2Name, 'b',
                                        'PLIST:' );
        }
    }

    if ( scalar(@metaTaxons) > 0 ) {
        my $meta_taxon_oid_str = join( ',', @metaTaxons );

        my $rclause   = WebUtil::urClause('g.taxon_oid');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

        if ( scalar(@$cog_ids_ref) > 0 ) {
            processProfileForCharFunc_merfs_s(
                $dbh, 'COG', $cog_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%funcId2Name, 't', '', $rclause, $imgClause );
        }

        if ( scalar(@$pfam_ids_ref) > 0 ) {
            processProfileForCharFunc_merfs_s(
                $dbh, 'pfam', $pfam_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%funcId2Name, 't', '', $rclause, $imgClause );
        }

        if ( scalar(@$tigr_ids_ref) > 0 ) {
            processProfileForCharFunc_merfs_s(
                $dbh, 'TIGR', $tigr_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%funcId2Name, 't', '', $rclause, $imgClause );
        }

        if ( scalar(@$ec_ids_ref) > 0 ) {
            processProfileForCharFunc_merfs_s(
                $dbh, 'EC', $ec_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%funcId2Name, 't', '', $rclause, $imgClause );
        }

        if ( scalar(@$ko_ids_ref) > 0 ) {
            processProfileForCharFunc_merfs_s(
                $dbh, 'KO', $ko_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%funcId2Name, 't', '', $rclause, $imgClause );
        }

        if ( scalar(@$bc_ids_ref) > 0 && $enable_biocluster ) {
            processProfileForCharFunc_merfs_s(
                $dbh, 'BC', $bc_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%funcId2Name, 't', 'BC:', $rclause, $imgClause );
		}

        if ( scalar(@$metacyc_ids_ref) > 0 ) {
            my ($metacyc2ec_href, $ec2metacyc_href) = QueryUtil::fetchMetaCyc2EcHash( $dbh, $metacyc_ids_ref );
            #print Dumper($metacyc2ec_href);
            #print "<br/>\n";
            #print Dumper($ec2metacyc_href);
            #print "<br/>\n";
            my @ec_ids_tmp = keys %$ec2metacyc_href;
            #print "printFuncCartProfile_s() ec_ids_tmp: @ec_ids_tmp<br/>\n";

            if ( scalar(@ec_ids_tmp) > 0 ){
                my @recs_tmp;
                processProfileForCharFunc_merfs_s(
                    $dbh, 'EC', \@ec_ids_tmp, $meta_taxon_oid_str, $data_type,
                    \@recs_tmp, \%funcId2Name, 't', '', $rclause, $imgClause );

                my %metacyc2taxon2cnt_h;
                for my $r (@recs_tmp) {
                    my ($ec_id, $ec_id_name, $taxon_oid, $bin_oid, $cnt) = split( /\t/, $r );

                    my $metacyc_ids_ref = $ec2metacyc_href->{$ec_id};
                    for my $metacyc_id (@$metacyc_ids_ref) {
                        my $taxon2cnt_href = $metacyc2taxon2cnt_h{$metacyc_id};
                        if ($taxon2cnt_href) {
                            $taxon2cnt_href->{$taxon_oid} += $cnt;
                        }
                        else {
                            my %taxon2cnt_h;
                            $taxon2cnt_h{$taxon_oid} = $cnt;
                            $metacyc2taxon2cnt_h{$metacyc_id} = \%taxon2cnt_h;
                        }
                    }
                }

                for my $metacyc_id (keys %metacyc2taxon2cnt_h) {
                    my $taxon2cnt_href = $metacyc2taxon2cnt_h{$metacyc_id};
                    for my $taxon_oid (keys %$taxon2cnt_href) {
                        my $cnt = $taxon2cnt_href->{$taxon_oid};

                        my $r = "$metacyc_id\t";
                        $r .= $funcId2Name{$metacyc_id} . "\t";
                        $r .= "$taxon_oid\t";
                        $r .= "\t";       # null bin_oid
                        $r .= "$cnt\t";
                        push( @recs, $r );
                    }
                }
            }
        }

    }

    #print "FuncCartStor::printFuncCartProfile_s() recs: @recs<br/>\n";
    if ( scalar(@recs) > 0 ) {

        my $url         = "$main_cgi?section=PhyloProfile&page=phyloProfile";
        my @colorMap_gc = ( "1:5:bisque", "5:100000:#FFFF66", );
        my @colorMap_zn = ( "0.01:1:bisque", "1:100000:#FFFF66", );

        my @colorMap = @colorMap_gc;
        @colorMap = @colorMap_zn if $znorm;
        my $sortUrl = "$section_cgi&showFuncCartProfile_s";

        my $taxon_cell_sql_template;
        my $bin_cell_sql_template;
        my $pp =
          new PhyloProfile( "func", $$, "Function ID", "Name", $url, $sortUrl, \@func_ids, \%funcId2Name,
                            \@taxon_oids, \@bin_oids, $data_type, \@recs, \@colorMap,
                            $taxon_cell_sql_template, $bin_cell_sql_template, $znorm );

        $pp->printProfile();
        printAllGenesLink( "PhyloProfile", $type, $procId );
    } else {
        print "No profile data retrieved for the selected function(s) and genome(s).<br/>\n";
    }

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );

    print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );

    $self->save();
}

sub processProfileForCharFunc_s {
    my ( $dbh, $func_type, $func_ids_ref, $db_oid_str, $oid2GeneCount_href, $clusterScaleMeanStdDev_href, $znorm,
         $contact_oid, $recs_ref, $funcId2Name_ref, $taxon_type, $symbToAdd )
      = @_;

    my $func_id_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref );
    my $sql;
    if ( $taxon_type eq 't' ) {
        $sql = getFuncCartProfileTaxonQuery_s( $func_type, $func_id_str, $db_oid_str, $contact_oid );
    } elsif ( $taxon_type eq 'b' ) {
        $sql = getFuncCartProfileBinQuery_s( $func_type, $func_id_str, $db_oid_str, $contact_oid );
    }

    #print "FuncCartStor::processProfileForCharFunc_s() func_type: $func_type, taxon_type: $taxon_type, sql: $sql<br/>\n";
    execFuncCartProfileSql_s( $dbh, $sql, $oid2GeneCount_href, $clusterScaleMeanStdDev_href, $znorm, $recs_ref,
                              $funcId2Name_ref, $taxon_type, $symbToAdd );
    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $func_id_str =~ /gtt_func_id/i );
}

sub processProfileForNumFunc_s {
    my ( $dbh, $func_type, $func_ids_ref, $db_oid_str, $oid2GeneCount_href, $clusterScaleMeanStdDev_href, $znorm,
         $contact_oid, $recs_ref, $funcId2Name_ref, $taxon_type, $symbToAdd )
      = @_;

    my $func_id_str = OracleUtil::getNumberIdsInClause( $dbh, @$func_ids_ref );
    my $sql;
    if ( $taxon_type eq 't' ) {
        $sql = getFuncCartProfileTaxonQuery_s( $func_type, $func_id_str, $db_oid_str, $contact_oid );
    } elsif ( $taxon_type eq 'b' ) {
        $sql = getFuncCartProfileBinQuery_s( $func_type, $func_id_str, $db_oid_str, $contact_oid );
    }
    execFuncCartProfileSql_s( $dbh, $sql, $oid2GeneCount_href, $clusterScaleMeanStdDev_href, $znorm, $recs_ref,
                              $funcId2Name_ref, $taxon_type, $symbToAdd );
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $func_id_str =~ /gtt_num_id/i );
}

sub execFuncCartProfileSql_s {
    my ( $dbh, $sql, $oid2GeneCount_href, $clusterScaleMeanStdDev_href, $znorm, $recs_ref, $funcId2Name_ref, $taxon_type,
         $symbToAdd )
      = @_;

    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id, $oid, $gene_count ) = $cur->fetchrow();
            last if !$id;
            my $total_gene_count = $oid2GeneCount_href->{$oid};
            $gene_count =
              WebUtil::geneCountWrap( $gene_count, $total_gene_count, $id, $clusterScaleMeanStdDev_href, $znorm );
            my $symbId = "$symbToAdd$id";
            my $r      = "$symbId\t";
            $r .= $funcId2Name_ref->{$symbId} . "\t";
            if ( $taxon_type eq 't' ) {
                $r .= "$oid\t";
                $r .= "\t";       # null bin_oid
            } elsif ( $taxon_type eq 'b' ) {
                $r .= "\t";       # null taxon_oid
                $r .= "$oid\t";
            }
            $r .= "$gene_count\t";
            push( @$recs_ref, $r );
        }
        $cur->finish();
    }
}

sub processProfileForCharFunc_merfs_s {
    my (
         $dbh,      $func_type,       $func_ids_ref, $oid_str,   $data_type,
         $recs_ref, $funcId2Name_ref, $taxon_type,   $symbToAdd, $rclause, $imgClause
      )
      = @_;

    my $func_id_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref );
    my $sql;
    if ( $taxon_type eq 't' ) {
        $sql = getFuncCartProfileTaxonQuery_merfs_s( $func_type, $func_id_str, $oid_str, $data_type, $rclause, $imgClause );
    }
    execFuncCartProfileSql_merfs_s( $dbh, $sql, $recs_ref, $funcId2Name_ref, $taxon_type, $symbToAdd );
    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $func_id_str =~ /gtt_func_id/i );
}

sub execFuncCartProfileSql_merfs_s {
    my ( $dbh, $sql, $recs_ref, $funcId2Name_ref, $taxon_type, $symbToAdd ) = @_;

    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id, $oid, $gene_count ) = $cur->fetchrow();
            last if !$id;
            my $symbId = "$symbToAdd$id";
            my $r      = "$symbId\t";
            $r .= $funcId2Name_ref->{$symbId} . "\t";
            if ( $taxon_type eq 't' ) {
                $r .= "$oid\t";
                $r .= "\t";       # null bin_oid
            }
            $r .= "$gene_count\t";
            push( @$recs_ref, $r );
        }
        $cur->finish();
    }
}

############################################################################
# printFuncCartProfile_t - Show profile for functions in cart, transposed.
############################################################################
sub printFuncCartProfile_t {
    my ( $self, $type, $procId, $sortIdx, $minPercIdent, $maxEvalue, $oids ) = @_;

    $type         = param("type")         if $type         eq "";
    $procId       = param("procId")       if $procId       eq "";
    $sortIdx      = param("sortIdx")      if $sortIdx      eq "";
    $minPercIdent = param("minPercIdent") if $minPercIdent eq "";
    $maxEvalue    = param("maxEvalue")    if $maxEvalue    eq "";
    my $znorm = param("znorm");

    my $data_type = param("data_type");
    if ( !$data_type ) {
        $data_type = param("q_data_type");
    }

    my $baseUrl = $self->{baseUrl};

    print "<h1>Function Profile</h1>\n";

    #featureLockCheck("funcCartLock");

    require FuncProfile;
    if ( $procId ne "" ) {
        my $fp = new FuncProfile( $type, $procId );
        $fp->printProfile();
        printAllGenesLink( "FuncProfile", $type, $procId );
        print "<br/>\n";
        print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );
        return;
    }

    my @func_ids = param("func_id");
    @func_ids = removeDuplicate(@func_ids);
    #print "printFuncCartProfile_t() func_ids: @func_ids<br/>\n";
    my $nFuncs   = scalar(@func_ids);
    if ( scalar(@func_ids) == 0 || scalar(@func_ids) > $max_func_batch ) {
        webError("Please select 1 to $max_func_batch functions.");
    }

    my @taxon_oids = OracleUtil::processTaxonBinOids("t");
    if ($enable_genomelistJson) {
        @taxon_oids = param('genomeFilterSelections');
        @taxon_oids = GenomeListJSON::cleanTaxonOid(@taxon_oids);
    }
    if ( $oids && $oids ne "" ) {
        @taxon_oids = @$oids;
    }
    my @bin_oids    = OracleUtil::processTaxonBinOids("b");
    my $nSelections = scalar(@taxon_oids) + scalar(@bin_oids);
    if ( $nSelections == 0 || $nSelections > $max_genome_selections ) {
        webError("Please select 1 to $max_genome_selections genome(s).");
    }

    my @taxon_bin_oids;
    for my $taxon_oid (@taxon_oids) {
        push( @taxon_bin_oids, "t:$taxon_oid" );
    }
    for my $bin_oid (@bin_oids) {
        push( @taxon_bin_oids, "b:$bin_oid" );
    }

    print "<p>";
    print "$nFuncs functions and $nSelections genomes are selected.";
    print "</p>";

    $self->{selected} = {};
    my $selected = $self->{selected};
    for my $func_id (@func_ids) {
        $selected->{$func_id} = 1;
    }
    $self->save();

    my (
         $cog_ids_ref,   $kog_ids_ref,   $pfam_ids_ref,    $tigr_ids_ref,
         $ec_ids_ref,    $ko_ids_ref,    $tc_fam_nums_ref, $bc_ids_ref, $metacyc_ids_ref,
         $iterm_ids_ref, $ipway_ids_ref, $plist_ids_ref,   $unrecognized_ids_ref,
         $unsurported_func_ids_ref
      )
      = CartUtil::separateFuncIds(@func_ids);

    if (    scalar(@$cog_ids_ref) <= 0
         && scalar(@$kog_ids_ref) <= 0
         && scalar(@$pfam_ids_ref) <= 0
         && scalar(@$tigr_ids_ref) <= 0
         && scalar(@$ec_ids_ref) <= 0
         && scalar(@$ko_ids_ref) <= 0
         && scalar(@$tc_fam_nums_ref) <= 0
         && ( scalar(@$bc_ids_ref) <= 0 && $enable_biocluster )
         && scalar(@$metacyc_ids_ref) <= 0
         && scalar(@$iterm_ids_ref) <= 0
         && scalar(@$ipway_ids_ref) <= 0
         && scalar(@$plist_ids_ref) <= 0
         && ( scalar(@$unrecognized_ids_ref) > 0 || scalar(@$unsurported_func_ids_ref) ) > 0 )
    {
        webError("Unspported (such as GO and Interpro) or unrecognized functions in Function Profile.");
    }

    if ( scalar(@$unsurported_func_ids_ref) > 0 ) {
        print "<h5>Unspported functions: @$unsurported_func_ids_ref</h5>";
    }

    if ( scalar(@$unrecognized_ids_ref) > 0 ) {
        print "<h5>Unrecognized functions: @$unrecognized_ids_ref</h5>";
    }

    my $contact_oid = getContactOid();
    if ( scalar(@$ec_ids_ref) > 0 && $contact_oid ) {
        print "<h5>Note: MyIMG gene-enzyme annotations (if any) will replace default IMG gene-enzyme associations.</h5>\n";
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    ##
    #  z-norm set up
    #
    my %taxonOid2GeneCount;
    my %binOid2GeneCount;
    my %clusterScaleMeanStdDev;

    #    if ($znorm) {
    #        WebUtil::arrayRef2HashRef( \@taxon_oids, \%taxonOid2GeneCount,     0 );
    #        WebUtil::arrayRef2HashRef( \@bin_oids,   \%binOid2GeneCount,       0 );
    #        WebUtil::arrayRef2HashRef( \@func_ids,   \%clusterScaleMeanStdDev, "" );
    #        getTaxonGeneCount( $dbh, \%taxonOid2GeneCount );
    #        getBinGeneCount( $dbh, \%binOid2GeneCount );
    #        getClusterScaleMeanStdDev( $dbh, "dt_func_abundance", "func_id", \%clusterScaleMeanStdDev );
    #    }

    my %taxonBinOid2Name;
    my %taxonBinOid2Domain;
    if ( scalar(@taxon_oids) > 0 ) {
        my $taxon_oid_str = join( ',', @taxon_oids );

        # get taxon names
        my $sql = QueryUtil::getTaxonOidNameDomainSql($taxon_oid_str);
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $taxon_oid, $taxon_display_name, $domain ) = $cur->fetchrow();
            last if !$taxon_oid;
            $taxonBinOid2Name{"t:$taxon_oid"} = $taxon_display_name;
            $taxonBinOid2Domain{"t:$taxon_oid"} = substr( $domain, 0, 1 );
        }
        $cur->finish();
    }

    ## get MER-FS taxons
    my ( $dbTaxons_ref, $metaTaxons_ref ) = MerFsUtil::findTaxonsInFile( $dbh, @taxon_oids );
    my @dbTaxons   = @$dbTaxons_ref;
    my @metaTaxons = @$metaTaxons_ref;

    #    my $rclause    = WebUtil::urClause('gf.taxon_oid');
    #    my $imgClause  = WebUtil::imgClauseNoTaxon('gf.taxon_oid');
    #    my $rclause1   = WebUtil::urClause('g1.taxon');
    #    my $imgClause1 = WebUtil::imgClauseNoTaxon('g1.taxon');
    #    my $rclause2   = WebUtil::urClause('g.taxon');
    #    my $imgClause2 = WebUtil::imgClauseNoTaxon('g.taxon');

    my %funcId2Name = QueryUtil::fetchFuncIdAndName( $dbh, \@func_ids );
    my @recs;

    ## Taxon rows
    if ( scalar(@dbTaxons) > 0 ) {
        my $db_taxon_oid_str = join( ',', @dbTaxons );

        if ( scalar(@$cog_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'COG', $cog_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 't' );
        }

        if ( scalar(@$kog_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'KOG', $kog_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 't' );
        }

        if ( scalar(@$pfam_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'pfam', $pfam_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 't' );
        }

        if ( scalar(@$tigr_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'TIGR', $tigr_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 't' );
        }

        if ( scalar(@$ec_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'EC', $ec_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 't' );
        }

        if ( scalar(@$ko_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'KO', $ko_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 't' );
        }

        if ( scalar(@$tc_fam_nums_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'TC', $tc_fam_nums_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 't' );
        }

        if ( scalar(@$bc_ids_ref) > 0 && $enable_biocluster ) {
            processProfileForCharFunc_t(
                 $dbh,                 'BC',
                 $bc_ids_ref,          $db_taxon_oid_str,
                 \%taxonOid2GeneCount, \%clusterScaleMeanStdDev,
                 $znorm,               $contact_oid,
                 \@recs,               \%taxonBinOid2Name,
                 't',                  'BC:'
            );
        }

        if ( scalar(@$metacyc_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                 $dbh,                 'MetaCyc',
                 $metacyc_ids_ref,     $db_taxon_oid_str,
                 \%taxonOid2GeneCount, \%clusterScaleMeanStdDev,
                 $znorm,               $contact_oid,
                 \@recs,               \%taxonBinOid2Name,
                 't',                  'MetaCyc:'
            );
        }

        if ( scalar(@$iterm_ids_ref) > 0 ) {
            processProfileForNumFunc_t(
                $dbh, 'ITERM', $iterm_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 't',
                'ITERM:' );
        }

        if ( scalar(@$ipway_ids_ref) > 0 ) {
            processProfileForNumFunc_t(
                $dbh, 'IPWAY', $ipway_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 't',
                'IPWAY:' );
        }

        if ( scalar(@$plist_ids_ref) > 0 ) {
            processProfileForNumFunc_t(
                $dbh, 'PLIST', $plist_ids_ref, $db_taxon_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 't',
                'PLIST:' );
        }

    }

    ## Bin rows
    if ( scalar(@bin_oids) > 0 ) {
        my $bin_oid_str = join( ',', @bin_oids );

        # get bin display names
        my $sql = qq{
            select b.bin_oid, b.display_name, es.sample_display_name
    	    from bin b, env_sample_gold es
    	    where bin_oid in ( $bin_oid_str )
    	    and b.env_sample = es.sample_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $bin_oid, $bin_display_name, $es_display_name ) = $cur->fetchrow();
            last if !$bin_oid;
            $taxonBinOid2Name{"b:$bin_oid"}   = "$bin_display_name ($es_display_name)";
            $taxonBinOid2Domain{"b:$bin_oid"} = "b";
        }
        $cur->finish();

        if ( scalar(@$cog_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'COG', $cog_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b' );
        }

        if ( scalar(@$kog_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'KOG', $kog_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b' );
        }

        if ( scalar(@$pfam_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'pfam', $pfam_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b' );
        }

        if ( scalar(@$tigr_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'TIGR', $tigr_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b' );
        }

        if ( scalar(@$ec_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'EC', $ec_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b' );
        }

        if ( scalar(@$ko_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'KO', $ko_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b' );
        }

        if ( scalar(@$tc_fam_nums_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'TC', $tc_fam_nums_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b' );
        }

        if ( scalar(@$bc_ids_ref) > 0 && $enable_biocluster ) {
            processProfileForCharFunc_t(
                $dbh, 'BC', $bc_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b',
                'BC:' );
        }

        if ( scalar(@$metacyc_ids_ref) > 0 ) {
            processProfileForCharFunc_t(
                $dbh, 'MetaCyc', $metacyc_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b',
                'MetaCyc:' );
        }

        if ( scalar(@$iterm_ids_ref) > 0 ) {
            processProfileForNumFunc_t(
                $dbh, 'ITERM', $iterm_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b',
                'ITERM:' );
        }

        if ( scalar(@$ipway_ids_ref) > 0 ) {
            processProfileForNumFunc_t(
                $dbh, 'IPWAY', $ipway_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b',
                'IPWAY:' );
        }

        if ( scalar(@$plist_ids_ref) > 0 ) {
            processProfileForNumFunc_t(
                $dbh, 'PLIST', $plist_ids_ref, $bin_oid_str, \%taxonOid2GeneCount,
                \%clusterScaleMeanStdDev, $znorm, $contact_oid, \@recs, \%taxonBinOid2Name, 'b',
                'PLIST:' );
        }

    }

    if ( scalar(@metaTaxons) > 0 ) {
        my $meta_taxon_oid_str = join( ',', @metaTaxons );

        my $rclause   = WebUtil::urClause('g.taxon_oid');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

        if ( scalar(@$cog_ids_ref) > 0 ) {
            processProfileForCharFunc_merfs_t(
                $dbh, 'COG', $cog_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%taxonBinOid2Name, 't', '', $rclause, $imgClause
            );
        }

        if ( scalar(@$pfam_ids_ref) > 0 ) {
            processProfileForCharFunc_merfs_t(
                $dbh, 'pfam', $pfam_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%taxonBinOid2Name, 't', '', $rclause, $imgClause
            );
        }

        if ( scalar(@$tigr_ids_ref) > 0 ) {
            processProfileForCharFunc_merfs_t(
                $dbh, 'TIGR', $tigr_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%taxonBinOid2Name, 't', '', $rclause, $imgClause
            );
        }

        if ( scalar(@$ec_ids_ref) > 0 ) {
            processProfileForCharFunc_merfs_t(
                $dbh, 'EC', $ec_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%taxonBinOid2Name, 't', '', $rclause, $imgClause
            );
        }

        if ( scalar(@$ko_ids_ref) > 0 ) {
            processProfileForCharFunc_merfs_t(
                $dbh, 'KO', $ko_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%taxonBinOid2Name, 't', '', $rclause, $imgClause
            );
        }

        if ( scalar(@$bc_ids_ref) > 0 && $enable_biocluster ) {
            processProfileForCharFunc_merfs_t(
                $dbh, 'BC', $bc_ids_ref, $meta_taxon_oid_str, $data_type,
                \@recs, \%taxonBinOid2Name, 't', 'BC:', $rclause, $imgClause
            );
        }

        if ( scalar(@$metacyc_ids_ref) > 0 ) {
            my ($metacyc2ec_href, $ec2metacyc_href) = QueryUtil::fetchMetaCyc2EcHash( $dbh, $metacyc_ids_ref );
            #print Dumper($metacyc2ec_href);
            #print "<br/>\n";
            #print Dumper($ec2metacyc_href);
            #print "<br/>\n";
            my @ec_ids_tmp = keys %$ec2metacyc_href;
            #print "printFuncCartProfile_t() ec_ids_tmp: @ec_ids_tmp<br/>\n";

            if ( scalar(@ec_ids_tmp) > 0 ){
                my @recs_tmp;
                processProfileForCharFunc_merfs_t(
                    $dbh, 'EC', \@ec_ids_tmp, $meta_taxon_oid_str, $data_type,
                    \@recs_tmp, \%taxonBinOid2Name, 't', '', $rclause, $imgClause
                );

                my %typeOid2metacyc2cnt_h;
                for my $r (@recs_tmp) {
                    #print "printFuncCartProfile_t() recs_tmp r: $r<br/>\n";
                    my ($typeOid, $typeOidName, $ec_id, $cnt) = split( /\t/, $r );

                    my $metacyc_ids_ref = $ec2metacyc_href->{$ec_id};
                    for my $metacyc_id (@$metacyc_ids_ref) {
                        my $metacyc2cnt_href = $typeOid2metacyc2cnt_h{$typeOid};
                        if ($metacyc2cnt_href) {
                            $metacyc2cnt_href->{$metacyc_id} += $cnt;
                        }
                        else {
                            my %metacyc2cnt_h;
                            $metacyc2cnt_h{$metacyc_id} = $cnt;
                            $typeOid2metacyc2cnt_h{$typeOid} = \%metacyc2cnt_h;
                        }
                    }
                }
                #print Dumper(\%typeOid2metacyc2cnt_h);
                #print "<br/>\n";

                for my $typeOid (keys %typeOid2metacyc2cnt_h) {
                    my $metacyc2cnt_href = $typeOid2metacyc2cnt_h{$typeOid};
                    for my $metacyc_id (keys %$metacyc2cnt_href) {
                        my $cnt = $metacyc2cnt_href->{$metacyc_id};

                        my $r = "$typeOid\t";
                        $r .= $taxonBinOid2Name{$typeOid} . "\t";
                        $r .= "$metacyc_id\t";
                        $r .= "$cnt\t";
                        push( @recs, $r );
                    }
                }
            }
        }

    }

    #print "FuncCartStor::printFuncCartProfile_t() recs: @recs<br/>\n";
    if ( scalar(@recs) > 0 ) {
        #print "printFuncCartProfile_t() recs: @recs<br/>\n";

        my $url         = "$main_cgi?section=FuncProfile&page=funcProfile";
        my @colorMap_gc = ( "1:5:bisque", "5:100000:yellow", );
        my @colorMap_zn = ( "0.01:1:bisque", "1:100000:yellow", );
        my @colorMap    = @colorMap_gc;
        @colorMap = @colorMap_zn if $znorm;
        my $sortUrl = "$section_cgi&showFuncCartProfile_t";

        my $taxon_cell_sql_template;
        my $bin_cell_sql_template;
        my $fp = new FuncProfile(
              "func",   $$, $url, $sortUrl,
              \@taxon_bin_oids, \%taxonBinOid2Name, \%taxonBinOid2Domain, $data_type,
              \@func_ids,       \%funcId2Name, \@recs, \@colorMap,
              $taxon_cell_sql_template, $bin_cell_sql_template, $znorm
        );

        $fp->printProfile();
        printAllGenesLink( "FuncProfile", $type, $procId );
    } else {
        print "No profile data retrieved for the selected function(s) and genome(s).<br/>\n";
    }

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print "<br/>\n";
    print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );

    $self->save();
}

sub processProfileForCharFunc_t {
    my ( $dbh, $func_type, $func_ids_ref, $db_oid_str, $oid2GeneCount_href, $clusterScaleMeanStdDev_href, $znorm,
         $contact_oid, $recs_ref, $taxonBinOid2Name_ref, $taxon_type, $symbToAdd )
      = @_;

    my $func_id_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref );
    my $sql;
    if ( $taxon_type eq 't' ) {
        $sql = getFuncCartProfileTaxonQuery_t( $func_type, $func_id_str, $db_oid_str, $contact_oid );
    } elsif ( $taxon_type eq 'b' ) {
        $sql = getFuncCartProfileBinQuery_t( $func_type, $func_id_str, $db_oid_str, $contact_oid );
    }
    execFuncCartProfileSql_t( $dbh, $sql, $oid2GeneCount_href, $clusterScaleMeanStdDev_href, $znorm, $recs_ref,
                              $taxonBinOid2Name_ref, $taxon_type, $symbToAdd );
    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $func_id_str =~ /gtt_func_id/i );
}

sub processProfileForNumFunc_t {
    my ( $dbh, $func_type, $func_ids_ref, $db_oid_str, $oid2GeneCount_href, $clusterScaleMeanStdDev_href, $znorm,
         $contact_oid, $recs_ref, $taxonBinOid2Name_ref, $taxon_type, $symbToAdd )
      = @_;

    my $func_id_str = OracleUtil::getNumberIdsInClause( $dbh, @$func_ids_ref );
    my $sql;
    if ( $taxon_type eq 't' ) {
        $sql = getFuncCartProfileTaxonQuery_t( $func_type, $func_id_str, $db_oid_str, $contact_oid );
    } elsif ( $taxon_type eq 'b' ) {
        $sql = getFuncCartProfileBinQuery_t( $func_type, $func_id_str, $db_oid_str, $contact_oid );
    }
    execFuncCartProfileSql_t( $dbh, $sql, $oid2GeneCount_href, $clusterScaleMeanStdDev_href, $znorm, $recs_ref,
                              $taxonBinOid2Name_ref, $taxon_type, $symbToAdd );
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $func_id_str =~ /gtt_num_id/i );
}

sub execFuncCartProfileSql_t {
    my ( $dbh, $sql, $oid2GeneCount_href, $clusterScaleMeanStdDev_href, $znorm, $recs_ref, $taxonBinOid2Name_ref,
         $taxon_type, $symbToAdd )
      = @_;

    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $oid, $id, $gene_count ) = $cur->fetchrow();
            last if !$oid;
            my $total_gene_count = $oid2GeneCount_href->{$oid};
            $gene_count =
              WebUtil::geneCountWrap( $gene_count, $total_gene_count, $id, $clusterScaleMeanStdDev_href, $znorm );
            my $typeOid = "$taxon_type:$oid";
            my $r       = "$typeOid\t";
            $r .= $taxonBinOid2Name_ref->{$typeOid} . "\t";
            my $symbId = "$symbToAdd$id";
            $r .= "$symbId\t";
            $r .= "$gene_count\t";
            push( @$recs_ref, $r );
        }
        $cur->finish();
    }
}

sub processProfileForCharFunc_merfs_t {
    my (
         $dbh,      $func_type,            $func_ids_ref, $oid_str,   $data_type,
         $recs_ref, $taxonBinOid2Name_ref, $taxon_type,   $symbToAdd, $rclause, $imgClause
      )
      = @_;

    my $func_id_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref );
    my $sql;
    if ( $taxon_type eq 't' ) {
        $sql = getFuncCartProfileTaxonQuery_merfs_t( $func_type, $func_id_str, $oid_str, $data_type, $rclause, $imgClause );
    }
    execFuncCartProfileSql_merfs_t( $dbh, $sql, $recs_ref, $taxonBinOid2Name_ref, $taxon_type, $symbToAdd );
    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $func_id_str =~ /gtt_func_id/i );
}

sub execFuncCartProfileSql_merfs_t {
    my ( $dbh, $sql, $recs_ref, $taxonBinOid2Name_ref, $taxon_type, $symbToAdd ) = @_;

    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $oid, $id, $gene_count ) = $cur->fetchrow();
            last if !$id;

            my $typeOid = "$taxon_type:$oid";
            my $r       = "$typeOid\t";
            $r .= $taxonBinOid2Name_ref->{$typeOid} . "\t";
            my $symbId = "$symbToAdd$id";
            $r .= "$symbId\t";
            $r .= "$gene_count\t";
            push( @$recs_ref, $r );
        }
        $cur->finish();
    }
}

############################################################################
# printPhyloOccurProfiles - Print phylogenetic occurrence profiles.
############################################################################
sub printPhyloOccurProfiles {

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my @taxon_oids = OracleUtil::processTaxonBinOids("t");
    if ($enable_genomelistJson) {
        @taxon_oids = param('genomeFilterSelections');
        @taxon_oids = GenomeListJSON::cleanTaxonOid(@taxon_oids);
    }
    @taxon_oids = QueryUtil::fetchTaxonsOfDomainABE($dbh, \@taxon_oids);
    if ( scalar(@taxon_oids) == 0 ) {
        webError("Please select at lease 1 genome(s) that belong to Archaea, Bacteria or Eukarya.");
    }

    my @func_ids = param("func_id");
    @func_ids = removeDuplicate(@func_ids);
    if ( scalar(@func_ids) == 0 ) {
        webError("Please select at least one function.");
    }

    my (
         $cog_ids_ref,   $kog_ids_ref,   $pfam_ids_ref,    $tigr_ids_ref,
         $ec_ids_ref,    $ko_ids_ref,    $tc_fam_nums_ref, $bc_ids_ref, $metacyc_ids_ref,
         $iterm_ids_ref, $ipway_ids_ref, $plist_ids_ref,   $unrecognized_ids_ref,
         $unsurported_func_ids_ref
      )
      = CartUtil::separateFuncIds(@func_ids);

    if (    scalar(@$cog_ids_ref) <= 0
         && scalar(@$kog_ids_ref) <= 0
         && scalar(@$pfam_ids_ref) <= 0
         && scalar(@$tigr_ids_ref) <= 0
         && scalar(@$ec_ids_ref) <= 0
         && scalar(@$ko_ids_ref) <= 0
         && scalar(@$tc_fam_nums_ref) <= 0
         && ( scalar(@$bc_ids_ref) <= 0 && $enable_biocluster )
         && scalar(@$metacyc_ids_ref) <= 0
         && scalar(@$iterm_ids_ref) <= 0
         && scalar(@$ipway_ids_ref) <= 0
         && scalar(@$plist_ids_ref) <= 0
         && ( scalar(@$unrecognized_ids_ref) > 0 || scalar(@$unsurported_func_ids_ref) ) > 0 )
    {
        webError("Unspported (such as GO and Interpro) or unrecognized functions in Phylogenetic Occurrence Profile.");
    }

    if ( scalar(@$unsurported_func_ids_ref) > 0 ) {
        print "<h5>Unspported functions: @$unsurported_func_ids_ref</h5>";
    }

    if ( scalar(@$unrecognized_ids_ref) > 0 ) {
        print "<h5>Unrecognized functions: @$unrecognized_ids_ref</h5>";
    }

    if ( ( scalar(@func_ids) - scalar(@$unsurported_func_ids_ref) - scalar(@$unrecognized_ids_ref) ) > $maxProfileOccurIds )
    {
        webError("Please select no more than $maxProfileOccurIds functions.");
    }

    ### Load ID information
    my @idRecs;
    my %idRecsHash;
    my %funcId2Name = QueryUtil::fetchFuncIdAndName( $dbh, \@func_ids );
    for my $id ( keys %funcId2Name ) {
        my $name = $funcId2Name{$id};

        my %taxons;
        my $rh = {
                   id           => $id,
                   name         => $name,
                   url          => "#",
                   taxonOidHash => \%taxons,
        };
        push( @idRecs, $rh );
        $idRecsHash{$id} = $rh;
    }

    ### Load taxonomic hits information
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    if ( scalar(@$cog_ids_ref) > 0 ) {
        processPhyloOccurProfileForCharFunc( $dbh, \@taxon_oids, 'COG', $cog_ids_ref, \%idRecsHash, '', $rclause, $imgClause );
    }

    if ( scalar(@$kog_ids_ref) > 0 ) {
        processPhyloOccurProfileForCharFunc( $dbh, \@taxon_oids, 'KOG', $kog_ids_ref, \%idRecsHash, '', $rclause, $imgClause );
    }

    if ( scalar(@$pfam_ids_ref) > 0 ) {
        processPhyloOccurProfileForCharFunc( $dbh, \@taxon_oids, 'pfam', $pfam_ids_ref, \%idRecsHash, '', $rclause, $imgClause );
    }

    if ( scalar(@$tigr_ids_ref) > 0 ) {
        processPhyloOccurProfileForCharFunc( $dbh, \@taxon_oids, 'TIGR', $tigr_ids_ref, \%idRecsHash, '', $rclause, $imgClause );
    }

    if ( scalar(@$ec_ids_ref) > 0 ) {
        processPhyloOccurProfileForCharFunc( $dbh, \@taxon_oids, 'EC', $ec_ids_ref, \%idRecsHash, '', $rclause, $imgClause );
    }

    if ( scalar(@$ko_ids_ref) > 0 ) {
        processPhyloOccurProfileForCharFunc( $dbh, \@taxon_oids, 'KO', $ko_ids_ref, \%idRecsHash, '', $rclause, $imgClause );
    }

    if ( scalar(@$tc_fam_nums_ref) > 0 ) {
        processPhyloOccurProfileForCharFunc( $dbh, \@taxon_oids, 'TC', $tc_fam_nums_ref, \%idRecsHash, '', $rclause, $imgClause );
    }

    if ( scalar(@$bc_ids_ref) > 0 && $enable_biocluster ) {
        processPhyloOccurProfileForCharFunc( $dbh, \@taxon_oids, 'BC', $bc_ids_ref, \%idRecsHash, 'BC:', $rclause,
                                             $imgClause );
    }

    if ( scalar(@$metacyc_ids_ref) > 0 ) {
        processPhyloOccurProfileForCharFunc( $dbh, \@taxon_oids, 'MetaCyc', $metacyc_ids_ref, \%idRecsHash, 'MetaCyc:', $rclause,
                                             $imgClause );
    }

    if ( scalar(@$iterm_ids_ref) > 0 ) {
        processPhyloOccurProfileForNumFunc( $dbh, \@taxon_oids, 'ITERM', $iterm_ids_ref, \%idRecsHash, 'ITERM:', $rclause, $imgClause );
    }

    if ( scalar(@$ipway_ids_ref) > 0 ) {
        processPhyloOccurProfileForNumFunc( $dbh, \@taxon_oids, 'IPWAY', $ipway_ids_ref, \%idRecsHash, 'IPWAY:', $rclause, $imgClause );
    }

    if ( scalar(@$plist_ids_ref) > 0 ) {
        processPhyloOccurProfileForNumFunc( $dbh, \@taxon_oids, 'PLIST', $plist_ids_ref, \%idRecsHash, 'PLIST:', $rclause, $imgClause );
    }

    #print Dumper(\%idRecsHash);
    #print "<br/>\n";

    ## Print it out as an alignment.
    require PhyloOccur;
    my $s = "Profiles are based on instantiation ";
    $s .= "of a function in a genome.\n";
    $s .= "A dot '.' means there is no instantiation.<br/>\n";
    PhyloOccur::printAlignment( \@taxon_oids, \@idRecs, $s );

    printStatusLine( "Loaded.", 2 );
}

sub processPhyloOccurProfileForCharFunc {
    my ( $dbh, $taxon_oids_ref, $func_type, $func_ids_ref, $idRecsH_ref, $symbToAdd, $rclause, $imgClause ) = @_;

    my $taxon_oids_str = OracleUtil::getNumberIdsInClause1( $dbh, @$taxon_oids_ref );
    my $func_id_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref );
    my $sql = getPhyloOccurProfileQuery( $taxon_oids_str, $func_type, $func_id_str, $rclause, $imgClause );
    execPhyloOccurProfileSql( $dbh, $sql, $idRecsH_ref, $symbToAdd );
    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $func_id_str =~ /gtt_func_id/i );
    OracleUtil::truncTable( $dbh, "gtt_num_id1" )
      if ( $taxon_oids_str =~ /gtt_num_id1/i );
}

sub processPhyloOccurProfileForNumFunc {
    my ( $dbh, $taxon_oids_ref, $func_type, $func_ids_ref, $idRecsH_ref, $symbToAdd, $rclause, $imgClause ) = @_;

    my $taxon_oids_str = OracleUtil::getNumberIdsInClause1( $dbh, @$taxon_oids_ref );
    my $func_id_str = OracleUtil::getNumberIdsInClause( $dbh, @$func_ids_ref );
    my $sql = getPhyloOccurProfileQuery( $taxon_oids_str, $func_type, $func_id_str, $rclause, $imgClause );
    execPhyloOccurProfileSql( $dbh, $sql, $idRecsH_ref, $symbToAdd );
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $func_id_str =~ /gtt_num_id/i );
    OracleUtil::truncTable( $dbh, "gtt_num_id1" )
      if ( $taxon_oids_str =~ /gtt_num_id1/i );
}

sub execPhyloOccurProfileSql {
    my ( $dbh, $sql, $idRecsH_ref, $symbToAdd ) = @_;

    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id, $taxon ) = $cur->fetchrow();
            last if !$id;
            my $symbId = "$symbToAdd$id";
            my $rh     = $idRecsH_ref->{$symbId};
            if ( !defined($rh) ) {
                webDie("printPhyloOccurProfiles: cannot find '$symbId'\n");
            }
            my $taxonOidHash = $rh->{taxonOidHash};
            $taxonOidHash->{$taxon} = 1;
        }
        $cur->finish();
    }
}

############################################################################
# printExportFuncCart - Show stuff for exporting function cart.
############################################################################
sub printExportFuncCart {
    my ($self) = @_;

    my @func_ids = param("func_id");
    @func_ids = removeDuplicate(@func_ids);

    # from table or hidden vars - ken
    #    webLog(" ======= " . param( "func_id" ) . "\n");
    #     webLog(" ======= " . @func_ids  . "\n");

    if ( scalar(@func_ids) == 0 ) {
        main::printAppHeader();
        webError("You must select at least one function to export.");
    }
    my %func_ids_h = WebUtil::array2Hash(@func_ids);

    printExcelHeader("func_export$$.xls");
    print "func_id\t";
    print "func_name\n";

    my $recs_ref = $self->{recs};
    my @keys     = sort( keys(%$recs_ref) );
    for my $k (@keys) {
        my $r = $recs_ref->{$k};
        my ( $func_id, $func_name, undef ) = split( /\t/, $r );
        next if $func_ids_h{$func_id} eq "";
        print "$func_id\t";
        print "$func_name\n";
    }
    WebUtil::webExit(0);
}

############################################################################
# uploadFuncCart - Upload function cart.
############################################################################
sub uploadFuncCart {
    my ($self) = @_;

    my $errMsg;
    my @func_ids;
    require MyIMG;
    if ( !MyIMG::uploadIdsFromFile( "func_id,Function ID", \@func_ids, \$errMsg ) ) {
        printStatusLine( "Error.", 2 );
        webError($errMsg);
    }

    $self->addFuncBatch( \@func_ids );
}

############################################################################
# printJavaScript - Print javascript code for this section.
############################################################################
sub printJavaScript {
    print "<script language='JavaScript' type='text/javascript'>\n";
    print qq{
         function selectFuncIds( x ) {
             var els = document.getElementsByName( "func_id" );
             for( var i = 0; i < els.length; i++ ) {
                 var e = els[ i ];
                 if( e.type == "checkbox" ) {
                     e.checked = ( x == 0 ? false : true );
                 }
             }
         }
     };
    print "</script>\n";
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
#  printPwayAssertionProfile_s - Print straight version of pathway
#    assertion profile.
############################################################################
sub printPwayAssertionProfile_s {
    my ($self) = @_;

    my $type   = $self->{type};
    my $procId = $self->{procId};

    print "<h1>IMG Pathways vs. Genomes Profile</h1>";

    my @func_ids    = param("func_id");
    @func_ids = removeDuplicate(@func_ids);
    my @taxon_oids  = OracleUtil::processTaxonBinOids("t");
    if ( $enable_genomelistJson ) {
        @taxon_oids = param('genomeFilterSelections');
        @taxon_oids = GenomeListJSON::cleanTaxonOid(@taxon_oids);
    }
    my @bin_oids    = OracleUtil::processTaxonBinOids("b");
    my $nSelections = scalar(@taxon_oids) + scalar(@bin_oids);
    my $nTaxons     = @taxon_oids;
    if ( $nTaxons == 0 || $nTaxons > $max_taxon_batch ) {
        webError("Please select 1 to $max_taxon_batch genomes.");
    }

    $self->{selected} = {};
    my $selected = $self->{selected};
    my @pathway_oids;
    for my $func_id (@func_ids) {
        $selected->{$func_id} = 1;
        if ( $func_id =~ /IPWAY:/ ) {
            my $pathway_oid = $func_id;
            $pathway_oid =~ s/IPWAY://;
            push( @pathway_oids, $pathway_oid );
        }
    }
    $self->save();
    my $nPwayOids = @pathway_oids;
    if ( $nPwayOids == 0 || $nPwayOids > $max_func_batch ) {
        webError("Please select 1 to $max_func_batch IMG pathways.");
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my %evidence;
    #getPwayAssertEvidence( $dbh, \@pathway_oids, \@taxon_oids, \%evidence );

    ## Row labels
    my $pathway_oid_str = join( ',', @pathway_oids );
    my $sql = qq{
        select pw.pathway_oid, pw.pathway_name
    	from img_pathway pw
    	where pw.pathway_oid in ( $pathway_oid_str )
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

    ## Column labels
    my $taxon_oid_str   = join( ',', @taxon_oids );
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

    ## Cells present
    my $rclause   = WebUtil::urClause('pwa.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('pwa.taxon');
    my $sql       = qq{
        select distinct pwa.pathway_oid, pwa.taxon, pwa.status, pwa.evidence
    	from img_pathway_assertions pwa
    	where pwa.pathway_oid in ( $pathway_oid_str )
    	and pwa.taxon in ( $taxon_oid_str )
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
        } elsif ( $status eq 'not asserted' ) {
            $asserted{$k} = 'a';
        } elsif ( $status eq 'unknown' ) {
            $asserted{$k} = 'u';
        }
        $evidence{$k} = $evid;
    }
    $cur->finish();

    ## Show table
    printAssertionNote();

    printHint("Mouse over genome abbreviation to see full name.<br/>\n");

#### BEGIN updated table using InnerTable +BSJ 03/01/10

    my $it = new InnerTable( 1, "ImgPathwaysGenome$$", "ImgPathwaysGenome", 0 );
    my $sd = $it->getSdDelim();                                                    # sort delimiter

    $it->addColSpec( "IMG Pathway", "char asc" );

    # sort the columns array by name (subscript 1) +BSJ 03/03/10
    @colLabels = sort {
        my @first  = split( /\t/, $a );
        my @second = split( /\t/, $b );
        $first[1] cmp $second[1];
    } @colLabels;

    for ( my $j = 0 ; $j < scalar(@colLabels); $j++ ) {
        my ( $colId, $colName ) = split( /\t/, $colLabels[$j] );

        #my $abbr = WebUtil::abbrColName( $colId, $colName, 0 );
        my $abbr = WebUtil::abbrColName( $colId, $colName, 1 );

        # Leave "title" attribute blank if in YUI mode.
        # Tooltip passed to it->addColSpec +BSJ 02/26/10
        $abbr =~ s/$colName//g;

        #$it->addColSpec( $abbr, "", "right", "", $colName );
        $it->addColSpec( $abbr, "char asc", "right", "", $colName );
    }
    for ( my $i = 0 ; $i < scalar(@rowLabels); $i++ ) {
        my ( $rowId, $rowName ) = split( /\t/, $rowLabels[$i] );
        my $row;

        my $url = "$main_cgi?section=ImgPwayBrowser";
        $url .= "&page=imgPwayDetail";
        $url .= "&pway_oid=$rowId";
        my $pathway_oid = FuncUtil::pwayOidPadded($rowId);

        $row .=
          $pathway_oid . " - " . escHtml($rowName) . $sd . alink( $url, $pathway_oid ) . " - " . escHtml($rowName) . "\t";

        for ( my $j = 0 ; $j < scalar(@colLabels); $j++ ) {
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
            my $vPadding    = 4;
            my $commonStyle = "padding:${vPadding}px 4px; white-space:nowrap;";

            if ( !$a ) {
                $a = "N/A";
            }
            $row .= "$a$x2" . $sd;
            $row .= "<span style='$commonStyle'>";
            if ( $a eq "N/A" ) {
                $row .= "N/A ";
            } else {
                $row .= alink( $url, "<i>$a</i>", "assertDetail$$", 1 );
            }
            $row .= "$x2</span>\t";
        }
        $it->addRow($row);
    }
    $it->printOuterTable(1);

#### END updated table using InnerTable +BSJ 03/01/10

    printStatusLine( "Loaded.", 2 );

    #$dbh->disconnect();
}

############################################################################
#  printPwayAssertionProfile_t - Print transposed version of pathway
#    assertion profile.
############################################################################
sub printPwayAssertionProfile_t {
    my ($self) = @_;

    my $type   = $self->{type};
    my $procId = $self->{procId};

    print "<h1>Genomes vs. IMG Pathways Profile</h1>";

    my @func_ids    = param("func_id");
    @func_ids = removeDuplicate(@func_ids);
    my @taxon_oids  = OracleUtil::processTaxonBinOids("t");
    if ( $enable_genomelistJson ) {
        @taxon_oids = param('genomeFilterSelections');
        @taxon_oids = GenomeListJSON::cleanTaxonOid(@taxon_oids);
    }
    my @bin_oids    = OracleUtil::processTaxonBinOids("b");
    my $nSelections = scalar(@taxon_oids) + scalar(@bin_oids);
    my $nTaxons     = @taxon_oids;
    if ( $nTaxons == 0 || $nTaxons > $max_taxon_batch ) {
        webError("Please select 1 to $max_taxon_batch genomes.");
    }

    $self->{selected} = {};
    my $selected = $self->{selected};
    my @pathway_oids;
    for my $func_id (@func_ids) {
        $selected->{$func_id} = 1;
        if ( $func_id =~ /IPWAY:/ ) {
            my $pathway_oid = $func_id;
            $pathway_oid =~ s/IPWAY://;
            push( @pathway_oids, $pathway_oid );
        }
    }
    $self->save();
    my $nPwayOids = @pathway_oids;
    if ( $nPwayOids == 0 || $nPwayOids > $max_func_batch ) {
        webError("Please select 1 to $max_func_batch IMG pathways.");
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my %evidence;
    #getPwayAssertEvidence( $dbh, \@pathway_oids, \@taxon_oids, \%evidence );

    ## Row labels
    my $taxon_oid_str   = join( ',', @taxon_oids );
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

    ## Column labels
    my $pathway_oid_str = join( ',', @pathway_oids );
    my $sql = qq{
        select pw.pathway_oid, pw.pathway_name
    	from img_pathway pw
    	where pw.pathway_oid in ( $pathway_oid_str )
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

    ## Cells present
    my $rclause   = WebUtil::urClause('pwa.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('pwa.taxon');
    my $sql       = qq{
        select distinct pwa.pathway_oid, pwa.taxon, pwa.status, pwa.evidence
    	from img_pathway_assertions pwa
    	where pwa.pathway_oid in ( $pathway_oid_str )
    	and pwa.taxon in ( $taxon_oid_str )
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
        } elsif ( $status eq 'not asserted' ) {
            $asserted{$k} = 'a';
        } elsif ( $status eq 'unknown' ) {
            $asserted{$k} = 'u';
        }
        $evidence{$k} = $evid;
    }

    #    for ( ; ; ) {
    #        my ( $pathway_oid, $taxon, $status, $evid ) = $cur->fetchrow();
    #        last if !$pathway_oid;
    #        my $k = "$pathway_oid-$taxon";
    #        $asserted{$k} = 1;
    #    }
    $cur->finish();

    ## Show table
    printAssertionNote();

    printHint( "Mouse over pathway object identifier "
        . "to see full pathway name.<br/>\n" );

#### BEGIN updated table using InnerTable +BSJ 03/01/10

    my $it = new InnerTable( 1, "ImgGenomePathways$$", "ImgGenomePathways", 0 );
    my $sd = $it->getSdDelim();                                                    # sort delimiter

    $it->addColSpec( "Genome", "char asc" );

    # sort the columns array by colId (subscript 0) +BSJ 03/03/10
    @colLabels = sort @colLabels;

    for ( my $j = 0 ; $j < scalar(@colLabels); $j++ ) {
        my ( $colId, $colName ) = split( /\t/, $colLabels[$j] );
        my $pathway_oid = FuncUtil::pwayOidPadded($colId);
        my $url         = "$main_cgi?section=ImgPwayBrowser";
        $url .= "&page=imgPwayDetail";
        $url .= "&pway_oid=$pathway_oid";

        #        $it->addColSpec(
        #            "<a href='$url' title='$colName'>IPWAY:<br>$pathway_oid </a>",
        #            "", "left", "", $colName );
        $it->addColSpec( "IPWAY:<br>$pathway_oid", "char asc", "left", "", $colName );
    }
    for ( my $i = 0 ; $i < scalar(@rowLabels); $i++ ) {
        my ( $rowId, $rowName ) = split( /\t/, $rowLabels[$i] );
        my $row;

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$rowId";
        $row .= $rowName . $sd . alink( $url, $rowName ) . "\t";

        for ( my $j = 0 ; $j < scalar(@colLabels); $j++ ) {
            my ( $colId, $colName ) = split( /\t/, $colLabels[$j] );
            my $k      = "$colId-$rowId";
            my $a      = $asserted{$k};
            my $evid_k = $k;
            my $x      = $evidence{$evid_k};
            $x = "0/0" if $x eq "";
            my $x2 = "($x)";
            my ( $nGenes, $nRxns ) = split( /\//, $x );
            my $shouldBeAsserted = 0;

            if ( $nGenes > 0 && $nRxns > 0 && $nGenes >= $nRxns && !$a ) {
                $shouldBeAsserted = 1;
            }
            my $url = "$main_cgi?section=ImgPwayBrowser";
            $url .= "&page=pwayTaxonDetail";
            $url .= "&pway_oid=$colId";
            $url .= "&taxon_oid=$rowId";

            my $vPadding    = 4;
            my $commonStyle = "padding:${vPadding}px 8px; white-space:nowrap;";

            if ( !$a ) {
                $a = "N/A";
            }
            $row .= "$a$x2" . $sd;
            $row .= "<span style='$commonStyle'>";
            if ( $a eq "N/A" ) {
                $row .= "N/A ";
            } else {
                $row .= alink( $url, "<i>$a</i>", "assertDetail$$", 1 );
            }
            $row .= "$x2</span>\t";
        }
        $it->addRow($row);
    }
    $it->printOuterTable(1);

#### END updated table using InnerTable +BSJ 03/01/10

    printStatusLine( "Loaded.", 2 );

    #$dbh->disconnect();
}

############################################################################
# printallGenesLink
############################################################################
sub printAllGenesLink {
    my ( $profileClass, $type, $procId ) = @_;

    $procId = $$ if $procId eq "";

    my $url = "$section_cgi&page=allGenes&type=$type";
    $url .= "&profileClass=$profileClass&procId=$procId";

    print "<p>\n";
    print alink( $url, "Show all genes" );
    print "</p>\n";
}

############################################################################
# printAllGenes - Show list of all genes.
############################################################################
sub printAllGenes {
    my ($self) = @_;

    my $type         = param("type");
    my $profileClass = param("profileClass");
    my $procId       = param("procId");

    my ( $taxon_oids_ref, $bin_oids_ref, $rowIds_ref );

    my $data_type_f;
    if ( $profileClass eq "PhyloProfile" ) {
        require PhyloProfile;
        my $pp = new PhyloProfile( $type, $procId );
        $taxon_oids_ref = $pp->{taxon_oids};
        $bin_oids_ref   = $pp->{bin_oids};
        $rowIds_ref     = $pp->{rowIds};
        $data_type_f    = $pp->{data_type};
    } elsif ( $profileClass eq "FuncProfile" ) {
        require FuncProfile;
        my $fp = new FuncProfile( $type, $procId );
        my @taxon_oids;
        my @bin_oids;
        my $taxonBinOids_ref = $fp->{taxonBinOids};
        for my $tbOid (@$taxonBinOids_ref) {
            my ( $t, $oid ) = split( /:/, $tbOid );
            if ( $t eq "b" ) {    # bin
                push( @bin_oids, $oid );
            } else {
                push( @taxon_oids, $oid );
            }
        }
        $taxon_oids_ref = \@taxon_oids;
        $bin_oids_ref   = \@bin_oids;
        $rowIds_ref     = $fp->{colIds};
        $data_type_f    = $fp->{data_type};
    } else {
        webDie("printAllGenes: unknown profileClass='$profileClass'\n");
    }

    if (    ( $taxon_oids_ref eq '' || scalar(@$taxon_oids_ref) <= 0 )
         && ( $bin_oids_ref eq '' || scalar(@$bin_oids_ref) <= 0 ) )
    {
        webError("No taxons or bins.\n");
    }
    if ( $rowIds_ref eq '' && scalar(@$rowIds_ref) <= 0 ) {
        webError("No functions.\n");
    }

    ## Deal with Oracle 1000 limit in "in" clause.
    if ( scalar(@$taxon_oids_ref) > 1000 ) {
        webError("Unsupported: Oracle SQL limit. Too many taxons\n");
    }
    if ( scalar(@$bin_oids_ref) > 1000 ) {
        webError("Unsupported: Oracle SQL limit. Too many bins\n");
    }
    if ( $rowIds_ref ne '' && scalar(@$rowIds_ref) > 1000 ) {
        webError("Unsupported: Oracle SQL limit. Too many functions\n");
    }

    print "<h1>All Genes</h1>\n";
    printMainForm();

    my (
         $cog_ids_ref,   $kog_ids_ref,   $pfam_ids_ref,    $tigr_ids_ref,
         $ec_ids_ref,    $ko_ids_ref,    $tc_fam_nums_ref, $bc_ids_ref, $metacyc_ids_ref,
         $iterm_ids_ref, $ipway_ids_ref, $plist_ids_ref,   $unrecognized_ids_ref,
         $unsurported_func_ids_ref
      )
      = CartUtil::separateFuncIds(@$rowIds_ref);

    if ( scalar(@$unsurported_func_ids_ref) > 0 ) {
        print "<h5>Unspported functions: @$unsurported_func_ids_ref</h5>";
    }

    if ( scalar(@$unrecognized_ids_ref) > 0 ) {
        print "<h5>Unrecognized functions: @$unrecognized_ids_ref</h5>";
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my ( $dbTaxons_ref, $metaTaxons_ref ) = MerFsUtil::findTaxonsInFile( $dbh, @$taxon_oids_ref );
    my @dbTaxons   = @$dbTaxons_ref;
    my @metaTaxons = @$metaTaxons_ref;

    my $it = new InnerTable( 1, "phyloProfileAllGenes$$", "phyloProfileGenes", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",      "char asc", "left" );
    $it->addColSpec( "Product Name", "char asc", "left" );
    $it->addColSpec( "Func ID",      "char asc", "left" );

    #$it->addColSpec( "Func Name",    "char asc", "left" );
    $it->addColSpec( "Scaffold ID", "char asc", "left" );
    $it->addColSpec( "Genome/Bin",  "char asc", "left" );
    my $sd = $it->getSdDelim();

    my $count = 0;
    my %done_genes;
    if ( scalar(@dbTaxons) > 0 ) {
        my $db_taxon_oid_str = join( ',', @dbTaxons );

        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');

        if ( scalar(@$cog_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'COG', $cog_ids_ref, $db_taxon_oid_str, 't' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$kog_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'KOG', $kog_ids_ref, $db_taxon_oid_str, 't' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$pfam_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'pfam', $pfam_ids_ref, $db_taxon_oid_str, 't' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$tigr_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'TIGR', $tigr_ids_ref, $db_taxon_oid_str, 't' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$ec_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'EC', $ec_ids_ref, $db_taxon_oid_str, 't' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$ko_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'KO', $ko_ids_ref, $db_taxon_oid_str, 't' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$tc_fam_nums_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'TC', $tc_fam_nums_ref, $db_taxon_oid_str, 't' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$bc_ids_ref) > 0 && $enable_biocluster ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'BC', $bc_ids_ref, $db_taxon_oid_str, 't', 'BC:' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$metacyc_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'MetaCyc', $metacyc_ids_ref, $db_taxon_oid_str, 't', 'MetaCyc:' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$iterm_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForNumFunc( $dbh, $it, $sd, 'ITERM', $iterm_ids_ref, $db_taxon_oid_str, 't', 'ITERM:' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$ipway_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForNumFunc( $dbh, $it, $sd, 'IPWAY', $ipway_ids_ref, $db_taxon_oid_str, 't', 'IPWAY:' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$plist_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForNumFunc( $dbh, $it, $sd, 'PLIST', $plist_ids_ref, $db_taxon_oid_str, 't', 'PLIST:' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

    }

    if ( scalar(@$bin_oids_ref) > 0 ) {
        my $bin_oid_str = join( ',', @$bin_oids_ref );

        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        if ( scalar(@$cog_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'COG', $cog_ids_ref, $bin_oid_str, 'b' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$kog_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'KOG', $kog_ids_ref, $bin_oid_str, 'b' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$pfam_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'pfam', $pfam_ids_ref, $bin_oid_str, 'b' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$tigr_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'TIGR', $tigr_ids_ref, $bin_oid_str, 'b' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$ec_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'EC', $ec_ids_ref, $bin_oid_str, 'b' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$ko_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'KO', $ko_ids_ref, $bin_oid_str, 'b' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$tc_fam_nums_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'TC', $tc_fam_nums_ref, $bin_oid_str, 'b' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$bc_ids_ref) > 0 && $enable_biocluster ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'BC', $bc_ids_ref, $bin_oid_str, 'b', 'BC:' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$metacyc_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForCharFunc( $dbh, $it, $sd, 'MetaCyc', $metacyc_ids_ref, $bin_oid_str, 'b', 'MetaCyc:' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$iterm_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForNumFunc( $dbh, $it, $sd, 'ITERM', $iterm_ids_ref, $bin_oid_str, 'b', 'ITERM:' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$ipway_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForNumFunc( $dbh, $it, $sd, 'IPWAY', $ipway_ids_ref, $bin_oid_str, 'b', 'IPWAY:' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

        if ( scalar(@$plist_ids_ref) > 0 ) {
            my ($cnt, $gene_oids_href) = processAllGenesForNumFunc( $dbh, $it, $sd, 'PLIST', $plist_ids_ref, $bin_oid_str, 'b', 'PLIST:' );
            for my $key (keys %$gene_oids_href) {
                $done_genes{$key} = 1;
            }
            $count += $cnt;
        }

    }

    # file
    if ( scalar(@metaTaxons) > 0 ) {
        printStartWorkingDiv();
        print "<p>Retrieving MER-FS gene information ...<br/>\n";

        my %taxon_name_h = QueryUtil::fetchTaxonOid2NameHash( $dbh, \@metaTaxons );
        my %funcId2Name  = QueryUtil::fetchFuncIdAndName( $dbh, $rowIds_ref );

        my @type_list = MetaUtil::getDataTypeList( $data_type_f );

        for my $t_oid (@metaTaxons) {
            for my $data_type ( @type_list ) {
                for my $func_id (@$rowIds_ref) {
                    my @func_genes = MetaUtil::getTaxonFuncMetaGenes( $t_oid, $data_type, $func_id );

                    my %genes_h;
                    for my $gene_oid (@func_genes) {
                        my $workspace_id = "$t_oid $data_type $gene_oid";
                        $genes_h{$workspace_id} = 1;
                    }

                    my %gene_name_h;
                    my %gene_info_h;
                    MetaUtil::getAllGeneNames( \%genes_h, \%gene_name_h, 1 );
                    MetaUtil::getAllGeneInfo( \%genes_h, \%gene_info_h, '', 1 );

                    for my $gene_oid (@func_genes) {
                        my $r;
                        my $workspace_id = "$t_oid $data_type $gene_oid";
                        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$workspace_id' " . "  /> \t";
                        my $url = "$main_cgi?section=MetaGeneDetail";
                        $url .= "&page=metaGeneDetail&taxon_oid=$t_oid" . "&data_type=$data_type&gene_oid=$gene_oid";
                        $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";

                        my $gene_name = $gene_name_h{$workspace_id};
                        if ( !$gene_name ) {
                            $gene_name = "hypothetical protein";
                        }
                        $r .= $gene_name . $sd . $gene_name . "\t";

                        $r .= $func_id . $sd . $func_id . "\t";

                        #my $func_name = $funcId2Name{$func_id};
                        #$r .= $func_name . $sd . $func_name . "\t";

                        my (
                             $locus_type, $locus_tag,    $gene_display_name, $start_coord, $end_coord,
                             $strand,     $scaffold_oid, $tid2,              $dtype2
                          )
                          = split( /\t/, $gene_info_h{$workspace_id} );

                        my $scaffold_url =
                            "$main_cgi?section=MetaDetail"
                          . "&page=metaScaffoldDetail&scaffold_oid=$scaffold_oid"
                          . "&taxon_oid=$t_oid&data_type=$data_type";
                        $scaffold_url = alink( $scaffold_url, $scaffold_oid );
                        $r .= $scaffold_oid . $sd . $scaffold_url . "\t";

                        my $t_url = "$main_cgi?section=MetaDetail&page=metaDetail&taxon_oid=$t_oid";
                        $r .= $taxon_name_h{$t_oid} . $sd . alink( $t_url, $taxon_name_h{$t_oid} ) . "\t";

                        $it->addRow($r);

                        $done_genes{$workspace_id} = 1;
                        $count++;
                    }
                }
            }
        }

        printEndWorkingDiv();
    }

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    my @done_genes = keys %done_genes;
    my $done_genes_num = scalar(@done_genes);
    printStatusLine( "$done_genes_num genes / $count entries retrieved.", 2 );
    print end_form();

}

sub processAllGenesForCharFunc {
    my ( $dbh, $it, $sd, $func_type, $func_ids_ref, $db_oid_str, $taxon_type, $symbToAdd ) = @_;

    my $func_id_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref );
    my $sql;
    if ( $taxon_type eq 't' ) {
        $sql = getAllGenesTaxonQuery( $func_type, $func_id_str, $db_oid_str );
    } elsif ( $taxon_type eq 'b' ) {
        $sql = getAllGenesBinQuery( $func_type, $func_id_str, $db_oid_str );
    }
    my ($cnt, $gene_oids_href) = execAllGenesSql( $dbh, $it, $sd, $sql, $taxon_type, $symbToAdd );
    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $func_id_str =~ /gtt_func_id/i );

    return ($cnt, $gene_oids_href);
}

sub processAllGenesForNumFunc {
    my ( $dbh, $it, $sd, $func_type, $func_ids_ref, $db_oid_str, $taxon_type, $symbToAdd ) = @_;

    my $func_id_str = OracleUtil::getNumberIdsInClause( $dbh, @$func_ids_ref );
    my $sql;
    if ( $taxon_type eq 't' ) {
        $sql = getAllGenesTaxonQuery( $func_type, $func_id_str, $db_oid_str );
    } elsif ( $taxon_type eq 'b' ) {
        $sql = getAllGenesBinQuery( $func_type, $func_id_str, $db_oid_str );
    }
    my ($cnt, $gene_oids_href) = execAllGenesSql( $dbh, $it, $sd, $sql, $taxon_type, $symbToAdd );
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $func_id_str =~ /gtt_num_id/i );

    return ($cnt, $gene_oids_href);
}

sub execAllGenesSql {
    my ( $dbh, $it, $sd, $sql, $taxon_type, $symbToAdd ) = @_;

    my $cnt = 0;
    my %gene_oids_h;
    if ($sql) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $gene_display_name, $func_id, $scaffold_oid, $tb_oid, $tb_display_name ) = $cur->fetchrow();
            last if !$gene_oid;
            $gene_oids_h{$gene_oid} = 1;
            $cnt++;

            my $r;
            $r .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' />\t";
            my $url = "$main_cgi?section=GeneDetail&page=geneDetail";
            $url .= "&gene_oid=$gene_oid";
            $r   .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
            $r   .= "$gene_display_name\t";
            $r   .= "$symbToAdd$func_id\t";

            my $scaffold_url = "$main_cgi?section=ScaffoldCart" . "&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
            $scaffold_url = alink( $scaffold_url, $scaffold_oid );
            $r .= $scaffold_oid . $sd . $scaffold_url . "\t";

            my $url;
            if ( $taxon_type eq 't' ) {
                $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
                $url .= "&taxon_oid=$tb_oid";
            } elsif ( $taxon_type eq 'b' ) {
                $url = "$main_cgi?section=Metagenome&page=binDetail";
                $url .= "&bin_oid=$tb_oid";
            }
            $r .= $tb_display_name . $sd . alink( $url, $tb_display_name ) . "\t";
            $it->addRow($r);
        }
        $cur->finish();
    }

    return ($cnt, \%gene_oids_h);
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

    my $rclause   = WebUtil::urClause('a.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('a.taxon');
    my $sql       = qq{
         select a.pathway_oid, a.taxon, a.status, a.evidence
    	 from img_pathway_assertions a
    	 where a.pathway_oid in ( $pway_oid_str )
         $rclause
         $imgClause
    	 order by 1, 2
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

######################################################################################################################
#
# on the fly function cart queries
# other packages that used dt_gene_func and need replacement
#
######################################################################################################################
sub getDtGeneFuncQuery1 {
    my ($id) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql;
    if ( $id =~ /^GO/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_go_terms ggt, gene g
            where g.taxon = ?
            and g.gene_oid = ggt.gene_oid
            and ggt.go_id = ?
            $rclause
            $imgClause
        };
    } elsif ( $id =~ /^COG/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_cog_groups g
            where g.taxon = ?
            and g.cog = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^KOG/ ) {
        $sql .= qq{
            select distinct g.gene_oid
            from gene_kog_groups g
            where g.taxon = ?
            and g.kog = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^pfam/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_pfam_families g
            where g.taxon = ?
            and g.pfam_family = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^TIGR/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_tigrfams g
            where g.taxon = ?
            and g.ext_accession = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^IPR/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_xref_families g
            where g.db_name = 'InterPro'
            and g.taxon = ?
            and g.id = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^EC:/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_ko_enzymes g
            where g.taxon = ?
            and g.enzymes = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^TC:/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_tc_families g
            where g.taxon = ?
            and g.tc_family = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^KO:/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_ko_terms g
            where g.taxon = ?
            and g.ko_terms = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^BC:/ ) {
        $sql = qq{
            select distinct bcg.gene_oid
            from bio_cluster_features_new bcg, bio_cluster_new g
            where g.taxon = ?
            and g.cluster_id = ?
            and g.cluster_id = bcg.cluster_id
            $rclause
            $imgClause
        };
    } elsif ( $id =~ /^MetaCyc:/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from biocyc_reaction_in_pwys brp, biocyc_reaction br,
                gene_biocyc_rxns g
            where g.taxon = ?
            and g.ec_number = br.ec_number
            and g.biocyc_rxn = br.unique_id
            and br.unique_id = brp.unique_id
            and brp.in_pwys = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^ITERM:/ ) {

        #        $sql = qq{
        #            select distinct g.gene_oid
        #            from img_term it, dt_img_term_path dtp, gene_img_functions g
        #            where g.taxon = ?
        #            and g.function = dtp.map_term
        #            and dtp.term_oid = it.term_oid
        #            and it.term_oid = ?
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select distinct g.gene_oid
            from gene_img_functions g
            where g.taxon = ?
            and g.function = ?
            $rclause
            $imgClause
        };
    } elsif ( $id =~ /^IPWAY:/ ) {

        #        $sql = qq{
        #            select distinct g.gene_oid
        #            from gene_img_functions g, dt_img_term_path dtp,
        #                img_reaction_catalysts irc, img_pathway_reactions ipr
        #            where g.taxon = ?
        #            and g.function = dtp.map_term
        #            and dtp.term_oid = irc.catalysts
        #            and irc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ?
        #        	$rclause
        #        	$imgClause
        #                union
        #            select distinct g.gene_oid
        #            from gene_img_functions g, dt_img_term_path dtp,
        #              img_reaction_t_components itc, img_pathway_reactions ipr
        #            where g.taxon = ?
        #            and g.function = dtp.map_term
        #            and dtp.term_oid = itc.term
        #            and itc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ?
        #        	$rclause
        #        	$imgClause
        #        };
        $sql = qq{
            select distinct g.gene_oid
            from gene_img_functions g, img_reaction_catalysts irc, img_pathway_reactions ipr
            where g.taxon = ?
            and g.function = irc.catalysts
            and irc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ?
            $rclause
            $imgClause
                union
            select distinct g.gene_oid
            from gene_img_functions g, img_reaction_t_components itc, img_pathway_reactions ipr
            where g.taxon = ?
            and g.function = itc.term
            and itc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ?
            $rclause
            $imgClause
        };
    } elsif ( $id =~ /^PLIST:/ ) {

        #        $sql = qq{
        #            select distinct g.gene_oid
        #            from img_parts_list ipl, img_parts_list_img_terms plt,
        #              dt_img_term_path tp, gene_img_functions g
        #            where ipl.parts_list_oid = plt.parts_list_oid
        #            and plt.term = tp.term_oid
        #            and tp.map_term = g.function
        #            and g.taxon = ?
        #            and ipl.parts_list_oid = ?
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select distinct g.gene_oid
            from img_parts_list ipl, img_parts_list_img_terms plt,
              gene_img_functions g
            where ipl.parts_list_oid = plt.parts_list_oid
            and plt.term = g.function
            and g.taxon = ?
            and ipl.parts_list_oid = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^EGGNOG/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_eggnogs ge, gene g
            where ge.gene_oid = g.gene_oid
            and ge.type like '%NOG'
            and g.taxon = ?
            and ge.nog_id = ?
        	$rclause
        	$imgClause
        };
    }

    return $sql;
}

sub getDtGeneFuncQuery1_bin {
    my ($id) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql;
    if ( $id =~ /^GO/ ) {

        # go ?
    } elsif ( $id =~ /^COG/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_cog_groups g, bin_scaffolds bs
            where g.scaffold = bs.scaffold
            and bs.bin_oid = ?
            and g.cog = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^KOG/ ) {
        $sql .= qq{
            select distinct g.gene_oid
            from gene_kog_groups g, bin_scaffolds bs
            where g.scaffold = bs.scaffold
            and bs.bin_oid = ?
            and g.kog = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^pfam/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_pfam_families g, bin_scaffolds bs
            where g.scaffold = bs.scaffold
            and bs.bin_oid = ?
            and g.pfam_family = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^TIGR/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_tigrfams g, bin_scaffolds bs
            where g.scaffold = bs.scaffold
            and bs.bin_oid = ?
            and g.ext_accession = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^IPR/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_xref_families g, bin_scaffolds bs
            where g.db_name = 'InterPro'
            and g.scaffold = bs.scaffold
            and bs.bin_oid = ?
            and g.id = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^EC:/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from  gene_ko_enzymes g, bin_scaffolds bs
            where g.scaffold = bs.scaffold
            and bs.bin_oid = ?
            and g.enzymes = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^TC:/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_tc_families g, bin_scaffolds bs
            where g.scaffold = bs.scaffold
            and bs.bin_oid = ?
            and g.tc_family = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^KO:/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_ko_terms g, bin_scaffolds bs
            where g.scaffold = bs.scaffold
            and bs.bin_oid = ?
            and g.ko_terms = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^BC:/ ) {
        $sql = qq{
            select distinct bcg.gene_oid
            from bio_cluster_features_new bcg, bio_cluster_new g, bin_scaffolds bs
            where g.taxon = ?
            and g.cluster_id = ?
            and g.cluster_id = bcg.cluster_id
            and g.scaffold = bs.scaffold
            $rclause
            $imgClause
        };
    } elsif ( $id =~ /^MetaCyc:/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from biocyc_reaction_in_pwys brp, biocyc_reaction br,
                gene_biocyc_rxns g, bin_scaffolds bs
            where brp.unique_id = br.unique_id
            and br.unique_id = g.biocyc_rxn
            and br.ec_number = g.ec_number
            and g.scaffold = bs.scaffold
            and bs.bin_oid = ?
            and brp.in_pwys = ?
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^ITERM:/ ) {

        #        $sql = qq{
        #            select distinct g.gene_oid
        #            from img_term it, dt_img_term_path dtp, gene_img_functions g, bin_scaffolds bs
        #            where bs.bin_oid = ?
        #            and bs.scaffold = g.scaffold
        #            and g.function = dtp.map_term
        #            and dtp.term_oid = it.term_oid
        #            and it.term_oid = ?
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select distinct g.gene_oid
            from gene_img_functions g, bin_scaffolds bs
            where bs.bin_oid = ?
            and bs.scaffold = g.scaffold
            and g.function = ?
            $rclause
            $imgClause
        };
    } elsif ( $id =~ /^IPWAY:/ ) {

        #        $sql = qq{
        #            select distinct g.gene_oid
        #            from bin_scaffolds bs, gene_img_functions g, dt_img_term_path dtp,
        #                img_reaction_catalysts irc, img_pathway_reactions ipr
        #            where bs.bin_oid = ?
        #            and bs.scaffold = g.scaffold
        #            and g.function = dtp.map_term
        #            and dtp.term_oid = irc.catalysts
        #            and irc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ?
        #            $rclause
        #            $imgClause
        #                union
        #            select distinct g.gene_oid
        #            from bin_scaffolds bs, gene_img_functions g, dt_img_term_path dtp,
        #              img_reaction_t_components itc, img_pathway_reactions ipr
        #            where bs.bin_oid = ?
        #            and bs.scaffold = g.scaffold
        #            and g.function = dtp.map_term
        #            and dtp.term_oid = itc.term
        #            and itc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ?
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select distinct g.gene_oid
            from bin_scaffolds bs, gene_img_functions g,
                img_reaction_catalysts irc, img_pathway_reactions ipr
            where bs.bin_oid = ?
            and bs.scaffold = g.scaffold
            and g.function = irc.catalysts
            and irc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ?
            $rclause
            $imgClause
                union
            select distinct g.gene_oid
            from bin_scaffolds bs, gene_img_functions g,
              img_reaction_t_components itc, img_pathway_reactions ipr
            where bs.bin_oid = ?
            and bs.scaffold = g.scaffold
            and g.function = itc.term
            and itc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ?
            $rclause
            $imgClause
        };
    } elsif ( $id =~ /^PLIST:/ ) {

        #        $sql = qq{
        #            select distinct g.gene_oid
        #            from img_parts_list ipl, img_parts_list_img_terms plt,
        #              gene_img_functions g, dt_img_term_path tp, bin_scaffolds bs
        #            where bs.bin_oid = ?
        #            and bs.scaffold = g.scaffold
        #            and g.function = tp.map_term
        #            and tp.term_oid = plt.term
        #            and plt.parts_list_oid = ipl.parts_list_oid
        #            and ipl.parts_list_oid = ?
        #        	$rclause
        #        	$imgClause
        #        };
        $sql = qq{
            select distinct g.gene_oid
            from img_parts_list ipl, img_parts_list_img_terms plt,
              gene_img_functions g, bin_scaffolds bs
            where bs.bin_oid = ?
            and bs.scaffold = g.scaffold
            and g.function = plt.term
            and plt.parts_list_oid = ipl.parts_list_oid
            and ipl.parts_list_oid = ?
            $rclause
            $imgClause
        };
    } elsif ( $id =~ /^EGGNOG/ ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_eggnogs ge, gene g, bin_scaffolds bs
            where ge.gene_oid = g.gene_oid
            and ge.type like '%NOG'
            and g.scaffold = bs.scaffold
            and bs.bin_oid = ?
            and gcg.cog = ?
        	$rclause
        	$imgClause
        };
    }

    return $sql;
}

# other packages that used dt_gene_func and need replacement
# - scaffold list
sub getDtGeneFuncQuery2 {
    my ( $id, $scaffold_str ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql;

    if ( $id =~ /^GO/ ) {
    } elsif ( $id =~ /^COG/ ) {
        $sql = qq{
            select g.gene_oid
            from gene_cog_groups g
            where g.cog = ?
            and g.scaffold in ($scaffold_str)
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^KOG/ )  {
    } elsif ( $id =~ /^pfam/ ) {
        $sql = qq{
            select g.gene_oid
            from gene_pfam_families g
            where g.pfam_family = ?
            and g.scaffold in ($scaffold_str)
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^TIGR/ ) {
        $sql = qq{
            select g.gene_oid
            from gene_tigrfams g
            where g.ext_accession = ?
            and g.scaffold in ($scaffold_str)
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^IPR/ ) {
    } elsif ( $id =~ /^EC:/ ) {
        $sql = qq{
            select g.gene_oid
            from gene_ko_enzymes g
            where g.enzymes = ?
            and g.scaffold in ($scaffold_str)
        	$rclause
        	$imgClause
        };
    } elsif ( $id =~ /^TC:/ )      {
    } elsif ( $id =~ /^KO:/ )      {
    } elsif ( $id =~ /^MetaCyc:/ ) {
    } elsif ( $id =~ /^IPWAY:/ )   {
    } elsif ( $id =~ /^PLIST:/ )   {
    } elsif ( $id =~ /^ITERM:/ )   {
    } elsif ( $id =~ /^EGGNOG/ )   {
    }

    return $sql;
}

# $bin_taxon_aref - bin oids not taxon ids
sub getDtGeneFuncAllGenes {
    my ( $dbh, $functions_aref, $taxons_aref, $bin_taxon_aref ) = @_;

    my $taxon_str     = OracleUtil::getTaxonIdsInClause( $dbh,  @$taxons_aref );
    my $func_str      = OracleUtil::getFuncIdsInClause( $dbh,   @$functions_aref );
    my $bin_taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$bin_taxon_aref );

    my $rclause    = WebUtil::urClause('tx');
    my $imgClause  = WebUtil::imgClause('tx');
    my $rclause1   = WebUtil::urClause('g.taxon');
    my $imgClause1 = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql;

    my $tmp_href       = CartUtil::getFunctionTypes($functions_aref);
    my %function_types = %$tmp_href;

    if ( $function_types{go} ) {
    }

    if ( $function_types{eggnog} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            ge.nog_id, ge.level_2,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from gene_eggnogs ge, gene g, taxon tx, scaffold scf
            where ge.gene_oid = g.gene_oid
            and ge.type like '%NOG'
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
            and ge.nog_id in ($func_str)
        	$rclause
        	$imgClause
        };
    }

    if ( $function_types{ipr} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            gi.id, ip.name,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from interpro ip, gene_xref_families gi, gene g, taxon tx, scaffold scf
            where gi.db_name = 'InterPro'
            and ip.ext_accession = gi.id
            and gi.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
            and gi.id in ($func_str)
        	$rclause
        	$imgClause
        };
    }

    # cog
    if ( $function_types{cog} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            c.cog_id, c.cog_name,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from cog c, gene_cog_groups gcg, gene g, taxon tx, scaffold scf
            where c.cog_id = gcg.cog
            and gcg.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
            and c.cog_id in ($func_str)
        	$rclause
        	$imgClause
        };
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{cog} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            c.cog_id, c.cog_name,
            scf.ext_accession,
            bs.bin_oid, b.display_name
            from cog c, gene_cog_groups gcg, gene g, bin_scaffolds bs, bin b, scaffold scf
            where c.cog_id = gcg.cog
            and gcg.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and g.scaffold = scf.scaffold_oid
            and bs.bin_oid = b.bin_oid
            and bs.bin_oid in ($bin_taxon_str)
            and c.cog_id in ($func_str)
        	$rclause1
        	$imgClause1
        };
    }

    # pfam
    if ( $function_types{pfam} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            pf.ext_accession, pf.name,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from pfam_family pf, gene_pfam_families gpf, gene g, taxon tx, scaffold scf
            where pf.ext_accession = gpf.pfam_family
            and gpf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
            and pf.ext_accession in ($func_str)
        	$rclause
        	$imgClause
        };
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{pfam} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            pf.ext_accession, pf.name,
            scf.ext_accession,
            b.bin_oid, b.display_name
            from pfam_family pf, gene_pfam_families gpf, gene g, bin_scaffolds bs, bin b, scaffold scf
            where pf.ext_accession = gpf.pfam_family
            and gpf.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and g.scaffold = scf.scaffold_oid
            and bs.bin_oid = b.bin_oid
            and g.taxon in ($bin_taxon_str)
            and pf.ext_accession in ($func_str)
        	$rclause1
        	$imgClause1
        };
    }

    # tigrfam
    if ( $function_types{tigrfam} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            tf.ext_accession, tf.expanded_name,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from tigrfam tf, gene_tigrfams gtf, gene g, taxon tx, scaffold scf
            where tf.ext_accession = gtf.ext_accession
            and gtf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
            and tf.ext_accession in ($func_str)
        	$rclause
        	$imgClause
        };
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{tigrfam} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            tf.ext_accession, tf.expanded_name,
            scf.ext_accession,
            b.bin_oid, b.display_name
            from tigrfam tf, gene_tigrfams gtf, gene g, bin_scaffolds bs, bin b, scaffold scf
            where tf.ext_accession = gtf.ext_accession
            and gtf.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and bs.bin_oid = b.bin_oid
            and g.scaffold = bs.scaffold
            and g.scaffold = scf.scaffold_oid
            and bs.bin_oid = b.bin_oid
            and g.taxon in ($bin_taxon_str)
            and tf.ext_accession in ($func_str)
        	$rclause1
        	$imgClause1
        };
    }

    # ec
    if ( $function_types{ec} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            ez.ec_number, ez.enzyme_name,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from enzyme ez, gene_ko_enzymes ge, gene g, taxon tx, scaffold scf
            where ez.ec_number = ge.enzymes
            and ge.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
            and ez.ec_number in ($func_str)
        	$rclause
        	$imgClause
        };
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{ec} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select  g.gene_oid, g.gene_display_name,
            ez.ec_number, ez.enzyme_name,
            scf.ext_accession,
            b.bin_oid, b.display_name
            from enzyme ez, gene_ko_enzymes ge, gene g, bin_scaffolds bs, bin b, scaffold scf
            where ez.ec_number = ge.enzymes
            and ge.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and bs.bin_oid = b.bin_oid
            and g.scaffold = bs.scaffold
            and g.scaffold = scf.scaffold_oid
            and bs.bin_oid = b.bin_oid
            and g.taxon in ($bin_taxon_str)
            and ez.ec_number in ($func_str)
        	$rclause1
        	$imgClause1
        };
    }

    # metacyc
    if ( $function_types{metacyc} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            'MetaCyc:'||bp.unique_id, bp.common_name,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
              biocyc_reaction br, gene_biocyc_rxns gb, gene g, enzyme e, taxon tx, scaffold scf
            where bp.unique_id = brp.in_pwys
            and brp.unique_id = br.unique_id
            and br.unique_id = gb.biocyc_rxn
            and br.ec_number = gb.ec_number
            and gb.gene_oid = g.gene_oid
            and gb.ec_number = e.ec_number
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
            and bp.unique_id in ($func_str)
        	$rclause
        	$imgClause
        };
    }

    # ko
    if ( $function_types{ko} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            gkt.ko_terms, kt.definition,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from ko_term kt, gene_ko_terms gkt, gene g, taxon tx, scaffold scf
            where kt.ko_id = gkt.ko_terms
            and gkt.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
            and gkt.ko_terms in ($func_str)
        	$rclause
        	$imgClause
        };
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{ko} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            gkt.ko_terms, kt.definition,
            scf.ext_accession,
            b.bin_oid, b.display_name
            from ko_term kt, gene_ko_terms gkt, gene g, bin_scaffolds bs, bin b, scaffold scf
            where kt.ko_id = gkt.ko_terms
            and gkt.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and g.scaffold = scf.scaffold_oid
            and bs.bin_oid = b.bin_oid
            and g.taxon in ($bin_taxon_str)
            and gkt.ko_terms in ($func_str)
        	$rclause1
        	$imgClause1
        };
    }

    # kog
    if ( $function_types{kog} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            k.kog_id, k.kog_name,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from kog k, gene_kog_groups gkg, gene g, taxon tx, scaffold scf
            where k.kog_id = gkg.kog
            and gkg.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
            and k.kog_id in ($func_str)
        	$rclause
        	$imgClause
        };
    }

    # tc
    if ( $function_types{tc} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            gtcf.tc_family, tcf.tc_family_name,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from tc_family tcf, gene_tc_families gtcf,
                gene g, taxon tx, scaffold scf
            where tcf.tc_family_num = gtcf.tc_family
            and gtcf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
            and gtcf.tc_family in ($func_str)
        	$rclause
        	$imgClause
        };
    }

    # part list
    if ( $function_types{plist} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        #        $sql .= qq{
        #            select g.gene_oid, g.gene_display_name,
        #                ipl.parts_list_oid, ipl.parts_list_name,
        #                scf.ext_accession,
        #                tx.taxon_oid, tx.taxon_display_name
        #            from img_parts_list ipl, img_parts_list_img_terms plt,
        #              dt_img_term_path tp, gene_img_functions gif, gene g, taxon tx, scaffold scf
        #            where ipl.parts_list_oid in ($func_str)
        #            and ipl.parts_list_oid = plt.parts_list_oid
        #            and plt.term = tp.term_oid
        #            and tp.map_term = gif.function
        #            and gif.gene_oid = g.gene_oid
        #            and g.taxon in ($taxon_str)
        #            and g.taxon = tx.taxon_oid
        #            and g.scaffold = scf.scaffold_oid
        #            and g.taxon = scf.taxon
        #        	$rclause
        #        	$imgClause
        #        };
        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
                ipl.parts_list_oid, ipl.parts_list_name,
                scf.ext_accession,
                tx.taxon_oid, tx.taxon_display_name
            from img_parts_list ipl, img_parts_list_img_terms plt,
              gene_img_functions gif, gene g, taxon tx, scaffold scf
            where ipl.parts_list_oid in ($func_str)
            and ipl.parts_list_oid = plt.parts_list_oid
            and plt.term = gif.function
            and gif.gene_oid = g.gene_oid
            and g.taxon in ($taxon_str)
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            $rclause
            $imgClause
        };
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{plist} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        #        $sql .= qq{
        #            select g.gene_oid, g.gene_display_name,
        #            ipl.parts_list_oid, ipl.parts_list_name,
        #            scf.ext_accession,
        #            b.bin_oid, b.display_name
        #            from img_parts_list ipl, img_parts_list_img_terms plt,
        #              dt_img_term_path tp, gene_img_functions gif, gene g,
        #              scaffold scf, bin_scaffolds bs, bin b
        #            where ipl.parts_list_oid in ($func_str)
        #            and ipl.parts_list_oid = plt.parts_list_oid
        #            and plt.term = tp.term_oid
        #            and tp.map_term = gif.function
        #            and gif.gene_oid = g.gene_oid
        #            and g.taxon in ($bin_taxon_str)
        #            and g.scaffold = scf.scaffold_oid
        #            and g.scaffold = bs.scaffold
        #            and bs.bin_oid = b.bin_oid
        #        	$rclause1
        #        	$imgClause1
        #        };
        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            ipl.parts_list_oid, ipl.parts_list_name,
            scf.ext_accession,
            b.bin_oid, b.display_name
            from img_parts_list ipl, img_parts_list_img_terms plt,
              gene_img_functions gif, gene g,
              scaffold scf, bin_scaffolds bs, bin b
            where ipl.parts_list_oid in ($func_str)
            and ipl.parts_list_oid = plt.parts_list_oid
            and plt.term = gif.function
            and gif.gene_oid = g.gene_oid
            and g.taxon in ($bin_taxon_str)
            and g.scaffold = scf.scaffold_oid
            and g.scaffold = bs.scaffold
            and bs.bin_oid = b.bin_oid
            $rclause1
            $imgClause1
        };
    }

    # img pathways
    if ( $function_types{ipways} ) {
        $sql .= qq{
            union
        } if $sql ne "";

        #        $sql .= qq{
        #            select g.gene_oid, g.gene_display_name,
        #            ipw.pathway_oid, ipw.pathway_name,
        #            scf.ext_accession,
        #            tx.taxon_oid, tx.taxon_display_name
        #            from gene_img_functions gif, gene g,
        #              img_reaction_catalysts irc, img_pathway_reactions ipr,
        #              img_pathway ipw, dt_img_term_path ditp, taxon tx, scaffold scf
        #            where g.obsolete_flag = 'No'
        #            and g.gene_oid = gif.gene_oid
        #            and g.taxon = tx.taxon_oid
        #            and g.scaffold = scf.scaffold_oid
        #            and g.taxon = scf.taxon
        #            and gif.function = ditp.map_term
        #            and irc.catalysts = ditp.term_oid
        #            and irc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ipw.pathway_oid
        #            and g.taxon in ($taxon_str)
        #            and ipw.pathway_oid in ($func_str)
        #        	$rclause
        #        	$imgClause
        #                union
        #            select g.gene_oid, g.gene_display_name,
        #            ipw.pathway_oid, ipw.pathway_name,
        #            scf.ext_accession,
        #            tx.taxon_oid, tx.taxon_display_name
        #            from gene_img_functions gif, gene g,
        #              img_reaction_t_components itc, img_pathway_reactions ipr,
        #              img_pathway ipw, dt_img_term_path ditp, taxon tx, scaffold scf
        #            where g.obsolete_flag = 'No'
        #            and g.gene_oid = gif.gene_oid
        #            and g.taxon = tx.taxon_oid
        #            and g.scaffold = scf.scaffold_oid
        #            and g.taxon = scf.taxon
        #            and gif.function = ditp.map_term
        #            and itc.term = ditp.term_oid
        #            and itc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ipw.pathway_oid
        #            and g.taxon in ($taxon_str)
        #            and ipw.pathway_oid in ($func_str)
        #        	$rclause
        #        	$imgClause
        #        };
        $sql .= qq{
            select g.gene_oid, g.gene_display_name,
            ipw.pathway_oid, ipw.pathway_name,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from gene_img_functions gif, gene g,
              img_reaction_catalysts irc, img_pathway_reactions ipr,
              img_pathway ipw, taxon tx, scaffold scf
            where g.obsolete_flag = 'No'
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.gene_oid = gif.gene_oid
            and gif.function = irc.catalysts
            and irc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            and g.taxon in ($taxon_str)
            and ipw.pathway_oid in ($func_str)
            $rclause
            $imgClause
                union
            select g.gene_oid, g.gene_display_name,
            ipw.pathway_oid, ipw.pathway_name,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from gene_img_functions gif, gene g,
              img_reaction_t_components itc, img_pathway_reactions ipr,
              img_pathway ipw, taxon tx, scaffold scf
            where g.obsolete_flag = 'No'
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.gene_oid = gif.gene_oid
            and gif.function = itc.term
            and itc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            and g.taxon in ($taxon_str)
            and ipw.pathway_oid in ($func_str)
            $rclause
            $imgClause
        };
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{ipways} ) {

        #        $sql = qq{
        #            select g.gene_oid, g.gene_display_name,
        #            ipw.pathway_oid, ipw.pathway_name,
        #            scf.ext_accession,
        #            b.bin_oid, b.display_name
        #            from gene_img_functions gif, gene g,
        #              img_reaction_catalysts irc, img_pathway_reactions ipr,
        #              img_pathway ipw, dt_img_term_path ditp, bin_scaffolds bs, bin b, scaffold scf
        #            where g.obsolete_flag = 'No'
        #            and g.gene_oid = gif.gene_oid
        #            and g.scaffold = bs.scaffold
        #            and g.scaffold = scf.scaffold_oid
        #            and bs.bin_oid = b.bin_oid
        #            and gif.function = ditp.map_term
        #            and irc.catalysts = ditp.term_oid
        #            and irc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ipw.pathway_oid
        #            and g.taxon in ($bin_taxon_str)
        #            and ipw.pathway_oid in ($func_str)
        #        	$rclause1
        #        	$imgClause1
        #                union
        #            select g.gene_oid, g.gene_display_name,
        #            ipw.pathway_oid, ipw.pathway_name,
        #            scf.ext_accession,
        #            b.bin_oid, b.display_name
        #            from gene_img_functions gif, gene g,
        #              img_reaction_t_components itc, img_pathway_reactions ipr,
        #              img_pathway ipw, dt_img_term_path ditp, bin_scaffolds bs, bin b, scaffold scf
        #            where g.obsolete_flag = 'No'
        #            and g.gene_oid = gif.gene_oid
        #            and gif.function = ditp.map_term
        #            and g.scaffold = bs.scaffold
        #            and g.scaffold = scf.scaffold_oid
        #            and bs.bin_oid = b.bin_oid
        #            and itc.term = ditp.term_oid
        #            and itc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ipw.pathway_oid
        #            and g.taxon in ($bin_taxon_str)
        #            and ipw.pathway_oid in ($func_str)
        #        	$rclause1
        #        	$imgClause1
        #        };
        $sql = qq{
            select g.gene_oid, g.gene_display_name,
            ipw.pathway_oid, ipw.pathway_name,
            scf.ext_accession,
            b.bin_oid, b.display_name
            from gene_img_functions gif, gene g,
              img_reaction_catalysts irc, img_pathway_reactions ipr,
              img_pathway ipw, bin_scaffolds bs, bin b, scaffold scf
            where g.obsolete_flag = 'No'
            and g.gene_oid = gif.gene_oid
            and g.scaffold = bs.scaffold
            and g.scaffold = scf.scaffold_oid
            and bs.bin_oid = b.bin_oid
            and gif.function = irc.catalysts
            and irc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            and g.taxon in ($bin_taxon_str)
            and ipw.pathway_oid in ($func_str)
            $rclause1
            $imgClause1
                union
            select g.gene_oid, g.gene_display_name,
            ipw.pathway_oid, ipw.pathway_name,
            scf.ext_accession,
            b.bin_oid, b.display_name
            from gene_img_functions gif, gene g,
              img_reaction_t_components itc, img_pathway_reactions ipr,
              img_pathway ipw, bin_scaffolds bs, bin b, scaffold scf
            where g.obsolete_flag = 'No'
            and g.scaffold = bs.scaffold
            and g.scaffold = scf.scaffold_oid
            and bs.bin_oid = b.bin_oid
            and g.gene_oid = gif.gene_oid
            and gif.function = itc.term
            and itc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            and g.taxon in ($bin_taxon_str)
            and ipw.pathway_oid in ($func_str)
            $rclause1
            $imgClause1
        };
    }

    # img term
    if ( $function_types{iterm} ) {

        #        $sql = qq{
        #            select g.gene_oid, g.gene_display_name,
        #            it.term_oid, it.term,
        #            scf.ext_accession,
        #            tx.taxon_oid, tx.taxon_display_name
        #            from dt_img_term_path tp, gene_img_functions gif, gene g,
        #              taxon tx, scaffold scf
        #            where tp.term_oid in ($func_str)
        #            and tp.map_term = gif.function
        #            and gif.gene_oid = g.gene_oid
        #            and g.taxon = tx.taxon_oid
        #            and g.scaffold = scf.scaffold_oid
        #            and g.taxon = scf.taxon
        #            and g.taxon in ($taxon_str)
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select g.gene_oid, g.gene_display_name,
            it.term_oid, it.term,
            scf.ext_accession,
            tx.taxon_oid, tx.taxon_display_name
            from gene_img_functions gif, gene g,
              taxon tx, scaffold scf
            where gif.function in ($func_str)
            and gif.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            and g.taxon = scf.taxon
            and g.taxon in ($taxon_str)
        	$rclause
        	$imgClause
        };
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{iterm} ) {

        #        $sql = qq{
        #            select g.gene_oid, g.gene_display_name,
        #            it.term_oid, it.term,
        #            scf.ext_accession,
        #            b.bin_oid, b.display_name
        #            from dt_img_term_path tp, gene_img_functions gif, gene g,
        #              bin_scaffolds bs, bin b, scaffold scf
        #            where tp.term_oid in ($func_str)
        #            and tp.map_term = gif.function
        #            and gif.gene_oid = g.gene_oid
        #            and g.scaffold = bs.scaffold
        #            and g.scaffold = scf.scaffold_oid
        #            and bs.bin_oid = b.bin_oid
        #            and g.obsolete_flag = 'No'
        #            and g.taxon in ($bin_taxon_str)
        #            $rclause1
        #            $imgClause1
        #        };
        $sql = qq{
            select g.gene_oid, g.gene_display_name,
            it.term_oid, it.term,
            scf.ext_accession,
            b.bin_oid, b.display_name
            from gene_img_functions gif, gene g,
              bin_scaffolds bs, bin b, scaffold scf
            where gif.function in ($func_str)
            and gif.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and g.scaffold = scf.scaffold_oid
            and bs.bin_oid = b.bin_oid
            and g.obsolete_flag = 'No'
            and g.taxon in ($bin_taxon_str)
        	$rclause1
        	$imgClause1
        };
    }

    return $sql;
}

#obosolete, not used
sub getDtGeneFunc {
    my ( $dbh, $functions_aref, $taxons_aref, $bin_taxon_aref ) = @_;

    my $taxon_str     = OracleUtil::getTaxonIdsInClause( $dbh,  @$taxons_aref );
    my $func_str      = OracleUtil::getFuncIdsInClause( $dbh,   @$functions_aref );
    my $bin_taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$bin_taxon_aref );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $tmp_href       = CartUtil::getFunctionTypes($functions_aref);
    my %function_types = %$tmp_href;

    # hash of hash
    # func id => hash of 't' or 'b' append taxon oid => hash of gene_oid
    my %dt_gene_func;

    # hash of func_id => name
    my %func_names;

    if ( $function_types{go} ) {
        my $sql = qq{

        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $function_types{eggnog} ) {
        my $sql = qq{
            select distinct 'EGGBOG',
            ge.nog_id, ge.level_2, g.gene_oid, 't' taxon_type, g.taxon, 100, 0
            from gene_eggnogs ge, gene g
            where ge.gene_oid = g.gene_oid
            and ge.type like '%NOG'
            and g.taxon in ($taxon_str)
            and ge.nog_id in ($func_str)
        	$rclause
        	$imgClause

        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $function_types{ipr} ) {
        my $sql = qq{
            select distinct 'IPR', g.id, ip.name,
            g.gene_oid, 't' taxon_type, g.taxon, 100, 0
            from interpro ip, gene_xref_families g
            where g.db_name = 'InterPro'
            and ip.ext_accession = g.id
            and g.taxon in ($taxon_str)
            and g.id in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    # cog
    if ( $function_types{cog} ) {
        my $sql = qq{
            select distinct 'COG' func_db, c.cog_id func_id, c.cog_name func_name,
               g.gene_oid, 't' taxon_type, g.taxon taxon_oid,
               gcg.percent_identity, gcg.evalue
            from cog c, gene_cog_groups gcg, gene g
            where c.cog_id = gcg.cog
            and gcg.gene_oid = g.gene_oid
            and g.obsolete_flag = 'No'
            and g.taxon in ($taxon_str)
            and c.cog_id in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{cog} ) {
        my $sql = qq{
            select distinct 'COG' func_db, c.cog_id func_id, c.cog_name func_name,
               g.gene_oid, 'b' taxon_type, bs.bin_oid taxon_oid,
               gcg.percent_identity, gcg.evalue
            from cog c, gene_cog_groups gcg, gene g, bin_scaffolds bs
            where c.cog_id = gcg.cog
            and gcg.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and g.obsolete_flag = 'No'
            and g.taxon in ($bin_taxon_str)
            and c.cog_id in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    # pfam
    if ( $function_types{pfam} ) {
        my $sql = qq{
            select distinct 'pfam' func_db, pf.ext_accession func_id, pf.name func_name,
              g.gene_oid, 't' taxon_type, g.taxon taxon_oid,
              gpf.percent_identity, gpf.evalue
            from pfam_family pf, gene_pfam_families gpf, gene g
            where pf.ext_accession = gpf.pfam_family
            and gpf.gene_oid = g.gene_oid
            and g.obsolete_flag = 'No'
            and g.taxon in ($taxon_str)
            and pf.ext_accession in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{pfam} ) {
        my $sql = qq{
            select distinct 'pfam' func_db, pf.ext_accession func_id, pf.name func_name,
              g.gene_oid, 'b' taxon_type,
              bs.bin_oid taxon_oid,
              gpf.percent_identity, gpf.evalue
            from pfam_family pf, gene_pfam_families gpf, gene g, bin_scaffolds bs
            where pf.ext_accession = gpf.pfam_family
            and gpf.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and g.obsolete_flag = 'No'
            and g.taxon in ($bin_taxon_str)
            and pf.ext_accession in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    # tigrfam
    if ( $function_types{tigrfam} ) {
        my $sql = qq{
            select distinct
             'TIGR' func_db, tf.ext_accession func_id, tf.expanded_name func_name,
              g.gene_oid, 't' taxon_type, g.taxon taxon_oid,
              gtf.percent_identity, gtf.evalue
            from tigrfam tf, gene_tigrfams gtf, gene g
            where tf.ext_accession = gtf.ext_accession
            and gtf.gene_oid = g.gene_oid
            and g.obsolete_flag = 'No'
            and g.taxon in ($taxon_str)
            and tf.ext_accession in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{tigrfam} ) {
        my $sql = qq{
            select distinct
              'TIGR' func_db, tf.ext_accession func_id, tf.expanded_name func_name,
              g.gene_oid, 'b' taxon_type,
              b.bin_oid taxon_oid,
              gtf.percent_identity, gtf.evalue
            from tigrfam tf, gene_tigrfams gtf, gene g, bin_scaffolds bs, bin b
            where tf.ext_accession = gtf.ext_accession
            and gtf.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and bs.bin_oid = b.bin_oid
            and g.obsolete_flag = 'No'
            and g.taxon in ($bin_taxon_str)
            and tf.ext_accession in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    # ec
    if ( $function_types{ec} ) {
        my $sql = qq{
            select distinct 'EC' func_db, ez.ec_number func_id, ez.enzyme_name func_name,
              g.gene_oid, 't' taxon_type, g.taxon taxon_oid,
              100 percent_identity, 0 evalue
            from enzyme ez, gene_ko_enzymes ge, gene g
            where ez.ec_number = ge.enzymes
            and ge.gene_oid = g.gene_oid
            and g.obsolete_flag = 'No'
            and g.taxon in ($taxon_str)
            and ez.ec_number in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{ec} ) {
        my $sql = qq{
            select distinct 'EC' func_db, ez.ec_number func_id, ez.enzyme_name func_name,
              g.gene_oid, 'b' taxon_type,
              bs.bin_oid taxon_oid,
              100 percent_identity, 0 evalue
            from enzyme ez, gene_ko_enzymes ge, gene g, bin_scaffolds bs
            where ez.ec_number = ge.enzymes
            and ge.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and g.obsolete_flag = 'No'
            and g.taxon in ($bin_taxon_str)
            and ez.ec_number in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $function_types{metacyc} ) {
        my $sql = qq{
            select distinct 'MetaCyc' func_db, 'MetaCyc:'||bp.unique_id func_id,
               bp.common_name func_name,
               g.gene_oid, 't' taxon_type, g.taxon taxon_oid,
               100 percent_identity, 0 evalue
            from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
              biocyc_reaction br, gene_biocyc_rxns gb, gene g, enzyme e
            where bp.unique_id = brp.in_pwys
            and brp.unique_id = br.unique_id
            and br.unique_id = gb.biocyc_rxn
            and br.ec_number = gb.ec_number
            and gb.gene_oid = g.gene_oid
            and gb.ec_number = e.ec_number
            and g.obsolete_flag = 'No'
            and g.taxon in ($taxon_str)
            and bp.unique_id in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    # ko
    if ( $function_types{ko} ) {
        my $sql = qq{
            select distinct
             'KO' func_db, gkt.ko_terms func_id, kt.definition func_name,
              g.gene_oid, 't' taxon_type, g.taxon taxon_oid,
              100 percent_identity, 0 evalue
            from ko_term kt, gene_ko_terms gkt, gene g
            where kt.ko_id = gkt.ko_terms
            and gkt.gene_oid = g.gene_oid
            and g.obsolete_flag = 'No'
            and g.taxon in ($taxon_str)
            and gkt.ko_terms in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{ko} ) {
        my $sql = qq{
            select distinct
              'KO' func_db, gkt.ko_terms func_id, kt.definition func_name,
              g.gene_oid, 'b' taxon_type,
              b.bin_oid taxon_oid,
              100 percent_identity, 0 evalue
            from ko_term kt, gene_ko_terms gkt, gene g, bin_scaffolds bs, bin b
            where kt.ko_id = gkt.ko_terms
            and gkt.gene_oid = g.gene_oid
            and g.scaffold = bs.scaffold
            and bs.bin_oid = b.bin_oid
            and g.obsolete_flag = 'No'
            and g.taxon in ($bin_taxon_str)
            and gkt.ko_terms in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $function_types{kog} ) {
        my $sql = qq{
            select distinct 'KOG' func_db, k.kog_id func_id, k.kog_name func_name,
               g.gene_oid, 't' taxon_type, g.taxon taxon_oid,
               gkg.percent_identity, gkg.evalue
            from kog k, gene_kog_groups gkg, gene g
            where k.kog_id = gkg.kog
            and gkg.gene_oid = g.gene_oid
            and g.obsolete_flag = 'No'
            and g.taxon in ($taxon_str)
            and k.kog_id in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $function_types{tc} ) {
        my $sql = qq{
            select distinct
             'TC' func_db, gtcf.tc_family func_id, tcf.tc_family_name func_name,
              g.gene_oid, 't' taxon_type, g.taxon taxon_oid,
              '100' percent_identity, '0' evalue
            from tc_family tcf, gene_tc_families gtcf, gene g
            where tcf.tc_family_num = gtcf.tc_family
            and gtcf.gene_oid = g.gene_oid
            and g.obsolete_flag = 'No'
            and g.taxon in ($taxon_str)
            and gtcf.tc_family in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    # part list
    if ( $function_types{plist} ) {

        #        my $sql = qq{
        #            select distinct 'PLIST', ipl.parts_list_oid, ipl.parts_list_name,
        #              g.gene_oid, 't' taxon_type, g.taxon,       100, 0
        #            from img_parts_list ipl, img_parts_list_img_terms plt,
        #                dt_img_term_path tp, gene_img_functions g
        #            where ipl.parts_list_oid = plt.parts_list_oid
        #            and plt.term = tp.term_oid
        #            and tp.map_term = g.function
        #            and g.taxon in ($taxon_str)
        #            and ipl.parts_list_oid in ($func_str)
        #           $rclause
        #           $imgClause
        #        };
        my $sql = qq{
            select distinct 'PLIST', ipl.parts_list_oid, ipl.parts_list_name,
              g.gene_oid, 't' taxon_type, g.taxon,       100, 0
            from img_parts_list ipl, img_parts_list_img_terms plt,
                gene_img_functions g
            where ipl.parts_list_oid = plt.parts_list_oid
            and plt.term = g.function
            and g.taxon in ($taxon_str)
            and ipl.parts_list_oid in ($func_str)
            $rclause
            $imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{plist} ) {

        #        my $sql = qq{
        #            select distinct 'PLIST', ipl.parts_list_oid, ipl.parts_list_name,
        #              g.gene_oid, 'b', bs.bin_oid, 100, 0
        #            from img_parts_list ipl, img_parts_list_img_terms plt,
        #                dt_img_term_path tp, gene_img_functions g, bin_scaffolds bs
        #            where ipl.parts_list_oid = plt.parts_list_oid
        #            and plt.term = tp.term_oid
        #            and tp.map_term = g.function
        #            and g.scaffold = bs.scaffold
        #            and g.taxon in ($bin_taxon_str)
        #            and ipl.parts_list_oid in ($func_str)
        #            $rclause
        #            $imgClause
        #        };
        my $sql = qq{
            select distinct 'PLIST', ipl.parts_list_oid, ipl.parts_list_name,
              g.gene_oid, 'b', bs.bin_oid, 100, 0
            from img_parts_list ipl, img_parts_list_img_terms plt,
                gene_img_functions g, bin_scaffolds bs
            where ipl.parts_list_oid = plt.parts_list_oid
            and plt.term = g.function
            and g.scaffold = bs.scaffold
            and g.taxon in ($bin_taxon_str)
            and ipl.parts_list_oid in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    # img pathways
    if ( $function_types{ipways} ) {

        #        my $sql = qq{
        #            select distinct 'IPWAY', ipw.pathway_oid,
        #                ipw.pathway_name,
        #                g.gene_oid, 't' taxon_type, g.taxon,
        #                100, 0
        #            from gene_img_functions g, dt_img_term_path ditp,
        #              img_reaction_catalysts irc, img_pathway_reactions ipr, img_pathway ipw
        #            where g.function = ditp.map_term
        #            and irc.catalysts = ditp.term_oid
        #            and irc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ipw.pathway_oid
        #            and g.taxon in ($taxon_str)
        #            and ipw.pathway_oid in ($func_str)
        #            $rclause
        #            $imgClause
        #                union
        #            select distinct 'IPWAY', ipw.pathway_oid,
        #                ipw.pathway_name,
        #                g.gene_oid, 't' taxon_type, g.taxon,
        #                100, 0
        #            from gene_img_functions g, dt_img_term_path ditp,
        #              img_reaction_t_components itc, img_pathway_reactions ipr, img_pathway ipw
        #            where g.function = ditp.map_term
        #            and itc.term = ditp.term_oid
        #            and itc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ipw.pathway_oid
        #            and g.taxon in ($taxon_str)
        #            and ipw.pathway_oid in ($func_str)
        #            $rclause
        #            $imgClause
        #        };
        my $sql = qq{
            select distinct 'IPWAY', ipw.pathway_oid,
                ipw.pathway_name,
                g.gene_oid, 't' taxon_type, g.taxon,
                100, 0
            from gene_img_functions g,
              img_reaction_catalysts irc, img_pathway_reactions ipr, img_pathway ipw
            where g.function = irc.catalysts
            and irc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            and g.taxon in ($taxon_str)
            and ipw.pathway_oid in ($func_str)
        	$rclause
        	$imgClause
                union
            select distinct 'IPWAY', ipw.pathway_oid,
                ipw.pathway_name,
                g.gene_oid, 't' taxon_type, g.taxon,
                100, 0
            from gene_img_functions g,
              img_reaction_t_components itc, img_pathway_reactions ipr, img_pathway ipw
            where g.function = itc.term
            and itc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            and g.taxon in ($taxon_str)
            and ipw.pathway_oid in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{ipways} ) {

        #        my $sql = qq{
        #            select distinct 'IPWAY', ipw.pathway_oid,
        #                ipw.pathway_name,
        #                g.gene_oid, 'b', bs.bin_oid, 100, 0
        #            from gene_img_functions g, dt_img_term_path ditp,
        #              img_reaction_catalysts irc, img_pathway_reactions ipr,
        #              img_pathway ipw, bin_scaffolds bs
        #            where bs.scaffold = g.scaffold
        #            and g.function = ditp.map_term
        #            and ditp.term_oid = irc.catalysts
        #            and irc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ipw.pathway_oid
        #            and g.taxon in ($bin_taxon_str)
        #            and ipw.pathway_oid in ($func_str)
        #            $rclause
        #            $imgClause
        #                union
        #            select distinct 'IPWAY', ipw.pathway_oid,
        #                ipw.pathway_name,
        #            g.gene_oid, 'b', bs.bin_oid, 100, 0
        #            from gene_img_functions g, dt_img_term_path ditp,
        #              img_reaction_t_components itc, img_pathway_reactions ipr,
        #              img_pathway ipw, bin_scaffolds bs
        #            where bs.scaffold = g.scaffold
        #            and g.function = ditp.map_term
        #            and ditp.term_oid = itc.term
        #            and itc.rxn_oid = ipr.rxn
        #            and ipr.pathway_oid = ipw.pathway_oid
        #            and g.taxon in ($bin_taxon_str)
        #            and ipw.pathway_oid in ($func_str)
        #            $rclause
        #            $imgClause
        #        };
        my $sql = qq{
            select distinct 'IPWAY', ipw.pathway_oid,
                ipw.pathway_name,
                g.gene_oid, 'b', bs.bin_oid, 100, 0
            from gene_img_functions g,
              img_reaction_catalysts irc, img_pathway_reactions ipr,
              img_pathway ipw, bin_scaffolds bs
            where bs.scaffold = g.scaffold
            and g.function = irc.catalysts
            and irc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            and g.taxon in ($bin_taxon_str)
            and ipw.pathway_oid in ($func_str)
        	$rclause
        	$imgClause
                union
            select distinct 'IPWAY', ipw.pathway_oid,
                ipw.pathway_name,
            g.gene_oid, 'b', bs.bin_oid, 100, 0
            from gene_img_functions g,
              img_reaction_t_components itc, img_pathway_reactions ipr,
              img_pathway ipw, bin_scaffolds bs
            where bs.scaffold = g.scaffold
            and g.function = itc.term
            and itc.rxn_oid = ipr.rxn
            and ipr.pathway_oid = ipw.pathway_oid
            and g.taxon in ($bin_taxon_str)
            and ipw.pathway_oid in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    # img term
    if ( $function_types{iterm} ) {

        #        my $sql = qq{
        #            select distinct 'ITERM',
        #                it.term_oid, it.term, g.gene_oid, 't' taxon_type, g.taxon,
        #                100, 0
        #            from img_term it, gene_img_functions g, dt_img_term_path tp
        #            where it.term_oid = tp.term_oid
        #            and tp.map_term = g.function
        #            and g.taxon in ($taxon_str)
        #            and it.term_oid in ($func_str)
        #        	$rclause
        #        	$imgClause
        #        };
        my $sql = qq{
            select distinct 'ITERM',
                it.term_oid, it.term, g.gene_oid, 't' taxon_type, g.taxon,
                100, 0
            from img_term it, gene_img_functions g
            where it.term_oid = g.function
            and g.taxon in ($taxon_str)
            and it.term_oid in ($func_str)
            $rclause
            $imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    if ( $#$bin_taxon_aref > -1 && $function_types{iterm} ) {

        #        my $sql = qq{
        #            select distinct 'ITERM', it.term_oid, it.term, g.gene_oid, 'b',
        #                b.bin_oid, 100, 0
        #            from img_term it, dt_img_term_path tp, gene_img_functions g,
        #                bin_scaffolds bs
        #            where it.term_oid = tp.term_oid
        #            and tp.map_term = g.function
        #            and g.scaffold = bs.scaffold
        #            and g.taxon in ($bin_taxon_str)
        #            and it.term_oid in ($func_str)
        #            $rclause
        #            $imgClause
        #        };
        my $sql = qq{
            select distinct 'ITERM', it.term_oid, it.term, g.gene_oid, 'b',
                b.bin_oid, 100, 0
            from img_term it, gene_img_functions g,
                bin_scaffolds bs
            where it.term_oid = g.function
            and g.scaffold = bs.scaffold
            and g.taxon in ($bin_taxon_str)
            and it.term_oid in ($func_str)
        	$rclause
        	$imgClause
        };
        getDtGeneFuncExecSql( $dbh, $sql, \%dt_gene_func, \%func_names );
    }

    OracleUtil::truncTable( $dbh, "gtt_taxon_oid" )
      if ( $taxon_str =~ /gtt_taxon_oid/i );
    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $func_str =~ /gtt_func_id/i );
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $bin_taxon_str =~ /gtt_num_id/i );

    return ( \%dt_gene_func, \%func_names );
}

#
#
#
sub getDtGeneFuncExecSql {
    my ( $dbh, $sql, $data_href, $func_name_href ) = @_;

    print "Find functions and genes<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $func, $func_id, $func_name, $gene_oid, $taxon_type, $taxon_oid, @junk ) = $cur->fetchrow();
        last if !$func_id;
        $func_name_href->{$func_id} = $func_name;

        # t - taxon
        # b - for bin
        $taxon_oid = $taxon_type . $taxon_oid;

        if ( exists $data_href->{$func_id} ) {
            my $taxon_href = $data_href->{$func_id};
            if ( exists $taxon_href->{$taxon_oid} ) {
                my $gene_href = $taxon_href->{$taxon_oid};
                $gene_href->{$gene_oid} = $gene_oid;
            } else {
                my %t;
                my %g = ( $gene_oid => $gene_oid );
                $t{$taxon_oid} = \%g;
                $taxon_href->{$taxon_oid} = \%t;
            }
        } else {
            my %t;
            my %g = ( $gene_oid => $gene_oid );
            $t{$taxon_oid} = \%g;
            $data_href->{$func_id} = \%t;
        }
    }
}

#obosolete, not used
sub getDtFuncExecSql {
    my ( $dbh, $sql, $func_name_href ) = @_;

    print "Find function names <br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $func_id, $func_name ) = $cur->fetchrow();
        last if !$func_id;
        $func_name_href->{$func_id} = $func_name;
    }
}

#obosolete, not used
sub getDtFunc {
    my ( $dbh, $functions_aref ) = @_;

    my $func_str = OracleUtil::getFuncIdsInClause( $dbh, @$functions_aref );

    my $tmp_href       = CartUtil::getFunctionTypes($functions_aref);
    my %function_types = %$tmp_href;

    # hash of func_id => name
    my %func_names;

    if ( $function_types{go} ) {
        my $sql = qq{

        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    if ( $function_types{eggnog} ) {
        my $sql = qq{
            select distinct h.nog_id, h.level_2
            from eggnog_hierarchy h
            where h.type like '%NOG'
            and h.nog_id in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    if ( $function_types{ipr} ) {
        my $sql = qq{
            select ip.ext_accession, ip.name
            from interpro ip
            where ip.ext_accession in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    # cog
    if ( $function_types{cog} ) {
        my $sql = qq{
            select  c.cog_id, c.cog_name
            from cog c
            where c.cog_id in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    # pfam
    if ( $function_types{pfam} ) {
        my $sql = qq{
            select  pf.ext_accession, pf.name
            from pfam_family pf
            where pf.ext_accession in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    # tigrfam
    if ( $function_types{tigrfam} ) {
        my $sql = qq{
            select tf.ext_accession, tf.expanded_name
            from tigrfam tf
            where tf.ext_accession in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    # ec
    if ( $function_types{ec} ) {
        my $sql = qq{
            select ez.ec_numbe, ez.enzyme_name
            from enzyme ez
            where ez.ec_number in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    if ( $function_types{metacyc} ) {
        my $sql = qq{
            select 'MetaCyc:'||bp.unique_id, bp.common_name
            from biocyc_pathway bp
            where bp.unique_id in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    # ko
    if ( $function_types{ko} ) {
        my $sql = qq{
            select kt.ko_id, kt.definition
            from ko_term kt
            where kt.ko_id in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    if ( $function_types{kog} ) {
        my $sql = qq{
            select k.kog_id func_id, k.kog_name
            from kog k
            where k.kog_id in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    if ( $function_types{tc} ) {
        my $sql = qq{
            select tcf.tc_family_num, tcf.tc_family_name
            from tc_family tcf
            where tcf.tc_family_num in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    # part list
    if ( $function_types{plist} ) {
        my $sql = qq{
            select ipl.parts_list_oid, ipl.parts_list_name
            from img_parts_list ipl
            where ipl.parts_list_oid in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    # img pathways
    if ( $function_types{ipways} ) {
        my $sql = qq{
            select ipw.pathway_oid, ipw.pathway_name
            from img_pathway ipw
            where ipw.pathway_oid in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    # img term
    if ( $function_types{iterm} ) {
        my $sql = qq{
            select it.term_oid, it.term
            from img_term it
            where it.term_oid in ($func_str)
        };
        getDtFuncExecSql( $dbh, $sql, \%func_names );
    }

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $func_str =~ /gtt_func_id/i );

    return \%func_names;
}

sub isUnsurportedFuncIds {
    my ($id) = @_;

    if ( $id =~ /^GO/ ) {
        return 1;
    } elsif ( $id =~ /^\d+\.[A-Z]\.\d+/ ) {
        return 1;
    }

    return 0;
}

sub getFuncCartProfileTaxonQuery_s {
    my ( $func_type, $func_id_str, $db_taxon_oid_str, $contact_oid ) = @_;

    my $rclause    = WebUtil::urClause('g.taxon_oid');
    my $imgClause  = WebUtil::imgClauseNoTaxon('g.taxon_oid');
    my $rclause2   = WebUtil::urClause('g.taxon');
    my $imgClause2 = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql;
    if ( $func_type eq 'COG' ) {
        $sql = qq{
            select g.cog, g.taxon_oid, g.gene_count
            from mv_taxon_cog_stat g
            where g.cog in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KOG' ) {
        $sql = qq{
            select g.kog, g.taxon_oid, g.gene_count
            from mv_taxon_kog_stat g
            where g.kog in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'pfam' ) {
        $sql = qq{
            select g.pfam_family, g.taxon_oid, g.gene_count
            from mv_taxon_pfam_stat g
            where g.pfam_family in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'TIGR' ) {
        $sql = qq{
            select g.ext_accession, g.taxon_oid, g.gene_count
            from mv_taxon_tfam_stat g
            where g.ext_accession in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KO' ) {
        $sql = qq{
            select g.ko_term, g.taxon_oid, g.gene_count
            from mv_taxon_ko_stat g
            where g.ko_term in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'EC' ) {
        if ($contact_oid) {
            my $rclause1   = WebUtil::urClause('g1.taxon');
            my $imgClause1 = WebUtil::imgClauseNoTaxon('g1.taxon');
            $sql = qq{
                select new.ec_number, new.taxon_oid, count( distinct new.gene_oid )
                from (
                    select g.enzymes ec_number, g.taxon taxon_oid, g.gene_oid gene_oid
                    from gene_ko_enzymes g
                    where g.enzymes in ( $func_id_str )
                    and g.taxon in ( $db_taxon_oid_str )
                    $rclause2
                    $imgClause2
                    union
                    select me.ec_number ec_number, g1.taxon taxon_oid, g1.gene_oid gene_oid
                    from gene_myimg_enzymes me, gene g1
                    where me.ec_number in ( $func_id_str )
                    and me.modified_by = $contact_oid
                    and me.gene_oid = g1.gene_oid
                    and g1.locus_type = 'CDS'
                    and g1.obsolete_flag = 'No'
                    and g1.taxon in ( $db_taxon_oid_str )
                    $rclause1
                    $imgClause1
                ) new
                group by new.ec_number, new.taxon_oid
                order by new.ec_number, new.taxon_oid
            };
        } else {
            $sql = qq{
                select g.enzyme, g.taxon_oid, g.gene_count
                from mv_taxon_ec_stat g
                where g.enzyme in ( $func_id_str )
                and g.taxon_oid in ( $db_taxon_oid_str )
                $rclause
                $imgClause
            };
        }
    } elsif ( $func_type eq 'TC' ) {
        $sql = qq{
            select g.tc_family, g.taxon_oid, g.gene_count
            from mv_taxon_tc_stat g
            where g.tc_family in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'BC' ) {
        $sql = qq{
            select bcg.cluster_id, g.taxon, count( distinct bcg.gene_oid )
            from bio_cluster_features_new bcg, bio_cluster_new g
            where bcg.cluster_id in ( $func_id_str )
            and bcg.cluster_id = g.cluster_id
            and g.taxon in ( $db_taxon_oid_str )
            $rclause2
            $imgClause2
            group by bcg.cluster_id, g.taxon
        };
    } elsif ( $func_type eq 'MetaCyc' ) {
        $sql = qq{
            select g.pwy_id, g.taxon_oid, g.gene_count
            from mv_taxon_metacyc_stat g
            where g.pwy_id in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'ITERM' ) {

        #        $sql = qq{
        #            select dtp.term_oid, g.taxon, count( distinct g.gene_oid )
        #            from dt_img_term_path dtp, gene_img_functions g
        #            where dtp.term_oid in ( $func_id_str )
        #            and dtp.map_term = g.function
        #            and g.taxon in ( $db_taxon_oid_str )
        #            $rclause2
        #            $imgClause2
        #            group by dtp.term_oid, g.taxon
        #            order by dtp.term_oid, g.taxon
        #        };
        $sql = qq{
            select g.function, g.taxon, count( distinct g.gene_oid )
            from gene_img_functions g
            where g.function in ( $func_id_str )
            and g.taxon in ( $db_taxon_oid_str )
            $rclause2
            $imgClause2
            group by g.function, g.taxon
            order by g.function, g.taxon
        };
    } elsif ( $func_type eq 'IPWAY' ) {

        #        $sql = qq{
        #            select new.pathway_oid, new.taxon, count( distinct new.gene_oid )
        #            from (
        #                select ipr.pathway_oid pathway_oid, g.taxon taxon, g.gene_oid gene_oid
        #                from img_pathway_reactions ipr, img_reaction_catalysts irc,
        #                    dt_img_term_path dtp, gene_img_functions g
        #                where ipr.pathway_oid in ( $func_id_str )
        #                and ipr.rxn = irc.rxn_oid
        #                and irc.catalysts = dtp.term_oid
        #                and dtp.map_term = g.function
        #                and g.taxon in ( $db_taxon_oid_str )
        #                $rclause2
        #                $imgClause2
        #                  union
        #                select ipr.pathway_oid pathway_oid, g.taxon taxon, g.gene_oid gene_oid
        #                from img_pathway_reactions ipr, img_reaction_t_components itc,
        #                    dt_img_term_path dtp, gene_img_functions g
        #                where ipr.pathway_oid in ( $func_id_str )
        #                and ipr.rxn = itc.rxn_oid
        #                and itc.term = dtp.term_oid
        #                and dtp.map_term = g.function
        #                and g.taxon in ( $db_taxon_oid_str )
        #                $rclause2
        #                $imgClause2
        #            ) new
        #            group by new.pathway_oid, new.taxon
        #            order by new.pathway_oid, new.taxon
        #        };
        $sql = qq{
            select new.pathway_oid, new.taxon, count( distinct new.gene_oid )
            from (
                select ipr.pathway_oid pathway_oid, g.taxon taxon, g.gene_oid gene_oid
                from img_pathway_reactions ipr, img_reaction_catalysts irc,
                    gene_img_functions g
                where ipr.pathway_oid in ( $func_id_str )
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = g.function
                and g.taxon in ( $db_taxon_oid_str )
                $rclause2
                $imgClause2
                  union
                select ipr.pathway_oid pathway_oid, g.taxon taxon, g.gene_oid gene_oid
                from img_pathway_reactions ipr, img_reaction_t_components itc,
                    gene_img_functions g
                where ipr.pathway_oid in ( $func_id_str )
                and ipr.rxn = itc.rxn_oid
                and itc.term = g.function
                and g.taxon in ( $db_taxon_oid_str )
                $rclause2
                $imgClause2
            ) new
            group by new.pathway_oid, new.taxon
            order by new.pathway_oid, new.taxon
        };
    } elsif ( $func_type eq 'PLIST' ) {

        #        $sql = qq{
        #            select pt.parts_list_oid, g.taxon, count( distinct g.gene_oid )
        #            from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
        #            where pt.parts_list_oid in ( $func_id_str )
        #            and pt.term = dtp.term_oid
        #            and dtp.map_term = g.function
        #            and g.taxon in ( $db_taxon_oid_str )
        #            $rclause2
        #            $imgClause2
        #            group by pt.parts_list_oid, g.taxon
        #            order by pt.parts_list_oid, g.taxon
        #        };
        $sql = qq{
            select pt.parts_list_oid, g.taxon, count( distinct g.gene_oid )
            from img_parts_list_img_terms pt, gene_img_functions g
            where pt.parts_list_oid in ( $func_id_str )
            and pt.term = g.function
            and g.taxon in ( $db_taxon_oid_str )
            $rclause2
            $imgClause2
            group by pt.parts_list_oid, g.taxon
            order by pt.parts_list_oid, g.taxon
        };
    }

    #print "FuncCartStor::getFuncCartProfileTaxonQuery_s() $func_type sql: $sql<br/>\n";

    return $sql;
}

sub getFuncCartProfileBinQuery_s {
    my ( $func_type, $func_id_str, $bin2taxon_str, $contact_oid ) = @_;

    my $rclause    = WebUtil::urClause('g.taxon_oid');
    my $imgClause  = WebUtil::imgClauseNoTaxon('g.taxon_oid');
    my $rclause2   = WebUtil::urClause('g.taxon');
    my $imgClause2 = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql;
    if ( $func_type eq 'COG' ) {
        $sql = qq{
            select g.cog, g.taxon_oid, g.gene_count
            from mv_taxon_cog_stat g
            where g.cog in ( $func_id_str )
            and g.taxon_oid in ( $bin2taxon_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KOG' ) {
        $sql = qq{
            select g.kog, g.taxon_oid, g.gene_count
            from mv_taxon_kog_stat g
            where g.kog in ( $func_id_str )
            and g.taxon_oid in ( $bin2taxon_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'pfam' ) {
        $sql = qq{
            select g.pfam_family, g.taxon_oid, g.gene_count
            from mv_taxon_pfam_stat g
            where g.pfam_family in ( $func_id_str )
            and g.taxon_oid in ( $bin2taxon_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'TIGR' ) {
        $sql = qq{
            select g.ext_accession, g.taxon_oid, g.gene_count
            from mv_taxon_tfam_stat g
            where g.ext_accession in ( $func_id_str )
            and g.taxon_oid in ( $bin2taxon_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KO' ) {
        $sql = qq{
            select g.ko_term, g.taxon_oid, g.gene_count
            from mv_taxon_ko_stat g
            where g.ko_term in ( $func_id_str )
            and g.taxon_oid in ( $bin2taxon_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'EC' ) {
        if ($contact_oid) {
            my $rclause1   = WebUtil::urClause('g1.taxon');
            my $imgClause1 = WebUtil::imgClauseNoTaxon('g1.taxon');
            $sql = qq{
                select new.ec_number, new.taxon_oid, count( distinct new.gene_oid )
                from (
                    select g.enzymes ec_number, g.taxon taxon_oid, g.gene_oid gene_oid
                    from enzyme ez, gene_ko_enzymes g
                    where g.enzymes in ( $func_id_str )
                    and g.taxon in ( $bin2taxon_str )
                    $rclause2
                    $imgClause2
                    union
                    select me.ec_number ec_number, g1.taxon taxon_oid, g1.gene_oid gene_oid
                    from gene_myimg_enzymes me, gene g1
                    where me.ec_number in ( $func_id_str )
                    and me.modified_by = $contact_oid
                    and me.gene_oid = g1.gene_oid
                    and g1.locus_type = 'CDS'
                    and g1.obsolete_flag = 'No'
                    and g1.taxon in ( $bin2taxon_str )
                    $rclause1
                    $imgClause1
                ) new
                group by new.ec_number, new.taxon_oid
                order by new.ec_number, new.taxon_oid
            };
        } else {
            $sql = qq{
                select g.enzyme, g.taxon_oid, g.gene_count
                from mv_taxon_ec_stat g
                where g.enzyme in ( $func_id_str )
                and g.taxon_oid in ( $bin2taxon_str )
                $rclause
                $imgClause
            };
        }
    } elsif ( $func_type eq 'TC' ) {
        $sql = qq{
            select g.tc_family, g.taxon_oid, g.gene_count
            from mv_taxon_tc_stat g
            where g.tc_family in ( $func_id_str )
            and g.taxon_oid in ( $bin2taxon_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'BC' ) {
        $sql = qq{
            select bcg.cluster_id, g.taxon, count( distinct bcg.gene_oid )
            from bio_cluster_features_new bcg, bio_cluster_new g
            where bcg.cluster_id in ( $func_id_str )
            and bcg.cluster_id = g.cluster_id
            and g.taxon in ( $bin2taxon_str )
            $rclause2
            $imgClause2
            group by bcg.cluster_id, g.taxon
        };
    } elsif ( $func_type eq 'MetaCyc' ) {
        $sql = qq{
            select g.pwy_id, g.taxon_oid, g.gene_count
            from mv_taxon_metacyc_stat g
            where g.pwy_id in ( $func_id_str )
            and g.taxon_oid in ( $bin2taxon_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'ITERM' ) {

        #        $sql = qq{
        #            select dtp.term_oid, g.taxon, count( distinct g.gene_oid )
        #            from dt_img_term_path dtp, gene_img_functions g
        #            where dtp.term_oid in ( $func_id_str )
        #            and dtp.map_term = g.function
        #            and g.taxon in ( $bin2taxon_str )
        #            $rclause2
        #            $imgClause2
        #            group by dtp.term_oid, g.taxon
        #            order by dtp.term_oid, g.taxon
        #        };
        $sql = qq{
            select g.function, g.taxon, count( distinct g.gene_oid )
            from gene_img_functions g
            where g.function in ( $func_id_str )
            and g.taxon in ( $bin2taxon_str )
            $rclause2
            $imgClause2
            group by g.function, g.taxon
            order by g.function, g.taxon
        };
    } elsif ( $func_type eq 'IPWAY' ) {

        #        $sql = qq{
        #            select new.pathway_oid, new.taxon, count( distinct new.gene_oid )
        #            from (
        #                select ipr.pathway_oid pathway_oid, g.taxon taxon, g.gene_oid gene_oid
        #                from img_pathway_reactions ipr, img_reaction_catalysts irc,
        #                    dt_img_term_path dtp, gene_img_functions g
        #                where ipr.pathway_oid in ( $func_id_str )
        #                and ipr.rxn = irc.rxn_oid
        #                and irc.catalysts = dtp.term_oid
        #                and dtp.map_term = g.function
        #                and g.taxon in ( $bin2taxon_str )
        #                $rclause2
        #                $imgClause2
        #                  union
        #                select ipr.pathway_oid pathway_oid, g.taxon taxon, g.gene_oid gene_oid
        #                from img_pathway_reactions ipr, img_reaction_t_components itc,
        #                    dt_img_term_path dtp, gene_img_functions g
        #                where ipr.pathway_oid in ( $func_id_str )
        #                and ipr.rxn = itc.rxn_oid
        #                and itc.term = dtp.term_oid
        #                and dtp.map_term = g.function
        #                and g.taxon in ( $bin2taxon_str )
        #                $rclause2
        #                $imgClause2
        #            ) new
        #            group by new.pathway_oid, new.taxon
        #            order by new.pathway_oid, new.taxon
        #        };
        $sql = qq{
            select new.pathway_oid, new.taxon, count( distinct new.gene_oid )
            from (
                select ipr.pathway_oid pathway_oid, g.taxon taxon, g.gene_oid gene_oid
                from img_pathway_reactions ipr, img_reaction_catalysts irc,
                    gene_img_functions g
                where ipr.pathway_oid in ( $func_id_str )
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = g.function
                and g.taxon in ( $bin2taxon_str )
                $rclause2
                $imgClause2
                  union
                select ipr.pathway_oid pathway_oid, g.taxon taxon, g.gene_oid gene_oid
                from img_pathway_reactions ipr, img_reaction_t_components itc,
                    gene_img_functions g
                where ipr.pathway_oid in ( $func_id_str )
                and ipr.rxn = itc.rxn_oid
                and itc.term = g.function
                and g.taxon in ( $bin2taxon_str )
                $rclause2
                $imgClause2
            ) new
            group by new.pathway_oid, new.taxon
            order by new.pathway_oid, new.taxon
        };
    } elsif ( $func_type eq 'PLIST' ) {

        #        $sql = qq{
        #            select pt.parts_list_oid, g.taxon, count( distinct g.gene_oid )
        #            from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
        #            where pt.parts_list_oid in ( $func_id_str )
        #            and pt.term = dtp.term_oid
        #            and dtp.map_term = g.function
        #            and g.taxon in ( $bin2taxon_str )
        #            $rclause2
        #            $imgClause2
        #            group by pt.parts_list_oid, g.taxon
        #            order by pt.parts_list_oid, g.taxon
        #        };
        $sql = qq{
            select pt.parts_list_oid, g.taxon, count( distinct g.gene_oid )
            from img_parts_list_img_terms pt, gene_img_functions g
            where pt.parts_list_oid in ( $func_id_str )
            and pt.term = g.function
            and g.taxon in ( $bin2taxon_str )
            $rclause2
            $imgClause2
            group by pt.parts_list_oid, g.taxon
            order by pt.parts_list_oid, g.taxon
        };
    }

    #print "FuncCartStor::getFuncCartProfileBinQuery_s() $func_type sql: $sql<br/>\n";

    return $sql;
}

sub getFuncCartProfileTaxonQuery_merfs_s {
    my ( $func_type, $func_id_str, $meta_taxon_oid_str, $data_type, $rclause, $imgClause ) = @_;

    my $dataTypeClause;
    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
        $dataTypeClause = " and g.data_type = '$data_type' ";
    }

    my $sql;
    if ( $func_type eq 'COG' ) {
        $sql = qq{
            select g.func_id, g.taxon_oid, g.gene_count
            from TAXON_COG_COUNT g
            where g.taxon_oid in ($meta_taxon_oid_str)
            and g.func_id in ($func_id_str)
            $dataTypeClause
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'pfam' ) {
        $sql = qq{
            select g.func_id, g.taxon_oid, g.gene_count
            from TAXON_PFAM_COUNT g
            where g.taxon_oid in ($meta_taxon_oid_str)
            and g.func_id in ($func_id_str)
            $dataTypeClause
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'TIGR' ) {
        $sql = qq{
            select g.func_id, g.taxon_oid, g.gene_count
            from TAXON_TIGR_COUNT g
            where g.taxon_oid in ($meta_taxon_oid_str)
            and g.func_id in ($func_id_str)
            $dataTypeClause
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KO' ) {
        $sql = qq{
            select g.func_id, g.taxon_oid, g.gene_count
            from TAXON_KO_COUNT g
            where g.taxon_oid in ($meta_taxon_oid_str)
            and g.func_id in ($func_id_str)
            $dataTypeClause
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'EC' ) {
        $sql = qq{
            select g.func_id, g.taxon_oid, g.gene_count
            from TAXON_EC_COUNT g
            where g.taxon_oid in ($meta_taxon_oid_str)
            and g.func_id in ($func_id_str)
            $dataTypeClause
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'BC' ) {
        if ( $data_type ne 'unassembled' ) {
            my $rclause2   = WebUtil::urClause('g.taxon');
            my $imgClause2 = WebUtil::imgClauseNoTaxon('g.taxon');
            $sql = qq{
                select bcg.cluster_id, g.taxon, count( distinct bcg.feature_id )
                from bio_cluster_features_new bcg, bio_cluster_new g
                where bcg.cluster_id in ($func_id_str)
                and bcg.cluster_id = g.cluster_id
                and g.taxon in ($meta_taxon_oid_str)
                $rclause2
                $imgClause2
                group by bcg.cluster_id, g.taxon
            };
        }
    }
    #print "FuncCartStor::getFuncCartProfileTaxonQuery_merfs_s() $func_type $data_type sql: $sql<br/>\n";

    return $sql;
}

sub getFuncCartProfileTaxonQuery_t {
    my ( $func_type, $func_id_str, $db_taxon_oid_str, $contact_oid ) = @_;

    my $rclause    = WebUtil::urClause('g.taxon_oid');
    my $imgClause  = WebUtil::imgClauseNoTaxon('g.taxon_oid');
    my $rclause2   = WebUtil::urClause('g.taxon');
    my $imgClause2 = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql;
    if ( $func_type eq 'COG' ) {
        $sql = qq{
            select g.taxon_oid, g.cog, g.gene_count
            from mv_taxon_cog_stat g
            where g.cog in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KOG' ) {
        $sql = qq{
            select g.taxon_oid, g.kog, g.gene_count
            from mv_taxon_kog_stat g
            where g.kog in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'pfam' ) {
        $sql = qq{
            select g.taxon_oid, g.pfam_family, g.gene_count
            from mv_taxon_pfam_stat g
            where g.pfam_family in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'TIGR' ) {
        $sql = qq{
            select g.taxon_oid, g.ext_accession, g.gene_count
            from mv_taxon_tfam_stat g
            where g.ext_accession in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KO' ) {
        $sql = qq{
            select g.taxon_oid, g.ko_term, g.gene_count
            from mv_taxon_ko_stat g
            where g.ko_term in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'EC' ) {
        if ($contact_oid) {
            my $rclause1   = WebUtil::urClause('g1.taxon');
            my $imgClause1 = WebUtil::imgClauseNoTaxon('g1.taxon');
            $sql = qq{
                select new.taxon_oid, new.enzyme, count( distinct new.gene_oid )
                from (
                    select g.taxon taxon_oid, g.enzymes enzyme, g.gene_oid gene_oid
                    from gene_ko_enzymes g
                    where g.enzymes in ( $func_id_str )
                    and g.taxon in ( $db_taxon_oid_str )
                    $rclause2
                    $imgClause2
                    union
                    select g1.taxon taxon_oid, me.ec_number enzyme, me.gene_oid gene_oid
                    from gene_myimg_enzymes me, gene g1
                    where me.ec_number in ( $func_id_str )
                    and me.modified_by = $contact_oid
                    and me.gene_oid = g1.gene_oid
                    and g1.locus_type = 'CDS'
                    and g1.obsolete_flag = 'No'
                    and g1.taxon in ( $db_taxon_oid_str )
                    $rclause1
                    $imgClause1
                ) new
                group by new.taxon_oid, new.enzyme
                order by new.taxon_oid, new.enzyme
            };
        } else {
            $sql = qq{
                select g.taxon_oid, g.enzyme, g.gene_count
                from mv_taxon_ec_stat g
                where g.enzyme in ( $func_id_str )
                and g.taxon_oid in ( $db_taxon_oid_str )
                $rclause
                $imgClause
            };
        }
    } elsif ( $func_type eq 'TC' ) {
        $sql = qq{
            select g.taxon_oid, g.tc_family, g.gene_count
            from mv_taxon_tc_stat g
            where g.tc_family in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'BC' ) {
        $sql = qq{
            select g.taxon, bcg.cluster_id, count( distinct bcg.gene_oid )
            from bio_cluster_features_new bcg, bio_cluster_new g
            where bcg.cluster_id in ( $func_id_str )
            and bcg.cluster_id = g.cluster_id
            and g.taxon in ( $db_taxon_oid_str )
            $rclause2
            $imgClause2
            group by g.taxon, bcg.cluster_id
        };
    } elsif ( $func_type eq 'MetaCyc' ) {
        $sql = qq{
            select g.taxon_oid, g.pwy_id, g.gene_count
            from mv_taxon_metacyc_stat g
            where g.pwy_id in ( $func_id_str )
            and g.taxon_oid in ( $db_taxon_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'ITERM' ) {

        #        $sql = qq{
        #            select g.taxon, dtp.term_oid, count( distinct g.gene_oid )
        #            from dt_img_term_path dtp, gene_img_functions g
        #            where dtp.term_oid in ( $func_id_str )
        #            and dtp.map_term = g.function
        #            and g.taxon in ( $db_taxon_oid_str )
        #            $rclause2
        #            $imgClause2
        #            group by g.taxon, dtp.term_oid
        #            order by g.taxon, dtp.term_oid
        #        };
        $sql = qq{
            select g.taxon, g.function, count( distinct g.gene_oid )
            from gene_img_functions g
            where g.function in ( $func_id_str )
            and g.taxon in ( $db_taxon_oid_str )
            $rclause2
            $imgClause2
            group by g.taxon, g.function
            order by g.taxon, g.function
        };
    } elsif ( $func_type eq 'IPWAY' ) {

        #        $sql = qq{
        #            select new.taxon_oid, new.pathway_oid, count( distinct new.gene_oid )
        #            from (
        #                select g.taxon taxon_oid, ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
        #                from img_pathway_reactions ipr, img_reaction_catalysts irc,
        #                    dt_img_term_path dtp, gene_img_functions g
        #                where ipr.pathway_oid in ( $func_id_str )
        #                and ipr.rxn = irc.rxn_oid
        #                and irc.catalysts = dtp.term_oid
        #                and dtp.map_term = g.function
        #                and g.taxon in ( $db_taxon_oid_str )
        #                $rclause2
        #                $imgClause2
        #                  union
        #                select g.taxon taxon_oid, ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
        #                from img_pathway_reactions ipr, img_reaction_t_components itc,
        #                    dt_img_term_path dtp, gene_img_functions g
        #                where ipr.pathway_oid in ( $func_id_str )
        #                and ipr.rxn = itc.rxn_oid
        #                and itc.term = dtp.term_oid
        #                and dtp.map_term = g.function
        #                and g.taxon in ( $db_taxon_oid_str )
        #                $rclause2
        #                $imgClause2
        #            ) new
        #            group by new.taxon_oid, new.pathway_oid
        #            order by new.taxon_oid, new.pathway_oid
        #        };
        $sql = qq{
            select new.taxon_oid, new.pathway_oid, count( distinct new.gene_oid )
            from (
                select g.taxon taxon_oid, ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
                from img_pathway_reactions ipr, img_reaction_catalysts irc,
                    gene_img_functions g
                where ipr.pathway_oid in ( $func_id_str )
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = g.function
                and g.taxon in ( $db_taxon_oid_str )
                $rclause2
                $imgClause2
                  union
                select g.taxon taxon_oid, ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
                from img_pathway_reactions ipr, img_reaction_t_components itc,
                    gene_img_functions g
                where ipr.pathway_oid in ( $func_id_str )
                and ipr.rxn = itc.rxn_oid
                and itc.term = g.function
                and g.taxon in ( $db_taxon_oid_str )
                $rclause2
                $imgClause2
            ) new
            group by new.taxon_oid, new.pathway_oid
            order by new.taxon_oid, new.pathway_oid
        };
    } elsif ( $func_type eq 'PLIST' ) {

        #        $sql = qq{
        #            select g.taxon, pt.parts_list_oid, count( distinct g.gene_oid )
        #            from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
        #            where pt.parts_list_oid in ( $func_id_str )
        #            and pt.term = dtp.term_oid
        #            and dtp.map_term = g.function
        #            and g.taxon in ( $db_taxon_oid_str )
        #            $rclause2
        #            $imgClause2
        #            group by g.taxon, pt.parts_list_oid
        #            order by g.taxon, pt.parts_list_oid
        #        };
        $sql = qq{
            select g.taxon, pt.parts_list_oid, count( distinct g.gene_oid )
            from img_parts_list_img_terms pt, gene_img_functions g
            where pt.parts_list_oid in ( $func_id_str )
            and pt.term = g.function
            and g.taxon in ( $db_taxon_oid_str )
            $rclause2
            $imgClause2
            group by g.taxon, pt.parts_list_oid
            order by g.taxon, pt.parts_list_oid
        };
    }

    #print "FuncCartStor::getFuncCartProfileTaxonQuery_t() $func_type sql: $sql<br/>\n";

    return $sql;
}

sub getFuncCartProfileBinQuery_t {
    my ( $func_type, $func_id_str, $bin_oid_str, $contact_oid ) = @_;

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my $sql;
    if ( $func_type eq 'COG' ) {
        $sql = qq{
            select b.bin_oid, g.cog, g.gene_count
            from mv_taxon_cog_stat g, taxon tx, env_sample_gold es, bin b
            where g.cog in ( $func_id_str )
            and g.taxon_oid = tx.taxon_oid
            and tx.env_sample = es.sample_oid
            and es.sample_oid = b.env_sample
            and b.bin_oid in ( $bin_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KOG' ) {
        $sql = qq{
            select b.bin_oid, g.kog, g.gene_count
            from mv_taxon_kog_stat g, taxon tx, env_sample_gold es, bin b
            where g.kog in ( $func_id_str )
            and g.taxon_oid = tx.taxon_oid
            and tx.env_sample = es.sample_oid
            and es.sample_oid = b.env_sample
            and b.bin_oid in ( $bin_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'pfam' ) {
        $sql = qq{
            select b.bin_oid, g.pfam_family, g.gene_count
            from mv_taxon_pfam_stat g, taxon tx, env_sample_gold es, bin b
            where g.pfam_family in ( $func_id_str )
            and g.taxon_oid = tx.taxon_oid
            and tx.env_sample = es.sample_oid
            and es.sample_oid = b.env_sample
            and b.bin_oid in ( $bin_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'TIGR' ) {
        $sql = qq{
            select b.bin_oid, g.ext_accession, g.gene_count
            from mv_taxon_tfam_stat g, taxon tx, env_sample_gold es, bin b
            where g.ext_accession in ( $func_id_str )
            and g.taxon_oid = tx.taxon_oid
            and tx.env_sample = es.sample_oid
            and es.sample_oid = b.env_sample
            and b.bin_oid in ( $bin_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KO' ) {
        $sql = qq{
            select b.bin_oid, g.ko_term, g.gene_count
            from mv_taxon_ko_stat g, taxon tx, env_sample_gold es, bin b
            where g.ko_term in ( $func_id_str )
            and g.taxon_oid = tx.taxon_oid
            and tx.env_sample = es.sample_oid
            and es.sample_oid = b.env_sample
            and b.bin_oid in ( $bin_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'EC' ) {
        if ($contact_oid) {
            $sql = qq{
                select new.bin_oid, new.enzyme, count( distinct new.gene_oid )
                from (
                    select b.bin_oid bin_oid, g.enzymes enzyme, g.gene_oid gene_oid
                    from gene_ko_enzymes g, taxon tx, env_sample_gold es, bin b
                    where g.enzymes in ( $func_id_str )
                    and g.taxon = tx.taxon_oid
                    and tx.env_sample = es.sample_oid
                    and es.sample_oid = b.env_sample
                    and b.bin_oid in ( $bin_oid_str )
                    $rclause
                    $imgClause
                    union
                    select b.bin_oid bin_oid, me.ec_number enzyme, me.gene_oid gene_oid
                    from gene_myimg_enzymes me, gene g1, taxon tx, env_sample_gold es, bin b
                    where me.ec_number in ( $func_id_str )
                    and me.modified_by = $contact_oid
                    and me.gene_oid = g1.gene_oid
                    and g1.locus_type = 'CDS'
                    and g1.obsolete_flag = 'No'
                    and g1.taxon = tx.taxon_oid
                    and tx.env_sample = es.sample_oid
                    and es.sample_oid = b.env_sample
                    and b.bin_oid in ( $bin_oid_str )
                    $rclause
                    $imgClause
                ) new
                group by new.bin_oid, new.enzyme
                order by new.bin_oid, new.enzyme
            };
        } else {
            $sql = qq{
                select b.bin_oid, g.enzyme, g.gene_count
                from mv_taxon_ec_stat g, taxon tx, env_sample_gold es, bin b
                where g.enzyme in ( $func_id_str )
                and g.taxon_oid = tx.taxon_oid
                and tx.env_sample = es.sample_oid
                and es.sample_oid = b.env_sample
                and b.bin_oid in ( $bin_oid_str )
                $rclause
                $imgClause
            };
        }
    } elsif ( $func_type eq 'TC' ) {
        $sql = qq{
            select b.bin_oid, g.tc_family, g.gene_count
            from mv_taxon_tc_stat g, taxon tx, env_sample_gold es, bin b
            where g.tc_family in ( $func_id_str )
            and g.taxon_oid = tx.taxon_oid
            and tx.env_sample = es.sample_oid
            and es.sample_oid = b.env_sample
            and b.bin_oid in ( $bin_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'BC' ) {
        $sql = qq{
            select b.bin_oid, bcg.cluster_id, count( distinct bcg.gene_oid )
            from bio_cluster_features_new bcg, bio_cluster_new g, taxon tx, env_sample_gold es, bin b
            where bcg.cluster_id in ( $func_id_str )
            and bcg.cluster_id = g.cluster_id
            and g.taxon = tx.taxon_oid
            and tx.env_sample = es.sample_oid
            and es.sample_oid = b.env_sample
            and b.bin_oid in ( $bin_oid_str )
            $rclause
            $imgClause
            group by b.bin_oid, bcg.cluster_id
        };
    } elsif ( $func_type eq 'MetaCyc' ) {
        $sql = qq{
            select b.bin_oid, g.pwy_id, g.gene_count
            from mv_taxon_metacyc_stat g, taxon tx, env_sample_gold es, bin b
            where g.pwy_id in ( $func_id_str )
            and g.taxon_oid = tx.taxon_oid
            and tx.env_sample = es.sample_oid
            and es.sample_oid = b.env_sample
            and b.bin_oid in ( $bin_oid_str )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'ITERM' ) {

        #        $sql = qq{
        #            select b.bin_oid, dtp.term_oid, count( distinct g.gene_oid )
        #            from dt_img_term_path dtp, gene_img_functions g,
        #                taxon tx, env_sample_gold es, bin b
        #            where dtp.term_oid in ( $func_id_str )
        #            and dtp.map_term = g.function
        #            and g.taxon = tx.taxon_oid
        #            and tx.env_sample = es.sample_oid
        #            and es.sample_oid = b.env_sample
        #            and b.bin_oid in ( $bin_oid_str )
        #            $rclause
        #            $imgClause
        #            group by b.bin_oid, dtp.term_oid
        #            order by b.bin_oid, dtp.term_oid
        #        };
        $sql = qq{
            select b.bin_oid, g.function, count( distinct g.gene_oid )
            from gene_img_functions g,
                taxon tx, env_sample_gold es, bin b
            where g.function in ( $func_id_str )
            and g.taxon = tx.taxon_oid
            and tx.env_sample = es.sample_oid
            and es.sample_oid = b.env_sample
            and b.bin_oid in ( $bin_oid_str )
            $rclause
            $imgClause
            group by b.bin_oid, g.function
            order by b.bin_oid, g.function
        };
    } elsif ( $func_type eq 'IPWAY' ) {

        #        $sql = qq{
        #            select new.bin_oid, new.pathway_oid, count( distinct new.gene_oid )
        #            from (
        #                select b.bin_oid bin_oid, ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
        #                from img_pathway_reactions ipr, img_reaction_catalysts irc,
        #                    dt_img_term_path dtp, gene_img_functions g,
        #                    taxon tx, env_sample_gold es, bin b
        #                where ipr.pathway_oid in ( $func_id_str )
        #                and ipr.rxn = irc.rxn_oid
        #                and irc.catalysts = dtp.term_oid
        #                and dtp.map_term = g.function
        #                and g.taxon = tx.taxon_oid
        #                and tx.env_sample = es.sample_oid
        #                and es.sample_oid = b.env_sample
        #                and b.bin_oid in ( $bin_oid_str )
        #                $rclause
        #                $imgClause
        #                  union
        #                select b.bin_oid bin_oid, ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
        #                from img_pathway_reactions ipr, img_reaction_t_components itc,
        #                    dt_img_term_path dtp, gene_img_functions g,
        #                    taxon tx, env_sample_gold es, bin b
        #                where ipr.pathway_oid in ( $func_id_str )
        #                and ipr.rxn = itc.rxn_oid
        #                and itc.term = dtp.term_oid
        #                and dtp.map_term = g.function
        #                and g.taxon = tx.taxon_oid
        #                and tx.env_sample = es.sample_oid
        #                and es.sample_oid = b.env_sample
        #                and b.bin_oid in ( $bin_oid_str )
        #                $rclause
        #                $imgClause
        #            ) new
        #            group by new.bin_oid, new.pathway_oid
        #            order by new.bin_oid, new.pathway_oid
        #        };
        $sql = qq{
            select new.bin_oid, new.pathway_oid, count( distinct new.gene_oid )
            from (
                select b.bin_oid bin_oid, ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
                from img_pathway_reactions ipr, img_reaction_catalysts irc,
                    gene_img_functions g,
                    taxon tx, env_sample_gold es, bin b
                where ipr.pathway_oid in ( $func_id_str )
                and ipr.rxn = irc.rxn_oid
                and irc.catalysts = g.function
                and g.taxon = tx.taxon_oid
                and tx.env_sample = es.sample_oid
                and es.sample_oid = b.env_sample
                and b.bin_oid in ( $bin_oid_str )
                $rclause
                $imgClause
                  union
                select b.bin_oid bin_oid, ipr.pathway_oid pathway_oid, g.gene_oid gene_oid
                from img_pathway_reactions ipr, img_reaction_t_components itc,
                    gene_img_functions g,
                    taxon tx, env_sample_gold es, bin b
                where ipr.pathway_oid in ( $func_id_str )
                and ipr.rxn = itc.rxn_oid
                and itc.term = g.function
                and g.taxon = tx.taxon_oid
                and tx.env_sample = es.sample_oid
                and es.sample_oid = b.env_sample
                and b.bin_oid in ( $bin_oid_str )
                $rclause
                $imgClause
            ) new
            group by new.bin_oid, new.pathway_oid
            order by new.bin_oid, new.pathway_oid
        };
    } elsif ( $func_type eq 'PLIST' ) {

        #        $sql = qq{
        #            select b.bin_oid, pt.parts_list_oid, count( distinct g.gene_oid )
        #            from img_parts_list_img_terms pt, dt_img_term_path dtp,
        #                gene_img_functions g, taxon tx, env_sample_gold es, bin b
        #            where pt.parts_list_oid in ( $func_id_str )
        #            and pt.term = dtp.term_oid
        #            and dtp.map_term = g.function
        #            and g.taxon = tx.taxon_oid
        #            and tx.env_sample = es.sample_oid
        #            and es.sample_oid = b.env_sample
        #            and b.bin_oid in ( $bin_oid_str )
        #            $rclause
        #            $imgClause
        #            group by b.bin_oid, pt.parts_list_oid
        #            order by b.bin_oid, pt.parts_list_oid
        #        };
        $sql = qq{
            select b.bin_oid, pt.parts_list_oid, count( distinct g.gene_oid )
            from img_parts_list_img_terms pt, gene_img_functions g,
                taxon tx, env_sample_gold es, bin b
            where pt.parts_list_oid in ( $func_id_str )
            and pt.term = g.function
            and g.taxon = tx.taxon_oid
            and tx.env_sample = es.sample_oid
            and es.sample_oid = b.env_sample
            and b.bin_oid in ( $bin_oid_str )
            $rclause
            $imgClause
            group by b.bin_oid, pt.parts_list_oid
            order by b.bin_oid, pt.parts_list_oid
        };
    }

    #print "FuncCartStor::getFuncCartProfileBinQuery_t() $func_type sql: $sql<br/>\n";

    return $sql;
}

sub getFuncCartProfileTaxonQuery_merfs_t {
    my ( $func_type, $func_id_str, $meta_taxon_oid_str, $data_type, $rclause, $imgClause ) = @_;

    my $dataTypeClause;
    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
        $dataTypeClause = " and g.data_type = '$data_type' ";
    }

    my $sql;
    if ( $func_type eq 'COG' ) {
        $sql = qq{
            select g.taxon_oid, g.func_id, g.gene_count
            from TAXON_COG_COUNT g
            where g.taxon_oid in ($meta_taxon_oid_str)
            and g.func_id in ($func_id_str)
            $dataTypeClause
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'pfam' ) {
        $sql = qq{
            select g.taxon_oid, g.func_id, g.gene_count
            from TAXON_PFAM_COUNT g
            where g.taxon_oid in ($meta_taxon_oid_str)
            and g.func_id in ($func_id_str)
            $dataTypeClause
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'TIGR' ) {
        $sql = qq{
            select g.taxon_oid, g.func_id, g.gene_count
            from TAXON_TIGR_COUNT g
            where g.taxon_oid in ($meta_taxon_oid_str)
            and g.func_id in ($func_id_str)
            $dataTypeClause
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KO' ) {
        $sql = qq{
            select g.taxon_oid, g.func_id, g.gene_count
            from TAXON_KO_COUNT g
            where g.taxon_oid in ($meta_taxon_oid_str)
            and g.func_id in ($func_id_str)
            $dataTypeClause
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'EC' ) {
        $sql = qq{
            select g.taxon_oid, g.func_id, g.gene_count
            from TAXON_EC_COUNT g
            where g.taxon_oid in ($meta_taxon_oid_str)
            and g.func_id in ($func_id_str)
            $dataTypeClause
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'BC' ) {
        if ( $data_type ne 'unassembled' ) {
            my $rclause2   = WebUtil::urClause('g.taxon');
            my $imgClause2 = WebUtil::imgClauseNoTaxon('g.taxon');
            $sql = qq{
                select g.taxon, bcg.cluster_id, count( distinct bcg.feature_id )
                from bio_cluster_features_new bcg, bio_cluster_new g
                where bcg.cluster_id in ($func_id_str)
                and bcg.cluster_id = g.cluster_id
                and g.taxon in ($meta_taxon_oid_str)
                $rclause2
                $imgClause2
                group by g.taxon, bcg.cluster_id
            };
        }
    }
    #print "FuncCartStor::getFuncCartProfileTaxonQuery_merfs_t() $func_type $data_type sql: $sql<br/>\n";

    return $sql;
}

sub getAllGenesTaxonQuery {
    my ( $func_type, $func_id_str, $db_taxon_oid_str ) = @_;

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my $sql;
    if ( $func_type eq 'COG' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, gf.cog, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from gene_cog_groups gf, gene g, taxon tx
            where gf.cog in ( $func_id_str )
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KOG' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, gf.kog, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from gene_kog_groups gf, gene g, taxon tx
            where gf.kog in ( $func_id_str )
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'pfam' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, gf.pfam_family, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from gene_pfam_families gf, gene g, taxon tx
            where gf.pfam_family in ( $func_id_str )
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'TIGR' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, gf.ext_accession, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from gene_tigrfams gf, gene g, taxon tx
            where gf.ext_accession in ( $func_id_str )
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KO' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, gf.ko_terms, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from gene_ko_terms gf, gene g, taxon tx
            where gf.ko_terms in ( $func_id_str )
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'EC' ) {
        my $contact_oid = getContactOid();
        if ($contact_oid) {
            $sql = qq{
                select g.gene_oid, g.gene_display_name, gf.enzymes, gf.scaffold,
                    tx.taxon_oid, tx.taxon_display_name
                from gene_ko_enzymes gf, gene g, taxon tx
                where gf.enzymes in ( $func_id_str )
                and gf.taxon in ( $db_taxon_oid_str )
                and gf.gene_oid = g.gene_oid
                and g.taxon = tx.taxon_oid
                $rclause
                $imgClause
                union
                select g.gene_oid, g.gene_display_name, me.ec_number, g.scaffold,
                    tx.taxon_oid, tx.taxon_display_name
                from gene_myimg_enzymes me, gene g, taxon tx
                where me.modified_by = $contact_oid
                and me.ec_number in ( $func_id_str )
                and me.gene_oid = g.gene_oid
                and g.locus_type = 'CDS'
                and g.obsolete_flag = 'No'
                and g.taxon in ( $db_taxon_oid_str )
                and g.taxon = tx.taxon_oid
                $rclause
                $imgClause
            };
        } else {
            $sql = qq{
                select distinct g.gene_oid, g.gene_display_name, gf.enzymes, gf.scaffold,
                    tx.taxon_oid, tx.taxon_display_name
                from gene_ko_enzymes gf, gene g, taxon tx
                where gf.enzymes in ( $func_id_str )
                and gf.taxon in ( $db_taxon_oid_str )
                and gf.gene_oid = g.gene_oid
                and g.taxon = tx.taxon_oid
                $rclause
                $imgClause
            };
        }
    } elsif ( $func_type eq 'TC' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, gf.tc_family, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from gene_tc_families gf, gene g, taxon tx
            where gf.tc_family in ( $func_id_str )
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'BC' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, bcg.cluster_id, g.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from bio_cluster_features_new bcg, gene g, taxon tx
            where bcg.cluster_id in ( $func_id_str )
            and bcg.gene_oid = g.gene_oid
            and g.taxon in ( $db_taxon_oid_str )
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'MetaCyc' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, brp.in_pwys, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from biocyc_reaction_in_pwys brp, biocyc_reaction br,
                gene_biocyc_rxns gf, gene g, taxon tx
            where brp.in_pwys in ( $func_id_str )
            and brp.unique_id = br.unique_id
            and br.unique_id = gf.biocyc_rxn
            and br.ec_number = gf.ec_number
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'ITERM' ) {

        #        $sql = qq{
        #            select distinct g.gene_oid, g.gene_display_name, dtp.term_oid, gf.scaffold,
        #                tx.taxon_oid, tx.taxon_display_name
        #            from dt_img_term_path dtp, gene_img_functions gf, gene g, taxon tx
        #            where dtp.term_oid in ( $func_id_str )
        #            and dtp.map_term = gf.function
        #            and gf.taxon in ( $db_taxon_oid_str )
        #            and gf.gene_oid = g.gene_oid
        #            and g.taxon = tx.taxon_oid
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, gf.function, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from gene_img_functions gf, gene g, taxon tx
            where gf.function in ( $func_id_str )
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'IPWAY' ) {

        #        $sql = qq{
        #            select g.gene_oid, g.gene_display_name, ipr.pathway_oid, gf.scaffold,
        #                tx.taxon_oid, tx.taxon_display_name
        #            from img_pathway_reactions ipr, img_reaction_catalysts irc,
        #                dt_img_term_path dtp, gene_img_functions gf, gene g, taxon tx
        #            where ipr.pathway_oid in ( $func_id_str )
        #            and ipr.rxn = irc.rxn_oid
        #            and irc.catalysts = dtp.term_oid
        #            and dtp.map_term = gf.function
        #            and gf.taxon in ( $db_taxon_oid_str )
        #            and gf.gene_oid = g.gene_oid
        #            and g.taxon = tx.taxon_oid
        #            $rclause
        #            $imgClause
        #              union
        #            select g.gene_oid, g.gene_display_name, ipr.pathway_oid, gf.scaffold,
        #                tx.taxon_oid, tx.taxon_display_name
        #            from img_pathway_reactions ipr, img_reaction_t_components itc,
        #                dt_img_term_path dtp, gene_img_functions gf, gene g, taxon tx
        #            where ipr.pathway_oid in ( $func_id_str )
        #            and ipr.rxn = itc.rxn_oid
        #            and itc.term = dtp.term_oid
        #            and dtp.map_term = gf.function
        #            and gf.taxon in ( $db_taxon_oid_str )
        #            and gf.gene_oid = g.gene_oid
        #            and g.taxon = tx.taxon_oid
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select g.gene_oid, g.gene_display_name, ipr.pathway_oid, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from img_pathway_reactions ipr, img_reaction_catalysts irc,
                gene_img_functions gf, gene g, taxon tx
            where ipr.pathway_oid in ( $func_id_str )
            and ipr.rxn = irc.rxn_oid
            and irc.catalysts = gf.function
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
              union
            select g.gene_oid, g.gene_display_name, ipr.pathway_oid, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from img_pathway_reactions ipr, img_reaction_t_components itc,
                gene_img_functions gf, gene g, taxon tx
            where ipr.pathway_oid in ( $func_id_str )
            and ipr.rxn = itc.rxn_oid
            and itc.term = gf.function
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'PLIST' ) {

        #        $sql = qq{
        #            select distinct g.gene_oid, g.gene_display_name, pt.parts_list_oid, gf.scaffold,
        #                tx.taxon_oid, tx.taxon_display_name
        #            from img_parts_list_img_terms pt, dt_img_term_path dtp,
        #                gene_img_functions gf, gene g, taxon tx
        #            where pt.parts_list_oid in ( $func_id_str )
        #            and pt.term = dtp.term_oid
        #            and dtp.map_term = gf.function
        #            and gf.taxon in ( $db_taxon_oid_str )
        #            and gf.gene_oid = g.gene_oid
        #            and g.taxon = tx.taxon_oid
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, pt.parts_list_oid, gf.scaffold,
                tx.taxon_oid, tx.taxon_display_name
            from img_parts_list_img_terms pt,
                gene_img_functions gf, gene g, taxon tx
            where pt.parts_list_oid in ( $func_id_str )
            and pt.term = gf.function
            and gf.taxon in ( $db_taxon_oid_str )
            and gf.gene_oid = g.gene_oid
            and g.taxon = tx.taxon_oid
            $rclause
            $imgClause
        };
    }

    #print "FuncCartStor::getAllGeneTaxonQuery() $func_type sql: $sql<br/>\n";

    return $sql;
}

sub getAllGenesBinQuery {
    my ( $func_type, $func_id_str, $bin_oid_str ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql;
    if ( $func_type eq 'COG' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name,
               gf.cog, gf.scaffold, b.bin_oid, b.display_name
            from gene_cog_groups gf, gene g, bin_scaffolds bs, bin b
            where gf.cog in ( $func_id_str )
            and gf.scaffold = bs.scaffold
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KOG' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name,
               gf.kog, gf.scaffold, b.bin_oid, b.display_name
            from gene_kog_groups gf, gene g, bin_scaffolds bs, bin b
            where gf.kog in ( $func_id_str )
            and gf.scaffold = bs.scaffold
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'pfam' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name,
               gf.pfam_family, gf.scaffold, b.bin_oid, b.display_name
            from gene_pfam_families gf, gene g, bin_scaffolds bs, bin b
            where gf.pfam_family in ( $func_id_str )
            and gf.scaffold = bs.scaffold
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'TIGR' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name,
               gf.ext_accession, gf.scaffold, b.bin_oid, b.display_name
            from gene_tigrfams gf, gene g, bin_scaffolds bs, bin b
            where gf.ext_accession in ( $func_id_str )
            and gf.scaffold = bs.scaffold
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KO' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name,
               gf.ko_terms, gf.scaffold, b.bin_oid, b.display_name
            from gene_ko_terms gf, gene g, bin_scaffolds bs, bin b
            where gf.ko_terms in ( $func_id_str )
            and gf.scaffold = bs.scaffold
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'EC' ) {
        my $contact_oid = getContactOid();
        if ($contact_oid) {
            $sql = qq{
                select g.gene_oid, g.gene_display_name,
                   gf.enzymes, gf.scaffold, b.bin_oid, b.display_name
                from gene_ko_enzymes gf, gene g, bin_scaffolds bs, bin b
                where gf.enzymes in ( $func_id_str )
                and gf.scaffold = bs.scaffold
                and bs.bin_oid in ( $bin_oid_str )
                and bs.bin_oid = b.bin_oid
                and gf.gene_oid = g.gene_oid
                $rclause
                $imgClause
                union
                select g.gene_oid, g.gene_display_name, me.ec_number, g.scaffold,
                    b.bin_oid, b.display_name
                from gene_myimg_enzymes me, gene g, bin_scaffolds bs, bin b
                where me.modified_by = $contact_oid
                and me.ec_number in ( $func_id_str )
                and me.gene_oid = g.gene_oid
                and g.locus_type = 'CDS'
                and g.obsolete_flag = 'No'
                and g.scaffold = bs.scaffold
                and bs.bin_oid in ( $bin_oid_str )
                and bs.bin_oid = b.bin_oid
                $rclause
                $imgClause
            };
        } else {
            $sql = qq{
                select distinct g.gene_oid, g.gene_display_name,
                   gf.enzymes, gf.scaffold, b.bin_oid, b.display_name
                from gene_ko_enzymes gf, gene g, bin_scaffolds bs, bin b
                where gf.enzymes in ( $func_id_str )
                and gf.scaffold = bs.scaffold
                and bs.bin_oid in ( $bin_oid_str )
                and bs.bin_oid = b.bin_oid
                and gf.gene_oid = g.gene_oid
                $rclause
                $imgClause
            };
        }
    } elsif ( $func_type eq 'TC' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name,
               gf.tc_family, gf.scaffold, b.bin_oid, b.display_name
            from gene_tc_families gf, gene g, bin_scaffolds bs, bin b
            where gf.tc_family in ( $func_id_str )
            and gf.scaffold = bs.scaffold
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'BC' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, bcg.cluster_id, g.scaffold,
                b.bin_oid, b.display_name
            from bio_cluster_features_new bcg, gene g, bin_scaffolds bs, bin b
            where bcg.cluster_id in ( $func_id_str )
            and bcg.gene_oid = g.gene_oid
            and g.locus_type = 'CDS'
            and g.obsolete_flag = 'No'
            and g.scaffold = bs.scaffold
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'MetaCyc' ) {
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name,
                brp.in_pwys, gf.scaffold, b.bin_oid, b.display_name
            from biocyc_reaction_in_pwys brp, biocyc_reaction br,
                gene_biocyc_rxns gf, gene g, bin_scaffolds bs, bin b
            where brp.in_pwys in ( $func_id_str )
            and brp.unique_id = br.unique_id
            and br.unique_id = gf.biocyc_rxn
            and br.ec_number = gf.ec_number
            and gf.scaffold = bs.scaffold
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'ITERM' ) {

        #        $sql = qq{
        #            select distinct g.gene_oid, g.gene_display_name,
        #               dtp.term_oid, gf.scaffold, b.bin_oid, b.display_name
        #            from dt_img_term_path dtp, gene_img_functions gf,
        #                gene g, bin_scaffolds bs, bin b
        #            where dtp.term_oid in ( $func_id_str )
        #            and dtp.map_term = gf.function
        #            and gf.scaffold = bs.scaffold
        #            and bs.bin_oid in ( $bin_oid_str )
        #            and bs.bin_oid = b.bin_oid
        #            and gf.gene_oid = g.gene_oid
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name,
               gf.function, gf.scaffold, b.bin_oid, b.display_name
            from gene_img_functions gf,
                gene g, bin_scaffolds bs, bin b
            where gf.function in ( $func_id_str )
            and gf.scaffold = bs.scaffold
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'IPWAY' ) {

        #        $sql = qq{
        #            select g.gene_oid, g.gene_display_name, ipr.pathway_oid, gf.scaffold,
        #                b.bin_oid, b.display_name
        #            from img_pathway_reactions ipr, img_reaction_catalysts irc, dt_img_term_path dtp,
        #                gene_img_functions gf, gene g, bin_scaffolds bs, bin b
        #            where ipr.pathway_oid in ( $func_id_str )
        #            and ipr.rxn = irc.rxn_oid
        #            and irc.catalysts = dtp.term_oid
        #            and dtp.map_term = gf.function
        #            and bs.bin_oid in ( $bin_oid_str )
        #            and bs.bin_oid = b.bin_oid
        #            and gf.gene_oid = g.gene_oid
        #            $rclause
        #            $imgClause
        #              union
        #            select g.gene_oid, g.gene_display_name, ipr.pathway_oid, gf.scaffold,
        #                b.bin_oid, b.display_name
        #            from img_pathway_reactions ipr, img_reaction_t_components itc, dt_img_term_path dtp,
        #                gene_img_functions gf, gene g, bin_scaffolds bs, bin b
        #            where ipr.pathway_oid in ( $func_id_str )
        #            and ipr.rxn = itc.rxn_oid
        #            and itc.term = dtp.term_oid
        #            and dtp.map_term = gf.function
        #            and bs.bin_oid in ( $bin_oid_str )
        #            and bs.bin_oid = b.bin_oid
        #            and gf.gene_oid = g.gene_oid
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select g.gene_oid, g.gene_display_name, ipr.pathway_oid, gf.scaffold,
                b.bin_oid, b.display_name
            from img_pathway_reactions ipr, img_reaction_catalysts irc,
                gene_img_functions gf, gene g, bin_scaffolds bs, bin b
            where ipr.pathway_oid in ( $func_id_str )
            and ipr.rxn = irc.rxn_oid
            and irc.catalysts = gf.function
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
              union
            select g.gene_oid, g.gene_display_name, ipr.pathway_oid, gf.scaffold,
                b.bin_oid, b.display_name
            from img_pathway_reactions ipr, img_reaction_t_components itc,
                gene_img_functions gf, gene g, bin_scaffolds bs, bin b
            where ipr.pathway_oid in ( $func_id_str )
            and ipr.rxn = itc.rxn_oid
            and itc.term = gf.function
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'PLIST' ) {

        #        $sql = qq{
        #            select distinct g.gene_oid, g.gene_display_name, pt.parts_list_oid, gf.scaffold,
        #                b.bin_oid, b.display_name
        #            from img_parts_list_img_terms pt, dt_img_term_path dtp,
        #                gene_img_functions gf, gene g, bin_scaffolds bs, bin b
        #            where pt.parts_list_oid in ( $func_id_str )
        #            and pt.term = dtp.term_oid
        #            and dtp.map_term = gf.function
        #            and bs.bin_oid in ( $bin_oid_str )
        #            and bs.bin_oid = b.bin_oid
        #            and gf.gene_oid = g.gene_oid
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, pt.parts_list_oid, gf.scaffold,
                b.bin_oid, b.display_name
            from img_parts_list_img_terms pt,
                gene_img_functions gf, gene g, bin_scaffolds bs, bin b
            where pt.parts_list_oid in ( $func_id_str )
            and pt.term = gf.function
            and bs.bin_oid in ( $bin_oid_str )
            and bs.bin_oid = b.bin_oid
            and gf.gene_oid = g.gene_oid
            $rclause
            $imgClause
        };
    }

    #print "FuncCartStor::getAllGeneBinQuery() $func_type sql: $sql<br/>\n";

    return $sql;
}

sub getPhyloOccurProfileQuery {
    my ( $taxon_oids_str, $func_type, $func_id_str, $rclause, $imgClause ) = @_;

    if ( !$rclause ) {
        $rclause = WebUtil::urClause('tx');
    }
    if ( !$imgClause ) {
        $imgClause = WebUtil::imgClause('tx');
    }

    my $sql;
    if ( $func_type eq 'COG' ) {
        $sql = qq{
            select distinct g.cog, g.taxon
            from gene_cog_groups g, taxon tx
            where g.cog in ( $func_id_str )
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KOG' ) {
        $sql = qq{
            select distinct g.kog, g.taxon
            from gene_kog_groups g, taxon tx
            where g.kog in ( $func_id_str )
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'pfam' ) {
        $sql = qq{
            select distinct g.pfam_family, g.taxon
            from gene_pfam_families g, taxon tx
            where g.pfam_family in ( $func_id_str )
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'TIGR' ) {
        $sql = qq{
            select distinct g.ext_accession, g.taxon
            from gene_tigrfams g, taxon tx
            where g.ext_accession in ( $func_id_str )
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'KO' ) {
        $sql = qq{
            select distinct g.ko_terms, g.taxon
            from gene_ko_terms g, taxon tx
            where g.ko_terms in ( $func_id_str )
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'EC' ) {
        $sql = qq{
            select distinct g.enzymes, g.taxon
            from gene_ko_enzymes g, taxon tx
            where g.enzymes in ( $func_id_str )
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'TC' ) {
        $sql = qq{
            select distinct g.tc_family, g.taxon
            from gene_tc_families g, taxon tx
            where g.tc_family in ( $func_id_str )
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'BC' ) {
        $sql = qq{
            select distinct bcg.cluster_id, g.taxon
            from bio_cluster_features_new bcg, bio_cluster_new g, taxon tx
            where bcg.cluster_id in ( $func_id_str )
            and bcg.cluster_id = g.cluster_id
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'MetaCyc' ) {
        $sql = qq{
            select distinct brp.in_pwys, g.taxon
            from biocyc_reaction_in_pwys brp, biocyc_reaction br,
                gene_biocyc_rxns g, taxon tx
            where brp.in_pwys in ( $func_id_str )
            and brp.unique_id = br.unique_id
            and br.unique_id = g.biocyc_rxn
            and br.ec_number = g.ec_number
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'ITERM' ) {

        #        $sql = qq{
        #            select distinct dtp.term_oid, g.taxon
        #            from dt_img_term_path dtp, gene_img_functions g, taxon tx
        #            where dtp.term_oid in ( $func_id_str )
        #            and dtp.map_term = g.function
        #            and g.taxon = tx.taxon_oid
        #            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select distinct g.function, g.taxon
            from gene_img_functions g, taxon tx
            where g.function in ( $func_id_str )
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'IPWAY' ) {

        #        $sql = qq{
        #            select ipr.pathway_oid, g.taxon
        #            from img_pathway_reactions ipr, img_reaction_catalysts irc,
        #                dt_img_term_path dtp, gene_img_functions g, taxon tx
        #            where ipr.pathway_oid in ( $func_id_str )
        #            and ipr.rxn = irc.rxn_oid
        #            and irc.catalysts = dtp.term_oid
        #            and dtp.map_term = g.function
        #            and g.taxon = tx.taxon_oid
        #            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
        #            $rclause
        #            $imgClause
        #              union
        #            select ipr.pathway_oid, g.taxon
        #            from img_pathway_reactions ipr, img_reaction_t_components itc,
        #                dt_img_term_path dtp, gene_img_functions g, taxon tx
        #            where ipr.pathway_oid in ( $func_id_str )
        #            and ipr.rxn = itc.rxn_oid
        #            and itc.term = dtp.term_oid
        #            and dtp.map_term = g.function
        #            and g.taxon = tx.taxon_oid
        #            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select ipr.pathway_oid, g.taxon
            from img_pathway_reactions ipr, img_reaction_catalysts irc,
                gene_img_functions g, taxon tx
            where ipr.pathway_oid in ( $func_id_str )
            and ipr.rxn = irc.rxn_oid
            and irc.catalysts = g.function
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
              union
            select ipr.pathway_oid, g.taxon
            from img_pathway_reactions ipr, img_reaction_t_components itc,
                gene_img_functions g, taxon tx
            where ipr.pathway_oid in ( $func_id_str )
            and ipr.rxn = itc.rxn_oid
            and itc.term = g.function
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    } elsif ( $func_type eq 'PLIST' ) {

        #        $sql = qq{
        #            select distinct pt.parts_list_oid, g.taxon
        #            from img_parts_list_img_terms pt, dt_img_term_path dtp,
        #                gene_img_functions gf, gene g, taxon tx
        #            where pt.parts_list_oid in ( $func_id_str )
        #            and pt.term = dtp.term_oid
        #            and dtp.map_term = g.function
        #            and g.taxon = tx.taxon_oid
        #            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
        #            $rclause
        #            $imgClause
        #        };
        $sql = qq{
            select distinct pt.parts_list_oid, g.taxon
            from img_parts_list_img_terms pt,
                gene_img_functions g, taxon tx
            where pt.parts_list_oid in ( $func_id_str )
            and pt.term = g.function
            and g.taxon = tx.taxon_oid
            and tx.taxon_oid in ( $taxon_oids_str )
            and tx.domain in ( 'Bacteria', 'Archaea', 'Eukaryota' )
            $rclause
            $imgClause
        };
    }

    #print "FuncCartStor::getPhyloOccurProfileQuery() $func_type sql: $sql<br/>\n";

    return $sql;
}

sub removeDuplicate {
    my (@arr1) = @_;

    my %entries;
    for my $tok (@arr1) {
        $entries{$tok} = 1;
    }

    return (keys %entries);
}

1;

