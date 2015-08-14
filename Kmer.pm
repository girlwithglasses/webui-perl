###########################################################################
# Kmer.pm - Get the kmer frequencies of a set of sequences
#           -- originally developed by Konstantinos Mavrommatis, Dec 2011
#
#           This tool is used to identify the contigs/scaffolds
#           that have significantly different composition than
#           the rest of the populations. The 4mer frequencies for
#           each scaffold are computed and then analyzed using PCA.
#
# $Id: Kmer.pm 33981 2015-08-13 01:12:00Z aireland $
###########################################################################
package Kmer;

use strict;
use warnings;
use CGI qw( :standard);
use Data::Dumper;
use WebConfig;
use WebUtil;
use OracleUtil;
use JSON;
use SequenceExportUtil;

$| = 1;

my $page;
my $section              = "Kmer";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $cgi_dir              = $env->{cgi_dir};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $tmp_url              = $env->{tmp_url};
my $tmp_dir              = $env->{tmp_dir};
my $verbose              = $env->{verbose};
my $user_restricted_site = $env->{user_restricted_site};
my $base_url             = $env->{base_url};
my $base_dir             = $env->{base_dir};
my $taxon_fna_dir        = $env->{taxon_fna_dir};
my $r_bin                = $env->{r_bin};
my $java_home            = $env->{java_home};
my $YUI                  = $env->{yui_dir_28};

# Kmer default settings in Customize button
my $defFragmentWindow    = 5000;
my $defFragmentStep      = 500;
my $defKmerSize          = 4;
my $defMinVariation      = 10;

my $kMerJar              = "$base_dir/KmerFrequencies.jar";
my $kMerRscript          = "$cgi_dir/bin/showKmerBin.R";
my $kMerHtmlFile         = "Kmer.html"; # must be prepended with $base_dir

# Kmer setting bounds and message text
my %kmerParam = (
    fragmentWindow => {
	text => "Fragment window",
	min  => 1000,
	max  => 10000,
	val  => $defFragmentWindow
    },
    fragmentStep => {
	text => "Fragment step",
	min  => 100,
	max  => 1000,
	val  => $defFragmentStep
    },
    kmerSize => {
	text => "Oligomer size",
	min  => 2,
	max  => 8,
	val  => $defKmerSize
    },
    minVariation => {
	text => "Minimum variation",
	min  => 1,
	max  => 20,
	val  => $defMinVariation
    }
);

my $SCAF_FOLDER = "scaffold";

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    $page = param("page");
    timeout( 60 * 20 );    # timeout in 20 minutes (from main.pl)
    if ( $page eq "plot" ) {
        kmerPlotTaxon();
    } elsif ( $page eq "plotScaffolds" ||
      paramMatch("plotScaffolds") ne "" ) {
    	kmerPlotScaffolds();
    } elsif ( $page eq "graph" ) {
        showScaffoldGraph();
    } elsif ( paramMatch("export") ne "" ) {
        exportPlot();
    } else {
        kmerPlotTaxon();
    }
}

############################################################################
# kmerPlotScaffolds - Print kmer frequency plot for selected scaffolds
############################################################################
sub kmerPlotScaffolds {
    # get what is selected in the cart
    my @scaffold_oids = param('scaffold_oid');
    my $isSet = param('isSet');
    if ( scalar(@scaffold_oids) == 0 ) {
        if ($isSet) {
            webError("No scaffold sets have been selected.");
        } else {
            webError("No scaffolds have been selected.");
        }
        return;
    }

    my $dbh = dbLogin();
    my $sid = WebUtil::getContactOid();

    my %set2scafs;
    my %set2shareSetName;
    my @scaf_set_names = param('input_file');
    foreach my $scaf_set (@scaf_set_names) {
        my @scafs = param($scaf_set);
        $set2scafs{$scaf_set} = \@scafs;

        my ( $owner, $x ) = WorkspaceUtil::splitAndValidateOwnerFileset( $sid, $scaf_set, '', $SCAF_FOLDER );
        my $share_set_name = WorkspaceUtil::fetchShareSetName( $dbh, $owner, $x, $sid );
        $set2shareSetName{$scaf_set} = $share_set_name;
    }

    kmerPlotScaf(\@scaffold_oids, \%set2scafs, \%set2shareSetName, $isSet);
}

