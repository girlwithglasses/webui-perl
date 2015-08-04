#!/webfs/projectdirs/microbial/img/bin/imgPerlEnv perl

# check if caliban user
# GET - returns plain text
# jgi - yes jgi caliban user
# img - yes img user
# false - not a user
# otherwise
# - 404 not found error
# - 400 error
# - 403 error for bots
# Ken
#
# $Id: IsCalibanUser.cgi 31207 2014-06-16 19:48:53Z klchu $
#
use strict;
use CGI qw( :standard  );
use CGI::Carp qw( carpout set_message fatalsToBrowser );
use DBI;
use Data::Dumper;
use URI::Escape;
use LWP::UserAgent;
use HTTP::Request::Common qw( GET POST PUT);
use XML::Simple;
use FindBin qw( $RealBin );
use lib "$RealBin";
use MailUtil;
use DataEntryUtil;
use WebConfig;
use WebUtil;

my $env = getEnv();

# sso Caliban
# cookie name: jgi_return, value: url, domain: jgi.doe.gov
my $sso_enabled = $env->{sso_enabled};
my $sso_url     = $env->{sso_url};
my $verbose     = $env->{verbose};

$| = 1;

# only POST
my $REQUEST_METHOD = uc( $ENV{REQUEST_METHOD} );

if ( $REQUEST_METHOD ne 'GET' ) {
    printNotPost("It must be GET not $REQUEST_METHOD");
}

if ( !$sso_enabled ) {
    printNotFound('no page');
}

blockRobots();

#my $env     = getEnv();
my $verbose = -1;
timeout(60);    # timeout in 1 minutes

isUser2();

WebUtil::webExit(0);

#
# checks img first
#
sub isUser2 {
    my $login = param('login');    # cannot be null - username in caliban

    my $jgiSsoErrorMsg;

    if ( blankStr($login) ) {
        printNotPost("login cannot be blank");
    }

    # is IMG user
    #$login = uri_unescape($login);
    #  CGI::unescape
    my $login2 = CGI::unescape($login);
    my $dbh = DataEntryUtil::connectGoldDatabase(1);
    if ( !$dbh ) {
        printFound('Error: gold db issue');
    }
    my $sql = qq{
        select contact_oid
        from contact
        where username = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $login2 );
    my ($id) = $cur->fetchrow();
    $cur->finish();
    if ($id) {
        printFound( 'img', $dbh );
    }

    #$dbh->disconnect();
    # banned user check
    my $sql = qq{
    select username, email
    from cancelled_user
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $username, $email ) = $cur->fetchrow();
        last if !$username;
        if ( $login2 eq $username || lc($login2) eq lc($email) ) {
            $cur->finish();
            $jgiSsoErrorMsg = "Error: Your IMG account has been locked.";
            last;
        }
    }


    # is caliban user
    my $url  = $sso_url . '/api/users?login=' . $login;
    my $ua   = new LWP::UserAgent();
    my $req  = GET($url);
    my $res  = $ua->request($req);
    my $code = $res->code;


    if ( $code eq "200" ) {
        my $content = $res->content;

        if ( $content =~ /Temporarily Unavailable/ ) {

            # do nothing and skip to img accounts
            $jgiSsoErrorMsg = 'Error: JGI SSO Temporarily Unavailable';
        } elsif ( $content !~ /users/ ) {

            # do nothing and skip to img accounts
        } else {

            # content is xml
            # <users> <user> <login>H.Schaefer%40warwick.ac.uk</login> ....
            #
            my $href = XMLin($content);
            if ( exists $href->{'user'} ) {
                printFound('jgi');
            }
        }
    } elsif ( $code eq "403" ) {

        # access to jgi sso failed
        # What to do? - ken
        $jgiSsoErrorMsg = 'Error: JGI SSO Temporarily Unavailable';
    }


    # user not found
    if ($jgiSsoErrorMsg) {
        printFound($jgiSsoErrorMsg);
    }
    printFound('false');
}

#
# checks caliban first
#
sub isUser {
    my $login = param('login');    # cannot be null - username in caliban

    if ( blankStr($login) ) {
        printNotPost("login cannot be blank");
    }

    # is caliban user
    my $url  = $sso_url . '/api/users?login=' . $login;
    my $ua   = new LWP::UserAgent();
    my $req  = GET($url);
    my $res  = $ua->request($req);
    my $code = $res->code;

    my $jgiSsoErrorMsg;

    if ( $code eq "200" ) {
        my $content = $res->content;

        if ( $content =~ /Temporarily Unavailable/ ) {

            # do nothing and skip to img accounts
            $jgiSsoErrorMsg = 'Error: JGI SSO Temporarily Unavailable';
        } elsif ( $content !~ /users/ ) {

            # do nothing and skip to img accounts
        } else {

            # content is xml
            # <users> <user> <login>H.Schaefer%40warwick.ac.uk</login> ....
            #
            my $href = XMLin($content);
            if ( exists $href->{'user'} ) {
                printFound('jgi');
            }
        }
    } elsif ( $code eq "403" ) {

        # access to jgi sso failed
        # What to do? - ken
        $jgiSsoErrorMsg = 'Error: JGI SSO Temporarily Unavailable';
    }

    # is IMG user
    #$login = uri_unescape($login);
    #  CGI::unescape
    $login = CGI::unescape($login);
    my $dbh = DataEntryUtil::connectGoldDatabase(1);
    if ( !$dbh ) {
        printFound('Error: gold db issue');
    }
    my $sql = qq{
        select contact_oid
        from contact
        where username = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $login );
    my ($id) = $cur->fetchrow();
    $cur->finish();
    if ($id) {
        printFound( 'img', $dbh );
    }

    #$dbh->disconnect();
    # banned user check
    my $sql = qq{
    select username, email
    from cancelled_user
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $username, $email ) = $cur->fetchrow();
        last if !$username;
        if ( $login eq $username || lc($login) eq lc($email) ) {
            $cur->finish();
            $jgiSsoErrorMsg = "Error: Your IMG account has been locked.";
            last;
        }
    }

    # user not found
    if ($jgiSsoErrorMsg) {
        printFound($jgiSsoErrorMsg);
    }
    printFound('false');
}

sub printFound {
    my ( $text, $dbh ) = @_;
    print header( -type => "text/plain" );
    print "$text\n";
    if ( $dbh ne "" ) {

        #$dbh->disconnect();
    }
    WebUtil::webExit(0);
}

sub printNotPost {
    my ( $text, $dbh ) = @_;

    if ( $dbh ne "" ) {

        #$dbh->disconnect();
    }

    #  Bad Request
    print header( -type => "text/html", -status => 400 );
    print qq{
       <html>
       <p>
       $text
       </html>
   };
    WebUtil::webExit(0);
}

sub printNotFound {
    my ( $text, $dbh ) = @_;

    if ( $dbh ne "" ) {

        #$dbh->disconnect();
    }

    #  Not Found
    print header( -type => "text/html", -status => 404 );
    print qq{
       <html>
       <p>
       404 Not Found - $text
       </html>
   };
    WebUtil::webExit(0);
}

