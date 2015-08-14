############################################################################
# AbundanceTest.pm - Abundance test tool to compare hypotheses.
#        --es 05/19/2007
############################################################################
package AbundanceTest;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use WebConfig;
use WebUtil;
use OracleUtil;
use GenomeListFilter;
use HtmlUtil;

my $section = "AbundanceTest";
my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $inner_cgi = $env->{ inner_cgi };
my $verbose = $env->{ verbose };
my $base_url = $env->{base_url};
my $base_dir = $env->{ base_dir };
my $img_internal = $env->{ img_internal };
my $include_img_terms = $env->{ include_img_terms };
my $include_metagenomes = $env->{ include_metagenomes };
my $show_myimg_login = $env->{ show_myimg_login };
my $img_lite = $env->{ img_lite };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $top_n_abundances = 10000;  # make a very large number
my $max_query_taxons = 20;
my $max_reference_taxons = 200;
my $r_bin = $env->{ r_bin };

my $max_batch = 500;
my %function2IdType = (
   cog => "cog_id",
   pfam => "pfam_id",
   enzyme => "ec_number",
   tigrfam => "tigrfam_id",
);
my $fdr = 0.05;

############################################################################
# dispatch - Dispatch events.
############################################################################
sub dispatch {
    my $page = param( "page" );
    timeout( 60 * 20 );    # timeout in 20 minutes (from main.pl)

    if( paramMatch( "abundanceResults" ) ne "" ) {
       printAbundanceResults( );
    }
    elsif( $page eq "abundancePager" ) {
       printAbundancePager( );
    }
    elsif( $page eq "abundanceDownload" ) {
       printAbundanceDownload( );
    }
    elsif( $page eq "geneList" ) {
       printGeneList( );
    }
    elsif( $page eq "dscoreNote" ) {
       printDScoreNote( );
    }
    else {
       printQueryForm( );
    }
}

############################################################################
# printQueryForm - Show query form for abundances.
############################################################################
sub printQueryForm {

    print "<h1>Abundance Test Tool</h1>\n";
    print "<p>\n";
    print "The abundance test tool allows you customize<br/>";
    print "functional abundance measurements for hypothesis testing.<br/>\n";
    print "Query and reference genomes may be compared.<br/>\n";
    print "Results may be exported to Excel.<br/>\n";
    print "</p>\n";

    printMainForm( );
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";
    printOptionLabel( "Page Options" );
    print nbsp( 2 );
    print popup_menu( -name => "funcsPerPage",
       -values => [ 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 ],
       -default => 500 );
    print nbsp( 1 );
    print "functions per page.\n";
    print "<br/>\n";
    print "<br/>\n";

    printOptionLabel( "Genome");
    print "</p>\n";

    my $dbh = dbLogin();
    GenomeListFilter::appendGenomeListFilter($dbh, 'Yes', 0, 'genomesToSelect');
    ####$dbh->disconnect();

    print qq{
        <script type='text/javascript' src='$base_url/abundanceShare.js'>
        </script>
        <input type='button' class='tobutton' id='toQueryG' name='toQueryG' />
        <input type='hidden' name='queryGenomes' />
        <font color='blue'>Query Genome: </font><font color='red'><span id='queryG'>0 selected.</span></font><br/>
        <input type='button' class='tobutton' id='toReferenceG' name='toReferenceG' />
        <input type='hidden' name='referenceGenomes' />
        <font color='blue'>Reference Genome: </font><font color='red'><span id='referenceG'>0 selected.</span></font><br/>
    };
    print "<br/>\n";

    print "<p>\n";
    printOptionLabel( "Function" );
    print "<input type='radio' name='function' value='cog' checked />\n";
    print "COG<br/>\n";
    print "<input type='radio' name='function' value='pfam' />\n";
    print "Pfam<br/>\n";
    print "<input type='radio' name='function' value='enzyme' />\n";
    print "Enzyme<br/>\n";
    print "<input type='radio' name='function' value='tigrfam' />\n";
    print "TIGRfam<br/>\n";
    print "<br/>\n";

    printOptionLabel( "Measurement" );
    print "<input type='radio' name='xcopy' value='gene_count' checked />\n";
    print "Gene count<br/>\n";
    print "<input type='radio' name='xcopy' value='est_copy' />\n";
    print "Estimated gene copies<sup>1</sup><br/>\n";
    print "<br/>\n";

    # --es 07/18/2007
    printOptionLabel( "Output" );
    print "<input type='checkbox' name='allRows' value='1' />\n";
    print "Include all rows, including those without hits.\n";
    print "<br/>\n";

    my $name = "_section_${section}_abundanceResults";
    print submit( -name => $name, -value => "Go", -class => "smdefbutton" );
    print nbsp( 1 );
    print reset( -id => "reset", -class => "smbutton" );
    print "<br/>\n";
    print "</p>\n";

    print "<p>\n";
    print "<b>Notes:</b><br/>\n";
    print "1 - Estimated by multiplying by read depth when available.<br/>\n";
    #print "2 - Normalized by dividing by the number of genes ";
    #print "for each genome.<br/>\n";
    #print "3 - Normalized by dividing by pooled number of genes ";
    #print "in query and reference groups.<br/>\n";
    print "</p>\n";
    printStatusLine( "Loaded.", 2 );
    print end_form( );
}

############################################################################
# printOptionLabel
############################################################################
sub printOptionLabel {
   my( $s, $footnote ) = @_;
   print "<b>";
   print "<font color='blue'>";
   print "$s";
   print "</font>";
   print "</b>";
   if( $footnote ne "" ) {
      print "<sup>$footnote</sup>\n";
   }
   print ":<br/>\n";
   print "<br/>\n";
}

