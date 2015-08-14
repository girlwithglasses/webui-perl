############################################################################
# AbundanceToolkit - Allows users to customize functional abundance
#     measurements.
#        --es 05/19/2007
#
# $Id: AbundanceToolkit.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package AbundanceToolkit;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use WebConfig;
use WebUtil;
use ScaffoldCart;
use OracleUtil;
use GenomeListFilter;
use MetaUtil;

my $section = "AbundanceToolkit";
my $env                 = getEnv();
my $main_cgi            = $env->{main_cgi};
my $section_cgi         = "$main_cgi?section=$section";
my $inner_cgi           = $env->{inner_cgi};
my $verbose             = $env->{verbose};
my $base_dir            = $env->{base_dir};
my $img_internal        = $env->{img_internal};
my $include_img_terms   = $env->{include_img_terms};
my $include_metagenomes = $env->{include_metagenomes};
my $show_myimg_login    = $env->{show_myimg_login};
my $img_lite            = $env->{img_lite};
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};
my $preferences_url     = "$main_cgi?section=MyIMG&form=preferences";

my $top_n_abundances     = 10000;           # make a very large number
my $max_query_taxons     = 20;
my $max_reference_taxons = 200;
my $r_bin                = $env->{r_bin};

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( ! $merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

my $scaffold_cart  = $env->{scaffold_cart};

my $in_file = $env->{in_file};
my $mer_data_dir   = $env->{mer_data_dir};

my $max_batch       = 500;
my %function2IdType = (
    cog     => "cog_id",
    enzyme  => "ec_number",
    ko      => "ko_id",
    pfam    => "pfam_id",
    tigrfam => "tigrfam_id",
);

my $estNormalizationText = "Normalize to Total Size for Unassembled Only";

############################################################################
# dispatch - Dispatch events.
############################################################################
sub dispatch {
    my $page = param("page");
    timeout( 60 * 20 );    # timeout in 20 minutes (from main.pl)

    if ( paramMatch("abundanceResults") ne "" ) {
        printAbundanceResults();
    } elsif ( $page eq "abundancePager" ) {
        printAbundancePager();
    } elsif ( $page eq "abundanceDownload" ) {
        printAbundanceDownload();
    } elsif ( $page eq "geneList" ) {
        printGeneList();
    } elsif ( $page eq "dscoreNote" ) {
        printDScoreNote();
    } else {
        printQueryForm();
    }
}

############################################################################
# getEstNormalizationText
############################################################################
sub getEstNormalizationText {
    return $estNormalizationText;
}

############################################################################
# printQueryForm - Show query form for abundances.
############################################################################
sub printQueryForm {

    print "<h1>Abundance Toolkit</h1>\n";
    print "<p>\n";
    print "The abundance toolkit allows you customize functional ";
    print "abundance measurements for browsing and export.<br/>\n";
    print "The exported values in tab-delimited format may be ";
    print "used by external statistical tools.<br/>\n";
    print "</p>\n";

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";
    printOptionLabel("Page Options");
    print "<br/>";
    print nbsp(2);
    print popup_menu(
        -name    => "funcsPerPage",
        -values  => [ 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 ],
        -default => 500
    );
    print nbsp(1);
    print "functions per page.\n";
    print "<br/>\n";
    print "<br/>\n";

    printOptionLabel( "Genomes");
    print "</p>\n";

    my $dbh = dbLogin();
    GenomeListFilter::appendGenomeListFilter($dbh, '', 0, 'queryGenomes');
    #$dbh->disconnect();

    print "<p>\n";
    printOptionLabel("Function");
    print "<input type='radio' name='function' value='cog' checked />\n";
    print "COG<br/>\n";
    print "<input type='radio' name='function' value='pfam' />\n";
    print "Pfam<br/>\n";
    print "<input type='radio' name='function' value='enzyme' />\n";
    print "Enzyme<br/>\n";
    print "<input type='radio' name='function' value='tigrfam' />\n";
    print "TIGRfam<br/>\n";
    print "<br/>\n";

    printOptionLabel("Measurement");
    print "<input type='radio' name='xcopy' value='gene_count' checked />\n";
    print "Gene count<br/>\n";
    print "<input type='radio' name='xcopy' value='est_copy' />\n";
    print "Estimated gene copies<sup>1</sup><br/>\n";
    print "<br/>\n";

    # --es 07/18/2007
    printOptionLabel("Output");
    print "<input type='checkbox' name='allRows' value='1' />\n";
    print "Include all rows, including those without hits\n";
    print "<br/>\n";

    my $name = "_section_${section}_abundanceResults";
    print submit( -id => "go", -name => $name,
		  -value => "Go", -class => "smdefbutton" );
    print nbsp(1);
    print reset( -id => "reset", -class => "smbutton" );
    print "<br/>\n";
    print "</p>\n";

    printStatusLine( "Loaded.", 2 );
    print end_form();

    print "<p>\n";
    print "<b>Notes:</b><br/>\n";
    print "1 - Estimated by multiplying by read depth when available.<br/>\n";
    print "</p>\n";

    printHint(
            "- Hold down control key (or command key in the case of Mac) "
          . "to select multiple genomes.<br/>\n"
          . "- Drag down list to select all genomes.<br/>\n"
          . "- More genome and function selections result in slower query.\n" );

}

############################################################################
# printOptionLabel
############################################################################
sub printOptionLabel {
    my ( $s, $footnote ) = @_;
    print "<b>";
    print "<font color='blue'>";
    print "$s";
    print "</font>";
    print "</b>";
    if ( $footnote ne "" ) {
        print "<sup>$footnote</sup>\n";
    }
    print ":<br/>\n";
}


############################################################################
# printAbundanceResults - Show results from query form.
############################################################################
sub printAbundanceResults {
    my @queryGenomes  = param('genomeFilterSelections');#OracleUtil::processTaxonSelectionParam("queryGenomes");

    #my @selectGenomes = param('genomeFilterSelections');
    #push(@queryGenomes, @selectGenomes);

    my $function      = param("function");
    my $xcopy         = param("xcopy");
    my $normalization = param("normalization");
    my $data_type     = param("data_type");
    my $funcsPerPage  = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);

    # scaffold cart
    # new for merged forms - ken 2008-16-12
    my $display = param("display");
    if ( $display eq "matrix" ) {
        $function     = param("cluster");
        if($function eq "") {
            $function = param("function");
        }
        @queryGenomes = param("profileTaxonOid");
    }

    print "<h1>Abundance Toolkit</h1>\n" if ( $display eq "" );

    my $nQueryGenomes = @queryGenomes;
    my $vir_count = 0;
    if ($scaffold_cart) {
         my @scaffold_cart_names = param("scaffold_cart_name");
        $vir_count = $#scaffold_cart_names + 1;
    }
    if ( $nQueryGenomes == 0 && $vir_count == 0) {
        webError("Please select 1 to $max_query_taxons genomes.<br/>\n");
    }

    printStatusLine( "Loading ...", 1 );
    print "<p>\n";

    my $dbh = dbLogin();
    #my %funcId2Name;
    my $funcId2Name_href = getFuncDict($dbh, $function);
    #print Dumper($funcId2Name_href);
    #print "<br/>\n";

    my %queryTaxonProfiles;
    getProfileVectors( $dbh, "query", \@queryGenomes, $function, $xcopy, '',
        \%queryTaxonProfiles, $data_type );
    #print Dumper(\%queryTaxonProfiles);
    #print "<br/>\n";

    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );

    webLog("pagerFileRoot $pagerFileRoot'\n");
    my $nFuncs =
      writePagerFiles( $dbh, $pagerFileRoot, $funcId2Name_href,
        \%queryTaxonProfiles );
    print "</p>\n";

    #$dbh->disconnect();

    printOnePage(1);
    printStatusLine( "$nFuncs functions $nQueryGenomes genomes loaded.", 2 );
}

