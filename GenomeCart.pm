###########################################################################
# GenomeCart.pm
# $Id: GenomeCart.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
############################################################################
package GenomeCart;

use strict;
use warnings;
use feature ':5.16';

use CGI qw( :standard);
use Data::Dumper;
use DBI;
use InnerTable;
use WebConfig;
use WebUtil;
use OracleUtil;
use GoldDataEntryUtil;
use TaxonTableConfiguration;
use TabHTML;
use MerFsUtil;
use WorkspaceUtil;
use HtmlUtil;
use MyIMG;
use CartUtil;

$| = 1;

my $section              = "GenomeCart";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $inner_cgi            = $env->{inner_cgi};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $include_metagenomes  = $env->{include_metagenomes};
my $verbose              = $env->{verbose};
my $user_restricted_site = $env->{user_restricted_site};
my $base_url             = $env->{base_url};
my $tmp_url              = $env->{tmp_url};
my $img_internal         = $env->{img_internal};
my $in_file              = $env->{in_file};
my $taxonomy_base_url    = $env->{taxonomy_base_url};
my $img_er_submit_url    = $env->{img_er_submit_url};
my $img_mer_submit_url   = $env->{img_mer_submit_url};
my $http                 = $env->{ http };
my $domain_name          = $env->{ domain_name };
my $img_ken          = $env->{ img_ken };

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( ! $merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

my $contact_oid;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    timeout( 60 * $merfs_timeout_mins );
    my $page = param("page");
    $contact_oid = getContactOid();

    if ( $page eq "genomeCart" ) {
        printMainPage();
    } elsif ( paramMatch("removeFromGenomeCart") ne "" ) {
        removeFromGenomeCart();
        printMainPage();
    } elsif ( paramMatch("uploadGenomeCart") ne "" ) {
        uploadGenomeCart();
        printMainPage();
    } elsif ( paramMatch("addGeneGenome") ne "" ) {
        addGeneGenomeToCart();
        printMainPage();
    } elsif ( paramMatch("addScaffoldGenome") ne "" ) {
        addScaffoldGenomeToCart();
        printMainPage();
    } elsif ( paramMatch("taxonUpload") ne "" ) {
        printTaxonUploadForm();
    } elsif ( paramMatch("exportGenomes") ne "" ) {
        exportGenomesInCart();
    } else {
        printMainPage();
    }
}

############################################################################
# printMainPage - Print main landing page
#                 Prompts for upload if cart is empty
############################################################################
sub printMainPage {
    my $genomeStr = param("genomes");    # from url
    if ( $genomeStr ne "" ) {
        my @taxons = split( ",", $genomeStr );
        addToGenomeCart( \@taxons );
    }

    my $taxon_oids = getAllGenomeOids();

    my $size = $#$taxon_oids;
    #webLog("size ------- " . $size .  "----- \n");

    if ( scalar(@$taxon_oids) == 0 ) {
        print "<h1>Genome Cart</h1>\n";
        CartUtil::printMaxNumMsg('genomes');
        printMainForm();
        printCartJS();
        wunlink( getStateFile() );       # remove cart
        wunlink( getColIdFile() );       # remove col id file
        print "<p>\n";
        print "0 genomes in cart.\n";
        print qq{
            In order to compare genomes you need to
            select / upload genomes into genome cart.
        };
        print "</p>\n";
        printStatusLine( "0 genomes in cart", 2 );
        printTaxonUploadForm('Yes');
    } else {
        print "<h1>Genome Cart</h1>\n";
        CartUtil::printMaxNumMsg('genomes');
        printMainForm();
        printCartJS();

        my $dbh = dbLogin();
        printGenomeCart_new( $dbh, @$taxon_oids );
        # printGenomeCart( $dbh, @$taxon_oids );
        #$dbh->disconnect();
    }

    print end_form();
}

############################################################################
# printTaxonUploadForm - Form for uploading taxons from tab-delimited file
############################################################################
sub printTaxonUploadForm {
    my ($insideGenomeCartSection) = @_;

    print start_multipart_form( -name   => "taxonSelectionUploadForm",
                                -action => "$section_cgi" );
    print pageAnchor("Upload Genome Selections");
    if ( $insideGenomeCartSection eq 'Yes' ) {
        print "<h2>Upload Genome Cart</h2>\n";
    } else {
        print "<h1>Upload Genome Cart</h1>\n";
    }
    printTaxonUploadFormContent();

    print qq {
        <script type="text/javascript">
        updCnt("ALL")
        </script>
    };
    print end_form();
}

