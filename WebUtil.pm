############################################################################
#   Misc. web utility functions.
# 	--es 04/15/2004
# $Id: WebUtil.pm 33902 2015-08-05 01:24:06Z jinghuahuang $
############################################################################
package WebUtil;

use warnings;
use strict;
use feature ':5.16';
our ( @ISA, @EXPORT );

BEGIN {
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw(
  abbrScaffoldName
  absCoord
  addIdPrefix
  addIntergenic
  addNxFeatures
  addRepeats
  alignImage
  alink
  alinkNoTarget
  alinkPad
  aNumLink
  appendFile
  array2Hash
  attrLabel
  attrValue
  binOid2Name
  binOid2TaxonOid
  blankStr
  blastProcCheck
  blockRobots
  bsearchFpos
  buttonUrl
  buttonUrlNewWindow
  canEditGeneTerm
  canEditPathway
  canEditBin
  catOid2Name
  checkAccess
  checkBlankVar
  checkEvalue
  checkGeneAvail
  checkGenePerm
  checkMysqlSearchTerm
  checkPath
  checkScaffoldPerm
  checkTaxonAvail
  checkTaxonPerm
  checkTaxonPermHeader
  checkTmpPath
  clearWorkingDiv
  cogCategoryName
  cogName
  cogPathwayName
  completionLetterNote
  completionLetterNoteParen
  conditionalFile2Str
  convertLatLong
  currDateTime
  dateSortVal
  dateTimeStr
  dbLogin
  decode
  dirList
  domainLetterNote
  domainLetterNoteNoV
  domainLetterNoteNoVNoM
  domainLetterNoteParen
  emailLink
  emailLinkParen
  encode
  enzymeName
  escHtml
  escapeQuote
  excelHeaderName
  execSql
  execSqlBind
  execSqlOnly
  execStmt
  extAccIdCount
  file2Str
  fileAtime
  fileRoot
  fileSize
  flushBrowser
  gcContent
  geneOid2AASeq
  geneOid2AASeqLength
  geneOid2GenomeType
  geneOid2Name
  geneOid2TaxonOid
  geneOidDirs
  geneOidMap
  geneOidsMap
  geneticCode
  genomeName
  getaa
  getAASeqLength
  getAASequence
  getAcgtCounts
  getAllTaxonsHashed
  getAnnotation
  getAvaTabAndFposFiles
  getBBHLiteRows
  getBBHZipRows
  getBinGeneCount
  getClusterHomologRows
  getClusterScaleMeanStdDev
  getContactOid
  getDateStr
  getDefaultBins
  getFileHomologs
  getFposLinear
  getGeneHitsRows
  getGeneHitsZipRows
  getGeneReplacementSql
  getGoogleMapsKey
  getHitsRows
  getHtmlBookmark
  getIdxHomologs
  getMyIMGPref
  getNextBatchId
  getNvl
  getOracleSortableDate
  getPhyloDomainCounts
  getRdbms
  getScaffold2BinNames
  getScaffoldSeq
  getSelectedTaxonCount
  getSelectedTaxonsHashed
  getSequence
  getSession
  getSessionId
  getSessionParam
  getSuperUser
  getSysDate
  getTaxonCount
  getTaxonFilterHash
  getTaxonGeneCount
  getTaxonOid4GeneOid
  getTaxonOidNames
  getTaxonRescale
  getUrOids
  getUserName
  getWrappedSequence
  hasDnaSequence
  hasHomolog
  hiddenVar
  highlightMatchHTML
  highlightMatchHTML2
  highlightMatchHTML_p12
  highlightMatchHTML3
  highlightRect
  highlightRectRgb
  histogramBar
  imgTerm2PartsList
  imgTerm2Pathways
  indexUnderscore
  isImgEditor
  isImgEditorWrap
  isInt
  isNumber
  isPangenome
  isParent
  isStartCodon
  isStopCodon
  joinSqlQuoted
  keggPathwayName
  lastPathTok
  loadFuncMap
  loadGeneOid2AltName4OidList
  locusTagCount
  lowerAttr
  massageToUrl
  maxCgiProcCheck
  nbsp
  nbspWrap
  newAppendFileHandle
  newCmdFileHandle
  newReadFileHandle
  newWriteFileHandle
  newUnzipFileHandle
  pageAnchor
  pageLink
  paramMatch
  paramCast
  parseBlastTab
  parseDNACoords
  pearsonCorr
  phyloSimMask
  prepSql
  printAddQueryGeneCheckBox
  printAttrRow
  printAttrRowRaw
  printCuraCartFooter
  printEndWorkingDiv
  printExcelHeader
  printFile
  printFuncCartFooter
  printGeneCartFooter
  printGenesToExcel
  printGeneTableExport
  printHeaderWithInfo
  printInfoTipLink
  printHiliteAttrRow
  printHint
  printHint2
  printMainForm
  printMessage
  printNoCache
  printOptAttrRow
  printPhyloSelectionList
  printPhyloSelectionListOld
  printStartWorkingDiv
  printStatusBox
  printStatusBoxUp
  printStatusLine
  printTaxonButtons
  printTruncatedStatus
  printWideHint
  printZnormNote
  processBindList
  processParamValue
  pwDecode
  readFasta
  readFileIndexed
  readMultiFasta
  printResetFormButton
  resetContactOid
  resetEnvPath
  runCmd
  runCmdNoExit
  sanitizeInt
  scaffoldOid2ExtAccession
  scaffoldOid2TaxonOid
  selectUrl
  setLinkTarget
  setSessionParam
  setTaxonSelections
  setWebLogOverride
  showFile
  showFileStderr
  sortByTaxonName
  splitTerm
  sqlInClause
  str2File
  strTrim
  taxonCategoryStrings
  taxonOid2Name
  taxonOidMap
  taxonOidsMap
  taxonReadsFasta
  termOid2Term
  timeout
  toolTipCode
  txsClause
  unsetEnvPath
  urClause
  urClauseBind
  urlGet
  validateGenePerms
  validEnvBlastDbs
  validOid
  webDie
  webError
  webErrorHeader
  webLog
  wrapSeq
  wsystem
  wunlink
);

}

use Time::localtime;
use WebConfig;
use DBI;
use GD;
use CGI qw( :standard );
use CGI::Session qw/-ip-match/;    # for security - ken
use MIME::Base64 qw( encode_base64 decode_base64 );
use FileHandle;
use Data::Dumper;
use LWP;
use LWP::UserAgent;
use HTTP::Request::Common qw( GET );
use Storable;

#use CGI::Carp qw( fatalsToBrowser carpout set_message  );
use CGI::Carp qw( carpout set_message  );
use Cwd;
use File::Path qw(make_path remove_tree);
use Sys::Hostname;
use Carp qw(longmess);
use POSIX ':signal_h';
use JSON;

# use IMG::Util::Untaint;

my $timeoutSec;    # set by main.pl; see WebUtil::timeout()

# Force flush
$| = 1;

###
# Environment variables
#
my $env                      = getEnv();
my $main_cgi                 = $env->{main_cgi};
my $base_url                 = $env->{base_url};
my $oracle_config            = $env->{oracle_config} || undef;
my $mysql_config             = $env->{mysql_config} || undef;
my $site_pw_md5              = $env->{site_pw_md5};
my $show_sql_verbosity_level = $env->{show_sql_verbosity_level};

require $oracle_config if $oracle_config;

#require $mysql_config  if $mysql_config  ne "";
my $img_internal        = $env->{img_internal};
my $include_metagenomes = $env->{include_metagenomes};
my $img_lite            = $env->{img_lite};
my $include_plasmids    = $env->{include_plasmids};

#my $public_nologin_site   = $env->{public_nologin_site};
my $public_login          = $env->{public_login};
my $env_blast_dbs         = $env->{env_blast_dbs};
my $env_blast_defaults    = $env->{env_blast_defaults};
my $snp_blast_data_dir    = $env->{snp_blast_data_dir};
my $img_term_overlay      = $env->{img_term_overlay};
my $web_log_file          = $env->{web_log_file};
my $err_log_file          = $env->{err_log_file};
my $img_ken               = $env->{img_ken};
my $img_er                = $env->{img_er};
my $img_geba              = $env->{img_geba};
my $img_edu               = $env->{img_edu};
my $ignore_dblock         = $env->{ignore_dblock};
my $gene_hits_files_dir   = $env->{gene_hits_files_dir};
my $gene_hits_zfiles_dir  = $env->{gene_hits_zfiles_dir};
my $bbh_files_dir         = $env->{bbh_files_dir};
my $bbh_zfiles_dir        = $env->{bbh_zfiles_dir};
my $blastall_bin          = $env->{blastall_bin};
my $img_hmms_serGiDb      = $env->{img_hmms_serGiDb};
my $img_hmms_singletonsDb = $env->{img_hmms_singletonsDb};
my $jira_email_error      = $env->{jira_email_error};
my $web_log_override      = 0;

# need this for IMG 2.3
my $show_myimg_login = $env->{show_myimg_login};

# html bookmark - ken
my $content_list = $env->{content_list};

my ( $dsn, $user, $pw );
if ( $mysql_config ) {
    $dsn  = $ENV{MYSQL_DBI_DSN};
    $user = $ENV{MYSQL_USER};
    $pw   = $ENV{MYSQL_PASSWORD};
}
my ( $ora_port, $ora_host, $ora_sid );
if ( $oracle_config ) {
    $dsn      = $ENV{ORA_DBI_DSN};
    $user     = $ENV{ORA_USER};
    $pw       = $ENV{ORA_PASSWORD};
    $ora_port = $ENV{ORA_PORT};
    $ora_host = $ENV{ORA_HOST};
    $ora_sid  = $ENV{ORA_SID};
}

#
# gold dbh and img dbh
# lets create a single instance of these db handlers
# I would use connect_cache but its does not work (very buggy) for inserts, updates and deletes
# - ken
my ( $DBH_GOLD, $DBH_IMG );

my $maxClobSize = 38000;
my $base_dir    = $env->{base_dir};
my $tmp_dir     = $env->{tmp_dir};
my $tmp_url     = $env->{tmp_url};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};
my $log_dir     = $env->{log_dir};

# Force the temporary files directory to dir abc - for files uploads see CGI.pm docs
# http://perldoc.perl.org/CGI.html search for -private_tempfiles
#$CGITempFile::TMPDIRECTORY = '/opt/img/temp';
#$CGITempFile::TMPDIRECTORY = $TempFile::TMPDIRECTORY = '/opt/img/temp';
#or
#$ENV{TMPDIR} = '/opt/img/temp';
# http://www.webdeveloper.com/forum/showthread.php?157639-CGI-Perl-uploading-files
#
$CGITempFile::TMPDIRECTORY = $TempFile::TMPDIRECTORY = "$cgi_tmp_dir";

# For sqllite
$ENV{TMP}     = "$cgi_tmp_dir";
$ENV{TEMP}    = "$cgi_tmp_dir";
$ENV{TEMPDIR} = "$cgi_tmp_dir";
$ENV{TMPDIR}  = "$cgi_tmp_dir";

# ifs scratch directory to email users
# see GenerateArtemisFile.pm var $public_artemis_url
my $ifs_tmp_dir = $env->{ifs_tmp_dir};

webfsTest();

# create index.html in tmp directories for security;
createTmpIndex();

my $cgi_dir             = $env->{cgi_dir};
my $ava_batch_dir       = $env->{ava_batch_dir};
my $ava_taxon_dir       = $env->{ava_taxon_dir};
my $ava_index_dir       = $env->{ava_index_dir};
my $taxon_fna_dir       = $env->{taxon_fna_dir};
my $taxon_reads_fna_dir = $env->{taxon_reads_fna_dir};
my $taxon_lin_fna_dir   = $env->{taxon_lin_fna_dir};
my $wsimHomologs_bin    = $env->{wsimHomologs_bin};
my $all_fna_files_dir   = $env->{all_fna_files_dir};

#my $gene_homlogs_tab_file = $env->{ gene_homologs_tab_file };
#my $gene_homlogs_fpos_file = $env->{ gene_homologs_fpos_file };
my $fastacmd_bin  = $env->{fastacmd_bin};
my $scaffold_cart = $env->{scaffold_cart};

#my $use_func_cart = $env->{ use_func_cart };
my $use_func_cart = 1;

# oracle in statement limit
my $ORACLEMAX = 999;

my $dbLoginTimeout = 10;    # 10 seconds

my $max_gene_batch        = 100;
my $max_taxon_batch       = 500;
my $max_scaffold_batch    = 500;
my $preferences_url       = "$main_cgi?section=MyIMG&page=preferences";
my $maxGeneListResults    = 1000;
my $user_restricted_site  = $env->{user_restricted_site};
my $no_restricted_message = $env->{no_restricted_message};

#blockRobots();
#my $max_db_conn           = $env->{max_db_conn};
my $cgi;

# see http://search.cpan.org/~sherzodr/CGI-Session-3.95/Session/Tutorial.pm
# section INITIALIZING EXISTING SESSIONS
# idea:
# before we create a session id lets check the cookies
# if it exists use existing cookie sid
# also the cookie name is now system base url specific
# - Ken
my $cookie_name;
my $g_session;
initialize();

my $linkTarget;
my $rdbms = getRdbms();

## --es 05/05/2005 limit no. of concurrent BLAST jobs.
my $max_blast_jobs = $env->{max_blast_jobs};
$max_blast_jobs = 20 if $max_blast_jobs == 0;

my $verbose = $env->{verbose};

if ( ! $web_log_file ) {
    webDie("env{ web_log_file } not define in WebConfig.pm\n");
}
if ( ! $err_log_file ) {
    webDie("env{ err_log_file } not define in WebConfig.pm\n");
}
## For web servers only, but not for developer doing "perl -c ...".
if ( defined $ENV{GATEWAY_INTERFACE} ) {
    my $err_fh = newAppendFileHandle( $err_log_file, "a" );
    if ( !defined($err_fh) ) {
        webDie("Unable to write '$err_log_file'\n");
    }
    carpout($err_fh);
}

# if a blast process is running and was called using the blast wrapper
# the child process id should be store here for the timeout to kill it
# - ken
my $blast_PID = 0;