############################################################################
# writePagerFiles - Write files for pager.
#   It writes to a file with 2 data columns for each
#   cell value.  One is for sorting.  The other is for display.
#   (Usually, they are the same, but sometimes not.)
############################################################################
sub writePagerFiles {
    my ( $dbh, $pagerFileRoot, $funcId2Name_ref, $queryTaxonProfiles_ref ) = @_;

    my $funcsPerPage = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);

    my $allRows      = param("allRows");
    my $function     = param("function");
    my $data_type    = param("data_type");
    my $xcopy        = param("xcopy");

    # merged form - ken
    my $display = param("display");
    if ( $display eq "matrix" ) {
        $function = param("cluster");
        if($function eq "") {
            $function = param("function");
        }
    }

    my $normalization         = param("normalization");
    my $idType                = $function2IdType{$function};
    my $doGenomeNormalization = 0;
    $doGenomeNormalization = 1 if $normalization eq "genomeSize";

    my $metaFile = "$pagerFileRoot.meta";    # metadata
    my $rowsFile = "$pagerFileRoot.rows";    # tab delimted rows for pager
    my $idxFile  = "$pagerFileRoot.idx";     # index file
    my $xlsFile  = "$pagerFileRoot.xls";     # Excel export file

    my $Fmeta = newWriteFileHandle( $metaFile, "writePagerFiles" );
    my $Frows = newWriteFileHandle( $rowsFile, "writePagerFiles" );
    my $Fxls  = newWriteFileHandle( $xlsFile,  "writePagerFiles" );

    my @taxon_oids = keys(%$queryTaxonProfiles_ref);

    my $nQueryGenomes    = @taxon_oids;

    # scaffold cart
    my @query_taxon_oids = sortByTaxonName( $dbh, \@taxon_oids );

    my @funcIds = sort( keys(%$funcId2Name_ref) );
    my $nFuncs  = @funcIds;
    my $nPages  = int( $nFuncs / $funcsPerPage ) + 1;

    my %queryFuncsSum;
    my %referenceFuncsSum;
    for my $funcId (@funcIds) {
        $queryFuncsSum{$funcId}     = 0;
        $referenceFuncsSum{$funcId} = 0;
    }

    ## Output rows data

    ## Metadata for pager
    print $Fmeta ".funcsPerPage $funcsPerPage\n";
    print $Fmeta ".nPages $nPages\n";
    print $Fmeta ".attrNameStart\n";

    ## Column header for pager
    my $colIdx = 0;
    print $Fmeta "$colIdx :  Select\n";
    $colIdx++;
    print $Fmeta "$colIdx :  Row<br/>No. : AN: right\n";
    $colIdx++;
    print $Fmeta "$colIdx :  ID : AS : left\n";
    $colIdx++;
    print $Fmeta "$colIdx :  Name : AS : left\n";
    $colIdx++;

    ## get MER-FS taxons
    my %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile( $dbh, @query_taxon_oids );
    for my $taxon_oid (@query_taxon_oids) {
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        my $abbrName = WebUtil::abbrColName( $taxon_oid, $name, 1 );
    	if ( $mer_fs_taxons{$taxon_oid} ) {
    	    $name .= " (MER-FS)";
    	    $abbrName .= "<br/>(MER-FS)";
            if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                $abbrName .= "<br/>($data_type)";
            }
    	}
        print $Fmeta "$colIdx : $abbrName<br/> : "
          . "DN : right : $name ($taxon_oid)\n";
        $colIdx++;
    }
    print $Fmeta ".attrNameEnd\n";

    ## Excel export header
    print $Fxls "Func_id\t";
    print $Fxls "Func_name\t";
    my $s;
    for my $taxon_oid (@query_taxon_oids) {
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        $name = excelHeaderName($name);
        $s .= "$name\t";
    }

    chop $s;
    print $Fxls "$s\n";

    my $count = 0;
    for my $funcId (@funcIds) {
        ## --es 07/18/2007
        my $allZeros = 1;
        for my $taxon_oid (@query_taxon_oids) {
            my $profile_ref = $queryTaxonProfiles_ref->{$taxon_oid};
            if ( !defined($profile_ref) ) {
                warn("writePagerFiles: cannot find q.profile for $taxon_oid\n");
                next;
            }
            my $cnt = $profile_ref->{$funcId};
            $allZeros = 0 if $cnt > 0;
        }
        next if $allZeros && !$allRows;
        $count++;
        my $funcName = $funcId2Name_ref->{$funcId};
        my $r;
        my $xls;

        # select
        $r .= "\t";
        $r .= "<input type='checkbox' name='$idType' value='$funcId' />\t";

        # row number
        $r .= "$count\t";
        $r .= "$count\t";

        # function id
        $r   .= "$funcId\t";
        $r   .= "$funcId\t";
        $xls .= "$funcId\t";

        # function name
        $r   .= "$funcName\t";
        $r   .= "$funcName\t";
        $xls .= "$funcName\t";
        for my $taxon_oid (@query_taxon_oids) {
            next if !isInt($taxon_oid);
            my $profile_ref = $queryTaxonProfiles_ref->{$taxon_oid};
            if ( !defined($profile_ref) ) {
                warn("writePagerFiles: cannot find q.profile for $taxon_oid\n");
                next;
            }
            my $cnt = $profile_ref->{$funcId};
            $cnt = 0 if $cnt eq "";
            $cnt = sprintf( "%.2f", $cnt ) if $doGenomeNormalization;
            $r .= "$cnt\t";

            my $url;
    	    if ( $mer_fs_taxons{$taxon_oid} ) {
                $url = "main.cgi?section=MetaDetail&page=";
        		if ( $funcId =~ /COG/ ) {
        		    $url .= "cogGeneList&cog_id=$funcId";
        		}
                elsif ( $funcId =~ /EC\:/ ) {
                    $url .= "enzymeGeneList&ec_number=$funcId";
                }
                elsif ( $funcId =~ /KO\:/ ) {
                    $url .= "koGenes&koid=$funcId";
                }
        		elsif ( $funcId =~ /pfam/ ) {
        		    $url .= "pfamGeneList&func_id=$funcId";
        		}
        		elsif ( $funcId =~ /TIGR/ ) {
        		    $url .= "tigrfamGeneList&func_id=$funcId";
        		}
        		else {
        		    $url = "";
        		}
        		if ( $url ) {
        		    $url .= "&taxon_oid=$taxon_oid&data_type=$data_type";
        		}
    	    }
    	    else {
                $url = "$section_cgi&page=geneList";
                $url .= "&funcId=$funcId&function=$function&taxon_oid=$taxon_oid";
    	    }

            if ( $url ) {
                if ( $xcopy eq 'est_copy' ) {
                    $url .= "&xcopy=est_copy&est=$cnt";
                }
            }

            my $link = alink( $url, $cnt );
            if ( ! $url ) {
        		$link = $cnt;
    	    }

            if($cnt == 0 &&  param("cluster") eq "enzyme" ) {
                # find other taxon oids v2.9 - ken
                my @othertoids;
                for my $t (@query_taxon_oids) {
                    next if($t eq $taxon_oid);
                    push(@othertoids, $t);
                }
                my $otherTaxonOids = join(",",@othertoids);

                my $url = "main.cgi?section=MissingGenes&page=candidatesForm"
                ."&taxon_oid=$taxon_oid"
                ."&funcId=$funcId"
                ."&otherTaxonOids=$otherTaxonOids";
                $link = alink($url, 0);
            } elsif($cnt == 0) {
                $link = 0;
            }

            $r   .= "$link\t";
            $xls .= "$cnt\t";
        }
        chop $r;
        chop $xls;
        print $Frows "$r\n";
        print $Fxls "$xls\n";
    }
    webLog("$count $function rows written\n");

    close $Fmeta;
    close $Frows;
    close $Fxls;

    indexRows( $rowsFile, $idxFile, $funcsPerPage );
    return $count;
}

############################################################################
# indexRows - Index rows in file.
############################################################################
sub indexRows {
    my ( $inFile, $outFile, $funcsPerPage, $nPages ) = @_;

    my $rfh = newReadFileHandle( $inFile,   "indexRows" );
    my $wfh = newWriteFileHandle( $outFile, "indexRows" );
    my $count  = 0;
    my $fpos   = tell($rfh);
    my $pageNo = 1;
    print $wfh "$pageNo $fpos\n";
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $count++;
        if ( $count > $funcsPerPage ) {
            $pageNo++;
            print $wfh "$pageNo $fpos\n";
            $count = 1;
        }
        $fpos = tell($rfh);
    }
    close $rfh;
    close $wfh;
}