############################################################################
# kmerPlotScaf
############################################################################
sub kmerPlotScaf {
    my ($scaffold_oids_ref, $set2scafs_href, $set2shareSetName_href, $isSet, $ignoreSettings) = @_;
    $page = "plotScaffolds";

    print "<h1>Kmer Frequency Analysis</h1>";

    my $outputPrefix = printKmerWindow
        ("", $scaffold_oids_ref, $set2scafs_href, $isSet, $ignoreSettings);
    return if !$outputPrefix;

    my $firstHtml = "$tmp_dir/${outputPrefix}PC1-PC2-PC3.html";
    # "kmerPlotScaf() firstHtml=$firstHtml<br/>\n";
    if (!-e $firstHtml) { # Check if at least 1 plot html exists
        my $fastaFile = SequenceExportUtil::getFastaFileForScaffolds
	    ($scaffold_oids_ref, 1);
        my $scaffoldsMapFile = writeScaffoldsMapFile
	    ($scaffold_oids_ref, $set2scafs_href, $isSet);
        my $outputFile = generateKmerSrc
            ($fastaFile, $outputPrefix, $scaffoldsMapFile);
        #print "kmerPlotScaf() outputFile=$outputFile<br/>\n";
    	my $text = "Selected Scaffolds";
    	$text = "Selected Scaffold Sets" if $isSet;
    	generatePlotTaxon($text, $outputFile, $outputPrefix);
    }

    print "<br/>";
    printPage($outputPrefix, $set2scafs_href, $set2shareSetName_href, $isSet);
}