############################################################################
# printAbundanceResults - Show results from query form.
############################################################################
sub printAbundanceResults {
   my @queryGenomes = OracleUtil::processTaxonSelectionSingleParam( "queryGenomes" );
   my @referenceGenomes = OracleUtil::processTaxonSelectionSingleParam( "referenceGenomes" );
   my $function = param( "function" );
   my $xcopy = param( "xcopy" );
   my $normalization = param( "normalization" );
   my $funcsPerPage = param( "funcsPerPage" );

   print "<h1>Abundance Test Tool</h1>\n";

   my $nQueryGenomes = @queryGenomes;
   #print "\$nQueryGenomes: $nQueryGenomes<br/>\n";
   if( $nQueryGenomes == 0 || ($nQueryGenomes == 1 && $queryGenomes[0] eq '') ) {
       webError( "Please select one query genome.<br/>\n" );
   }
   my $nReferenceGenomes = @referenceGenomes;
   #print "\$nReferenceGenomes: $nReferenceGenomes<br/>\n";
   if( $nReferenceGenomes == 0 || ($nReferenceGenomes == 1 && $referenceGenomes[0] eq '') ) {
       webError( "Please select one reference genome.<br/>\n" );
   }

   printMainForm( );
   printStatusLine( "Loading ...", 1 );
   print "<p>\n";
   #print "Set $funcsPerPage functions per page ...<br/>\n";

   my $dbh = dbLogin( );

   my %funcId2Name;

   my %queryTaxonProfiles;
   getProfileVectors( $dbh, "query", \@queryGenomes, $function, $xcopy,
      \%queryTaxonProfiles, \%funcId2Name );

   my %referenceTaxonProfiles;
   getProfileVectors( $dbh, "reference", \@referenceGenomes, $function, $xcopy,
      \%referenceTaxonProfiles, \%funcId2Name );

   my $queryProfile_ref = $queryTaxonProfiles{ query };
   my $referenceProfile_ref = $referenceTaxonProfiles{ reference };
   my %qfreq;
   my %rfreq;
   my %dscores;
   my %flags;
   my( $n1, $n2 ) = getDScores( $queryProfile_ref, $referenceProfile_ref,
      \%qfreq, \%rfreq, \%dscores, \%flags );
   delete $queryTaxonProfiles{ query };
   delete $referenceTaxonProfiles{ reference };

   print "Get p-values for d-scores ...<br/>\n";
   my %pvalues;
   getPvalues( \%dscores, \%flags, \%pvalues );

   my $pvalue_cutoff = getPvalueCutoff( \%pvalues );
   setCutoffFlag( $pvalue_cutoff, \%pvalues, \%flags );
   my $pc = sprintf( "%.2e", $pvalue_cutoff );
   print "False discovery rate p-value cutoff $pc<br/>\n";

   if( $normalization eq "genomeSize" ) {
      genomeNormalizeProfileVectors( $dbh, \%queryTaxonProfiles, "query" );
      genomeNormalizeProfileVectors( $dbh,
         \%referenceTaxonProfiles, "reference" );
   }
   elsif( $normalization eq "pooledGenes" ) {
      pooledNormalizeProfileVectors( $dbh, \%queryTaxonProfiles, "query" );
      pooledNormalizeProfileVectors( $dbh,
         \%referenceTaxonProfiles, "reference" );
   }

   my $pagerFileRoot = getPagerFileRoot(  $function, $xcopy, $normalization );
   webLog( "pagerFileRoot $pagerFileRoot'\n" );
   my $nFuncs = writePagerFiles( $dbh, $pagerFileRoot,
       \%funcId2Name, \%queryTaxonProfiles, \%referenceTaxonProfiles,
           \%qfreq, \%rfreq, $n1, $n2, \%dscores, \%pvalues, \%flags );
   print "</p>\n";

   #$dbh->disconnect( );

   printOnePage( 1 );
   #my $nFuncs = keys( %funcId2Name );
   printStatusLine( "$nFuncs functions loaded.", 2 );
   print end_form( );
}