sub printTaxonUploadFormContent {
    my ($export) = @_;
    $export = 0 if $export eq "";

    my $submission_site_url = $http . $domain_name . "/cgi-bin/submit/" . $main_cgi;
    my $submission_site_url_link = alink( $submission_site_url, 'submission site' );

    my $text = "";
    $text = " or IMG genomes saved as a genome set to the workspace,"
	if $user_restricted_site;

    print "<p style='width: 650px;'>";
    print "<font color=red>";
    print "The Genome Cart is used for genomes already in IMG. Only previously exported IMG genomes$text can be uploaded. <u>To upload private genomes</u>, you must submit your data to IMG through the $submission_site_url_link.";
    print "</font><br/><br/>\n";

    print "You may upload a genome cart from a tab-delimited file.<br/> ";
    print "Uploading a genome cart will add the genomes to the list " . "of selected genomes.<br/>\n";
    print "The file should have a column header 'taxon_oid'.<br/>\n";

    if (!$export) {
        print qq{
        (This file may initially be obtained by exporting genomes from
        <a href='$main_cgi?section=TaxonList&page=TaxonListAlpha'>
        Genome Browser</a> to Excel)<br/>\n
        };
    } else {
        print qq{
        (This file may initially be obtained by exporting genomes from
        <a href='$main_cgi?section=TaxonList&page=TaxonListAlpha'>
        Genome Browser</a> to Excel<br/>or by using the
        <u>Export Genomes</u> section below)<br/>\n
        };
    }
    print "<br/>\n";

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

    if ($user_restricted_site) {
	print nbsp(1);
	my $url = "$main_cgi?section=WorkspaceGenomeSet&page=home";
	print buttonUrl( $url, "Upload from Workspace", "medbutton" );
    }

    print "</p>\n";
}

sub printCartTab1Start {
    TabHTML::printTabAPILinks("genomecartTab");
    my @tabIndex = ( "#genomecarttab1",   "#genomecarttab2" );
    my @tabNames = ( "Genomes in Cart", "Upload & Export & Save" );
    TabHTML::printTabDiv( "genomecartTab", \@tabIndex, \@tabNames );

    print "<div id='genomecarttab1'>";
    # link to cart phyla grouping
    print qq{
        <p>
        <a href='main.cgi?section=GenomeList&page=phylumCartList'>Group Genome Cart by Phyla</a>
        </p>
    };
    printGenomeCartButtons(1);
}

sub printCartTab1End {
    my ($count) = @_;
    printStatusLine( "$count genome(s) in cart.", 2 ) if $count > 0;
    #printGenomeCartButtons();
    print "</div>";
}

sub printCartTab2 {
    my ($count) = @_;
    print "<div id='genomecarttab2'>";
    print "<h2>Upload Genome Cart</h2>";
    printTaxonUploadFormContent('Yes');

    # Run JS for updating number of genomes in cart. See below.
    print qq{
        <script type="text/javascript">
        updCnt($count)
        </script>
    } if $count > 0;

    print "<h2>Export Genomes</h2>";
    print "<p>\n";
    print "You may select genomes from the cart to export.";
    print "</p>\n";
    if ( $count == 0 ) {
        print "<p>You have 0 genomes to export.</p>\n";
    } else {
        my $name = "_section_${section}_exportGenomes_noHeader";
#        print submit(
#                      -name  => $name,
#                      -value => "Export Genomes",
#                      -class => "medbutton"
#        );


 my $str = HtmlUtil::trackEvent("Export", $contact_oid, "img button $name");
print qq{
   <input class='medbutton' name='$name' type="submit" value="Export Genomes" $str>
 };

        WorkspaceUtil::printSaveGenomeToWorkspace('taxon_filter_oid');
    }
    print "</div>";    # end genomecarttab2

}

############################################################################
# printGenomeCart - Display contents of the genome cart in tabular form
############################################################################
sub printGenomeCart_new {
    my ( $dbh, @taxon_filter_oid ) = @_;
    my $showTaxonOid = 0;    ##### set to 1 for TaxonOid column in Cart
    printStatusLine( "Loading", 1 );

    setSessionParam( "initial", "1" );

    my $count = scalar(@taxon_filter_oid);
    print "<p>\n";
    print "$count genome(s) in cart\n";
    print "</p>\n";

    # limit genome data to those in cart
    my $selectedOnlyClause = txsClause( "tx", $dbh );
    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    # TODO bug can't disconnect here since the gtt_taxon_oid temp is used
    ##$dbh->disconnect();

    printCartTab1Start();

    # TODO genomelist
    my $sql1 = qq{
        select tx.taxon_oid
        from taxon tx
        where 1 = 1
        $selectedOnlyClause
        $rclause
        $imgClause
    };
    require GenomeList;
    GenomeList::printGenomesViaSql($dbh, $sql1, '', '', 'genomeCart' );


    printCartTab1End($count);

    # end genomecarttab1
    printCartTab2($count);

    TabHTML::printTabDivEnd();
}