############################################################################
# printAbundancePager - Show pages in pager.
############################################################################
sub printAbundancePager {
    my $pageNo   = param("pageNo");
    my $colIdx   = param("colIdx");
    my $function = param("function");

    # merged form - ken
    my $display = param("display");
    if ( $display eq "matrix" ) {
        $function = param("cluster");
        if($function eq "") {
            $function = param("function");
        }
    }

    my $xcopy         = param("xcopy");
    my $normalization = param("normalization");
    my $funcsPerPage  = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);
    my $sortType      = param("sortType");

    if ( $display eq "" ) {
        print "<h1>Abundance Toolkit</h1>\n";
    } else {
         print "<h1>Abundance Profile Overview Results</h1>\n";
    }
    printStatusLine( "Loading ...", 1 );
    if ( $sortType ne "" ) {
        sortAbundanceFile( $function, $xcopy, $normalization, $sortType,
            $colIdx, $funcsPerPage );
        $pageNo = 1;
    }

    printOnePage($pageNo);
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# sortAbundanceFile - Resort abundance file.
############################################################################
sub sortAbundanceFile {
    my ( $function, $xcopy, $normalization, $sortType, $colIdx, $funcsPerPage )
      = @_;

    webLog("resorting sortType='$sortType' colIdx='$colIdx'\n");
    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );
    my $pagerFileRows = "$pagerFileRoot.rows";
    my $pagerFileIdx  = "$pagerFileRoot.idx";
    if ( !(-e $pagerFileRows) || !(-e $pagerFileIdx)) {
        webLog("Expired session file '$pagerFileRows' or '$pagerFileIdx'\n");
        webError("Session file expired.<br/>Please start your 'Function Comparison' study from the beginning.\n");
    }

    my $rfh           = newReadFileHandle( $pagerFileRows, "sortAbudanceFile" );
    my @recs;
    my $rowIdx = 0;
    my @sortRecs;

    while ( my $s = $rfh->getline() ) {
        chomp $s;
        push( @recs, $s );
        my (@vals) = split( /\t/, $s );
        my $idx = $colIdx * 2;
        my $sortVal = $vals[$idx];
        my $sortRec = "$sortVal\t";
        $sortRec .= "$rowIdx";
        push( @sortRecs, $sortRec );
        $rowIdx++;
    }
    close $rfh;
    my @sortRecs2;
    if ( $sortType =~ /N/ ) {
        if ( $sortType =~ /D/ ) {
            @sortRecs2 = reverse( sort { $a <=> $b } (@sortRecs) );
        } else {
            @sortRecs2 = sort { $a <=> $b } (@sortRecs);
        }
    } else {
        if ( $sortType =~ /D/ ) {
            @sortRecs2 = reverse( sort(@sortRecs) );
        } else {
            @sortRecs2 = sort(@sortRecs);
        }
    }
    my $wfh = newWriteFileHandle( $pagerFileRows, "sortAbundanceFile" );
    for my $r2 (@sortRecs2) {
        my ( $sortVal, $rowIdx ) = split( /\t/, $r2 );
        my $r = $recs[$rowIdx];
        print $wfh "$r\n";
    }
    close $wfh;
    indexRows( $pagerFileRows, $pagerFileIdx, $funcsPerPage );
}

############################################################################
# getPagerFileRoot - Convention for getting the pager file.
############################################################################
sub getPagerFileRoot {
    my ( $function, $xcopy, $normalization ) = @_;
    my $sessionId    = getSessionId();
    my $tmpPagerFile =
        "$cgi_tmp_dir/abundanceToolkit.$function"
      . ".$xcopy.$normalization.$sessionId";
}

############################################################################
# printOnePage - Print one page for pager.
############################################################################
sub printOnePage {
    my ($pageNo) = @_;
    my $colIdx   = param("colIdx");
    my $function = param("function");

    # merged form - ken
    my $display = param("display");
    if ( $display eq "matrix" ) {
        $function = param("cluster");
        if($function eq "") {
            $function = param("function");
        }

        # javascript form
        print qq{
        <script language="JavaScript" type="text/javascript">
        <!--
        function mySubmit2(pageNum) {
            document.mainForm2.pageNo.value = pageNum;
            document.mainForm2.submit();
        }
        -->
        </script>
        };

        print qq{
        <script language="JavaScript" type="text/javascript">
        <!--
        function mySubmit3(pageNum) {
            document.mainForm3.pageNo.value = pageNum;
            document.mainForm3.submit();
        }
        -->
        </script>
        };

    }

    # Ken - 3rd column is the function name
    my $clusterMatchText = param("clusterMatchText");

    my $xcopy                 = param("xcopy");
    my $normalization         = param("normalization");
    my $funcsPerPage          = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);

    my $doGenomeNormalization = 0;
    $doGenomeNormalization = 1               if $normalization eq "genomeSize";
    $pageNo                = param("pageNo") if $pageNo        eq "";
    $pageNo                = 1               if $pageNo        eq "";

    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );
    my $pagerFileIdx  = "$pagerFileRoot.idx";
    my $pagerFileRows = "$pagerFileRoot.rows";
    my $pagerFileMeta = "$pagerFileRoot.meta";
    my $pagerFileXls  = "$pagerFileRoot.xls";
    if ( !-e ($pagerFileIdx) ) {
        warn("$pagerFileIdx not found\n");
        webError( "Session expired for this page 1 $pagerFileIdx."
              . "  Please start again." );
    }
    if ( !-e ($pagerFileRows) ) {
        warn("$pagerFileRows not found\n");
        webError("Session expired for this page 2.  Please start again.");
    }
    if ( !-e ($pagerFileMeta) ) {
        warn("$pagerFileMeta not found\n");
        webError("Session expired for this page 3.  Please start again.");
    }
    if ( !-e ($pagerFileXls) ) {
        warn("$pagerFileXls not found\n");
        webError("Session expired for this page 4.  Please start again.");
    }

    my %metaData      = loadMetaData($pagerFileMeta);
    my $funcsPerPage  = $metaData{funcsPerPage};
    my $attrSpecs_ref = $metaData{attrSpecs};
    my $n1            = $metaData{n1};
    my $n2            = $metaData{n2};
    my $nAttrSpecs    = @$attrSpecs_ref;
    my $nAttrSpecs2   = $nAttrSpecs * 2;

    my $colorLegend = getAbsColorLegend();
    $colorLegend = getRelColorLegend() if $doGenomeNormalization;
    printHint( "- Click on column name to sort.<br/>"
          . "- Mouse over genome abbreviation to see genome name "
          . "and taxon object identifier.<br/>"
          . "- Click on count to see constituent genes.<br/>"
          . "- $colorLegend.<br/>" );

    WebUtil::printMainFormName("2");
    printPageHeader( $function, $xcopy, $normalization, $pageNo,
        $clusterMatchText, "2" );
    print "\n";
    print end_form();
    print "\n";

    printMainForm();
    printFuncCartFooter();
    my %rightAlign;
    my $idx = 0;
    print "<table class='img' border='1'>\n";
    for my $attrSpec (@$attrSpecs_ref) {
        my ( $colIdx, $attrName, $sortType, $align, $mouseover ) =
          split( /:/, $attrSpec );
        $colIdx    =~ s/\s//g;
        $attrName  =~ s/^\s+//;
        $attrName  =~ s/\s+$//;
        $mouseover =~ s/^\s+//;
        $mouseover =~ s/\s+$//;
        $sortType  =~ s/\s+//g;
        if ( $sortType eq "" ) {
            print "<th class='img'>$attrName</th>\n";
        } else {
            my $url = "$section_cgi&page=abundancePager";
            $url .= "&sortType=$sortType";
            $url .= "&function=$function";
            $url .= "&xcopy=$xcopy";
            $url .= "&normalization=$normalization";
            $url .= "&colIdx=$colIdx";
            $url .= "&pageNo=1";
            $url .= "&funcsPerPage=$funcsPerPage";
            if($display ne "") {
                $url .= "&display=$display";
            }
            my $x;
            $x = "title='$mouseover'" if $mouseover ne "";
            my $link = "<a href='$url' $x>$attrName</a>";
            print "<th class='img'>$link</th>\n";
        }
        if ( $align =~ /right/ ) {
            $rightAlign{$idx} = 1;
        }
        $idx++;
    }
    my $fpos = getFilePosition( $pagerFileIdx,    $pageNo );
    my $rfh  = newReadFileHandle( $pagerFileRows, "printOnePage" );
    seek( $rfh, $fpos, 0 );
    my $count     = 0;
    my $dscoreIdx = $nAttrSpecs - 2;
    while ( my $s = $rfh->getline() ) {
        my (@vals) = split( /\t/, $s );
        my $nVals = @vals;
        $count++;
        if ( $count > $funcsPerPage ) {
            last;
        }
        print "<tr class='img'>\n";
        for ( my $i = 0 ; $i < $nAttrSpecs ; $i++ ) {
            my $right = $rightAlign{$i};
            my $alignSpec;
            $alignSpec = "align='right'" if $right;
            my $val = $vals[ $i * 2 ];
            my $val_display = $vals[ ( $i * 2 ) + 1 ];
            my $colorSpec;
            my $color;
            $color = getAbsColor($val) if $i >= 4;
            $colorSpec = "bgcolor='$color'" if $color ne "";

            if (   $i == 3
                && $clusterMatchText ne ""
                && $val_display =~ /$clusterMatchText/i )
            {

                # ken function name matching
                print "<td class='img'> "
                  . "<font color='red'>$val_display</font></td>\n";
            } else {
                print
                  "<td class='img' $colorSpec $alignSpec>$val_display</td>\n";
            }
        }
        print "</tr>\n";
    }
    close $rfh;
    print "</table>\n";
    printFuncCartFooter();
    my $url = "$section_cgi&page=queryForm";
    print buttonUrl( $url, "Start Over", "medbutton" );
    print "\n";
    print end_form();
    print "\n";

    WebUtil::printMainFormName("3");
    printPageHeader( $function, $xcopy, $normalization, $pageNo,
        $clusterMatchText, "3" );
    print "\n";
    print end_form();
    print "\n";

}