############################################################################
# writePagerFiles - Write files for pager.
#   It writes to a file with 2 data columns for each
#   cell value.  One is for sorting.  The other is for display.
#   (Usually, they are the same, but sometimes not.)
############################################################################
sub writePagerFiles {
   my( $dbh, $pagerFileRoot, $funcId2Name_ref,
       $queryTaxonProfiles_ref, $referenceTaxonProfiles_ref,
       $qfreq_ref, $rfreq_ref, $n1, $n2,
       $dscores_ref, $pvalues_ref, $flags_ref ) = @_;

   my $funcsPerPage = param( "funcsPerPage" );
    $funcsPerPage = 500 if ($funcsPerPage == 0);

   my $function = param( "function" );
   my $normalization = param( "normalization" );
   my $allRows = param( "allRows" );
   my $idType = $function2IdType{ $function };
   my $doGenomeNormalization = 0;
   $doGenomeNormalization = 1 if $normalization eq "genomeSize";

   my $metaFile = "$pagerFileRoot.meta";  # metadata
   my $rowsFile = "$pagerFileRoot.rows";  # tab delimted rows for pager
   my $idxFile  = "$pagerFileRoot.idx";   # index file
   my $xlsFile  = "$pagerFileRoot.xls";   # Excel export file

   my $Fmeta = newWriteFileHandle( $metaFile, "writePagerFiles" );
   my $Frows = newWriteFileHandle( $rowsFile, "writePagerFiles" );
   my $Fxls = newWriteFileHandle( $xlsFile, "writePagerFiles" );

   my @taxon_oids = keys( %$queryTaxonProfiles_ref );

   my @query_taxon_oids = sortByTaxonName( $dbh, \@taxon_oids );

   my @taxon_oids = keys( %$referenceTaxonProfiles_ref );
   my @reference_taxon_oids = sortByTaxonName( $dbh, \@taxon_oids );

   my @funcIds = sort( keys( %$funcId2Name_ref ) );
   my $nFuncs = @funcIds;
   my $nPages  = int( $nFuncs / $funcsPerPage ) + 1;

   my %queryFuncsSum;
   my %referenceFuncsSum;
   for my $funcId( @funcIds ) {
      $queryFuncsSum{ $funcId } = 0;
      $referenceFuncsSum{ $funcId } = 0;
   }

   ## Get sums for query and reference
   for my $funcId( @funcIds ) {
      my $funcName = $funcId2Name_ref->{ $funcId };
      for my $taxon_oid( @query_taxon_oids ) {
         my $profile_ref = $queryTaxonProfiles_ref->{ $taxon_oid };
	 if( !defined( $profile_ref ) ) {
	    warn( "writePagerFiles: cannot find q.profile for $taxon_oid\n" );
	    next;
	 }
	 my $cnt = $profile_ref->{ $funcId };
	 $cnt = 0 if $cnt eq "";
	 $queryFuncsSum{ $funcId } += $cnt;
      }
      for my $taxon_oid( @reference_taxon_oids ) {
         my $profile_ref = $referenceTaxonProfiles_ref->{ $taxon_oid };
	 if( !defined( $profile_ref ) ) {
	    warn( "writePagerFiles: cannot find r.profile for $taxon_oid\n" );
	    next;
	 }
	 my $cnt = $profile_ref->{ $funcId };
	 $cnt = 0 if $cnt eq "";
	 $referenceFuncsSum{ $funcId } += $cnt;
      }
   }

   ## Output rows data

   ## Metadata for pager
   print $Fmeta ".funcsPerPage $funcsPerPage\n";
   print $Fmeta ".nPages $nPages\n";
   print $Fmeta ".n1 $n1\n";
   print $Fmeta ".n2 $n2\n";
   print $Fmeta ".attrNameStart\n";

   ## Column header for pager
   my $colIdx = 0;
   print $Fmeta "$colIdx :  Select\n"; $colIdx++;
   print $Fmeta "$colIdx :  Row<br/>No. : AN: right\n"; $colIdx++;
   print $Fmeta "$colIdx :  ID : AS : left\n"; $colIdx++;
   print $Fmeta "$colIdx :  Name : AS : left\n"; $colIdx++;
   for my $taxon_oid( @query_taxon_oids ) {
       my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
       my $abbrName = WebUtil::abbrColName( $taxon_oid, $name, 1 );
       print $Fmeta "$colIdx : $abbrName<br/>(Q) : " .
          "DN : right : $name ($taxon_oid)\n"; $colIdx++;
   }
   for my $taxon_oid( @reference_taxon_oids ) {
       my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
       my $abbrName = WebUtil::abbrColName( $taxon_oid, $name, 1 );
       print $Fmeta "$colIdx : $abbrName<br/>(R) : " .
           "DN : right : $name ($taxon_oid)\n"; $colIdx++;
   }
   my $op = "Freq";
   print $Fmeta "$colIdx :  (Q)ry<br/>$op : DN : right\n"; $colIdx++;
   print $Fmeta "$colIdx :  (R)ef<br/>$op : DN : right\n"; $colIdx++;
   print $Fmeta "$colIdx :  D-score<sup>1</sup> : DN : right\n"; $colIdx++;
   print $Fmeta "$colIdx :  P-value : AN : left\n"; $colIdx++;
   print $Fmeta "$colIdx :  Valid<br/>Test : AS : left\n"; $colIdx++;
   print $Fmeta ".attrNameEnd\n";

   ## Excel export header
   print $Fxls "Func_id\t";
   print $Fxls "Func_name\t";
   for my $taxon_oid( @query_taxon_oids ) {
       my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
       $name = excelHeaderName( $name );
       #print $Fxls "Qry_${taxon_oid}\t";
       print $Fxls "$name\t";
   }
   for my $taxon_oid( @reference_taxon_oids ) {
       my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
       $name = excelHeaderName( $name );
       #print $Fxls "Ref_${taxon_oid}\t";
       print $Fxls "$name\t";
   }
   my $op = "Freq";
   print $Fxls "Query_${op}\t";
   print $Fxls "Ref_${op}\t";
   print $Fxls "D-score\t";
   print $Fxls "P-value\t";
   print $Fxls "Valid-Test\n";

   my $count = 0;
   for my $funcId( @funcIds ) {
      ## --es 07/18/2007
      my $allZeros = 1;
      for my $taxon_oid( @reference_taxon_oids ) {
         my $profile_ref = $referenceTaxonProfiles_ref->{ $taxon_oid };
	 if( !defined( $profile_ref ) ) {
	    warn( "writePagerFiles: cannot find r.profile for $taxon_oid\n" );
	    next;
	 }
	 my $cnt = $profile_ref->{ $funcId };
	 $allZeros = 0 if $cnt > 0;
      }
      next if $allZeros && !$allRows;
      $count++;

      my $funcName = $funcId2Name_ref->{ $funcId };
      my $r;
      my $xls;

      # select
      $r .= "\t";
      $r .= "<input type='checkbox' name='$idType' value='$funcId' />\t";

      # row number
      $r .= "$count\t";
      $r .= "$count\t";

      # function id
      $r .= "$funcId\t";
      $r .= "$funcId\t";
      $xls .= "$funcId\t";

      # function name
      $r .= "$funcName\t";
      $r .= "$funcName\t";
      $xls .= "$funcName\t";
      for my $taxon_oid( @query_taxon_oids ) {
	 next if !isInt( $taxon_oid );
         my $profile_ref = $queryTaxonProfiles_ref->{ $taxon_oid };
	 if( !defined( $profile_ref ) ) {
	    warn( "writePagerFiles: cannot find q.profile for $taxon_oid\n" );
	    next;
	 }
	 my $cnt = $profile_ref->{ $funcId };
	 $cnt = 0 if $cnt eq "";
	 $cnt = sprintf( "%.2f", $cnt ) if $doGenomeNormalization;
	 $r .= "$cnt\t";
	 my $url = "$section_cgi&page=geneList";
	 $url .= "&funcId=$funcId&taxon_oid=$taxon_oid";
	 my $link = alink( $url, $cnt );
	 $link = 0 if $cnt == 0;
	 $r .= "$link\t";
	 $xls .= "$cnt\t";
      }
      for my $taxon_oid( @reference_taxon_oids ) {
	 next if !isInt( $taxon_oid );
         my $profile_ref = $referenceTaxonProfiles_ref->{ $taxon_oid };
	 if( !defined( $profile_ref ) ) {
	    warn( "writePagerFiles: cannot find r.profile for $taxon_oid\n" );
	    next;
	 }
	 my $cnt = $profile_ref->{ $funcId };
	 $cnt = 0 if $cnt eq "";
	 $cnt = sprintf( "%.2f", $cnt ) if $doGenomeNormalization;
	 $r .= "$cnt\t";
	 my $url = "$section_cgi&page=geneList";
	 $url .= "&funcId=$funcId&taxon_oid=$taxon_oid";
	 my $link = alink( $url, $cnt );
	 $link = 0 if $cnt == 0;
	 $r .= "$link\t";
	 $xls .= "$cnt\t";
      }

      # query frequency
      my $f = $qfreq_ref->{ $funcId };
      $f = sprintf( "%.5f", $f );
      $r .= "$f\t";
      $r .= "$f\t";
      $xls .= "$f\t";

      # reference frequency
      my $f = $rfreq_ref->{ $funcId };
      $f = sprintf( "%.5f", $f );
      $r .= "$f\t";
      $r .= "$f\t";
      $xls .= "$f\t";

      # difference
      #$cnt = $q_cnt - $r_cnt;
      #$cnt = sprintf( "%.2f", $cnt ) if $doGenomeNormalization;
      #$r .= "$cnt\t";
      #$r .= "$cnt\t";
      #$xls .= "$cnt\t";

      # d-score
      my $dscore = $dscores_ref->{ $funcId };
      $dscore = sprintf( "%.2f", $dscore );
      $r .= "$dscore\t";
      $r .= "$dscore\t";
      $xls .= "$dscore\t";

      # p-value
      my $pvalue = $pvalues_ref->{ $funcId };
      $pvalue = sprintf( "%.2e", $pvalue );
      my $pvalue2 = $pvalue;
      $pvalue2 = "$pvalue";
      $r .= "$pvalue\t";
      $r .= "$pvalue2\t";
      $xls .= "$pvalue2\t";

      # valid-test
      my $flag_val =  $flags_ref->{ $funcId };
      my $valid = "Yes";
      $valid = "No" if $flag_val eq "undersized";
      $valid = "No" if $flag_val eq "fdr_cutoff";
      $r .= "$valid\t";
      $r .= "$valid\t";
      $xls .= "$valid\t";

      chop $r;
      chop $xls;
      print $Frows "$r\n";
      print $Fxls "$xls\n";
   }
   webLog( "$count $function rows written\n" );

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
    my( $inFile, $outFile, $funcsPerPage, $nPages ) = @_;

    my $rfh = newReadFileHandle( $inFile, "indexRows" );
    my $wfh = newWriteFileHandle( $outFile, "indexRows" );
    my $count = 0;
    my $fpos = tell( $rfh );
    my $pageNo = 1;
    print $wfh "$pageNo $fpos\n";
    while( my $s = $rfh->getline( ) ) {
        chomp $s;
	$count++;
	if( $count > $funcsPerPage ) {
	   $pageNo++;
	   print $wfh "$pageNo $fpos\n";
	   $count = 1;
	}
	$fpos = tell( $rfh );
    }
    close $rfh;
    close $wfh;
}