sub printGenomeCart {
    my ( $dbh, @taxon_filter_oid ) = @_;
    my $showTaxonOid = 0;     ##### set to 1 for TaxonOid column in Cart
    printStatusLine( "Loading", 1 );

    setSessionParam( "initial", "1" );

    my $count = scalar(@taxon_filter_oid);
    print "<p>\n";
    print "$count genome(s) in cart\n";
    print "</p>\n";

    my $str = qq{
      To view <b>Metadata</b> for genomes, go to
      <a href='$main_cgi?section=TaxonList&page=selected'>Genome Metadata</a>.
      <br/>To add more genomes to cart, please use the
      <a href='$main_cgi?section=TaxonList&page=TaxonListAlpha'>
      Genome Browser</a>.
    };
    printHint($str);
    print "<br/>";

    my $inFileClause;
    if ($in_file) {
        $inFileClause = "tx.in_file ";
    } else {
        $inFileClause = "'No' ";
    }

    my $outputColStr = param("outputCol");
    my @outputCol    = processParamValue($outputColStr);

    if ( scalar(@outputCol) == 0 && paramMatch("setGeneOutputCol") eq '' ) {
        my $colIDsExist = readColIdFile();
        if ( $colIDsExist ne '' ) {
            my @outColsExist = processParamValue($colIDsExist);
            push( @outputCol, @outColsExist );
        } else {
            push( @outputCol, "seq_center" );
            push( @outputCol, "proposal_name" );
            push( @outputCol, "total_gene_count" );
            push( @outputCol, "total_bases" );
        }
    }

    my $outColClause = '';
    my $anyStn       = -1;
    my $mOutStartIdx = -1;
    my @mOutCol      = ();
    for ( my $i = 0 ; $i < scalar(@outputCol) ; $i++ ) {
        my $c         = $outputCol[$i];
        my $tableType = TaxonTableConfiguration::findColType($c);
        if ( $tableType eq 'g' ) {
            if ( $c =~ /add_date/i || $c =~ /release_date/i ) {

                # its a date column
                # use iso format yyyy-mm-dd s.t. its ascii sortable - ken
                $outColClause .= ", to_char(tx.$c, 'yyyy-mm-dd') ";
            } else {
                $outColClause .= ", tx.$c ";
            }
        } elsif ( $tableType eq 'm' ) {
            $mOutStartIdx = $i if ( $mOutStartIdx == -1 );
            push( @mOutCol, $c );
        } elsif ( $tableType eq 's' ) {
            $outColClause .= ", stn.$c ";
            $anyStn = 1;
        }
    }
    if ( $mOutStartIdx >= 0 ) {
        $outColClause .= ", tx.sample_gold_id, tx.submission_id, tx.gold_id";
    }

    # limit genome data to those in cart
    my $selectedOnlyClause = txsClause( "tx", $dbh );
    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my $sql = qq{
        select tx.taxon_oid, tx.domain, tx.seq_status, tx.taxon_display_name,
        $inFileClause $outColClause
        from taxon tx, taxon_stats stn
        where tx.taxon_oid = stn.taxon_oid
        $selectedOnlyClause
        $rclause
        $imgClause
        order by tx.taxon_display_name
    };

    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    my @tOids;
    my %tOids2SubmissionIds = ();    #submissionIds, goldIds
    my %tOids2ProjectGoldIds = (); # taxon to gold project ids
    my %tOids2GoldIds       = ();
    my %taxons_in_file;

    for ( ; ; ) {
        my ( $taxon_oid, $domain, $seq_status, $taxon_display_name, $in_file_val, @outColVals ) = $cur->fetchrow();
        last if !$taxon_oid;

        if ( $in_file_val eq 'Yes' ) {
            $taxons_in_file{$taxon_oid} = 1;
        }

        my $r = "$taxon_oid\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= "$taxon_display_name\t";

        my $nOutColVals = scalar(@outColVals);
        for ( my $j = 0 ; $j < $nOutColVals ; $j++ ) {
            if (
                 $mOutStartIdx >= 0
                 && (    $j == $nOutColVals - 3
                      || $j == $nOutColVals - 2
                      || $j == $nOutColVals - 1 )
              )
            {
                if ( $j == $nOutColVals - 2 ) {
                    $tOids2SubmissionIds{$taxon_oid} = $outColVals[$j]
                      if ( $outColVals[$j] ne '' );
                } elsif ( $j == $nOutColVals - 1 ) {
                    $tOids2GoldIds{$taxon_oid} = $outColVals[$j]
                      if ( $outColVals[$j] ne '' );
                    $tOids2ProjectGoldIds{$taxon_oid} = $outColVals[$j] if ( $outColVals[$j] ne '' );

                    # gold id for metagenomes is actually $sample_gold_id - ken
                    # but not all metagenomes have sample_gold_id so the gold_id is
                    # use - but this gold_id is project_info level metadata
                    my $sample_gold_id = $outColVals[ $nOutColVals - 3 ];
                    if ( $sample_gold_id ne "" ) {
                        $tOids2GoldIds{$taxon_oid} = $sample_gold_id;
                    }
                }
            } else {
                if ( $outColVals[$j] eq '' ) {
                    # to stop the shift on a blank split
                    $r .= "0\t";
                } else {
                    $r .= "$outColVals[$j]\t";
                }
            }
        }

        push( @recs,  $r );
        push( @tOids, $taxon_oid );
    }
    $cur->finish();
    #$dbh->disconnect();

    my %tOids2Meta;
    %tOids2Meta = getMetadataForAttrs_new_2_0( \%tOids2SubmissionIds, \%tOids2GoldIds, \@mOutCol, \%tOids2ProjectGoldIds )
      if ( $mOutStartIdx >= 0 );

    
    TabHTML::printTabAPILinks("genomecartTab");
    my @tabIndex = ( "#genomecarttab1",   "#genomecarttab2" );
    my @tabNames = ( "Genomes in Cart", "Upload & Export & Save" );
    TabHTML::printTabDiv( "genomecartTab", \@tabIndex, \@tabNames );
    print "<div id='genomecarttab1'>";

    my $it = new InnerTable( 1, "genomecart$$", "genomecart", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Domain", "char asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "char asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Taxon ID", "char asc", "left" ) if $showTaxonOid;
    $it->addColSpec( TaxonTableConfiguration::getColLabel("taxon_display_name"), "char asc", "left" );

    my $select_id_name = "taxon_oid";

    foreach my $col (@outputCol) {
        my $colName  = TaxonTableConfiguration::getColLabel($col);
        my $tooltip  = TaxonTableConfiguration::getColTooltip($col);
        my $colAlign = TaxonTableConfiguration::getColAlign($col);
        if ( $colAlign eq "num asc right" ) {
            $it->addColSpec( "$colName", "asc", "right", '', $tooltip );
        } elsif ( $colAlign eq "num desc right" ) {
            $it->addColSpec( "$colName", "desc", "right", '', $tooltip );
        } elsif ( $colAlign eq "num desc left" ) {
            $it->addColSpec( "$colName", "desc", "left", '', $tooltip );
        } elsif ( $colAlign eq "char asc left" ) {
            $it->addColSpec( "$colName", "asc", "left", '', $tooltip );
        } elsif ( $colAlign eq "char desc left" ) {
            $it->addColSpec( "$colName", "desc", "left", '', $tooltip );
        } else {
            $it->addColSpec( "$colName", '', '', '', $tooltip );
        }
    }

    $count = 0;
    for my $r (@recs) {
        my ( $taxon_oid, $domain, $seq_status, $taxon_display_name, @outColVals ) = split( /\t/, $r );
        if ( $mOutStartIdx >= 0 ) {
            my $mOutColVals_str = $tOids2Meta{$taxon_oid};
            my @mOutColVals = split( /\t/, $mOutColVals_str );
            if ( scalar(@mOutColVals) < scalar(@mOutCol) ) {
                my $diff = scalar(@mOutCol) - scalar(@mOutColVals);
                for ( my $i = 0 ; $i < $diff ; $i++ ) {
                    push( @mOutColVals, '' );
                }
            }
            splice( @outColVals, $mOutStartIdx, 0, @mOutColVals );
        }
        $count++;

        my $row;
        $row .= $sd
          . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' />\t"
          . $domain
          . $sd
          . substr( $domain, 0, 1 ) . "\t"
          . $seq_status
          . $sd
          . substr( $seq_status, 0, 1 ) . "\t";

        $row .= $taxon_oid . $sd . $taxon_oid . "\t" if $showTaxonOid;

        my $url;
        if ( $taxons_in_file{$taxon_oid} ) {
            $url = "$main_cgi?section=MetaDetail&page=metaDetail&taxon_oid=$taxon_oid";
        } else {
            $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        }
        my $link = alink( $url, $taxon_display_name );

        $row .= $taxon_display_name . $sd . $link . "\t";

        for ( my $j = 0 ; $j < scalar(@outputCol) ; $j++ ) {
            my $col    = $outputCol[$j];
            my $colVal = $outColVals[$j];
            if ( $col eq 'proposal_name' ) {

                # to make sorting work - ken
                my $mynull = $colVal;
                if ( $colVal eq "" || $colVal eq "0") {
                    $mynull = "zzz";
                    $colVal = "_";
                }
                $row .= $mynull . $sd . $colVal . "\t";
            } elsif ( $colVal eq '_' && $col ne 'proposal_name' ) {

                # shift stop - see above where I add '_'
                # for blanks and in metadata from gold - ken
                $row .= '_' . $sd . '_' . "\t";
            } elsif ( $col eq "seq_center" && $colVal =~ /JGI/ ) {
                my $x1      = "<font color='red'>";
                my $x2      = "</font>";
                my $colVal2 = $colVal;
                $colVal2 =~ s/JGI/${x1}JGI${x2}/;
                $row .= $colVal . $sd . $colVal2 . "\t";
            } elsif ( $col eq "seq_center" && $colVal =~ /DOE Joint Genome Institute/ ) {
                my $x1      = "<font color='red'>";
                my $x2      = "</font>";
                my $colVal2 = $colVal;
                $colVal2 =~ s/DOE Joint Genome Institute/${x1}DOE Joint Genome Institute${x2}/;
                $row .= $colVal . $sd . $colVal2 . "\t";
            } elsif ( $col eq 'ncbi_taxon_id' && $colVal ) {
                my $ncbiTxid_url = "$taxonomy_base_url$colVal";
                $ncbiTxid_url = alink( $ncbiTxid_url, $colVal );
                $row .= $colVal . $sd . $ncbiTxid_url . "\t";
            } elsif ( $col eq 'refseq_project_id' && $colVal ) {
                my $ncbiPid_url = TaxonSearchUtil::getNCBIProjectIdLink($colVal);
                $row .= $colVal . $sd . $ncbiPid_url . "\t";
            } elsif ( $col eq 'gbk_project_id' && $colVal ) {
                my $ncbiPid_url = TaxonSearchUtil::getNCBIProjectIdLink($colVal);
                $row .= $colVal . $sd . $ncbiPid_url . "\t";
            } elsif ( $col eq 'gold_id' && $colVal ) {
                my $goldId_url = HtmlUtil::getGoldUrl($colVal);
                $goldId_url = alink( $goldId_url, $colVal );
                $row .= $colVal . $sd . $goldId_url . "\t";
            } elsif ( $col eq 'sample_gold_id' && $colVal ) {
                my $goldId_url = HtmlUtil::getGoldUrl($colVal);
                $goldId_url = alink( $goldId_url, $colVal );
                $row .= $colVal . $sd . $goldId_url . "\t";
            } elsif ( $col eq 'submission_id' && $colVal ) {
                my $url = $img_er_submit_url;
                $url = $img_mer_submit_url if ( $domain eq "*Microbiome" );
                $url = $url . $colVal;
                $url = alink( $url, $colVal );
                $row .= $colVal . $sd . $url . "\t";
            } elsif ( $col eq 'project_info' && $colVal ) {
                my $url =
                  "http://img.jgi.doe.gov/cgi-bin/submit/main.cgi?section=ProjectInfo&page=displayProject&project_oid=";
                $url .= $colVal;
                $url = alink( $url, $colVal );
                $row .= $colVal . $sd . $url . "\t";
            } else {
                if ( !$colVal || blankStr($colVal) ) {
                    $row .= nbsp(1)  . $sd . '_' . "\t";
                } else {
                    $row .= $colVal . $sd . $colVal . "\t";
                }
            }
        }
        $it->addRow($row);
    }

    printGenomeCartButtons() if $count > 10;
    $it->printOuterTable(1);
    printGenomeCartButtons(1);

    printStatusLine( "$count genome(s) in cart.", 2 );

    ## Table Configuration
    my %outputColHash = WebUtil::array2Hash(@outputCol);
    my $name          = "_section_${section}_setTaxonOutputCol";
    TaxonTableConfiguration::appendTaxonTableConfiguration( \%outputColHash, $name );
    writeColIdFile(@outputCol);
    print "</div>";    # end genomecarttab1

    print "<div id='genomecarttab2'>";
    print "<h2>Upload Genome Cart</h2>";
    printTaxonUploadFormContent('Yes');

    # Run JS for updating number of genomes in cart. See below.
    print qq {
        <script type="text/javascript">
        updCnt($count)
        </script>
    };

    print "<h2>Export Genomes</h2>";
    print "<p>\n";
    print "You may select genomes from the cart to export.";
    print "</p>\n";

    if ( $count == 0 ) {
        print "<p>You have 0 genomes to export.</p>\n";
    } else {
        print submit(
              -name  => "_section_${section}_exportGenomes_noHeader",
              -value => "Export Genomes",
              -class => "medbutton"
        );

        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

    print "</div>";    # end genomecarttab3
    TabHTML::printTabDivEnd();
}

sub exportGenomesInCart {
    my @tx_ids = param("taxon_oid");
    my @genome_oids2 = param('taxon_filter_oid');
    push(@tx_ids, @genome_oids2);
    if ( scalar(@tx_ids) == 0 ) {
        main::printAppHeader();
        webError("You must select at least one genome to export.");
    }

    printExcelHeader("genomecart_export$$.xls");
    print "taxon_oid\t";
    print "domain\t";
    print "taxon_name\n";

    my $dbh = dbLogin();
    my $taxonStr = OracleUtil::getNumberIdsInClause( $dbh, @tx_ids );

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my $sql = qq{
        select tx.taxon_oid, tx.domain, tx.taxon_display_name
        from taxon tx
        where tx.taxon_oid in ($taxonStr)
        $rclause
        $imgClause
        order by tx.domain, tx.taxon_oid, tx.taxon_display_name
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $tx, $domain, $name ) = $cur->fetchrow();
        last if !$tx;
        print "$tx\t$domain\t$name\n";
    }

    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) if ( $taxonStr =~ /gtt_num_id/i );
    #$dbh->disconnect();
    WebUtil::webExit(0);
}