sub writeScaffoldsMapFile {
    my ($scaffold_oids_ref, $set2scafs_href, $isSet) = @_;

    my %s2set; # anna: need a map of scaffold_oid:set
    if ($isSet && $set2scafs_href) {
    	foreach my $x (keys %$set2scafs_href) {
    	    my $scafs_ref = $set2scafs_href->{$x};
    	    foreach my $scaf_oid (@$scafs_ref) {
                $s2set{$scaf_oid} = $x;
    	    }
    	}
    }

    my ( $dbOids_ref, $metaOids_ref ) =
	MerFsUtil::splitDbAndMetaOids(@$scaffold_oids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my $scaffoldsMapFile = "$tmp_dir/scaffoldsKmer$$.txt";
    my $wfh = newWriteFileHandle( $scaffoldsMapFile, "scaffoldsMap" );
    if (scalar(@metaOids) > 0) {
        foreach my $scaffold_oid (@metaOids) {
            my ($taxon_oid, $d2, $s_oid) = split(/ /, $scaffold_oid);
    	    my $str = "$s_oid\t";
            $str .= "$taxon_oid"."-"."$d2"."-"."$s_oid";
    	    my $set = $s2set{ $scaffold_oid };
    	    $str .= "\t$set" if $isSet && $set;
    	    $str .= "\n";
    	    print $wfh $str;
        }
    }

    if (scalar(@dbOids) > 0) {
        my $dbh = dbLogin();
        my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );
        my $sql = qq{
            select s.scaffold_oid, s.ext_accession
            from scaffold s
            where s.scaffold_oid in ($oid_str)
            and s.ext_accession is not null
        };
        my $cur = execSql($dbh, $sql, $verbose);
        for ( ;; ) {
            my ( $scaffold_oid, $ext_accession ) = $cur->fetchrow();
            last if !$scaffold_oid;
    	    print $wfh "$ext_accession\t";
            print $wfh "$scaffold_oid";

    	    my $set = $s2set{ $scaffold_oid };
    	    print $wfh "\t$set" if $isSet && $set;
    	    print $wfh "\n";
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
            if ( $oid_str =~ /gtt_num_id/i );
    }
    close $wfh;

    return $scaffoldsMapFile;
}


############################################################################
# kmerPlotTaxon - Print kmer frequency plot for a given taxon
############################################################################
sub kmerPlotTaxon {
    my $taxon_oid = param("taxon_oid");
    webError("Taxon ID missing") if (!$taxon_oid);
    webError("Invalid Taxon ID") if (!isNumber($taxon_oid));

    my $dbh = dbLogin();
    my $sql = qq{
        select s.scaffold_oid, s.ext_accession,
               tx.taxon_display_name
        from scaffold s, taxon tx
        where s.taxon = tx.taxon_oid
        and tx.taxon_oid = ?
        and s.ext_accession is not null
    };
    my $cur = execSql($dbh, $sql, $verbose, $taxon_oid);

    my $scaffoldsMapFile = "$tmp_dir/scaffolds$$.txt";
    my $wfh = newWriteFileHandle( $scaffoldsMapFile, "scaffoldsMap" );
    my $taxon_name;
    for ( ;; ) {
        my ( $scaffold_oid, $ext_accession, $taxon_display_name )
	    = $cur->fetchrow();
        last if !$scaffold_oid;
    	$taxon_name = $taxon_display_name;
        print $wfh "$ext_accession\t";
        print $wfh "$scaffold_oid\n";
    }
    close $wfh;
    $cur->finish();

    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<h1>Kmer Frequency Analysis</h1>";
    print "<p>".alink($url, $taxon_name)."</p>";

    my $outputPrefix = printKmerWindow($taxon_oid);
    return if !$outputPrefix;
    print hiddenVar("taxon_oid", $taxon_oid);

    my $firstHtml = "$tmp_dir/${outputPrefix}PC1-PC2-PC3.html";
    if (!-e $firstHtml) { # Check if at least 1 plot html exists
    	my $outputFile = generateKmerSrcTaxon
    	    ($taxon_oid, $outputPrefix, $scaffoldsMapFile);
    	generatePlotTaxon($taxon_name, $outputFile, $outputPrefix);
    }

    print "<br/>";
    printPage($outputPrefix);
}

############################################################################
# printKmerWindow - shows the Kmer settings popup
############################################################################
sub printKmerWindow {
    my ($taxon_oid, $scaffold_oid_aref, $set2scafs_href, $isSet,
	$ignoreSettings) = @_;

    my $outputPrefix;
    if ( ! $ignoreSettings ) {
        $outputPrefix = findKmerSettings();
    }
    printKmerSettings($outputPrefix, $taxon_oid, $scaffold_oid_aref,
		      $set2scafs_href, $isSet);

    return $outputPrefix;
}

############################################################################
# findKmerSettings
############################################################################
sub findKmerSettings {
    my $fragmentWindow = param("fragmentWindow");
    my $fragmentStep   = param("fragmentStep");
    my $kmerSize       = param("kmerSize");
    my $minVariation   = param("minVariation");
    #print "findKmerSettings() fragmentWindow=$fragmentWindow, fragmentStep=$fragmentStep, kmerSize=$kmerSize, minVariation=$minVariation<br/>\n";

    $kmerParam{fragmentWindow}{val} = $fragmentWindow if ($fragmentWindow);
    $kmerParam{fragmentStep}{val}   = $fragmentStep   if ($fragmentStep);
    $kmerParam{kmerSize}{val}       = $kmerSize       if ($kmerSize);
    $kmerParam{minVariation}{val}   = $minVariation   if ($minVariation);

    foreach my $key (keys %kmerParam) {
        my $min  = $kmerParam{$key}{min};
        my $max  = $kmerParam{$key}{max};
        my $text = $kmerParam{$key}{text};
        if ( $kmerParam{$key}{val} < $min || $kmerParam{$key}{val} > $max) {
            webError("$text needs to be between $min and $max");
        }
    }

    my $outputPrefix = getOutputPrefix() if ($fragmentWindow);
    return ($outputPrefix);
}

############################################################################
# getOutputPrefix
############################################################################
sub getOutputPrefix {
    my $sessid = getSessionId();
    my $id = "Kmer$$".$sessid;
    my $outputPrefix = "$id" .
        "-${kmerParam{fragmentWindow}{val}}" .
        "-${kmerParam{fragmentStep}{val}}" .
        "-${kmerParam{kmerSize}{val}}" .
        "-${kmerParam{minVariation}{val}}";

    return $outputPrefix;
}

############################################################################
# printKmerWindowSettings - shows the Kmer settings popup
############################################################################
sub printKmerSettings {
    my ($outputPrefix, $taxon_oid, $scaffold_oid_aref, $set2scafs_href, $isSet) = @_;

    my $maidenRun = 1 if (!$outputPrefix);
    printKmerHTML($taxon_oid, $scaffold_oid_aref,
		  $set2scafs_href, $isSet, $maidenRun);
    return 0 if $maidenRun;

    if ( !$outputPrefix ) {
        $outputPrefix = getOutputPrefix();
    }

    print "<div style='border:2px solid #99ccff;"
        . "padding:1px 5px;margin-left:1px;width:100%'>\n";
    my $oligo_text = "<span style='color:red'>Lowering the 'Oligomer size' helps avoid running out of memory</span>";
    print "<table width='100%'>";
    print "<tr><td>\n";
    print "<span style='padding-left:15px;margin:0px;'>\n";
    print "$oligo_text <br/>";
    print "<span style='padding-left:15px;margin:0px; "
	. "title='Length of fragment represented by each "
        . "point on the plot'>${kmerParam{fragmentWindow}{text}}: "
        . "<b>${kmerParam{fragmentWindow}{val}}</b> "
        . "bp</span>, <span title='Distance between two fragment windows'>"
        . "${kmerParam{fragmentStep}{text}}: "
        . "<b>${kmerParam{fragmentStep}{val}}</b> bp</span>, "
        . "<span title='Value of K'>${kmerParam{kmerSize}{text}}: "
        . "<b>${kmerParam{kmerSize}{val}}</b></span>, "
        . "<span title='Minimum variation that a PC explains "
        . "in order to be plotted'>${kmerParam{minVariation}{text}}: "
        . "<b>${kmerParam{minVariation}{val}}</b></span>\n";
    print "</span></td><td style='text-align:right'>";
    print button(
            -id    => "show",
            -value => "Change Settings",
            -class => "smbutton",
    );
    print "</td></tr></table>";
    print "</div>";

    return $outputPrefix;
}

sub printPage {
    my ($outputPrefix, $set2scafs_href, $set2shareSetName_href, $isSet) = @_;

    use TabHTML;
    TabHTML::printTabAPILinks("kmerTab", 1);
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("kmerTab");
        </script>
    };
    my @tabIndex = ( "#kmertab1", "#kmertab2" );
    my @tabNames = ( "2D View", "3D View" );
    TabHTML::printTabDiv("kmerTab", \@tabIndex, \@tabNames);

    print "<div id='kmertab1'>";
    printHint("Mouse over a point to see the scaffold which it represents.  "
	    . "<br/>Click on a point to go to the Chromosome Viewer."
	    . "<br/>If .html and/or .kin files were not created, the system "
	    . "could have run out of memory during computation, - "
	    . "you may try to lower the 'Oligomer size' and recompute."
	);

    my $statLine = "";
    for (my $i = 1; ;$i++) {
    	my $filePath = "$tmp_dir/${outputPrefix}PC$i" .
    	    "-PC" . ($i+1) . "-PC" . ($i+2);
    	my $htmlFilePath  = $filePath . ".html";
    	my $pngFilePath   = $filePath . ".png";
    	my $strHtml;

    	if (!-e $htmlFilePath) {
    	    if (-e $pngFilePath) {
		print "<p>Unable to generate interactive plot for PC$i vs PC"
		    . ($i+1) . ".</p>";
		$strHtml = "<img src='$pngFilePath'>";
    	    } else {
		if ($i == 1) {
		    print "<p style='padding-left:10px;font-style:italic'>";
		    print "<img style='vertical-align:middle' "
			. "src='$base_url/images/error.gif' border=0>"
			. nbsp(1) . "Could not find the .html data file. "
			. "Please check whether the parameters to Kmer are "
			. "within the range for your data.</p>";
		}
		last;
    	    }
    	} else {
    	    no warnings; # suppress warnings for uninitialized string
    	    $strHtml = file2Str($htmlFilePath);
    	    my $comma = ", " if ($i > 1);
    	    $statLine .= "${comma}PC$i vs PC" . ($i+1);
    	}
    	print "\n$strHtml";
    }
    print "</div>"; # end kmertab1

    print "<div id='kmertab2'>";
    my $kinFile = "$tmp_dir/${outputPrefix}PC1-PC2-PC3.kin";
    if (!-e $kinFile) {
    	print "<p style='padding-left:10px;font-style:italic'>";
    	print "<img style='vertical-align:middle' "
    	    . "src='$base_url/images/error.gif' border=0>"
    	    . nbsp(1) . "Could not find the .kin file.</p>";
    } else {
    	use King;
    	King::plotFile($kinFile, $set2scafs_href, $isSet);
    }
    print "</div>"; # end kmertab2
    TabHTML::printTabDivEnd();

    printStatusLine($statLine . " loaded.");
}