############################################################################
# loadMetaData - Load metadata about the pager.
############################################################################
sub loadMetaData {
    my ($inFile) = @_;

    my %meta;
    my $rfh = newReadFileHandle( $inFile, "loadMetaData" );
    my $inAttrs = 0;
    my @attrSpecs;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        if ( $s =~ /^\.attrNameStart/ ) {
            $inAttrs = 1;
        } elsif ( $s =~ /^\.attrNameEnd/ ) {
            $meta{attrSpecs} = \@attrSpecs;
            $inAttrs = 0;
        } elsif ($inAttrs) {
            push( @attrSpecs, $s );
        } elsif ( $s =~ /^\./ ) {
            my ( $tag, @toks ) = split( / /, $s );
            $tag =~ s/^\.//;
            my $val = join( ' ', @toks );
            $meta{$tag} = $val;
        }
    }
    close $rfh;
    return %meta;
}

############################################################################
# printPageHeader - Print header with all the pages.
############################################################################
sub printPageHeader {
    my ( $function, $xcopy, $normalization, $currPageNo, $clusterMatchText,
        $formNum )
      = @_;


    my $display = param("display");

    if ( $clusterMatchText ne "" ) {
        my $cluster = param("cluster");

        print hiddenVar( "section",       "AbundanceToolkit" );
        print hiddenVar( "page",          "abundancePager" );
        print hiddenVar( "function",      "$function" );
        print hiddenVar( "xcopy",         "$xcopy" );
        print hiddenVar( "normalization", "$normalization" );
        print hiddenVar( "pageNo",           "1" );
        print hiddenVar( "display",          "$display" );
        print hiddenVar( "clusterMatchText", "$clusterMatchText" );
        print hiddenVar( "cluster",          "$cluster" );
        print hiddenVar( "_section_AbundanceToolkit_abundancePager", "_section_AbundanceToolkit_abundancePager");
    }

    my $filePagerRoot = getPagerFileRoot( $function, $xcopy, $normalization );
    my $idxFile       = "$filePagerRoot.idx";
    my $rfh           = newReadFileHandle( $idxFile, "printPageHeader" );
    print "<p>\n";
    print "Pages:";
    my $lastPageNo = 1;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $pageNo, $fpos ) = split( / /, $s );
        print nbsp(1);
        if ( $pageNo eq $currPageNo ) {
            print "[";
        }

        # javascript form?
        if ( $clusterMatchText ne "" ) {
            print "<a href=\"javascript:mySubmit" . $formNum
              . "($pageNo)\"> $pageNo </a>";

        } else {
            my $url = "$section_cgi&page=abundancePager";
            $url .= "&function=$function";
            $url .= "&xcopy=$xcopy";
            $url .= "&normalization=$normalization";
            $url .= "&pageNo=$pageNo";
            if($display ne "") {
                $url .= "&display=$display";
            }
            print alink( $url, $pageNo );
        }
        if ( $pageNo eq $currPageNo ) {
            print "]";
        }
        $lastPageNo = $pageNo;
    }
    if ( $currPageNo < $lastPageNo ) {
        print nbsp(1);
        my $nextPageNo = $currPageNo + 1;
        if ( $clusterMatchText ne "" ) {
            print "["
              . "<a href=\"javascript:mySubmit"
              . $formNum
              . "($nextPageNo)\"> Next Page </a>" . "]";

        } else {
            my $url = "$section_cgi&page=abundancePager";
            $url .= "&function=$function";
            $url .= "&xcopy=$xcopy";
            $url .= "&normalization=$normalization";
            $url .= "&pageNo=$nextPageNo";
            if($display ne "") {
                $url .= "&display=$display";
            }
            print "[" . alink( $url, "Next Page" ) . "]";
        }
    }
    close $rfh;
    print "<br/>\n";
    my $url = "$section_cgi&page=abundanceDownload";
    $url .= "&function=$function";
    $url .= "&xcopy=$xcopy";
    $url .= "&normalization=$normalization";
    $url .= "&noHeader=1";
    my $contact_oid = WebUtil::getContactOid();
    print alink( $url, "Download tab-delimited file for Excel", '', '', '', "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link abundanceDownload']);" );
    print "</p>\n";
}

############################################################################
# getFilePosition - Get file positino given page no.
############################################################################
sub getFilePosition {
    my ( $idxFile, $currPageNo ) = @_;

    my $rfh = newReadFileHandle( $idxFile, "getFilePosition" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $pageNo, $fpos ) = split( / /, $s );
        if ( $pageNo eq $currPageNo ) {
            close $rfh;
            return $fpos;
        }
    }
    close $rfh;
    return 0;
}