############################################################################
# printCartJS - Genome cart specific JavaScript
#     JS function to update the genome count in the banner, called after
#     the cart is displayed
############################################################################
sub printCartJS {
    print qq{
        <script type="text/javascript">
        function updCnt(cnt) {
            var objCnt = document.getElementById("genome_cart").children[0];
            if (objCnt) {
                objCnt.innerHTML = cnt;
            }
        }
        </script>
    };
}

############################################################################
# printGenomeCartButtons
############################################################################
sub printGenomeCartButtons {
    my ($toPrintHint) = @_;

    if ($toPrintHint && $include_metagenomes) {
        my $str = qq{
            Scaffolds will not be added into cart for very large genomes.<br/>
            Only scaffolds (assembled data only) of selected MER-FS genomes
            can be added into cart.
        };
        printHint($str);
    }

    print submit(
        -name    => "_section_ScaffoldCart_addGenomeScaffold",
        -value   => "Add Scaffolds of Selected Genomes to Cart",
        -class   => 'medbutton',
	-onclick => "setSectionAndPage('ScaffoldCart','addGenomeScaffold');"
    );

    print nbsp(1);
    WebUtil::printButtonFooterInLineWithToggle();

    print submit(
          -name  => "_section_${section}_removeFromGenomeCart",
          -value => 'Remove Selected',
          -class => 'smdefbutton',
    );
    print "<br>\n";
}

