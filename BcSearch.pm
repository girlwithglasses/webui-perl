#
#
# $Id: BcSearch.pm 33018 2015-03-18 21:53:32Z aratner $
#
package BcSearch;
my $section = "BcSearch";

use strict;
use POSIX qw(ceil floor);
use CGI qw( :standard );
use Data::Dumper;
use HTML::Template;
use WebConfig;
use WebUtil;
use HtmlUtil;
use OracleUtil;
use InnerTable;

my $env             = getEnv();
my $main_cgi        = $env->{main_cgi};
my $section_cgi     = "$main_cgi?section=$section";
my $inner_cgi       = $env->{inner_cgi};
my $tmp_url         = $env->{tmp_url};
my $tmp_dir         = $env->{tmp_dir};
my $verbose         = $env->{verbose};
my $base_dir        = $env->{base_dir};
my $base_url        = $env->{base_url};
my $ncbi_base_url   = $env->{ncbi_entrez_base_url};
my $pfam_base_url   = $env->{pfam_base_url};
my $img_ken         = $env->{img_ken};
my $preferences_url = "$main_cgi?section=MyIMG&form=preferences";
my $YUI             = $env->{yui_dir_28};
my $nvl             = getNvl();

sub dispatch {
    my $page = param('page');

    if ( $page eq 'test' ) {
        test();
    } elsif ( $page eq 'chemSearch' ) {
        printChemSearchForm(1);
    } elsif ( $page eq 'chemSearchRun' ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;           
        chemSearchRun();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq 'npSearch' ) {
        require NaturalProductSearch;
        NaturalProductSearch::printNaturalProductSearchForm(1);
    } elsif ( $page eq 'npSearchResult' 
        || paramMatch("npSearchResult") ne '' ) {
        timeout( 60 * 40 );      # timeout in 40 minutes
        require NaturalProductSearch;
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;           
        NaturalProductSearch::printNaturalProductSearchResult();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq 'npSearches' ) {
        printNPSearchForms();
    } elsif ( $page eq 'bcSearch' ) {
        require BiosyntheticSearch;
        BiosyntheticSearch::printBiosyntheticSearchForm();
    } elsif ( $page eq 'bcSearchResult' 
        || paramMatch("bcSearchResult") ne '' ) {
        timeout( 60 * 40 );      # timeout in 40 minutes
        require BiosyntheticSearch;
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;           
        BiosyntheticSearch::printBiosyntheticSearchResult();
        HtmlUtil::cgiCacheStop();
    }
}

sub printNPSearchForms {
    print "<h1>Secondary Metabolite (SM) Search</h1>\n";

    my $idSearchUrl = "main.cgi?section=BcNpIDSearch&option=np";
    my $idSearchLink = alink($idSearchUrl, "Search Secondary Metabolite by ID");
    print qq{
        <p>$idSearchLink</p>
    };
    print qq{
        <script language='JavaScript' type='text/javascript' src='$base_url/validation.js'>
        </script>
    };

    TabHTML::printTabAPILinks("npsearchesTab");
    my @tabIndex = ( "#npsearchestab1", "#npsearchestab2" );
    my @tabNames = ( "by Fields", "by Chemical Structure" );
    TabHTML::printTabDiv( "npsearchesTab", \@tabIndex, \@tabNames );

    print "<div id='npsearchestab1'>";
    require NaturalProductSearch;
    NaturalProductSearch::printNaturalProductSearchForm();
    print "</div>\n";

    print "<div id='npsearchestab2'>";
    printChemSearchForm();
    print "</div>\n";

    TabHTML::printTabDivEnd();
}