############################################################################
# generateKmerSrcTaxon - Create a kmer file given a taxon
#
# Load sequences from a fasta file and output a file with kmer frequencies
# of the sequences. Each sequence is split to overlapping pieces of
# size fragmentWindow, and step fragmentStep
############################################################################
sub generateKmerSrcTaxon {
    my ($taxon_oid, $outputPrefix, $scaffoldsMapFile) = @_;
    my $inputFasta = "$taxon_fna_dir/$taxon_oid.fna";
    generateKmerSrc($inputFasta, $outputPrefix, $scaffoldsMapFile);
}

sub generateKmerSrc {
    my ($inputFasta, $outputPrefix, $scaffoldsMapFile) = @_;
    my $outputFile = "$cgi_tmp_dir/$outputPrefix.${kmerParam{kmerSize}{val}}"
	           . "mer";
    webDie("Cannot find input file "      . $inputFasta) if(!-e $inputFasta);
    webDie("Cannot find the jar file "    . $kMerJar) if(!-e $kMerJar);
    webDie("Cannot find the script file " . $kMerRscript) if(!-e $kMerRscript);

    #print "generateKmerSrc() inputFasta=$inputFasta<br/>\n";
    #print "generateKmerSrc() kMerJar=$kMerJar<br/>\n";
    #print "generateKmerSrc() kMerRscript=$kMerRscript<br/>\n";
    #print "generateKmerSrc() outputFile=$outputFile<br/>\n";

    WebUtil::unsetEnvPath();
    my $env = "PATH='$java_home/bin:/bin:/usr/bin'; export PATH;";
    my $cmd = "$env java -jar $kMerJar "
	    . "-i $inputFasta "       # .fna
	    . "-o $outputFile "       # .4mer
	    . "-a $scaffoldsMapFile " # map of ext_accession:scaffold_oid:set
	    . "-w ${kmerParam{fragmentWindow}{val}} "   # 5000
	    . "-s ${kmerParam{fragmentStep}{val}} "     # 500
	    . "-k ${kmerParam{kmerSize}{val}} ";        # 4
    $cmd = each %{{$cmd,0}};  # untaint the variable to make it safe for Perl
    printLocalStatus("Generating ${kmerParam{kmerSize}{val}}mer file.");

    #print "generateKmerSrc() cmd=$cmd<br/>\n";
    my $st = system($cmd);
    WebUtil::resetEnvPath();

    return $outputFile;
}