############################################################################
# getProfileVectors
############################################################################
sub getProfileVectors {
    my ( $dbh, $type, $taxonOids_ref, $func, $xcopy, $estNormalization,
        $taxonProfiles_ref, $data_type, $notScaffortCart )
      = @_;

    my $start_time = time();
    my $last_id    = "";

    if ( !$notScaffortCart ) {
        printStartWorkingDiv();
    }

    ## get MER-FS taxons
    my %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile( $dbh, @$taxonOids_ref );

    for my $taxon_oid (@$taxonOids_ref) {
        print "Finding $type $func profile for <i>$taxon_oid</i> ...<br/>\n";
        if ( $mer_fs_taxons{$taxon_oid} ) {

            if ( $xcopy eq 'gene_count' ) {
                print "Computing $taxon_oid $data_type $func gene count ...<br/>\n";
                my %profile = MetaUtil::getTaxonFuncCount( $taxon_oid, $data_type, $func );
                $taxonProfiles_ref->{$taxon_oid} = \%profile;
            }
            else {
                print "Computing $taxon_oid $data_type $func est copy ...<br/>\n";
                my ($profile_href, $last_id1) = getMetaTaxonFuncEstCopies(
                    $dbh, $taxon_oid, $func, $data_type, $last_id, $start_time );
                $taxonProfiles_ref->{$taxon_oid} = $profile_href;
                $last_id = $last_id1;
            }

        }
        else {

            # DB
            my ( $cur, $scaffold_oids_str ) = getFuncProfileCur( $dbh, $xcopy, $func, $taxon_oid );

            my %profile;
            for ( ; ; ) {
                my ( $id, $cnt ) = $cur->fetchrow();
                last if !$id;
                $profile{$id} = $cnt;
            }
            $taxonProfiles_ref->{$taxon_oid} = \%profile;
            $cur->finish();
        }
    }

    # TODO scaffold cart - 1000 limit
    if ($scaffold_cart && !$notScaffortCart) {
        my @scaffold_cart_names = param("scaffold_cart_name");
        foreach my $sname (@scaffold_cart_names) {
            my $virtual_taxon_oid =
              ScaffoldCart::getVirtualTaxonIdForName($sname);
            print "Finding profile for scaffold cart $virtual_taxon_oid <i>"
              . escHtml($sname);
            print "</i> ...<br/>\n";

            my ( $cur, $scaffold_oids_str ) = getFuncProfileCur( $dbh, $xcopy, $func, '', $sname );

            my %profile;
            for ( ; ; ) {
                my ( $id, $cnt ) = $cur->fetchrow();
                last if !$id;
                $profile{$id} = $cnt;
            }
            $cur->finish();
            OracleUtil::truncTable( $dbh, "gtt_num_id" )
                if ( $scaffold_oids_str =~ /gtt_num_id/i );

            $taxonProfiles_ref->{$virtual_taxon_oid} = \%profile;
        }
    }

    if ( !$notScaffortCart ) {
        printEndWorkingDiv();
    }

    if ($last_id) {
        print
"<p><font color='red'>It takes too long to compute $type -- stop at $last_id.</font>\n";
    }
}

############################################################################
# getMetaTaxonFuncEstCopies
############################################################################
sub getMetaTaxonFuncEstCopies {
    my ( $dbh, $taxon_oid, $func, $data_type, $last_id, $start_time )
      = @_;

    # $xcopy eq 'est_copy'

    my %profile;

    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {

        if ( $t2 eq 'unassembled' ) {
            # get count for unassembled if any
            print "Computing $taxon_oid $t2 $func est copy through gene count ...<br/>\n";
            my %funcs =
              MetaUtil::getTaxonFuncCount( $taxon_oid, 'unassembled', $func );
            for my $k ( keys %funcs ) {
                if ( $profile{$k} ) {
                    $profile{$k} += $funcs{$k};
                }
                else {
                    $profile{$k} = $funcs{$k};
                }
            }
        }
        else {

            # now assembled
            # check whether there is cog_copy.txt
            my $copy_fname;
            if ( $func eq "cog" ) {
                $copy_fname = "cog_copy.txt";
            }
            elsif ( $func eq "enzyme" ) {
                $copy_fname = "ec_copy.txt";
            }
            elsif ( $func eq "ko" ) {
                $copy_fname = "ko_copy.txt";
            }
            elsif ( $func eq "pfam" ) {
                $copy_fname = "pafm_copy.txt";
            }
            elsif ( $func eq "tigrfam" ) {
                $copy_fname = "tigr_copy.txt";
            }

            my $cnt_file_name =
              $mer_data_dir . "/" . $taxon_oid . "/$t2/$copy_fname";
            if ( -e $cnt_file_name ) {
                print "Computing $taxon_oid $t2 $func est copy through $copy_fname ...<br/>\n";

                my %funcs = MetaUtil::getTaxonFuncCopy( $taxon_oid, $t2, $func );
                for my $k ( keys %funcs ) {
                    if ( $profile{$k} ) {
                        $profile{$k} += $funcs{$k};
                    }
                    else {
                        $profile{$k} = $funcs{$k};
                    }
                }

            }
            else {

                print "Retrieving gene estimated copies data ...<br/>\n";
                my %gene_copies;
                MetaUtil::getTaxonGeneEstCopy( $taxon_oid, 'assembled',
                    \%gene_copies );

                #get all assembled func genes first
                my %genes_h =
                  MetaUtil::getTaxonFuncsGenes( $taxon_oid, "assembled", $func );

                if ( scalar( keys %genes_h ) > 0 ) {
                    print "Computing $taxon_oid $t2 $func est copy through the results of getTaxonFuncsGenes() ...<br/>\n";

                    for my $id ( sort ( keys %genes_h ) ) {
                        my @gene_list = split( /\t/, $genes_h{$id} );
                        for my $gene_oid (@gene_list) {
                            my $gene_copy = 1;
                            if ( $gene_copies{$gene_oid} ) {
                                $gene_copy = $gene_copies{$gene_oid};
                            }
                            if ( $profile{$id} ) {
                                $profile{$id} += $gene_copy;
                            }
                            else {
                                $profile{$id} = $gene_copy;
                            }
                        }

                        if ( $start_time ne ''
                            && (( $merfs_timeout_mins * 60 ) - ( time() - $start_time )) < 100 )
                        {
                            $last_id = "$taxon_oid $id";
                            last;
                        }
                    }    # end for id

                    if ( tied(%genes_h) ) {
                        untie(%genes_h);
                    }

                }
                else {

                    # use getTaxonFuncGeneEstCopy()
                    print "Computing $taxon_oid $t2 $func est copy through the use of getTaxonFuncGeneEstCopy() ...<br/>\n";

                    my @ids = QueryUtil::getAllFuncList($dbh, $func);
                    #print "getMetaTaxonFuncEstCopies() ids: @ids<br/>\n";
                    for my $id (@ids) {
                        my $cnt =
                          MetaUtil::getTaxonFuncGeneEstCopy( $taxon_oid, 'assembled', $id,
                            \%gene_copies );
                        $profile{$id} = $cnt;

                        if ( $start_time ne ''
                            && (( $merfs_timeout_mins * 60 ) - ( time() - $start_time )) < 100 )
                        {
                            $last_id = "$taxon_oid $id";
                            last;
                        }
                    }
                }

                if ( tied(%gene_copies) ) {
                    untie(%gene_copies);
                }

            }
        }
    }

    return (\%profile, $last_id);
}


############################################################################
# genomeNormalizeProfileVectors - Normalize value by genome size.
############################################################################
sub genomeNormalizeProfileVectors {
    my ( $dbh, $taxonProfiles_ref, $type ) = @_;

    print "Normalizing profiles by genome size ...<br/>\n";
    my @taxon_oids = keys(%$taxonProfiles_ref);
    for my $taxon_oid (@taxon_oids) {
        my $profile_ref = $taxonProfiles_ref->{$taxon_oid};
        genomeNormalizeTaxonProfile( $dbh, $taxon_oid, $profile_ref );
    }
}

