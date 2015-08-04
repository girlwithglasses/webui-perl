############################################################################
# Utility functions to support to generate GenBank/EMBL file.
#
# $Id: GenerateArtemisFile.pm 33888 2015-08-04 00:35:03Z aireland $
############################################################################
package GenerateArtemisFile;

use strict;
use warnings;
use feature ':5.16';
our (@ISA, @EXPORT);

BEGIN {
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();
}

use CGI qw( :standard );
use DBI;
use Cwd;
use File::Path;
use File::Copy;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use threads;
use WebConfig;
use WebUtil;
use MailUtil;
use FileHandle;
use File::Path qw(make_path);

# Force flush
$| = 1;

my $env               = getEnv();
my $main_cgi          = $env->{main_cgi};
my $base_url          = $env->{base_url};
my $base_dir          = $env->{base_dir};
my $cgi_dir           = $env->{cgi_dir};
my $tmp_url           = $env->{tmp_url};
my $tmp_dir           = $env->{tmp_dir};
my $cgi_tmp_dir       = $env->{cgi_tmp_dir};
my $artemis_url       = $env->{artemis_url};
my $artemis_link      = alink( $artemis_url, "Artemis" );
my $include_img_terms = $env->{include_img_terms};
my $verbose           = $env->{verbose};
my $img_internal      = $env->{img_internal};

my $default_timeout_mins = $env->{default_timeout_mins} // 5;
#$default_timeout_mins = 5 if $default_timeout_mins eq "";

my $max_export_scaffold_list = 100000;
my $max_artemis_scaffolds    = 10000;
my $artemis_scaffolds_switch = 100;

my $max_artemis_genes    = 10000;
my $artemis_genes_switch = 1000;

my $ifs_tmp_dir        = $env->{ifs_tmp_dir};
my $public_artemis_dir = "$ifs_tmp_dir";
my $public_artemis_url = "$tmp_url/public";     # see WebUtil $ifs_tmp_dir

# user's sub folder names
my $GENE_FOLDER   = "gene";
my $FUNC_FOLDER   = "function";
my $SCAF_FOLDER   = "scaffold";
my $GENOME_FOLDER = "genome";

sub dispatch {
    my $page = param('page');
    if ( $page eq 'processArtemisFile2' ) {
        $default_timeout_mins = 120; # 2 hours
        timeout( 60 * $default_timeout_mins );
        #timeout(0);    # turn off timeout
        processArtemisFile2();
    }
}

#
# Kostas script to create ncbi genbank files for submission
#
sub processArtemisFile2 {
    my $taxon_oid = param('taxon_oid');
    my $myEmail   = param("myEmail");
    $myEmail =~ s/\r//g;
    $myEmail =~ s/^\s+//;
    $myEmail =~ s/\s+$//;

    webError("Invalid email address $myEmail\n") if ( ! MailUtil::validateEMail($myEmail) );
    #print "processArtemisFile2() taxon_oid=$taxon_oid, myEmail: $myEmail<br/>\n";

    # untaint
    if ( $taxon_oid   =~ /^(.*)$/ ) { $taxon_oid   = $1; }
    if ( $cgi_tmp_dir =~ /^(.*)$/ ) { $cgi_tmp_dir = $1; }

    my $user = getUserName();
    $user = 'public' if ( $user eq "" );

    # BUG if user name is a an email address replace @ with _
    # and other special chars
    $user =~ s/\W/_/g; # any non word char The same as [^a-zA-Z0-9_]
    $user =~ s/\s/_/g; # any whitespace


    my $outDir = "$public_artemis_dir/$user/$$/$taxon_oid";
    my $url    = "$public_artemis_url/$user/$$/$taxon_oid";

    if (1) {
        WebUtil::dbLogoutImg();
        WebUtil::dbLogoutGold();

        # is the genome a metagenome
        printProcessSubmittedMessage();

        my $tmp = printWindowStop();
        main::printMainFooter( "", $tmp );

        my $t = threads->new( \&threadjob2, $myEmail, $taxon_oid, $user, $outDir, $url );
        $t->join;

    } else {
        # testing - realtime

        printStartWorkingDiv();

        # TODO - add real user name and unique directory
        #
        my $cmd = "$cgi_dir/bin/Genbank/prepareSubmission.pl -t $taxon_oid -d $outDir -u $user -r";
        if($user eq 'public') {
            $cmd = "$cgi_dir/bin/Genbank/prepareSubmission.pl -t $taxon_oid -d $outDir -r";
        }
        runCmd($cmd);
        $cmd = "$cgi_dir/bin/Genbank/linux.tbl2asn -a s -p $outDir -Vvb";
        runCmd2( "$cmd");

        printEndWorkingDiv();

        my @files = dirList("$outDir");
        foreach my $file (@files) {
            print "<a href='$url/$file'> $url/$file </a> <br/>\n";
        }
    }
}