############################################################################
# generatePlot - Create a kmer frequency plot image and a bundled HTML file
############################################################################
sub generatePlotTaxon {
    my ($taxon_name, $kmerFile, $outputPrefix) = @_;

    #print "generatePlotTaxon() kmerFile=$kmerFile<br/>\n";
    #print "generatePlotTaxon() outputPrefix=$outputPrefix<br/>\n";

    my $dotUrl = $section_cgi . "&page=graph";
    my $taxon_oid = param("taxon_oid");

    WebUtil::unsetEnvPath();
    my $env = "PATH='/bin:/usr/bin'; export PATH; cd $tmp_dir";
    my $cmd = "$env; $r_bin --slave "
	    . "--file=$kMerRscript --args "
	    . "--input  '$kmerFile' "
	    . "--output '$outputPrefix' "
	    . "--pngurl '$tmp_url/' "
	    . "--doturl '$dotUrl' "
	    . "--label  '$taxon_name' "
	    . "--oid    '$taxon_oid' "
	    . "--minvariation ${kmerParam{minVariation}{val}}";
    $cmd = each %{{$cmd,0}};  # untaint the variable to make it safe for Perl
    printLocalStatus("Creating plot.");

    #print "generatePlotTaxon() cmd=$cmd<br/>\n";
    my $st = system($cmd);
    WebUtil::resetEnvPath();
    wunlink ($kmerFile);
}