############################################################################
# genomeNormalizeTaxonProfile - Normalize profile for one taxon.
############################################################################
sub genomeNormalizeTaxonProfile {
    my ( $dbh, $taxon_oid, $profile_ref ) = @_;

    my $sql = qq{
       select sum( g.est_copy )
       from gene g
       where g.taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($total_gene_count) = $cur->fetchrow();
    $cur->finish();
    if ( $total_gene_count == 0 ) {
        webLog("genomeNormalizeTaxonProfile: WARNING: total_gene_count=0\n");
        warn("genomeNormalizeTaxonProfile: WARNING: total_gene_count=0\n");
        return;
    }
    my @keys = sort( keys(%$profile_ref) );
    for my $k (@keys) {
        my $cnt = $profile_ref->{$k};
        my $v   = ( $cnt / $total_gene_count ) * 1000;
        $profile_ref->{$k} = $v;
    }
}

############################################################################
# pooledNormalizeProfileVectors - Normalize value by group size.
############################################################################
sub pooledNormalizeProfileVectors {
    my ( $dbh, $taxonProfiles_ref, $type ) = @_;

    print "Normalizing profiles by pooled size ...<br/>\n";
    my @taxon_oids = keys(%$taxonProfiles_ref);
    my ($pooled_gene_count) = getCumGeneCount( $dbh, \@taxon_oids );
    for my $taxon_oid (@taxon_oids) {
        my $profile_ref = $taxonProfiles_ref->{$taxon_oid};
        pooledNormalizeTaxonProfile( $dbh, $taxon_oid, $profile_ref,
            $pooled_gene_count );
    }
}

############################################################################
# pooledNormalizeTaxonProfile - Normalize profile for group size.
############################################################################
sub pooledNormalizeTaxonProfile {
    my ( $dbh, $taxon_oid, $profile_ref, $pooled_gene_count ) = @_;

    my @keys = sort( keys(%$profile_ref) );
    for my $k (@keys) {
        my $cnt = $profile_ref->{$k};
        my $v   = ( $cnt / $pooled_gene_count ) * 1000;
        $profile_ref->{$k} = $v;
    }
}

############################################################################
# getCumGeneCount - Get cumulative gene count
############################################################################
sub getCumGeneCount {
    my ( $dbh, $taxon_oid, $taxonOids_ref ) = @_;

    my $taxon_oid_str = join( ',', @$taxonOids_ref );
    if ( blankStr($taxon_oid_str) ) {
        warn("getCumGeneCount: no genes found for '$taxon_oid_str'\n");
        return 0;
    }
    my $sql = qq{
        select sum( g.est_copy )
    	from gene g
    	where g.taxon in( $taxon_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($pooled_gene_count) = $cur->fetchrow();
    $cur->finish();
    return $pooled_gene_count;
}

############################################################################
# printGeneList  - User clicked on link to select genes for
#    funcId / taxon_oid.
############################################################################
sub printGeneList {
    my $funcId    = param("funcId");
    my $func_type = param("function");
    my $taxon_oid = param("taxon_oid");
    my $est_copy  = param("est");

    printMainForm();
    print "<h1>Abundance Profile Overview Genes</h1>\n";

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    printAbundanceGeneListSubHeader( $dbh, $func_type, $funcId, $taxon_oid );

    my $sql;
    my @binds;
    if ($scaffold_cart && $taxon_oid < 0) {
        my $sname = ScaffoldCart::getCartNameForTaxonOid($taxon_oid);
        my $scaffold_oids_aref = ScaffoldCart::getScaffoldByCartName($sname);
        my $str = join(",",@$scaffold_oids_aref);
        $sql = FuncCartStor::getDtGeneFuncQuery2($funcId, $str);
	    @binds = ( $taxon_oid, $funcId);
    }
    else {
        require FuncCartStor;
        $sql = FuncCartStor::getDtGeneFuncQuery1($funcId);
        @binds = ( $taxon_oid, $funcId);
    }

    printDbGeneList( $dbh, $sql, \@binds, $est_copy );

}

sub printDbGeneList {
    my ( $dbh, $sql, $binds_ref, $est_copy ) = @_;

    my $cur = execSql( $dbh, $sql, $verbose, @$binds_ref );

    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();
    my $nGenes = scalar( @gene_oids );

    require InnerTable;
    my $it = new InnerTable( 1, "AbundanceFuncGenes$$", "AbundanceFuncGenes", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "number asc", "right" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );

    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it, '', 1 );

    printGeneCartFooter() if $nGenes > 10;
    print "<p>\n";
    $it->printOuterTable(1);
    print "</p>\n";
    printGeneCartFooter();

    if ( $nGenes > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace('gene_oid');
    }

    my $stLineText;
    if ($est_copy) {
        $stLineText = "$nGenes/$est_copy genes/copies retrieved.";
    }
    else {
        $stLineText = "$nGenes gene(s) retrieved.";
    }
    printStatusLine( $stLineText, 2 );

}

sub printMetaGeneList {
    my ( $funcId, $taxon_oid, $data_type, $est_copy ) = @_;

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );
    print hiddenVar( "func_id",   $funcId );

    my %genes     = MetaUtil::getTaxonFuncGenes( $taxon_oid, $data_type, $funcId );
    my @gene_oids = ( keys %genes );
    my $nGenes = @gene_oids;

    if ( $nGenes > 1000 ) {
        print "<p><font color='red'>Too many genes -- gene product names are not displayed.</font><br/>\n";
    }

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    my $trunc = 0;

    require InnerTable;
    my $it = new InnerTable( 1, "AbundanceGenes$$", "AbundanceGenes", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "number asc", "right" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );

    my $select_id_name = "gene_oid";

    my $gene_count = 0;
    for my $key (@gene_oids) {
        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }

        my $workspace_id = $genes{$key};
        my ( $tid, $dt, $id2 ) = split( / /, $workspace_id );

        # checkbox
        my $row = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
        $row .=
            $workspace_id . $sd
          . "<a href='main.cgi?section=MetaGeneDetail"
          . "&page=metaGeneDetail&taxon_oid=$tid"
          . "&data_type=$dt&gene_oid=$key'>$key</a></td>\t";

        my ( $value, $source );
        if ( $nGenes > 1000 ) {
            $value = "-";
        } else {
            ( $value, $source ) = MetaUtil::getGeneProdNameSource( $key, $tid, $dt );
        }
        $row .= $value . $sd . $value . "\t";

        $it->addRow($row);
        $gene_count++;
    }

    WebUtil::printGeneCartFooter() if ( $gene_count > 10 );
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $gene_count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" )
            . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        my $stLineText;
        if ($est_copy) {
            $stLineText = "$gene_count/$est_copy genes/copies retrieved.";
        }
        else {
            $stLineText = "$gene_count gene(s) retrieved.";
        }
        printStatusLine( $stLineText, 2 );
    }

}


############################################################################
# printAbundanceDownload - Downloads abundance data to Excel.
############################################################################
sub printAbundanceDownload {
    my $function = param("function");

    # merged form - ken
    my $display = param("display");
    if ( $display eq "matrix" ) {
        $function = param("cluster");
        if($function eq "") {
            $function = param("function");
        }
    }

    my $xcopy         = param("xcopy");
    my $normalization = param("normalization");

    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );
    my $path = "$pagerFileRoot.xls";
    if ( !( -e $path ) ) {
        webErrorHeader(
            "Session of download has expired. " . "Please start again." );
    }
    my $sz = fileSize($path);

    print "Content-type: application/vnd.ms-excel\n";
    my $filename = "abundance_${function}_$$.tab.xls";
    print "Content-Disposition: inline; filename=$filename\n";
    print "Content-length: $sz\n";
    print "\n";
    my $rfh = newReadFileHandle( $path, "printAbundanceDownload" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "$s\n";
    }
    close $rfh;
}

############################################################################
# getAbsColor - Get color for absolute values.
############################################################################
sub getAbsColor {
    my ($val) = @_;

    return "white" if !isNumber($val);

    $val = abs($val);
    if ( $val >= 1 && $val <= 5 ) {
        return "bisque";
    } elsif ( $val > 5 && $val <= 10 ) {
        return "pink";
    } elsif ( $val > 10 ) {
        return "yellow";
    } else {
        return "white";
    }
}

############################################################################
# getAbsColorLegend - Get legend string.
############################################################################
sub getAbsColorLegend {
    my $s;
    $s .= "Counts for cell coloring: ";
    $s .= "white < 1,
          <span style='background-color:bisque'>bisque</span> = 1-5,
          <span style='background-color:pink'>pink</span> = 6-10,
          <span style='background-color:yellow'>yellow</span> > 10.";
    return $s;
}

############################################################################
# getRelColor - Get color for relative values.
############################################################################
sub getRelColor {
    my ($val) = @_;

    return "white" if !isNumber($val);

    $val = abs($val);
    if ( $val >= 0.5 && $val <= 1 ) {
        return "bisque";
    } elsif ( $val > 1 ) {
        return "yellow";
    } else {
        return "white";
    }
}

############################################################################
# getRelColorLegend - Get legend string.
############################################################################
sub getRelColorLegend {
    my $s;
    $s .= "Frequency magnitudes (positive or negative) for cell coloring: ";
    $s .= "white < 0.50, bisque = 0.50-1.00, yellow > 1.00.";
    return $s;
}