############################################################################
# getNextBatchId
############################################################################
sub getGenomeCartNextBatchId {
    my ($records_aref) = @_;

    my $max_id = 0;
    foreach my $line (@$records_aref) {
        my ( $taxon_oid, $contact_oid, $batch_id, $name, $virtual_taxon_oid ) =
          split( /\t/, $line );
        if ( $batch_id > $max_id ) {
            $max_id = $batch_id;
        }
    }
    if ( !$max_id ) {
        return 1;
    }

    $max_id++;
    return $max_id;
}

# get next virtual taxon oid
# only for names genomes
# ids are negative starting from -1
sub getNextVirtualTaxonOid {
    my ($records_aref) = @_;

    my $max_id = 0;
    foreach my $line (@$records_aref) {
        my ( $taxon_oid, $contact_oid, $batch_id, $name, $virtual_taxon_oid ) =
          split( /\t/, $line );
        if ( $virtual_taxon_oid < $max_id ) {
            $max_id = $virtual_taxon_oid;
        }
    }

    $max_id--;
    return $max_id;

}

# get  virtual taxon ids for a given cart name
sub getVirtualTaxonIdForName {
    my ($cartname) = @_;

    my $records_aref = readCartFile();
    foreach my $line (@$records_aref) {
        chomp $line;
        my ( $taxon_oid, $contact_oid, $batch_id, $name, $virtual_taxon_oid ) =
          split( /\t/, $line );
        if ( $cartname eq $name ) {
            return $virtual_taxon_oid;
        }
    }
    return 0;    # no id found
}