############################################################################
# showScaffoldGraph - Display scaffold graph when plot is clicked
############################################################################
sub showScaffoldGraph {
    my $extAccession = param("extacc");
    my $range        = param("range");
    my $taxon_oid    = param("taxon_oid");
    my $scaffold_oid = param("scaffold_oid");

    my $start_coord;
    my $end_coord;
    my $block_size   = 30000; # Length of Chromosome Viewer window

    webError("Unable to proceed with missing scaffold name") if !$extAccession;

    if (!$scaffold_oid || $scaffold_oid eq "") {
	webError("Unable to proceed with missing taxon_oid")
	    if !$taxon_oid || $taxon_oid eq "";
    }

    my $dbh = dbLogin();
    my $last_coord;

    if ($taxon_oid && $taxon_oid ne "") {
	my $sql = qq{
            select scf.scaffold_oid, st.seq_length
    	    from scaffold scf, scaffold_stats st
    	    where scf.scaffold_oid = st.scaffold_oid
	    and scf.taxon = st.taxon
            and scf.ext_accession = ?
            and scf.taxon = ?
        };
	my $cur = execSql($dbh, $sql, $verbose, $extAccession, $taxon_oid);
	($scaffold_oid, $last_coord) = $cur->fetchrow();
	param("scaffold_oid", $scaffold_oid);

    } else {
	if (isInt($scaffold_oid)) {
	    my $sql = qq{
            select scf.taxon, st.seq_length
            from scaffold scf, scaffold_stats st
            where scf.scaffold_oid = st.scaffold_oid
            and scf.scaffold_oid = st.scaffold_oid
            and scf.scaffold_oid = ?
            };
	    my $cur = execSql($dbh, $sql, $verbose, $scaffold_oid);
	    ($taxon_oid, $last_coord) = $cur->fetchrow();
	} else {
	    # merfs
	    my ($tx_oid, $d2, $scf_oid) = split("-", $scaffold_oid);
	    my ($seq_length, $gc, $gcount)
		= MetaUtil::getScaffoldStats($tx_oid, $d2, $scf_oid);
	    $last_coord = $seq_length;
	    $taxon_oid = $tx_oid;
	    param("data_type", $d2);
	    param("scaffold_oid", $scf_oid);
	}
    }

    if ($range) {
	($start_coord, $end_coord) = split(/\-/, $range);
    } else {
	$start_coord = 1;
	$end_coord   = $last_coord;
    }

    my $window_size = $end_coord - ($start_coord - 1);
    my $flank_size  = int($block_size/2) - int($window_size/2);
    my $left_flank  = $start_coord - $flank_size;
    my $right_flank = $end_coord + $flank_size;

    $left_flank  = 1 if ($left_flank < 1);
    $right_flank = $last_coord if ($right_flank > $last_coord);

    param("taxon_oid",    $taxon_oid);
    param("start_coord",  $left_flank);
    param("end_coord",    $right_flank);

    if (isInt($scaffold_oid)) {
	require ScaffoldGraph;
	ScaffoldGraph::printScaffoldGraph();
    } else {
	# merfs
	use MetaScaffoldGraph;
	MetaScaffoldGraph::printMetaScaffoldGraph();
    }
}