sub initialize {
    $cgi = CGI->new();

    # see http://search.cpan.org/~sherzodr/CGI-Session-3.95/Session/Tutorial.pm
    # section INITIALIZING EXISTING SESSIONS
    # idea:
    # before we create a session id lets check the cookies
    # if it exists use existing cookie sid
    # also the cookie name is now system base url specific
    # - Ken
    $cookie_name = "CGISESSID_";
    if ( $env->{urlTag} ) {
        $cookie_name = $cookie_name . $env->{urlTag};
    } else {
        my @tmps = split( /\//, $base_url );
        $cookie_name = $cookie_name . $tmps[$#tmps];
    }
    CGI::Session->name($cookie_name);    # override default cookie name CGISESSID
    $CGI::Session::IP_MATCH = 1;

    my $cookie_sid = $cgi->cookie($cookie_name) || undef;
    $g_session = new CGI::Session( undef, $cookie_sid, { Directory => $cgi_tmp_dir } );

    #$g_session              = new CGI::Session( undef, $cgi, { Directory => $cgi_tmp_dir } );

    stackTrace( "WebUtil::initialize()", "TEST: cookie ids ======= cookie_name => $cookie_name sid => " . ( $cookie_sid || "" ) );

}

sub stackTrace {
    my ( $title, $text, $contact_oid, $sid ) = @_;

    if ( !$contact_oid ) {
		$contact_oid = getContactOid() || "";
	}
    if ( !$sid ) {
		$sid = getSessionId() || "";
	}

    # Natalia or Ken
    if (   $img_ken
        || $contact_oid eq '10'
        || $contact_oid eq '3038' )
    {
        my $dump = longmess();
        my $date = dateTimeStr();

        my $str = qq{

======== Stack Trace $title ============
$date
    $text
    contact id = $contact_oid
    session id = $sid
$dump
======== End of Stack Trace ============

        };

        my $afh = new FileHandle( $web_log_file, "a" ); #newAppendFileHandle( $web_log_file, "stackTrace" );
        if ( !$afh ) {
            print "Content-type: text/html\n\n";
            print "Stack Trace Error FileHandle\n";
            exit -1;
        }
        print $afh $str;
        close $afh;
    }
}

#
# clear cgi session id file and directory after logout and after block bots calls
#
sub clearSession {
    webLog("clear cgi session\n");
    my $contact_oid = getContactOid();
    my $session     = getSession();
    my $session_id  = getSessionId();

    setSessionParam( "blank_taxon_filter_oid_str", "1" );
    setSessionParam( "contact_oid",                "" );
    setTaxonSelections("");
    setSessionParam( "jgi_session_id", "" );
    setSessionParam( "oldLogin",       "" );

    $session->delete();
    $session->flush();                # Recommended practice says use flush() after delete().

    webLog( "clear cgi session: $cgi_tmp_dir/cgisess_" . $session_id . "\n" );
    wunlink( "$cgi_tmp_dir/cgisess_" . $session_id );

    webLog( "clear cgi session: $cgi_tmp_dir/" . $session_id . "\n" );
    remove_tree( "$cgi_tmp_dir/" . $session_id ) if ( $session_id ne '' );

    stackTrace( "WebUtil::clearSession()", '', $contact_oid, $session_id );
}

sub getCookieName {
    return $cookie_name;
}

# set the pid to kill - see timeout method
# - ken
#
sub setBlastPid {
    my ($pid) = @_;
    $blast_PID = $pid;
    $blast_PID = sanitizeInt($blast_PID);
    webLog("child pid set = $pid\n");
}

# 1. create tmp areas
# 2. for security create index.html in tmp directories - ken
#
sub createTmpIndex {

	return;
    return if $env->{dev_site};

	# make sure these directories exist
	# this just a check to make sure it exists and create it if not.
	# it should have been created from install script and rsync over to prod machine
	# - ken
    for my $dir ( $tmp_dir, $log_dir, $cgi_tmp_dir ) {
        if ( $dir && ! -e $dir ) {
			umask 0002;
			make_path( $dir, { mode => 0775 } );
		}
	}

    # what if /ifs/scratch/ failed?
    my $ifs_tmp_parent_dir = $env->{ifs_tmp_parent_dir};
    if ( $ifs_tmp_parent_dir ne "" && -e $ifs_tmp_parent_dir && $ifs_tmp_dir ne "" && !-e $ifs_tmp_dir ) {
        umask 0000;
        make_path( $ifs_tmp_dir, { mode => 0777 } );
        chmod( 0777, $ifs_tmp_dir );
    }

    if ( $ifs_tmp_dir ne "" && -e $ifs_tmp_dir ) {
        if ( !-e "$tmp_dir/public" ) {
            symlink $ifs_tmp_dir, "$tmp_dir/public";
        }
    }

    if ( -e $ifs_tmp_dir ) {
        if ( !-e "$ifs_tmp_dir/index.html" ) {

            # tmp index-tmp.html
            my $s  = file2Str( $base_dir . "/index-tmp.html" );       # read file only when necessary
            my $wh = newWriteFileHandle("$ifs_tmp_dir/index.html");
            print $wh $s;
            close $wh;
        }
    }

    if ( -e $tmp_dir ) {
        if ( !-e "$tmp_dir/index.html" ) {

            # tmp index-tmp.html
            my $s  = file2Str( $base_dir . "/index-tmp.html" );       # read file only when necessary
            my $wh = newWriteFileHandle("$tmp_dir/index.html");
            print $wh $s;
            close $wh;
        }
    }
}

############################################################################
# blockRobots - Block robots from using this script.
#   (robots.txt doesn't always work; so a little brute force ...)
############################################################################
sub blockRobots {
    ## .htaccess and robots.txt does not work; we force it.
    my $http_user_agent = $ENV{HTTP_USER_AGENT};
    webLog("HTTP_USER_AGENT='$http_user_agent'\n") if $verbose >= 1;
    my $remote_addr = $ENV{REMOTE_ADDR};
    webLog("REMOTE_ADDR=$remote_addr\n") if $verbose >= 1;

    #
    # NCBI LinkOut Link Check Utility
    # IP proxy: 130.14.254.25 or 130.14.254.26
    # User agent : "LinkOut Link Check Utility"
    # IP range: 130.14.*.*
    #
    if ($http_user_agent =~ /LinkOut Link Check Utility/
        && ( $remote_addr =~ /^130\.14\./ || $remote_addr eq '128.55.71.38' )) {
        # its must go thru genome.php
        my $ip = param('ip');
        my $useragent = param('useragent');

        webLog("\nNCBI bot ignored for LinkOut test Apr 27 2015\n");
        webLog("$remote_addr === $ip\n");
        webLog("$http_user_agent === $useragent\n\n");

        return;
    }

    # potential fix for error resulted from single plus sign input
    my $page;
    eval { $page = param("page"); };

    my $bot_patterns = $env->{bot_patterns};
    my $match        = 0;

    if ( defined($bot_patterns) ) {
        for my $pattern (@$bot_patterns) {
            if ( $http_user_agent =~ /$pattern/ ) {
                $match = 1;
                last;
            }
        }
    }
    my $allow_hosts = $env->{allow_hosts};
    if ( defined($allow_hosts) ) {
        my @parts0 = split( /\./, $remote_addr );
        my $n = @parts0;
        for my $allow_host (@$allow_hosts) {
            my @parts1 = split( /\./, $allow_host );
            my $allPartsMatch = 1;
            for ( my $i = 0 ; $i < $n ; $i++ ) {
                my $part0 = $parts0[$i];
                my $part1 = $parts1[$i];
                if ( $part0 ne $part1 && $part1 ne "*" ) {
                    $allPartsMatch = 0;
                    last;
                }
            }
            if ($allPartsMatch) {

                # Nullify bot pattern match
                $match = 0;
                webLog("'$remote_addr' allowed by '$allow_host' rule\n");
                last;
            }
        }
    }

    if ( $match && $page ne "home" && $page ne "help" && $page ne "uiMap" ) {

        my $file = "$base_dir/403-Forbidden.html";
        my $rfh  = newReadFileHandle( $file, "blockbots", 1 );

        if ( !$rfh ) {
            print header( -status => 403 );
            print "<html>\n";
            print "<head>\n";
            print "<title>403 Forbidden</title>\n";
            print "</head>\n";
            print "<body>\n";
            print "<h1>Forbidden</h1>\n";
            print "$http_user_agent.<br/>\n";
            print "Bots don't have permission.\n";
            print "</body>\n";
            print "</html>\n";
        } else {
            print header( -type => "text/html" );
            while ( my $s = $rfh->getline() ) {
                print "$s";
            }
        }
        close $rfh;
        webLog("== Exit for HTTP_USER_AGENT $http_user_agent\n");
        clearSession();
        webExit(0);
    }

    blockIpAddress();
}

sub blockIpAddress {
    my $remote_addr = $ENV{REMOTE_ADDR};

    my $file = $env->{block_ip_address_file};
    if ( $file ne '' && -e $file ) {
        my $rfh = newReadFileHandle( $file, 'blockIpAddress', 1 );
        if ($rfh) {
            while ( my $s = $rfh->getline() ) {
                chomp $s;
                next if ( $s =~ /^#/ );
                next if ( blankStr($s) );

                my ( $ip, $comment ) = split( /=/, $s );
                if ( $ip eq $remote_addr ) {

                    # blocked ip
                    # 429 Too Many Requests
                    print header( -status => '429 Too Many Requests' );
                    print "<html>\n";
                    print "<head>\n";
                    print "<title>429 Too Many Requests</title>\n";
                    print "</head>\n";
                    print "<body>\n";
                    print "<h1>429 Too Many Requests</h1>\n";
                    print "Your IP address $remote_addr has been blocked.\n";
                    print "</body>\n";
                    print "</html>\n";
                    clearSession();
                    webExit(0);
                }
            }
            close $rfh;
        }
    }
}

#
# get a single cgi object - perl 5.10 bug fix
# - ken
sub getCgi {
    return $cgi;
}

############################################################################
# timeout - Timeout CGI processes that take too long.  Do not clog
#   up the process table.
# http://www.tutorialspoint.com/perl/perl_alarm.htm
# Sets the "alarm," causing the current process to receive a SIGALRM signal in
# EXPR seconds. If EXPR is omitted, the value of $_ is used instead.
# The actual time delay is not precise, since different systems implement
# the alarm functionality differently. The actual time may be up to a second
# more or less than the requested value. You can only set one alarm timer at any
# one time. If a timer is already running and you make a new call to the alarm
# function, the alarm timer is reset to the new value. A running timer can be
# reset without setting a new timer by specifying a value of 0.
############################################################################
sub timeout {
    my ($secs) = @_;
    $timeoutSec = $secs;

    my $cwd = getcwd();
    my $dt  = currDateTime();
    $SIG{ALRM} = sub {
        print "<p><font color='red'>Session has timed out. Process is taking too long to run.</font></p>\n";
        if ( $blast_PID > 0 ) {

            $blast_PID = sanitizeInt($blast_PID);

            # kill any child pid set in $blast_PID
            # we've tried kill HUP => -$$; but it still waits for blast to
            # finish - I've already tested with simple scripts
            # and the parent still waits for the child to finish
            # test model
            # parent.pl -> child.sh -> child.pl
            #
            #webLog("killing PID $blast_PID\n");
            kill 9, $blast_PID;
        }

        #print "<p><font color='red'>Session has timed out. Process is taking too long to run.</font></p>\n";
        webDie("$dt: $cwd: $0: pid=$$ timeout=($secs seconds)\n");
    };
    alarm $secs;
}

############################################################################
# printResetFormButton - prints a reset button for a form that contains
#   InnerTable(s) to make sure to clear the table upon a reset call
############################################################################
sub printResetFormButton {
    my ($innerTableIds) = @_;
    my $str;
    foreach my $id (@$innerTableIds) {
        $str .= 'checkAll(0, oIMGTable_' . $id . '); ';
    }
    print "<input type='button' class='smbutton' value='Reset' " . "onclick='$str reset();'>";
}

#######################################################################
# Standard buttons for taxon list
# Prints button "Add to Genome Cart", "Select All", and "Clear All"
# Parameter $txTableName = InnerTable table ID for YUI tables
# Parameter $txTableName = "" for non YUI table
#######################################################################
sub printTaxonButtons {
    my ($txTableName) = @_;
    print submit(
        -name    => 'setTaxonFilter',
        -value   => 'Add Selected to Genome Cart',
        -class   => 'meddefbutton',
        -onClick => "return isGenomeSelected('$txTableName');"
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' " . "onClick='selectAllTaxons(1)' class='smbutton' />";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' " . "onClick='selectAllTaxons(0)' class='smbutton' />";
}

############################################################################
# resetContactOid - Compare base_url's.  If new one for the first time
#  reset contact_oid so old user is not carried over to next site.
############################################################################
sub resetContactOid {
    my $base_url_x = getSessionParam("base_url");
    if ( $base_url_x ne $base_url ) {
        setSessionParam( "contact_oid", 0 );
    }
    setSessionParam( "base_url", $base_url );
}

############################################################################
# setWebLogOverride - Set flag for overriding web logging file.
#   Mainly used by test applications.
############################################################################
sub setWebLogOverride {
    my ($bf) = @_;
    $web_log_override = $bf;
}

############################################################################
# delete the web logs after given size
#
# new for 3.3 - ken
############################################################################
#sub purgeLogs {
#    my ($file) = @_;
#
#    # return in bytes
#    my $filezie = -s $file;
#
#    # 100 MB
#    my $maxsize = 100 * 1024 * 1024;
#
#    if ( $filezie > $maxsize ) {
#
#        #webErrLog("$filezie unlinked\n");
#        unlink($file);
#    }
#}

############################################################################
# webLog - Do logging to file.
############################################################################
sub webLog {
    my ($s) = @_;
    return if ( $verbose < 0 );

    #    my $enable_purge = $env->{enable_purge};
    #    if ($enable_purge) {
    #        purgeLogs($web_log_file);
    #    }

    my $afh = newAppendFileHandle( $web_log_file, "webLog" );
    print $afh $s;
    close $afh;
}

############################################################################
# webErrLog - Do logging to STDERR to file.
############################################################################
sub webErrLog {
    my ($s) = @_;
    my $afh = newAppendFileHandle( $err_log_file, "webErrLog" );
    print $afh $s;
    close $afh;
}

# trace logins and logouts
# $loginType - login or logout
# $sso - img or sso
sub loginLog {
    my ( $loginType, $sso ) = @_;
    my $login_log_file = $env->{login_log_file};
    if ( $login_log_file ne '' ) {
        my $afh         = newAppendFileHandle($login_log_file);
        my $time        = dateTimeStr();
        my $session     = getSessionId();
        my $contactId   = getContactOid();
        my $url         = $env->{cgi_url};
        my $remote_addr = $ENV{REMOTE_ADDR};
        my $servername  = getHostname();

        print $afh $time;
        print $afh "\t";
        print $afh $loginType;
        print $afh "\t";
        print $afh $sso;
        print $afh "\t";
        print $afh $contactId;
        print $afh "\t";
        print $afh $remote_addr;
        print $afh "\t";
        print $afh $servername;
        print $afh "\t";
        print $afh $url;
        print $afh "\t";
        print $afh $session;
        print $afh "\n";
        close $afh;
    }
}

############################################################################
# getRdbms - Get rdbms type from configuration file.
############################################################################
sub getRdbms {
    return "mysql"  if $mysql_config;
    return "oracle" if $oracle_config;
    webDie("rdbms: rdbm configuration file not set\n");
}

############################################################################
# getNvl - Get right version of Oracle function NVL, but for other
#   RDBMS's like mysql.
############################################################################
sub getNvl {
    return "ifnull" if $rdbms eq "mysql";
    return "nvl";
}

############################################################################
# unsetEnvPath - Unset the environment path for external calls.
############################################################################
sub unsetEnvPath {

    my $envPath = $ENV{PATH};
    if ( $envPath =~ /^(.*)$/ ) {
	    $ENV{PATH} = $1; # untaint
    }
	return;
}

############################################################################
# resetEnvPath - Rest environment path to original.
############################################################################
sub resetEnvPath {

    #$ENV{PATH} = $envPath;
}

############################################################################
# checkBlankVar - Check for blank variable or variables.
#   Convenience wrapper.
############################################################################
sub checkBlankVar {
    my ($s) = @_;
    return if !blankStr($s);
    printStatusLine( "No data.", 2 );
    webError("No data retrieved.");
    webExit(0);
}

###########################################################################
# checkAccess - Check login access.  Exit with error message if
#  not valid.
############################################################################
sub checkAccess {
    my $contact_oid = getContactOid();
    if ( !blankStr($site_pw_md5) ) {
        my $pw_prev_md5 = getSessionParam("site_pw_md5");
        my $pw_curr     = param("site_password");
        my $pw_curr_md5 = md5_base64($pw_curr);
        if (   ( blankStr($pw_curr) && $pw_prev_md5 ne $site_pw_md5 )
            || ( !blankStr($pw_curr) && $pw_curr_md5 ne $site_pw_md5 ) )
        {
            webErrorHeader("Invalid access");
        }
    }
    if ( $user_restricted_site && !$contact_oid ) {
        webErrorHeader("Invalid access");
    }
}

############################################################################
# checkEvalue - Check option selection evalue from UI.
############################################################################
sub checkEvalue {
    my ($evalue) = @_;
    $evalue =~ /([0-9]+e-?[0-9]+)/;
    my $evalue2 = $1;
    if ( $evalue2 eq "" ) {
        webDie("checkEvalue: invalid evalue='$evalue'\n");
    }
    return $evalue2;
}

############################################################################
# checkPath - Check path for invalid characters.
############################################################################
sub checkPath {
    my ($path) = @_;
    ## Catch bad pattern first.
    my @toks = split( /\//, $path );
    for my $t (@toks) {
        next if $t eq "";    # for double slashes
        if ( $t !~ /^[a-zA-Z0-9_\.\-\~]+$/ || $t eq ".." ) {
            webDie("checkPath:1: invalid path '$path' tok='$t'\n");
        }
    }
    ## Untaint.
    $path =~ /([a-zA-Z0-9\_\.\-\/]+)/;
    my $path2 = $1;
    if ( $path2 eq "" ) {
        webDie("checkPath:2: invalid path '$path2'\n");
    }
    return $path2;
}


#
# file name cannot have the following chars
# .. \ / ~ ' " `
#
sub checkFileName {
    my ($fname) = @_;
    if (   $fname =~ /\\/
        || $fname =~ /\.\./
        || $fname =~ /\//
        || $fname =~ /~/
        || $fname =~ /\'/
        || $fname =~ /\"/
        || $fname =~ /`/ )
    {

        #return "bad";
        webDie("Invalid filename: $fname\n");
    }
    return $fname;
}

############################################################################
# validFileName - Check for valid file name w/o full path.
############################################################################
sub validFileName {
    my ($fname) = @_;
    $fname =~ /([a-zA-Z0-9\._-]+)/;
    my $fname2 = $1;
    if ( $fname2 eq "" ) {
        webDie("validFileName: invalid file name '$fname'\n");
    }
    return $fname2;
}

############################################################################
# wunlink - Web version of unlink, check path.
############################################################################
sub wunlink {
    my ($path) = @_;
    ## Sometimes in clustalw the current directory is changed to tmp.
    $path = checkPath($path);

    #my $fname = lastPathTok( $path );
    #my $fname2 = validFileName( $fname );
    webLog("unlink '$path'\n") if $verbose >= 2;
    unlink($path);
}

############################################################################
# wsystem - system() for web. Use only first token as executable.
############################################################################
sub wsystem {
    my ($cmd) = @_;
    $cmd =~ s/\s+/ /g;
    my @args = split( / /, $cmd );
    my $ex = shift(@args);
    checkPath($ex);

    unsetEnvPath();
    my $st = system( $ex, @args );

    return $st;
}

############################################################################
# newReadFileHandle - Security wrapper for new FileHandle.
############################################################################
sub newReadFileHandle {
    my ( $path, $func, $noExit ) = @_;

    $func = "newReadFileHandle" if $func eq "";
    $path = checkPath($path);
    my $fh = new FileHandle( $path, "r" );
    if ( !$fh && !$noExit ) {
        webDie("$func: cannot read '$path'\n");
    } elsif ( !$fh ) {
        webLog("$func: cannot read '$path'\n");
    }
    return $fh;
}

############################################################################
# newWriteFileHandle - Security wrapper for new FileHandle.
############################################################################
sub newWriteFileHandle {
    my ( $path, $func, $noExit ) = @_;

    $func = "newWriteFileHandle" if $func eq "";
    $path = checkPath($path);
    my $fh = new FileHandle( $path, "w" );
    if ( !$fh && !$noExit ) {
        webDie("$func: cannot write '$path'\n");
    } elsif ( !$fh ) {
        webLog("$func: cannot write '$path'\n");
    }
    return $fh;
}

############################################################################
# newAppendFileHandle - Security wrapper for new FileHandle.
############################################################################
sub newAppendFileHandle {
    my ( $path, $func, $noExit ) = @_;

    $func = "newAppendFileHandle" if $func eq "";
    $path = checkPath($path);
    my $fh = new FileHandle( $path, "a" );

    # to stop infinite loop when log files cannot be open - ken
    if ( !$fh && ( $func eq "webLog" || $func eq "webErrLog" ) ) {
        print "Cannot open log file $path \n";
        webExit(-1);
    }

    if ( !$fh && !$noExit ) {
        webDie("$func: cannot append '$path'\n");
    }
    return $fh;
}

############################################################################
# newCmdFileHandle - Security wrapper for new FileHandle with command.
############################################################################
sub newCmdFileHandle {
    my ( $cmd, $func, $noExit ) = @_;

    $func = "newCmdFileHandle" if $func eq "";

    # http://perldoc.perl.org/perlipc.html#Using-open()-for-IPC
    #
    # see section "Using open() for IPC"
    # - ken
    #$SIG{PIPE} = 'IGNORE';
    $SIG{PIPE} = sub {
        die "<p><font color='red'> pipe failed. </font></p>\n";
    };

    webLog "+ $cmd\n";
    my $fh = new FileHandle("$cmd |");
    if ( !$fh && !$noExit ) {
        webLog("$func: cannot '$cmd'\n");
        webExit(-1);
    }
    return $fh;
}

############################################################################
# newUnzipFileHandle - Fault tolerant access to members of zip files.
############################################################################
sub newUnzipFileHandle {
    my ( $inZipFile, $member, $func, $noExit ) = @_;

    webLog("newUnzipFileHandle: '$inZipFile':'$member'\n");
    $func = "newUnzipileHandle" if $func eq "";
    my $cmd = "/usr/bin/unzip -p $inZipFile $member";

    #    print "+ $cmd\n";
    unsetEnvPath();
    my $fh = new FileHandle("$cmd |");
    resetEnvPath();

    # This section doesn't really work.
    # But leave it here just in case.
    if ( !defined($fh) ) {
        warn("$func: file='$inZipFile' member='$member' not found\n");
        $fh = newReadFileHandle( "/dev/null", $func );
    }
    if ( !$fh && !$noExit ) {
        webDie("$func: cannot '$cmd' or read /dev/null\n");
    }

    return $fh;
}

# webfs / db lock file test
sub webfsTest {
    my $webfs = $env->{ifs_tmp_parent_dir};
    my $errorMsg;
    my $mask   = POSIX::SigSet->new(SIGALRM);    # signals to mask in the handler
    my $action = POSIX::SigAction->new(
        sub { webErrorHeader( "IMG webfs hard drive has failed. Please try again later.", 0, -1 ) },   # the handler code ref
        $mask

          # not using (perl 5.8.2 and later) 'safe' switch or sa_flags
    );

    my $oldaction = POSIX::SigAction->new();
    sigaction( 'ALRM', $action, $oldaction );
    eval {
        alarm( $dbLoginTimeout ) if $dbLoginTimeout;    # seconds before time out
        if ( -e $webfs ) {

            # its fine.
        }
        alarm(0);                  # cancel alarm (if connect worked fast)
    };
    alarm(0);                      # cancel alarm (if eval failed)

    # restore original signal handler
    sigaction( 'ALRM', $oldaction );
    alarm($timeoutSec) if $timeoutSec;

    if ($@) {

        # eval failed
        webErrorHeader( "$@", 0, -1 );
    }
}

# Can we read the web data dir?
sub webDataTest {
    my $common_tmp_dir = $env->{common_tmp_dir};
    my $web_data_dir   = $env->{web_data_dir};
    my $str            = "";
    my $ifs_str        = "";
    my $web_str        = "";

    if ( !-e $web_data_dir ) {
        $web_str = "data drive";
        $str     = qq{
This is embarrassing. IMG's data files cannot be accessed at this time.
Please try again later.
If the problem presist please contact us at:
<a href="main.cgi?page=questions&subject=Web Data Problems $web_str">IMG Questions/Comments</a> or email us at:
<a href="mailto:$jira_email_error?Subject=Web Data Problems $web_str"> IMG Support </a>.
        };
    } elsif ( !-e $ifs_tmp_dir ) {
        $ifs_str = "ifs drive";
        $str     = qq{
This is embarrassing. IMG's web temporary area cannot be accessed at this time.
This only affects our export tools and emailed results tools. You can still use most of IMG's tools.
If the problem presist please contact us at:
<a href="main.cgi?page=questions&subject=Web Data Problems $ifs_str">IMG Questions/Comments</a> or email us at:
<a href="mailto:$jira_email_error?Subject=Web Data Problems $ifs_str"> IMG Support </a>.
        };
    } elsif ( !-e $common_tmp_dir ) {
        $str = qq{
This is embarrassing. IMG's BLAST temporary area cannot be accessed at this time.
This only affects our BLAST tools. You can still use most of IMG's tools.
If the problem presist please contact us at:
<a href="main.cgi?page=questions&subject=Web Data Problems $ifs_str">IMG Questions/Comments</a> or email us at:
<a href="mailto:$jira_email_error?Subject=Web Data Problems $ifs_str"> IMG Support </a>.
        };

    }

    return $str;
}

#############################################################################
# runCmd - Run external command line tool.  Exit on failure, non-zero
#   exit status.
#############################################################################
sub runCmd {
    my ($cmd) = @_;
    webLog "+ $cmd\n";
    my $st = wsystem($cmd);
    if ( $st != 0 ) {
        webDie("runCmd: execution error status $st\n");
    }
}

#############################################################################
# runCmdNoExit - Run external command line, but do not exit on failure.
#############################################################################
sub runCmdNoExit {
    my ($cmd) = @_;
    webLog "+ $cmd\n";
    my $st = wsystem($cmd);
    return $st;
}

############################################################################
# checkTmpPath - Wrap temp path for safety.  An additional
#   check for writing (or reading) to (from) temp directory.
############################################################################
sub checkTmpPath {
    my ($path) = @_;
    my $common_tmp_dir = $env->{common_tmp_dir};
    if ( $path !~ /^$tmp_dir/ && $path !~ /^$cgi_tmp_dir/ && $path !~ /^$common_tmp_dir/ ) {
        webLog( "checkTmpPath: expected full temp directory " . "'$tmp_dir' or '$cgi_tmp_dir'; got path '$path'\n" );
        webExit(-1);
    }
    $path = checkPath($path);
    my $fname  = lastPathTok($path);
    my $fname2 = validFileName($fname);
    return $path;
}

###########################################################################
# file2Str - Convert file contents to string.
###########################################################################
sub file2Str {
    my ( $file, $noexit ) = @_;

    my $rfh  = newReadFileHandle( $file, "file2Str", $noexit );
    my $line = "";
    my $s    = "";
    if ( !$rfh && $noexit ) {
        return $s;
    }

    while ( $line = $rfh->getline() ) {
        $s .= $line;
    }
    close $rfh;
    return $s;
}

sub conditionalFile2Str {
    my ( $file, $origLine, $newLine ) = @_;

    my $rfh  = newReadFileHandle( $file, "file2Str" );
    my $line = '';
    my $s    = '';
    while ( $line = $rfh->getline() ) {
        if ( $line =~ /$origLine/i ) {
            $s .= $newLine;
        } else {
            $s .= $line;
        }
    }
    close $rfh;
    return $s;
}

#############################################################################
# str2File - Write string to file.
#############################################################################
sub str2File {
    my ( $str, $file ) = @_;
    my $wfh = newWriteFileHandle( $file, "str2File" );
    print $wfh $str;
    close $wfh;
}

#############################################################################
# appendFile - Append string to file.
#############################################################################
sub appendFile {
    my ( $file, $str ) = @_;
    my $afh = newAppendFileHandle( $file, "appendFile" );
    print $afh $str;
    close $afh;
}

#############################################################################
# currDateTime - Get current date time string.
#############################################################################
sub currDateTime {
    my $s = sprintf(
        "%d/%d/%d %d:%d:%d",
        localtime->mon() + 1, localtime->mday(), localtime->year() + 1900,
        localtime->hour(),    localtime->min(),  localtime->sec()
    );
    return $s;
}

#############################################################################
# dateTimeStr - Another version of date time string.
#############################################################################
sub dateTimeStr {
    my $s = sprintf(
        "%04d-%02d-%02d-%02d.%02d.%02d",
        localtime->year() + 1900, localtime->mon() + 1, localtime->mday(),
        localtime->hour(),        localtime->min(),     localtime->sec()
    );
    return $s;
}

#############################################################################
# getDateStr - Yet another versino of date time string.
#############################################################################
sub getDateStr {
    my $s = sprintf( "%02d-%02d-%02d", localtime->year() + 1900, localtime->mon() + 1, localtime->mday() );
    return $s;
}

############################################################################
# getSysDate - Get system date in Oracle like default format.
############################################################################
sub getSysDate {
    my @months = ( "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" );
    my $month  = $months[ localtime->mon() ];
    my $year   = localtime->year() + 1900;
    my $day    = localtime->mday();
    return sprintf( "%02d-%s-%04d", $day, $month, $year );
}

###########################################################################
# blankStr - Is blank string.  Return 1=true or 0=false.
###########################################################################
sub blankStr {
    my $s = shift;

    if ( $s =~ /^[ \t\n]+$/ || $s eq "" ) {
        return 1;
    } else {
        return 0;
    }
}

###########################################################################
# strTrim - Trim string of preceding and ending spaces.
###########################################################################
sub strTrim {
    my $s = shift;

    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    return $s;
}

###########################################################################
# trimIntLeadingZero - remove leading zeros.
###########################################################################
sub trimIntLeadingZero {
    my $s = shift;

    if ( isInt($s) ) {
        $s =~ s/^0*//;
    }
    return $s;
}

###########################################################################
# showFile - Show file to standard error output.
###########################################################################
sub showFile {
    my $file = shift;

    my $rfh = newReadFileHandle( $file, "showFile" );
    my $line = "";
    while ( $line = $rfh->getline() ) {
        webLog($line);
    }
    close $rfh;
}

###########################################################################
# printFile - Show file to standard output.
###########################################################################
sub printFile {
    my $file = shift;

    my $rfh = newReadFileHandle( $file, "printFile" );
    my $line = "";
    while ( $line = $rfh->getline() ) {
        print $line;
    }
    close $rfh;
}

###########################################################################
# showFileStderr - Show file to standard err output.
###########################################################################
sub showFileStderr {
    my $file = shift;

    my $rfh = newReadFileHandle( $file, "showFileStderr" );
    my $line = "";
    while ( $line = $rfh->getline() ) {
        webLog "$line";
    }
    close $rfh;
}

#############################################################################
# fileSize - Return file size of file name.
#############################################################################
sub fileSize {
    my ($fileName) = @_;
    my $rfh = newReadFileHandle( $fileName, "fileSize", 1 );
    return 0 if !$rfh;
    my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat($rfh);
    close $rfh;
    return $size;
}

#############################################################################
# fileAtime - Return file access time for file name.
#############################################################################
sub fileAtime {
    my ($fileName) = @_;
    my $rfh = newReadFileHandle( $fileName, "fileAtime", 1 );
    return 0 if !$rfh;
    my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat($rfh);
    close $rfh;

    #return $atime;
    return $mtime;
}

#
# touch a file / update the access time such that the
# file is not purged by cgi purge timeout
# - Ken
#
sub fileTouch {
    my ($fileName) = @_;

    # cannot use with perl -T
    my $now = time;

    $fileName = checkPath($fileName);

    if ( $fileName =~ /^(.*)$/ ) { $fileName = $1; }
    utime( $now, $now, $fileName );

    #if ($fileName =~ /^(.*)$/) { $fileName = $1; }
    # fileName is now untainted

}

#############################################################################
# lastPathTok - Last path token in file path, i.e, the file name.
#############################################################################
sub lastPathTok {
    my ($path) = @_;
    my @toks = split( /\//, $path );
    my $i;
    my @toks2;
    foreach $i (@toks) {
        next if $i eq "";
        push( @toks2, $i );
    }
    my $nToks = @toks2;
    return $toks2[ $nToks - 1 ];
}

#############################################################################
# dirList - Directory list of files given a directory.
#############################################################################
sub dirList {
    my ($dir) = @_;
    opendir( Dir, $dir ) || webDie("dirList: cannot read '$dir'\n");
    my @paths = sort( readdir(Dir) );
    closedir(Dir);
    my @paths2;
    my $i;
    for $i (@paths) {
        next if $i =~ /^\./;
        next if $i eq "CVS";
        push( @paths2, $i );
    }
    return @paths2;
}

############################################################################
# getSequence - Get substring sequence given start < end,
#   start > end.  Handle compliments as necessary.  Coordinates
#   start with 1.
############################################################################
sub getSequence {
    my ( $seq, $start, $end ) = @_;
    $start = 1 if $start < 1;
    my $len = length($seq);
    $end = $len if $end > $len;
    my $range = $end - $start + 1;
    if ( $start <= $end ) {
        my $s2 = substr( $seq, $start - 1, $range );
        return $s2;
    } else {
        $range = $start - $end + 1;
        my $s2 = substr( $seq, $end - 1, $range );
        my $rseq = reverse($s2);
        $rseq =~ tr/actgACTG/tgacTGAC/;
        return $rseq;
    }
}

############################################################################
# arrray2Hash - Convert array values to hash.
############################################################################
sub array2Hash {
    my (@a) = @_;
    my %h;
    for my $i (@a) {
        $h{$i} = $i;
    }
    return %h;
}

############################################################################
# arrayRef2HashRef - Convert array values to hash and initialize.
############################################################################
sub arrayRef2HashRef {
    my ( $a_ref, $h_ref, $initVal ) = @_;
    for my $i (@$a_ref) {
        $h_ref->{$i} = $initVal;
    }
}

############################################################################
# getaa - Get amino acids from sequence.
############################################################################

=cut

sub getaa {
    my ( $seq, $sp ) = @_;
    my $i;
    my $len = length($seq);
    my $aaSeq;
    for ( $i = 0 ; $i < $len ; $i += 3 ) {
        my $s2 = substr( $seq, $i, 3 );
        my $aa = geneticCode($s2);
        $aaSeq .= $aa;
    }
    return $aaSeq;
}

=cut

############################################################################
# wrapSeq - Wrap a sequence for pretty printing.
############################################################################
sub wrapSeq {
    my ( $seq, $wrapLen ) = @_;
    $seq =~ s/\s//g;

    if ( $wrapLen eq "" ) {
        $wrapLen = 50;
    }
    my $i;
    my $s2;
    my $len = length($seq);
    for ( $i = 0 ; $i < $len ; $i += $wrapLen ) {
        my $s = substr( $seq, $i, $wrapLen );
        $s2 .= $s . "\n";
    }
    return $s2;
}

############################################################################
# absCoord - Retrieve original
#    absolute coordinate from relative coordinates.
#    a1..a2 - Original start and stop coordinates.
#    r1..r2 - Start and stop of relative coordinates to a1..a2.
#    Handle reverse strand mapping here too (where a2>a1, or r2>r1).
############################################################################
sub absCoord {
    my ( $a1, $a2, $r1, $r2 ) = @_;

    my ( $ra1, $ra2 ) = ( $a1, $a2 );

    if ( $a1 <= $a2 ) {

        # works for r1<=r2 and r1>r2.
        $ra1 = $a1 + $r1 - 1;
        $ra2 = $a1 + $r2 - 1;
    } else {
        $ra1 = $a1 - $r1 + 1;
        $ra2 = $a1 - $r2 + 1;
    }
    return ( $ra1, $ra2 );
}

############################################################################
# gcContent - Given a sequence, return GC% for
#    1. base 1 & 2 of all codons
#    2. base 3 for all codons
#    3. overall for all codons
############################################################################
sub gcContent {
    my ($seq) = @_;
    my $b12   = 0;
    my $b3    = 0;
    my $total = 0;
    my $i;
    $seq =~ tr/a-z/A-Z/;
    my $len  = length($seq);
    my $len2 = 0;

    for ( $i = 0 ; $i < $len ; $i += 3 ) {
        my $codon = substr( $seq, $i, 3 );
        my $j;
        my $c1 = substr( $codon, 0, 1 );
        my $c2 = substr( $codon, 1, 1 );
        my $c3 = substr( $codon, 2, 1 );
        if ( $c1 eq "G" || $c1 eq "C" ) {
            $total++;
            $b12++;
        }
        if ( $c2 eq "G" || $c2 eq "C" ) {
            $total++;
            $b12++;
        }
        if ( $c3 eq "G" || $c3 eq "C" ) {
            $total++;
            $b3++;
        }
        if ( $c1 ne "N" ) {
            $len2++;
        }
        if ( $c2 ne "N" ) {
            $len2++;
        }
        if ( $c3 ne "N" ) {
            $len2++;
        }
    }
    return ( 0, 0, 0 ) if $len2 == 0;
    $b12 /= ( ( 2.00 / 3.00 ) * $len2 );
    $b3  /= ( ( 1.00 / 3.00 ) * $len2 );
    $total /= $len;
    return ( $b12, $b3, $total );
}

############################################################################
# getAcgtCounts - Get counts of 'A', 'C', 'G', 'T's.
############################################################################
sub getAcgtCounts {
    my ($seq) = @_;

    $seq =~ s/\s+//g;
    $seq =~ tr/a-z/A-Z/;
    $seq =~ s/[NX]//g;

    my $a_seq = $seq;
    $a_seq =~ s/[^A]//g;
    my $a_count = length($a_seq);

    my $c_seq = $seq;
    $c_seq =~ s/[^C]//g;
    my $c_count = length($c_seq);

    my $g_seq = $seq;
    $g_seq =~ s/[^G]//g;
    my $g_count = length($g_seq);

    my $t_seq = $seq;
    $t_seq =~ s/[^T]//g;
    my $t_count = length($t_seq);

    return ( $a_count, $c_count, $g_count, $t_count );
}

############################################################################
# readFasta - Read Fasta file and return sequence.
############################################################################
sub readFasta {
    my ($inFile) = @_;
    my $s;
    my $rfh = newReadFileHandle( $inFile, "readFasta", 1 );
    if ( !$rfh ) {
        webLog("readFasta: WARNING: cannot read '$inFile'\n");
        return "";
    }
    my $seq;
    while ( $s = $rfh->getline() ) {
        chop $s;
        next if $s =~ /^>/;
        $s =~ s/\s+//g;
        $seq .= $s;
    }
    close $rfh;
    return $seq;
}

############################################################################
# readMultiFasta - Read multiple sequence Fasta file and return sequence.
#   Get starting position from index file.
############################################################################
sub readMultiFasta {
    my ( $inFile, $id ) = @_;
    my $rfh = newReadFileHandle( $inFile, "readMultiFasta", 1 );
    if ( !$rfh ) {
        webLog("readMultiFasta: cannot read '$inFile'\n");
        return "";
    }
    my $pos     = -1;
    my $idxFile = "$inFile.idx";
    my $rfh2    = newReadFileHandle( $idxFile, "readMultiFasta", 1 );
    if ( !$rfh2 ) {
        webLog("readMultiFasta: cannot read '$idxFile'\n");
    } else {
        while ( my $s = $rfh2->getline() ) {
            chomp $s;
            my ( $id2, $pos2 ) = split( / /, $s );
            if ( $id2 eq $id ) {
                $pos = $pos2;
                last;
            }
        }
        close $rfh2;
    }
    if ( $pos == -1 ) {
        webLog("readMultiFasta: cannot find index for $inFile:'$id'\n");
        $pos = 0;
    }
    my $seq;
    seek( $rfh, $pos, 0 );
    my $inBlock = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        last if ( $seq ne "" && ( $s =~ /^>/ || blankStr($s) ) );
        if ( $s =~ /^>/ && $seq eq "" ) {
            $s =~ s/^>//;
            my ( $id2, undef ) = split( / /, $s );
            if ( $id2 eq $id ) {
                $inBlock = 1;
                next;
            }
        }
        if ($inBlock) {
            $s =~ s/\s+//g;
            $seq .= $s;
        }
    }
    close $rfh;
    return $seq;
}

############################################################################
# readLinearFasta - Read linearized and indexed FASTA.
#  Linearized version of FASTA has the sequence all in one line.
############################################################################
sub readLinearFasta {
    my ( $inFile, $id, $start_coord, $end_coord, $strand, $adjustedCoordLines_ref ) = @_;

   #print("readLinearFasta() inFile=$inFile, id=$id, start_coord=$start_coord, end_coord=$end_coord, strand=$strand, adjustedCoordLines_ref=@$adjustedCoordLines_ref<br/>\n");

    webLog("Reading file: $inFile\n");
    my $rfh = newReadFileHandle( $inFile, "readLinearFasta", 1 );
    if ( !$rfh ) {
        webLog("WARNING: readLinearFasta() cannot read '$inFile'\n");
        return "";
    }

    my $idxFile = "$inFile.idx";

    #print("readLinearFasta() inFile.idx=$inFile.idx<br/>\n");
    webLog("Reading file: $idxFile\n");

    my ( $pos1, $pos2 ) = ( -1, -1 );
    my $rfh2    = newReadFileHandle( $idxFile, "readLinearFasta", 1 );
    if ( !$rfh2 ) {
        webLog("WARNING: readLinearFasta() cannot read '$idxFile'\n");
        return "";
    } else {
        while ( my $s = $rfh2->getline() ) {
            chomp $s;
            my ( $id2, $pos1x, $pos2x ) = split( / /, $s );
            if ( $id2 eq $id ) {
                $pos1 = $pos1x;
                $pos2 = $pos2x;
                last;
            }
        }
        close $rfh2;
    }
    webLog("Index position for $id: $pos1, $pos2\n");

    if ( $pos1 == -1 ) {
        webLog("WARNING: readLinearFasta() cannot find index for $inFile:'$id'\n");
        return "";
    }

    #print("readLinearFasta() pos1=$pos1, pos2 = $pos2<br/>\n");

    if ( $start_coord > $end_coord ) {
        webLog("WARNING: readLinearFasta() bad start_coord=$start_coord end_coord=$end_coord\n");
        return "";
    }
    if ( $start_coord == 0 && $end_coord == 0 ) {
        $start_coord = 1;
        $end_coord   = $pos2 - $pos1 + 1;
    }

    my $pos1r = $pos1 + $start_coord - 1;
    if ( $pos1r < 0 ) {
        webLog("WARNING: readLinearFasta() bad pos1r=$pos1r\n");
        return "";
    }

    my $len   = $end_coord - $start_coord + 1;
    my $pos2r = $pos1r + $len - 1;
    if ( $pos2r > $pos2 ) {
        webLog("WARNING: readLinearFasta() bad pos2r=$pos2r > pos2=$pos2; resetting\n");
        $pos2r = $pos2;
        $len   = $pos2r - $pos1r + 1;
    }

    #print("readLinearFasta() pos1r=$pos1r, pos2r = $pos2r<br/>\n");

    my $seq;
    if ( $adjustedCoordLines_ref && scalar(@$adjustedCoordLines_ref) > 1 ) {

        #print("readLinearFasta() adjustment adjustedCoordLines_ref=@$adjustedCoordLines_ref<br/>\n");
        my $coordsSize = scalar(@$adjustedCoordLines_ref);
        my $cnt;
        for my $frag (@$adjustedCoordLines_ref) {
            my ( $fragStart, $fragEnd ) = split( /\.\./, $frag );

            my $fragPos1r = $pos1 + $fragStart - 1;
            if ( $fragPos1r > $pos2 ) {
                webLog("WARNING: readLinearFasta() bad fragPos1r=$fragPos1r > pos2=$pos2; skipping\n");
                next;
            }
            my $fragLen   = $fragEnd - $fragStart + 1;
            my $fragPos2r = $fragPos1r + $fragLen - 1;
            if ( $fragPos2r > $pos2 ) {
                webLog("WARNING: readLinearFasta() bad fragPos2r=$fragPos2r > pos2=$pos2; resetting\n");
                $fragPos2r = $pos2;
                $fragLen   = $fragPos2r - $fragPos1r + 1;
            }

            #print("readLinearFasta() adjusted frag = $frag, fragPos1r=$fragPos1r, fragPos2r=$fragPos2r, fragLen=$fragLen<br/>\n");

            my $fragSeq;
            seek( $rfh, $fragPos1r, 0 );
            read( $rfh, $fragSeq, $fragLen ) if $fragLen > 0;

            #print("readLinearFasta() fragSeq = $fragSeq<br/>\n");
            $seq .= $fragSeq;

            $cnt++;
        }
    } else {
        seek( $rfh, $pos1r, 0 );
        read( $rfh, $seq, $len ) if $len > 0;
    }
    close $rfh;

    $strand = "+" if $strand eq "";
    if ( $strand eq "-" ) {
        my $rseq = reverse($seq);
        $rseq =~ tr/actgACTG/tgacTGAC/;
        return $rseq;
    }
    return $seq;
}

############################################################################
# parseBlastTab - Parse BLAST tab delimited output.
############################################################################
sub parseBlastTab {
    my ($s) = @_;

    my %blast_h;
	@blast_h{ qw( qid sid percIdent alen nMisMatch nGaps qstart qend sstart send evalue bitscore ) } = split /\t/, $s;
	return \%blast_h;

    my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
      split( /\t/, $s );
    my $hash_ref = {
        qid       => $qid,
        sid       => $sid,
        percIdent => $percIdent,
        alen      => $alen,
        nMisMatch => $nMisMatch,
        nGaps     => $nGaps,
        qstart    => $qstart,
        qend      => $qend,
        sstart    => $sstart,
        send      => $send,
        evalue    => $evalue,
        bitScore  => $bitScore,
    };
    return $hash_ref;
}

############################################################################
# massageToUrl  - Massage string for GET method URL.
############################################################################
sub massageToUrl {
    my ($s) = @_;
    my $len = length($s);
    my $s2;
    for ( my $i = 0 ; $i < $len ; $i++ ) {
        my $c = substr( $s, $i, 1 );
        if ( $c eq " " ) {
            $s2 .= "+";
        } elsif ( index( ":+\%&?\"^'=><;`\@\$[]{}#\\", $c ) >= 0 ) {
            $s2 .= '%' . sprintf( "%02x", ord($c) );
        } else {
            $s2 .= $c;
        }
    }
    return $s2;
}

############################################################################
# massageToUrl  version 2 using CGI escape
# get the text so things like + sign should be  - plus sign = %2B
#
# good for url's
############################################################################
sub massageToUrl2 {
    my ($text) = @_;

    return CGI::escape($text);
}

############################################################################
# hiddenVar - Hidden variable.
############################################################################
sub hiddenVar {
    my ( $tag, $val ) = @_;
    my $val2 = escapeHTML($val);
    my $s    = "<input type='hidden' id='$tag' name='$tag' value='$val2' />\n";
    return $s;
}

#
# web exit
# this should be use instead of the perl exit command
# - ken
#
sub webExit {
    my ($code) = @_;

    $code = 0 if ! $code;

    dbLogoutImg();
    dbLogoutGold();
    exit $code;
}

############################################################################
# webError - Show error message.
############################################################################
sub webError {
    my ( $txt, $exitcode, $noHtmlEsc ) = @_;

    if ($img_ken) {
        print "Content-type: text/html\n\n";    # test from ken

        my @names = param();
        foreach my $p (@names) {
            my $x = param($p);
            print "$p => $x <= <br>\n";
        }
    }
    my $copyright_year = $env->{copyright_year};
    my $version_year   = $env->{version_year};

    my $remote_addr = $ENV{REMOTE_ADDR} // '';
    my $servername;
    my $s = getHostname();
    $servername = $s . ' ' . ( $ENV{ORA_SERVICE} || "" ) . ' ' . $];
    my $buildDate = file2Str( "$base_dir/buildDate", 1 ) // '';

    print "<div id='error'>\n";
    print "<img src='$base_url/images/error.gif' " . "width='46' height='46' alt='Error' />\n";
    print "<p>\n";
    if ( defined $noHtmlEsc && $noHtmlEsc == 0 ) {
        print escHtml($txt);
    } else {
        print $txt;
    }
    print "</p>\n";
    print "</div>\n";
    print "<div class='clear'></div>\n";
    my $templateFile = "$base_dir/footer.html";
    my $str            = file2Str($templateFile);
    $str =~ s/__main_cgi__/$main_cgi/g;
    $str =~ s/__google_analytics__//g;

    $str =~ s/__copyright_year__/$copyright_year/;
    $str =~ s/__version_year__/$version_year/;

    $str =~ s/__server_name__/$servername/;
    $str =~ s/__build_date__/$buildDate $remote_addr/;
    $str =~ s/__post_javascript__//;

    print "$str\n";

    printStatusLine( "Error", 2 );
    webExit($exitcode);
}

############################################################################
# webErrorHeader - Show error with header.
############################################################################
sub webErrorHeader {
    my ( $msg, $noHtmlEsc, $exitcode ) = @_;

    print header( -type => "text/html" );
    print "<br>\n";
    webError( $msg, $exitcode, $noHtmlEsc );

    #    if ($noHtmlEsc) {
    #        print $msg;
    #    } else {
    #        print escHtml($msg);
    #    }
    #    webExit($exitcode);
}

############################################################################
# printHint - Print hint box with message.
############################################################################
sub printHint2 {
    my ($txt) = @_;
    print "<div id='hint'>\n";
    print "<img src='$base_url/images/hint.gif' " . "width='67' height='32' alt='Hint' />";
    print "<div>\n";
    print "<table cellpadding=0 border=0>";
    print $txt;
    print "</table>";
    print "</div>\n";
    print "</div>\n";
    print "<div class='clear'></div>\n";
}

############################################################################
# printHint - Print hint box with message.
############################################################################
sub printHint {
    my ( $txt, $maxwidth ) = @_;
    if ( $maxwidth ne '' ) {
        print "<div id='hint' style='width:" . $maxwidth . "px;'>\n";
    } else {
        print "<div id='hint'>\n";
    }
    print "<img src='$base_url/images/hint.gif' " . "width='67' height='32' alt='Hint' />";
    print "<p>\n";
    print $txt;
    print "</p>\n";
    print "</div>\n";
    print "<div class='clear'></div>\n";
}

############################################################################
# printWideHint - Print hint box with message.
############################################################################
sub printWideHint {
    my ($txt) = @_;
    print "<div id='hint' style='width: 400px;'>\n";
    print "<img src='$base_url/images/hint.gif' " . "width='67' height='32' alt='Hint' />";
    print "<p>\n";
    print $txt;
    print "</p>\n";
    print "</div>\n";
    print "<div class='clear'></div>\n";
}

############################################################################
# printMessage - Print boxed message.
############################################################################
sub printMessage {
    my ($html) = @_;
    print "<div id='message'>\n";
    print "<p>\n";
    print "$html\n";
    print "</p>\n";
    print "</div>\n";
}

############################################################################
# webDie - Code dies a serious death.   Show on web.
############################################################################
sub webDie {
    my ($s) = @_;

    #webError($s);
    print "Content-type: text/html\n\n";
    print header( -status => '404 Not Found' );
    print "<html>\n";
    print "<p>\n";
    print "SCRIPT ERROR:\n";
    print "<p>\n";
    print "<font color='red'>\n";
    print "<b>$s</b>\n";
    print "</font>\n";

    webExit(0);
}

############################################################################
# flushBrowser - Flush browser buffering for progress indication.
############################################################################
sub flushBrowser {
    print " " x 100000;
}

############################################################################
# nbsp - "space" character in HTML.
############################################################################
sub nbsp {
    my ($cnt) = @_;
    my $s;
    for ( my $i = 0 ; $i < $cnt ; $i++ ) {
        $s .= "&nbsp; ";
    }
    return $s;
}

############################################################################
# dbLogin - Login to oracle or some RDBMS and return handle.
############################################################################
sub dbLogin {
    if ( defined $DBH_IMG ) {

        #http://search.cpan.org/~pythian/DBD-Oracle-1.64/lib/DBD/Oracle.pm#ping
        #        my  $rv = $DBH_IMG->ping;
        #        if($rv) {
        webLog("img using pooled connection \n");
        return $DBH_IMG;

        #        }
    }

    if ( $ora_port ne "" && $ora_host ne "" && $ora_sid ne "" ) {
        $dsn = "dbi:Oracle:host=$ora_host;port=$ora_port;sid=$ora_sid;";
    }

    my $mask   = POSIX::SigSet->new(SIGALRM);    # signals to mask in the handler
    my $action = POSIX::SigAction->new(
        sub {
        	webErrorHeader("Database connection timeout. UI is waiting too long. Please try again later.");
        },       # the handler code ref
        $mask # not using (perl 5.8.2 and later) 'safe' switch or sa_flags
    );

    my $oldaction = POSIX::SigAction->new();
    sigaction( 'ALRM', $action, $oldaction );
    my $dbh;
    eval {
        alarm($dbLoginTimeout);                  # seconds before time out
        $dbh = DBI->connect( $dsn, $user, pwDecode($pw) );
        alarm(0);                                # cancel alarm (if connect worked fast)
    };
    alarm(0);                                    # cancel alarm (if eval failed)

    # restore original signal handler
    sigaction( 'ALRM', $oldaction );
    alarm($timeoutSec) if ( $timeoutSec ne '' && $timeoutSec > 0 );

    if ($@) {
        webError("$@");
    } elsif ( !defined($dbh) ) {
        my $error = $DBI::errstr;

        #webLog("$error\n");
        if ( $error =~ "ORA-00018" ) {

            # "ORA-00018: maximum number of sessions exceeded"
            webErrorHeader( "<br/> Sorry, database is very busy. " . "Please try again later. <br/> $error", 1 );
        } else {
            webErrorHeader(
                "<br/>  This is embarrassing. Sorry, database is down. " . "Please try again later. <br/> $error", 1 );
        }
    }
    $dbh->{LongReadLen} = $maxClobSize;
    $dbh->{LongTruncOk} = 1;

    $DBH_IMG = $dbh;

    my $max = getMaxSharedConn($dbh);
    $max = $max * 0.9;    # 90% threshold
    my $opn = getOpenSharedConn($dbh);
    webLog("max = $max , open = $opn\n");
    if ( !$env->{ignore_db_check} && $opn >= $max ) {
        webErrorHeader( "<br>We are sorry. The database is very busy ($opn, $max). Please try again later. <br> ", 1 );
    }

    return $dbh;
}

#
# max number of possible shared connections
#
sub getMaxSharedConn {
    my ($dbh) = @_;

    if ( $env->{img_edu} ) {

#SELECT name, value
#  FROM v$parameter
# WHERE name = 'sessions'
        return 200;
    } else {
        return 500; # all other img system
    }

    my $sql = qq{
select value from v\$parameter where name = 'max_shared_servers'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();

    return $cnt;
}

#
# the number of current open shared connections
#
# I should take 80% ??? of the max to test against to throw a db busy message
#
sub getOpenSharedConn {
    my ($dbh) = @_;
    my $sql = qq{
select count(*) from v\$session where server != 'DEDICATED'
    };

    if ( $env->{img_edu} ) {
        $sql = qq{
select count(*) from v\$session
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();

    return $cnt;
}

sub dbGoldLogin {
    my ($isAjaxCall) = @_;

    if ( defined $DBH_GOLD ) {

        #        my  $rv = $DBH_GOLD->ping;
        #        if($rv) {
        webLog("gold using pooled connection \n");
        return $DBH_GOLD;

        #        }
    }

    # use the new database imgsg_dev
    my $user;        #     = "imgsg_dev";
    my $pw;          #       = decode_base64('VHVlc2RheQ==');
    my $ora_host;    # = 'muskrat.jgi-psf.org';                 #"jericho.jgi-psf.org";
    my $ora_port;    # = "";
    my $ora_sid;     #  = "imgiprd";
    my $dsn;         #      = "dbi:Oracle:" . $ora_sid;

    my $img_ken_localhost      = $env->{img_ken_localhost};
    my $img_gold_oracle_config = $env->{img_gold_oracle_config};

    if ($img_ken_localhost) {

        # used by ken for local testing only!

        $user = "imgsg_dev";
        $pw   = decode_base64('VHVlc2RheQ==');

        $ora_host = "localhost";
        $ora_port = "1531";
        $ora_sid  = "imgiprd";
    } elsif ($img_gold_oracle_config) {

        require $img_gold_oracle_config;
        $dsn      = $ENV{ORA_DBI_DSN_GOLD};
        $user     = $ENV{ORA_USER_GOLD};
        $pw       = pwDecode( $ENV{ORA_PASSWORD_GOLD} );
        $ora_port = "";
        $ora_sid  = "";
        $ora_host = "";

        #webLog("===== using gold snapshot db ===========\n");
    }

    if ( $ora_port ne "" ) {
        $dsn = "dbi:Oracle:host=$ora_host;port=$ora_port;sid=$ora_sid";
    }

    my $mask   = POSIX::SigSet->new(SIGALRM);    # signals to mask in the handler
    my $action = POSIX::SigAction->new(
        sub {
            if ($isAjaxCall) {
                return '';
                webExit(0);
            } else {
                webErrorHeader("GOLD database connection timeout. UI is waiting too long. Please try again later.");
            }

        },                                       # the handler code ref
        $mask

          # not using (perl 5.8.2 and later) 'safe' switch or sa_flags
    );

    my $oldaction = POSIX::SigAction->new();
    sigaction( 'ALRM', $action, $oldaction );
    my $dbh;
    eval {
        alarm($dbLoginTimeout);                  # seconds before time out
        $dbh = DBI->connect( $dsn, $user, pwDecode($pw) );
        alarm(0);                                # cancel alarm (if connect worked fast)
    };
    alarm(0);                                    # cancel alarm (if eval failed)

    # restore original signal handler
    sigaction( 'ALRM', $oldaction );
    alarm($timeoutSec) if ( $timeoutSec ne '' && $timeoutSec > 0 );

    if ($@) {
        webError("$@");
    } elsif ( !defined($dbh) ) {
        my $error = $DBI::errstr;

        #webLog("$error\n");
        if ( $error =~ "ORA-00018" ) {

            # "ORA-00018: maximum number of sessions exceeded"
            webErrorHeader( "<br/> DB GOLD: Sorry, database is very busy. " . "Please try again later. <br/> $error", 1 );
        } else {
            webErrorHeader(
                "<br/> DB GOLD: This is embarrassing. Sorry, database is down. " . "Please try again later. <br/> $error",
                1 );
        }
    }
    $dbh->{LongReadLen} = $maxClobSize;
    $dbh->{LongTruncOk} = 1;

    $DBH_GOLD = $dbh;
    return $dbh;
}

#
# logout of img
#
sub dbLogoutImg {
    if ( defined $DBH_IMG ) {
        webLog("img pooled connection logout\n");
        $DBH_IMG->disconnect();
        undef $DBH_IMG;
    }

    stackTrace("WebUtil::dbLogoutImg()");
}

#
# logout of gold
#
sub dbLogoutGold {
    if ( defined $DBH_GOLD ) {
        webLog("gold pooled connection logout\n");
        $DBH_GOLD->disconnect();
        undef $DBH_GOLD;
    }
}

############################################################################
# execSql - Convenience wrapper to execute an SQL.
############################################################################
sub execSql {
    my ( $dbh, $sql, $verbose, @args ) = @_;
    webLog("$sql\n") if ( $verbose >= $show_sql_verbosity_level );
    my $nArgs = @args;
    if ( $nArgs > 0 ) {
        my $s;
        for ( my $i = 0 ; $i < $nArgs ; $i++ ) {
            my $a = $args[$i];
            $s .= "arg[$i] '$a'\n";
        }
        webLog($s) if ( $verbose >= $show_sql_verbosity_level );
    }
    my $cur = $dbh->prepare($sql)
      or webDie("execSql: cannot preparse statement: $DBI::errstr\n");
    $cur->execute(@args)
      or webDie("execSql: cannot execute: $DBI::errstr\n");
    return $cur;
}

############################################################################
# execSqlOnly - Convenience wrapper to execute an SQL. This does not
#   do any fetches.
############################################################################
sub execSqlOnly {
    my ( $dbh, $sql, $verbose, @args ) = @_;
    webLog("$sql\n") if ( $verbose >= $show_sql_verbosity_level );
    my $cur = $dbh->prepare($sql)
      or webDie("execSql: cannot preparse statement: $DBI::errstr\n");
    my $nArgs = @args;
    if ( $nArgs > 0 ) {
        my $s;
        for ( my $i = 0 ; $i < $nArgs ; $i++ ) {
            my $a = $args[$i];
            $s .= "arg[$i] '$a'\n";
        }
        webLog($s) if ( $verbose >= $show_sql_verbosity_level );
    }
    $cur->execute(@args)
      or webDie("execSql: cannot execute: $DBI::errstr\n");
    $cur->finish();
}

############################################################################
# execSqlBind - Convenience wrapper to execute an SQL with bind params.
#
# param $dbh - database handler
# param $sql - sql with '?' in the where clause statement
# param $bindList_aref - binding list of values
# param $verbose
# return sql execute cursor
#
# - ken
############################################################################
sub execSqlBind {
    my ( $dbh, $sql, $bindList_aref, $verbose ) = @_;
    webLog "$sql\n"             if ( $verbose >= $show_sql_verbosity_level );
    webLog("@$bindList_aref\n") if ( $verbose >= $show_sql_verbosity_level );
    my $cur = $dbh->prepare($sql)
      or webDie("execSqlBind: cannot preparse statement: $DBI::errstr\n");
    for ( my $i = 0 ; $i <= $#$bindList_aref ; $i++ ) {
        $cur->bind_param( ( $i + 1 ), $bindList_aref->[$i] )
          or webDie("execSqlBind: cannot bind param: $DBI::errstr\n");
    }
    $cur->execute()
      or webDie("execSqlBind: cannot execute: $DBI::errstr\n");
    return $cur;
}

############################################################################
# prepSql - Prepare SQL wrapper.
############################################################################
sub prepSql {
    my ( $dbh, $sql, $verbose ) = @_;
    webLog "$sql\n" if $verbose >= 1;
    my $cur = $dbh->prepare($sql)
      or webDie("prepSql: cannot preparse statement: $DBI::errstr\n");
    return $cur;
}

############################################################################
# execStmt - Execute SQL statement.
############################################################################
sub execStmt {
    my ( $cur, @vars ) = @_;
    $cur->execute(@vars)
      or webDie("execStmt: cannot execute $DBI::errstr\n");
}

############################################################################
# toolTipCode - Tool tip code. Show tool tip code.
############################################################################
sub toolTipCode {
    my $s = "<script language='JavaScript' type='text/javascript'\n";
    $s .= "src='$base_url/wz_tooltip.js'></script>\n";
    return $s;
}

############################################################################
# attrLabel - Attribute label format.
#   Wrapper for future special formatting.
############################################################################
sub attrLabel {
    my ($s) = @_;
    my $s2 = escHtml($s);
    return $s2;
}

############################################################################
# attrValue - Attribute value format.
#   Wrapper for future special formatting.
############################################################################
sub attrValue {
    my ($s) = @_;
    my $s2 = escHtml($s);
    return $s2;
}

############################################################################
# alink - Anchor link.
############################################################################
sub alink {
    my ( $url, $text, $target, $isHtmlText, $useDoubleQuote, $onclick ) = @_;
    my $t = '';
    $t = "target=$target"     if $target;
    $t = "target=$linkTarget" if $linkTarget;
	# define onclick as an empty string if it is not defined
    $onclick //= '';

    # plus sign = %2B
    #$url =~ s/\+/%2B/g;
    # cgi url escape
    #http://cpansearch.perl.org/src/LDS/CGI.pm-3.48/cgi_docs.html
    #$url = CGI::escape($url);

    my $s;
    if ($useDoubleQuote) {
        $s = "<a href=\"$url\" $t onclick=\"$onclick\">";
    } else {
        $s = "<a href='$url' $t onclick=\"$onclick\">";
    }

    if ($isHtmlText) {
        $s .= $text;
    } else {
        $s .= escHtml($text);
    }
    $s .= "</a>";
    return $s;
}

############################################################################
# alinkNoTarget - Anchor link. Local version. No target window.
############################################################################
sub alinkNoTarget {
    my ( $url, $text, $target, $isHtmlText ) = @_;
    my $s = "<a href='$url'>";
    if ($isHtmlText) {
        $s .= $text;
    } else {
        $s .= escHtml($text);
    }
    $s .= "</a>";
    return $s;
}

############################################################################
# aNumLink - Do anchor link for number except if it is 0.
############################################################################
sub aNumLink {
    my ( $url, $n ) = @_;
    if ( blankStr($n) ) {

        #return nbsp( 1 );
        return "0";
    }
    if ( $n == 0 ) {
        return $n;
    }
    return alink( $url, $n );
}

############################################################################
# alinkPad - Do anchor link with padding of text so fields are uniform.
############################################################################
sub alinkPad {
    my ( $url, $text ) = @_;
    my $s2 = $text;
    $s2 =~ s/\s+$//;
    my $padLen = length($text) - length($s2);
    my $pad    = " " x $padLen;
    my $s3     = alink( $url, $s2 ) . $pad;
}

############################################################################
# printAttrRow - Print one attribute row in a table.
############################################################################
sub printAttrRow {
    my ( $attrName, $attrVal, $url ) = @_;
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>$attrName</th>\n";
    my $val = attrValue($attrVal);
    if ( $url ne "" ) {
        $val = alink( $url, $attrVal );
    }
    print "  <td class='img'   align='left'>" . $val . "</td>\n";
    print "</tr>\n";
}

############################################################################
# printOptAttrRow - Print one attribute row in a table optionally.
############################################################################
sub printOptAttrRow {
    my ( $attrName, $attrVal, $url ) = @_;
    return if $attrVal eq "";
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>$attrName</th>\n";
    my $val = attrValue($attrVal);
    if ( $url ne "" ) {
        $val = alink( $url, $attrVal );
    }
    print "  <td class='img'   align='left'>" . $val . "</td>\n";
    print "</tr>\n";
}

############################################################################
# printAttrRowRaw - Print one attribute row in a table, w/o
#  HTML escaping.
############################################################################
sub printAttrRowRaw {
    my ( $attrName, $attrVal ) = @_;
    $attrVal = nbsp(1) if blankStr($attrVal);
    print "<tr class='img' >\n";
    print "  <th class='subhead' align='right'>$attrName</th>\n";
    print "  <td class='img'   align='left'>" . $attrVal . "</td>\n";
    print "</tr>\n";
}

############################################################################
# printHiliteAttrRow - Print one attribute row in a table.
############################################################################
sub printHiliteAttrRow {
    my ( $attrName, $attrVal, $url ) = @_;
    print "<tr class='highlight'>\n";
    print "  <th class='subhead' align='right'>$attrName</th>\n";
    my $val = attrValue($attrVal);
    if ( $url ne "" ) {
        $val = alink( $url, $attrVal );
    }
    print "  <td class='img'   align='left'>" . $val . "</td>\n";
    print "</tr>\n";
}

############################################################################
# highlightMatchHTML - Highlight via HTML for gene search results.
############################################################################
sub highlightMatchHTML {
    my ( $str, $matchStr ) = @_;
    my $str_u      = $str;
    my $matchStr_u = $matchStr;
    $str_u      =~ tr/a-z/A-Z/;
    $matchStr_u =~ tr/a-z/A-Z/;
    my $idx = index( $str_u, $matchStr_u );
    my $targetMatchStr = substr( $str, $idx, length($matchStr) );
    return escHtml($str) if $idx < 0;
    my $part1 = escHtml( substr( $str, 0, $idx ) );
    my $part2 = escHtml($targetMatchStr);
    my $part3 = escHtml( substr( $str, $idx + length($matchStr) ) );
    return $part1 . "<font color='green'><b>" . $part2 . "</b></font>" . $part3;
}

############################################################################
# highlightMatchHTML_p12 - Highlight via HTML for gene search results.
#   Parts 1 and 2.
############################################################################
sub highlightMatchHTML_p12 {
    my ( $str, $matchStr, $noesc ) = @_;
    my $str_u      = $str;
    my $matchStr_u = $matchStr;
    $str_u      =~ tr/a-z/A-Z/;
    $matchStr_u =~ tr/a-z/A-Z/;
    my $idx = indexUnderscore( $str_u, $matchStr_u );
    my $targetMatchStr = substr( $str, $idx, length($matchStr) );
    if ( $idx < 0 ) {

        if ($noesc) {
            return $str;
        } else {
            return escHtml($str);
        }
    }

    my $part1 = '';
    my $part2 = '';
    if ($noesc) {
        $part1 = substr( $str, 0, $idx );
        $part2 = $targetMatchStr;
    } else {
        $part1 = escapeHTML( substr( $str, 0, $idx ) );
        $part2 = escapeHTML($targetMatchStr);
    }

    return ( $part1 . "<font color='green'><b>" . $part2 . "</b></font>", $idx + length($matchStr) );
}

############################################################################
# indexUnderscore - Index with undersore escape.
############################################################################
sub indexUnderscore {
    my ( $str, $mstr ) = @_;
    if ( $mstr !~ /_/ ) {
        return index( $str, $mstr );
    }
    my @mtoks = split( /_/, $mstr );
    my $len = length($str);
    for ( my $i = 0 ; $i < $len ; $i++ ) {
        my $idx   = $i;
        my $s2    = substr( $str, $i );
        my $match = 1;
        for my $mtok (@mtoks) {
            my $idx2 = index( $s2, $mtok );
            if ( $idx2 != 0 ) {
                $match = 0;
                last;
            }
            $s2 = substr( $s2, length($mtok) + 1 );
        }
        return $i if $match;
    }
    return -1;
}

############################################################################
# highlightMatchHtml2 - 2nd version.
############################################################################
sub highlightMatchHTML2 {
    my ( $str, $matchStr, $noesc ) = @_;
    my (@matchToks) = split( /[%]/, $matchStr );
    my $nMatchToks  = @matchToks;
    my $idx         = 0;
    my $s;
    for my $mt (@matchToks) {
        my $s2 = substr( $str, $idx );
        my ( $hiliteStr, $idx2 ) = highlightMatchHTML_p12( $s2, $mt, $noesc );
        $idx += $idx2;
        if ( $idx > 0 ) {
            $s .= $hiliteStr;
        }

        #print "highlightMatchHTML2 \$hiliteStr: $hiliteStr   \$s: $s  \$idx: $idx<br/>";
    }
    my $p3 = substr( $str, $idx ) if $idx > 0;
    $s .= "$p3";

    #print "highlightMatchHTML2 \$s: $s<br/>";
    if ( $s eq '' ) {
        $s = $str;
    }

    #print "highlightMatchHTML2 \$s: $s<br/><br/><br/>";
    return $s;
}

############################################################################
# highlightMatchHtml3 - comma split version.
############################################################################
sub highlightMatchHTML3 {
    my ( $str, $matchStr, $noesc ) = @_;
    my (@matchToks) = splitTerm( $matchStr, 0, 0 );
    for my $mt (@matchToks) {
        my $s = highlightMatchHTML2( $str, $mt, $noesc );
        if ( rindex( $s, "<font color='green'><b>" ) >= 0 ) {
            return $s;
        }
    }
    return $str;
}

############################################################################
# printGeneTableExport - Print gene table for exporting.
############################################################################
sub printGeneTableExport {
    my ($gene_oids_ref) = @_;
    my $gene_oid_str = join( ",", @$gene_oids_ref );
    return if blankStr($gene_oid_str);

    my $dbh = dbLogin();
    my $sql = qq{
       select g.gene_oid, g.gene_display_name, g.locus_tag, g.gene_symbol,
         tx.taxon_oid, tx.ncbi_taxon_id, tx.genus, tx.species
       from taxon tx, gene g
       where g.taxon = tx.taxon_oid
       and g.gene_oid in ( $gene_oid_str )
       order by tx.taxon_display_name, g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $locus_tag, $gene_symbol, $taxon_oid, $ncbi_taxon_id, $genus, $species ) =
          $cur->fetchrow();
        last if !$gene_oid;
        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$locus_tag\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$genus\t";
        $rec .= "$species";
        push( @recs, $rec );
    }
    my %done;
    print "<b>gene_oid</b>\t";
    print "<b>locus_tag</b>\t";
    print "<b>gene_symbol</b>\t";
    print "<b>description</b>\n";
    for my $r (@recs) {
        my ( $gene_oid, $gene_display_name, $locus_tag, $gene_symbol, $taxon_oid, $ncbi_taxon_id, $genus, $species ) =
          split( /\t/, $r );
        next if $done{$gene_oid} ne "";

        print "$gene_oid\t";
        print "$locus_tag\t";
        print "$gene_symbol\t";
        print "$gene_display_name [$genus $species]\n";
        $done{$gene_oid} = 1;
    }
    $cur->finish();

    #$dbh->disconnect();
}

############################################################################
# getSessionId - Get session ID.
############################################################################
sub getSessionId {
    return $g_session->id();
}

############################################################################
# getSession - Get session cookie
############################################################################
sub getSession {
    return $g_session;
}

############################################################################
# getSessionParam - Get session parameter.
############################################################################
sub getSessionParam {
    my ($arg) = @_;
    return $g_session->param($arg);
}

############################################################################
# getContactOid - Get current contact_oid for user restricted site.
############################################################################
sub getContactOid {
    if ( ! $user_restricted_site && ! $public_login ) {
        return 0;
    }
    return getSessionParam("contact_oid");
}

############################################################################
# getUserName - Get username
# user - login id
############################################################################
sub getUserName {
    if ( !$user_restricted_site && !$public_login ) {
        return "";
    }
    return getSessionParam("username");
}

# gets users "name" from contact table
sub getUserName2 {
    if ( !$user_restricted_site && !$public_login ) {
        return "";
    }
    return getSessionParam("name");
}

############################################################################
# getSuperUser - Get contact.super_user status.
############################################################################
sub getSuperUser {
    if ( !$user_restricted_site ) {
        return "";
    }
    return getSessionParam("super_user");
}

############################################################################
# isImgEditor - See if contact_oid is img_editor for certain
#   priveleges.
############################################################################
sub isImgEditor {
    my ( $dbh, $contact_oid ) = @_;
    return 0 unless $contact_oid;
    return 0 if 901 == $contact_oid;

    my $x = getSessionParam("editor");
    #webLog("editor == $x \n");

    return $x if defined $x;

    my $sql = qq{
       select img_editor
       from contact
       where contact_oid = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my ($img_editor) = $cur->fetchrow();

    $cur->finish();

    if ( $img_editor eq "Yes" ) {
        setSessionParam( "editor", 1 );
    } else {
        setSessionParam( "editor", 0 );
    }

    return 1 if $img_editor eq "Yes";
    return 0;
}
## Wrapped version, no extern db login.
sub isImgEditorWrap {
    my $contact_oid = getContactOid();
    return 0 if ! $contact_oid;
    my $dbh = dbLogin();
    my $b   = isImgEditor( $dbh, $contact_oid );

    #$dbh->disconnect();
    return $b;
}

############################################################################
# canEditGeneTerm - whether this contact can edit gene-term assoc
############################################################################
sub canEditGeneTerm {
    my ( $dbh, $contact_oid ) = @_;
    return 0 if !$contact_oid;

    if ( isImgEditor( $dbh, $contact_oid ) ) {
        return 1;
    }

    my $x = getSessionParam("img_editing_level");
    if ( $x ne "" ) {
        return $x;
    }

    my $sql = qq{
       select img_editing_level
       from contact
       where contact_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my ($editing_level) = $cur->fetchrow();
    $cur->finish();

    if ( !$editing_level ) {
        setSessionParam( "img_editing_level", 0 );
        return 0;
    } elsif ( $editing_level =~ /gene\-term/ ) {
        setSessionParam( "img_editing_level", 1 );
        return 1;
    }

    return 0;
}

############################################################################
# canEditPathway - whether this contact can edit IMG pathway assertions.
############################################################################
sub canEditPathway {
    my ( $dbh, $contact_oid ) = @_;
    return 0 if !$contact_oid;

    if ( isImgEditor( $dbh, $contact_oid ) ) {
        return 1;
    }

    my $x = getSessionParam("img_editing_level");
    if ( $x ne "" ) {
        return $x;
    }

    my $sql = qq{
       select img_editing_level
       from contact
       where contact_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my ($editing_level) = $cur->fetchrow();
    $cur->finish();

    if ( !$editing_level ) {
        setSessionParam( "img_editing_level", 0 );
        return 0;
    } elsif ( $editing_level =~ /img\-pathway/ ) {
        setSessionParam( "img_editing_level", 1 );
        return 1;
    }

    return 0;
}

############################################################################
# canEditBin
############################################################################
sub canEditBin {
    my ( $dbh, $contact_oid ) = @_;
    return 0 if !$contact_oid;

    if ( isImgEditor( $dbh, $contact_oid ) ) {
        return 1;
    }
    my $x = getSessionParam("img_editing_level");
    if ( $x ne "" ) {
        return $x;
    }

    my $sql = qq{
       select img_editing_level
       from contact
       where contact_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my ($editing_level) = $cur->fetchrow();
    $cur->finish();

    if ( !$editing_level ) {
        setSessionParam( "img_editing_level", 0 );
        setSessionParam( "editor",            0 );
        return 0;
    } elsif ( $editing_level =~ /img\-bin/ ) {
        setSessionParam( "editor",            1 );
        setSessionParam( "img_editing_level", 1 );
        return 1;
    }

    return 0;
}

############################################################################
# setSessionParam - Set session parameter.
############################################################################
sub setSessionParam {
    my ( $arg, $val ) = @_;
    $g_session->param( $arg, $val );
}

############################################################################
# getTaxonCount - Get count of taxons for statistics purposes.
############################################################################
sub getTaxonCount {
    my ($dbh_param) = @_;
    my $dbh;
    if ( $dbh_param ne "" ) {
        $dbh = $dbh_param;
    } else {
        $dbh = dbLogin();
    }
    my $rclause   = urClause("tx");
    my $imgClause = imgClause('tx');
    my $sql       = qq{
      select count(*)
      from taxon tx
      where 1 = 1
      $rclause
      $imgClause
   };
    my $cur = execSql( $dbh, $sql, 0 );
    my $count = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect() if ( $dbh_param eq "" );
    return $count;
}

############################################################################
# getSelectedTaxonCount - Returns the number of selected taxons.
############################################################################
sub getSelectedTaxonCount {
    require GenomeCart;
    my $taxon_oids = GenomeCart::getAllGenomeOids();
    my $count      = @$taxon_oids;
    return $count;
}

############################################################################
# getUrOids - Get contact specific access to taxons.
############################################################################
sub getUrOids {
    my ($dbh) = @_;
    my $contact_oid = getContactOid();
    if ( !$contact_oid ) {
        webDie("Invalid session.");
    }
    my $sql = qq{
      select taxon_oid
      from taxon
      where is_public = 'Yes'
         union
      select taxon_permissions
      from contact_taxon_permissions
      where contact_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my @taxon_oids;
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        push( @taxon_oids, $taxon_oid );
    }
    $cur->finish();
    return @taxon_oids;
}

############################################################################
# setTaxonSelections - Set genome or taxon selections in the RDBMS
#   table.  This is used later for joins against genomes for subset
#   of the data.    This is activated by saving user selections
#   in the genome browser.
############################################################################
sub setTaxonSelections {
    my ($taxon_filter_oid_str) = @_;

    my @taxon_oids = split( /,/, $taxon_filter_oid_str );
    if ( @taxon_oids > 0 ) {
        require GenomeCart;
        GenomeCart::addToGenomeCart( \@taxon_oids );
    }
}

############################################################################
# isPangenome - returns 1 if this taxon_oid is a pangenome
############################################################################
sub isPangenome {
    my ($taxon_oid) = @_;

    my $enable_pangenome = $env->{enable_pangenome};

    # over 700 mill is hmp metag
    if ( $enable_pangenome && $taxon_oid >= 5000000000 && $taxon_oid < 7000000000 ) {
        return 1;
    }
    return 0;
}

############################################################################
# getTaxonFilterOidStr - Wrapper for handling list of taxons or all
#   taxons, which is an empty qualifier.
############################################################################
sub getTaxonFilterOidStr {
    require GenomeCart;
    my $taxon_oids = GenomeCart::getAllGenomeOids();
    my $taxon_oid_str = join( ',', @$taxon_oids );
    return $taxon_oid_str;
}

############################################################################
# txsClause - Taxon selection clause.
############################################################################
sub txsClause {
    my ( $aliasOrAttr, $dbh ) = @_;
    my $taxon_oid_attr = "taxon_oid";

    $taxon_oid_attr = "$aliasOrAttr.taxon_oid"
      if $aliasOrAttr ne ""
      && $aliasOrAttr ne "taxon_oid"
      && $aliasOrAttr !~ /\./;
    $taxon_oid_attr = $aliasOrAttr
      if $aliasOrAttr ne ""
      && $aliasOrAttr ne "taxon_oid"
      && $aliasOrAttr =~ /\./;
    my $taxon_filter_oid_str = getTaxonFilterOidStr();
    return "" if blankStr($taxon_filter_oid_str);

    my @taxons = split( ",", $taxon_filter_oid_str );
    my $s;

    if ( @taxons > 900 ) {
        $s = " and $taxon_oid_attr in (select id from gtt_taxon_oid) ";

        # insert taxons from genome cart into Oracle's global temp table
        require GenomeCart;
        GenomeCart::insertToGtt($dbh);
    } else {
        $s = " and $taxon_oid_attr in ($taxon_filter_oid_str) ";
    }

    return $s;
}

############################################################################
# txsObsoleteClause - taxon clause to show or not show obsolete taxon
#                   - default is to not show
#
# $aliasOrAttr - optional - table alias or full attribute eg t2.obsolete_flag
# $value - Yes or No optional default is No
# - 2009-12-08 ken
############################################################################
sub txsObsoleteClause {
    my ( $aliasOrAttr, $value ) = @_;
    my $taxon_oid_attr = "obsolete_flag";

    if (   $aliasOrAttr ne ""
        && $aliasOrAttr ne "obsolete_flag"
        && $aliasOrAttr !~ /\./ )
    {
        $taxon_oid_attr = "$aliasOrAttr.obsolete_flag";
    }

    if (   $aliasOrAttr ne ""
        && $aliasOrAttr ne "obsolete_flag"
        && $aliasOrAttr =~ /\./ )
    {
        my @x = split( /\./, $aliasOrAttr );
        $taxon_oid_attr = $x[0] . "." . "obsolete_flag";
    }

    if ( $value ne "" && lc($value) eq "yes" ) {
        $value = "Yes";
    } else {
        $value = "No";
    }

    my $nvl = getNvl();
    my $s   = " and $nvl($taxon_oid_attr,'No') = '$value' ";
    return $s;

}

############################################################################
# getTaxonFilterHash - Get taxon_oid filter as hash.
############################################################################
sub getTaxonFilterHash {
    my $taxon_filter_oid_str = getTaxonFilterOidStr();
    my @taxon_oids = split( /,/, $taxon_filter_oid_str );
    my %taxonFilterHash;
    for my $taxon_oid (@taxon_oids) {
        $taxonFilterHash{$taxon_oid} = $taxon_oid;
    }
    return \%taxonFilterHash;
}

############################################################################
# highlightRect - Highlight rectangular area (and fill) for Kegg maps.
############################################################################
sub highlightRect {
    my ( $im, $x, $y, $w, $h, $colorName ) = @_;

    if ( $w < 1 ) {
        webLog("highlightRect: bad w=$w\n");
        print STDERR "highlightRect: bad w=$w\n";
        return;
    }
    if ( $h < 1 ) {
        webLog("highlightRect: bad h=$h\n");
        print STDERR "highlightRect: bad h=$h\n";
        return;
    }

    my $rect = new GD::Image( $w, $h );

    if ( !$rect ) {
        webDie("highlightRect failed w, h = $w,$h color=$colorName  \n");
    }

    my $color;
    my $perc;
    if ( $colorName eq "green" ) {
        $color = $rect->colorAllocate( 0, 255, 0 );
        $perc = 40;
    } elsif ( $colorName eq "red" ) {
        $color = $rect->colorAllocate( 255, 50, 50 );
        $perc = 25;
    } elsif ( $colorName eq "blue" ) {
        $color = $rect->colorAllocate( 0, 0, 255 );
        $perc = 25;
    } elsif ( $colorName eq "orange" ) {
        $color = $rect->colorAllocate( 255, 165, 0 );
        $perc = 40;
    } elsif ( $colorName eq "cyan" ) {
        $color = $rect->colorAllocate( 0, 255, 255 );
        $perc = 25;
    } elsif ( $colorName eq "yellow" ) {
        $color = $rect->colorAllocate( 255, 255, 0 );
        $perc = 50;
    } else {
        webDie("highlightRect: unsupported color: '$colorName'\n");
    }
    $rect->filledRectangle( 0, 0, $w, $h, $color );
    $im->copyMerge( $rect, $x + 1, $y + 1, 0, 0, $w - 1, $h - 1, $perc );
    $rect->colorDeallocate($color);
}

############################################################################
# highlightRectRgb - Highlight rectangular area (and fill) for Kegg maps.
#   Use RGB specification.
############################################################################
sub highlightRectRgb {
    my ( $im, $x, $y, $w, $h, $r, $g, $b, $percentage ) = @_;
    my $rect = new GD::Image( $w, $h );
    my $color;
    my $perc = 40;
    if ( $percentage ne "" ) {
        $perc = $percentage;
    }
    $color = $rect->colorAllocate( $r, $g, $b );
    $rect->filledRectangle( 0, 0, $w, $h, $color );
    $im->copyMerge( $rect, $x + 1, $y + 1, 0, 0, $w - 1, $h - 1, $perc );
    $rect->colorDeallocate($color);
}

############################################################################
# alignImage - Show alignment bar on for ortholog, paralog, homolog pages.
############################################################################
sub alignImage {
    my ( $start, $end, $length, $image_len ) = @_;
    if ( $length < $start ) {
        webLog("alignImage: length=$length < end=$end\n")
          if $verbose >= 2;
        $start = $length;
    }
    if ( $length < $end ) {
        webLog("alignImage: length=$length < end=$end\n")
          if $verbose >= 2;
        $end = $length;
    }
    return nbsp(1) if $length == 0;
    my $startPerc = $start / $length;
    my $endPerc   = $end / $length;
    $image_len = 50 if ( $image_len == 0 || $image_len eq '' );
    webLog "start=$start end=$end length=$length\n"    if $verbose >= 3;
    webLog "  startPerc=$startPerc endPerc=$endPerc\n" if $verbose >= 3;
    my $start_pos = $startPerc * $image_len;
    my $end_pos   = $endPerc * $image_len;
    my $seg1      = int($start_pos);
    my $seg2      = int( $end_pos - $start_pos );
    my $seg3      = int( $image_len - $end_pos );
    $seg2 = 1 if $seg2 < 1;
    webLog "  seg1=$seg1 seg2=$seg2 seg3=$seg3\n" if $verbose >= 3;
    my $s = "<image src='$base_url/images/rect.blue.png' " . "width='$seg1' height='1' />";
    $s .= "<image src='$base_url/images/rect.green.png' " . "width='$seg2' height='5' />";
    $s .= "<image src='$base_url/images/rect.blue.png' " . "width='$seg3' height='1' />";
    return $s;
}

############################################################################
# histogramBar - Show histogram bar on web page.
#   Used mainly for metagenomic gene to best "other taxon" hits.
############################################################################
sub histogramBar {
    my ( $percentage, $maxLen, $url ) = @_;
    my $w = int( $maxLen * $percentage );
    my $h = 10;
    my $s = "<image src='$base_url/images/rect.green.png' " . "width='$w' height='$h'/>";
    if ( $url ne "" ) {
        my $s2 = "<a href='$url'>$s</a>";
        $s = $s2;
    }
    return $s;
}

#############################################################################
# isInt - Is integer.
#############################################################################
sub isInt {
    my $s = shift;

    if ( $s =~ /^\-{0,1}[0-9]+$/ ) {
        return 1;
    } elsif ( $s =~ /^\+{0,1}[0-9]+$/ ) {
        return 1;
    } else {
        return 0;
    }
}

#############################################################################
# isNumber - Is integer, or number with decimal point.
#############################################################################
sub isNumber {
    my $s = shift;

    if ( isInt($s) ) {
        return 1;
    }
    if ( $s =~ /^\-{0,1}[0-9]*\.[0-9]+$/ ) {
        return 1;
    } elsif ( $s =~ /^\+{0,1}[0-9]*\.[0-9]+$/ ) {
        return 1;
    } else {
        return 0;
    }
}

############################################################################
# isStartCodon - Is start codon.
############################################################################
sub isStartCodon {
    my ($s) = @_;
    $s =~ tr/a-z/A-Z/;
    if ( $s eq "ATG" || $s eq "GTG" || $s eq "CTG" ) {
        return 1;
    }
    return 0;
}

############################################################################
# isStopCodon - Is stop codon.
############################################################################
sub isStopCodon {
    my ($s) = @_;
    $s =~ tr/a-z/A-Z/;
    if ( $s eq "TAA" || $s eq "TGA" || $s eq "TAG" ) {
        return 1;
    }
    return 0;
}

############################################################################
# printAlignFnaSeq - Show FASTA nucleic acid sequence for alignment.
############################################################################
sub printAlignFnaSeq {
    my ($outFile) = @_;
    my $wfh = newWriteFileHandle( $outFile, "printAlignFnaSeq" );

    my @gene_oid        = param("gene_oid");
    my $up_stream       = param("align_up_stream");
    my $down_stream     = param("align_down_stream");
    my $up_stream_int   = sprintf( "%d", $up_stream );
    my $down_stream_int = sprintf( "%d", $down_stream );
    $up_stream   =~ s/\s+//g;
    $down_stream =~ s/\s+//g;

    my $gene_oid_str = join( ',', @gene_oid );
    if ( blankStr($gene_oid_str) ) {
        print "<p>\n";
        webError("Select genes first.");
    }
    if ( $up_stream_int > 0 || !isInt($up_stream) ) {
        print "<p>\n";
        webError("Expected a negative integer for up stream.");
    }
    if ( $down_stream_int < 0 || !isInt($down_stream) ) {
        print "<p>\n";
        webError("Expected a positive integer for down stream.");
    }

    my $dbh = dbLogin();
    my $sql = qq{
        select g.gene_oid, g.gene_display_name,
	  tx.taxon_oid, tx.genus, tx.species,
          g.start_coord, g.end_coord, g.strand, scf.ext_accession
        from gene g, scaffold scf, taxon tx
        where g.scaffold = scf.scaffold_oid
        and g.taxon = tx.taxon_oid
        and g.gene_oid in( $gene_oid_str )
	and g.start_coord > 0
	and g.end_coord > 0
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %records;
    for ( ; ; ) {
        my (
            $gene_oid,     $gene_display_name, $taxon_oid, $genus, $species,
            $start_coord0, $end_coord0,        $strand,    $ext_accession
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $rec =
            $gene_oid . "\t"
          . $gene_display_name . "\t"
          . $taxon_oid . "\t"
          . $genus . "\t"
          . $species . "\t"
          . $start_coord0 . "\t"
          . $end_coord0 . "\t"
          . $strand . "\t"
          . $ext_accession;
        $records{$gene_oid} = $rec;
    }
    $cur->finish();

    #$dbh->disconnect();

    foreach my $_gene_oid (@gene_oid) {
        my $str = $records{$_gene_oid};
        next if ( !defined $str || $str eq "" );
        my (
            $gene_oid,     $gene_display_name, $taxon_oid, $genus, $species,
            $start_coord0, $end_coord0,        $strand,    $ext_accession
          )
          = split( "\t", $str );

        # Reverse convention for reverse strand.
        my $start_coord = $start_coord0 + $up_stream;
        $start_coord = 1 if $start_coord < 1;
        my $end_coord = $end_coord0 + $down_stream;
        if ( $strand eq "-" ) {
            $start_coord = $start_coord0 - $down_stream;
            $end_coord   = $end_coord0 - $up_stream;
        }
        webLog "$ext_accession: $start_coord..$end_coord " . "($strand)\n"
          if $verbose >= 1;
        print $wfh ">$gene_oid\n";

        my $path = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
        my $seq1 = readLinearFasta( $path, $ext_accession, $start_coord, $end_coord, $strand );
        if ( blankStr($seq1) ) {
            webLog( "naSeq.cgi: no sequence for '$path' " . "$start_coord..$end_coord ($strand)\n" );
            next;
        }
        my $us_len = $start_coord0 - $start_coord;    # upstream length
        $us_len = $end_coord - $end_coord0 if $strand eq "-";
        $us_len = 0 if $us_len < 0;

        my $dna_len      = $end_coord0 - $start_coord0 + 1;
        my $dna_len1     = 3;                                 # start codon
        my $dna_len2     = $dna_len - 6;                      # middle
        my $dna_len3     = 3;                                 # end codon
                                                              # Set critical coordinates from segment lengths.
        my $c0           = 1;
        my $c1           = $c0 + $us_len;
        my $c2           = $c1 + $dna_len1;
        my $c3           = $c2 + $dna_len2;
        my $c4           = $c3 + $dna_len3;
        my $c1StartCodon = 0;
        my $startCodon0  = substr( $seq1, $c1 - 1, 3 );
        $c1StartCodon = 1 if isStartCodon($startCodon0);
        my $stopCodon0 = substr( $seq1, $c3 - 1, 3 );
        my $c3StopCodon = 0;
        $c3StopCodon = 1 if isStopCodon($stopCodon0);

        if ( $verbose >= 1 ) {
            webLog "up_stream=$up_stream ";
            webLog "start_coord0=$start_coord0 ";
            webLog "start_coord=$start_coord\n";
            webLog "end_coord=$end_coord ";
            webLog "end_coord0=$end_coord0 ";
            webLog "c0=$c0 c1=$c1 c2=$c2 c3=$c3 c4=$c4\n";
            webLog "startCodon0='$startCodon0' " . "c1StartCodon=$c1StartCodon\n";
            webLog "stopCodon0 ='$stopCodon0' c3StopCodon=$c3StopCodon\n";
        }

        my @bases        = split( //, $seq1 );
        my $baseCount    = 0;
        my $maxWrapCount = 50;
        my $wrapCount    = 0;
        for my $b (@bases) {
            $wrapCount++;
            print $wfh $b;
            if ( $wrapCount >= $maxWrapCount ) {
                print $wfh "\n";
                $wrapCount = 0;
            }
        }
        print $wfh "\n";
    }
    $cur->finish();

    #$dbh->disconnect();
    close $wfh;
}

############################################################################
# getWrappedSequence - Get sequence for wrap around coordinates for
#   circular genomes.
#   Inputs:
#     seq_all - all of the sequence
#     start_coord - start coordinate
#     end_coord - end coordinate
#     strand - strand
#     start_coord_w - start coordinate wrapped around
#     end_coord_w - end coordinate wrapped around
############################################################################
sub getWrappedSequence {
    my ( $seq_all, $start_coord, $end_coord, $strand, $start_coord_w, $end_coord_w ) = @_;
    my $seq;
    if ( $strand eq "+" ) {
        my $s1 = getSequence( $seq_all, $start_coord, $end_coord );
        my $s2;
        if ( $start_coord_w ne "" && $end_coord_w ne "" ) {
            $s2 = getSequence( $seq_all, $start_coord_w, $end_coord_w );
        }
        $seq = $s1 . $s2;
    } else {
        my $s1 = getSequence( $seq_all, $end_coord, $start_coord );
        my $s2;
        if ( $start_coord_w ne "" && $end_coord_w ne "" ) {
            $s2 = getSequence( $seq_all, $end_coord_w, $start_coord_w );
        }
        $seq = $s2 . $s1;
    }
    return $seq;
}

############################################################################
# bsearchFpos - Binary search on file position.  BUGGY. Not used.
############################################################################
sub bsearchFpos {
    my ( $fh, $recLen, $maxIdx, $key ) = @_;
    my $lo = 0;
    my $hi = $maxIdx;
    while ( $lo <= $hi ) {
        my $mid = int( ( $lo + $hi ) / 2 );
        my $fpos = $mid * $recLen;
        seek( $fh, $fpos, 0 );
        my $rec = <$fh>;
        chop $rec;
        my ( $key2, $val2 ) = split( /\t/, $rec );
        if ( $key2 eq $key ) {
            $val2 =~ s/\s+//g;
            return $val2;
        } else {
            if ( $key2 > $key ) {
                $hi = $mid - 1;
            } else {
                $lo = $mid + 1;
            }
        }
    }
    return -1;
}

############################################################################
# getFposLinear - Do linear search to get file position, since the
#  the binary version seems buggy and this is fast enough for
#  point and click use (though not iteration).
############################################################################
sub getFposLinear {
    my ( $fileName, $gene_oid0 ) = @_;
    my $rfh = newReadFileHandle( $fileName, "getFposLinear", 1 );
    if ( !$rfh ) {
        webLog("getFposLinear: WARNING: cannot read '$fileName'\n");
        return -1;
    }
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/^\s+//;
        $s =~ s/\s+$//;
        my ( $gene_oid, $fpos, $taxon ) = split( /\t/, $s );
        if ( $gene_oid eq $gene_oid0 ) {
            close Fpos;
            return $fpos;
        }
    }
    close Fpos;
    return -1;
}

############################################################################
# getIdxHomologs  - Get homolog hits directly indexed files.
#   Filter on currently available taxons.
#   Inputs:
#      dbh -  database handle
#      gene_oid - gene object identifier
#      recs_ref - output records reference
############################################################################
sub getIdxHomologs {
    my ( $dbh, $gene_oid, $recs_ref ) = @_;

    ## Get all taxons in this database.
    my $rclause   = urClause("tx");
    my $imgClause = imgClause('tx');
    my $sql       = qq{
       select tx.taxon_oid
       from taxon tx
       where 1 = 1
       $rclause
       $imgClause
    };
    my $cur     = execSql( $dbh, $sql, $verbose );
    my $tmpFile = "$tmp_dir/all_taxon_oids$$.txt";
    my $wfh     = newWriteFileHandle( $tmpFile, "getIdxHomologs" );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        print $wfh "$taxon_oid\n";
    }
    close $wfh;
    $cur->finish();
    my $taxon_oid     = getTaxonOid4GeneOid( $dbh, $gene_oid );
    my $avaTaxonDir   = checkPath("$ava_batch_dir/$taxon_oid");
    my $geneOidsFile  = checkPath("$ava_index_dir/$taxon_oid.geneOids.txt");
    my $fposFile      = checkPath("$ava_index_dir/$taxon_oid.gidxFpos.bin");
    my $lineCountFile = checkPath("$ava_index_dir/$taxon_oid.lineCount.txt");
    $gene_oid =~ /([0-9]+)/;
    $gene_oid = $1;
    my $cmd = "$wsimHomologs_bin -i $gene_oid -d $avaTaxonDir ";
    $cmd .= "-g $geneOidsFile -f $fposFile -l $lineCountFile ";
    $cmd .= "-t $tmpFile ";
    webLog "+ $cmd\n" if $verbose >= 1;
    unsetEnvPath();
    my $cfh = newCmdFileHandle( $cmd, "getIdxHomologs" );
    my %done;

    while ( my $s = $cfh->getline() ) {
        chomp $s;
        my ( $qid, $sid, @junk ) = split( /\t/, $s );
        $qid = firstDashTok($qid);
        $sid = firstDashTok($sid);
        my $key = "$qid-$sid";
        next if $done{$key} ne "";
        push( @$recs_ref, $s );
        $done{$key} = 1;
    }
    close $cfh;
    resetEnvPath();
    wunlink($tmpFile);
}

############################################################################
# getAllTaxonsHashed - Get all taxons in this database and put
#   in lookup hash structure.  Return hash.
############################################################################
sub getAllTaxonsHashed {
    my ( $dbh, $genomeType ) = @_;

    # lets save the query per session - ken
    my $dir      = getSessionCgiTmpDir();
    my $filename = $dir . '/getAllTaxonsHashed_' . $genomeType;
    if ( -e $filename ) {
        my $href = retrieve("$filename");
        webLog("reading cache data for getAllTaxonsHashed: $filename\n");
        return %$href;
    }

    my $rclause = urClause("tx");

    my $genomeTypeClause;
    if ( $genomeType == 2 ) {
        $genomeTypeClause = "and tx.genome_type = 'metagenome'";
    } elsif ( $genomeType == 1 ) {
        $genomeTypeClause = "and tx.genome_type = 'isolate'";
    }

    my $imgClause = imgClause('tx');

    my $sql = qq{
        select tx.taxon_oid
    	from taxon tx
    	where 1 = 1
    	$genomeTypeClause
    	$rclause
    	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %h;
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        $h{$taxon_oid} = $taxon_oid;
    }
    $cur->finish();

    my $size = keys %h;
    webLog( "caching rows " . $size . "\n" );
    store \%h, "$filename";
    return %h;
}

############################################################################
# getSelectedTaxonsHashed - Get all taxons in this database and put
#   in lookup hash structure.  Return hash.
############################################################################
sub getSelectedTaxonsHashed {
    my ($dbh) = @_;
    my $rclause = urClause("tx");
    my $taxonClause = txsClause( "tx", $dbh );
    my $imgClause   = imgClause('tx');
    my $sql         = qq{
        select tx.taxon_oid
	from taxon tx
	where 1 = 1
	$rclause
	$taxonClause
	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %h;

    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        $h{$taxon_oid} = $taxon_oid;
    }
    $cur->finish();
    return %h;
}

############################################################################
# getFileHomologs  - Get homolog hits directly from 2 files.
#  1. index file position with gene_oid -> file_position mapping
#  2. sorted by gene_oid homologs hits file starting at the seek
#     position from file_position mapping.
#   Inputs:
#      dbh -  database handle
#      gene_oid - gene object identifier
#      recs_ref - output records reference
############################################################################
sub getFileHomologs {
    my ( $dbh, $gene_oid, $recs_ref ) = @_;

    # --es 01/30/2005
    my ( $gene_homologs_tab_file, $fposFile ) = getAvaTabAndFposFiles( $dbh, $gene_oid );
    my $fpos = getFposLinear( $fposFile, $gene_oid );
    return if $fpos < 0;
    my $rfh = newReadFileHandle( $gene_homologs_tab_file, "getFileHomologs" );
    seek( $rfh, $fpos, 0 );
    my %taxonHash = getAllTaxonsHashed($dbh);
    my %ignored;

    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $gene_oid2, $homolog, $taxon, @junk ) = split( /\t/, $s );
        last if $gene_oid2 ne $gene_oid;
        if ( $taxonHash{$taxon} eq "" ) {
            $ignored{$taxon} = $taxon;
            next;
        }
        push( @$recs_ref, $s );
    }
    close $rfh;
    my @keys = sort( keys(%ignored) );
    for my $k (@keys) {
        webLog "getFileHomologs: taxon='$k' ignored\n"
          if $verbose >= 1;
    }
}

############################################################################
# hasHomolog - Gene has homolog.
############################################################################
sub hasHomolog {
    my ( $dbh, $gene_oid ) = @_;

    # --es 01/30/2005
    my $taxon_oid = getTaxonOid4GeneOid( $dbh, $gene_oid );
    my $geneOidsFile = "$ava_index_dir/$taxon_oid.geneOids.txt";
    my %geneOids;
    my $rfh = newReadFileHandle( $geneOidsFile, "hasHomolog" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $geneOids{$s} = $s;
    }
    close $rfh;
    if ( $geneOids{$gene_oid} ne "" ) {
        return 1;
    }
    return 0;
}

############################################################################
# getAvaTabAndFposFiles - Get "all vs. all" table and file position files.
############################################################################
sub getAvaTabAndFposFiles {
    my ( $dbh, $gene_oid ) = @_;
    my $taxon_oid = getTaxonOid4GeneOid( $dbh, $gene_oid );
    my $tabFile   = "$ava_taxon_dir/$taxon_oid.tab.txt";
    my $fposFile  = "$ava_taxon_dir/$taxon_oid.fpos.txt";
    return ( $tabFile, $fposFile );
}

############################################################################
# getPhyloDomainCount - Get counts for phylogenetic domains.
############################################################################
sub getPhyloDomainCounts {
    my ($taxon_filter_oid_str) = @_;

    my $dbh         = dbLogin();
    my $taxonClause = txsClause( "tx", $dbh );
    my $rclause     = urClause("tx");
    my $imgClause   = imgClause('tx');
    my $sql         = qq{
       select tx.domain, count(*)
       from taxon tx
       where 1 = 1
       $taxonClause
       $rclause
       $imgClause
       group by tx.domain
       order by tx.domain
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @recs;

    for ( ; ; ) {
        my ( $domain, $count ) = $cur->fetchrow();
        last if !$domain;
        my $rec = "$domain\t";
        $rec .= "$count";
        push( @recs, $rec );
    }
    $cur->finish();

    #$dbh->disconnect();
    return @recs;
}

############################################################################
# printCartFooter -  Support various types of cart footers.
# Note: \n adds extra space, so do not use it!
############################################################################
sub printCartFooter {
    my ( $id, $buttonLabel, $bclass, $form_id ) = @_;
    my $buttonClass = "meddefbutton";
    $buttonClass = $bclass if $bclass ne "";
    print submit(
        -name  => $id,
        -value => $buttonLabel,
        -class => $buttonClass
    );
    print nbsp(1);
    printButtonFooter($form_id);
}

sub printCartFooterInLine {
    my ( $id, $buttonLabel, $bclass, $form_id ) = @_;
    my $buttonClass = "meddefbutton";
    $buttonClass = $bclass if $bclass ne "";
    print submit(
        -name  => $id,
        -value => $buttonLabel,
        -class => $buttonClass
    );
    print nbsp(1);
    printButtonFooterInLine($form_id);
}

sub printCartFooterInLineWithToggle {
    my ( $id, $buttonLabel, $bclass, $form_id ) = @_;
    my $buttonClass = "meddefbutton";
    $buttonClass = $bclass if $bclass ne "";
    print submit(
        -name  => $id,
        -value => $buttonLabel,
        -class => $buttonClass
    );
    print nbsp(1);
    printButtonFooterInLineWithToggle($form_id);
}

sub printCartFooterWithToggle {
    my ( $id, $buttonLabel, $bclass, $form_id ) = @_;
    my $buttonClass = "meddefbutton";
    $buttonClass = $bclass if $bclass ne "";
    print submit(
        -name  => $id,
        -value => $buttonLabel,
        -class => $buttonClass
    );
    print nbsp(1);
    printButtonFooterWithToggle($form_id);
}

#
# i added a $postname for ajax stuff, each form needs its own
# selectAllCheckBoxes{$postname}(x) call
#
sub printFuncCartFooter {
    my ( $addCuraCart, $postname ) = @_;
    if ( !defined($postname) || $postname eq "" ) {
        $postname = "";
    }

    my $isEditor    = isImgEditorWrap();
    my $id          = "_section_FuncCartStor_addToFuncCart";
    my $buttonLabel = "Add Selected to Function Cart";
    my $buttonClass = "meddefbutton";
    print submit(
        -name  => $id,
        -value => $buttonLabel,
        -class => $buttonClass
    );
    if ( $addCuraCart && $isEditor ) {
        my $id2          = "_section_CuraCartStor_addToCuraCart";
        my $buttonLabel2 = "Add Selected to Curation Cart";
        my $buttonClass2 = "meddefbutton";
        print nbsp(1);
        print submit(
            -name  => $id2,
            -value => $buttonLabel2,
            -class => $buttonClass2
        );
    }
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes"
      . $postname
      . "(1)' class='smbutton' />";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes"
      . $postname
      . "(0)' class='smbutton' />";
    print "<br/>";
}

sub printCuraCartFooter {
    my ($form_id)   = @_;
    my $id          = "_section_CuraCartStor_addToCuraCart";
    my $buttonLabel = "Add Selected to Curation Cart";
    my $buttonClass = "meddefbutton";
    print submit(
        -name  => $id,
        -value => $buttonLabel,
        -class => $buttonClass
    );
    print nbsp(1);
    printButtonFooter($form_id);
}

sub printFuncCartFooterForEditor {
    my ($postname) = @_;
    my $isEditor = isImgEditorWrap();
    printFuncCartFooter( $isEditor, $postname );
}

sub printGeneCartFooter {
    my ($form_id) = @_;
    printCartFooter( "_section_GeneCartStor_addToGeneCart", "Add Selected to Gene Cart", "", $form_id );
}

sub printGeneCartFooterWithToggle {
    my ($form_id) = @_;
    printCartFooterWithToggle( "_section_GeneCartStor_addToGeneCart", "Add Selected to Gene Cart", "", $form_id );
}

sub printScaffoldCartFooter {
    my ($form_id) = @_;
    printCartFooter( "_section_ScaffoldCart_addToScaffoldCart", "Add Selected to Scaffold Cart", "", $form_id );
}

sub printScaffoldCartFooterInLine {
    my ($form_id) = @_;
    printCartFooterInLine( "_section_ScaffoldCart_addToScaffoldCart", "Add Selected to Scaffold Cart", "", $form_id );
}

sub printScaffoldCartFooterInLineWithToggle {
    my ($form_id) = @_;
    printCartFooterInLineWithToggle(
        "_section_ScaffoldCart_addToScaffoldCart",
        "Add Selected to Scaffold Cart",
        "", $form_id
    );
}

sub printGenomeCartFooter {
    my ($form_id) = @_;
    print submit(
        -name  => 'setTaxonFilter',
        -value => 'Add Selected to Genome Cart',
        -class => 'meddefbutton'
    );
    print nbsp(1);
    printButtonFooter($form_id);
}

# button IDs may be provided as argument
sub printButtonFooterInLine {
    my ($form_id) = @_;
    my $id1       = "";
    my $id2       = "";
    if ( $form_id ne "" ) {
        $id1 = "$form_id" . "1";
        $id2 = "$form_id" . "0";
    }
    $id1 = " id='$id1' " if ( $id1 ne "" );
    $id2 = " id='$id2' " if ( $id2 ne "" );
    print "<input $id1 type='button' name='selectAll' value='Select All' "
      . " onClick='selectAllCheckBoxes(1)' class='smbutton' />";
    print nbsp(1);
    print "<input $id2 type='button' name='clearAll' value='Clear All' "
      . " onClick='selectAllCheckBoxes(0)' class='smbutton' />";
}

sub printButtonFooterInLineWithToggle {
    my ($form_id) = @_;
    my $id3 = "";
    if ( $form_id ne "" ) {
        $id3 = "$form_id" . "3";
    }
    my $id = " id='$id3' " if $id3 ne "";
    print "<input $id type='button' name='inverseSel' value='Toggle Selected' "
      . "onClick='inverseSelection()' class='smbutton' />";
    print nbsp(1);
    printButtonFooterInLine($form_id);
    print nbsp(1);
}

# button IDs may be provided as argument
sub printButtonFooter {
    my ($form_id) = @_;
    printButtonFooterInLine($form_id);
    print "<br/>";
}

sub printButtonFooterWithToggle {
    my ($form_id) = @_;
    printButtonFooterInLineWithToggle($form_id);
    print "<br/>";
}

############################################################################
# gene2EnzymesMap - Map a gene to enzymes.
#   Inputs:
#     dbh - database handle
#     scaffold_oid - scaffold object identifier
#     min_start_coord - minimum start coordinate
#     max_end_coord - maximum end coordinate
#   Outputs:
#      map_ref - map reference mapping gene to enzymes
############################################################################
sub gene2EnzymesMap {
    my ( $dbh, $scaffold_oid, $min_start_coord, $max_end_coord, $map_ref ) = @_;
    my $sql = qq{
       select g.gene_oid, ge.enzymes
       from gene g, gene_ko_enzymes ge
       where g.gene_oid = ge.gene_oid
       and g.start_coord >= ?
       and g.end_coord <= ?
       and g.scaffold = ?
       and g.start_coord > 0
       and g.end_coord > 0
   };
    my $cur = execSql( $dbh, $sql, $verbose, $min_start_coord, $max_end_coord, $scaffold_oid );
    for ( ; ; ) {
        my ( $gene_oid, $enzyme ) = $cur->fetchrow();
        last if !$gene_oid;
        $map_ref->{$gene_oid} .= "$enzyme,";
    }
    $cur->finish();
}

############################################################################
# gene2MyEnzymesMap - Map a gene to MyIMG enzymes.
#   Inputs:
#     dbh - database handle
#     scaffold_oid - scaffold object identifier
#     min_start_coord - minimum start coordinate
#     max_end_coord - maximum end coordinate
#   Outputs:
#      map_ref - map reference mapping gene to enzymes
############################################################################
sub gene2MyEnzymesMap {
    my ( $dbh, $scaffold_oid, $min_start_coord, $max_end_coord, $map_ref ) = @_;
    my $sql = qq{
       select g.gene_oid, gmf.ec_number
       from gene g, gene_myimg_functions gmf
       where g.gene_oid = gmf.gene_oid
       and gmf.ec_number is not null
       and g.start_coord >= ?
       and g.end_coord <= ?
       and g.scaffold = ?
       and g.start_coord > 0
       and g.end_coord > 0
    };
    my $cur = execSql( $dbh, $sql, $verbose, $min_start_coord, $max_end_coord, $scaffold_oid );
    for ( ; ; ) {
        my ( $gene_oid, $enzyme ) = $cur->fetchrow();
        last if !$gene_oid;
        $map_ref->{$gene_oid} = $enzyme;
    }
    $cur->finish();
}

############################################################################
# getTaxonOid4GeneOid - Get taxon_oid for gene_oid.
############################################################################
sub getTaxonOid4GeneOid {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
       select g.taxon
       from gene g
       where g.gene_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($taxon_oid) = $cur->fetchrow();
    $cur->finish();
    return $taxon_oid;
}

############################################################################
# printStatusLine - Show status line in the UI.
############################################################################
sub printStatusLine {
    my ( $s, $z_index ) = @_;
    my $zidx = 1;
    if ( $z_index > 1 || blankStr($s) ) {
        $zidx = 2;
    }

    #print "<div id='status_line_z$zidx'>\n";
    if ( $s =~ /Loading/ ) {

        #        print qq{
        #        <script language='javascript' type='text/javascript'>
        #            var e0 = document.getElementById( "loading" );
        #            e0.innerHTML = "<font color='red'> $s </font> <img src='$base_url/images/ajax-loader.gif'> ";
        #        </script>
        #        };
    } else {
        $s =~ s/\n/ /g;
        $s =~ s/"/'/g;
        print qq{
        <script language='javascript' type='text/javascript'>
            var e0 = document.getElementById( "loading" );
            if(e0 != null) {
                e0.innerHTML = "$s";
            }
        </script>
        };
    }

    #print "</div>\n";
}

sub printStatusLine_old {
    my ( $s, $z_index ) = @_;
    my $zidx = 1;
    if ( $z_index > 1 || blankStr($s) ) {
        $zidx = 2;
    }
    print "<div id='status_line_z$zidx'>\n";
    if ( $s =~ /Loading/ ) {
        print "<font color='red'><blink>$s</blink></font>\n";

        #print "<font color='red'>$s</font>\n";
        #print "<span style='color: #ff0000; text-decoration: blink'>" .
        #  "$s</span>\n";
    } else {
        print "$s\n";
    }
    print "</div>\n";
}

############################################################################
# printStatusBox - Show status box in the UI.
############################################################################
sub printStatusBox {
    my ($s) = @_;
    my ( $tok0, @toks ) = split( / /, $s );

    #my $s2 = join( ' ', @toks );
    #print "<div id='status_box'>\n";
    #print "<span class='status_box'>$tok0</span>\n";
    #print "$s2\n";
    #print "</div>\n";
    print "<div id='genomes'>\n";
    print "<p>\n";
    print "<span class='orgcount'>$tok0</span><br/>\n";
    print "genomes selected\n";
    print "</p>\n";
    print "</div>\n";
}

#
# another version but uses params instead of the split to get the values
#
sub printStatusBox2 {
    my ( $count, $text ) = @_;
    print "<div id='genomes'>\n";
    print "<p>\n";
    print "<span class='orgcount'> $count </span><br/>\n";
    print "$text\n";
    print "</p>\n";
    print "</div>\n";
}

############################################################################
#  setStatusBox - Set status box from javascript.
############################################################################
sub setStatusBox {
    my ($s) = @_;
    print "<script>\n";
    print "setStatusBox( '$s' );\n";
    print "</script>\n";
}

############################################################################
# printStatusBoxUp - Print out of boudaries up from outside of content
#   division.  This is a kludge to do things w/in 'content'.
############################################################################
sub printStatusBoxUp {
    my ($s) = @_;
    my ( $tok0, @toks ) = split( / /, $s );
    my $s2 = join( ' ', @toks );
    print "<div id='status_box'>\n";
    print "<p>\n";
    print "<span class='orgcount'>$tok0</span><br/>\n";
    print "genomes selected\n";
    print "</p>\n";
    print "</div>\n";
}

############################################################################
# getChromosomeName - Get names for chromosome page print out.
############################################################################
sub getChromosomeName {
    my ($scaffold_name) = @_;
    return $scaffold_name;

    # Heursitic do not currently work, so
    # we abandon the parsing for now.

    my (@toks) = split( / /, $scaffold_name );
    $scaffold_name =~ s/\s/ /g;
    my $nToks = @toks;
    my @stack;
    my $count = 0;
    for ( my $i = $nToks - 1 ; $i >= 0 ; $i-- ) {
        $count++;
        my $tok = $toks[$i];
        last if $tok =~ /\)$/;
        last if $tok =~ /:$/;
        last if $tok eq "sp.";
        push( @stack, $tok );

        #last if $count > 2;
        $tok =~ tr/A-Z/a-z/;
        last if $tok eq "chromosome";
        last if $tok eq "plasmid";
        last if $tok =~ /Contig/;
    }
    my $s = join( ' ', reverse(@stack) );
    return $s;
}

############################################################################
# buttonUrl - Wrapper to generate code for button that's a GET URL.
############################################################################
sub buttonUrl {
    my ( $url, $label, $class, $disabled ) = @_;
    my $url2 = $url;
    ## Force buffer flush for IE
    my $x      = time();
    my $procId = "$$.$x";
    if ( $url2 !~ /\?/ ) {
        $url2 = "$url?pidt=$procId";
    } else {
        $url2 = "$url&pidt=$procId";
    }
    $disabled = 0 if $disabled eq "";
    my $ds = "";
    if ($disabled) {
        $ds = " disabled='disabled' ";
    }

    my $s = "<input type='button' class='$class' value='$label' $ds ";
    $s .= "onClick='javascript:window.open(\"$url2\", \"_self\");' />";
    return $s;
}

############################################################################
# buttonUrlNewWindow - Wrapper to generate code for button that's a GET URL.
############################################################################
sub buttonUrlNewWindow {
    my ( $url, $label, $class ) = @_;
    my $url2 = $url;
    ## Force buffer flush for IE
    my $x      = time();
    my $procId = "$$.$x";
    if ( $url2 !~ /\?/ ) {
        $url2 = "$url?pidt=$procId";
    } else {
        $url2 = "$url&pidt=$procId";
    }
    my $s = "<input type='button' class='$class' value='$label' ";
    $s .= "onClick='javascript:window.open(\"$url2\", \"$$\");' />";
    return $s;
}

# $section - default section
# $page - default page
#
sub buttonMySubmit {
    my ( $label, $class, $defaultSection, $defaultPage, $section, $page ) = @_;

    print hiddenVar( "section", $defaultSection );
    print hiddenVar( "page",    $defaultPage );

    print qq{
    <script language="javascript" type="text/javascript">
        function mySubmit(section, page) {
            document.mainForm.section.value = section;
            document.mainForm.page.value = page;
            document.mainForm.submit();
        }
    </script>

    <input type='button' class='$class' value='$label' onClick='mySubmit("$section", "$page")' />
    };
}

############################################################################
# selectUrl - Wrapper to generate code for <select> that's a GET URL.
############################################################################
sub selectUrl {
    my ( $url, $name ) = @_;
    my $s = "<select name='$name' ";
    $s .= "onChange='window.open(\"$url\", \"_self\");'>\n";
    return $s;
}

############################################################################
# locusTagCount - Get locus tag count of genes.
############################################################################
sub locusTagCount {
    my ($id) = @_;
    my $dbh  = dbLogin();
    my $sql  = qq{
      select count(*)
      from gene
      where lower( locus_tag ) = lower( ? )
   };
    my $cur = execSql( $dbh, $sql, $verbose, $id );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();
    return $cnt;
}

############################################################################
# extAccIdCount - Get external accession ID count.
############################################################################
sub extAccIdCount {
    my ($id) = @_;
    my $dbh  = dbLogin();
    my $sql  = qq{
      select count(*)
      from gene
      where lower( g.protein_seq_accid ) =  ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, lc($id) );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();
    return $cnt;
}

############################################################################
# domainLetterNote - Domain note string.
############################################################################
sub domainLetterNote {
    my ($includeBin) = @_;

    my $x;
    if ($include_metagenomes) {
        $x = "* = Microbiome, ";
        $x .= "b = bin, " if $includeBin;
        $x .= "<br>\n";
        $x .= nbsp(2);
    }
    my $plasmids = "P = Plasmids, " if $include_plasmids;
    my $s = "Domains(D): ${x}B = Bacteria,  " . "A = Archaea, E = Eukarya, $plasmids G = GFragment, V = Viruses.";
    return $s;
}
############################################################################
# domainLetterNoteParen - Domain note string, parenthesis vesion.
############################################################################
sub domainLetterNoteParen {
    my ($includeBin) = @_;

    my $x;
    if ($include_metagenomes) {
        $x = "(*) = Microbiome, ";
        $x .= "(b)in, " if $includeBin;
        $x .= "<br>\n";
        $x .= nbsp(2);
    }
    my $plasmids = "(P)lasmids, " if $include_plasmids;
    my $s = "Domains: ${x}(B)acteria, " . "(A)rchaea, (E)ukarya, $plasmids (G)Fragment, (V)iruses.";
    return $s;
}

############################################################################
# domainLetterNoteNoV - Domain note string. No viruses.
############################################################################
sub domainLetterNoteNoV {
    my $x;
    if ($include_metagenomes) {
        $x = "* = Microbiome, b = bin, ";
    }
    my $s = "Domains(D): ${x}B = Bacteria, A = Archaea, E = Eukarya.";
    return $s;
}

############################################################################
# domainLetterNoteNoVNoM - Domain note string. No viruses, microbiomes.
############################################################################
sub domainLetterNoteNoVNoM {
    my $s = "Domains(D): B = Bacteria, A = Archaea, E = Eukarya.";
    return $s;
}

############################################################################
# completionLetterNote - Note string for completion.
############################################################################
sub completionLetterNote {
    my $s = "Genome Completion(C): F = Finished, P = Permanent Draft, D = Draft.";
    return $s;
}

############################################################################
# completionLetterNoteParen - Note string for completion,
#   parenthesis or bracket version.
############################################################################
sub completionLetterNoteParen {
    my $s = "Genome Completion: [F]inished, [P]ermanent Draft, [D]raft.";
    return $s;
}

############################################################################
# addNxFeatures - Add feature on scaffold panel for long strings
#   of N's and X's.
#   Inputs:
#     dbh - database handle
#     scaffold_oid - scaffold object identifer
#     scf_panel - scaffold panel handle
#     panelStrand - panel strand orientation
#     scf_start_coord - scaffold start coorindate
#     scf_end_coord - scaffold end coordinate
############################################################################
sub addNxFeatures {
    my ( $dbh, $scaffold_oid, $scf_panel, $panelStrand, $scf_start_coord, $scf_end_coord ) = @_;
    my $sql = qq{
       select distinct ft.scaffold_oid, ft.start_coord, ft.end_coord
       from scaffold_nx_feature ft
       where ft.scaffold_oid = ?
       and ft.seq_length > 500
       and( ( ft.start_coord > ? and
               ft.end_coord < ? ) or
            ( ? <= ft.start_coord and
	       ft.start_coord <= ? ) or
            ( ? <= ft.end_coord and
	       ft.end_coord <= ? )
       )
   };
    my $cur = execSql(
        $dbh,           $sql,             $verbose,       $scaffold_oid,    $scf_start_coord,
        $scf_end_coord, $scf_start_coord, $scf_end_coord, $scf_start_coord, $scf_end_coord
    );
    my $count = 0;
    for ( ; ; ) {
        my ( $scaffold_oid, $start_coord, $end_coord ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $count++;
        $scf_panel->addNxBrackets( $start_coord, $end_coord, $panelStrand );
    }
    $cur->finish();
    webLog "$count features found\n" if $verbose >= 3;
}
############################################################################
# addRepeats -  Mark crispr and other repeat features.
#   Inputs:
#     dbh - database handle
#     scaffold_oid - scaffold object identifer
#     scf_panel - scaffold panel handle
#     panelStrand - panel strand orientation
#     scf_start_coord - scaffold start coorindate
#     scf_end_coord - scaffold end coordinate
############################################################################
sub addRepeats {
    my ( $dbh, $scaffold_oid, $scf_panel, $panelStrand, $scf_start_coord, $scf_end_coord ) = @_;

    #return if !$img_internal && !$include_metagenomes;

    my $sql = qq{
       select distinct sr.start_coord, sr.end_coord, sr.n_copies, sr.type
       from scaffold_repeats sr
       where sr.scaffold_oid = ?
       and ( sr.end_coord - sr.start_coord ) > 50
       and( ( sr.start_coord > ? and
               sr.end_coord < ? ) or
            ( ? <= sr.start_coord and
	       sr.start_coord <= ? ) or
            ( ? <= sr.end_coord and
	       sr.end_coord <= ? )
       )
   };
    my $cur = execSql(
        $dbh,           $sql,             $verbose,       $scaffold_oid,    $scf_start_coord,
        $scf_end_coord, $scf_start_coord, $scf_end_coord, $scf_start_coord, $scf_end_coord
    );
    my $count = 0;
    for ( ; ; ) {
        my ( $start_coord, $end_coord, $n_copies, $type ) = $cur->fetchrow();
        last if !$start_coord;
        $count++;
        if ( $type eq "crispr" || $type eq "CRISPR" ) {
            $scf_panel->addCrispr( $start_coord, $end_coord, $panelStrand, $n_copies );
        }
    }
    $cur->finish();
    webLog "$count repeats found\n" if $verbose >= 1;
}

############################################################################
# addIntergenic -  Mark intergenic regions.
#   Inputs:
#     dbh - database handle
#     scaffold_oid - scaffold object identifer
#     scf_panel - scaffold panel handle
#     panelStrand - panel strand orientation
#     scf_start_coord - scaffold start coorindate
#     scf_end_coord - scaffold end coordinate
############################################################################
sub addIntergenic {
    my ( $dbh, $scaffold_oid, $scf_panel, $panelStrand, $scf_start_coord, $scf_end_coord ) = @_;

    #return if !$img_internal;

    my $sql = qq{
       select distinct ig.start_coord, ig.end_coord
       from dt_intergenic ig
       where ig.scaffold_oid = ?
       and( ( ig.start_coord > ? and
               ig.end_coord < ? ) or
            ( ? <= ig.start_coord and
	       ig.start_coord <= ? ) or
            ( ? <= ig.end_coord and
	       ig.end_coord <= ? )
       )
   };
    my $cur = execSql(
        $dbh,           $sql,             $verbose,       $scaffold_oid,    $scf_start_coord,
        $scf_end_coord, $scf_start_coord, $scf_end_coord, $scf_start_coord, $scf_end_coord
    );
    my $count = 0;
    for ( ; ; ) {
        my ( $start_coord, $end_coord ) = $cur->fetchrow();
        last if !$start_coord;
        $count++;
        $scf_panel->addIntergenic( $scaffold_oid, $start_coord, $end_coord, $panelStrand );
    }
    $cur->finish();
    webLog "$count intergenic found\n" if $verbose >= 3;
}

############################################################################
# readFileIndexed - Read file index sorted.
#   Args:
#     inFile - Input tab delimited file, no header
#     sortColIdx - Sort column index, 0..length-1
#     sortType - sort datatype ("alpha" or "num")
#     outRows - Output rows
#     outIdxs - Output indexes
#
#   Sort specification is for one column only.  It has 3 whitespace
#   separated values:  <colIdx> <asc|desc> <alpha|num>
#   colIdx is zero based.
############################################################################
sub readFileIndexed {
    my ( $inFile, $sortColIdx, $sortType, $outRows_ref, $outIdxs_ref ) = @_;
    my $rfh = newReadFileHandle( $inFile, "readFileIndexed" );
    my @idxVals;
    my $count = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $count++;
        my $rowIdx = $count - 1;
        my (@vals) = split( /\t/, $s );
        my $nVals = @vals;
        if ( $sortColIdx < 0 || $sortColIdx >= $nVals ) {
            webDie("readFileIndexed: bad sortColIdx=$sortColIdx nVals=$nVals\n");
        }
        push( @$outRows_ref, $s );
        push( @idxVals,      $vals[$sortColIdx] . "\t" . "$rowIdx" );
    }
    close $rfh;
    if ( $sortType eq "num" ) {
        @$outIdxs_ref = sort { $a <=> $b } (@idxVals);
    } else {
        @$outIdxs_ref = sort(@idxVals);
    }
}

############################################################################
# printExcelHeader - Print HTTP header for outputting to Excel.
############################################################################
sub printExcelHeader {
    my ($fileName) = @_;
    print "Content-type: application/vnd.ms-excel\n";
    print "Content-Disposition: inline;filename=$fileName\n";
    print "\n";
}

############################################################################
# fileRoot - Get file name root from path.
############################################################################
sub fileRoot {
    my ($path) = @_;
    my $fileName = lastPathTok($path);
    my ( $fileRoot, @exts ) = split( /\./, $fileName );
    return $fileRoot;
}

############################################################################
# phyloSimMask - Mask for selected taxons.
############################################################################
sub phyloSimMask {
    my ($dbh) = @_;
    ## Get bitmap.
    my $imgClause = imgClause('tx');
    my $sql       = qq{
       select 1, tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family,
          tx.genus, tx.species, tx.strain, tx.taxon_name, tx.taxon_oid
       from taxon tx
       where domain not like 'Vir%'
       and domain not like 'Plasmid%'
       and domain not like 'GFragment%'
       $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %bitMap;
    my $count = 0;

    for ( ; ; ) {
        my ( $flag, $domain, $phylum, $ir_class, $ir_order, $famliy, $genus, $species, $strain, $taxon_name, $taxon_oid ) =
          $cur->fetchrow();
        last if !$flag;
        $bitMap{$taxon_oid} = $count++;
    }
    webLog("phyloSimMask mask size=$count\n");
    $cur->finish();
    my $bitMapSize  = $count;
    my $whereClause = txsClause( "tx", $dbh );
    my $rclause     = urClause("tx");
    my $sql2         = qq{
        select tx.taxon_oid
	from taxon tx, taxon_stats ts
	where domain not like 'Vir%'
	and domain not like 'Plasmid%'
	and domain not like 'GFragment%'
	and ts.taxon_oid = tx.taxon_oid
	$whereClause
	$rclause
	$imgClause
    };
    my $cur2    = execSql( $dbh, $sql2, $verbose );
    my $bitVec = "0" x $bitMapSize;

    for ( ; ; ) {
        my ($taxon_oid) = $cur2->fetchrow();
        last if !$taxon_oid;
        my $idx = $bitMap{$taxon_oid};
        substr( $bitVec, $idx, 1 ) = "1";
    }
    $cur2->finish();
    my $len = length($bitVec);
    webLog("Length bitVec=$len\n");
    return $bitVec;
}

############################################################################
# geneOidMap - Map old gene_oid's to new one.  Check also if existing
#   one exists.  If not try alternate gene_oid.
############################################################################
sub geneOidMap {
    my ( $dbh, $gene_oid0 ) = @_;
    my $sql = qq{
      select gene_oid
      from gene
      where gene_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose - 1, $gene_oid0 );
    my ($gene_oid) = $cur->fetchrow();
    $cur->finish();
    return $gene_oid if $gene_oid;

    ## Try alt identifiers.
    my $cur2 = execSql( $dbh, getGeneReplacementSql(), $verbose, $gene_oid0 );
    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid) = $cur2->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    if ( scalar(@gene_oids) != 1 ) {
        my $gene_oid_str = join( ',', @gene_oids );
        webLog( "geneOidMap: multiple gene_oids='$gene_oid_str' for " . "original gene_oid0='$gene_oid0'\n" );
    }
    return $gene_oids[0];
    return 0;
}

sub getGeneReplacementSql {
    my ($inClause) = @_;

    my $sql;
    if ( $inClause ne '' ) {
        $sql = qq{
	      select distinct gene_oid
	      from gene_replacements
	      where old_gene_oid in ($inClause)
        };
    } else {
        $sql = qq{
	      select distinct gene_oid
	      from gene_replacements
	      where old_gene_oid = ?
        };
    }

    return $sql;
}

############################################################################
# geneOidsMap - Map multiple gene_oids.
############################################################################
sub geneOidsMap {
    my ( $dbh, $origList_ref, $finalList_ref, $badList_ref ) = @_;
    for my $gene_oid0 (@$origList_ref) {
        my $gene_oid = geneOidMap( $dbh, $gene_oid0 );
        if ( $gene_oid ne "" ) {
            push( @$finalList_ref, $gene_oid );
        } else {
            push( @$badList_ref, $gene_oid0 );
        }
    }
}

############################################################################
# taxonOidMap - Map old taxon_oid's to new one.  Check also if existing
#   one exists.  If not try alternate taxon_oid.
############################################################################
sub taxonOidMap {
    my ( $dbh, $taxon_oid0 ) = @_;
    my $sql = qq{
      select taxon_oid
      from taxon
      where taxon_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose - 1, $taxon_oid0 );
    my ($taxon_oid) = $cur->fetchrow();
    $cur->finish();
    return $taxon_oid if $taxon_oid;

    ## Try alt identifiers.
    my $cur2 = execSql( $dbh, getTaxonReplacementSql(), $verbose, $taxon_oid0 );
    my @taxon_oids;
    for ( ; ; ) {
        my ($taxon_oid) = $cur2->fetchrow();
        last if !$taxon_oid;
        push( @taxon_oids, $taxon_oid );
    }
    if ( scalar(@taxon_oids) != 1 ) {
        my $taxon_oid_str = join( ',', @taxon_oids );
        webLog( "taxonOidMap: multiple taxon_oids='$taxon_oid_str' for " . "original taxon_oid0='$taxon_oid0'\n" );
    }
    return $taxon_oids[0];
    return 0;
}

sub getTaxonReplacementSql {
    my ($inClause) = @_;

    my $sql;
    if ( $inClause ne '' ) {
        $sql = qq{
	        select distinct tr.taxon_oid
	        from taxon_replacements tr, taxon t
            where tr.old_taxon_oid in ($inClause)
            and tr.old_taxon_oid = t.taxon_oid
            and t.obsolete_flag = 'Yes'
	    };
    } else {
        $sql = qq{
	        select distinct tr.taxon_oid
	        from taxon_replacements tr, taxon t
	        where tr.old_taxon_oid = ?
            and tr.old_taxon_oid = t.taxon_oid
            and t.obsolete_flag = 'Yes'
	    };
    }

    return $sql;
}

############################################################################
# taxonOidsMap - Map multiple taxon_oids.
############################################################################
sub taxonOidsMap {
    my ( $dbh, $origList_ref, $finalList_ref, $badList_ref ) = @_;
    my %validTaxons = getAllTaxonsHashed($dbh);
    for my $taxon_oid0 (@$origList_ref) {
        my $taxon_oid = taxonOidMap( $dbh, $taxon_oid0 );
        if ( $taxon_oid ne "" && $validTaxons{$taxon_oid} ne "" ) {
            push( @$finalList_ref, $taxon_oid );
        } else {
            push( @$badList_ref, $taxon_oid0 );
        }
    }
}

############################################################################
# blastProcCheck - Do system wide BLAST process check.  We don't
#    want too many hogs running at the same time so as to overwhelm
#    the system.  Do the error message here if it's too much.
#        --es  05/05/2005
############################################################################
sub blastProcCheck {
    my $cmd = "/bin/ps -ef";
    webLog "+ $cmd\n" if $verbose >= 5;
    my $count = 0;
    unsetEnvPath();
    my $cfh = newCmdFileHandle( $cmd, "blastProcCheck" );
    while ( my $s = $cfh->getline() ) {
        chomp $s;
        $count++ if $s =~ /blastall/;
    }
    close $cfh;
    resetEnvPath();
    webLog "$count blastall's running\n" if $verbose >= 1;
    if ( $count >= $max_blast_jobs ) {
        webError( "Maximum BLAST jobs ($max_blast_jobs) currently running. " . "Please try again later." );
    }
}

############################################################################
# maxCgiProcCheck - Check for maximum CGI processes.
############################################################################
sub maxCgiProcCheck {
    my $scriptName = shift || 'main.cgi';
#    $scriptName = 'main.cgi' if ( $scriptName eq '' );

    my $max_cgi_procs = $env->{max_cgi_procs};
    webLog("maxCgiProcCheck: $max_cgi_procs allowed processes\n");

    return if ! $max_cgi_procs;
    my $cmd = "/bin/ps -ef";

    #webLog "+ $cmd\n" if $verbose >= 5;
    my $count = 0;
    unsetEnvPath();
    my $cfh = newCmdFileHandle( $cmd, "maxCgiProcCheck" );
    while ( my $s = $cfh->getline() ) {
        chomp $s;
        $count++ if $s =~ /$scriptName/;
    }
    close $cfh;
    resetEnvPath();

    webLog("maxCgiProcCheck: $count $scriptName running\n");

    if ( $count > $max_cgi_procs ) {

        #webLog "WARNING: max_cgi_procs exceeded.\n";
        print header( -type => "text/html", -status => '503' );
        print <<EOF;
<html>
<head>
    <title>503 Service Overloaded</title>
    <link rel="stylesheet" type="text/css" href="http://img.jgi.doe.gov/css/div-v33.css" />
    <link rel="stylesheet" type="text/css" href="http://img.jgi.doe.gov/css/img-v33.css" />
    <link rel="icon" href="http://img.jgi.doe.gov/images/favicon.ico"/>
    <link rel="SHORTCUT ICON" href="http://img.jgi.doe.gov/images/favicon.ico" />
</head>
<body id="body_frame">
<div id="jgi_logo2">
    <img src="http://img.jgi.doe.gov/images/jgi_home_header.gif" alt="IMG: Integrated Microbial Genomes" title="IMG: Integrated Microbial Genomes nameplate">
</div>
<div id="content_other">
<h2>503 Service Overloaded</h2>
        <p>
        <img src="http://img.jgi.doe.gov/images/Warning.png" alt="warning"
        style="height:70px; width:70px; float:left; padding-right:10px;" />
        IMG is very busy.<br/>
        Please try again later.
</div>
</body>
</html>
EOF

        webExit(0);
    }
}

############################################################################
# tableExists - Test if table exists.
#
# $runcheck - used to actually run the table check
# otherwise return true that table exists
############################################################################
sub tableExists {
    my ( $dbh, $tableName, $runcheck ) = @_;

    # vervion 3.1 lets assume the schema has all tables - ken 2010-03-29
    if ( $runcheck eq "" || $runcheck == 0 ) {
        return 1;
    }

    return 0 if $tableName eq "";
    $tableName      =~ tr/a-z/A-Z/;
    my $tableNameLc =~ tr/A-Z/a-z/;
    my $cnt = 0;
    if ( $rdbms eq "mysql" ) {
        my $sql = qq{
	   show tables
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($table_name) = $cur->fetchrow();
            last if !$table_name;
            if ( $table_name eq $tableNameLc ) {
                $cnt++;
                last;
            }
        }
        $cur->finish();
    }
    if ( $rdbms eq "oracle" ) {
        my $sql = qq{
        select count(*)
        from user_objects
        where object_name = ?
        and object_type in ('TABLE','SYNONYM','VIEW')
        };

        my $cur = execSql( $dbh, $sql, $verbose, $tableName );
        $cnt = $cur->fetchrow();
        $cur->finish();
    }
    webLog "tableExists('$tableName') $cnt rdbms='$rdbms'\n"
      if $verbose >= 1;
    return $cnt;
}

############################################################################
# encode - Encode base64
############################################################################
sub encode {
    my ($s) = @_;
    my $b64 = encode_base64($s);
    chop $b64;
    return $b64;
}

############################################################################
# decode - Decode base64
############################################################################
sub decode {
    my ($b64) = @_;
    my $s = decode_base64($b64);
    return $s;
}

############################################################################
# pwDecode - Password decode if encoded.
############################################################################
sub pwDecode {
    my ($pw) = @_;
    my ( $tag, @toks ) = split( /:/, $pw );
    if ( $tag eq "encoded" ) {
        my $val = join( ':', @toks );
        return decode($val);
    } else {
        return $pw;
    }
}

############################################################################
# urClause - Generate user restriction clause
#    for user restricted sites.
############################################################################
sub urClause {
    my ($aliasOrAttr) = @_;

    my $taxon_oid_attr = "taxon_oid";
    $taxon_oid_attr = "$aliasOrAttr.taxon_oid"
      if $aliasOrAttr ne ""
      && $aliasOrAttr ne "taxon_oid"
      && $aliasOrAttr !~ /\./;
    $taxon_oid_attr = $aliasOrAttr
      if $aliasOrAttr ne ""
      && $aliasOrAttr ne "taxon_oid"
      && $aliasOrAttr =~ /\./;

    #webLog("====== user_restricted_site $user_restricted_site  \n");
    #webLog("====== public_login $public_login  \n");

    return "" if ( !$user_restricted_site );
    my $contact_oid = getContactOid();

    #webLog("====== contact_oid $contact_oid\n");

    return "" if !$contact_oid;

    my $super_user = getSuperUser();
    if ( $super_user eq "Yes" ) {

        #        my $clause = qq{
        #      and $taxon_oid_attr in(
        #         select tx.taxon_oid
        #         from taxon tx
        #         where tx.obsolete_flag = 'No'
        #      )
        #        };
        #        return $clause;
        return "";
    }

    my $clause = qq{
      and $taxon_oid_attr in(
         select tx.taxon_oid
         from taxon tx
         where tx.is_public = 'Yes'
         and tx.obsolete_flag = 'No'
            union all
         select ctp.taxon_permissions
         from contact_taxon_permissions ctp
         where ctp.contact_oid = $contact_oid
      )
    };
    return $clause;
}

sub urClauseBind {
    my ($aliasOrAttr) = @_;

    my $taxon_oid_attr = "taxon_oid";
    $taxon_oid_attr = "$aliasOrAttr.taxon_oid"
      if $aliasOrAttr ne ""
      && $aliasOrAttr ne "taxon_oid"
      && $aliasOrAttr !~ /\./;
    $taxon_oid_attr = $aliasOrAttr
      if $aliasOrAttr ne ""
      && $aliasOrAttr ne "taxon_oid"
      && $aliasOrAttr =~ /\./;

    my @bindList = ();
    return ( "", @bindList ) if !$user_restricted_site;

    my $contact_oid = getContactOid();
    return ( "", @bindList ) if !$contact_oid;

    my $super_user = getSuperUser();
    if ( $super_user eq "Yes" ) {

        #        my $clause = qq{
        #      and $taxon_oid_attr in(
        #         select tx.taxon_oid
        #         from taxon tx
        #         where tx.obsolete_flag = 'No'
        #      )
        #        };
        #        return ( $clause, @bindList );
        return ( "", @bindList );
    }

    my $clause = qq{
      and $taxon_oid_attr in(
	     select tx.taxon_oid
	     from taxon tx
	     where tx.is_public = ?
         and tx.obsolete_flag = 'No'
	        union all
	     select ctp.taxon_permissions
	     from contact_taxon_permissions ctp
	     where ctp.contact_oid = ?
      )
   };
    push( @bindList, 'Yes' );
    push( @bindList, $contact_oid );

    return ( $clause, @bindList );
}

#
# Now that there is only one DB we have to restrict genomes by img site
#
# $alias - taxon table sql alias - required
#
sub imgClause {
    my ($alias) = @_;

    my $clause = "";

    # w, er, geba
    if ( !$include_metagenomes ) {
        $clause = " and $alias" . '.' . "genome_type = 'isolate' ";
    }

    # w, geba is now w, m
    #if(!$user_restricted_site || $public_nologin_site) {
    if ( !$user_restricted_site ) {
        $clause .= " and $alias" . '.' . "is_public = 'Yes' ";
    }

    $clause .= " and $alias" . '.' . "obsolete_flag = 'No' ";

    return $clause;
}

#
# same as the imgClause but your initial query that has no taxon table defined in the sql
#
#
# $domainType - optional
#   0 - do nothing - all genome_type
#   1 - restrict to - genome_type 'isolate'
#   2 - restrict to - genome type 'metagenome'
sub imgClauseNoTaxon {
    my ( $aliasOrAttr, $domainType ) = @_;

    my $taxon_oid_attr = "taxon_oid";
    $taxon_oid_attr = "$aliasOrAttr.taxon_oid"
      if $aliasOrAttr ne ""
      && $aliasOrAttr ne "taxon_oid"
      && $aliasOrAttr !~ /\./;
    $taxon_oid_attr = $aliasOrAttr
      if $aliasOrAttr ne ""
      && $aliasOrAttr ne "taxon_oid"
      && $aliasOrAttr =~ /\./;

    my $str;

    # w, er, geba
    if ( !$include_metagenomes ) {
        $str = " and tx2.genome_type = 'isolate' ";
    }

    # w, geba is now w, m
    #if(!$user_restricted_site || $public_nologin_site) {
    if ( !$user_restricted_site ) {
        $str .= " and tx2.is_public = 'Yes' ";
    }

    #return "" if ($str eq "" && !$domainType);

    my $type;
    if ( $domainType == 1 ) {
        $type = "and tx2.genome_type = 'isolate'";
    } elsif ( $domainType == 2 ) {
        $type = "and tx2.genome_type = 'metagenome'";
    }

    my $clause = qq{
      and $taxon_oid_attr in(
         select tx2.taxon_oid
         from taxon tx2
         where 1 = 1
         and tx2.obsolete_flag = 'No'
         $str
         $type
      )
    };
    return $clause;
}

sub singleCellClause {
    my ( $aliasOrAttr, $hideSingleCell ) = @_;

    my $taxon_oid_attr = "taxon_oid";
    $taxon_oid_attr = "$aliasOrAttr.taxon_oid"
      if $aliasOrAttr ne ""
      && $aliasOrAttr ne "taxon_oid"
      && $aliasOrAttr !~ /\./;
    $taxon_oid_attr = $aliasOrAttr
      if $aliasOrAttr ne ""
      && $aliasOrAttr ne "taxon_oid"
      && $aliasOrAttr =~ /\./;

    my $singleCellClause = '';
    if ($hideSingleCell) {
        $singleCellClause = "and $taxon_oid_attr not in (select sc.taxon_oid from vw_taxon_sc sc)";
    }

    return $singleCellClause;
}

############################################################################
# checkTaxonPerm - Check permission for taxon access.
#   Give error message if no access.
############################################################################
sub checkTaxonPerm {
    my ( $dbh, $taxon_oid ) = @_;
    return if !$user_restricted_site;

    my $super_user = getSuperUser();
    return if $super_user eq "Yes";

    if ( $taxon_oid !~ /^[0-9]+$/ ) {
        webError("Illegal taxon_oid='$taxon_oid'\n");
    }
    my $contact_oid = getContactOid();
    if ( !$contact_oid ) {
        webError( "Session expired. " . "You do not have permission to view this genome." );
    }
    my $sql = qq{
      select count(*)
      from taxon tx
      where tx.taxon_oid = ?
      and is_public = 'Yes'
      and rownum < 2
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $cnt = $cur->fetchrow();
    $cur->finish();
    return if $cnt > 0;

    $sql = qq{
      select count(*)
      from contact_taxon_permissions ctp
      where contact_oid = ?
      and taxon_permissions = ?
      and rownum < 2
   };
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $taxon_oid );
    $cnt = $cur->fetchrow();
    $cur->finish();
    return if $cnt > 0;

    printStatusLine( "Error.", 2 );

    #$dbh->disconnect();

    # Changed per Amy's request. +BSJ 10/05/11
    # webError("You do not have permission on this genome.");
    webError("Taxon object identifier $taxon_oid not found.");
}

############################################################################
# checkTaxonPermHeader - Check permission for taxon access.
#   Give error message if no access with header.
############################################################################
sub checkTaxonPermHeader {
    my ( $dbh, $taxon_oid ) = @_;
    return if !$user_restricted_site;

    my $super_user = getSuperUser();
    return if $super_user eq "Yes";

    my $contact_oid = getContactOid();
    if ( !$contact_oid ) {
        webErrorHeader("Session expired. You do not have permission to view this genome.");
    }
    my $sql = qq{
      select count(*)
      from taxon tx
      where tx.taxon_oid = ?
      and is_public = 'Yes'
      and rownum < 2
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $cnt = $cur->fetchrow();
    $cur->finish();
    return if $cnt > 0;

    $sql = qq{
      select count(*)
      from contact_taxon_permissions ctp
      where contact_oid = ?
      and taxon_permissions = ?
      and rownum < 2
   };
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $taxon_oid );
    $cnt = $cur->fetchrow();
    $cur->finish();
    return if $cnt > 0;

    printStatusLine( "Error.", 2 );

    #$dbh->disconnect();
    webErrorHeader("You do not have permission to view this genome.");
}

############################################################################
# checkGenePerm - Check permission for gene access. Give error message
#   if do not have access.
############################################################################
sub checkGenePerm {
    my ( $dbh, $gene_oid ) = @_;

    # has the genome been removed
    if ( !$img_edu ) {
        my $sql = qq{
      select count(*)
      from taxon tx, gene g
      where g.gene_oid = ?
      and g.taxon = tx.taxon_oid
      and tx.obsolete_flag = 'Yes'
      and rownum < 2
   };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        my $cnt = $cur->fetchrow();
        $cur->finish();
        if ( $cnt > 0 ) {
            webError("The gene your are looking for does not exist or it may have been removed from IMG.");
        }
    }

    return if !$user_restricted_site;

    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();
    return 1 if $super_user eq "Yes";
    if ( !$contact_oid ) {
        webError("Session expired. You do not have permission to view this genome.");
    }
    my $sql = qq{
      select count(*)
      from taxon tx, gene g
      where g.gene_oid = ?
      and g.taxon = tx.taxon_oid
      and tx.is_public = 'Yes'
      and rownum < 2
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $cnt = $cur->fetchrow();
    $cur->finish();
    return 1 if $cnt > 0;

    $sql = qq{
      select count(*)
      from contact_taxon_permissions ctp, gene g
      where contact_oid = ?
      and taxon_permissions = g.taxon
      and g.gene_oid = ?
      and rownum < 2
   };
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $gene_oid );
    $cnt = $cur->fetchrow();
    $cur->finish();
    return 1 if $cnt > 0;

    $sql = qq{
      select count(*)
      from taxon tx, gene g, gene_replacements gr
      where gr.old_gene_oid = ?
      and gr.gene_oid = g.gene_oid
      and tx.taxon_oid = g.taxon
      and tx.is_public = 'Yes'
      and rownum < 2
   };
    $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    $cnt = $cur->fetchrow();
    $cur->finish();
    return 1 if $cnt > 0;

    $sql = qq{
      select count(*)
      from contact_taxon_permissions ctp, gene g, gene_replacements gr
      where contact_oid = ?
      and taxon_permissions = g.taxon
      and gr.gene_oid = g.gene_oid
      and gr.old_gene_oid = ?
      and rownum < 2
   };
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $gene_oid );
    $cnt = $cur->fetchrow();
    $cur->finish();
    return 1 if $cnt > 0;

    printStatusLine( "Error.", 2 );

    #$dbh->disconnect();
    webError("You do not have permission to view genes in this genome.");
    return 0;
}

#
# is taxon or genome public
# return 1 - yes public
# return 0 - its not public
#
# - Ken
sub isTaxonPublic {
    my ( $dbh, $taxon_oid ) = @_;

    return 0 if $taxon_oid eq '';

    if ( !$user_restricted_site ) {

        # always public
        return 1;
    }
    my $sql = qq{
        select '1'
        from taxon t
        where t.taxon_oid = ?
        and t.is_public = 'Yes'
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $cnt = $cur->fetchrow();
    $cur->finish();

    if ( $cnt eq "1" ) {
        return 1;
    }

    return 0;    # not public
}

#
# is gene public
# return 1 - yes public
# return 0 - its not public
#
# - Ken
sub isGenePublic {
    my ( $dbh, $gene_oid ) = @_;

    if ( !$user_restricted_site ) {

        # always public
        return 1;
    }
    my $sql = qq{
        select '1'
        from taxon t, gene g
        where t.taxon_oid = g.taxon
        and g.gene_oid = ?
        and t.is_public = 'Yes'
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $cnt = $cur->fetchrow();
    $cur->finish();

    if ( $cnt eq "1" ) {
        return 1;
    }

    return 0;    # not public
}

############################################################################
# validGenePerms - Check permission for multiple gene access.
#   Give error message if do not have access.
############################################################################
sub validateGenePerms {
    my ( $dbh, $gene_oids_ref, $badGeneOids_ref ) = @_;
    return if !$user_restricted_site;
    my $contact_oid = getContactOid();
    return if !$contact_oid;
    my $super_user = getSuperUser();
    return if $super_user eq "Yes";

    my @urOids     = getUrOids($dbh);
    my %urOidsHash = array2Hash(@urOids);
    my $sql        = "select gene_oid, taxon from gene where gene_oid = ?";
    my $cur        = prepSql( $dbh, $sql, $verbose );
    my $stat       = 1;
    for my $gene_oid (@$gene_oids_ref) {

        #my $cur = execSql( $dbh, $sql, $verbose - 1 );
        execStmt( $cur, $gene_oid );
        my ( $gene_oid, $taxon ) = $cur->fetchrow();
        if ( $urOidsHash{$taxon} eq "" ) {

            #printStatusLine( "Error.", 2 );
            #webError( "Invalid gene_oid=$gene_oid.  No access permission." );
            webLog "validateGenePerms: bad gene_oid='$gene_oid'\n"
              if $verbose >= 1;
            push( @$badGeneOids_ref, $gene_oid );
            $stat = 0;
        }
    }
    $cur->finish();
    return $stat;
}

############################################################################
# checkScaffoldPerm - Check permission for taxon access.
#   Give error message if no access.
############################################################################
sub checkScaffoldPerm {
    my ( $dbh, $scaffold_oid ) = @_;
    return if !$user_restricted_site;
    my $contact_oid = getContactOid();
    if ( !$contact_oid ) {
        webError("Session expired. You do not have permission to view this genome.");
    }
    my $super_user = getSuperUser();
    return if $super_user eq "Yes";

    my $sql = qq{
      select count(*)
      from taxon tx, scaffold scf
      where scf.scaffold_oid = ?
      and scf.taxon = tx.taxon_oid
      and tx.is_public = 'Yes'
      and rownum < 2
   };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my $cnt = $cur->fetchrow();
    $cur->finish();
    return if $cnt > 0;

    $sql = qq{
      select count(*)
      from contact_taxon_permissions ctp, scaffold scf
      where contact_oid = ?
      and scf.taxon = ctp.taxon_permissions
      and scf.scaffold_oid = ?
      and rownum < 2
   };
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid, $scaffold_oid );
    $cnt = $cur->fetchrow();
    $cur->finish();
    return if $cnt > 0;

    printStatusLine( "Error.", 2 );
    webError("You do not have permission to view this genome.");
}

############################################################################
# keggPathwayName - Get pathway name from pathway_oid.
############################################################################
sub keggPathwayName {
    my ( $dbh, $pathway_oid ) = @_;
    my $sql = qq{
      select pathway_name
      from kegg_pathway
      where pathway_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    my ($pathway_name) = $cur->fetchrow();
    $cur->finish();
    return $pathway_name;
}

############################################################################
# genomeName - Get genome name from taxon_oid.
############################################################################
sub genomeName {
    my ( $dbh, $taxon_oid ) = @_;
    my $sql = qq{
      select taxon_display_name
      from taxon
      where taxon_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_display_name) = $cur->fetchrow();
    $cur->finish();
    return $taxon_display_name;
}

############################################################################
# cogCategoryName - Get COG/KOG cateogry name from function_code.
############################################################################
sub cogCategoryName {
    my ( $dbh, $function_code, $og ) = @_;
    $og = "cog" if ( !$og );    # orthogonal group: cog|kog

    my $sql = qq{
      select definition
      from ${og}_function
      where function_code = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    my ($name) = $cur->fetchrow();
    $cur->finish();
    return $name;
}

############################################################################
# cogPathwayName - Get COG/KOG pathway name from oid.
############################################################################
sub cogPathwayName {
    my ( $dbh, $cog_pathway_oid, $og ) = @_;
    $og = "cog" if ( !$og );    # orthogonal group: cog|kog

    my $sql = qq{
      select ${og}_pathway_name
      from ${og}_pathway
      where ${og}_pathway_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_pathway_oid );
    my ($name) = $cur->fetchrow();
    $cur->finish();
    return $name;
}

############################################################################
# cogName - Return cog_name/kog_name given cog_id/kog_id.
############################################################################
sub cogName {
    my ( $dbh, $cog_id, $og ) = @_;
    $og = "cog" if ( !$og );    # orthogonal group: cog|kog

    my $sql = qq{
      select ${og}_name
      from ${og}
      where ${og}_id = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $cog_id );
    my ($name) = $cur->fetchrow();
    return $name;
}

############################################################################
# enzymeName - Return enzyme_name given ec_number.
############################################################################
sub enzymeName {
    my ( $dbh, $ec_number ) = @_;
    my $sql = qq{
      select enzyme_name
      from enzyme
      where ec_number = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $ec_number );
    my ($name) = $cur->fetchrow();
    return $name;
}

############################################################################
# abbrColName - Abbreviate column name by breaking to 3 lines, first
#  3 letters for genome name to save space.  Link out to genome
#  and allow for mouseover.
############################################################################
sub abbrColName {
    my ( $taxon_oid, $taxon_display_name, $noLink ) = @_;
    $taxon_display_name =~ s/\s+/ /g;
    $taxon_display_name =~ s/\W+/ /g;    # any non word char - ken
    $taxon_display_name = strTrim($taxon_display_name);
    my @toks = split( / /, $taxon_display_name );

    #substr( $toks[0], 1 ) =~ s/[aeiou]//g;
    #substr( $toks[1], 1 ) =~ s/[aeiou]//g;
    my $tok0 = substr( $toks[0], 0, 3 );
    my $tok1 = substr( $toks[1], 0, 3 );
    my $nToks   = @toks;
    my $tok2Len = length( $toks[ $nToks - 1 ] );
    my $tok2    = substr( $toks[ $nToks - 1 ], 0, 2 ) . substr( $toks[ $nToks - 1 ], $tok2Len - 1, 1 );
    my $s       = escHtml($tok0) . "<br/>";
    $s .= escHtml($tok1) . "<br/>" if $tok1 ne "";
    $s .= escHtml($tok2) . "<br/>" if $tok2 ne "";
    $s .= escHtml($taxon_oid);
    my $url                 = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_display_name2 = escHtml($taxon_display_name);
    my $link                = "<a href='$url' title='$taxon_display_name2'>$s</a>";
    $link = $s if $noLink;
    return $link;
}

############################################################################
# abbrColName - Abbreviate column name by cropping the first 10 words
#      and last 3 words to max 5 chars.
############################################################################
sub abbrColName2 {
    my ( $taxon_oid, $taxon_display_name, $url ) = @_;
    $taxon_display_name =~ s/\s+/ /g;
    $taxon_display_name =~ s/\W+/ /g;    # any non word char - ken
    $taxon_display_name = strTrim($taxon_display_name);
    my $s;
    my $count = 0;
    my @toks  = split( / /, $taxon_display_name );
    my $nToks = scalar @toks;

    foreach my $t (@toks) {
        last if $count >= 10;
        if ( $count > 0 ) {
            $s .= " ";
        }
        $s .= escHtml( substr( $t, 0, 5 ) );
        $count++;
    }
    my $idx = 3;
    if ( $nToks > 13 ) {
        while ( $idx >= 1 ) {
            $s .= " ";
            $s .= escHtml( substr( $toks[ $nToks - $idx ], 0, 5 ) );
            $idx--;
        }
    }
    my $link = $s;
    if ( $url ne "" ) {
        $link = alink( $url, $s, "_blank" );
    }
    return $link;
}

############################################################################
# abbrBinColName - Abbreviate column name by breaking to 3 lines, first
#  3 letters for bin name to save space.  Link out to genome
#  and allow for mouseover.
############################################################################
sub abbrBinColName {
    my ( $bin_oid, $bin_display_name, $noLink ) = @_;
    my ( $bin_name, $env_name ) = split( /\(/, $bin_display_name );
    $bin_display_name = $bin_name;
    $bin_display_name =~ s/\s+/ /g;
    my @toks = split( / /, $bin_display_name );

    #substr( $toks[0], 1 ) =~ s/[aeiou]//g;
    #substr( $toks[1], 1 ) =~ s/[aeiou]//g;
    my $tok0 = substr( $toks[0], 0, 3 );
    my $tok1 = substr( $toks[1], 0, 3 );
    my $tok2Len = length( $toks[2] );
    my $tok2    = substr( $toks[2], 0, 2 ) . substr( $toks[2], $tok2Len - 1, 1 );
    my $s       = escHtml($tok0) . "<br/>";
    $s .= escHtml($tok1) . "<br/>" if $tok1 ne "";
    $s .= escHtml($tok2) . "<br/>" if $tok2 ne "";
    $s .= escHtml($bin_oid);
    my $url                 = "$main_cgi?section=Metagenome&page=binDetail&bin_oid=$bin_oid";
    my $taxon_display_name2 = escHtml($bin_display_name);
    my $link                = "<a href='$url' title='$taxon_display_name2'>$s</a>";
    $link = $s if $noLink;
    return $link;
}

############################################################################
# abbrScaffoldName - Abbreviate column name by breaking to 3 lines, first
#  3 letters for genome name to save space.  Link out to scaffold
#  and allow for mouseover.
############################################################################
sub abbrScaffoldName {
    my ( $scaffold_oid, $scaffold_name ) = @_;
    $scaffold_name =~ s/_/ /g;
    $scaffold_name =~ s/\s+/ /g;
    my @toks       = split( / /, $scaffold_name );
    my $nToks      = @toks;
    my $tok0       = substr( $toks[0], 0, 3 );
    my $tok1       = substr( $toks[1], 0, 3 );
    my $lastTok    = $toks[ $nToks - 1 ];
    my $lastTokLen = length($lastTok);
    $lastTok = substr( $lastTok, $lastTokLen - 3, 3 ) if $lastTokLen > 3;
    my $s = escHtml($tok0) . "<br/>";
    $s .= escHtml($tok1) . "<br/>" if $tok1 ne "";
    $s .= escHtml($lastTok) if $lastTok ne "" && $nToks >= 3;
    return $s;
}

############################################################################
# printPhyloSelectionList - Show phylogenetically ordered
#   taxon selection list.
############################################################################
sub printPhyloSelectionList {
    my ($dbh) = @_;

    my $imgClause = imgClause('tx');

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause;
    $virusClause = "and tx.domain not like 'Vir%'" if $hideViruses eq "Yes";

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $plasmidClause;
    $plasmidClause = "and tx.domain not like 'Plasmid%'"
      if $hidePlasmids eq "Yes";

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    my $GFragmentClause;
    $GFragmentClause = "and tx.domain not like 'GFragment%'"
      if $hideGFragment eq "Yes";

    my $rclause     = urClause("tx");
    my $taxonClause = txsClause( "tx", $dbh );
    my $sql         = qq{
      select tx.domain, tx.seq_status, tx.taxon_oid, tx.taxon_display_name
      from taxon tx, taxon_stats ts
      where tx.taxon_oid = ts.taxon_oid
      $rclause
      $taxonClause
      $virusClause
      $plasmidClause
      $GFragmentClause
      $imgClause
      order by tx.domain, tx.taxon_display_name
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    print "<select name='profileTaxonBinOid' size='10' multiple>\n";
    my $old_domain;
    my $old_phylum;
    my $old_genus;

    for ( ; ; ) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        print "<option value='t:$taxon_oid'>\n";
        print escHtml($taxon_display_name);
        my $d = substr( $domain,     0, 1 );
        my $c = substr( $seq_status, 0, 1 );
        print " ($d)[$c]";
        print "</option>\n";
    }
    print "</select>\n";
    print "<script language='JavaScript' type='text/javascript'>\n";
    print qq{
      function clearProfileTaxonOidSelections( ) {
         var selector = document.mainForm.profileTaxonBinOid;
	 for( var i = 0; i < selector.length; i++ ) {
	    var e = selector[ i ];
	    e.selected = false;
	 }
	 document.mainForm.minPercIdent.selectedIndex = 0;
	 document.mainForm.maxEvalue.selectedIndex = 0;
      }
   };
    print "</script>\n";
    print "<br/>\n";
}

############################################################################
# printPhyloBinSelectionList - Show phylogenetically ordered
#   taxon with bins selection list.
# marked obsolete because it is not in use by any scripts
############################################################################
sub printPhyloBinSelectionList_OBSOLETE {
    my ($dbh) = @_;

    my $imgClause = imgClause('tx');

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause;
    $virusClause = "and tx.domain not like 'Vir%'" if $hideViruses eq "Yes";

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $plasmidClause;
    $plasmidClause = "and tx.domain not like 'Plasmid%'"
      if $hidePlasmids eq "Yes";

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    my $GFragmentClause;
    $GFragmentClause = "and tx.domain not like 'GFragment%'"
      if $hideGFragment eq "Yes";

    my %defaultBins;
    getDefaultBins( $dbh, \%defaultBins );
    my $rclause     = urClause("tx");
    my $taxonClause = txsClause( "tx", $dbh );
    my $sql         = qq{
      select tx.domain, tx.seq_status, tx.taxon_oid, tx.taxon_display_name,
         b.bin_oid, b.display_name
      from taxon_stats ts, taxon tx
      left join env_sample_gold es
         on tx.env_sample = es.sample_oid
      left join bin b
         on es.sample_oid = b.env_sample
      where tx.taxon_oid = ts.taxon_oid
      $rclause
      $taxonClause
      $virusClause
      $plasmidClause
      $GFragmentClause
      $imgClause
      order by tx.domain, tx.taxon_display_name, tx.taxon_oid, b.display_name
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    print "<select name='profileTaxonBinOid' size='10' multiple>\n";
    my $old_domain;
    my $old_phylum;
    my $old_genus;
    my $old_taxon_oid;

    for ( ; ; ) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name, $bin_oid, $bin_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        if ( $old_taxon_oid ne $taxon_oid ) {
            print "<option value='t:$taxon_oid'>\n";
            print escHtml($taxon_display_name);
            my $d = substr( $domain,     0, 1 );
            my $c = substr( $seq_status, 0, 1 );
            print " ($d)[$c]";
            print "</option>\n";
        }
        if ( $bin_oid ne "" && $defaultBins{$bin_oid} ) {
            print "<option value='b:$bin_oid'>\n";
            print "-- ";
            print escHtml($bin_display_name);
            print " (b)";
            print "</option>\n";
        }
        $old_taxon_oid = $taxon_oid;
    }
    print "</select>\n";
    print "<script language='JavaScript' type='text/javascript'>\n";
    print qq{
      function clearProfileTaxonOidSelections( ) {
         var selector = document.mainForm.profileTaxonBinOid;
	 for( var i = 0; i < selector.length; i++ ) {
	    var e = selector[ i ];
	    e.selected = false;
	 }
	 document.mainForm.minPercIdent.selectedIndex = 0;
	 document.mainForm.maxEvalue.selectedIndex = 0;
      }
   };
    print "</script>\n";
    print "<br/>\n";
}

############################################################################
# printPhyloSelectionListOld - Show phylogenetically ordered
#   taxon selection list.  Old version.  Still need to keep around
#   because used by Abundance.pm.
############################################################################
sub printPhyloSelectionListOld {
    my ($dbh) = @_;

    my $imgClause = imgClause('tx');

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause;
    $virusClause = "and tx.domain not like 'Vir%'" if $hideViruses eq "Yes";

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $plasmidClause;
    $plasmidClause = "and tx.domain not like 'Plasmid%'"
      if $hidePlasmids eq "Yes";

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    my $GFragmentClause;
    $GFragmentClause = "and tx.domain not like 'GFragment%'"
      if $hideGFragment eq "Yes";

    my $rclause     = urClause("tx");
    my $taxonClause = txsClause( "tx", $dbh );
    my $sql         = qq{
      select tx.domain, tx.seq_status, tx.taxon_oid, tx.taxon_display_name
      from taxon tx
      where 1 = 1
      $rclause
      $taxonClause
      $virusClause
      $plasmidClause
      $GFragmentClause
      $imgClause
      order by tx.domain, tx.taxon_display_name
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    print "<select name='profileTaxonOid' size='10' multiple>\n";
    my $old_domain;
    my $old_phylum;
    my $old_genus;

    for ( ; ; ) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        print "<option value='$taxon_oid'>\n";
        print escHtml($taxon_display_name);
        my $d = substr( $domain,     0, 1 );
        my $c = substr( $seq_status, 0, 1 );
        print " ($d)[$c]";
        print "</option>\n";
    }
    print "</select>\n";
    print "<script language='JavaScript' type='text/javascript'>\n";
    print qq{
      function clearProfileTaxonOidSelections( ) {
         var selector = document.mainForm.profileTaxonOid;
	 for( var i = 0; i < selector.length; i++ ) {
	    var e = selector[ i ];
	    e.selected = false;
	 }
      }
   };
    print "</script>\n";
    print "<br/>\n";
}

############################################################################
# getTaxonBinOids - Get taxon or bin oid from printPhyloBinSelectionList.
#    Currently type is either "t" (taxon) or "b" (bin).
# marked obsolete because it is not in use by any scripts
############################################################################
sub getTaxonBinOids_OBSOLETE {
    my ($type) = @_;
    my @toids = param("profileTaxonBinOid");
    my @oids2;
    for my $toid (@toids) {
        my ( $type2, $oid ) = split( /:/, $toid );
        if ( $type2 eq $type ) {
            push( @oids2, $oid );
        }
    }
    return @oids2;
}

############################################################################
# pageLink - Show link within the same HTML page.
############################################################################
sub pageLink {
    my ($title) = @_;
    my $id = $title;
    $id =~ s/\s+//g;
    my $s = "<a href='#$id'>$title</a><br/>\n";
    return $s;
}

############################################################################
# pageAnchor - Show page anchor.
############################################################################
sub pageAnchor {
    my ($title) = @_;
    my $id = $title;
    $id =~ s/\s+//g;
    my $s = "<a name='$id' id='$id'></a>";
    return $s;
}

############################################################################
# printMainForm - Print standard main form declaration.
############################################################################
sub printMainForm {
    if ( $linkTarget ne "" ) {
        print start_form(
            -name   => "mainForm",
            -action => "$main_cgi",
            -target => $linkTarget
        );
    } else {
        print start_form( -name => "mainForm", -action => "$main_cgi" );
    }
}

#
# Same function as printMainForm() but you can
# append a name to mainForm{name}
#
sub printMainFormName {
    my ($postname) = @_;

    my $name = "mainForm" . $postname;
    if ( $linkTarget ne "" ) {
        print start_form(
            -name   => "$name",
            -action => "$main_cgi",
            -target => $linkTarget
        );
    } else {
        print start_form( -name => "$name", -action => "$main_cgi" );
    }
}

############################################################################
# setLinkTarget - Set global window target.
############################################################################
sub setLinkTarget {
    my ($target) = @_;
    $linkTarget = $target;
}

############################################################################
# printNoCache - Print pragma for no-caching.
############################################################################
sub printNoCache {
    print "<meta http-equiv='Pragma' content='no-cache'>\n";
    print "<meta http-equiv='Expires' content='-1'>\n";
}

############################################################################
# getNextBatchId - Get next batch_id for carts.
############################################################################
sub getNextBatchId {
    my ($type) = @_;

    my $batch_id = getSessionParam("${type}_batch_id");
    $batch_id++;
    setSessionParam( "${type}_batch_id", $batch_id );
    return $batch_id;
}

############################################################################
# joinSqlQuoted - Joins values that are single quoted.
############################################################################
sub joinSqlQuoted {
    my ( $delimChar, @a ) = @_;
    my $s;
    for my $i (@a) {
        $i =~ s/'/''/g;
        $s .= "'$i'$delimChar ";
    }
    chop $s;
    chop $s;
    return $s;
}

############################################################################
# geneOid2Name - Convert gene_oid to name.
############################################################################
sub geneOid2Name {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
      select gene_display_name
      from gene
      where gene_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $gene_display_name = $cur->fetchrow();
    $cur->finish();
    return $gene_display_name;
}

############################################################################
# geneOid2AASeqLength - Get amino acid sequence length.
############################################################################
sub geneOid2AASeqLength {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
      select aa_seq_length
      from gene
      where gene_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $aa_seq_length = $cur->fetchrow();
    $cur->finish();
    return $aa_seq_length;
}
############################################################################
# geneOid2AASeq - Get amino acid sequence.
############################################################################
sub geneOid2AASeq {
    my ( $dbh, $gene_oid ) = @_;

    my $rclause   = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
      select g.aa_residue
      from gene g
      where g.gene_oid = ?
      $rclause
      $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $aa_residue = $cur->fetchrow();
    $cur->finish();
    $aa_residue =~ s/\s+//g;
    return $aa_residue;
}

############################################################################
# geneOid2GenomeType
############################################################################
sub geneOid2GenomeType {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
      select tx.genome_type
      from gene g, taxon tx
      where g.gene_oid = ?
      and g.taxon = tx.taxon_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $genome_type = $cur->fetchrow();
    $cur->finish();
    return $genome_type;
}

############################################################################
# taxonOid2Name - Convert taxon_oid to name.
############################################################################
sub taxonOid2Name {
    my ( $dbh, $taxon_oid, $highlightMetagenome ) = @_;

    # scaffold cart
    if ( $scaffold_cart && $taxon_oid < 0 ) {
        require ScaffoldCart;
        my $name = ScaffoldCart::getCartNameForTaxonOid($taxon_oid);
        return $name;
    }

    my $sql = qq{
      select taxon_display_name, genome_type, domain
      from taxon
      where taxon_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $taxon_display_name, $genome_type, $domain ) = $cur->fetchrow();
    $cur->finish();
    $taxon_display_name .= " (*)"
      if $highlightMetagenome && $genome_type eq "metagenome";
    return $taxon_display_name;
}

############################################################################
# sqlInClause - Write in( ... ) SQL clause.  Escape quotes.
############################################################################
sub sqlInClause {
    my (@vals) = @_;
    return "" if scalar(@vals) == 0;
    my $nVals = @vals;
    if ( $nVals > 1000 ) {
        webLog("inSqlClause: too many values: $nVals\n");
        return;
    }
    my $s = " in(";
    for my $v (@vals) {
        $v =~ s/'/''/g;
        $s .= "'$v',";
    }
    chop $s;
    $s .= ") ";
    return $s;
}

############################################################################
# taxonCategoryStrings - Get taxon category from set-valued attributes.
#   Input taxons are in taxonOid2Str_ref keys.
#   Return hash for taxon_oid with comma separted list string in same
#   taxonOid2Str_ref.
############################################################################
sub taxonCategoryStrings {
    my ( $dbh, $categoryName, $taxonOid2Str_ref ) = @_;

    my @keys  = keys(%$taxonOid2Str_ref);
    my $nKeys = @keys;
    if ( $nKeys > 1000 ) {
        webLog("taxonCategoryStrings: too many taxon_oid's: $nKeys\n");
    }
    my $taxon_oid_str = join( ",", @keys );
    my $whereClause;
    checkBlankVar($taxon_oid_str);
    $whereClause = "and ta.taxon_oid in( $taxon_oid_str )"
      if $nKeys > 0;
    my $categoryNameLc = $categoryName;
    $categoryNameLc =~ tr/A-Z/a-z/;
    my $sql = qq{
      select distinct ta.taxon_oid, cv.${categoryNameLc}_term
      from taxon_${categoryName}s ta, ${categoryNameLc}cv cv
      where 1 = 1
      $whereClause
      and ta.${categoryName}s = cv.${categoryNameLc}_oid

   };

    #       order by cv.${categoryNameLc}_term
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $taxon_oid, $val ) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxonOid2Str_ref->{$taxon_oid} .= "$val, ";
    }
    $cur->finish();
    ## Trim last two characters
    @keys = keys(%$taxonOid2Str_ref);
    for my $k (@keys) {
        my $s = $taxonOid2Str_ref->{$k};
        chop $s;
        chop $s;
        $taxonOid2Str_ref->{$k} = $s;
    }
}

############################################################################
# sanitizeInt - Sanitize to integer for security purposes.
############################################################################
sub sanitizeInt {
    my ($s) = @_;
    if ( $s !~ /^[0-9]+$/ ) {
        webDie("sanitizeInt: invalid integer '$s'\n");
    }
    $s =~ /([0-9]+)/;
    $s = $1;
    return $s;
}

############################################################################
# getScaffold2BinNames - Retrieve bin oid and name from scaffold_oid.
############################################################################
sub getScaffold2BinNames {
    my ( $dbh, $scaffold_oid ) = @_;
    my $sql = qq{
        select distinct b.bin_oid, b.display_name, bm.method_name
	from bin b, bin_scaffolds bs, bin_method bm
	where b.bin_oid = bs.bin_oid
	and bs.scaffold = ?
	and b.is_default = 'Yes'
	and b.bin_method = bm.bin_method_oid
	order by b.display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my $bin_display_names;
    for ( ; ; ) {
        my ( $bin_oid, $bin_display_name, $method_name ) = $cur->fetchrow();
        last if !$bin_oid;
        $bin_display_names .= "$bin_display_name($method_name); ";
    }
    $cur->finish();
    chop $bin_display_names;
    chop $bin_display_names;
    return $bin_display_names;
}

############################################################################
# getScaffolds2Bins - Complete the has with scaffold_oid keys with
#    bin_oid \t display_name.
############################################################################
sub getScaffolds2Bins {
    my ( $dbh, $scaffold2Bin_ref ) = @_;
    my @scaffold_oids = sort( keys(%$scaffold2Bin_ref) );
    my @batch;
    for my $scaffold_oid (@scaffold_oids) {
        if ( scalar(@batch) > $max_scaffold_batch ) {
            flushScaffolds2Bins( $dbh, \@batch, $scaffold2Bin_ref );
            @batch = ();
        }
        push( @batch, $scaffold_oid );
    }
    flushScaffolds2Bins( $dbh, \@batch, $scaffold2Bin_ref );
}

sub flushScaffolds2Bins {
    my ( $dbh, $batch_ref, $scaffold2Bin_ref ) = @_;
    return if scalar(@$batch_ref) == 0;
    my $scaffold_oid_str = join( ',', @$batch_ref );
    my $sql              = qq{
        select bs.scaffold, b.bin_oid, b.display_name
	from bin b, bin_scaffolds bs
	where b.bin_oid = bs.bin_oid
	and bs.scaffold in( $scaffold_oid_str )
	and b.is_default = 'Yes'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $scaffold_oid, $bin_oid, $display_name ) = $cur->fetchrow();
        last if !$bin_oid;
        my $r = "$bin_oid\t";
        $r .= "$display_name";
        $scaffold2Bin_ref->{$scaffold_oid} = $r;
    }
    $cur->finish();
}

############################################################################
# binOid2TaxonOid - Convert bin_oid to taxon_oid.
############################################################################
sub binOid2TaxonOid {
    my ( $dbh, $bin_oid ) = @_;
    my $sql = qq{
        select tx.taxon_oid
	from taxon tx, env_sample_gold es, bin b
	where tx.env_sample = es.sample_oid
	and es.sample_oid = b.env_sample
	and b.bin_oid = ?
	and b.is_default = 'Yes'
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ($taxon_oid) = $cur->fetchrow();
    $cur->finish();
    return $taxon_oid;
}

############################################################################
# binOid2Name - Get name for bin.
############################################################################
sub binOid2Name {
    my ( $dbh, $bin_oid ) = @_;
    my $sql = qq{
      select display_name
      from bin
      where bin_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ($name) = $cur->fetchrow();
    $cur->finish();
    return $name;
}

############################################################################
# geneOid2TaxonOid - Map gene_oid to taxon.
############################################################################
sub geneOid2TaxonOid {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
       select taxon
       from gene
       where gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($taxon) = $cur->fetchrow();
    $cur->finish();
    return $taxon;
}

############################################################################
# scaffoldOid2TaxonOid - Get taxon_oid from scaffold_oid.
############################################################################
sub scaffoldOid2TaxonOid {
    my ( $dbh, $scaffold_oid ) = @_;
    my $sql = qq{
        select scf.taxon
	from scaffold scf
	where scf.scaffold_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my ($taxon_oid) = $cur->fetchrow();
    $cur->finish();
    return $taxon_oid;
}

############################################################################
# scaffoldOid2ExtAccession - Retrieve external accession.
############################################################################
sub scaffoldOid2ExtAccession {
    my ( $dbh, $scaffold_oid ) = @_;
    my $sql = qq{
        select scf.ext_accession
	from scaffold scf
	where scf.scaffold_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my ($ext_accession) = $cur->fetchrow();
    $cur->finish();
    return $ext_accession;
}

############################################################################
# getScaffoldSeq - Get sequence give a scaffold_oid and coordinates.
############################################################################
sub getScaffoldSeq {
    my ( $dbh, $scaffold_oid, $start, $end ) = @_;

    my $strand = "+";
    my ( $start_coord, $end_coord ) = ( $start, $end );
    if ( $start > $end ) {
        ( $start_coord, $end_coord ) = ( $end, $start );
        $strand = "-";
    }
    my $sql = qq{
        select taxon, ext_accession
    	from scaffold
    	where scaffold_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my ( $taxon, $ext_accession ) = $cur->fetchrow();
    $cur->finish();
    if ( $taxon eq "" ) {
        webLog( "getScaffoldSeq: cannot find value for " . "scaffold_oid=$scaffold_oid\n" );
        return "";
    }
    my $path = "$taxon_lin_fna_dir/$taxon.lin.fna";
    if ($img_ken) {
        print "<p> getScaffoldSeq: $path </p>\n";
    }
    $path = checkPath($path);
    my $seq = readLinearFasta( $path, $ext_accession, $start_coord, $end_coord, $strand );
    if ( $seq eq "" ) {
        webLog( "getScaffoldSeq: cannot find sequence from " . "'$path':'$ext_accession'\n" );
    }
    return $seq;
}

############################################################################
# lowerAttr - Return lower case version of attribute.
#    Mainly to support Oracle and Mysql, the latter doesn't currently
#    have function indices for lower case indexing.
############################################################################
sub lowerAttr {
    my ( $attr, $forceFunc ) = @_;
    if ( $rdbms eq "mysql" && !$forceFunc ) {

        #return "${attr}_lc";
        return "lower( $attr )";
    }
    return "lower( $attr )";
}

############################################################################
# checkMysqlSearchTerm - Check search term using keywords in MySQL.
############################################################################
sub checkMysqlSearchTerm {
    my ($term) = @_;
    my @toks = split( /\s+/, $term );
    my $nToks = @toks;
    if ( $nToks != 1 ) {
        webError("Only one keyword is supported.");
    }
    if ( length($term) < 4 ) {
        webError("Keyword should be at least 4 characters long.");
    }
}

############################################################################
# getDefaultBins - Get bin_oid's for default bins.
############################################################################
sub getDefaultBins {
    my ( $dbh, $bin_oids_ref ) = @_;
    my $sql = qq{
         select b.bin_oid
	 from bin b
	 where b.is_default = 'Yes'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($bin_oid) = $cur->fetchrow();
        last if !$bin_oid;
        $bin_oids_ref->{$bin_oid} = 1;
    }
    $cur->finish();
}

############################################################################
# escHtml - Escape HTML with HTML space.
#
# good for labels not so for url / uri
# see massageToUrl2() for url's - ken
############################################################################
sub escHtml {
    my ($s) = @_;
    return nbsp(1) if blankStr($s);
    return escapeHTML($s);
}

############################################################################
# escapeQuote  - escape with Double Quote
############################################################################
sub escapeQuote {
    my ($s) = @_;
    my $len = length($s);
    my $s2;
    for ( my $i = 0 ; $i < $len ; $i++ ) {
        my $c = substr( $s, $i, 1 );
        if ( index( "\"'", $c ) >= 0 ) {
            $s2 .= '%' . sprintf( "%02x", ord($c) );
        } else {
            $s2 .= $c;
        }
    }
    return $s2;
}

############################################################################
# printProfileBlastConstraints - Print contraint options for forms
#   in phyloProfiles.
############################################################################
sub printProfileBlastConstraints {

    print "<table class='img' border='1'>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Max. E-value</th>\n";
    print "<td class='img'>\n";
    my $maxEvalue = param("maxEvalue");
    print popup_menu(
        -name    => "maxEvalue",
        -values  => [ 1e-1, 1e-2, 1e-5, 1e-7, 1e-10, 1e-20, 1e-50 ],
        -default => $maxEvalue
    );
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Min. Percent Identity</th>\n";
    print "<td class='img'>\n";
    my $minPercIdent = param("minPercIdent");
    print popup_menu(
        -name    => "minPercIdent",
        -values  => [ 10, 20, 30, 40, 50, 60, 70, 80, 90 ],
        -default => $minPercIdent
    );
    print "</td>\n";
    print "</tr>\n";

    print "</table>\n";
}

############################################################################
# getTaxonRescale - Get rescale for taxon for chromosome viewer.
#   We use some heuristics here.  If these don't work, we
#   use a configuration file for specific genomes.
############################################################################
sub getTaxonRescale {
    my ( $dbh, $taxon_oid ) = @_;
    my $taxon_rescale = 1;

    my $h = $env->{taxon_rescale};
    if ( defined($h) ) {
        my $x = $h->{$taxon_oid};
        $taxon_rescale = $x if $x > 0;
    } else {
        my $sql = qq{
	   select avg_gene_length, avg_intergenic_length
	   from taxon_stats
	   where taxon_oid = ?
	};
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        my ( $avg_gene_length, $avg_intergenic_length ) = $cur->fetchrow();
        $cur->finish();
        my $len = $avg_gene_length;
        $len = $avg_intergenic_length if $avg_intergenic_length > $len;
        if ( $len > 0 ) {
            my $rescale = int( $len / 300 );
            $taxon_rescale = $rescale
              if $rescale > 1;
            webLog "taxon_rescale=$taxon_rescale\n" if $verbose >= 1;
        }
    }
    webLog "taxon_rescale=$taxon_rescale\n" if $verbose >= 2;
    return $taxon_rescale;
}

############################################################################
# loadGeneOid2AltName - Populate structure for alternate gene_display_name
#   for a given contact.  The extract constructs will be
#   added to the SQL to get the contact annotations.
#   The SQL will be rewritten here to include contact information.
#   We assume only one gene with gene_display_name here.
############################################################################
sub loadGeneOid2AltName {
    my ( $dbh, $sql, $geneOid2AltName_ref, $bind_ref ) = @_;

    # Ken did this to see if anyone will notice - 2012-05-04
    return;

    my $userPref = "";
    if ($show_myimg_login) {
        $userPref = getMyIMGPref( $dbh, "MYIMG_PROD_NAME" );
    } else {
        $userPref = 'No';
    }

    if ( blankStr($userPref) || lc($userPref) eq 'yes' ) {

        # use my annotated product name if available
        loadGeneOid2AltNameMyImg( $dbh, $sql, $geneOid2AltName_ref, $bind_ref );
    }

    loadGeneOid2AltNameImgTerm( $dbh, $sql, $geneOid2AltName_ref, $bind_ref )
      if $img_term_overlay;

    if ( tableExists( $dbh, "dt_proxygene_info" ) ) {

        #loadDtProxyGeneInfo( $dbh, $sql, $geneOid2AltName_ref, $bind_ref );
    } else {

        #loadProxyGeneName( $dbh, $sql, $geneOid2AltName_ref, $bind_ref );
    }
    webLog("loadGeneOid2AltName done.\n");
}

sub loadGeneOid2AltNameMyImg {
    my ( $dbh, $sql, $geneOid2AltName_ref, $bind_ref ) = @_;

    my $contact_oid = getContactOid();
    return if !$contact_oid;
    my $sql_username = qq{
        select username, img_group
	from contact
	where contact_oid = ?
    };
    my $cur = execSql( $dbh, $sql_username, $verbose, $contact_oid );
    my ( $username, $img_group ) = $cur->fetchrow();
    $cur->finish();

    my $sql2;
    $sql =~ s/^\s+//;
    $sql =~ s/\s+$//;
    $sql =~ s/,/ , /g;
    $sql =~ s/\(/ (  /g;
    $sql =~ s/\)/ )  /g;
    $sql =~ s/\s+/ /g;
    my @toks = split( / /, $sql );
    my $gAlias = getGeneNameTableAlias( \@toks );
    if ( $gAlias eq "" ) {
        webLog( "loadGeneOid2AltName: cannot find " . "gene_display_name table alias " . "for '$sql'\n" );
        return;
    }
    ## --es 04/10/2006 "distinct" not work with text type
    #$sql2 .= "select distinct $gAlias.gene_oid, a.annotation_text\n";

    # Amy: change to get all group annotations
    $sql2 .= "select $gAlias.gene_oid, a.product_name, c1.username\n";
    $sql2 .= "from gene_myimg_functions a, contact c1, ";
    $sql2 .= getSqlClause( \@toks, "from", { "where" => 1, "group" => 1, "order" => 1 } );
    $sql2 .= "\n";
    $sql2 .= "where a.gene_oid = $gAlias.gene_oid\n";
    if ($img_group) {
        $sql2 .= "and (a.modified_by = $contact_oid or ";

        #$sql2 .= " a.modified_by in (select c2.contact_oid from contact c2 where img_group = $img_group)) ";
        $sql2 .= " exists (select 1 from contact c2 where img_group = $img_group and c2.contact_oid = a.modified_by ))";
    } else {
        $sql2 .= "and a.modified_by = $contact_oid ";
    }
    $sql2 .= "and a.modified_by = c1.contact_oid ";
    $sql2 .= getSqlClause( \@toks, "where", { "group" => 1, "order" => 1 } );
    $sql2 .= "\n";

    webLog ">>> MyIMG alternate SQL\n" if $verbose >= 1;

    #print ">>> MyIMG alternate SQL:<br/>$sql2<br/>\n";
    my $cur2;
    if ( defined($bind_ref) && scalar(@$bind_ref) > 0 ) {
        $cur2 = execSqlBind( $dbh, $sql2, $bind_ref, $verbose );
    } else {
        $cur2 = execSql( $dbh, $sql2, $verbose );
    }
    for ( ; ; ) {
        my ( $gene_oid, $altName, $uname ) = $cur2->fetchrow();
        last if !$gene_oid;
        if ( $geneOid2AltName_ref->{$gene_oid} ) {
            if ( $uname eq $username ) {

                # my annot
                my $annot2 = $geneOid2AltName_ref->{$gene_oid};
                $geneOid2AltName_ref->{$gene_oid} = "$altName (MyIMG:$uname)" . "; " . $annot2;
            } else {
                $geneOid2AltName_ref->{$gene_oid} .= "; $altName (MyIMG:$uname)";
            }
        } else {
            $geneOid2AltName_ref->{$gene_oid} = "$altName (MyIMG:$uname)";
        }
    }
    $cur2->finish();
}

sub loadGeneOid2AltNameImgTerm {
    my ( $dbh, $sql, $geneOid2AltName_ref, $bind_ref ) = @_;

    if ( invalidUnion($sql) ) {
        webLog("loadGeneOid2AltNameImgTerm: union SQL not supported\n");
        print STDERR "loadGeneOid2AltNameImgTerm: union SQL not supported\n";
        webLog($sql);
        return;
    }
    my $sql2;
    $sql =~ s/^\s+//;
    $sql =~ s/\s+$//;
    $sql =~ s/,/ , /g;
    $sql =~ s/\(/ (  /g;
    $sql =~ s/\)/ )  /g;
    $sql =~ s/\s+/ /g;
    my @toks   = split( / /, $sql );
    my $gAlias = getGeneNameTableAlias( \@toks );

    if ( $gAlias eq "" ) {
        webLog( "loadGeneOid2AltName: cannot find gene_display_name " . "table alias for '$sql'\n" );
        return;
    }
    $sql2 .= "select distinct $gAlias.gene_oid, gifx.f_order, ";
    $sql2 .= "itx.term, gifx.f_flag ";
    $sql2 .= "from gene_img_functions gifx, img_term itx, ";
    $sql2 .= getSqlClause( \@toks, "from", { "where" => 1, "group" => 1, "order" => 1 } );
    $sql2 .= "\n";
    $sql2 .= "where $gAlias.gene_oid = gifx.gene_oid\n";
    $sql2 .= "and gifx.function = itx.term_oid\n";
    $sql2 .= getSqlClause( \@toks, "where", { "group" => 1, "order" => 1 } );

    #$sql2 .= "\norder by $gAlias.gene_oid, gifx.f_order\n";
    $sql2 .= "\n";

    webLog ">>> IMG Term alternate SQL\n" if $verbose >= 1;

    #print ">>> IMG Term alternate SQL:<br/>$sql2<br/>\n";
    my $cur;
    if ( defined($bind_ref) && scalar(@$bind_ref) > 0 ) {
        $cur = execSqlBind( $dbh, $sql2, $bind_ref, $verbose );
    } else {
        $cur = execSql( $dbh, $sql2, $verbose );
    }
    my %geneOid2ImgTerms;
    my %geneOid2ImgFflags;
    for ( ; ; ) {
        my ( $gene_oid, $f_order, $term, $f_flag ) = $cur->fetchrow();
        last if !$gene_oid;
        $geneOid2ImgTerms{$gene_oid}  .= "$term / ";
        $geneOid2ImgFflags{$gene_oid} .= "$f_flag/";
    }
    $cur->finish();
    my @keys = keys(%geneOid2ImgTerms);
    for my $gene_oid (@keys) {
        my $altName = $geneOid2AltName_ref->{$gene_oid};
        next if $altName ne "";
        my $imgTerms = $geneOid2ImgTerms{$gene_oid};
        chop $imgTerms;
        chop $imgTerms;
        chop $imgTerms;
        my $f_flags = $geneOid2ImgFflags{$gene_oid};
        chop $f_flags;
        my $x;
        $x = ":$f_flags" if $img_internal;
        $geneOid2AltName_ref->{$gene_oid} = "$imgTerms (IMGterm$x)";

        #$geneOid2AltName_ref->{ $gene_oid } = "$imgTerms";
    }
}

sub loadProxyGeneName {
    my ( $dbh, $sql, $geneOid2AltName_ref, $bind_ref ) = @_;

    my $sql2;
    $sql =~ s/^\s+//;
    $sql =~ s/\s+$//;
    $sql =~ s/,/ , /g;
    $sql =~ s/\(/ (  /g;
    $sql =~ s/\)/ )  /g;
    $sql =~ s/\s+/ /g;
    my @toks = split( / /, $sql );
    my $gAlias = getGeneNameTableAlias( \@toks );
    if ( $gAlias eq "" ) {
        webLog( "loadGeneOid2AltName: cannot find " . "gene_display_name table alias " . "for '$sql'\n" );
        return;
    }
    my $to_char = "to_char";
    my $to_char_x;
    if ( $rdbms eq "mysql" ) {
        $to_char   = "cast";
        $to_char_x = "as char";
    }
    $sql2 .= "select $gAlias.gene_oid, $gAlias.gene_display_name, ";
    $sql2 .= "$gAlias.est_copy, tprox2.taxon_display_name\n";
    $sql2 .= "from taxon tprox1, gene_ext_links gproxl, ";
    $sql2 .= "gene gprox2, taxon tprox2, ";
    $sql2 .= getSqlClause( \@toks, "from", { "where" => 1, "group" => 1, "order" => 1 } );
    $sql2 .= "\n";
    $sql2 .= "where $gAlias.taxon = tprox1.taxon_oid\n";
    $sql2 .= "and tprox1.is_proxygene_set = 'Yes'\n";
    $sql2 .= "and $gAlias.gene_oid = gproxl.gene_oid\n";
    $sql2 .= "and gproxl.db_name = 'gene_oid'\n";
    $sql2 .= "and gproxl.id = $to_char( gprox2.gene_oid $to_char_x )\n";
    $sql2 .= "and gprox2.taxon = tprox2.taxon_oid\n";
    $sql2 .= getSqlClause( \@toks, "where", { "group" => 1, "order" => 1 } );
    $sql2 .= "\n";

    webLog ">>> Proxy gene alternate SQL\n" if $verbose >= 1;

    #print ">>> Proxy gene alternate SQL:<br/>$sql2<br/>\n";
    my $cur;
    if ( defined($bind_ref) && scalar(@$bind_ref) > 0 ) {
        $cur = execSqlBind( $dbh, $sql2, $bind_ref, $verbose );
    } else {
        $cur = execSql( $dbh, $sql2, $verbose );
    }
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $est_copy, $pr_taxon_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        my $gene_description = "$gene_display_name ";
        $gene_description .= "(n_reads=$est_copy) ";
        $gene_description .= "[[proxy from $pr_taxon_display_name]]";
        $geneOid2AltName_ref->{$gene_oid} = $gene_description;
    }
    $cur->finish();
}

sub loadDtProxyGeneInfo_old {
    my ( $dbh, $sql, $geneOid2AltName_ref, $bind_ref ) = @_;

    my $sql2;
    $sql =~ s/^\s+//;
    $sql =~ s/\s+$//;
    $sql =~ s/,/ , /g;
    $sql =~ s/\(/ (  /g;
    $sql =~ s/\)/ )  /g;
    $sql =~ s/\s+/ /g;
    my @toks = split( / /, $sql );
    my $gAlias = getGeneNameTableAlias( \@toks );
    if ( $gAlias eq "" ) {
        webLog( "loadGeneOid2AltName: cannot find " . "gene_display_name table alias " . "for '$sql'\n" );
        return;
    }
    my $to_char = "to_char";
    my $to_char_x;
    if ( $rdbms eq "mysql" ) {
        $to_char   = "cast";
        $to_char_x = "as char";
    }
    $sql2 .= "select $gAlias.gene_oid, $gAlias.gene_display_name, ";
    $sql2 .= "pi.est_copy, pi.taxon_display_name\n";
    $sql2 .= "from dt_proxygene_info pi,";
    $sql2 .= getSqlClause( \@toks, "from", { "where" => 1, "group" => 1, "order" => 1 } );
    $sql2 .= "\n";
    $sql2 .= "where $gAlias.gene_oid = pi.gene_oid\n";
    $sql2 .= getSqlClause( \@toks, "where", { "group" => 1, "order" => 1 } );
    $sql2 .= "\n";

    webLog ">>> Dt Proxy gene alternate SQL\n" if $verbose >= 1;

    #print ">>> Dt Proxy gene alternate SQL:<br/>$sql2<br/>\n";
    my $cur;
    if ( defined($bind_ref) && scalar(@$bind_ref) > 0 ) {
        $cur = execSqlBind( $dbh, $sql2, $bind_ref, $verbose );
    } else {
        $cur = execSql( $dbh, $sql2, $verbose );
    }
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $est_copy, $pr_taxon_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        my $gene_description = "$gene_display_name ";
        $gene_description .= "(n_reads=$est_copy) ";
        $gene_description .= "[[proxy from $pr_taxon_display_name]]";
        $geneOid2AltName_ref->{$gene_oid} = $gene_description;
    }
    $cur->finish();

}

############################################################################
# getMyIMGPref - Get MyIMG user preference from database
#
# (under construction - wait for the table to be added to the database)
############################################################################
sub getMyIMGPref {
    my ( $dbh, $tag ) = @_;

    my $val = "";

    #
    #    my $contact_oid = getContactOid();
    #    return "" if !$contact_oid;
    #
    #    my $sql = qq{
    #        select value
    #	    from contact_myimg_prefs
    #	    where contact_oid = ?
    #    };
    #    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    #    my ($val) = $cur->fetchrow();
    #    if ( !$val ) {
    #        $val = "";
    #    }
    #    $cur->finish();

    return $val;
}

############################################################################
# invalidUnion - Check for invalid use of "union".  Union is only
# allowed in conjunction with contact_taxon_permissions.
############################################################################
sub invalidUnion {
    my ($s) = @_;

    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    $s =~ s/\s+/ /g;

    my @toks = split( / /, $s );
    my $nToks = @toks;
    for ( my $i = 0 ; $i < $nToks ; $i++ ) {
        my $tok  = $toks[$i];
        my $tok2 = $toks[ $i + 2 ];
        my $tok3 = $toks[ $i + 3 ];
        if (   $tok eq "union"
            && $tok2 !~ /taxon_permissions/
            && $tok3 !~ /taxon_permissions/ )
        {
            return 1;
        }
    }
    return 0;
}

############################################################################
# getGeneNameTableAlias - Get appropriate alias for gene table.
############################################################################
sub getGeneNameTableAlias {
    my ($toks_ref) = @_;

    my $sql = join( ' ', @$toks_ref );
    for my $t (@$toks_ref) {
        my ( $tabAlias, $attr ) = split( /\./, $t );
        if ( $attr eq "gene_display_name" ) {
            return $tabAlias;
        }
        last if $t eq "from";
    }
    return "";
}

############################################################################
# getSqlClause - Get a section of SQL clause without the initiating
#    keyword.
# Inputs:
#   toks_ref - Token input list.
#   type - type of clause ( "from", "where", etc.)
#   fenceToks_ref - Hash of terminating tokens.
#
# Handle one level of nested queries.
############################################################################
sub getSqlClause {
    my ( $toks_ref, $type, $fenceToks_ref ) = @_;

    my $inClause = 0;
    my $s;
    my $tokCount = 0;
    my $nToks    = @$toks_ref;
    for ( my $i = 0 ; $i < $nToks ; $i++ ) {
        my $t = $toks_ref->[$i];
        last if $fenceToks_ref->{$t} ne "";
        if ( $t eq $type ) {
            $inClause = 1;
            next;
        }
        if ($inClause) {
            $tokCount++;
            if ( $tokCount == 1 && $t ne "and" && $type eq "where" ) {
                $s .= "and ";
            }
            if ( $t eq "left" || $t eq "and" ) {
                $s .= "\n";
            }
            $s .= "$t ";
            if ( $type eq "where" && $t eq "in" ) {
                $s .= "\n";
                ## Flush subquery at one level.
                for ( $i = $i + 1 ; $i < $nToks ; $i++ ) {
                    my $t2 = $toks_ref->[$i];
                    $s .= "$t2 ";
                    last if $t2 eq ")";
                }
            }
        }
    }
    return $s;
}

############################################################################
# loadGeneOid2AltName4OidList - Load list from geneOids_ref list.
############################################################################
sub loadGeneOid2AltName4OidList {
    my ( $dbh, $geneOids_ref, $geneOid2AltName_ref ) = @_;

    my @batch;
    for my $gene_oid (@$geneOids_ref) {
        if ( scalar(@batch) > $max_gene_batch ) {
            flushLoadGeneOid2AltName4OidList( $dbh, \@batch, $geneOid2AltName_ref );
            @batch = ();
        }
        push( @batch, $gene_oid );
    }
    flushLoadGeneOid2AltName4OidList( $dbh, \@batch, $geneOid2AltName_ref );
}

sub flushLoadGeneOid2AltName4OidList {
    my ( $dbh, $geneOids_ref, $geneOid2AltName_ref ) = @_;

    my $nGenes = @$geneOids_ref;
    return if $nGenes == 0;
    my $gene_oid_str = join( ',', @$geneOids_ref );

    my $sql = qq{
        select ag.genes, a.annotation_text
	from annotation a, annotation_genes ag
	where a.annot_oid = ag.annot_oid
	and ag.genes in( $gene_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $annotation_text ) = $cur->fetchrow();
        last if !$gene_oid;
        $geneOid2AltName_ref->{$gene_oid} = $annotation_text;
    }
    $cur->finish();
}

############################################################################
# getTaxonGeneCount - Return has with gene counts for taxon_oid keys.
############################################################################
sub getTaxonGeneCount {
    my ( $dbh, $taxonOid2GeneCount_ref ) = @_;

    my @taxon_oids = sort( keys(%$taxonOid2GeneCount_ref) );
    my $nTaxons    = @taxon_oids;
    return if $nTaxons == 0;
    if ( $nTaxons > 1000 ) {
        webDie("getTaxonGeneCounts: too many taxons $nTaxons\n");
    }
    my $taxon_oid_str = join( ',', @taxon_oids );
    checkBlankVar($taxon_oid_str);
    my $sql = qq{
	select ts.taxon_oid, ts.total_gene_count
	from taxon_stats ts
	where ts.taxon_oid in( $taxon_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $total_gene_count ) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxonOid2GeneCount_ref->{$taxon_oid} = $total_gene_count;
    }
    $cur->finish();
}

############################################################################
# getBinGeneCount - Return has with gene counts for bin_oid keys.
############################################################################
sub getBinGeneCount {
    my ( $dbh, $binOid2GeneCount_ref ) = @_;

    my @bin_oids = sort( keys(%$binOid2GeneCount_ref) );
    my $nBins    = @bin_oids;
    return if $nBins == 0;
    if ( $nBins > 1000 ) {
        webDie("getBinGeneCounts: too many bins $nBins\n");
    }
    my $bin_oid_str = join( ',', @bin_oids );
    my $sql         = qq{
	select b.bin_oid, count( distinct g.gene_oid )
	from bin b, bin_scaffolds bs, gene g
	where b.bin_oid in( $bin_oid_str )
	and b.bin_oid = bs.bin_oid
	and bs.scaffold = g.scaffold
	and g.obsolete_flag = 'No'
	group by b.bin_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $bin_oid, $cnt ) = $cur->fetchrow();
        last if !$bin_oid;
        $binOid2GeneCount_ref->{$bin_oid} = $cnt;
    }
    $cur->finish();
}

############################################################################
# getClusterScaleMeanStdDev - Get records for cluster_id.
#
# $oracle_gtt_str - oracle limit data should be in gtt already
#    see FuncCartStor::printFuncCartProfile_s
############################################################################
sub getClusterScaleMeanStdDev {
    my ( $dbh, $tableName, $idAttr, $clusterScaleMeanStdDev_ref, $oracle_gtt_str ) = @_;

    my @ids  = sort( keys(%$clusterScaleMeanStdDev_ref) );
    my $nIds = @ids;
    return if $nIds == 0;
    if ( $nIds > 1000 && $oracle_gtt_str eq "" ) {
        webDie("getClusterScaleMeanStdDev: too many ID's $nIds\n");
    }
    my $id_str = joinSqlQuoted( ",", @ids );
    $id_str = $oracle_gtt_str if ( $oracle_gtt_str ne "" );
    my $sql = qq{
	select dt.$idAttr, dt.scale, dt.mean, dt.std_dev
	from $tableName dt
	where dt.$idAttr in( $id_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $scale, $mean, $std_dev ) = $cur->fetchrow();
        last if !$scale;
        my $r = "$scale\t";
        $r .= "$mean\t";
        $r .= "$std_dev\t";
        $clusterScaleMeanStdDev_ref->{$id} = $r;
    }
    $cur->finish();
}

############################################################################
# geneCountWrap - Utility routine to return gene count or z-score,
#    floored at 0.
############################################################################
sub geneCountWrap {
    my ( $gene_count, $total_gene_count, $cluster_id, $clusterScaleMeanStdDev_ref, $znorm ) = @_;
    return $gene_count if !$znorm;
    if ( $total_gene_count == 0 ) {

        #webLog( "geneCountWrap: total_gene_count=$total_gene_count\n" );
        return 0;
    }
    my $r = $clusterScaleMeanStdDev_ref->{$cluster_id};
    my ( $scale, $mean, $std_dev ) = split( /\t/, $r );
    if ( $std_dev == 0 ) {
        webLog( "geneCountWrap: cluster_id='$cluster_id' " . "bad std_dev=$std_dev r='$r'\n" );
        return 0;
    }
    my $x    = ( $gene_count / $total_gene_count ) * $scale;
    my $diff = $x - $mean;
    my $z    = $diff / $std_dev;
    $z = 0 if $z < 0;    # floor at 0
    return sprintf( "%.2f", $z );
}

############################################################################
# printZnormNote - Print z-normalizations note.
############################################################################
sub printZnormNote {
    print qq{
       <h1>Z-score Normalization</h1>
       <p>
       A z-score for a value is defined as <br/>
       <br/>
       &nbsp;
       &nbsp;
       <i>
	  z(x) = ( x - mean(X) ) / std_deviation(X)
       </i>
       <br/>
       </p>
       <p>
       In this case <i>x = gene_count / total_number_genes</i>
       in a genome for a functional cluster (such
       as COG and Pfam), or the "frequency" of occurrence
       of a functional cluster in a genome normalized by "size"
       (total number of genes).
       </p>
       <p>
       The z-score may show a cluster frequency as "overabundant",
       i.e., normalized counts of genes for a given cluster that are
       at the extreme end of the normal distribution.
       The distribution of frequencies (x) for each cluster identifier
       is generated from all non-viral genomes in IMG (Bacterial,
       Archaeal, Eukaryota, and Metagnome).
       <i>X</i> is a vector
       of all <i>x's</i> for a cluster across these genomes.
       </p>
       <p>
       z-scores less than zero are floored to zero (ignored for
       cosmetic purposes) since we're mainly concerned about
       "overabundance".  (0.00 is the mean frequency
       for the cluster occurrence. 1.00 represents a frequency
       > 68% of the values,
       and 2.00 > 99% of the values on the normal distribution.
       The z-score represents the number of standard deviations away
       from the mean.)
       </p>
       <p>
       The method described here is currently experimental.
       It is intended for comparing metagenomes which
       are <i>samples</i> rather than individual organisms.
       The method may also be used for comparing metagenomes
       with isolate genomes, and isolates with isolates
       by treating isolates as <i>samples</i>.
       </p>
    };
}

############################################################################
# imgTerm2Pathways - Get IMG pathways from recursive list of IMG terms.
############################################################################
sub imgTerm2Pathways {
    my ( $dbh, $root, $terms_ref, $outPathwayOids_ref ) = @_;

    my $nTerms = @$terms_ref;
    return if $nTerms == 0;

    my %term_oids_h;
    for my $term_oid0 (@$terms_ref) {
        my $n = $root->findNode($term_oid0);
        if ( !defined($n) ) {
            webLog("imgTerm2Pathways: cannot find term_oid='$term_oid0'\n");
            next;
        }
        $n->loadAllParentTermOidsHashed( \%term_oids_h );
    }
    my @term_oids = keys(%term_oids_h);
    my $term_oid_str = join( ',', @term_oids );
    if ( blankStr($term_oid_str) ) {
        warn("imgTerms2Pathways: WARNING no term_oids retrieved\n");
        return;
    }
    my $sql = qq{
        select ipr.pathway_oid
        from img_reaction_catalysts irc, img_pathway_reactions ipr
        where irc.catalysts in( $term_oid_str )
        and irc.rxn_oid = ipr.rxn
	    union
        select ipr.pathway_oid
        from img_reaction_t_components itc,
	   img_pathway_reactions ipr, img_pathway ipw
	where itc.term in( $term_oid_str )
        and itc.rxn_oid = ipr.rxn
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($pathway_oid) = $cur->fetchrow();
        last if !$pathway_oid;
        $outPathwayOids_ref->{$pathway_oid} = $pathway_oid;
    }
    $cur->finish();
}

############################################################################
# imgTerm2PartsList - Map IMG terms (recursive) to parts list.
############################################################################
sub imgTerm2PartsList {
    my ( $dbh, $root, $terms_ref, $outPartsListOids_ref ) = @_;

    my $nTerms = @$terms_ref;
    return if $nTerms == 0;

    my %term_oids_h;
    for my $term_oid0 (@$terms_ref) {
        my $n = $root->findNode($term_oid0);
        if ( !defined($n) ) {
            webLog("imgTerm2PartsList: cannot find term_oid='$term_oid0'\n");
            next;
        }
        $n->loadAllParentTermOidsHashed( \%term_oids_h );
    }
    my @term_oids = keys(%term_oids_h);
    my $term_oid_str = join( ',', @term_oids );
    if ( blankStr($term_oid_str) ) {
        webDie("imgTerms2PartsList: ERROR no term_oids retrieved\n");
    }
    my $sql = qq{
        select plt.parts_list_oid
	from img_parts_list_img_terms plt
	where plt.term in( $term_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($parts_list_oid) = $cur->fetchrow();
        last if !$parts_list_oid;
        $outPartsListOids_ref->{$parts_list_oid} = $parts_list_oid;
    }
    $cur->finish();
}

############################################################################
# getTaxonOidNames - Get taxon_oid and names sorted by name.
#   Use batch flush method.
############################################################################
sub getTaxonOidNames {
    my ( $dbh, $taxonOids_ref, $outRecs_ref ) = @_;
    my @batch;
    my @recs;
    for my $taxon_oid (@$taxonOids_ref) {
        if ( scalar(@batch) > $max_taxon_batch ) {
            flushTaxonOidNames( $dbh, \@batch, \@recs );
            @batch = ();
        }
        push( @batch, $taxon_oid );
    }
    flushTaxonOidNames( $dbh, \@batch, \@recs );
    my @recs2 = sort(@recs);
    for my $r (@recs2) {
        my ( $domain, $seq_status, $taxon_display_name, $taxon_oid ) =
          split( /\t/, $r );
        my $r2;
        $r2 .= "$domain\t";
        $r2 .= "$seq_status\t";
        $r2 .= "$taxon_oid\t";
        $r2 .= "$taxon_display_name";
        push( @$outRecs_ref, $r2 );
    }
}

sub flushTaxonOidNames {
    my ( $dbh, $taxonOids_ref, $recs_ref ) = @_;
    my $taxon_oid_str = join( ',', @$taxonOids_ref );
    return if blankStr($taxon_oid_str);
    my $sql = qq{
	select
	   tx.domain,
	   tx.seq_status,
	   tx.taxon_display_name, tx.taxon_oid
	from taxon tx
	where tx.taxon_oid in( $taxon_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $domain, $seq_status, $taxon_display_name, $taxon_oid ) = $cur->fetchrow();
        last if !$taxon_oid;
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        my $r;
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= "$taxon_display_name\t";
        $r .= "$taxon_oid";
        push( @$recs_ref, $r );
    }
    $cur->finish();
}

############################################################################
# validEnvBlastDbs - Get valid environmental BLAST DB's for
#   user's permissions.
#      --es 06/20/2007
############################################################################
sub validEnvBlastDbs {
    my ($dbh) = @_;

    my $imgClause = imgClause('tx');

    my %validDbs;

    my $contact_oid = getContactOid();

    return %validDbs if !defined($env_blast_defaults);

    my $sql = qq{
	select tx.taxon_oid, tx.jgi_species_code
	from taxon tx
	where 1 = 1
	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $jgi_species_code ) = $cur->fetchrow();
        last if !$taxon_oid;
        my $db = $env_blast_defaults->{$jgi_species_code};
        next if $db eq "";
        $validDbs{$db} = 1;
    }
    $cur->finish();

    return %validDbs if !$contact_oid;

    $sql = qq{
	select tx.taxon_oid, tx.jgi_species_code
	from contact_taxon_permissions ctp, taxon tx
	where ctp.contact_oid = $contact_oid
	and ctp.taxon_permissions = tx.taxon_oid
    };
    $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $jgi_species_code ) = $cur->fetchrow();
        last if !$taxon_oid;
        my $db = $env_blast_defaults->{$jgi_species_code};
        next if $db eq "";
        $validDbs{$db} = 1;
    }
    $cur->finish();
    return %validDbs;
}

############################################################################
# getAnnotation - Get MyIMG annotation.
############################################################################
sub getAnnotation {
    my ( $dbh, $gene_oid, $contact_oid ) = @_;

    my $sql = qq{
       select a.annot_oid, a.annotation_text
       from annotation a, annotation_genes ag
       where a.annot_oid = ag.annot_oid
       and ag.genes = ?
       and author = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $contact_oid );
    my $text;
    my $count = 0;
    for ( ; ; ) {
        my ( $annot_oid, $annotation ) = $cur->fetchrow();
        last if !$annot_oid;
        $count++;
        $text = $annotation;
    }
    $cur->finish();
    if ( $count > 1 ) {
        webLog( "getAnnotation: found $count annotation for " . "gene_oid=$gene_oid contact_oid=$contact_oid\n" );
    }
    return $text;
}

############################################################################
# firstDashTok - Take first token in keyword separated by dashes,
#   or actually, underscores.
############################################################################
sub firstDashTok {
    my ($s) = @_;
    my (@toks) = split( /_/, $s );
    return $toks[0];
}

############################################################################
# lastColonTok - Take last token in keyword separated by colon(:).
############################################################################
sub lastColonTok {
    my ($s)    = @_;
    my (@toks) = split( /:/, $s );
    my $size   = scalar(@toks);
    return $toks[ $size - 1 ];
}

############################################################################
# dateSortVal - Make up a sort value for client side date sorting.
#   We handle one case for the time being:  Oracle's default DD-MON-YY.
############################################################################
sub dateSortVal {
    my ($s) = @_;
    my ( $dy, $mon, $yr ) = split( /-/, $s );
    if ( $dy < 0 || $dy > 31 ) {
        webDie("dateSortVal: unexpected day '$dy'\n");
    }
    my %months = (
        JAN => 1,
        FEB => 2,
        MAR => 3,
        APR => 4,
        MAY => 5,
        JUN => 6,
        JUL => 7,
        AUG => 8,
        SEP => 9,
        OCT => 10,
        NOV => 11,
        DEC => 12,
    );
    my $mnVal = $months{$mon};
    if ( $mnVal eq "" ) {
        webDie("dateSortVal: unexpected month '$mon'\n");
    }
    my $val = sprintf( "%02d-%02d-%02d", $yr, $mnVal, $dy );
    return $val;
}

############################################################################
# printTruncatedStatus - Print status line with truncated note.
#   This is the "Max. Gene List Results" version.
############################################################################
sub printTruncatedStatus {
    my ($maxGeneListResults) = @_;
    print "<br/>\n";
    my $s = "Results limited to $maxGeneListResults genes.\n";
    $s .= "( Go to ";
    $s .= alink( $preferences_url, "Preferences" );
    $s .= " to change \"Max. Gene List Results\" limit. )\n";
    printStatusLine( $s, 2 );
}

############################################################################
# nbspWrap - Show &nbsp; for tables with blank string.
############################################################################
sub nbspWrap {
    my ($s) = @_;
    return $s if !blankStr($s);
    return nbsp(1);
}

############################################################################
# printAddQueryGeneCheckBox - Add checkbox for query gene.
############################################################################
sub printAddQueryGeneCheckBox {
    my ($gene_oid) = @_;

    print "<p>\n";
    print "<input type='checkbox' name='gene_oid' value='$gene_oid' checked />\n";
    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
    my $link = alink( $url, $gene_oid );
    print "Add query gene $link<br/>\n";
    print "</p>\n";
}

############################################################################
# getAASeqLength - Get amino acid sequence length.
############################################################################
sub getAASeqLength {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
       select g.aa_seq_length
       from gene g
       where g.gene_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($aa_seq_length) = $cur->fetchrow();
    $cur->finish();
    return $aa_seq_length;
}

############################################################################
# getAASequence - Get amino acid sequence.
############################################################################
sub getAASequence {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
        select g.aa_residue
        from gene g
        where g.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $aa_residue = $cur->fetchrow();
    $cur->finish();
    return $aa_residue;
}

############################################################################
# emailLink - Show email link
############################################################################
sub emailLink {
    my ($email) = @_;
    if ( $email =~ /MISSING/ || blankStr($email) || $email eq "none" ) {
        return nbsp(1);
    }
    return "<a href='mailto:$email'>" . escHtml($email) . "</a>";
}

############################################################################
# emailLinkParen - Add parenthesis with email inside.
############################################################################
sub emailLinkParen {
    my ($email) = @_;
    if ( $email =~ /MISSING/ || blankStr($email) || $email eq "none" ) {
        return "";
    }
    return sprintf( " (%s)", emailLink($email) );
}

############################################################################
# urlGet - Get contents of a URL.
############################################################################
sub urlGet {
    my ($url) = @_;

    my $ua = myLwpUserAgent();
    $ua->timeout(5);
    $ua->agent("IMG 2.0 ");
    my $req = new HTTP::Request 'GET' => $url;
    my $res = $ua->request($req);
    if ( $res->is_success ) {
        if ( $res->content =~ /error/i ) {
            return "";
        } elsif ( $res->content =~ /exception/i ) {

            # java errors in page
            return "";
        } elsif ( $res->content =~ /script/i ) {

            # page has script code
            return "";
        }
        return $res->content;
    } else {
        webLog( $res->status_line() . "\n" );
        return "";
    }
}

#
# ssl bad cert temp fix / work around
#
sub myLwpUserAgent {
    my $ua = new LWP::UserAgent();

    # a temp fix for ssl cert issues - ken 2014-07-28
    # Doug has fixed the bad cert - I can commit out the below line
    # all servers are fixed

    # $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);

    return $ua;
}

############################################################################
# printAllParams - print all params for debugging  uses
############################################################################
sub printAllParams {
    my @all_params = $cgi->param;
    foreach my $p (@all_params) {
        my @values = param($p);
        foreach my $v (@values) {
            print "<p>param: [$p]   value: [$v]</p>";
        }
    }
}

############################################################################
# paramMatch - One of the parameters matches this substring.
############################################################################
sub paramMatch {
    my ($pattern) = @_;

    my @all_params = $cgi->param;

    #    webLog("all_params: @all_params\n");
    for my $p (@all_params) {
        if ( $p =~ /$pattern/ ) {
            return $p;
        }
    }
    return "";
}

############################################################################
# paramCast - Cast parmater value to a certain format for perl taint.
############################################################################
sub paramCast {
    my ( $tag, $pattern ) = @_;

    my $val      = param($tag);
    my $pattern2 = "($pattern)";
    $val =~ /$pattern2/;
    my $val2 = $1;
    if ( $val ne $val2 ) {
        warn("paramCast: '$val' cast to '$val2'\n");
    }
    return $val2;
}

############################################################################
# printGenesToExcel - Print gene table for exporting to excel.
############################################################################
sub printGenesToExcel {
    my ($gene_oids_ref) = @_;
    print "gene_oid\t";
    print "Locus Tag\t";
    print "Gene Symbol\t";
    print "Product Name\t";
    print "AA Seq Length\t";
    print "Genome\n";
    my $gene_oid_str = join( ",", @$gene_oids_ref );
    return if blankStr($gene_oid_str);
    my @genes_oids = sort(@$gene_oids_ref);
    my @batch;
    my $dbh = dbLogin();

    for my $gene_oid (@genes_oids) {
        if ( scalar(@batch) > 500 ) {
            flushGenesToExcel( $dbh, \@batch );
            @batch = ();
        }
        push( @batch, $gene_oid );
    }
    flushGenesToExcel( $dbh, \@batch );

    #$dbh->disconnect();
}

############################################################################
# flushGenesToExcel - Flush buffer genes to Excel.
############################################################################
sub flushGenesToExcel {
    my ( $dbh, $gene_oids_ref ) = @_;

    my $gene_oid_str = join( ',', @$gene_oids_ref );
    my $sql          = qq{
       select g.gene_oid, g.gene_display_name,
         g.locus_type, g.locus_tag, g.gene_symbol, g.aa_seq_length,
         tx.taxon_oid, tx.ncbi_taxon_id, tx.taxon_display_name
       from taxon tx, gene g
       where g.taxon = tx.taxon_oid
       and g.gene_oid in ( $gene_oid_str )
       order by tx.taxon_display_name, g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @recs;
    my %gene2Enzyme;

    for ( ; ; ) {
        my (
            $gene_oid,      $gene_display_name, $locus_type,    $locus_tag, $gene_symbol,
            $aa_seq_length, $taxon_oid,         $ncbi_taxon_id, $taxon_display_name
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$locus_type\t";
        $rec .= "$locus_tag\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$taxon_display_name";
        push( @recs, $rec );
    }
    my %done;
    for my $r (@recs) {
        my (
            $gene_oid,      $gene_display_name, $locus_type,    $locus_tag, $gene_symbol,
            $aa_seq_length, $taxon_oid,         $ncbi_taxon_id, $taxon_display_name
          )
          = split( /\t/, $r );
        next if $done{$gene_oid} ne "";

        $gene_display_name = " ( $locus_type ) " if $locus_type ne "CDS";
        print "$gene_oid\t";
        print "$locus_tag\t";
        print "$gene_symbol\t";
        my $desc = "$gene_display_name";
        $desc =~ s/"/'/g;
        print "$desc\t";
        print "$aa_seq_length\t";
        print "$taxon_display_name\n";
        $done{$gene_oid} = 1;
    }
    $cur->finish();
}

############################################################################
# pearsonCorr - Compute pearson correlation r.
#   @param x_ref - reference to array x
#   @param y_ref - reference to array y
#   @return r
############################################################################
sub pearsonCorr {
    my ( $x_ref, $y_ref ) = @_;

    my $sum_xy = 0;
    my $sum_xx = 0;
    my $sum_x  = 0;
    my $sum_y  = 0;
    my $sum_yy = 0;
    my $n1     = @$x_ref;
    my $n2     = @$y_ref;
    if ( $n1 != $n2 ) {
        warn("pearsonCorr: n1=$n1 n2=$n2 do not match\n");
    }
    my $n = $n1;
    $n = $n < $n2 ? $n : $n2;
    for ( my $i = 0 ; $i < $n ; $i++ ) {
        my $x = $x_ref->[$i];
        my $y = $y_ref->[$i];
        $sum_x  += $x;
        $sum_y  += $y;
        $sum_xy += $x * $y;
        $sum_xx += $x * $x;
        $sum_yy += $y * $y;
    }
    my $num0  = $sum_xy - ( ( $sum_x * $sum_y ) / $n );
    my $den_x = $sum_xx - ( ( $sum_x * $sum_x ) / $n );
    my $den_y = $sum_yy - ( ( $sum_y * $sum_y ) / $n );
    my $r     = 0;
    if ( sqrt( $den_x * $den_y ) ) {
        $r = $num0 / sqrt( $den_x * $den_y );
    }
    return $r;
}

############################################################################
# getArrayFromFile - read file, process text, get array
#     convert each line into an array element
#     (option) strip=1 : remove newline at end of line
#     (option) clean=1 : discard empty lines
############################################################################
sub getArrayFromFile {
    my ( $filename, $stripOption, $cleanOption ) = @_;
    my @newArray = ();
    my $rfh      = newReadFileHandle("$cgi_tmp_dir/$filename");
    while ( my $line = $rfh->getline() ) {
        chomp $line if ( $stripOption eq 1 );
        push( @newArray, $line ) if ( $cleanOption ne 1 || $line ne "" );
    }
    return \@newArray;
}

############################################################################
# sortByTaxonName - Sort taxon_oid's by taxon_display_name.
#   @taxonOids_ref - Array reference of taxon_oid's.
#   @return - List of sorted taxon_oid's.
############################################################################
sub sortByTaxonName {
    my ( $dbh, $taxonOids_ref ) = @_;

    my $taxon_oid_str = join( ',', @$taxonOids_ref );
    my @a;
    return @a if $taxon_oid_str eq "";

    my $sql = qq{
       select tx.taxon_oid
       from taxon tx
       where tx.taxon_oid in( $taxon_oid_str )
       order by taxon_display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        push( @a, $taxon_oid );
    }
    $cur->finish();

    # scaffold cart
    if ($scaffold_cart) {
        require ScaffoldCart;

        foreach my $id ( sort @$taxonOids_ref ) {
            next if $id > -1;
            push( @a, $id );
        }
    }

    return @a;
}

############################################################################
# excelHeaderName - Massage for Excel column header in tab delimtied files.
############################################################################
sub excelHeaderName {
    my ($s) = @_;
    $s =~ s/[^a-z^A-Z^0-9]+/_/g;
    return $s;
}

############################################################################
# loadFuncMap - Load function map from gene_oid => "id\tname\n..."
#   entries.
#   Column separator: tabs
#   Row separator: newline
############################################################################
sub loadFuncMap {
    my ( $dbh, $sql, $map_ref ) = @_;

    my $cur = execSql( $dbh, $sql, $verbose );
    my %done;
    for ( ; ; ) {
        my ( $gene_oid, $id, $name ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $done{"$gene_oid-$id"};
        $map_ref->{$gene_oid} .= "$id\t$name\n";
        $done{"$gene_oid-$id"} = 1;
    }
    $cur->finish();
}

############################################################################
# geneticCode - Return amino acid from codon.
############################################################################
my %genetic_code = (
    'TTT' => 'F',
    'TTC' => 'F',
    'TTA' => 'L',
    'TTG' => 'L',
    'TCT' => 'S',
    'TCC' => 'S',
    'TCA' => 'S',
    'TCG' => 'S',
    'TCN' => 'S',
    'TAT' => 'Y',
    'TAC' => 'Y',
    'TAA' => '*',
    'TAG' => '*',
    'TGT' => 'C',
    'TGC' => 'C',
    'TGA' => '*',
    'TGG' => 'W',
    'CTT' => 'L',
    'CTC' => 'L',
    'CTA' => 'L',
    'CTG' => 'L',
    'CTN' => 'L',
    'CCT' => 'P',
    'CCC' => 'P',
    'CCA' => 'P',
    'CCG' => 'P',
    'CCN' => 'P',
    'CAT' => 'H',
    'CAC' => 'H',
    'CAA' => 'Q',
    'CAG' => 'Q',
    'CGT' => 'R',
    'CGC' => 'R',
    'CGA' => 'R',
    'CGG' => 'R',
    'CGN' => 'R',
    'ATT' => 'I',
    'ATC' => 'I',
    'ATA' => 'I',
    'ATG' => 'M',
    'ACT' => 'T',
    'ACC' => 'T',
    'ACA' => 'T',
    'ACG' => 'T',
    'ACN' => 'T',
    'AAT' => 'N',
    'AAC' => 'N',
    'AAA' => 'K',
    'AAG' => 'K',
    'AGT' => 'S',
    'AGC' => 'S',
    'AGA' => 'R',
    'AGG' => 'R',
    'GTT' => 'V',
    'GTC' => 'V',
    'GTA' => 'V',
    'GTG' => 'V',
    'GTN' => 'V',
    'GCT' => 'A',
    'GCC' => 'A',
    'GCA' => 'A',
    'GCG' => 'A',
    'GCN' => 'A',
    'GAT' => 'D',
    'GAC' => 'D',
    'GAA' => 'E',
    'GAG' => 'E',
    'GGT' => 'G',
    'GGC' => 'G',
    'GGA' => 'G',
    'GGG' => 'G',
    'GGN' => 'G',
);

sub geneticCode {
    my ($codon) = @_;
    return $genetic_code{$codon};
}

############################################################################
# getaa - Get amino acids from sequence.
############################################################################
sub getaa {
    my ($seq) = @_;
    my $i;
    my $len = length($seq);
    my $aaSeq;
    for ( $i = 0 ; $i < $len ; $i += 3 ) {
        my $s2 = substr( $seq, $i, 3 );
        my $aa = geneticCode($s2);

        # Selenocysteine
        if ( $aa eq "*" && $s2 eq "TGA" && $i < $len - 3 ) {
            $aa = "U";
        }
        $aaSeq .= $aa;
    }
    return $aaSeq;
}

############################################################################
# getOracleSortableDate - Get string for oracle sortable date
#   for default oracle date format.
############################################################################
sub getOracleSortableDate {
    my ($s) = @_;

    my ( $dy, $mn, $yr ) = split( /-/, $s );
    my %mn2Num = (
        JAN => 1,
        FEB => 2,
        MAR => 3,
        APR => 4,
        MAY => 5,
        JUN => 6,
        JUL => 7,
        AUG => 8,
        SEP => 9,
        OCT => 10,
        NOV => 11,
        DEC => 12,
    );
    my $mnNum = sprintf( "%02d", $mn2Num{$mn} );
    my $s2 = "$yr-$mnNum-$dy";
    return $s2;
}

#
# html bookmark section header
# param $bmark_name - bookmark name
# param $name - display name
#
sub getHtmlBookmark {
    my ( $bmark_name, $name ) = @_;
    if ($content_list) {

        # always back to top
        # ensure the header is at the top of the page on bookmark links
        #print "<p></p>\n";
        my $s = "<p></p><a name='$bmark_name' href='#'>" . $name . " </a>";
        return $s;
    }
    return $name;
}

#
# I use this to solve the problem of 1000 in stmt limit
# Returns a query that has an 'in' statment greater than 1000
# Its using "union all"
# - FOR numbers not strings
# param $origsql - simple sql query with the 'in ()' clasue which has a
#       text pattern to replace
#       e.g. select ... from ... where ... t.a in ( _xxx_ ) ...
# param $pattern - pattern to look for to replace e.g. "_xxx_"
# param $aref - array ref of ids numbers, NOT strings
#
# - ken
sub bigInQuery {
    my ( $origsql, $pattern, $aref ) = @_;

    if ( $#$aref < $ORACLEMAX ) {
        my $tmpstr = join( ",", @$aref );
        $origsql =~ s/$pattern/$tmpstr/;
        return $origsql;
    }

    my $i   = 0;
    my @tmp = ();
    my $sql = "";
    foreach my $id (@$aref) {
        push( @tmp, $id );

        if ( $i >= ( $ORACLEMAX - 1 ) ) {
            if ( $sql ne "" ) {
                $sql = $sql . " union all ";
            }
            my $tmpstr = join( ",", @tmp );
            $sql = $sql . $origsql;
            $sql =~ s/$pattern/$tmpstr/;
            @tmp = ();
            $i   = 0;
        }
        $i++;
    }

    if ( $#tmp > -1 ) {
        my $tmpstr = join( ",", @tmp );
        $sql = "$sql union all " . $origsql;
        $sql =~ s/$pattern/$tmpstr/;
    }
    return $sql;
}

# Gets oracle in statement size limit
sub getORACLEMAX {
    return $ORACLEMAX;
}

############################################################################
# printStartWorkingDiv - print start of working div
#      (for progress indication)
############################################################################
sub printStartWorkingDiv {
    my ($name) = @_;
    $name = "working" if ( $name eq "" );
    print qq{
        <div id='$name'>
        <p> Processing messages:</p>
        <div class="working_area" style="resize: both;">
        <p>
        };
}

############################################################################
# printEndWorkingDiv - print end of the working div
#
# $noClear - 1 do not clear the working div to be used on errors
############################################################################
sub printEndWorkingDiv {
    my ( $name, $noClear ) = @_;
    print qq{
       </p>
       </div>
       </div>
    };
    clearWorkingDiv($name) if ( !$noClear );
}

############################################################################
# clearWorkingDiv - Clear working div
############################################################################
sub clearWorkingDiv {
    my ($name) = @_;
    $name = "working" if ( $name eq "" );
    print qq{
    <script>
        var e0 = document.getElementById( "$name" );
        e0.innerHTML = "";
        e0.style.display = 'none';
    </script>
    };
}

############################################################################
# termOid2Term - Lookup term from oid.
############################################################################
sub termOid2Term {
    my ( $dbh, $term_oid ) = @_;
    my $sql = qq{
        select term
	from img_term
	where term_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    my ($term) = $cur->fetchrow();
    $cur->finish();
    return $term;
}

############################################################################
# catOid2Name - Convert catagory OID to name.
############################################################################
sub catOid2Name {
    my ( $dbh, $cat_oid ) = @_;
    my $sql = qq{
        select category_name
	from dt_myfunc_cat
	where cat_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cat_oid );
    my ($category_name) = $cur->fetchrow();
    $cur->finish();
    return $category_name;
}

############################################################################
# convert latitude/longitude info into useful format for mapping
############################################################################
sub convertLatLong {
    my ($coord) = @_;
    return if ( $coord eq "" );

    # it is important to strip whitespaces at the beginning
    # and end of the string, since sometimes longitude strings
    # like  " -72.886667" is passed.
    $coord =~ s/^\s+|\s+$//g;

    # Regex for format: decimal number
    if ( $coord =~ /^-?\d+\.?\d*$/ ) {
        $coord = sprintf( "%.5f", $coord );
        return $coord;
    }

    # Regex for format: N10.11.260
    elsif ( $coord =~ /^([NWSE])(\d+)\.(\d+)\.(\d+)$/ ) {
        my $sec    = $4 / 60;
        my $min    = $3 + $sec;
        my $mindeg = $min / 60;
        my $deg    = $2 + $mindeg;
        if ( $1 eq "S" || $1 eq "W" ) {
            $deg = "-" . $deg;
        }
        return $deg;
    }

    # Regex for format: N44.560318 and/or W -110.8338344
    elsif ( $coord =~ /^([NWSE]) ?(-?\d+.?\d+)$/ ) {
        my $coord2 = $2;
        $coord2 = sprintf( "%.5f", $coord2 );
        return $coord2;
    }

    # Regex for format: 47 degrees 38.075 minutes N
    elsif ( $coord =~ /^(\d+) (degrees|degress|degress,) (\d+).(\d+) minutes ([NWSE])/ ) {
        my $mins    = $3 . "." . $4;
        my $degmins = $mins / 60;
        $degmins = sprintf( "%.5f", $degmins );
        if ( length($degmins) > 8 ) {
            $degmins = substr( $degmins, 0, 7 );
        }
        my $deg = $1 + $degmins;
        if ( $5 eq "S" || $5 eq "W" ) {
            $deg = "-" . $deg;
        }
        return $deg;
    }

    # else
    return "";
}

############################################################################
# get the proper google maps key based on server name
############################################################################
sub getGoogleMapsKey {
    my $servername = $ENV{SERVER_NAME};
    my $gkeys      = $env->{google_map_keys};
    foreach my $key ( keys %$gkeys ) {
        if ( $servername =~ m/$key$/i ) {
            return $gkeys->{$key};
        }

    }
    return "";
}

############################################################################
# get the proper google analytics key based on server name
############################################################################
sub getGoogleAnalyticsKey {
    my $servername = $ENV{SERVER_NAME};

    #webLog("===== $servername\n");

    my $gkeys = $env->{google_analytics_keys};
    foreach my $key ( keys %$gkeys ) {
        if ( $servername =~ m/$key$/i ) {
            return ( $key, $gkeys->{$key} );
        }

    }
    return "";
}

sub getGoogleReCaptchaPrivateKey {
    my $servername = $ENV{SERVER_NAME};

    my $gkeys = $env->{google_recaptcha_private_key};
    foreach my $key ( keys %$gkeys ) {
        if ( $servername =~ m/$key$/i ) {
            return ( $key, $gkeys->{$key} );
        }

    }
    return "";
}

sub getGoogleReCaptchaPublicKey {
    my $servername = $ENV{SERVER_NAME};

    my $gkeys = $env->{google_recaptcha_public_key};
    foreach my $key ( keys %$gkeys ) {
        if ( $servername =~ m/$key$/i ) {
            return ( $key, $gkeys->{$key} );
        }

    }
    return "";
}

############################################################################
# hasDnaSequence - Check if gene  has DNA sequence.
############################################################################
sub hasDnaSequence {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
      select g.end_coord, scf.ext_accession
      from gene g, scaffold scf
      where g.gene_oid = ?
      and g.scaffold = scf.scaffold_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $end_coord, $scf_ext_accession ) = $cur->fetchrow();
    $cur->finish();
    if ( $end_coord >= 1 && $scf_ext_accession ne "" ) {
        return 1;
    } else {
        return 0;
    }
}

############################################################################
# taxonReadsFasta - Get FASTA information for ID's.
#  @return defintionLine, sequence
############################################################################
sub taxonReadsFasta {
    my ( $taxon_oid, $reads_id ) = @_;

    $taxon_oid = sanitizeInt($taxon_oid);
    $reads_id =~ /([a-zA-Z0-9_\-\.]+)/;
    $reads_id = $1;
    my $db = "$taxon_reads_fna_dir/$taxon_oid.reads.fna";
    if ( !-e $db ) {
        warn("taxonReadsFasta: cannot find '$db'\n");
        return ( "", "" );
    }
    unsetEnvPath();
    my $cmd = "$fastacmd_bin -d $db -s 'lcl|$reads_id'";
    my $cfh = newCmdFileHandle( $cmd, "taxonReadsFasta" );
    my ( $defLine, $seq );
    while ( my $s = $cfh->getline() ) {
        chomp $s;
        if ( $s =~ /^>/ ) {
            $s =~ s/lcl\|//;
            $defLine = $s;
        } else {
            $s =~ s/\s+//g;
            $seq .= $s;
        }
    }
    close $cfh;
    resetEnvPath();
    return ( $defLine, $seq );
}

############################################################################
# remapTaxonOids - Remap taxon_oid's from replacements.
############################################################################
sub remapTaxonOids {
    my ( $dbh, $taxon_oids_aref ) = @_;

    my $size = $#$taxon_oids_aref;
    my $taxonClause;
    if ( $size == 0 ) {

        # there is one taxon to display
        $taxonClause = " and tr.old_taxon_oid = ? ";
    }

    my $sql = qq{
        select tr.old_taxon_oid, tr.taxon_oid
	    from taxon_replacements tr, taxon t
	    where tr.old_taxon_oid = t.taxon_oid
        and t.obsolete_flag = 'Yes'
	    $taxonClause
    };

    my $cur;
    if ( $size == 0 ) {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oids_aref->[0] );
    } else {
        $cur = execSql( $dbh, $sql, $verbose );
    }

    my %old2New;
    for ( ; ; ) {
        my ( $old_taxon_oid, $taxon_oid ) = $cur->fetchrow();
        last if !$taxon_oid;
        $old2New{$old_taxon_oid} = $taxon_oid;
    }
    $cur->finish();

    my @taxon_oids;
    for my $taxon_oid (@$taxon_oids_aref) {
        $taxon_oid = sanitizeInt($taxon_oid);
        my $new_taxon_oid = $old2New{$taxon_oid};
        if ( $new_taxon_oid > 0 ) {
            push( @taxon_oids, $new_taxon_oid );
        } else {
            push( @taxon_oids, $taxon_oid );
        }
    }
    return @taxon_oids;
}

############################################################################
# checkTaxonAvail - Check taxon availability.
############################################################################
sub checkTaxonAvail {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
       select count(*)
       from taxon_stats
       where taxon_oid = ?
       and rownum < 2
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($st1) = $cur->fetchrow();
    $cur->finish();

    if ( $st1 == 0 ) {
        return 0;
    } else {

        # return 1 for next perm check
        return 1;
    }
}

############################################################################
# checkGeneAvail - Check gene availability.
############################################################################
sub checkGeneAvail {
    my ( $dbh, $gene_oid ) = @_;

    my $taxon_oid = geneOid2TaxonOid( $dbh, $gene_oid );
    return checkTaxonAvail( $dbh, $taxon_oid );
}

############################################################################
# geneOidDirs - Get directories for gene_oid.  This is a bit
#   of a hash to keep any directory from getting too large.
############################################################################
sub geneOidDirs {
    my ($gene_oid) = @_;

    my $len   = length($gene_oid);
    my $mid3  = substr( $gene_oid, $len - 6, 3 );
    my $last3 = substr( $gene_oid, $len - 3, 3 );
    return sprintf( "%03d/%03d", $mid3, $last3 );
}

sub geneOidDirs_old {
    my ($gene_oid) = @_;

    my $len = length($gene_oid);
    my $last3 = substr( $gene_oid, $len - 3, 3 );
    return sprintf( "%03d", $last3 );
}

############################################################################
# splitTerm - Split comma separated list of ID's
############################################################################
sub splitTerm {
    my ( $lineTerm, $intFlag, $noErrorFlag ) = @_;

    #print "<h5>splitTerm() lineTerm: $lineTerm</h5>";
    #print "<h5>splitTerm() intFlag: $intFlag</h5>";

    my @termToks = split( /\,/, $lineTerm );

    #print "<h5>splitTerm() termToks: @termToks</h5>\n";
    for (@termToks) {
        s/^\s+//;
        s/\s+$//;
    }
    my %entries;
    for my $tok (@termToks) {

        #print "<h5>splitTerm() tok: $tok</h5>\n";
        next if ( $tok eq "" || ( $intFlag && !isInt($tok) ) );
        $entries{$tok} = 1;
    }
    my @terms;    # package new array without any duplicate element
    for my $tok (@termToks) {
        if ( $entries{$tok} ) {
            push( @terms, $tok );
            $entries{$tok} = 0;
        }
    }

    my $nTerms = @terms;
    if ( $nTerms > 1000 ) {
        webError("Please enter no more than 1000 terms.");
    }
    if ( $nTerms == 0 && $intFlag && !$noErrorFlag ) {
        webError("Invalid integer identifier.");
    }

    return @terms;
}

############################################################################
# addIdPrefix
# type 1: KO id, $idPrefix = "KO:", $idPrefixForInt = "KO:K"
#
############################################################################
sub addIdPrefix {
    my ( $id, $type ) = @_;
    $id =~ tr/a-z/A-Z/;
    my ( $idPrefix, $idPrefixForInt );
    if ( $type == 1 ) {    #KO id
        $idPrefix       = "KO:";
        $idPrefixForInt = "KO:K";
    }

    if ( $id !~ /^$idPrefix/i ) {
        if ( $idPrefixForInt ne '' && isInt($id) ) {
            $id = $idPrefixForInt . $id;
        } else {
            $id = $idPrefix . $id;
        }
    }

    return $id;
}

############################################################################
# hasAlphanumericChar -  have some alphanumeric characters or not
############################################################################
sub hasAlphanumericChar {
    my ($text) = @_;

    if ( $text =~ /[a-zA-Z0-9]+/ ) {
        return 1;
    }
    return 0;
}

############################################################################
# printSearchTermCheck - block empty and none alphanumeric search
############################################################################
sub processSearchTermCheck {
    my ( $searchTerm, $searchTermName ) = @_;

    if ( blankStr($searchTerm) ) {
        if ($searchTermName) {
            webError("No $searchTermName specified. Please go back and enter a search term.");
        } else {
            webError("No search term specified. Please go back and enter a term.");
        }
    }
    if ( !isInt($searchTerm) && length($searchTerm) <= 2 ) {
        if ($searchTermName) {
            webError("$searchTermName must be at least 3 char long.");
        } else {
            webError("Search term must be at least 3 char long.");
        }
    }
    if ( $searchTerm !~ /[a-zA-Z0-9]+/ ) {
        if ($searchTermName) {
            webError("$searchTermName should have some alphanumeric characters.");
        } else {
            webError("Search term should have some alphanumeric characters.");
        }
    }
}

############################################################################
# processSearchTerm - remove space from search term etc
############################################################################
sub processSearchTerm {
    my ( $searchTerm, $notEscapeSingleQuote ) = @_;

    $searchTerm =~ s/\r//g;
    $searchTerm =~ s/^\s+//;
    $searchTerm =~ s/\s+$//;
    my ( $term, @junk ) = split( /\n/, $searchTerm );
    $searchTerm = $term;
    $searchTerm =~ s/^\s+//;
    $searchTerm =~ s/\s+$//;
    $searchTerm =~ s/'/''/g if ( !$notEscapeSingleQuote );

    return ($searchTerm);
}

############################################################################
# processBindList - add into bindList pool
############################################################################
sub processBindList {
    my ( $bindList_ref, $bindList_sql_ref, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    if ( $bindList_sql_ref && defined($bindList_sql_ref) && scalar(@$bindList_sql_ref) > 0 ) {
        push( @$bindList_ref, @$bindList_sql_ref );
    }
    if ( $bindList_txs_ref && defined($bindList_txs_ref) && scalar(@$bindList_txs_ref) > 0 ) {
        push( @$bindList_ref, @$bindList_txs_ref );
    }
    if ( $bindList_ur_ref && defined($bindList_ur_ref) && scalar(@$bindList_ur_ref) > 0 ) {
        push( @$bindList_ref, @$bindList_ur_ref );
    }
}

############################################################################
# processParamValue - needed to process javascript dynamically generated param.
############################################################################
sub processParamValue {
    my ($valStr) = @_;
    my @vals = split( /,/, $valStr );
    return @vals;
}

############################################################################
# printNoHitMessage - print no hit message
############################################################################
sub printNoHitMessage {
    print "<p>\n";
    print "No results returned from search.\n";
    print "</p>\n";
}

############################################################################
# getBBHLiteRows - Get raw rows from BBH lite files.
#   (You need to filter for valid taxons for this database in
#    the hits since data  may come from multiple IMG systems.)
#  Data is assumed to be sorted by descending bit score,
#  top hits order.
############################################################################
sub getBBHLiteRows {
    my ( $gene_oid, $validTaxons_href ) = @_;
    $gene_oid = sanitizeInt($gene_oid);

    # Use new format if turned on. --es 02/26/11
    if ( $bbh_zfiles_dir ne "" ) {
        my $dbh = dbLogin();
        my @a   = getBBHZipRows( $dbh, $gene_oid, $validTaxons_href );

        #$dbh->disconnect();
        return @a;
    }

    my $bbh_file = "$bbh_files_dir/" . geneOidDirs($gene_oid) . "/$gene_oid.m8.txt.gz";
    my @a;
    if ( !-e $bbh_file ) {
        webLog("Cannot find '$bbh_file'\n");
        warn("Cannot find '$bbh_file'\n");
        return @a;
    }
    unsetEnvPath();
    my $cmd = "/bin/zcat $bbh_file";
    webLog("+ $cmd\n");
    my $rfh = newCmdFileHandle( $cmd, "getBBHLiteRows" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $s );
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
        if ( defined($validTaxons_href) ) {
            next if !$validTaxons_href->{$staxon};
        }
        next if $bitScore eq "";    # bad record
        push( @a, $s );
    }
    close $rfh;
    resetEnvPath();
    return @a;
}
############################################################################
# getBBHZipRows - Get raw rows from BBH zip files.
#   (You need to filter for valid taxons for this database in
#    the hits since data  may come from multiple IMG systems.)
#  Data is assumed to be sorted by descending bit score,
#  top hits order.
############################################################################
sub getBBHZipRows {
    my ( $dbh, $gene_oid, $validTaxons_href ) = @_;
    $gene_oid = sanitizeInt($gene_oid);
    my $taxon_oid = geneOid2TaxonOid( $dbh, $gene_oid );
    $taxon_oid = sanitizeInt($taxon_oid);

    my $zipFile = "$bbh_zfiles_dir/$taxon_oid.zip";
    my @a;
    if ( !-e $zipFile ) {
        webLog("getBBHZipRows: file '$zipFile' not found\n");
        warn("getBBHZipRows: file '$zipFile' not found\n");
        return @a;
    }
    unsetEnvPath();
    my $rfh = newUnzipFileHandle( $zipFile, $gene_oid, "getBBHZipFiles" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $s );
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
        if ( defined($validTaxons_href) ) {
            next if !$validTaxons_href->{$staxon};
        }
        next if $bitScore eq "";    # bad record
        push( @a, $s );
    }
    close $rfh;
    resetEnvPath();
    return @a;
}

############################################################################
# getGeneHitsRows - Get raw rows from gene_hits files.
############################################################################
sub getGeneHitsRows {
    my ( $gene_oid, $opType, $validTaxons_href ) = @_;
    $gene_oid = sanitizeInt($gene_oid);

    my $bbh_file = "$bbh_files_dir/" . geneOidDirs($gene_oid) . "/$gene_oid.m8.txt.gz";
    my %orthologs;
    if ( !-e $bbh_file ) {
        webLog("Cannot find '$bbh_file'\n");
        warn("Cannot find '$bbh_file'\n");
    } else {
        my @rows = getBBHLiteRows( $gene_oid, $validTaxons_href );
        for my $row (@rows) {
            my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
              split( /\t/, $row );
            my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
            my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
            $orthologs{$sgene_oid} = 1;
        }
    }
    my $gene_hits_file = "$gene_hits_files_dir/" . geneOidDirs($gene_oid) . "/$gene_oid.m8.txt.gz";
    my @a;
    if ( !-e $gene_hits_file ) {
        webLog("Cannot find '$gene_hits_file'\n");
        warn("Cannot find '$gene_hits_file'\n");
        return @a;
    } else {
        unsetEnvPath();
        my $cmd = "/bin/zcat $gene_hits_file";
        webLog("+ $cmd\n");
        my $rfh = newCmdFileHandle( $cmd, "getGeneHitsRows" );
        while ( my $s = $rfh->getline() ) {
            chomp $s;
            my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
              split( /\t/, $s );
            my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
            my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
            next if !validOid( $qgene_oid, "qgene_oid" );
            next if !validOid( $sgene_oid, "sgene_oid" );
            next if !validOid( $qtaxon,    "qtaxon" );
            next if !validOid( $staxon,    "staxon" );
            next if $bitScore eq "";    # bad record

            if ( $qgene_oid ne $gene_oid ) {
                print STDERR "getGeneHitRows: qgene_oid='$qgene_oid' " . "gene_oid='$gene_oid' file='$gene_hits_file'\n";
                next;
            }
            if ( defined($validTaxons_href) ) {
                next if !$validTaxons_href->{$staxon};
            }
            my $op;
            next if $opType eq "P" && $qtaxon ne $staxon;
            $op = "O" if $orthologs{$sgene_oid} || $opType eq "O";
            $op = "P" if $qtaxon eq $staxon;
            push( @a, "$s\t$op" );
        }
        close $rfh;
        resetEnvPath();
    }

    return @a;
}
############################################################################
# getGeneHitsZipRows - Get raw rows from gene hits zip files.
############################################################################
sub getGeneHitsZipRows {
    my ( $dbh, $gene_oid, $opType, $validTaxons_href ) = @_;
    $gene_oid = sanitizeInt($gene_oid);
    my $taxon_oid = geneOid2TaxonOid( $dbh, $gene_oid );

    my %orthologs;
    my @rows = getBBHZipRows( $dbh, $gene_oid, $validTaxons_href );
    for my $row (@rows) {
        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $row );

        #my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
        $orthologs{$sgene_oid} = 1;
    }
    my @a;
    my $zipFile = "$gene_hits_zfiles_dir/$taxon_oid.zip";
    if ( !-e $zipFile ) {
        webLog("Cannot find '$zipFile'\n");
        warn("Cannot find '$zipFile'\n");
        return @a;
    } else {
        unsetEnvPath();
        my $rfh = newUnzipFileHandle( $zipFile, $gene_oid, "getGeneHitsZipRows" );
        while ( my $s = $rfh->getline() ) {
            chomp $s;
            my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
              split( /\t/, $s );
            my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
            my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
            next if !validOid( $qgene_oid, "qgene_oid" );
            next if !validOid( $sgene_oid, "sgene_oid" );
            next if !validOid( $qtaxon,    "qtaxon" );
            next if !validOid( $staxon,    "staxon" );
            next if $bitScore eq "";    # bad record

            if ( $qgene_oid ne $gene_oid ) {
                print STDERR "getGeneHitZipRows: qgene_oid='$qgene_oid' "
                  . "gene_oid='$gene_oid' file='$zipFile':'$gene_oid'\n";
                next;
            }
            if ( defined($validTaxons_href) ) {
                next if !$validTaxons_href->{$staxon};
            }
            my $op;
            next if $opType eq "P" && $qtaxon ne $staxon;
            $op = "O" if $orthologs{$sgene_oid} || $opType eq "O";
            $op = "P" if $qtaxon eq $staxon;
            push( @a, "$s\t$op" );
        }
        close $rfh;
        resetEnvPath();
    }

    return @a;
}

############################################################################
# validOid - Check for valid OID in case of corrput file.
############################################################################
sub validOid {
    my ( $oid, $type ) = @_;

    if ( length($oid) != 9 && length($oid) != 10 ) {
        warn "INVALID OID $type '$oid'\n" if $type ne "";
        return 0;
    }
    return 1;
}

############################################################################
# getClusterHomologRows
############################################################################
sub getClusterHomologRows {
    my ( $gene_oid, $opType, $validTaxons_href ) = @_;

    $gene_oid = sanitizeInt($gene_oid);

    my $dbh = dbLogin();

    my %orthologs;
    my $bbh_file = "$bbh_files_dir/" . geneOidDirs($gene_oid) . "/$gene_oid.m8.txt.gz";
    if ( !-e $bbh_file ) {
        webLog("Cannot find '$bbh_file'\n");
        warn("Cannot find '$bbh_file'\n");
    } else {
        my @rows = getBBHLiteRows( $gene_oid, $validTaxons_href );
        for my $row (@rows) {
            my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
              split( /\t/, $row );
            my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
            my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
            $orthologs{$sgene_oid} = 1;
        }
    }

    my $top_n;
    my $maxHomologResults = getSessionParam("maxHomologResults");
    if ( $top_n eq "" && $maxHomologResults ne "" ) {
        $top_n = $maxHomologResults;
    }
    webLog("top_n=$top_n\n");

    my $serGiBlastDb = $img_hmms_serGiDb;
    my $singletonsDb = $img_hmms_singletonsDb;

    my $tool    = lastPathTok($0);
    my $verbose = 1;

    unsetEnvPath();

    my $tmpDir = "$cgi_tmp_dir/clusterHomologs$$.tmpDir";
    runCmd("/bin/rm -fr $tmpDir");
    runCmd("/bin/mkdir -p $tmpDir");
    runCmd("/bin/cp $cgi_dir/BLOSUM62 $tmpDir");
    my $queryTmpFile = "$tmpDir/query.$gene_oid.faa";
    my $subjTmpFile  = "$tmpDir/subject.$gene_oid.faa";
    my $tmpOutFile1  = "$tmpDir/query.$gene_oid.m8.txt";
    my $tmpOutFile2  = "$tmpDir/singletons.m8.txt.";

    webLog( ">>> Query gene " . currDateTime() . "\n" );
    my $sql = qq{
       select g.gene_oid, g.taxon, g.aa_seq_length, g.aa_residue
       from gene g
       where g.gene_oid = ?
    };
    writeFaaFile( $dbh, $sql, $gene_oid, $queryTmpFile );

    webLog( ">>> Subject genes " . currDateTime() . "\n" );
    $sql = qq{
       select distinct sm.serial_gi
       from gene g, gene_img_clusters gic1, gene_img_clusters gic2,
         dt_sergi_map sm
       where g.gene_oid = ?
       and g.gene_oid = gic1.gene_oid
       and gic1.cluster_id = gic2.cluster_id
       and gic2.gene_oid = sm.gene_oid
       order by sm.serial_gi
    };

    #    my $cur        = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $giListFile = "$tmpDir/gilist.txt";
    my $Fgi        = newWriteFileHandle( $giListFile, $tool );
    my $count      = 0;

    #    for ( ; ; ) {
    #        my ($serial_gi) = $cur->fetchrow();
    #        last if !$serial_gi;
    #        $count++;
    #        print $Fgi "$serial_gi\n";
    #    }
    close $Fgi;
    webLog( "$count GI's written " . currDateTime() . "\n" );

    my $z_arg = "-z 700000000 ";
    webLog( ">>> Cluster BLAST " . currDateTime() . "\n" );

    my $cmd =
        "$blastall_bin/legacy_blast.pl blastall "
      . " -p blastp -i $queryTmpFile -d $serGiBlastDb "
      . " -l $giListFile "
      . " -e 1e-2 -F F  $z_arg -m 8 -o $tmpOutFile1 -a 16 -b 2500 "
      . " --path $blastall_bin ";

    # --path is needed although fullpath of legacy_blast.pl is
    # specified in the beginning of command! ---yjlin 03/12/2013
    runCmd($cmd);
    webLog( ">>> Singleton BLAST " . currDateTime() . "\n" );

    $cmd =
        "$blastall_bin/legacy_blast.pl blastall "
      . " -p blastp -i $queryTmpFile -d $singletonsDb "
      . " -e 1e-2 -F F  $z_arg -m 8 -o $tmpOutFile2 -a 16 -b 2500 "
      . " --path $blastall_bin ";

    # --path is needed although fullpath of legacy_blast.pl is
    # specified in the beginning of command! ---yjlin 03/12/2013
    runCmd($cmd);
    webLog( ">>> Sort and write " . currDateTime() . "\n" );

    my @rows;
    my $cnt = loadHitsMapGi( $dbh, $tmpOutFile1, \@rows, $validTaxons_href );
    webLog("== $cnt rows loaded from clusters\n");
    $cnt = loadSingletonHits( $tmpOutFile2, \@rows, $validTaxons_href );
    webLog("== $cnt rows loaded from singletons\n");
    my @rows2 = sort(@rows);
    $count = 0;
    my @rows3;

    for my $r2 (@rows2) {
        $count++;
        my ( $sortVal, $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue,
            $bitScore ) = split( /\t/, $r2 );
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
        next if $gene_oid eq $sgene_oid;
        my $op;
        $op = "O" if $orthologs{$sgene_oid};
        $op = "P" if $qtaxon eq $staxon;
        my $r = "$qid\t";
        $r .= "$sid\t";
        $r .= "$percIdent\t";
        $r .= "$alen\t";
        $r .= "$nMisMatch\t";
        $r .= "$nGaps\t";
        $r .= "$qstart\t";
        $r .= "$qend\t";
        $r .= "$sstart\t";
        $r .= "$send\t";
        $r .= "$evalue\t";
        $r .= "$bitScore\t";
        $r .= "$op\t";
        push( @rows3, $r );
    }
    webLog("== $count rows total\n");
    webLog( "Done. " . currDateTime() . "\n" );

    runCmd("/bin/rm -fr $tmpDir");

    resetEnvPath();

    #$dbh->disconnect();

    return @rows3;
}

############################################################################
# writeFaaFile - Write FASTA from SQL.
############################################################################
sub writeFaaFile {
    my ( $dbh, $sql, $gene_oid0, $outFile ) = @_;

    my $wfh = newWriteFileHandle( $outFile, "writeFaaFile" );
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid0 );
    my %done;
    my $count = 0;
    for ( ; ; ) {
        my ( $gene_oid, $taxon, $aa_seq_length, $aa_residue ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $done{$gene_oid};
        $count++;
        print $wfh ">${gene_oid}_${taxon}_${aa_seq_length}\n";
        my $seq = wrapSeq($aa_residue);
        print $wfh "$seq\n";
        $done{$gene_oid} = 1;
    }
    $cur->finish();
    close $wfh;
    webLog("$count genes written to FASTA\n");
}

############################################################################
# loadSingletonHits
############################################################################
sub loadSingletonHits {
    my ( $inFile, $rows_aref, $validTaxons_href ) = @_;

    my $rfh = newReadFileHandle( $inFile, "loadHits" );
    my $count = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $count++;
        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $s );
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
        next if !$validTaxons_href->{$staxon};
        my $revBitScore = sprintf( "%05d", 10000 - $bitScore );
        push( @$rows_aref, "$revBitScore\t$s" );
    }
    close $rfh;
    return $count;
}

############################################################################
# loadHitsMapGi
############################################################################
sub loadHitsMapGi {
    my ( $dbh, $inFile, $rows_aref, $validTaxons_href ) = @_;

    return 0;

    #    my $sql = qq{
    #       select gene_lid
    #       from dt_sergi_map
    #       where serial_gi = ?
    #   };
    #    my $cur = prepSql( $dbh, $sql, $verbose );
    #    my $rfh = newReadFileHandle( $inFile, "loadHitsMapGi" );
    #    my $count = 0;
    #    while ( my $s = $rfh->getline() ) {
    #        chomp $s;
    #        $count++;
    #        my (
    #             $qid,       $gi,    $percIdent, $alen,
    #             $nMisMatch, $nGaps, $qstart,    $qend,
    #             $sstart,    $send,  $evalue,    $bitScore
    #          )
    #          = split( /\t/, $s );
    #        $gi =~ s/gi\|//;
    #        execStmt( $cur, $gi );
    #        my ($sid) = $cur->fetchrow();
    #        if ( $sid eq "" ) {
    #            print "loadHitsMapGi: gi='$gi' -> gene_lid map not found\n"
    #              if $verbose >= 1;
    #            next;
    #        }
    #        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
    #        next if !$validTaxons_href->{$staxon};
    #        my $revBitScore = sprintf( "%05d", 10000 - $bitScore );
    #        my $r = "$revBitScore\t";
    #        $r .= "$qid\t";
    #        $r .= "$sid\t";
    #        $r .= "$percIdent\t";
    #        $r .= "$alen\t";
    #        $r .= "$nMisMatch\t";
    #        $r .= "$nGaps\t";
    #        $r .= "$qstart\t";
    #        $r .= "$qend\t";
    #        $r .= "$sstart\t";
    #        $r .= "$send\t";
    #        $r .= "$evalue\t";
    #        $r .= "$bitScore\t";
    #        push( @$rows_aref, $r );
    #    }
    #    $cur->finish();
    #    close $rfh;
    #    return $count;
}

############################################################################
# printHeaderWithInfo - writes the header for a tool and puts the specified
#     text as a popup tip in the question mark image next to the header
############################################################################
sub printSubHeaderWithInfo {
    my ( $header, $text, $tooltip, $popup_header, $hide_metagenomes, $help, $howto, $java ) = @_;
    print "<h2>";
    printCustomHeader( $header, $text, $tooltip, $popup_header, $hide_metagenomes, $help, $howto, $java );
    print "</h2>";
}

sub printHeaderWithInfo {
    my ( $header, $text, $tooltip, $popup_header, $hide_metagenomes, $help, $howto, $java ) = @_;
    print "<h1>";
    printCustomHeader( $header, $text, $tooltip, $popup_header, $hide_metagenomes, $help, $howto, $java );
    print "</h1>";
}

sub printCustomHeader {
    my ( $header, $text, $tooltip, $popup_header, $hide_metagenomes, $help, $howto, $java ) = @_;
    print "<script src='$base_url/overlib.js'></script>\n";

    my $infolink = "";
    if ( $text ne "" ) {
        my $info =
            "onclick=\"return overlib('$text', "
          . "RIGHT, STICKY, MOUSEOFF, "
          . "CAPTION, '$popup_header', "
          . "FGCOLOR, '#E0FFC2', "
          . "WIDTH, 400)\" "
          . "onmouseout='return nd()' ";
        $infolink = qq{
        <a $info>
        <img src="$base_url/images/question.png" width="24" height="24"
        border="0" title="$tooltip"
        style="cursor:pointer; cursor:hand;" /></a>
        };
    }

    my $hidelink = "";
    if ($hide_metagenomes) {
        my $info2 =
            "onclick=\"return overlib('Currently, this tool does not support metagenomes. "
          . "Only isolate genomes can be analyzed.', "
          . "RIGHT, STICKY, MOUSEOFF, "
          . "CAPTION, 'metagenomes are not supported', "
          . "FGCOLOR, '#E0FFC2', "
          . "WIDTH, 400)\" "
          . "onmouseout='return nd()' ";

        $hidelink = qq{
            <a $info2>
            <img src="$base_url/images/no-metag.jpg" width="24" height="24"
            border="0" title="metagenomes not supported"
            style="cursor:pointer; cursor:hand;" /></a>
        };
    }

    my $helplink = "";
    if ( $help ne "" ) {
        $helplink = qq{
            <a href="$base_url/doc/$help" target="_help" onClick="_gaq.push(['_trackEvent', 'Document', 'printHeaderWithInfo', '$help']);">
            <img width="30" height="24" border="0"
             src="$base_url/images/help.gif" title="view help document"
             style="cursor:pointer; cursor:hand;" /></a>
        };
    }

    my $howtolink = "";
    if ( $howto ne "" ) {
        $howtolink = qq{
            <a href=$base_url/doc/$howto target=_help onClick="_gaq.push(['_trackEvent', 'Document', 'printHeaderWithInfo', '$howto']);">
            <img width="20" height="24" border="0"
             src="$base_url/images/howto.png" title="view how-to in IMG"
             style="cursor:pointer; cursor:hand;" /></a>
        };
    }

    my $javalink = "";
    if ( $java ne "" ) {
        my $javatext =
"Please verify the current version of java using: <a href=http://www.java.com/en/download/installed.jsp >verify</a>. <br/>Please make sure that older versions of java are uninstalled. This can be done using: <a href=http://www.java.com/en/download/uninstallapplet.jsp >uninstall</a> <br/>With Java 7 Update 51 or later, you need to go to Control Panel -> Java -> Security tab, click on <u>Edit Site List</u> and add the following to the list: <br/><br/> http://img.jgi.doe.gov/ <br/> https://img.jgi.doe.gov/ <br/><br/>On linux, go to your jre/bin directory and launch jcontrol to change the security setting as above.<br/>See <a href=$base_url/doc/systemreqs.html >System Requirements</a> for supported browsers. Some browsers may have issues with java.";

        my $info3 =
            "onclick=\"return overlib('$javatext', "
          . "RIGHT, STICKY, MOUSEOFF, "
          . "CAPTION, 'Java issues in IMG', "
          . "FGCOLOR, '#E0FFC2', "
          . "WIDTH, 450)\" "
          . "onmouseout='return nd()' ";

        $javalink = qq{
        <a $info3>
        <img src="$base_url/images/java-cup.jpg" width="24" height="24"
        border="0" title="view java issues in IMG"
        style="cursor:pointer; cursor:hand;" /></a>
        };
    }

    print qq{
        $header $infolink
        $hidelink $helplink $howtolink $javalink
    };
}

############################################################################
# printInfoTipLink - writes a question mark image or the specified link-to
# item ($linktothis) with a tooltip and an onclick popup that contains
# the information specified in $text
############################################################################
sub printInfoTipLink {
    my ( $text, $tooltip, $popup_header, $linktothis ) = @_;
    print "<script src='$base_url/overlib.js'></script>\n";
    my $info =
        "onclick=\"return overlib('$text', "
      . "RIGHT, STICKY, MOUSEOFF, "
      . "CAPTION, '$popup_header', "
      . "FGCOLOR, '#E0FFC2', "
      . "WIDTH, 400)\" "
      . "onmouseout='return nd()' ";

    if ( $linktothis eq "" ) {
        $linktothis = qq{
            <img src="$base_url/images/question.png"
            border="0" title="$tooltip"
            style="cursor:pointer; cursor:hand;"/>
        };
    } else {
        $linktothis = qq {
            <font color="blue"><u>$linktothis</u></font>
        };
    }

    my $link = qq{
        <a $info title="$tooltip" style="cursor:pointer; cursor:hand;">
        $linktothis
        </a>
    };

    print $link;
}

############################################################################
# parseDNACoords
#
# dna_coords: e.g., 3146..3680,5982..8922 or <1..30,25..>75
#
# return:
# start_coord: start coord
# end_coord: end coord
# partial_gene: 1 if is partial gene; 0 otherwise
# error_msg: error in dna_coords, if any
############################################################################
sub parseDNACoords {
    my ($dna_coords) = @_;

    my $start_coord  = 0;
    my $end_coord    = 0;
    my $partial_gene = 0;
    my $error_msg    = "";

    if ( !$dna_coords ) {
        $error_msg = "No DNA coordinates.";
        return ( $start_coord, $end_coord, $partial_gene, $error_msg );
    }

    my @coords = split( /\,/, $dna_coords );
    for my $coord2 (@coords) {
        my ( $s2, $e2 ) = split( /\.\./, $coord2 );

        # check start coord
        if ( $s2 =~ /^\</ ) {

            # partial gene
            $s2 = substr( $s2, 1 );
            $partial_gene = 1;
        }
        if ( length($s2) == 0 || !isInt($s2) || $s2 < 0 ) {
            $error_msg = "Incorrect start coordinate in $coord2";
            last;
        }
        if ( $start_coord == 0 ) {
            $start_coord = $s2;
        } elsif ( $s2 < $start_coord ) {
            $error_msg = "Coordinate $coord2 out of order";
            last;
        }

        # check end coord
        if ( $e2 =~ /^\>/ ) {

            # partial gene
            $e2 = substr( $e2, 1 );
            $partial_gene = 1;
        }
        if ( length($e2) == 0 || !isInt($e2) || $e2 < 0 ) {
            $error_msg = "Incorrect end coordinate in $coord2";
            last;
        }
        if ( $e2 < $s2 ) {
            $error_msg = "Incorrect DNA coordinate $coord2";
            last;
        }
        if ( $end_coord == 0 ) {
            $end_coord = $e2;
        } elsif ( $e2 < $end_coord ) {
            $error_msg = "Coordinate $coord2 out of order";
            last;
        } else {
            $end_coord = $e2;
        }
    }

    return ( $start_coord, $end_coord, $partial_gene, $error_msg );
}

#
# convert a list of function ids to a url
# the list is plain text separated by space
# return string of html <a> tags
# otherwise id is returned back
#
sub functionIdToUrl {
    my ( $id, $type, $gene_oid ) = @_;

    my $pfam_base_url    = $env->{pfam_base_url};
    my $cog_base_url     = $env->{cog_base_url};
    my $tigrfam_base_url = $env->{tigrfam_base_url};
    my $enzyme_base_url  = $env->{enzyme_base_url};
    my $kegg_module_url  = $env->{kegg_module_url};
    my $ipr_base_url     = $env->{ipr_base_url};
    my $cassette_url     = 'main.cgi?section=GeneCassette&page=cassetteBox&type=cog&cassette_oid=';

    # main.cgi?section=KeggPathwayDetail&page=koterm2&ko_id=KO:K13280&gene_oid=646510566
    my $ko_url = 'main.cgi?section=KeggPathwayDetail&page=koterm2&gene_oid=' . $gene_oid . '&ko_id=';

    # sometimes the id is the list of ids separate by a space
    my @ids = split( /\s/, $id );
    my $urls;
    if ( $id =~ /^COG/i ) {
        foreach my $i (@ids) {
            my $tmp = alink( $cog_base_url . $i, $i );
            $urls .= " $tmp";
        }
    } elsif ( $id =~ /^EC/i ) {
        foreach my $i (@ids) {
            my $o = $i;
            $i =~ tr/A-Z/a-z/;
            my $tmp = alink( $enzyme_base_url . $i, $o );
            $urls .= " $tmp";
        }
    } elsif ( $id =~ /^pfam/i ) {
        foreach my $i (@ids) {
            my $o = $i;
            $i =~ s/pfam/PF/;
            my $tmp = alink( $pfam_base_url . $i, $o );
            $urls .= " $tmp";
        }
    } elsif ( $id =~ /^TIGR/i ) {
        foreach my $i (@ids) {
            my $tmp = alink( $tigrfam_base_url . $i, $i );
            $urls .= " $tmp";
        }
    } elsif ( $id =~ /^IPR/i ) {
        foreach my $i (@ids) {
            my $tmp = alink( $ipr_base_url . $i, $i );
            $urls .= " $tmp";
        }
    } elsif ( $id =~ /^KO/i ) {
        foreach my $i (@ids) {
            my $tmp = alink( $ko_url . $i, $i );
            $urls .= " $tmp";
        }

    } elsif ( $type eq 'cassette' ) {
        $urls = alink( $cassette_url . $id, $id );
    }

    if ( $urls ne '' ) {
        return $urls;
    } else {
        return $id;
    }
}

sub getGenomeHitsDir {
    my $sessionId = getSessionId();
    my $dir       = getSessionDir();
    $dir .= "/genomeHits";
    if ( !( -e "$dir" ) ) {
        mkdir "$dir" or webError("Cannot make $dir!");
    }
    return ( $dir, $sessionId );
}

sub getCartDir {
    my $sessionId = getSessionId();
    my $dir       = getSessionDir();
    $dir .= "/cart";
    if ( !( -e "$dir" ) ) {
        mkdir "$dir" or webError("Cannot make $dir!");
    }
    return ( $dir, $sessionId );
}

#
# create and gets session dir under cgi_tmp_dir
#
# $e->{ cgi_tmp_dir } = "/opt/img/temp/" . $e->{ domain_name } .  "_"  . $urlTag;
#
# $subDir - optional - create a subdir under $cgi_tmp_dir/$sessionId/$subDir
sub getSessionDir {
    my ($subDir) = @_;

    my $sessionId = getSessionId();
    my $dir       = "$cgi_tmp_dir/$sessionId";
    if ( ! -e "$dir" ) {
        mkdir "$dir" or webError("Cannot make $dir!");
    }

    if ( $subDir ) {
        $dir = "$cgi_tmp_dir/$sessionId/$subDir";
        if ( ! -e "$dir" ) {
            mkdir "$dir" or webError("Cannot make $dir!");
        }
    }

    return $dir;
}

#
# wrapper to getSessionDir()
# this has a better method name
#
sub getSessionCgiTmpDir {
    my ($subDir) = @_;
    return getSessionDir($subDir);
}

#
# create and gets session dir under tmp_dir
#     $e->{ base_dir } = $apacheVhostDir . $e->{ domain_name } . "/htdocs/$urlTag";
#     $e->{ tmp_dir } = $e->{ base_dir } . "/tmp";
#
# $subDir - optional - create a subdir under $tmp_dir/$sessionId/$subDir
sub getSessionTmpDir {
    my ($subDir) = @_;

    my $sessionId = getSessionId();
    my $dir       = "$tmp_dir/public/$sessionId";
    if ( !( -e "$dir" ) ) {
        mkdir "$dir" or webError("Cannot make $dir!");
        chmod( 0777, $dir );
    }

    if ( $subDir ne '' ) {
        $dir = "$tmp_dir/public/$sessionId/$subDir";
        if ( !( -e "$dir" ) ) {
            mkdir "$dir" or webError("Cannot make $dir!");
            chmod( 0777, $dir );
        }
    }

    return $dir;
}

#
# gets tmp dir url that goes with method getSessionTmpDir()
# You MUST call getSessionTmpDir() first, because it creates the needed sub-directories.
#
# $subDir - optional - create a subdir under $tmp_dir/$sessionId/$subDir
sub getSessionTmpDirUrl {
    my ($subDir) = @_;

    my $sessionId = getSessionId();
    my $dir       = "$tmp_url/public/$sessionId";
    my $dirTest   = "$tmp_dir/public/$sessionId";
    if ( !( -e $dirTest ) ) {
        webError("Cannot find $dirTest!");
    }

    if ( $subDir ne '' ) {
        $dir = "$tmp_url/public/$sessionId/$subDir";
        if ( !( -e "$dirTest/$subDir" ) ) {
            webError("Cannot find $dirTest!");
        }
    }

    return $dir;
}

sub getGenerateDir {
    my $dir = "$cgi_tmp_dir/generate";
    if ( !( -e "$dir" ) ) {
        mkdir "$dir" or webError("Cannot make $dir!");
    }
    return ($dir);
}

############################################################################
# inArray - is $val in @arr?
############################################################################
sub inArray {
    my ( $val, @arr ) = @_;

    for my $i (@arr) {
        if ( $val eq $i ) {
            return 1;
        }
    }
    return 0;
}

############################################################################
# inArray_ignoreCase - is $val in @arr?
#                      (use case-insensitive comparison)
############################################################################
sub inArray_ignoreCase {
    my ( $val, @arr ) = @_;

    $val = strTrim($val);

    for my $i (@arr) {
        my $val2 = strTrim($i);

        if ( lc($val) eq lc($val2) ) {
            return 1;
        }
    }

    return 0;
}

############################################################################
# inIntArray - is $val in @arr? (use integer comparison)
############################################################################
sub inIntArray {
    my ( $val, @arr ) = @_;

    for my $i (@arr) {
        if ( $val == $i ) {
            return 1;
        }
    }

    return 0;
}

#############################################################################
# isSubset - is array $a_ref a subset of array $b_ref
#############################################################################
sub isSubset {
    my ( $a_ref, $b_ref ) = @_;

    for my $i (@$a_ref) {
        if ( !WebUtil::inArray( $i, @$b_ref ) ) {
            return 0;
        }
    }

    return 1;
}

#############################################################################
# intersectionOfArrays - intersection of array $a_ref and array $b_ref
#############################################################################
sub intersectionOfArrays {
    my ( $a_ref, $b_ref ) = @_;

    my %a_h = map { $_ => 1 } @$a_ref;

    # the intersection of @$a_ref and @$b_ref:
    my @intersection = grep( $a_h{$_}, @$b_ref );

    return @intersection;
}

#
# get server's hostanme eg gpweb04, gpweb05 etc
#
sub getHostname {
    my $host = hostname;
    if ( $host ne '' ) {
        return $host;
    }

    # otherwise try command line way of getting host name
    unsetEnvPath();    # to avoid -T errors in perl 5.10 - ken
    delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };
    my $servername = `/bin/hostname`;
    chomp $servername;
    return $servername;
}

############################################################################
# sdbLogin - Login to oracle or some RDBMS and return handle.
#   If "mode" is write, create a new sdb file.
############################################################################
sub sdbLogin {
    my ( $sdb_name, $mode, $exit ) = @_;

    my $sdbh;
    webLog(">>> sdbLogin: '$sdb_name' (mode='$mode')\n");
    if ( $sdb_name && ( -e $sdb_name ) ) {
        $sdbh = DBI->connect( "dbi:SQLite:dbname=$sdb_name", "", "", { RaiseError => 1 }, );
    } elsif ( $sdb_name && $mode eq "w" ) {
        unlink($sdb_name);
        $sdbh = DBI->connect( "dbi:SQLite:dbname=$sdb_name", "", "", { RaiseError => 1 }, );
    }
    if ( !defined($sdbh) ) {
        webLog("sdbLogin: cannot connect dbi:SQLite:dbname=$sdb_name\n");
        my $error = $DBI::errstr;

        if ($exit) {
            webErrorHeader(
"<br/>  This is embarrassing. Sorry, $sdb_name SQLite database is down. Please try again later. <br/> $error",
                1
            );
        }
    }

    return $sdbh;
}

# does the genome have a prodege data
# https://prodege.jgi-psf.org/api/img/2518645523
# returns json object
# {
#    "url": "/readJob/75"
# }
# OR
# {} on no data
#
# return url https://prodege.jgi-psf.org/readJob/75
# or blank ''
sub hasProdege {
    my ($taxonOid) = @_;
    my $url        = "https://prodege.jgi-psf.org/api/img/" . $taxonOid;
    my $content    = urlGet($url);
    if ( !$content ) {
        return '';
    }
    my $href = decode_json($content);
    if ( exists $href->{url} ) {
        my $subUrl = $href->{url};
        return 'https://prodege.jgi-psf.org' . $subUrl;
    }
    return '';
}

# dir list of all files
sub dirListAll {
    my ($dir) = @_;
    opendir( Dir, $dir ) || webDie("dirList: cannot read '$dir'\n");
    my @paths = sort( readdir(Dir) );
    closedir(Dir);
    my @paths2;
    my $i;
    for $i (@paths) {
        push( @paths2, $i );
    }
    return @paths2;
}

1;