sub threadjob2 {
    my ( $myEmail, $taxon_oid, $user, $outDir, $url ) = @_;

    eval {
        if (! -e $outDir) {
            umask 0022;
            make_path( $outDir, { mode => 0755 } );
        }
        my $cmd = "$cgi_dir/bin/Genbank/prepareSubmission.pl -t $taxon_oid -d $outDir -u $user -r";
        if ($user eq 'public') {
            $cmd = $cmd = "$cgi_dir/bin/Genbank/prepareSubmission.pl -t $taxon_oid -d $outDir -r";
        }
        runCmd2($cmd);
        $cmd = "$cgi_dir/bin/Genbank/linux.tbl2asn -a s -p $outDir -Vvb";
        runCmd2("$cmd");

        my $gzip = '/bin/gzip';

        my $tmp;
        my @files = dirList("$outDir");
        chdir $outDir;
        foreach my $file (@files) {
            # gzip files
            if ($file =~ /^(.*)$/) { $file = $1; } # untaint
            runCmd("$gzip $file");

            $tmp .= "   - $url/$file" . ".gz\n";
        }
        #webLog("threadjob2() outDir=$outDir, url=$url, tmp=$tmp\n");

        my $subject = "NCBI submission file for Genome $taxon_oid done";
        my $content = getDoNotReplyMailContent($url, $tmp);
        sendMail( $myEmail, '', $subject, $content );

    };
    if ($@) {
        my $monitor = "imgsupp\@lists.jgi-psf.org";
        my $subject = "NCBI filed for submission processing failed.";
        my $content = "Genome $taxon_oid failed reason ==> $@ \n";
        sendMail( $myEmail, $monitor, $subject, $content );
    }
}

sub runCmd2 {
    my ( $cmd, $v ) = @_;

    $v = 1 if($img_internal);

    webLog("Status: Running $cmd<br/>\n");

    #print "Status: Running $cmd<br/>\n" if $v;

    # a better untaint to system exec
    #  http://www.boards.ie/vbulletin/showthread.php?p=55944778
    $ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
    delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

    my $cfh;
    #if ($v) {
    #    $cfh = new FileHandle("$cmd 2>\&1 |");
    #} else {

        # manually set the ENV for threads
        # see http://perldoc.perl.org/threads.html#BUGS-AND-LIMITATIONS on ENV
        #
        $cfh = new FileHandle("PATH=/bin:/usr/bin:/usr/local/bin; IFS=''; CDPATH=''; ENV=''; BASH_ENV=''; $cmd 2>\&1 |");
    #}

    if ( !$cfh ) {
        webLog("Failure: runCmd2 $cmd<br/>\n");
        #print "Failure: runCmd2 $cmd<br/>\n" if $v;
        WebUtil::webExit(-1);
    }

    while ( my $s = $cfh->getline() ) {
        chomp $s;
        webLog("Status: $s<br/>\n");
        #print "Status: $s<br/>\n" if $v;
    }

    $cfh->close();
}