############################################################################
# getKmerSettingTableStr
############################################################################
sub getKmerSettingTableStr {
    my ( $isForJob ) = @_;

    my @customizeText;
    my @customizeValues;

    # Get %kmerParam values in the required order
    my @kmerKeys = ("fragmentWindow","fragmentStep","kmerSize","minVariation");

    foreach my $key (@kmerKeys) {
        no warnings;      # suppress warnings for uninitialized string
        my $text = $kmerParam{$key}{text};
        my $min  = $kmerParam{$key}{min};
        my $max  = $kmerParam{$key}{max};
        my $val  = $kmerParam{$key}{val};
        my $unit = "bp"
            if ($key eq "fragmentWindow" || $key eq "fragmentStep");
        push @customizeText, "$text ($min - $max)";
        push @customizeValues,
        qq{
        <input type="textbox" id="$key" name="$key" value="$val" maxLength="4" /> $unit
        };
    }

    # Use YUI css
    my $options;
    if ( $isForJob ) {
        my $json = new JSON;
        $json->pretty;
        my $kmerParamJSON = $json->encode(\%kmerParam);
        $options = qq{
        <script type="text/javascript">
        function validateAndCheckSets(textFieldName, btnGrpName, setType) {
            if (subValidate()) {
                if ( btnGrpName == "" ) {
                    return checkSetsAndFilled(textFieldName, setType);
                }
                else {
                    return checkSetsAndFileName(textFieldName, btnGrpName, setType);
                }
            }
            return false;
        }

        function subValidate() {
            var kmerParam = $kmerParamJSON;
                for (var i in kmerParam) {
                    var min  = kmerParam[i]['min' ];
                    var max  = kmerParam[i]['max' ];
                    var text = kmerParam[i]['text'];
                    var curValue = document.getElementById(i).value;
                    //alert(text + " value = " + curValue);
                    if (curValue < min || curValue > max) {
                        alert(text + " needs to be between " + min + " and " + max + "");
                        return false;
                    }
                }
                return true;
            }
        </script>
        };
    }
    $options .= qq{
        <link rel="stylesheet" type="text/css"
            href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <div class='yui-dt'>
        <p style='color:red'>
        Lowering the 'Oligomer size' helps avoid memory issues
        </p>
        <table style='font-size:12px'>
        <th>
          <div class='yui-dt-liner'>
          <span>Parameter</span>
          </div>
        </th>
        <th>
          <div class='yui-dt-liner'>
          <span>Setting</span>
          </div>
        </th>
    };

    my $classStr;
    for (my $idx = 0; $idx < @customizeText; $idx++) {
        $classStr = $idx ? "" : "yui-dt-first ";
        $classStr .= ($idx % 2 == 0) ? "yui-dt-even" : "yui-dt-odd";

        $options .= qq{
            <tr class='$classStr'>
            <td class='$classStr'>
            <div style='white-space:nowrap; padding:5px 20px 5px 20px'>
            $customizeText[$idx]
            </div>
            </td>
            <td class='$classStr'>
            <div style='white-space:nowrap; padding:5px 20px 5px 20px'>
            $customizeValues[$idx]
            </div>
            </td></tr>
        };
    }
    $options .= "</table>\n</div>\n";

    return $options;
}