############################################################################
# getDScoreColor - Get color for absolute values.
############################################################################
sub getDScoreColor {
    my ($val) = @_;

    return "white" if !isNumber($val);

    $val = abs($val);
    if ( $val >= 1.00 && $val <= 1.96 ) {
        return "bisque";
    } elsif ( $val > 1.96 && $val <= 2.33 ) {
        return "pink";
    } elsif ( $val > 2.33 ) {
        return "yellow";
    } else {
        return "white";
    }
}

############################################################################
# getDScoreColorLegend - Get legend string.
############################################################################
sub getDScoreColorLegend {
    my $s;
    $s .= "D-score (positive or negative) for cell coloring: ";
    $s .= "white < 1.00, bisque = 1.00-1.96, pink = 1.96-2.33, yellow > 2.33.";
    return $s;
}

############################################################################
# getDScores - Get Daniel's binomial assumption d-score.
#
# Input:
#    @param q_ref - query profiles
#    @param r_ref - reference profiles
#    @param flags_ref - Flag insufficiently large values for test.
# Output:
#    @param qfreq_ref - Query frequency values (hash)
#    @param rfreq_ref - Reference frequency values (hash)
#    @param dscores_ref - Output hash of function to d-score
#    @param pvalues_ref - Output hash of function to p-value
#
############################################################################
sub getDScores {
    my ( $q_ref, $r_ref, $qfreq_ref, $rfreq_ref, $dscores_ref, $flags_ref ) =
      @_;

    ## n1
    my @keys   = sort( keys(%$q_ref) );
    my $nKeys1 = @keys;
    my $n1     = 0;
    for my $k (@keys) {
        my $cnt = $q_ref->{$k};
        $n1 += $cnt;
    }

    ## n2
    my @keys   = sort( keys(%$r_ref) );
    my $nKeys2 = @keys;
    my $n2     = 0;
    for my $k (@keys) {
        my $cnt = $r_ref->{$k};
        $n2 += $cnt;
    }
    if ( $nKeys1 != $nKeys2 ) {
        webDie("getDScores: nKeys1=$nKeys1 nKeys2=$nKeys2 do not match\n");
    }
    if ( $n1 < 1 || $n2 < 1 ) {
        webLog("getDScores: n1=$n1 n2=$n2: no hits to calculate\n");
        return ( $n1, $n2 );
    }
    webLog("getDScores: n1=$n1 n2=$n2\n");

    my @keys       = sort( keys(%$q_ref) );
    my $undersized = 0;
    for my $id (@keys) {
        my $x1 = $q_ref->{$id};
        my $x2 = $r_ref->{$id};
        my $p1 = $x1 / $n1;
        my $p2 = $x2 / $n2;
        $qfreq_ref->{$id} = $p1;
        $rfreq_ref->{$id} = $p2;
        my $p   = ( $x1 + $x2 ) / ( $n1 + $n2 );
        my $q   = 1 - $p;
        my $num = $p1 - $p2;
        my $den = sqrt( $p * $q * ( ( 1 / $n1 ) + ( 1 / $n2 ) ) );
        my $d   = 0;
        $d = ( $num / $den ) if $den > 0;
        $dscores_ref->{$id} = $d;

        if ( $x1 + $x2 < 10 ) {
            $flags_ref->{$id} = "undersized";

            #webLog( "$id: x1=$x1 x2=$x2 undersized\n" );
            $undersized++;
        }
    }
    webLog("$undersized / $nKeys2 undersized\n");
    return ( $n1, $n2 );
}

############################################################################
# getPvalues - Get pvalues given z (or d-score in this case).
#
#  Input:
#    @param dscores_ref - Hash of d-scores
#    @param flags_ref - Flag of undersized values.
#  Output:
#    @param pvalues_ref - Hash of p-values.
############################################################################
sub getPvalues {
    my ( $dscores_ref, $flags_ref, $pvalues_ref ) = @_;

    my $tmpDscoreFile = "$cgi_tmp_dir/dscores$$.txt";
    my $tmpRcmdFile   = "$cgi_tmp_dir/rcmd$$.r";
    my $tmpRoutFile   = "$cgi_tmp_dir/rout$$.txt";
    my $wfh           = newWriteFileHandle( $tmpDscoreFile, "getPvalues" );
    my @keys          = sort( keys(%$dscores_ref) );
    my $nKeys         = @keys;
    for my $k (@keys) {
        my $v = $dscores_ref->{$k};
        print $wfh "$v\n";
    }
    close $wfh;

    my $wfh = newWriteFileHandle( $tmpRcmdFile, "getPvalues" );
    print $wfh "t1 <- read.table( '$tmpDscoreFile', sep='\\t', header=F )\n";
    print $wfh "v1 <- 1 - pnorm( abs( t1\$V1 ) )\n";
    print $wfh "write.table( v1, file='$tmpRoutFile', ";
    print $wfh "row.names=F, col.names=F )\n";
    close $wfh;

    WebUtil::unsetEnvPath();
    webLog("Running R pnorm( )\n");
    my $env = "PATH='/bin:/usr/bin'; export PATH";
    my $cmd = "$env; $r_bin --slave < $tmpRcmdFile > /dev/null";
    webLog("+ $cmd\n");
    my $st = system($cmd );
    WebUtil::resetEnvPath();

    my $rfh = newReadFileHandle( $tmpRoutFile, "getPvalues" );
    my @pvalues;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my $pvalue = $s;
        push( @pvalues, $pvalue );
    }
    close $rfh;
    my $nPvalues = @pvalues;
    if ( $nPvalues != $nKeys ) {
        webDie("getPvalues: nPvalues=$nPvalues nKeys=$nKeys");
    }

    my $idx = 0;
    for my $id (@keys) {
        my $pvalue = $pvalues[$idx];
        my $flag   = $flags_ref->{$id};
        $pvalues_ref->{$id} = $pvalue;
        $idx++;
    }
}

############################################################################
# printDScoreNote - Print note about D-score calculation.
############################################################################
sub printDScoreNote {
    print "<h1>D-score</h1>\n";
    print "<p>\n";
    print qq{
       D-score uses a binomial distribution
       whereby the "difference" measurement is approximately normally
       distributed with mean 0 and unit variance, <i>N(0,1)</i>.<br/>
       <br/>
       <b>Data:</b><br/>
       <br/>
       <i>x1</i> = count of a given function in query group.<br/>
       <i>x2</i> = count of a given function
           in reference group.<br/>
       <i>n1</i> = total counts of all function occurrences in query group.<br/>
       <i>n2</i> = total counts of all function occurrences
          in reference group.<br/>
       <br/>
       <b>Computations:</b><br/>
       <br/>
       <i>f1</i> = <i>x1/n1</i> = frequency of functional occurrence
          in query group.<br/>
       <i>f2</i> = <i>x2/n2</i> = frequency of functional occurrence
          in reference group.<br/>
       <i>p = (x1 + x2) / (n1 + n2)</i> = probability of occurrence.<br/>
       <i>q = 1 - p</i> = probability of non-occurrence.<br/>
       <i>d_score = ( f1 - f2 ) / sqrt( p*q * ( 1/n1 + 1/n2 ) )</i><br/>
       <br/>
       <i>pnorm()</i> - probability distribution function for <i>N(0,1)</i><br/>
       <i>p_value = 1.00 - pnorm( d_score )</i><br/>
       <br/>
       <b>Qualifications:</b><br/>
       <br/>
       <i>p_value</i> is masked out with '-'
       to indicate<br/>insufficient data for the test,
       as specified by <i>x1 + x2 < 10</i>.<br/>
    };
    print "</p>\n";
}

############################################################################
# getFuncDict - Get func_id -> func_name dictionary mapping.
############################################################################
sub getFuncDict {
    my ($dbh, $func_type) = @_;

    #print "getFuncDict(): func type '$func_type'<br/>\n";
    if ( $func_type eq "cog" ) {
        return QueryUtil::getAllCogNames($dbh);
    } elsif ( $func_type eq "enzyme" ) {
        return QueryUtil::getAllEnzymeNames($dbh);
    } elsif ( $func_type eq "ko" ) {
        return QueryUtil::getAllKoNames($dbh);
    } elsif ( $func_type eq "pfam" ) {
        return QueryUtil::getAllPfamNames($dbh);
    } elsif ( $func_type eq "tigrfam" ) {
        return QueryUtil::getAllTigrfamNames($dbh);
    } else {
        webLog("getFuncDict(): unknown func type '$func_type'\n");
        WebUtil::webExit(-1);
    }
}