# get cart name for a given virtual taxon oid
sub getCartNameForTaxonOid {
    my ($toid) = @_;

    my $records_aref = readCartFile();
    foreach my $line (@$records_aref) {
        chomp $line;
        my ( $taxon_oid, $contact_oid, $batch_id, $name, $virtual_taxon_oid ) =
          split( /\t/, $line );
        if ( $toid eq $virtual_taxon_oid ) {
            return $name;
        }
    }
    return "";    # no name found
}

############################################################################
# uploadGenomeCart - import from text files - reset batch id
############################################################################
sub uploadGenomeCart {
    my ($self) = @_;

    require ScaffoldCart;
    my @taxon_oids;
    my %upload_cart_names;
    my @recs_ids;
    my $dbh = dbLogin();
    my $errmsg;

    if ( !MyIMG::uploadOidsFromFile( "taxon_oid", \@taxon_oids, \$errmsg, "Cart Name", \%upload_cart_names ) ) {
        printStatusLine( "Error.", 2 );
        webError($errmsg);
    }

    # check what's already in the cart
    my %g_carts;    # file taxon oids
    my $records_aref = readCartFile();
    my %cart_names;      # file cart names
    my %cartname2oid;    # taxon cart name => virtual taxon oid
    foreach my $line (@$records_aref) {
        my ( $t_oid, $contact_oid, $batch_id, $name, $virtual_taxon_oid ) =
          split( /\t/, $line );
        $g_carts{$t_oid}     = $batch_id;
        $cart_names{$t_oid}  = "$name\t$virtual_taxon_oid";
        $cartname2oid{$name} = $virtual_taxon_oid;
    }

    my $next_batch             = ScaffoldCart::getNextBatchId($records_aref);
    my $next_virtual_taxon_oid = ScaffoldCart::getNextVirtualTaxonOid($records_aref);

    my @sqlList;         # new taxons to add


    my %taxon_oid_hash = QueryUtil::fetchValidTaxonOidHash( $dbh, @taxon_oids );
    @taxon_oids = ();
    @taxon_oids = keys %taxon_oid_hash;

    # what is uploaded
    foreach my $taxon_oid (@taxon_oids) {
        if ( exists $g_carts{$taxon_oid} ) {
            $g_carts{$taxon_oid}    = $next_batch;
            $cart_names{$taxon_oid} = $upload_cart_names{$taxon_oid};

        } else {
            $g_carts{$taxon_oid}    = $next_batch;
            $cart_names{$taxon_oid} = $upload_cart_names{$taxon_oid};

            # new to be added
            my $name              = $cart_names{$taxon_oid};
            my $virtual_taxon_oid = "";
            if ( $name ne "" && exists $cartname2oid{$name} ) {
                $virtual_taxon_oid = $cartname2oid{$name};
            } elsif ( $name ne "" ) {
                $virtual_taxon_oid = $next_virtual_taxon_oid;
                $cartname2oid{$name} = $virtual_taxon_oid;
                $next_virtual_taxon_oid--;
            }
            push @sqlList, "$taxon_oid\t$contact_oid\t$next_batch\t$name\t$virtual_taxon_oid\n";
        }
    }

    # write to file
    my $res = newWriteFileHandle( getStateFile(), "runJob" );
    foreach my $line (@$records_aref) {
        my ( $t_oid, $contact_oid, $batch_id, $name, $virtual_taxon_oid ) =
          split( /\t/, $line );
        push( @recs_ids, $t_oid );

        # new batch id
        $name = $cart_names{$t_oid};
        print $res "$t_oid\t$contact_oid\t$next_batch\t$name\t$virtual_taxon_oid\n";

    }

    push( @recs_ids, @taxon_oids );

    # get existing genome oids from cart
    my $existing_oids = getAllGenomeOids();

    # add to current cart
    push( @recs_ids, @$existing_oids );

    my %h                    = WebUtil::array2Hash(@recs_ids);            # get unique taxon_oid's
    my @taxon_filter_oid     = sort( keys(%h) );
    my $taxon_filter_oid_str = join( ",", @taxon_filter_oid );

    setTaxonSelections( $taxon_filter_oid_str, $dbh );
    if ( blankStr($taxon_filter_oid_str) ) {
        setSessionParam( "blank_taxon_filter_oid_str", "1" );
    } else {
        setSessionParam( "blank_taxon_filter_oid_str", "0" );
    }

    foreach my $line (@sqlList) {
        print $res "$line\n";
    }

    close $res;
}