############################################################################
# printAbundancePager - Show pages in pager.
############################################################################
sub printAbundancePager {
   my $pageNo = param( "pageNo" );
   my $colIdx = param( "colIdx" );
   my $function = param( "function" );
   my $xcopy = param( "xcopy" );
   my $normalization = param( "normalization" );
   my $funcsPerPage = param( "funcsPerPage" );
   my $sortType =  param( "sortType" );

   print "<h1>Abundance Test Tool</h1>\n";
   printMainForm( );
   printStatusLine( "Loading ...", 1 );
   if( $sortType ne "" ) {
      sortAbundanceFile( $function, $xcopy, $normalization,
          $sortType, $colIdx, $funcsPerPage );
      $pageNo = 1;
   }
   printOnePage( $pageNo );
   printStatusLine( "Loaded.", 2 );
   print end_form( );
}

############################################################################
# sortAbundanceFile - Resort abundance file.
############################################################################
sub sortAbundanceFile {
   my( $function, $xcopy, $normalization,
       $sortType, $colIdx, $funcsPerPage ) = @_;

   #print "<p>\n";
   #print "Resorting ...<br/>\n";
   #print "</p>\n";
   webLog( "resorting sortType='$sortType' colIdx='$colIdx'\n" );
   my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );
   my $pagerFileRows = "$pagerFileRoot.rows";
   my $pagerFileIdx = "$pagerFileRoot.idx";
    if ( !(-e $pagerFileRows) || !(-e $pagerFileIdx)) {
        webLog("Expired session file '$pagerFileRows' or '$pagerFileIdx'\n");
        webError("Session file expired.<br/>Please start your 'Function Comparison' study from the beginning.\n");
    }

   my $rfh = newReadFileHandle( $pagerFileRows, "sortAbudanceFile" );
   my @recs;
   my $rowIdx = 0;
   my @sortRecs;
   while( my $s = $rfh->getline( ) ) {
      chomp $s;
      push( @recs, $s );
      my( @vals ) = split( /\t/, $s );
      my $idx = $colIdx * 2;
      my $sortVal = $vals[ $idx ];
      my $sortRec = "$sortVal\t";
      $sortRec .= "$rowIdx";
      push( @sortRecs, $sortRec );
      $rowIdx++;
   }
   close $rfh;
   my @sortRecs2;
   if( $sortType =~ /N/ ) {
      if( $sortType =~ /D/ ) {
         @sortRecs2 = reverse( sort{ $a <=> $b  }( @sortRecs ) );
      }
      else {
         @sortRecs2 = sort{ $a <=> $b  }( @sortRecs );
      }
   }
   else {
      if( $sortType =~ /D/ ) {
         @sortRecs2 = reverse( sort( @sortRecs ) );
      }
      else {
         @sortRecs2 = sort( @sortRecs );
      }
   }
   my $wfh = newWriteFileHandle( $pagerFileRows, "sortAbundanceFile" );
   for my $r2( @sortRecs2 ) {
      my( $sortVal, $rowIdx ) = split( /\t/, $r2 );
      my $r = $recs[ $rowIdx ];
      print $wfh "$r\n";
   }
   close $wfh;
   indexRows( $pagerFileRows, $pagerFileIdx, $funcsPerPage );
}

############################################################################
# getPagerFileRoot - Convention for getting the pager file.
############################################################################
sub getPagerFileRoot {
   my( $function, $xcopy, $normalization ) = @_;
   my $sessionId = getSessionId( );
   my $tmpPagerFile = "$cgi_tmp_dir/abundanceTest.$function" .
      ".$xcopy.$normalization.$sessionId";
}