############################################################################
# getFuncProfileCur - Get function profile cur for a taxon.
############################################################################
sub getFuncProfileCur {
    my ( $dbh, $xcopy, $func_type, $taxon_oid, $scaffold_cart_name ) = @_;

    my $scaffold_oids_str;
    if ( $scaffold_cart_name && $taxon_oid < 0 ) {
        my $scaffold_oids_aref = ScaffoldCart::getScaffoldByCartName($scaffold_cart_name);
        $scaffold_oids_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffold_oids_aref );
    }

    my $aggFunc;
    if ( $xcopy eq "est_copy" ) {
        $aggFunc = "sum( g.est_copy )";
    }
    else {
        $aggFunc = "count( distinct g.gene_oid )";
    }

    my $sql;

    if ( $func_type eq "cog" ) {
        if ( $scaffold_cart_name && !$taxon_oid ) {
            my $sql = qq{
                select gcg.cog, $aggFunc
                from gene_cog_groups gcg, gene g
                where gcg.gene_oid = g.gene_oid
                and g.scaffold in ($scaffold_oids_str)
                and g.locus_type = ?
                and g.obsolete_flag = ?
                group by gcg.cog
            };
        }
        else {
            $sql = qq{
                select gcg.cog, $aggFunc
                from gene_cog_groups gcg, gene g
                where gcg.gene_oid = g.gene_oid
                and g.taxon = ?
                and g.locus_type = ?
                and g.obsolete_flag = ?
                group by gcg.cog
            };
        }

    } elsif ( $func_type eq "enzyme" ) {
        if ( $scaffold_cart_name && !$taxon_oid ) {
            $sql = qq{
                select ge.enzymes, $aggFunc
                from gene_ko_enzymes ge, gene g
                where ge.gene_oid = g.gene_oid
                and g.scaffold in ($scaffold_oids_str)
                and g.locus_type = ?
                and g.obsolete_flag = ?
                group by ge.enzymes
            };
        }
        else {
            $sql = qq{
                select ge.enzymes, $aggFunc
                from gene_ko_enzymes ge, gene g
                where ge.gene_oid = g.gene_oid
                and g.taxon = ?
                and g.locus_type = ?
                and g.obsolete_flag = ?
                group by ge.enzymes
            };
        }

    } elsif ( $func_type eq "ko" ) {
        if ( $scaffold_cart_name && !$taxon_oid ) {
            $sql = qq{
                select gk.ko_terms, $aggFunc
                from gene_ko_terms gk, gene g
                where gk.gene_oid = g.gene_oid
                and g.scaffold in ($scaffold_oids_str)
                and g.locus_type = ?
                and g.obsolete_flag = ?
                group by gk.ko_terms
            };
        }
        else {
            $sql = qq{
                select gk.ko_terms, $aggFunc
                from gene_ko_terms gk, gene g
                where gk.gene_oid = g.gene_oid
                and g.taxon = ?
                and g.locus_type = ?
                and g.obsolete_flag = ?
                group by gk.ko_terms
            };
        }

    } elsif ( $func_type eq "pfam" ) {
        if ( $scaffold_cart_name && !$taxon_oid ) {
            $sql = qq{
                select gpf.pfam_family, $aggFunc
                from gene_pfam_families gpf, gene g
                where gpf.gene_oid = g.gene_oid
                and g.scaffold in ($scaffold_oids_str)
                and g.locus_type = ?
                and g.obsolete_flag = ?
                group by gpf.pfam_family
            };
        }
        else {
             $sql = qq{
                select gpf.pfam_family, $aggFunc
                from gene_pfam_families gpf, gene g
                where gpf.gene_oid = g.gene_oid
                and g.taxon = ?
                and g.locus_type = ?
                and g.obsolete_flag = ?
                group by gpf.pfam_family
            };
        }

    } elsif ( $func_type eq "tigrfam" ) {
        if ( $scaffold_cart_name && !$taxon_oid ) {
            $sql = qq{
                select gtf.ext_accession, $aggFunc
                from gene_tigrfams gtf, gene g
                where gtf.gene_oid = g.gene_oid
                and g.scaffold in ($scaffold_oids_str)
                and g.locus_type = ?
                and g.obsolete_flag = ?
                group by gtf.ext_accession
            };
        }
        else {
            $sql = qq{
                select gtf.ext_accession, $aggFunc
                from gene_tigrfams gtf, gene g
                where gtf.gene_oid = g.gene_oid
                and g.taxon = ?
                and g.locus_type = ?
                and g.obsolete_flag = ?
                group by gtf.ext_accession
            };
        }
    }
    #print "getFuncProfileCur() sql: $sql<br/>\n";

    my $cur;
    if ( $scaffold_cart_name && !$taxon_oid ) {
        $cur = execSql( $dbh, $sql, $verbose, 'CDS', 'No' );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, 'CDS', 'No' );
    }

    return ( $cur, $scaffold_oids_str );

}

############################################################################
# getFuncHeader - Get func_id -> func_header.
############################################################################
sub getFuncHeader {
    my ( $func_type ) = @_;

    my $funcHeader;
    if ( $func_type eq "cog" ) {
        $funcHeader = 'COG';
    } elsif ( $func_type eq "enzyme" ) {
        $funcHeader = 'Enzyme';
    } elsif ( $func_type eq "ko" ) {
        $funcHeader = 'KO';
    } elsif ( $func_type eq "pfam" ) {
        $funcHeader = 'Pfam';
    } elsif ( $func_type eq "tigrfam" ) {
        $funcHeader = 'Tigrfam';
    }

    return $funcHeader;
}

############################################################################
# getFuncName - Get func_id -> func_name.
############################################################################
sub getFuncName {
    my ($dbh, $func_type, $func_id) = @_;

    my @ids = ($func_id);
    my %id2name_h;

    if ( $func_type eq "cog" ) {
        QueryUtil::fetchCogIdNameHash( $dbh, \%id2name_h, @ids);
    } elsif ( $func_type eq "enzyme" ) {
        QueryUtil::fetchEnzymeNumberNameHash( $dbh, \%id2name_h, @ids);
    } elsif ( $func_type eq "ko" ) {
        QueryUtil::fetchKoIdDefHash( $dbh, \%id2name_h, @ids);
    } elsif ( $func_type eq "pfam" ) {
        QueryUtil::fetchPfamIdNameHash( $dbh, \%id2name_h, @ids);
    } elsif ( $func_type eq "tigrfam" ) {
        QueryUtil::fetchTigrfamIdNameHash( $dbh, \%id2name_h, @ids);
    } else {
        webLog("getFuncName(): unknown func type '$func_type'\n");
        #WebUtil::webExit(-1);
    }

    my $func_name = $id2name_h{$func_id};

    return $func_name;
}

############################################################################
# printAbundanceGeneListSubHeader
############################################################################
sub printAbundanceGeneListSubHeader {
    my ( $dbh, $func_type, $func_id, $taxon_oid, $data_type) = @_;

    # make page
    my $func_header = getFuncHeader( $func_type );
    my $func_name = getFuncName($dbh, $func_type, $func_id);

    print "<p>\n";
    print "$func_header ID: $func_id\n";
    print "<br>$func_header Name: $func_name\n";
    print "</p>\n";

    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

    my $isTaxonInFile;
    if ( $in_file && isInt($taxon_oid) ) {
        $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
        if ( $isTaxonInFile ) {
            $taxon_name .= " (MER-FS)";
            if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                $taxon_name .= " ($data_type)";
            }
        }
    }

    print "<p>\n";
    print "Taxon ID: <a href='main.cgi?section=TaxonDetail"
      . "&page=taxonDetail&taxon_oid=$taxon_oid'>"
      . "$taxon_oid</a>\n";
    print "<br>Taxon Name: $taxon_name\n";
    print "</p>\n";

    return $isTaxonInFile;
}


1;