############################################################################
# addToGenomeCart
############################################################################
sub addToGenomeCart {
    my ($genome_oids_aref) = @_;

    my @genome_oids = param('taxon_oid');
    if ( $#genome_oids < 0 ) {
        @genome_oids = @$genome_oids_aref;
    }

    if ( scalar(@genome_oids) == 0 ) {
        webError("No genomes have been selected or can be derived.");
        return;
    }

    my $dbh = dbLogin();
    my %taxon_oid_hash = QueryUtil::fetchValidTaxonOidHash( $dbh, @genome_oids );
    @genome_oids = keys %taxon_oid_hash;
    if ( scalar(@genome_oids) == 0 ) {
        webError("Obsolete genomes cannot be added into Cart.");
        return;
    }

    # check what's already in the cart
    my %t_carts;
    my %cart_names;
    my $records_aref = readCartFile();
    my $recsNum = scalar(@$records_aref);
    #print "addToGenomeCart() recsNum=$recsNum<br/>\n";
    if ( !$recsNum || $recsNum < CartUtil::getMaxDisplayNum() ) {

        foreach my $line (@$records_aref) {
            my ( $taxon_oid, $contact_oid, $batch_id, $name, $virtual_taxon_oid ) =
              split( /\t/, $line );
            $t_carts{$taxon_oid}    = 1;
            $cart_names{$taxon_oid} = "$name\t$virtual_taxon_oid";
        }

        my $next_batch = getGenomeCartNextBatchId($records_aref);

        my $res = newAppendFileHandle( getStateFile(), "append 1" );
        for my $taxon_oid (@genome_oids) {
            if ( $t_carts{$taxon_oid} ) {
                # already there
                next;
            }

            $t_carts{$taxon_oid} = 1;    # make sure there are no duplicates

            # add - $virtual_taxon_oid was added
            my $name = $cart_names{$taxon_oid};
            print $res "$taxon_oid\t$contact_oid\t$next_batch\t$name\n";

            $recsNum++;
            if ( $recsNum >= CartUtil::getMaxDisplayNum() ) {
                last;
            }
        }
        close $res;
    }
}

############################################################################
# remove From Genome Cart
############################################################################
sub removeFromGenomeCart {
    #printMainForm();
    # clear cache before we remove the genome, just like add to genome cart
	require GenomeList;
	GenomeList::clearCache();

    print "<p>\n";    # paragraph section puts text in proper font.

    my @genome_oids = param('taxon_oid');
    my @genome_oids2 = param('taxon_filter_oid');
    push(@genome_oids, @genome_oids2);
    if ( scalar(@genome_oids) == 0 ) {
        webError("No genomes have been selected.");
        return;
    }

    my $aref = readCartFile();
    my %hash;         # ids to remove

    # convert to array to hash
    foreach my $taxon_oid (@genome_oids) {
        $hash{$taxon_oid} = $taxon_oid;
    }

    my $res = newWriteFileHandle( getStateFile(), "runJob" );

    my $cnt = 0;
    foreach my $line (@$aref) {
        my ( $taxon_oid, $contact_oid, $batch_id, $name, $virtual_taxon_oid ) =
          split( /\t/, $line );
        if ( exists $hash{$taxon_oid} ) {

            # delete
            # do nothing
            # next
        } else {
            print $res "$line\n";
            $cnt++;
        }
    }
    close $res;

    if ( $cnt == 0 ) {
        wunlink( getColIdFile() );    # remove col id file
    }
}

#
# genome cart file
#
sub getStateFile {

	my ($cartDir, $sessionId) = WebUtil::getCartDir();
	return "$cartDir/genomeCart.$sessionId.stor";
}

sub getColIdFile {

	my ($cartDir, $sessionId) = WebUtil::getCartDir();
	return "$cartDir/genomeCart.$sessionId.colid";
}

#
# read sessson genome cart
# return array ref of lines
#
sub readCartFile {
    my $res = newReadFileHandle( getStateFile(), "runJob", 1 );
    if ( !$res ) {
        return [];
    }
    my @records;
    while ( my $line = $res->getline() ) {
        chomp $line;
        push @records, $line if $line;
    }
    close $res;
    return \@records;
}