############################################################################
# printOnePage - Print one page for pager.
############################################################################
sub printOnePage {
   my( $pageNo ) = @_;
   my $colIdx = param( "colIdx" );
   my $function = param( "function" );
   my $xcopy = param( "xcopy" );
   my $normalization = param( "normalization" );
   my $funcsPerPage = param( "funcsPerPage" );
   my $doGenomeNormalization = 0;
   $doGenomeNormalization = 1 if $normalization eq "genomeSize";
   $pageNo = param( "pageNo" )  if $pageNo eq "";
   $pageNo = 1 if $pageNo eq "";

   my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );
   my $pagerFileIdx = "$pagerFileRoot.idx";
   my $pagerFileRows = "$pagerFileRoot.rows";
   my $pagerFileMeta = "$pagerFileRoot.meta";
   my $pagerFileXls = "$pagerFileRoot.xls";
   if( !-e( $pagerFileIdx ) ) {
       warn( "$pagerFileIdx not found\n" );
       webError( "Session expired for this page.  Please start again." );
   }
   if( !-e( $pagerFileRows ) ) {
       warn( "$pagerFileRows not found\n" );
       webError( "Session expired for this page.  Please start again." );
   }
   if( !-e( $pagerFileMeta ) ) {
       warn( "$pagerFileMeta not found\n" );
       webError( "Session expired for this page.  Please start again." );
   }
   if( !-e( $pagerFileXls ) ) {
       warn( "$pagerFileXls not found\n" );
       webError( "Session expired for this page.  Please start again." );
   }

   my %metaData = loadMetaData( $pagerFileMeta );
   my $funcsPerPage = $metaData{ funcsPerPage };
   my $attrSpecs_ref = $metaData{ attrSpecs };
   my $n1 = $metaData{ n1 };
   my $n2 = $metaData{ n2 };
   my $nAttrSpecs = @$attrSpecs_ref;
   my $nAttrSpecs2 = $nAttrSpecs * 2;

   printMainForm( );
   my $colorLegend = getDScoreColorLegend( );
   $colorLegend = getRelColorLegend( ) if $doGenomeNormalization;
   printHint(
      "- Click on column name to sort.<br/>" .
      "- Mouse over genome abbreviation to see genome name " .
      "and taxon object identifier.<br/>" .
      "- Click on number to see constituent genes.<br/>" .
      "- Codes: (Q)uery, (R)eference.<br/>" .
      "- $colorLegend.<br/>"
   );
   printPageHeader( $function, $xcopy, $normalization, $pageNo );

   printFuncCartFooter( );
   my %rightAlign;
   my $idx = 0;
   print "<table class='img' border='1'>\n";
   for my $attrSpec( @$attrSpecs_ref ) {
      my( $colIdx, $attrName, $sortType, $align,
          $mouseover ) = split( /:/, $attrSpec );
      $colIdx =~ s/\s//g;
      $attrName =~ s/^\s+//;
      $attrName =~ s/\s+$//;
      $mouseover =~ s/^\s+//;
      $mouseover =~ s/\s+$//;
      $sortType =~ s/\s+//g;
      if( $sortType eq "" ) {
         print "<th class='img'>$attrName</th>\n";
      }
      else {
	 my $url = "$section_cgi&page=abundancePager";
	 $url .= "&sortType=$sortType";
	 $url .= "&function=$function";
	 $url .= "&xcopy=$xcopy";
	 $url .= "&normalization=$normalization";
	 $url .= "&colIdx=$colIdx";
	 $url .= "&pageNo=1";
	 $url .= "&funcsPerPage=$funcsPerPage";
	 my $x;
	 $x = "title='$mouseover'" if $mouseover ne "";
	 my $link = "<a href='$url' $x>$attrName</a>";
         print "<th class='img'>$link</th>\n";
      }
      if( $align =~ /right/ ) {
         $rightAlign{ $idx } = 1;
      }
      $idx++;
   }
   my $fpos = getFilePosition( $pagerFileIdx, $pageNo );
   my $rfh = newReadFileHandle( $pagerFileRows, "printOnePage" );
   seek( $rfh, $fpos, 0 );
   my $count = 0;
   my $dscoreIdx = $nAttrSpecs - 3;
   my $validTestIdx = $nAttrSpecs - 1;
   while( my $s = $rfh->getline( ) ) {
      my( @vals ) = split( /\t/, $s );
      my $nVals = @vals;
      my $validTest = $vals[ 2*$validTestIdx ];
      $count++;
      if( $count > $funcsPerPage ) {
         last;
      }
      print "<tr class='img'>\n";
      for( my $i = 0; $i < $nAttrSpecs; $i++ ) {
         my $right = $rightAlign{ $i };
	 my $alignSpec;
	 $alignSpec = "align='right'" if $right;
	 my $val = $vals[ $i*2 ];
	 my $val_display = $vals[ ($i*2)+1 ];
	 my $colorSpec;
	 my $color;
	 $color = getDScoreColor( $val )
	    if $i == $dscoreIdx && $validTest eq "Yes";
	 $colorSpec = "bgcolor='$color'" if $color ne "";
	 print "<td class='img' $colorSpec $alignSpec>$val_display</td>\n";
      }
      print "</tr>\n";
   }
   close $rfh;
   print "</table>\n";
   print "<p>\n";
   print "Total query hits (n1): $n1<br/>\n";
   print "Total reference hits (n2): $n2<br/>\n";
   print "</p>\n";
   printFuncCartFooter( );
   printPageHeader( $function, $xcopy, $normalization, $pageNo );
   my $url = "$section_cgi&page=queryForm";
   print buttonUrl( $url, "Start Over", "medbutton" );
   print "<p>\n";
   print "<b>Notes:</b><br/>\n";
   my $url = "$section_cgi&page=dscoreNote";
   my $link = alink( $url, "D-score" );
   print "1 - $link calculation for query and reference ";
   print "group differences.<br/>\n";
   print "</p>\n";
   print end_form( );

}

############################################################################
# loadMetaData - Load metadata about the pager.
############################################################################
sub loadMetaData {
   my( $inFile ) = @_;

   my %meta;
   my $rfh = newReadFileHandle( $inFile, "loadMetaData" );
   my $inAttrs = 0;
   my @attrSpecs;
   while( my $s = $rfh->getline( ) ) {
      chomp $s;
      if( $s =~ /^\.attrNameStart/ ) {
         $inAttrs = 1;
      }
      elsif( $s =~ /^\.attrNameEnd/ ) {
	 $meta{ attrSpecs } = \@attrSpecs;
         $inAttrs = 0;
      }
      elsif( $inAttrs ) {
         push( @attrSpecs, $s );
      }
      elsif( $s =~ /^\./ ) {
         my( $tag, @toks ) = split( / /, $s );
	 $tag =~ s/^\.//;
	 my $val = join( ' ', @toks );
	 $meta{ $tag } =  $val;
      }
   }
   close $rfh;
   return %meta;
}


############################################################################
# printPageHeader - Print header with all the pages.
############################################################################
sub printPageHeader {
   my( $function, $xcopy, $normalization, $currPageNo ) = @_;

   my $filePagerRoot = getPagerFileRoot( $function, $xcopy, $normalization );
   my $idxFile = "$filePagerRoot.idx";
   my $rfh = newReadFileHandle( $idxFile, "printPageHeader" );
   print "<p>\n";
   print "Pages:";
   my $lastPageNo = 1;
   while( my $s = $rfh->getline( ) ) {
       chomp $s;
       my( $pageNo, $fpos ) = split( / /, $s );
       print nbsp( 1 );
       if( $pageNo eq $currPageNo ) {
           print "[";
       }
       my $url = "$section_cgi&page=abundancePager";
       $url .= "&function=$function";
       $url .= "&xcopy=$xcopy";
       $url .= "&normalization=$normalization";
       $url .= "&pageNo=$pageNo";
       print alink( $url, $pageNo );
       if( $pageNo eq $currPageNo ) {
           print "]";
       }
       $lastPageNo = $pageNo;
   }
   if( $currPageNo < $lastPageNo ) {
       print nbsp( 1 );
       my $nextPageNo = $currPageNo + 1;
       my $url = "$section_cgi&page=abundancePager";
       $url .= "&function=$function";
       $url .= "&xcopy=$xcopy";
       $url .= "&normalization=$normalization";
       $url .= "&pageNo=$nextPageNo";
       print "[" . alink( $url, "Next Page" ) . "]";
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
   my( $idxFile, $currPageNo ) = @_;

   my $rfh = newReadFileHandle( $idxFile, "getFilePosition" );
   while( my $s = $rfh->getline( ) ) {
       chomp $s;
       my( $pageNo, $fpos ) = split( / /, $s );
       if( $pageNo eq $currPageNo ) {
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
   my( $dbh, $type, $taxonOids_ref, $func,
       $xcopy, $taxonProfiles_ref, $funcId2Name_ref ) = @_;

   if( $func eq "cog" ) {
      getCogVectors( $dbh, $type, $taxonOids_ref,
         $xcopy, $taxonProfiles_ref, $funcId2Name_ref );
   }
   elsif( $func eq "pfam" ) {
      getPfamVectors( $dbh, $type, $taxonOids_ref,
         $xcopy, $taxonProfiles_ref, $funcId2Name_ref );
   }
   elsif( $func eq "enzyme" ) {
      getEnzymeVectors( $dbh, $type, $taxonOids_ref,
         $xcopy, $taxonProfiles_ref, $funcId2Name_ref );
   }
   elsif( $func eq "tigrfam" ) {
      getTigrfamVectors( $dbh, $type, $taxonOids_ref,
         $xcopy, $taxonProfiles_ref, $funcId2Name_ref );
   }
}

############################################################################
# getCogVectors - Get profile vectors for COG.
############################################################################
sub getCogVectors {
    my( $dbh, $type, $taxonOids_ref,
        $xcopy, $taxonProfiles_ref, $funcId2Name_ref ) = @_;

    ## Template
    my $sql = qq{
       select c.cog_id, c.cog_name
       from cog c
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id, $name ) = $cur->fetchrow( );
       last if !$id;
       $tpl{ $id } = 0;
       $funcId2Name_ref->{ $id } = $name;
    }
    $cur->finish( );

    my %typeProfile = %tpl;
    $taxonProfiles_ref->{ $type } = \%typeProfile;

    my $aggFunc = "count( distinct g.gene_oid )";
    $aggFunc = "sum( g.est_copy )" if $xcopy eq "est_copy";
    for my $taxon_oid( @$taxonOids_ref ) {
        my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 0 );
	print "Find $type profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";
	my $sql = qq{
	    select gcg.cog, $aggFunc
	    from gene g, gene_cog_groups gcg
	    where g.gene_oid = gcg.gene_oid
	    and g.taxon = ?
	    group by gcg.cog
	};
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	my %profile = %tpl;
	for( ;; ) {
	    my( $id, $cnt ) = $cur->fetchrow( );
	    last if !$id;
	    $profile{ $id } = $cnt;
	    $typeProfile{ $id } += $cnt;
	}
	$cur->finish( );
	$taxonProfiles_ref->{ $taxon_oid } = \%profile;
    }
}

############################################################################
# getPfamVectors - Get profile vectors for Pfams.
############################################################################
sub getPfamVectors {
    my( $dbh, $type, $taxonOids_ref,
        $xcopy, $taxonProfiles_ref, $funcId2Name_ref ) = @_;

    ## Template
    my $sql = qq{
       select pf.ext_accession, pf.name
       from pfam_family pf
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id, $name ) = $cur->fetchrow( );
       last if !$id;
       $tpl{ $id } = 0;
       $funcId2Name_ref->{ $id } = $name;
    }
    $cur->finish( );

    my %typeProfile = %tpl;
    $taxonProfiles_ref->{ $type } = \%typeProfile;

    my $aggFunc = "count( distinct g.gene_oid )";
    $aggFunc = "sum( g.est_copy )" if $xcopy eq "est_copy";
    for my $taxon_oid( @$taxonOids_ref ) {
        my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 0 );
	print "Find $type profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";
	my $sql = qq{
	    select gpf.pfam_family, $aggFunc
	    from gene g, gene_pfam_families gpf
	    where g.gene_oid = gpf.gene_oid
	    and g.taxon = ?
	    group by gpf.pfam_family
	};
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid);
	my %profile = %tpl;
	for( ;; ) {
	    my( $id, $cnt ) = $cur->fetchrow( );
	    last if !$id;
	    $profile{ $id } = $cnt;
	    $typeProfile{ $id } += $cnt;
	}
	$cur->finish( );
	$taxonProfiles_ref->{ $taxon_oid } = \%profile;
    }
}