sub test {
    #runCompareSearch('Pyocyanin', 'CN1C2=CC=CC=C2N=C3C1=CC=CC3=O', 50, 'nps');
    print qq{
        Search for <br>
        'Pyocyanin', 'CN1C2=CC=CC=C2N=C3C1=CC=CC3=O', 0.5, 'all'
    };

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    printStartWorkingDiv();
    my $dbh = dbLogin();
    my $data_aref = runCompareSearch( 'Pyocyanin', 'CN1C2=CC=CC=C2N=C3C1=CC=CC3=O', 0.5, 'all' );
    return if ( $#$data_aref < 0 );    # no results

    my ($compoundIds_ref, $compId2pubId_href, $compId2score_href) 
        = getCompounds( $dbh, $data_aref );

    myEndWorkingDiv();
    
    require NaturalProd;
    my $cnt = NaturalProd::printNaturalProducts( $dbh, '', 
        $compoundIds_ref, $compId2pubId_href, $compId2score_href );

    print end_form();
    printStatusLine( "$cnt loaded", 2 );
}

sub chemSearchRun {
    my $name   = param('name');
    my $smiles = param('smiles');
    my $cutoff = param('cutoff');
    my $space  = param('space');

    if ( $name ) {
        $name = WebUtil::processSearchTerm($name, 1);
        if (!blankStr($name) && length($name) > 64) {
            WebUtil::webError("Name cannot be more than 64 characters.");
        }
        if ( !blankStr($name) && $name !~ /[a-zA-Z0-9]+/ ) {
            WebUtil::webError("Name should have some alphanumeric characters.");
        }
    }    
    
    WebUtil::processSearchTermCheck($smiles, 'SMILES');
    $smiles = WebUtil::processSearchTerm($smiles, 1);
    if (blankStr($smiles)) {
        WebUtil::webError("SMILES is required for a search.");
    }
    
    $cutoff = WebUtil::processSearchTerm($cutoff);
    if (blankStr($cutoff)) {
        WebUtil::webError("Similarity Cutoff is required for a search.");
    }
    if (!WebUtil::isNumber($cutoff)) {
        WebUtil::webError("Invalid Cutoff value.");
    }
    if ( $cutoff !~ m/\d+|\./ || $cutoff =~ m/[a-zA-Z]/ || $cutoff < 0 || $cutoff > 1 ) {
        WebUtil::webError("Cutoff value not valid. Only integers between 0 and 1 are accepted.");
    }
    if (!blankStr($cutoff)) {
        $cutoff = sprintf( "%.2f",  $cutoff);
    }

    # do some validation here?
    # SMILES - https://gist.github.com/lsauer/1312860
    # https://www.biostars.org/p/13468/ /^([^J][A-Za-z0-9@+\-\[\]\(\)\\=#$]+)$/
    #
    #if($smiles =~ /^([^J][A-Za-z0-9@+\-\[\]\(\)\\=#$]+)$/) {
    # good SMILES syntax
    #} else {
    #     WebUtil::webError("Incorrect SMILES syntax");
    #}

    print qq{
      <h1>Secondary Metabolite (SM) Search Results By Chemical Structure</h1>
      <p>
    };
    print qq{
      Secondary Metabolite Name: $name<br>
    } if ( $name && !blankStr($name) );
    
    my $tmp = 'All Biosynthetic Gene Cluster associated compounds';
    $tmp = 'All IMG compounds' if($space eq 'all');
    print qq{
      SMILES: $smiles<br>
      Similarity Cutoff: $cutoff<br>
      Search Space: $tmp<br>
      </p>  
    };
    
    printStatusLine( "Loading ...", 1 );
    printMainForm();

    printStartWorkingDiv();

    my $dbh = dbLogin();
    my $data_aref = runCompareSearch( $name, $smiles, $cutoff, $space );
    return if ( $#$data_aref < 0 );    # no results

    my ($compoundIds_ref, $compId2pubId_href, $compId2score_href) 
        = getCompounds( $dbh, $data_aref );

    myEndWorkingDiv();
    
    require NaturalProd;
    my $cnt = NaturalProd::printNaturalProducts( $dbh, '', 
        $compoundIds_ref, $compId2pubId_href, $compId2score_href );

    print end_form();
    printStatusLine( "$cnt loaded", 2 );

}

sub printChemSearchForm {
    my ( $includeJS ) = @_;

    WebUtil::printMainFormName('Chem');
    if ( $includeJS ) {
        print qq{
            <h1>Secondary Metabolite (SM) Search By Chemical Structure</h1>
            <script language='JavaScript' type='text/javascript' src='$base_url/validation.js'>
            </script>
        };        
    }
    print qq{
        <p>
        Use chemical structures to find the most similar compound in IMG and,
        if available, the associated biosynthetic gene cluster.</p>
    };

    my $template = HTML::Template->new
	( filename => "$base_dir/bcChemSearch.html" );
    print $template->output;
    print WebUtil::end_form();
}

sub myEndWorkingDiv {
    my ($name) = @_;

    if ($img_ken) {
        printEndWorkingDiv( $name, 1 );
    } else {
        printEndWorkingDiv($name);
    }
}

#
# returns list of compound IDs
#
sub getCompounds {
    my ( $dbh, $data_aref ) = @_;

    my @numIds;
    my %id2score;
    foreach my $line (@$data_aref) {
        my ( $id, $score ) = split( /\t/, $line );
        push( @numIds, $id );
        $id2score{$id} = $score;
    }

    # get img compounds
    print "Getting compound names<br>\n";
    my $inClause = OracleUtil::getNumberIdsInClause( $dbh, @numIds );
    my $sql      = qq{
        select x.compound_oid, x.id
        from img_compound_ext_links x
        where x.db_name ='PubChem Compound'
        and x.id in ($inClause)
    };

    my %compId2pubId;
    my %compId2score;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $compoundId, $pubId ) = $cur->fetchrow();
        last if ( !$compoundId );
        $compId2pubId{$compoundId} = $pubId;
        $compId2score{$compoundId} = $id2score{$pubId};
    }
    my @compoundIds = keys %compId2pubId;

    return (\@compoundIds, \%compId2pubId, \%compId2score);
}