############################################################################
# printKmerHTML - Prints required HTML & JavaScript for the Kmer Plot
############################################################################
sub printKmerHTML {
    my ($taxon_oid, $scaffold_oid_aref, $set2scafs_href,
	$isSet, $maidenRun) = @_;

    my $htmlTemplate = "$base_dir/$kMerHtmlFile";
    my $htmlStr = WebUtil::file2Str( $htmlTemplate );

    my $options = getKmerSettingTableStr();

    # Add hidden variables to form
    $options .= hiddenVar("section", $section);
    $options .= hiddenVar("page", $page) if $page;
    $options .= hiddenVar("taxon_oid", $taxon_oid) if $taxon_oid;
    if (!$taxon_oid || $taxon_oid eq "") {
	if ($scaffold_oid_aref ne "") {
	    my @scaffold_oids = @$scaffold_oid_aref;
	    foreach my $scaffold_oid (@scaffold_oids) {
		$options .= hiddenVar( 'scaffold_oid', $scaffold_oid );
	    }
	    if ( $set2scafs_href ) {
                foreach my $x (keys %$set2scafs_href) {
                    $options .= hiddenVar("input_file", $x);
                    my $scafs_ref = $set2scafs_href->{$x};
                    foreach my $scaf_oid (@$scafs_ref) {
                        $options .= hiddenVar($x, $scaf_oid);
                    }
                }
	    }
            $options .= hiddenVar("isSet", $isSet) if $isSet;
	}
    }

    # Show settings dialog if running for the first time
    my $popupVisibility = $maidenRun ? "true" : "false";

    my $json = new JSON;
    $json->pretty;
    my $kmerParamJSON = $json->encode(\%kmerParam);

    # replace markers in HTML template
    my $txclause = "";
    $txclause = "&taxon_oid=$taxon_oid" if $taxon_oid;
    $htmlStr =~ s/__base_url__/$base_url/g;
    $htmlStr =~ s/__main_cgi__/$section_cgi&page=$page$txclause/g;
    $htmlStr =~ s/__section__/$section/g;
    $htmlStr =~ s/__yui_url__/$YUI/g;
    $htmlStr =~ s/__popup_content__/$options/g;
    $htmlStr =~ s/__kmer_param_json__/$kmerParamJSON/g;
    $htmlStr =~ s/__popup_visibility__/$popupVisibility/g;

    print $htmlStr;
}

############################################################################
# printLocalStatus - Customized wrapper for printStatusLine
############################################################################
sub printLocalStatus {
    my ($msgText) = @_;
    printStatusLine("<font color='red'>$msgText " .
		    "This may take several minutes. " .
		    "Please wait ... </font>\n<img src=" .
		    "'$base_url/images/ajax-loader.gif'>")
}


############################################################################
# extractKmerSettings
############################################################################
sub extractKmerSettings {
    my ($outputPrefix) = @_;

    my ($junk, $fragmentWindow, $fragmentStep, $kmerSize, $minVariation)
        = split(/\-/, $outputPrefix);

    return ($fragmentWindow, $fragmentStep, $kmerSize, $minVariation);
}

############################################################################
# getKmerSettings
############################################################################
sub getKmerSettingDisplay {
    my ($outputPrefix) = @_;

    my ($fragmentWindow, $fragmentStep, $kmerSize, $minVariation)
        = extractKmerSettings($outputPrefix);
    my $text;
    $text .= "Fragment window: " . $fragmentWindow . " bp, ";
    $text .= "Fragment step: " . $fragmentStep . " bp, ";
    $text .= "Oligomer size: " . $kmerSize . ", ";
    $text .= "Minimum variation: " . $minVariation . " ";

    return $text;
}


1;