############################################################################
# printGenerateForm - Print form for generating GenBank file.
############################################################################
sub printGenerateForm {
    my ( $dbh, $sql, $taxon_oid, $bin_oid, $scaffold_oids_ref, $scaffold_count, $fromMetagenome ) = @_;

    my $contact_oid = getContactOid();

    my $title = "Genbank File";
    $title = "Genbank/EMBL File" if ($fromMetagenome);

    print "<h1>Generate $title</h1>\n";
    print "<p>\n";
    print qq{
        This tool was provided to you as an aid.
        <b>We do not guarantee the output is a valid Genbank format.</b><br/>
        You still need to spend extra effort to make the Genbank file accepted by NCBI.
        And we will no longer support this tool,
        <a href='https://groups.google.com/a/lbl.gov/d/msg/img-user-forum/X9wVMGy7gh4/eC27DnjAMnsJ'> why?</a>
        <p>
    };
    print "You may generate a custom $title ";
    print "for one or more scaffolds.<br/>";
    print "Your MyIMG gene annotation may override ";
    print "the default product name.<br/>\n";
    print "(You must be logged into MyIMG to use your annotations.)<br/>\n";
    if ($fromMetagenome) {
        print "If exactly one IMG term is associated with a gene, ";
    } else {
        print "If an IMG term is associated with a gene, ";
    }
    print "this can also override the product name.<br/>\n";
    print "IMG term, if present and the override option selected, ";
    print "also overrides MyIMG annotation.<br/>\n";
    #print "The file is viewable by a recent version of $artemis_link.<br/>\n";
    print "</p>\n";

    print qq{
        <script language='JavaScript' type='text/javascript' src='$base_url/validation.js'>
        </script>
        <script type="text/javascript">
            //validateOnSubmit for Artemis Form
            function validateOnSubmitForArtemis(switchLimit, maxLimit) {
                var selectedCount = 0

                var formObj = document.mainForm;
                var selectObj = formObj.elements['scaffold_oid'];
                if(selectObj.options.length > 1 && selectObj.options[0].selected) {
                    selectedCount = selectObj.options.length - 1;
                }
                else {
                    for(j = 0; j < selectObj.options.length; j++) {
                        if(selectObj.options[j].selected) {
                            selectedCount++;
                        }
                    }
                }

                if (selectedCount == 0) {
                    window.alert("Please select at least one scaffold.");
                    return false;
                }
                if (selectedCount > maxLimit) {
                    window.alert("Please select at most " + maxLimit + " scaffolds.");
                    return false;
                }
                if (selectedCount > switchLimit) {
                    var emailStr;
                    if ( switchLimit == 0 ) {
                        emailStr = document.mainForm2.elements['myEmail'].value;
                    }
                    else {
                        emailStr = formObj.elements['myEmail'].value;
                    }
                    if (emailStr == null || emailStr.length < 1) {
                        if ( switchLimit == 0 ) {
                            window.alert("Please enter your email.");
                        }
                        else {
                            window.alert("Please enter your email since you have selected over " + switchLimit + " entries.");
                        }
                        return false;
                    }
                    if ( !(testEmail(emailStr)) ) {
                        window.alert("Please enter a valid email address.");
                        return false;
                   }
                }
                return true;
            }
        </script>
    };

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    if ( $taxon_oid ) {
        print hiddenVar( "taxon_oid", $taxon_oid );
    } elsif ( $bin_oid ) {
        print hiddenVar( "bin_oid", $bin_oid );
    } elsif ( $scaffold_oids_ref && scalar(@$scaffold_oids_ref) > 0 ) {
        #send all scaffold oid as hidden param
        #print "\$scaffold_oids_ref: $scaffold_oids_ref";
        for my $s1 (@$scaffold_oids_ref) {
            print hiddenVar( "scaffold_all", $s1 );
        }
    }

    print "<table class='img' border='1'>\n";

    ## Scaffold selection
    print "<tr class='img'>\n";
    print "<th class='subhead'>Scaffold</th>\n";
    print "<td class='img'>\n";

    print "<select name='scaffold_oid' size='10' multiple >\n";
    my $x;
    $x = " - can take a long time to run" if $scaffold_count > $artemis_scaffolds_switch;
    print "<option value='all'>" . "(All $scaffold_count scaffolds$x)</option>"
      if $scaffold_count > 1;

    my $bind = '';
    if ( $bin_oid ) {
        $bind = $bin_oid;
    } elsif ( $taxon_oid ) {
        $bind = $taxon_oid;
    }

    my $cur;
    if ( $bind ) {
        $cur = execSql( $dbh, $sql, $verbose, $bind );
    }
    else {
        $cur = execSql( $dbh, $sql, $verbose );
    }

    my $count = 0;
    my $trunc = 0;
    for ( ; ; ) {
        my ( $scaffold_oid, $ext_accession, $scaffold_name, $seq_length ) = $cur->fetchrow();
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

    ## MyIMGannotation
    print "<tr class='img'>\n";
    print "<th class='subhead'>MyIMG Annotation</th>\n";
    print "<td class='img'>\n";
    if ( $contact_oid > 0 ) {
        print "<input type='checkbox' name='myImgOverride' />";
        print "Override using MyIMG annotations, if present.";
    } else {
        print "(You are not logged in to use MyIMG annotations.)";
    }
    print "</td>\n";

    ## IMG Term
    if ($include_img_terms) {
        print "<tr class='img'>\n";
        print "<th class='subhead'>IMG Term</th>\n";
        print "<td class='img'>\n";
        print "<input type='checkbox' name='imgTermOverride' />";
        if ($fromMetagenome) {
            print "Override product name with IMG term, if there is exactly one IMG term.";
        } else {
            print "Override product name with IMG term.";
        }
        print "</td>\n";
        print "</tr>\n";
    }

    if ($fromMetagenome) {
        ## Format
        print "<tr class='img'>\n";
        print "<th class='subhead'>Output Format</th>\n";
        print "<td class='img'>\n";
        print "<input type='radio' name='format' value='gbk' checked />Genbank";
        print nbsp(1);
        print "<input type='radio' name='format' value='embl' />EMBL";
        print "</td>\n";
    } else {
        ## Gene Object ID
        print "<tr class='img'>\n";
        print "<th class='subhead'>Gene ID</th>\n";
        print "<td class='img'>\n";
        print "<input type='checkbox' name='gene_oid_note' />";
        print "Include IMG Gene ID in note field.";
        print "</td>\n";
        print "</tr>\n";

        ## Misc. Gene Features
        print "<tr class='img'>\n";
        print "<th class='subhead'>Misc. Gene Features</th>\n";
        print "<td class='img'>\n";
        print "<input type='checkbox' name='misc_features' />";
        print "Include miscellaneous gene features.";
        print "</td>\n";
        print "</tr>\n";

        ## include my missing gene?
        if ( $contact_oid > 0 && WebUtil::tableExists('MYGENE') ) {
            print "<tr class='img'>\n";
            print "<th class='subhead'>My Missing Genes</th>\n";
            print "<td class='img'>\n";
            print "<input type='checkbox' name='mygeneOverride' />";
            print "Include my missing genes in the output.";
            print "</td>\n";
            print "</tr>\n";
        }

        ## Format
        print hiddenVar( "format", "gbk" );
    }

    ## enter email address
    if ( $scaffold_count > $artemis_scaffolds_switch ) {
        my $myEmail = getMyEmail($dbh, $contact_oid);
        print "<tr class='img'>\n";
        print "<th class='subhead'>My Email</th>\n";
        print "<td class='img'>\n";
        print "<input type='email' name='myEmail' value='$myEmail' style='min-width:281px' />";
        print "<br/>(Results will be mailed to you if selection over $artemis_scaffolds_switch)";
        print "</td>\n";
        print "</tr>\n";
    }

    print "</table>\n";
    if ($trunc) {
        print "<p>\n";
        print "<font color='red'>\n";
        print escHtml( "Scaffold list truncated to " . "$max_export_scaffold_list scaffolds." ) . "<br/>\n";
        print "</font>\n";
        print "</p>\n";
    }

    print hiddenVar( "taxon_oid", $taxon_oid );

    print "<br/>\n";
    my $name = "_section_TaxonDetail_processArtemisFile";
    print submit(
          -name    => $name,
          -value   => "Go",
          -class   => "smdefbutton",
          -onclick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button genbank $name']); return validateOnSubmitForArtemis($artemis_scaffolds_switch, $max_artemis_scaffolds)"
    );
    print nbsp(1);
    print reset( -value => "Reset", -class => "smbutton" );

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    printHint(   "Hold down control key (or command key in the case "
               . "of the Mac)<br/>to select or deselect multiple values.  "
               . "Drag down the list to select many items.<br/>" );
    print end_form();

    if ( $taxon_oid ) {
        print qq{
            <br/><br/>
            <h2>Create files for submission to Genbank</h2>
            <form name="mainForm2" enctype="multipart/form-data" action="main.cgi" method="post">
        };

        print hiddenVar( "taxon_oid", $taxon_oid );
        print hiddenVar( "section",   'GenerateArtemisFile' );
        print hiddenVar( "page",      'processArtemisFile2' );

        my $myEmail = getMyEmail($dbh, $contact_oid);
        print "<table class='img' border='1'>\n";
        print "<tr class='img'>\n";
        print "<th class='subhead'>My Email</th>\n";
        print "<td class='img'>\n";
        print "<input type='email' name='myEmail' value='$myEmail' style='min-width:281px' />";
        print "&nbsp; (Results will be mailed to you)";
        print "</td>\n";
        print "</tr>\n";
        print "</table>\n";

        my $name = "_section_GenerateArtemisFile_processArtemisFile2";
        print submit(
              -name  => $name,
              -value => "Go",
              -class => "smdefbutton",
              -onclick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button genbank emailed $name']); return validateOnSubmitForArtemis(0, $max_artemis_scaffolds)"
        );

        print end_form();
    }
}

sub getMyEmail {
    my ( $dbh, $contact_oid ) = @_;

    my $myEmail;
    if ( $contact_oid > 0 ) {
        my $sql = qq{
           select email
           from contact
           where contact_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
        $myEmail = $cur->fetchrow();
        $cur->finish();
    }

    return $myEmail;
}

############################################################################
# printProcessArtemisFile - Process generating an Artemis file,
#   which now is synonymous with generating an output for Genbank
#   or EMBL format.
############################################################################
sub processArtemisFile {

    my $myEmail = param("myEmail");
    $myEmail =~ s/\r//g;
    $myEmail =~ s/^\s+//;
    $myEmail =~ s/\s+$//;
    #print "processArtemisFile() myEmail: $myEmail<br/>\n";

    my $format          = param("format");
    my $myImgOverride   = param("myImgOverride");
    my $imgTermOverride = param("imgTermOverride");
    my $mygeneOverride  = param("mygeneOverride");
    my $gene_oid_note   = param("gene_oid_note");
    my $misc_features   = param("misc_features");
    my $taxon_oid       = param("taxon_oid");
    my $bin_oid         = param("bin_oid");
    my @scaffold_all    = param("scaffold_all");
    my @scaffold_oids   = param("scaffold_oid");

    timeout(0);    # turn off timeout

    if ( $scaffold_oids[0] eq "all" ) {
        my $dbh = dbLogin();
        my $rclause = WebUtil::urClause('s.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');

        @scaffold_oids = ();
        my $cur;
        if ( $taxon_oid > 0 ) {
            my $sql = qq{
                select s.scaffold_oid
                from scaffold s
                where s.taxon = ?
                $rclause
                $imgClause
            };
            $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        } elsif ( $bin_oid > 0 ) {
            my $sql = qq{
                select s.scaffold
                from bin_scaffolds s
                where s.bin_oid = ?
                $rclause
                $imgClause
            };
            $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
        } elsif ( scalar(@scaffold_all) > 0 ) {
            @scaffold_oids = @scaffold_all;
        }
        if ( $cur ne '' ) {
            for ( ; ; ) {
                my ($scaffold_oid) = $cur->fetchrow();
                last if !$scaffold_oid;
                push( @scaffold_oids, $scaffold_oid );
            }
        }
        #$dbh->disconnect();
    }

    my $nScaffolds = scalar(@scaffold_oids);
    #print "\$nScaffolds: $nScaffolds<br/>\n";
    if ( $nScaffolds == 0 ) {
        webError("Please select at least one scaffold.\n");
    }
    if ( $nScaffolds > $max_artemis_scaffolds ) {
        webError( "Please select at most " + $max_artemis_scaffolds + " scaffolds." );
    }
    if ( $nScaffolds > $artemis_scaffolds_switch ) {
        webError("Please enter your email address since you have selected over $artemis_scaffolds_switch entries.")
          if ( blankStr($myEmail) );
        webError("Invalid email address $myEmail\n") if ( !MailUtil::validateEMail($myEmail) );
    }

    my $title;
    my $ext;
    if ( $format eq "embl" ) {
        $title = "Generate EMBL File";
        $ext   = "embl";
        require EmblFile;
    } else {
        $title = "Generate Genbank File";
        $ext   = "gbk";
        require GenBankFile;
    }
    print "<h1>$title</h1>\n";

    my $outDir      = WebUtil::getGenerateDir();
    my $outFileName = "$$.$ext";
    my $outFile     = "$outDir/$outFileName";
    #print "processArtemisFile() outFile=$outFile<br/>\n";
    webLog("processArtemisFile() write '$outFile'\n") if $verbose >= 1;
    wunlink($outFile);

    if ( $nScaffolds > $artemis_scaffolds_switch ) {
        printProcessSubmittedMessage("$nScaffolds scaffolds");

        my $tmp = printWindowStop();
        main::printMainFooter( "", $tmp );

        # I need to disconnect parent thread before child use db connection because it cannot be shared between
        # connections - ken
        WebUtil::dbLogoutImg();
        WebUtil::dbLogoutGold();

        my $t = threads->new(
              \&threadjob,     $format,        $title,         $outFile,         $outFileName,
              $outDir,         $myEmail,       $myImgOverride, $imgTermOverride, $gene_oid_note,
              $mygeneOverride, $misc_features, \@scaffold_oids
        );
        $t->join;

    } else {
        printHint( "Results will be viewable at the bottom of the page after processing is done." );

        printMainForm();
        printStatusLine( "Loading ...", 1 );

        writeArtemisFile( $format,         $outFile,       $myImgOverride,  $imgTermOverride, $gene_oid_note,
                          $mygeneOverride, $misc_features, \@scaffold_oids, 0 );

        printStatusLine( "Loaded.", 2 );

        print hiddenVar( "pid",  $$ );
        print hiddenVar( "type", $format );
        my $contact_oid = WebUtil::getContactOid();
        print submit(
                      -name  => "_section_TaxonDetail_viewArtemisFile_noHeader",
                      -value => "View Results",
                      -class => "meddefbutton",
                      -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button _section_TaxonDetail_viewArtemisFile_noHeader']);"
        );
        print nbsp(1);
        print submit(
                      -name  => "_section_TaxonDetail_downloadArtemisFile_noHeader",
                      -value => "Download File",
                      -class => "medbutton",
                      -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button _section_TaxonDetail_downloadArtemisFile_noHeader']);"
        );

        print "<br/>\n";
        printHint("The downloaded file is viewable by $artemis_link.");
        print end_form();
    }

    timeout( 60 * $default_timeout_mins );    # restore default

}

sub writeArtemisFile {
    my (
         $format,         $outFile,       $myImgOverride,     $imgTermOverride, $gene_oid_note,
         $mygeneOverride, $misc_features, $scaffold_oids_ref, $notPrint
      )
      = @_;

    my $nScaffolds = scalar(@$scaffold_oids_ref);
    print "Processing $nScaffolds scaffolds ...<br/>\n" if ( !$notPrint );

    my $count = 0;
    for my $scaffold_oid (@$scaffold_oids_ref) {
        $count++;
        if ( $format eq "embl" ) {
            EmblFile::writeScaffold2EmblFile(
                $scaffold_oid,    $outFile,       $myImgOverride,
                $imgTermOverride, $gene_oid_note, $notPrint
            );
        } else {
            GenBankFile::writeScaffold2GenBankFile(
                $scaffold_oid,    $outFile,       $myImgOverride,
                $imgTermOverride, $gene_oid_note, 0,
                $mygeneOverride,  $misc_features, $notPrint
            );
        }
        print "Scaffold $count / $nScaffolds done.<br/>\n" if ( !$notPrint );
        webLog("Scaffold $count / $nScaffolds done.<br/>\n");
    }
}

sub threadjob {
    my (
         $format,        $title,           $outFile,       $outFileName,    $outDir,        $myEmail,
         $myImgOverride, $imgTermOverride, $gene_oid_note, $mygeneOverride, $misc_features, $scaffold_oids_ref
      )
      = @_;

    my $nScaffolds = scalar(@$scaffold_oids_ref);

    eval {
        writeArtemisFile( $format,         $outFile,       $myImgOverride,     $imgTermOverride, $gene_oid_note,
                          $mygeneOverride, $misc_features, $scaffold_oids_ref, 1 );

        my ( $zippedFilePath, $zippedFileName, $zippedFileUrl ) = compressArtemisFile( $outFile, $outFileName, $outDir );
        #webLog("threadjob() zippedFilePath=$zippedFilePath, zippedFileName=$zippedFileName, zippedFileUrl=$zippedFileUrl\n");

        my $subject = "$title done for the $nScaffolds scaffolds";
        my $content = getDoNotReplyMailContent($zippedFileUrl);
        sendMail( $myEmail, '', $subject, $content );
    };
    if ($@) {
        my $monitor = "jinghuahuang\@lbl.gov";

        my $subject = "Artemis processing failed for your $nScaffolds scaffolds.";
        my $content = "failed reason ==> $@ \n";
        sendMail( $myEmail, $monitor, $subject, $content );

        $subject = "Artemis processing thread failed for $nScaffolds scaffolds.";
        $content = "failed reason ==> $@ \n";
        $content .= "format: $format\n";
        $content .= "title: $title\n";
        $content .= "outFile: $outFile\n";
        $content .= "outFileName: $outFileName\n";
        $content .= "myEmail: $myEmail\n";
        $content .= "myImgOverride: $myImgOverride\n";
        $content .= "imgTermOverride: $imgTermOverride\n";
        $content .= "gene_oid_note: $gene_oid_note\n";
        $content .= "mygeneOverride: $mygeneOverride\n";
        $content .= "misc_features: $misc_features\n";
        $content .= "scaffold_oids: @$scaffold_oids_ref\n";
        sendMail( '', $monitor, $subject, $content );
    }

}

sub compressArtemisFile {
    my ( $outFilePath, $outFileName, $outDir ) = @_;

    my ( $fileName, $ext ) = split( /\./, $outFileName );
    my $id             = getSessionId();
    my $zippedFileName = "$fileName" . "-" . $id . ".zip";
    my $zippedFilePath = "$public_artemis_dir/$zippedFileName";
    my $zippedFileUrl  = "$public_artemis_url/$zippedFileName";

    unless ( -d $public_artemis_dir ) {
        File::Path::mkpath($public_artemis_dir) || die("Cannot make directory '$public_artemis_dir'\n");
        chmod( 0777, $public_artemis_dir );
    }
    if ( -d $public_artemis_dir ) {
        my $ae = Archive::Zip->new();
        $ae->addFile( $outFilePath, $outFileName );
        $ae->writeToFileNamed($zippedFilePath) == AZ_OK or die "Can't compress: $outFilePath";
        chmod( 0777, $zippedFilePath );
    }

    return ( $zippedFilePath, $zippedFileName, $zippedFileUrl );
}

sub sendMail {
    my ( $emailTo, $ccTo, $subject, $content, $filePath, $file ) = @_;

    if ( $filePath ne '' ) {
        MailUtil::sendMailAttachment( $emailTo, $ccTo, $subject, $content, $filePath, $file );
    } else {
        MailUtil::sendMail( $emailTo, $ccTo, $subject, $content );
    }
    webLog("Mail sent to $emailTo for $subject<br/>\n");
}

sub printWindowStop {
    my $str = qq{
        <script language="javascript" type="text/javascript">
            window.stop();
        </script>
    };
    return $str;
}


############################################################################
# processFastaFile - Process generating a gene or scaffold fasta file
############################################################################
sub processFastaFile {
    my ($oids_ref, $isAA, $isFromWorkspace, $folder) = @_;

    my $myEmail = param("myEmail");
    $myEmail =~ s/\r//g;
    $myEmail =~ s/^\s+//;
    $myEmail =~ s/\s+$//;
    #print "\$myEmail: $myEmail<br/>\n";

    my $folderTxt = $folder.'s';
    my $switchNum = getSwitchNumber($folder);

    my $nOids = scalar(@$oids_ref);
    if ( $nOids > $switchNum ) {
        if ($isFromWorkspace) {
            main::printAppHeader("AnaCart");
        }

        webError("Please enter your email address since you have selected over $switchNum entries.")
          if ( blankStr($myEmail) );
        webError("Invalid email address $myEmail\n") if ( !MailUtil::validateEMail($myEmail) );

        my $title;
        my $ext;
        my $what = ucfirst( lc($folder) );
        if ($isAA == 1) {
            $title = "Export $what Fasta Amino Acid Sequence";
            $ext = "faa";
        }
        else {
            $title = "Export $what Fasta Nucleic Acid Sequence";
            $ext = "fna";
        }
        print "<h1>$title</h1>\n";
        my $outDir      = WebUtil::getGenerateDir();
        my $outFileName = "$$.$ext";
        my $outFile     = "$outDir/$$.$ext";

        #print "processFastaFile() outFile: $outFile, tmp_dir: $tmp_dir, public_artemis_dir: $public_artemis_dir<br/>\n";
        webLog("processFastaFile() write '$outFile'\n") if $verbose >= 1;
        wunlink($outFile);

        printProcessSubmittedMessage("$nOids $folderTxt");

        my $tmp = printWindowStop();
        main::printMainFooter( "", $tmp );

        WebUtil::dbLogoutImg();
        WebUtil::dbLogoutGold();

        my $t = threads->new(
            \&threadjob_fasta, $title, $outFile, $outFileName, $outDir, $myEmail,
            $oids_ref, $isAA, $isFromWorkspace, $folder
        );
        $t->join;

    }
    else {
        if ($isFromWorkspace) {
            print "Content-type: text/plain\n";
            print "Content-Disposition: inline;filename=exportFasta\n";
            print "\n";

            if ( $folder eq $GENE_FOLDER ) {
                if ($isAA == 1) {
                    SequenceExportUtil::printGeneFaaSeqWorkspace($oids_ref);
                }
                else {
                    SequenceExportUtil::printGeneFnaSeqWorkspace($oids_ref);
                }
            }
            elsif ( $folder eq $SCAF_FOLDER ) {
                SequenceExportUtil::printScaffoldFastaDnaFile($oids_ref);
            }

            WebUtil::webExit(0);
        }
        else {
            if ($isAA == 1) {
                SequenceExportUtil::printGeneFaaSeq($oids_ref);
            }
            else {
                SequenceExportUtil::printGeneFnaSeq($oids_ref);
            }
        }
    }

}


sub threadjob_fasta {
    my ($title, $outFile, $outFileName, $outDir, $myEmail, $oids_ref, $isAA, $isFromWorkspace, $folder)
      = @_;

    webLog("threadjob_fasta() into threadjob_fasta: ". currDateTime() ."\n");

    my $nOids = scalar(@$oids_ref);
    my $folderTxt = $folder.'s';
    my $fromWorkspaceText = '';
    if ($isFromWorkspace) {
        $fromWorkspaceText = 'from workspace';
    }

    eval {
        if ( $folder eq $GENE_FOLDER ) {
            if ($isFromWorkspace == 1) {
                if ($isAA == 1) {
                    SequenceExportUtil::printGeneFaaSeqWorkspace_toEmail($oids_ref, $outFile);
                }
                else {
                    SequenceExportUtil::printGeneFnaSeqWorkspace_toEmail($oids_ref, $outFile);
                }
            }
            else {
                if ($isAA == 1) {
                    SequenceExportUtil::printGeneFaaSeq($oids_ref, $outFile);
                }
                else {
                    SequenceExportUtil::printGeneFnaSeq($oids_ref, $outFile);
                }
            }
        }
        elsif ( $folder eq $SCAF_FOLDER ) {
            if ($isFromWorkspace == 1) {
                SequenceExportUtil::printScaffoldFastaDnaFile($oids_ref, $outFile);
            }
        }

        my ( $zippedFilePath, $zippedFileName, $zippedFileUrl ) = compressArtemisFile( $outFile, $outFileName, $outDir );

        my $subject = "$title done for the $nOids $folderTxt $fromWorkspaceText";
        my $content = getDoNotReplyMailContent($zippedFileUrl);
        sendMail( $myEmail, '', $subject, $content );
    };
    if ($@) {
        my $monitor = "jinghuahuang\@lbl.gov";

        my $subject = "Artemis processing failed for your $nOids $folderTxt $fromWorkspaceText";
        my $content = "failed reason ==> $@ \n";
        sendMail( $myEmail, $monitor, $subject, $content );

        $subject = "Client Artemis processing thread failed for $nOids $folderTxt $fromWorkspaceText";
        $content = "failed reason ==> $@ \n";
        $content .= "title: $title\n";
        $content .= "outFile: $outFile\n";
        $content .= "outFileName: $outFileName\n";
        $content .= "myEmail: $myEmail\n";
        $content .= "oids: " . @$oids_ref. "\n";
        sendMail( '', $monitor, $subject, $content );
    }

}

############################################################################
# prepareProcessGeneFastaFile - Process generating a gene fasta file
# from gene cart table
############################################################################
sub prepareProcessGeneFastaFile {
    my ($isAA) = @_;

    my @gene_oids = param("gene_oid");

    if ( scalar(@gene_oids) == 0) {
        webError("Select genes to export first.");
    }

    processFastaFile(\@gene_oids, $isAA, 0, $GENE_FOLDER);
}

sub prepareProcessGeneAAFastaFile {
	return prepareProcessGeneFastaFile( 1 );
}

sub printProcessSubmittedMessage {
    my ($content) = @_;

    my $fromEmail = $env->{img_support_email};
    my $text = qq{
        Your request to process $content has been successfully submitted.
        You will be notified via email from <b>$fromEmail</b>. <br/>
        with a URL to the result. The URL will be valid for <b>only 24 hours</b>.
    };
    printMessage($text);

}

sub getDoNotReplyMailContent {
    my ($url, $tmp) = @_;

    my $content = qq{
        This is an automatically generated email. DO NOT reply.
        Use links below to download your results. (The URL will be valid for <b>only 24 hours</b>)

        Files:
        $url
        $tmp

        It is best to have the IMG web page open first.
        $base_url
        before downloading files.
    };

    return $content;

}

sub printDataExportHint {
    my ($folder) = @_;

    my $folderTxt = $folder.'s';
    my $switchNum = getSwitchNumber($folder);

    printHint("Export large number of $folderTxt will be very slow. "
        . "<br/>You will be notified for the result via email if exporting over $switchNum $folderTxt.");

}

sub printEmailInputTable {
    my ($sid, $folder) = @_;

    my $folderTxt = $folder.'s';
    my $switchNum = getSwitchNumber($folder);

    ## enter email address
    my $myEmail = '';
    if (!$sid) {
        $sid = getContactOid();
    }
    if ( $sid > 0 ) {
        my $dbh = dbLogin();
        my $sql = qq{
           select email
           from contact
           where contact_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $sid );
        $myEmail = $cur->fetchrow();
        $cur->finish();
        #$dbh->disconnect();
    }

    print "<table class='img' border='1'>\n";
    print "<tr class='img'>\n";
    print "<th class='subhead'>My Email</th>\n";
    print "<td class='img'>\n";
    print "<input type='email' name='myEmail' value='$myEmail' style='min-width:281px' />";
    print "<br/>( Results will be mailed to you if selection is over $switchNum $folderTxt. )";
    print "</td>\n";
    print "</tr>\n";
    print "</table>\n";

}

sub getSwitchNumber {
    my ($folder) = @_;

    my $switchNum;
    if ( $folder eq $GENE_FOLDER ) {
        $switchNum = $artemis_genes_switch;
    }
    elsif ( $folder eq $SCAF_FOLDER ) {
        $switchNum = $artemis_scaffolds_switch;
    }

    return $switchNum;
}

############################################################################
# processDataFile - Process generating a gene or scaffold data file
############################################################################
sub processDataFile {
    my ($oids_ref, $isFromWorkspace, $folder) = @_;

    my $myEmail = param("myEmail");
    $myEmail =~ s/\r//g;
    $myEmail =~ s/^\s+//;
    $myEmail =~ s/\s+$//;
    #print "\$myEmail: $myEmail<br/>\n";

    my $folderTxt = $folder.'s';
    my $switchNum = getSwitchNumber($folder);

    my $nOids = scalar(@$oids_ref);
    if ( $nOids > $switchNum ) {
        if ($isFromWorkspace) {
            main::printAppHeader("AnaCart");
        }

        webError("Please enter your email address since you have selected over $switchNum entries.")
          if ( blankStr($myEmail) );
        webError("Invalid email address $myEmail\n") if ( !MailUtil::validateEMail($myEmail) );

        my $title;
        my $ext;
        my $what = ucfirst( lc($folder) );
        $title = "Export $what Data";
        $ext = "xls";
        print "<h1>$title</h1>\n";
        my $outDir      = WebUtil::getGenerateDir();
        my $outFileName = "$$.$ext";
        my $outFile     = "$outDir/$$.$ext";

        #print "processDataFile() outFile: $outFile, tmp_dir: $tmp_dir, public_artemis_dir: $public_artemis_dir<br/>\n";
        webLog("processDataFile() write '$outFile'\n") if $verbose >= 1;
        wunlink($outFile);

        printProcessSubmittedMessage("$nOids $folderTxt");

        my $tmp = printWindowStop();
        main::printMainFooter( "", $tmp );

        WebUtil::dbLogoutImg();
        WebUtil::dbLogoutGold();

        my $t = threads->new(
            \&threadjob_data, $title, $outFile, $outFileName, $outDir, $myEmail,
            $oids_ref, $isFromWorkspace, $folder
        );
        $t->join;

    }
    else {
        if ($isFromWorkspace) {
            # print Excel Header
            WebUtil::printExcelHeader($folder."_sets$$.xls");
            if ( $folder eq $GENE_FOLDER ) {
                #for future implementation
            }
            elsif ( $folder eq $SCAF_FOLDER ) {
                require ScaffoldCart;
                ScaffoldCart::printScaffoldDataFile($oids_ref);
            }

            WebUtil::webExit(0);
        }
        else {
            #for future implementation
        }
    }

}


sub threadjob_data {
    my ($title, $outFile, $outFileName, $outDir, $myEmail, $oids_ref, $isFromWorkspace, $folder)
      = @_;

    webLog("threadjob_data() into threadjob_data: before compress outFile=$outFile ". currDateTime() ."\n");

    my $nOids = scalar(@$oids_ref);
    my $folderTxt = $folder.'s';
    my $fromWorkspaceText = '';
    if ($isFromWorkspace) {
        $fromWorkspaceText = 'from workspace';
    }

    eval {
        if ( $folder eq $GENE_FOLDER ) {
            if ($isFromWorkspace == 1) {
                #for future implementation
            }
            else {
                #for future implementation
            }
        }
        elsif ( $folder eq $SCAF_FOLDER ) {
            if ($isFromWorkspace == 1) {
                require ScaffoldCart;
                ScaffoldCart::printScaffoldDataFile($oids_ref, $outFile);
            }
        }

        my ( $zippedFilePath, $zippedFileName, $zippedFileUrl ) = compressArtemisFile( $outFile, $outFileName, $outDir );

        my $subject = "$title done for the $nOids $folderTxt $fromWorkspaceText";
        my $content = getDoNotReplyMailContent($zippedFileUrl);
        sendMail( $myEmail, '', $subject, $content );
    };
    if ($@) {
        my $monitor = "jinghuahuang\@lbl.gov";

        my $subject = "Artemis processing failed for your $nOids $folderTxt $fromWorkspaceText";
        my $content = "failed reason ==> $@ \n";
        sendMail( $myEmail, $monitor, $subject, $content );

        $subject = "Client Artemis processing thread failed for $nOids $folderTxt $fromWorkspaceText";
        $content = "failed reason ==> $@ \n";
        $content .= "title: $title\n";
        $content .= "outFile: $outFile\n";
        $content .= "outFileName: $outFileName\n";
        $content .= "myEmail: $myEmail\n";
        $content .= "oids: " . @$oids_ref. "\n";
        sendMail( '', $monitor, $subject, $content );
    }

}



1;

