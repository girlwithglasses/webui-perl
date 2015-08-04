############################################################################
#
# see webUI/worker.cgi
#
# $Id: Command.pm 31512 2014-07-28 17:51:15Z klchu $
############################################################################
package Command;

use strict;
use Data::Dumper;
use WebConfig;
use WebUtil;
use Cwd;
use File::Path qw(make_path remove_tree);
use LWP::UserAgent;
use HTTP::Request::Common qw( GET POST);

$| = 1;

my $env            = getEnv();
my $common_tmp_dir = $env->{common_tmp_dir};
my $cassetteDir    = $env->{fastbit_dir};
my $img_ken        = $env->{img_ken};
my $base_url       = $env->{base_url};
my $worker_base_url = $env->{worker_base_url};
#
# create a session directory to store temp files
# this dir is located at common_tmp_dir where gpint05 and gpweb04 to 07 can read and write data too
#
# return session directory
#
sub createSessionDir {

    my $sessionId = getSessionId();

    my $hostname = WebUtil::getHostname();

    #my @tmps   = split( /\//, $base_url );
    my $urlTag = $env->{urlTag}; #$tmps[$#tmps];

    my $dir = $common_tmp_dir . "/$hostname/$urlTag/" . $sessionId;

    # untaint
    if ( $dir =~ /^(.*)$/ ) { $dir = $1; }

    print "making dir $dir <br/>\n" if ($img_ken);
    if ( !( -e "$dir" ) ) {
        umask 0002;
        make_path( $dir, { mode => 0775 } );

        #chmod (0777, $dir);
    }

    print "done making dir $dir <br/>\n" if ($img_ken);
    return $dir;
}

#
# create the command file to run on gpint05
#
# structure of the file
# cd=some directory to 'cd' to optional param
# cmd=the script to run all on one line
# stdout=a file to write out the stdout from the above cmd
#
#cd=/global/homes/k/klchu/Dev/cassettes/v3/genome/
#cmd=/global/homes/k/klchu/Dev/cassettes/v3/genome/findCommonPropsInTaxa db 638341121 2013515003
#stdout=/global/projectb/scratch/img/www-data/service/tmp/gpweb04/<urltag>/e100eb6e22a772898a6060a79a668c0c/output7877.txt
#
# $command - full path to the script to run with all options
# $cdDir - optional  the directory to 'cd' before running the script
#
# return:
# $cmdFile - full path to the command file
# $stdOutFilePath - full path the stdout file
#
sub createCmdFile {
    my ( $command, $cdDir ) = @_;

    my $dir = createSessionDir();

    my $cmdFile        = $dir . '/cmd' . $$ . '.txt';
    my $stdOutFilePath = $dir . '/output' . $$ . '.txt';

    my $wfh = WebUtil::newWriteFileHandle($cmdFile);
    print $wfh "cd=$cdDir\n" if ( $cdDir ne '' );
    print $wfh "cmd=$command\n";
    print $wfh "stdout=$stdOutFilePath";
    close $wfh;

    return ( $cmdFile, $stdOutFilePath );
}

#
# run the script on gpint05
#
# $cmdFile - full path to the command file
# $stdOutFile - full path the stdout file
#
# retrun
# $stdOutFile
# or -1 on failure
#
sub runCmdViaUrl {
    my ( $cmdFile, $stdOutFile ) = @_;

    # call url
    my $tmp = CGI::escape($cmdFile);
    my $url = $worker_base_url . "/cgi-bin/runCmd/cmd.cgi?file=$tmp";
    
    # add users email to the end of the url
    my $email = getSessionParam("email");
    if($email ne '') {
        $email = CGI::escape($email);
        $url = $url . '&email=' . $email;
    }
    
    if ($img_ken) {
        print "<pre>$url </pre><br/>";
    }

    my $ua   = WebUtil::myLwpUserAgent(); #new LWP::UserAgent();
    #$ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
    my $req  = GET($url);
    my $res  = $ua->request($req);
    my $code = $res->code;
    if ( $code eq "200" ) {
        my $content = $res->content;
        if ( $content =~ /Error:/ || $content =~ /Failure:/ ) {
            print qq{
            <br>
            failed<br/>
            $code <br/>
            $content
            };
            return -1;

        } else {

            # do noting for now
            #print "$content<br/>\n";
        }

        return $stdOutFile;
    } else {
        my $content = $res->content;
        print qq{
            <br>
            failed<br/>
            $code <br/>
            $content
        };
        return -1;
    }
}

1;