############################################################################
# getEnzymeVectors - Get profile vectors for enzymes.
############################################################################
sub getEnzymeVectors {
    my( $dbh, $type, $taxonOids_ref,
        $xcopy, $taxonProfiles_ref, $funcId2Name_ref ) = @_;

    ## Template
    my $sql = qq{
       select ez.ec_number, ez.enzyme_name
       from enzyme ez
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id, $name ) = $cur->fetchrow( );
       last if !$id;
       $tpl{ $id } = 0;
       $funcId2Name_ref->{ $id } = $name;
    }
    $cur->finish( );

    my %typeProfile = %tpl;
    $taxonProfiles_ref->{ $type } = \%typeProfile;

    my $aggFunc = "count( distinct g.gene_oid )";
    $aggFunc = "sum( g.est_copy )" if $xcopy eq "est_copy";
    for my $taxon_oid( @$taxonOids_ref ) {
        my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 0 );
	print "Find $type profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";
	my $sql = qq{
	    select ge.enzymes, $aggFunc
	    from gene g, gene_ko_enzymes ge
	    where g.gene_oid = ge.gene_oid
	    and g.taxon = ?
	    group by ge.enzymes
	};
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	my %profile = %tpl;
	for( ;; ) {
	    my( $id, $cnt ) = $cur->fetchrow( );
	    last if !$id;
	    $profile{ $id } = $cnt;
	    $typeProfile{ $id } += $cnt;
	}
	$cur->finish( );
	$taxonProfiles_ref->{ $taxon_oid } = \%profile;
    }
}

############################################################################
# getTigrfamVectors - Get profile vectors for TIGRfams.
############################################################################
sub getTigrfamVectors {
    my( $dbh, $type, $taxonOids_ref,
        $xcopy, $taxonProfiles_ref, $funcId2Name_ref ) = @_;

    ## Template
    my $sql = qq{
       select tf.ext_accession, tf.expanded_name
       from tigrfam tf
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id, $name ) = $cur->fetchrow( );
       last if !$id;
       $tpl{ $id } = 0;
       $funcId2Name_ref->{ $id } = $name;
    }
    $cur->finish( );

    my %typeProfile = %tpl;
    $taxonProfiles_ref->{ $type } = \%typeProfile;

    my $aggFunc = "count( distinct g.gene_oid )";
    $aggFunc = "sum( g.est_copy )" if $xcopy eq "est_copy";
    for my $taxon_oid( @$taxonOids_ref ) {
        my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 0 );
	print "Find $type profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";
	my $sql = qq{
	    select gtf.ext_accession, $aggFunc
	    from gene g, gene_tigrfams gtf
	    where g.gene_oid = gtf.gene_oid
	    and g.taxon = ?
	    group by gtf.ext_accession
	};
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	my %profile = %tpl;
	for( ;; ) {
	    my( $id, $cnt ) = $cur->fetchrow( );
	    last if !$id;
	    $profile{ $id } = $cnt;
	    $typeProfile{ $id } += $cnt;
	}
	$cur->finish( );
	$taxonProfiles_ref->{ $taxon_oid } = \%profile;
    }
}

############################################################################
# genomeNormalizeProfileVectors - Normalize value by genome size.
############################################################################
sub genomeNormalizeProfileVectors {
    my( $dbh, $taxonProfiles_ref, $type ) = @_;

    print "Normalizing $type profiles by genome size ...<br/>\n";
    my @taxon_oids = keys( %$taxonProfiles_ref );
    for my $taxon_oid( @taxon_oids ) {
        my $profile_ref = $taxonProfiles_ref->{ $taxon_oid };
	genomeNormalizeTaxonProfile( $dbh, $taxon_oid, $profile_ref );
    }
}