#
# Michalis compare.pl - code place here run it within IMG framework and not as script
# - ken
#
# return array ref of PubChem_Comp_ID<tab>SimilarityScore%
sub runCompareSearch {
    my ( $name, $smiles, $cutoff, $all ) = @_;
    my $databaseDir  = '/global/dna/projectdirs/microbial/omics-biosynthetic/BigNP_Structure_search/';
    my $databaseFile = $databaseDir . 'apsetNPS.rda';                                                    # 'np'
    $databaseFile = $databaseDir . 'apsetALL.rda' if ( $all eq 'all' );

    # user's tmp dir
    my $dir = WebUtil::getSessionCgiTmpDir('BC');

    #if ( $cutoff < 0 || $cutoff > 100 || $cutoff !~ m/\d+/ || $cutoff =~ m/[a-zA-Z]/ ) {
    #    myEndWorkingDiv();
    #    WebUtil::webError("Cutoff value not valid. Only integers between 0 and 100 are accepted.");
    #}

    #my $cut = 0;
    #$cut = $cutoff / 100 unless $cutoff == 0;

    # write $smiles to a file
    print "Creating smiles<br>\n";
    my $smilesFilename = $dir . "/smi$$.txt";
    my $wfh            = WebUtil::newWriteFileHandle($smilesFilename);
    if (blankStr($name)) {
        print $wfh "$smiles\n";
    } else {
        print $wfh "$smiles\t$name\n";
    }
    close $wfh;

    print "Preparing R script<br>\n";
    my $comparisonRFilename = $dir . "/comparison$$.r";
    my $wfh                 = WebUtil::newWriteFileHandle($comparisonRFilename);
    my $str                 =
        "library(ChemmineR)\n"
      . "library(fmcsR)\n"
      . "smi <- read.SMIset(\"$smilesFilename\")\n"
      . "sdfq <- smiles2sdf(smi[1])\n"
      . "load(\"$databaseFile\")\n"
      . "apsetQ <- sdf2ap(sdfq)\n"
      . "cmp.search(apset, apsetQ[1], type=3, cutoff = "
      . $cutoff . ")\n";

    print $wfh $str;
    close $wfh;

    my $outputFilename = $dir . "/tmpO$$";
    my $errorFilename  = $dir . "/tmpE$$";
    my $rscript        = '/global/common/genepool/usg/languages/R/3.0.1/bin/Rscript';
    $rscript = 'Rscript';
    my $cmd = "$rscript $comparisonRFilename >$outputFilename 2>$errorFilename";

    print "Running R....<br>\n";
    print "running:<br> $cmd<br>\n" if ($img_ken);
    unsetEnvPath();
    $cmd = each %{ { $cmd, 0 } };    # untaint
    my $suc = system($cmd);

    if ( $suc != 0 ) {

        print "Exit is non zero $? <br> $!\n";
        print "Checking for errors.<br>\n";
        myEndWorkingDiv();
        my $rfh = newReadFileHandle( $errorFilename, 'error file check' );
        while ( my $line = $rfh->getline() ) {
            chomp $line;
            if ( $line =~ m/Error\sin\ssmiles2sdfWeb/ ) {

                WebUtil::webError("SMILES are not valid. Please check and resubmit.");
                close $rfh;
            }
        }
        close $rfh;

        WebUtil::webError( "Error: $cmd <br> failed <br> $? <br> $!", 0, 1 );
    }

    # check for errors
    print "Checking for errors.<br>\n";
    my $rfh = newReadFileHandle( $errorFilename, 'error file check' );
    while ( my $line = $rfh->getline() ) {
        chomp $line;
        if ( $line =~ m/Error\sin\ssmiles2sdfWeb/ ) {
            myEndWorkingDiv();
            WebUtil::webError("SMILES are not valid. Please check and resubmit.");
            close $rfh;
        }
    }
    close $rfh;

    # read output file
    print "Reading results.<br>\n";
    my @out;
    my @tally;
    my $rfh = newReadFileHandle( $outputFilename, 'output file' );
    while ( my $line = $rfh->getline() ) {
        chomp $line;
        next unless $line =~ m/^\d/;
        @out = split( " ", $line );
        my $score = $out[3] * 100;
        next unless $score > $cutoff;
        my $res = "$out[2],$score";
        push( @tally, $res );
    }
    close $rfh;

    my @returnData;
    my $total = scalar(@tally);
    if ( $total == 0 ) {
        myEndWorkingDiv();
        print "No compounds found with similarity cutoff of $cutoff to \"$name\"\n";
    } else {
        foreach my $match (@tally) {
            $match =~ s/\,/\t/;
            print "$match<br>\n" if ($img_ken);
            push( @returnData, $match );
        }
    }

    my $size = $#returnData + 1;
    print "$size results found<br>\n";
    return \@returnData;
}


1;