#
# read sessson genome cart column ids
# return one line
#
sub readColIdFile {
    my $colIDs = '';
    my $res = newReadFileHandle( getColIdFile(), "runJob", 1 );
    if ($res) {
        my $line = $res->getline();
        chomp $line;
        $colIDs = $line;
        close $res;
    }
    return $colIDs;
}

sub writeColIdFile {
    my (@outCols) = @_;

    my $colIDs = '';
    foreach my $col (@outCols) {
        $colIDs .= "$col,";
    }
    if ( $colIDs eq '' ) {
        wunlink( getColIdFile() );    # remove col id file
    } else {
        my $res = newWriteFileHandle( getColIdFile(), "runJob", 1 );
        if ($res) {
            print $res "$colIDs\n";
            close $res;
        }
    }
}

# all genome oids in cart
sub getAllGenomeOids {

    my $records_aref = readCartFile();

	# return the first column from each line, excluding blank lines
	return [ grep { /\w/ } map { ( split "\t" )[0] } @$records_aref ];
=cut
    my @list;
    for my $line (@$records_aref) {
        chomp $line;
        my @arr = split /\t/, $line;
        my ( $taxon_oid, $contact_oid, $batch_id, $name, $virtual_taxon_oid ) =
          split( /\t/, $line );
        if ($taxon_oid) {
            push( @list, $taxon_oid );
        }
    }

    #print "getAllGenomeOids: @list<br/>\n";
    return \@list;
=cut
}

#
# is the genome cart empty
#
sub isCartEmpty {
    my $res = newReadFileHandle( getStateFile(), "runJob", 1 );
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

#
# insert genome ids to ggt - gtt_taxon_oid
# remember this is a session insert
#
sub insertToGtt {
    my ($dbh) = @_;
    my $taxon_oids_aref = getAllGenomeOids();
    return if ( $#$taxon_oids_aref < 0 );

    if ( OracleUtil::tableExist( $dbh, "gtt_taxon_oid" ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_taxon_oid", $taxon_oids_aref );
    } else {
        webError(   "Unable to create Genome Cart.<br/>"
                  . "Required temp table does not exist. "
                  . "Please contact Technical Support" );
    }
}

############################################################################
# addGeneGenomeToCart
############################################################################
sub addGeneGenomeToCart {
    my @gene_oids = param('gene_oid');
    if ( scalar(@gene_oids) == 0 ) {
        printMainForm();
        webError("No genes have been selected.");
        return;
    }

    my $dbh = dbLogin();
    my $genomeOid_href = getGenomeOidsFromGeneOids( $dbh, \@gene_oids );
    #$dbh->disconnect();
    addToGenomeCart( [ keys %$genomeOid_href ] );
}

############################################################################
# addScaffoldGenomeToCart
############################################################################
sub addScaffoldGenomeToCart {
    my @scaffold_oids = param('scaffold_oid');
    if ( scalar(@scaffold_oids) == 0 ) {
        printMainForm();
        webError("No scaffolds have been selected.");
        return;
    }

    my $dbh = dbLogin();
    my $genomeOid_href = getGenomeOidsFromScaffoldOids( $dbh, \@scaffold_oids );

    addToGenomeCart( [ keys %$genomeOid_href ] );
}

#
# get all the genomes from a list of gene oids
# returns a hash of genome oids as keys
#
sub getGenomeOidsFromGeneOids {
    my ( $dbh, $gene_oids_ref ) = @_;

    my ($dbOids_ref, $metaOids_ref) = MerFsUtil::splitDbAndMetaOids(@$gene_oids_ref);
    my @dbOids = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    # found genome oids
    my %foundIds;

    if (scalar(@dbOids) > 0) {
        %foundIds = QueryUtil::fetchGeneGenomeOidsHash( $dbh, @dbOids );
    }

    if (scalar(@metaOids) > 0) {
        my %taxon_oid_hash = MerFsUtil::fetchValidMetaTaxonOidHash( $dbh, @metaOids );
        for my $oid (keys %taxon_oid_hash) {
            $foundIds{$oid} = 1;
        }
    }

    return \%foundIds;
}


#
# get all the genomes from a list of scaffold oids
# returns a hash of genome keys
#
sub getGenomeOidsFromScaffoldOids {
    my ( $dbh, $scaffold_oids_ref ) = @_;

    my ( $dbOids_ref, $metaOids_ref ) =
      MerFsUtil::splitDbAndMetaOids(@$scaffold_oids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    # found genome ids
    my %foundIds;

    if ( scalar(@dbOids) > 0 ) {
        %foundIds = QueryUtil::fetchScaffoldGenomeOidsHash( $dbh, @dbOids );
    }

    if ( scalar(@metaOids) > 0 ) {
        my %taxon_oid_hash =
          MerFsUtil::fetchValidMetaTaxonOidHash( $dbh, @metaOids );
        for my $oid ( keys %taxon_oid_hash ) {
            $foundIds{$oid} = 1;
        }
    }

    return \%foundIds;
}


1;