############################################################################
# genomeNormalizeTaxonProfile - Normalize profile for one taxon.
############################################################################
sub genomeNormalizeTaxonProfile {
    my( $dbh, $taxon_oid, $profile_ref ) = @_;

    my $sql = qq{
       select sum( g.est_copy )
       from gene g
       where g.taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid);
    my( $total_gene_count ) = $cur->fetchrow( );
    $cur->finish( );
    if( $total_gene_count == 0 ) {
       webLog( "genomeNormalizeTaxonProfile: WARNING: total_gene_count=0\n" );
       warn( "genomeNormalizeTaxonProfile: WARNING: total_gene_count=0\n" );
       return;
    }
    my @keys = sort( keys( %$profile_ref ) );
    for my $k( @keys ) {
       my $cnt = $profile_ref->{ $k };
       my $v = ( $cnt / $total_gene_count ) * 1000;
       $profile_ref->{ $k } = $v;
    }
}

############################################################################
# pooledNormalizeProfileVectors - Normalize value by group size.
############################################################################
sub pooledNormalizeProfileVectors {
    my( $dbh, $taxonProfiles_ref, $type ) = @_;

    print "Normalizing $type profiles by pooled size ...<br/>\n";
    my @taxon_oids = keys( %$taxonProfiles_ref );
    my( $pooled_gene_count ) = getCumGeneCount( $dbh, \@taxon_oids );
    for my $taxon_oid( @taxon_oids ) {
        my $profile_ref = $taxonProfiles_ref->{ $taxon_oid };
	pooledNormalizeTaxonProfile( $dbh, $taxon_oid,
	   $profile_ref, $pooled_gene_count );
    }
}

############################################################################
# pooledNormalizeTaxonProfile - Normalize profile for group size.
############################################################################
sub pooledNormalizeTaxonProfile {
    my( $dbh, $taxon_oid, $profile_ref, $pooled_gene_count ) = @_;

    my @keys = sort( keys( %$profile_ref ) );
    for my $k( @keys ) {
       my $cnt = $profile_ref->{ $k };
       my $v = ( $cnt / $pooled_gene_count ) * 1000;
       $profile_ref->{ $k } = $v;
    }
}

############################################################################
# getCumGeneCount - Get cumulative gene count
############################################################################
sub getCumGeneCount {
    my( $dbh, $taxon_oid, $taxonOids_ref ) = @_;

    my $taxon_oid_str = join( ',', @$taxonOids_ref );
    if( blankStr( $taxon_oid_str ) ) {
       warn( "getCumGeneCount: no genes found for '$taxon_oid_str'\n" );
       return 0;
    }
    my $sql = qq{
        select sum( g.est_copy )
	from gene g
	where g.taxon in( $taxon_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my( $pooled_gene_count ) = $cur->fetchrow( );
    $cur->finish( );
    return $pooled_gene_count;
}

############################################################################
# printGeneList  - User clicked on link to select genes for
#    funcId / taxon_oid.
############################################################################
sub printGeneList {
    my $funcId = param( "funcId" );
    my $taxon_oid = param( "taxon_oid" );

    my $dbh = dbLogin( );
    require FuncCartStor;
    my $sql = FuncCartStor::getDtGeneFuncQuery1($funcId);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $funcId );
    my @gene_oids;
    for( ;; ) {
       my( $gene_oid ) = $cur->fetchrow( );
       last if !$gene_oid;
       push( @gene_oids, $gene_oid );
    }
    $cur->finish( );
    my $nGenes = @gene_oids;
    #if( $nGenes == 1 ) {
    #   $dbh->disconnect( );
    #   require GeneDetail;
    #   GeneDetail::printGeneDetail( $gene_oids[ 0 ] );
    #   return;
    #}
    print "<h1>Abundance Test Tool Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );
    printMainForm( );

    printGeneCartFooter( );
    print "<p>\n";
    #HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );
    print "</p>\n";
    printGeneCartFooter( ) if $nGenes > 10;

    printStatusLine( "$nGenes gene(s) retrieved.", 2 );
    print end_form( );
}

############################################################################
# printAbundanceDownload - Downloads abundance data to Excel.
############################################################################
sub printAbundanceDownload {
    my $function = param( "function" );
    my $xcopy = param( "xcopy" );
    my $normalization = param( "normalization" );

    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );
    my $path = "$pagerFileRoot.xls";
    if( !( -e $path ) ) {
       webErrorHeader( "Session of download has expired. " .
         "Please start again." );
    }
    my $sz = fileSize( $path );
    #print "Content-type: text/plain\n";
    print "Content-type: application/vnd.ms-excel\n";
    my $filename = "abundance_${function}_$$.tab.xls";
    print "Content-Disposition: inline; filename=$filename\n";
    print "Content-length: $sz\n";
    print "\n";
    my $rfh = newReadFileHandle( $path, "printAbundanceDownload" );
    while( my $s = $rfh->getline( ) ) {
       chomp $s;
       print "$s\n";
    }
    close $rfh;
}

############################################################################
# getAbsColor - Get color for absolute values.
############################################################################
sub getAbsColor {
   my( $val ) = @_;

   return "white" if !isNumber( $val );

   $val = abs( $val );
   if( $val >= 1 &&  $val <= 5 ) {
      return "bisque";
   }
   elsif( $val >  5 ) {
      return "yellow";
   }
   else {
      return "white";
   }
}

############################################################################
# getAbsColorLegend - Get legend string.
############################################################################
sub getAbsColorLegend {
   my $s;
   $s .= "Absolute magnitudes (positive or negative) for cell coloring: ";
   $s .= "white < 1, bisque = 1-5, yellow > 5.";
   return $s;
}

############################################################################
# getRelColor - Get color for relative values.
############################################################################
sub getRelColor {
   my( $val ) = @_;

   return "white" if !isNumber( $val );

   $val = abs( $val );
   if( $val >= 0.5 &&  $val <= 1 ) {
      return "bisque";
   }
   elsif( $val > 1 ) {
      return "yellow";
   }
   else {
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
   my( $val ) = @_;

   return "white" if !isNumber( $val );

   $val = abs( $val );
   if( $val >= 1.00 &&  $val <= 1.96 ) {
      return "bisque";
   }
   elsif( $val > 1.96 &&  $val <= 2.33 ) {
      return "pink";
   }
   elsif( $val >  2.33 ) {
      return "yellow";
   }
   else {
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
#    @param q_ref - query profile
#    @param r_ref - reference profile
# Output:
#    @param qfreq_ref - Query frequency values (hash)
#    @param rfreq_ref - Reference frequency values (hash)
#    @param dscores_ref - Output hash of function to d-score
#    @param flags_ref - Output hash for flags with invalid test.
#
############################################################################
sub getDScores {
   my( $q_ref, $r_ref, $qfreq_ref, $rfreq_ref,
       $dscores_ref, $flags_ref ) = @_;

   ## n1
   my @keys = sort( keys( %$q_ref ) );
   my $nKeys1 = @keys;
   my $n1 = 0;
   for my $k( @keys ) {
      my $cnt = $q_ref->{ $k };
      $n1 += $cnt;
   }

   ## n2
   my @keys = sort( keys( %$r_ref ) );
   my $nKeys2 = @keys;
   my $n2 = 0;
   for my $k( @keys ) {
      my  $cnt = $r_ref->{ $k };
      $n2 += $cnt;
   }
   if( $nKeys1 != $nKeys2 ) {
       webDie( "getDScores: nKeys1=$nKeys1 nKeys2=$nKeys2 do not match\n" );
   }
   if( $n1 < 1 ||  $n2 < 1 ) {
       webLog( "getDScores: n1=$n1 n2=$n2: no hits to calculate\n" );
       for my $id( @keys ) {
          $qfreq_ref->{ $id } = 0;
          $rfreq_ref->{ $id } = 0;
          $dscores_ref->{ $id } = 0;
	  $flags_ref->{ $id } = "undersized";
       }
       return( $n1, $n2 );
   }
   webLog( "getDScores: n1=$n1 n2=$n2\n" );

   my @keys  = sort( keys( %$q_ref ) );
   my $undersized = 0;
   for my $id( @keys ) {
       my $x1 = $q_ref->{ $id };
       my $x2 = $r_ref->{ $id };
       my $p1 = $x1 / $n1;
       my $p2 = $x2 / $n2;
       $qfreq_ref->{ $id } = $p1;
       $rfreq_ref->{ $id } = $p2;
       my $p  = ( $x1 + $x2 ) / ( $n1 + $n2 );
       my $q  = 1 - $p;
       my $num = $p1 - $p2;
       my $den = sqrt( $p * $q * ( (1/$n1) + (1/$n2) ) );
       my $d   = 0;
       $d = ( $num / $den ) if $den > 0;
       $dscores_ref->{ $id } = $d;
       if( !isValidTest( $n1, $n2, $x1, $x2 ) ) {
           $flags_ref->{ $id } = "undersized";
	   $undersized++;
       }
   }
   webLog( "$undersized / $nKeys2 undersized\n" );
   return( $n1, $n2 );
}

############################################################################
# isValidTest - Heursitics to see if test is sufficent size to be valid.
############################################################################
sub isValidTest {
    my( $n1, $n2, $x1, $x2 ) = @_;

    return 1 if $x1 >= 5 && $x2 >= 5;
    return 1 if $x1 + $x2 >= 10 && $x1 > $x2 && $n2 >= $n1;
    return 1 if $x1 + $x2 >= 10 && $x2 > $x1 && $n1 >= $n2;
    return 0;
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
    my( $dscores_ref, $flags_ref, $pvalues_ref ) = @_;

    my $tmpDscoreFile = "$cgi_tmp_dir/dscores$$.txt";
    my $tmpRcmdFile = "$cgi_tmp_dir/rcmd$$.r";
    my $tmpRoutFile = "$cgi_tmp_dir/rout$$.txt";
    my $wfh = newWriteFileHandle( $tmpDscoreFile, "getPvalues" );
    my @keys = sort( keys( %$dscores_ref ) );
    my $nKeys = @keys;
    for my $k( @keys ) {
        my $v = $dscores_ref->{ $k };
	print $wfh "$v\n";
    }
    close $wfh;

    my $wfh = newWriteFileHandle( $tmpRcmdFile, "getPvalues" );
    print $wfh "t1 <- read.table( '$tmpDscoreFile', sep='\\t', header=F )\n";
    print $wfh "v1 <- 1 - pnorm( abs( t1\$V1 ) )\n";
    print $wfh "write.table( v1, file='$tmpRoutFile', ";
    print $wfh "row.names=F, col.names=F )\n";
    close $wfh;

    WebUtil::unsetEnvPath( );
    webLog( "Running R pnorm( )\n" );
    my $env = "PATH='/bin:/usr/bin'; export PATH";
    my $cmd = "$env; $r_bin --slave < $tmpRcmdFile > /dev/null";
    webLog( "+ $cmd\n" );
    my $st = system( $cmd );
    WebUtil::resetEnvPath( );

    my $rfh = newReadFileHandle( $tmpRoutFile, "getPvalues" );
    my @pvalues;
    while( my $s = $rfh->getline( ) ) {
        chomp $s;
	my $pvalue = $s;
	push( @pvalues, $pvalue );
    }
    close $rfh;
    my $nPvalues = @pvalues;
    if( $nPvalues != $nKeys ) {
        webDie( "getPvalues: nPvalues=$nPvalues nKeys=$nKeys" );
    }

    my $idx = 0;
    for my $id( @keys ) {
       my $pvalue = $pvalues[ $idx ];
       my $flag = $flags_ref->{ $id };
       #if( $flag eq "undersized" ) {
       #  webLog( "Setting p-value to 1.00 for undersized '$id'\n" );
       #  $pvalue = 1.00;
       #}
       $pvalues_ref->{ $id } = $pvalue;
       $idx++;
    }

    wunlink( $tmpDscoreFile );
    wunlink( $tmpRcmdFile );
    wunlink( $tmpRoutFile );
}


############################################################################
# getPvalueCutoff - Get false discovery rate cutoffs.  Set flags that
#   don't meet the cutoffs.
############################################################################
sub getPvalueCutoff {
    my( $pvalues_href ) = @_;

    my @funcIds = keys( %$pvalues_href );
    my $n = @funcIds;
    my @a;
    for my $funcId( @funcIds ) {
        my $pvalue = $pvalues_href->{ $funcId };
	push( @a, $pvalue );
    }
    my @b = sort{ $a <=> $b }( @a );
    my $last_pvalue = 0;
    for( my $i = 1; $i <= $n; $i++ ) {
       my $pvalue = $b[ $i ];
       my $pfdr = ( $i * $fdr ) / $n;
       if( $pvalue > $pfdr ) {
           last;
       }
       $last_pvalue = $pvalue;
    }
    return $last_pvalue;
}

############################################################################
# setCutoffFlag - Set cutoff flag for values that exceed false
#   discovery rate (FDR).
############################################################################
sub setCutoffFlag {
    my( $pvalue_cutoff, $pvalues_href, $flags_href ) = @_;

    my @funcIds = keys( %$pvalues_href );
    for my $funcId( @funcIds ) {
        my $pvalue = $pvalues_href->{ $funcId };
	if( $pvalue > $pvalue_cutoff ) {
	   $flags_href->{ $funcId } = "fdr_cutoff";
	}
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
       A test is valid if sufficient size for a normal distribution:<br/>
       <br/>
       <i>x1 >= 5 and x2 >= 5</i> or<br/>
       <i>x1 + x2 >= 10 and x1 > x2 and n2 >= n1</i> or<br/>
       <i>x1 + x2 >= 10 and x2 > x1 and n1 >= n2</i>.<br/>
       <br/>
       A test is invalid if it does not meet the p-value cutoff based on<br/>
       a prorated false discovery rate (fdr) of 0.05  for ranked  p-values:<br/>
       &nbsp; &nbsp; <i>p_value >= fdr * rank( p_value ) / n</i><br/>
       where <i>n</i> is the number of hypotheses (functions) tested.<br/>
    };
    print "</p>\n";
}


1;


