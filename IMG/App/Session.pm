###########################################################################
#
# $Id: IMG::App::Session.pm 33673 2015-06-30 19:50:33Z klchu $
#
############################################################################
package IMG::App::Session;

use IMG::Util::Base;
use Moo::Role;

use CGI::Session qw/-ip-match/;
use HTTP::Cookies;

requires 'session', 'env', 'cookies';
#has 'session' => (
#	is => 'ro',
#);

#has 'cookies' => (
#	is => 'ro',
#);

#has 'env' => (
#	is => 'ro',
#);

has 'http_ua' => (
	is => 'lazy',
);


sub _build_http_ua {
	my $self = shift;
	return HTTP::Tiny->new;
}

=head3 is_valid_session

Check that a session is valid by pinging the JGI sign-on server

=cut

sub is_valid_session {
	my $self = shift;
    my $sid = $self->session->param("jgi_session_id");

	return 0 unless $sid;

#    webLog("isValidSession \n");
#    return 0 if ( $sid eq "" || $sid eq 0 );

    # https://signon.jgi-psf.org/api/sessions/
    # my $url = $sso_api_url . $sid;
    # new 2015-01-04 - ken
	my $url = $self->env->{sso_api_url} . $sid . '.json';

	my $resp = $self->http_ua->head( $url );

	# 200 - OK
	# 204 - ok but no content
	# 410 or 404 - Gone
	if ($resp->{status} == 200 || $resp->{status} == 204) {
		return 1;
	}

	return 0;
#	{
#		status => $resp->{status},
#		title  => 'JGI session error',
#		message => $resp->{reason},
#	};
}

sub get_jgi_user_json {
	my $self = shift;
	my $u_id = shift || die "No user ID supplied";

	my $response = $self->http_ua->get( $self->cfg->{sso_url} . $u_id . '.json' );

	if (! $response->{success}) {
		warn "No user data found for $u_id";
		return 0;
	}

	return decode_json $response->{content};

}

#
# once login in sso call this to setup cgi session
#
# https://signon.jgi.doe.gov/api/users/3701.json
# http://contacts.jgi-psf.org/api/contacts/3696
#
sub validate_user {
	my $self = shift;
	my $arg_h = shift;

	my $conn = $arg_h->{conn};
	my $cookies = $self->{cookies};

	# check for session cookie and value
	if (! $cookies->{ $self->cfg->{sso_session_cookie_name } } || ! $cookies->{ $self->cfg->{sso_session_cookie_name}}->value) {
		return 0;
	}

#    webLog("here 4 $url\n");
#    my $ua = WebUtil::myLwpUserAgent();

#    my $req  = GET($url);
#    my $res  = $ua->request($req);
#    my $code = $res->code;

    #webLog("here 5 $code\n");

	my $sess_data = $self->get_jgi_user_data( $cookies->{ $self->cfg->{sso_session_cookie_name} }->value );
	# ping the server

	if (! $sess_data->{user}{login} || ! $sess_data->{user}{email_address}) {
		return 0;
	}

	my $sess_id   = $sess_data->{id};
	my $user_href = $sess_data->{user};
	my $user_id   = $sess_data->{user}{id};

	# contact_oid, username, super_user, name, email
	my $user_h = getContactOid( $arg_h->{dbh}, $sess_data->{user}{id} );


#	my ( $contact_oid, $username, $super_user, $name, $email2 ) = getContactOid( $dbh, $sess_data->{user}{id} );

	return 0 unless $user_h->{contact_oid};

=cut
	my ( $ans, $login, $email, $userData_href ) = getUserInfo3( $user_id, $user_href );

    my ( $id, $user_href ) = @_;

    my $contact_id = $user_href->{contact_id};
    my $login      = $user_href->{'login'};
    my $email      = $user_href->{'email_address'};

    if ( $email eq '' || $login eq '' ) {
        return ( 0, '', '', '' );
    }

    my %userData = (
        'username'     => $login,
        'email'        => $email,
        'name'         => $user_href->{'first_name'} . ' ' . $user_href->{'last_name'},
        'phone'        => $user_href->{'phone_number'},
        'organization' => $user_href->{'institution'},
        'address'      => $user_href->{'address_1'},
        'state'        => $user_href->{'state'},
        'country'      => $user_href->{'country'},
        'city'         => $user_href->{'city'},
        'title'        => $user_href->{'prefix'},
        'department'   => $user_href->{'department'},
    );

    webLog(" 1, $login, lc($email),\n");
    return ( 1, $login, lc($email), \%userData );

=cut

        checkBannedUsers( $user_h->{username}, $user_h->{email}, $sess_data->{user}{email_address} );
=cut
        if ( $ans == 1 && $contact_oid eq "" ) {
            $login = CGI::unescape($login);
            $email = CGI::unescape( lc($email) );

            my $emailExists = emailExist( $dbh, $email );
            if ($emailExists) {

                # update user's old img account with caliban data
                updateUser( $login, $email, $user_id );
            } else {

                # user is an old jgi sso user, data not in img's contact table
                #insertUser( $login, $email, $user_id, $userData_href );

                imgAccounttForm( $email, $userData_href );
            }
            ( $contact_oid, $username, $super_user, $name, $email2 ) = getContactOid( $dbh, $user_id );
        }
=cut

	setSessionParam( "contact_oid",       $user_h->{contact_oid} );
	setSessionParam( "super_user",        $user_h->{super_user} );
	setSessionParam( "username",          $user_h->{username} );
	setSessionParam( "jgi_session_id",    $sess_data->{id} );
	setSessionParam( "name",              $sess_data->{first_name} . ' ' . $sess_data->{last_name} );
	setSessionParam( "email",             $user_h->{email} );
	setSessionParam( "caliban_id",        $sess_data->{user}{id} );
	setSessionParam( "caliban_user_name", $sess_data->{user}{login} );
	return 1;
}

#
# get user img contact oid via caliban_id
#
sub getContactOid {

    my ( $dbh, $user_id ) = @_;

	my @cols = qw( contact_oid username super_user name email );

    my $sql = 'select '
    	. join ( ", ", @cols )
		. ' from contact where caliban_id = ? ';

	my $cur = execSql( $dbh, $sql, $verbose, $user_id );

	my %contact;
	my $rslt = $cur->fetchrow_arrayref();

	return { @contact{ @cols } = @$rslt } || undef;

}




#  we need to touch the session to keep active
#
# curl -X PUT -d "" -D headers.txt https://signon.jgi-psf.org/api/sessions/e8b6ef108302e1e4
# ; cat headers.txt
#
#sub touch {
#    my($sid) = @_;
#
#    webLog("running: curl -i -X PUT $sso_url/api/sessions/$sid \n");
#

#}

# newer version
# new user json url
# https://signon.jgi-psf.org/api/sessions/01f3b5f748d90db59a4a4fbe5f1cbdb2.json
# {"ip":"128.3.44.193","id":"01f3b5f748d90db59a4a4fbe5f1cbdb2",
#  "user":{"created_at":"2011-02-15T14:52:51Z","email":"klchu@lbl.gov","id":3701,
#    "last_authenticated_at":"2015-04-28T18:31:26Z","login":"klchu","updated_at":"2015-01-07T18:55:00Z",
#    "contact_id":3696,"prefix":null,"first_name":"Ken","middle_name":null,"last_name":"Chu","suffix":null,
#    "gender":null,"institution":"Joint Genome Institute","institution_type":"DOE Lab","department":null,
#    "address_1":"2800 Mitchell Drive","address_2":"","city":"Walnut Creek","state":"CA","postal_code":"94598",
#    "country":"United States","phone_number":"925-296-5670",
#    "fax_number":null,"email_address":"klchu@lbl.gov",
#    "comments":null,"internal":true}
#    }
sub getUserInfo3 {
    my ( $id, $user_href ) = @_;

    my $contact_id = $user_href->{contact_id};
    my $login      = $user_href->{'login'};
    my $email      = $user_href->{'email_address'};

    if ( $email eq '' || $login eq '' ) {
        return ( 0, '', '', '' );
    }

    my %userData = (
        'username'     => $login,
        'email'        => $email,
        'name'         => $user_href->{'first_name'} . ' ' . $user_href->{'last_name'},
        'phone'        => $user_href->{'phone_number'},
        'organization' => $user_href->{'institution'},
        'address'      => $user_href->{'address_1'},
        'state'        => $user_href->{'state'},
        'country'      => $user_href->{'country'},
        'city'         => $user_href->{'city'},
        'title'        => $user_href->{'prefix'},
        'department'   => $user_href->{'department'},
    );

    webLog(" 1, $login, lc($email),\n");
    return ( 1, $login, lc($email), \%userData );
}

#
# check to see if username or email address has been banned
#
# - noly works for jgi sso logins
# - img accounts are not found in the IsCalibanUser.cgi - get popup of bad login
#
sub checkBannedUsers {
    my ( $cur_username, $curr_email, $curr_email2 ) = @_;

    my $ans = getSessionParam("banned_checked");
    if ( $ans eq 'Yes' ) {
        return;
    }

    my $dbh = DataEntryUtil::connectGoldDatabase();
    my $sql = qq{
    select username, email
    from cancelled_user
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $username, $email ) = $cur->fetchrow();
        last if !$username;

        if (   ( $cur_username eq $username )
            || ( lc($cur_username) eq lc($email) )
            || ( lc($curr_email)   eq lc($email) )
            || ( lc($curr_email2)  eq lc($email) ) )
        {
            my $text = qq{
Your account has been locked. <br>
If you believe this is an error please email us at:<br>
imgsupp at lists.jgi-psf.org (imgsupp\@lists.jgi-psf.org)
            };
            $cur->finish();

            main::printAppHeader("login");
            print $text;
            main::printContentEnd();
            main::printMainFooter();
            Caliban::logout(1);
            WebUtil::webExit(0);
        }
    }

    setSessionParam( "banned_checked", "Yes" );
}






sub initialize {
    $cgi = new CGI;

    # see http://search.cpan.org/~sherzodr/CGI-Session-3.95/Session/Tutorial.pm
    # section INITIALIZING EXISTING SESSIONS
    # idea:
    # before we create a session id lets check the cookies
    # if it exists use existing cookie sid
    # also the cookie name is now system base url specific
    # - Ken
    $cookie_name = "CGISESSID_";
    if ( $self->cfg->{urlTag} ) {
        $cookie_name .= $self->cfg->{urlTag};
    } else {
        my @tmps = split( /\//, $base_url );
        $cookie_name = $cookie_name . $tmps[$#tmps];
    }
    CGI::Session->name($cookie_name);    # override default cookie name CGISESSID
    $CGI::Session::IP_MATCH = 1;

    my $cookie_sid = $cgi->cookie($cookie_name) || undef;
    $g_session = new CGI::Session( undef, $cookie_sid, { Directory => $cgi_tmp_dir } );

    #$g_session              = new CGI::Session( undef, $cgi, { Directory => $cgi_tmp_dir } );

    stackTrace( "WebUtil::initialize()", "TEST: cookie ids ======= cookie_name => $cookie_name sid => $cookie_sid" );
}


my $session = getSession();

# +90m expire after 90 minutes
# +24h - 24 hour cookie
# +1d - one day
# +6M   6 months from now
# +1y   1 year from now
#$session->expire("+1d");
#
# TODO Can this be the problem with NAtalia always getting logged out - ken June 1, 2015 ???
#resetContactOid();

my $session_id  = $session->id();
my $contact_oid = getContactOid();

# see WebUtil.pm line CGI::Session->name($cookie_name); is called - ken
my $cookie_name = WebUtil::getCookieName();
my $cookie      = cookie( $cookie_name => $session_id );
if ( $sso_enabled ) {
    require Caliban;
    if ( !$contact_oid ) {
        my $dbh_main = dbLogin();
        my $ans      = Caliban::validateUser($dbh_main);


        if ( !$ans ) {
			# go to login
            printAppHeader("login");
            Caliban::printSsoForm();
            printContentEnd();
            printMainFooter(1);
            WebUtil::webExit(0);
        }
        WebUtil::loginLog( 'login', 'sso' );
        require MyIMG;
        MyIMG::loadUserPreferences();
    }

    # logout in genome portal i still have contact oid
    # I have to fix and relogin
    my $ans = Caliban::isValidSession();

    if ( !$ans ) {
        Caliban::logout( 0, 1 );
        printAppHeader("login");
        Caliban::printSsoForm();
        printContentEnd();
        printMainFooter(1);
        WebUtil::webExit(0);
    }
} elsif ( ( $public_login || $user_restricted_site ) && !$contact_oid ) {
    require Caliban;
    my $username = param("username");
    $username = param("login") if ( blankStr($username) );    # single login form for sso or img
    my $password = param("password");
    if ( blankStr($username) ) {
        printAppHeader("login");
        Caliban::printSsoForm();
        printContentEnd();
        printMainFooter(1);
        WebUtil::webExit(0);
    } else {
        my $redirecturl = "";
        if ($sso_enabled) {

            # do redirect via cookie
            # return cookie name
            my %cookies = CGI::Cookie->fetch;
            if ( exists $cookies{$sso_cookie_name} ) {
                $redirecturl = $cookies{$sso_cookie_name}->value;
                $redirecturl = "" if ( $redirecturl =~ /main.cgi$/ );

                #$redirecturl = "" if ( $redirecturl =~ /forceimg/ );
            }
        }

        require MyIMG;
        my $b = MyIMG::validateUserPassword( $username, $password );
        if ( !$b ) {
            Caliban::logout();
            printAppHeader( "login", '', '', '', '', '', $redirecturl );
            print qq{
<p>
    <span style="color:red; font-size: 14px;">
    Invalid Username or Password. Try again. <br>
    For JGI SSO accounts please use the login form on the right side
    <span style="color:#336699; font-weight:bold;"> "JGI Single Sign On (JGI SSO)"</span></span>
</p>
            };
            Caliban::printSsoForm();
            printContentEnd();
            printMainFooter(1);
            WebUtil::webExit(0);
        }
        Caliban::checkBannedUsers( $username, $username, $username );
        WebUtil::loginLog( 'login', 'img' );
        MyIMG::loadUserPreferences();
        setSessionParam( "oldLogin", 1 );

        #if($img_ken) {
            Caliban::migrateImg2JgiSso($redirecturl);
        #}

        if ( $sso_enabled && $redirecturl ne "" ) {
            print header( -type => "text/html", -cookie => $cookie );
            print qq{
                    <p>
                    Redirecting to: <a href='$redirecturl'> $redirecturl </a>
                    <script language='JavaScript' type="text/javascript">
                     window.open("$redirecturl", "_self");
                    </script>
            };
            WebUtil::webExit(0);
        }
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
# getContactOid - Get currenct contact_oid for user restricted site.
############################################################################
sub getContactOid {
    if ( !$user_restricted_site && !$public_login ) {
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
# setSessionParam - Set session parameter.
############################################################################
sub setSessionParam {
    my ( $arg, $val ) = @_;
    $g_session->param( $arg, $val );
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
    if ( !( -e "$dir" ) ) {
        mkdir "$dir" or webError("Cannot make $dir!");
    }

    if ( $subDir ne '' ) {
        $dir = "$cgi_tmp_dir/$sessionId/$subDir";
        if ( !( -e "$dir" ) ) {
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


=cut
my $env         = getEnv();
my $base_url    = $env->{base_url};
my $base_dir    = $env->{base_dir};
my $top_base_url             = $env->{top_base_url};
my $main_cgi    = $env->{main_cgi};
my $cgi_url     = $env->{cgi_url};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};
my $section     = "Caliban";
my $section_cgi = "$main_cgi?section=$section";

# sso Caliban
# cookie name: jgi_return, value: url, domain: jgi.doe.gov
my $sso_url                 = $env->{sso_url};
my $sso_domain              = $env->{sso_domain};
my $sso_cookie_name         = $env->{sso_cookie_name};           # jgi_return cookie name
my $sso_session_cookie_name = $env->{sso_session_cookie_name};
my $sso_api_url             = $env->{sso_api_url};               # https://signon.jgi-psf.org/api/sessions/
my $verbose                 = $env->{verbose};
=cut
#
# once login in sso call this to setup cgi session
#
# https://signon.jgi.doe.gov/api/users/3701.json
# http://contacts.jgi-psf.org/api/contacts/3696
#
sub validateUser {

	my $arg_h = shift;

	my $conn = $arg_h->{conn};
	my $cfg = $self->{cfg};
	my $cookies = $self->{cookies};

	# check for session cookie and value
	if (! $cookies->{ $cfg->{sso_session_cookie_name } } || ! $cookies->{ $cfg->{sso_session_cookie_name}}->value) {
		return 0;
	}

#    webLog("here 4 $url\n");
#    my $ua = WebUtil::myLwpUserAgent();

#    my $req  = GET($url);
#    my $res  = $ua->request($req);
#    my $code = $res->code;

    #webLog("here 5 $code\n");

	# ping the server
	my $ua = LWP::UserAgent->new();
	my $response = $ua->get( $cfg->{sso_url} . $cookies->{ $cfg->{sso_session_cookie_name} } . '.json' );

	return 0 unless $response->is_success;

	my $sess_data = decode_json $response->content;

	say "session data: " . Dumper $sess_data;

	if (! $sess_data->{user}{login} || ! $sess_data->{user}{email_address}) {
		return 0;
	}

	my $sess_id   = $user_blob->{id};
	my $user_href = $user_blob->{user};
	my $user_id   = $sess_data->{user}{id};

	# contact_oid, username, super_user, name, email
	my $user_h = getContactOid( $arg_h->{dbh}, $sess_data->{user}{id} );


#	my ( $contact_oid, $username, $super_user, $name, $email2 ) = getContactOid( $dbh, $sess_data->{user}{id} );

	return 0 unless $user_h->{contact_oid};

=cut
	my ( $ans, $login, $email, $userData_href ) = getUserInfo3( $user_id, $user_href );

    my ( $id, $user_href ) = @_;

    my $contact_id = $user_href->{contact_id};
    my $login      = $user_href->{'login'};
    my $email      = $user_href->{'email_address'};

    if ( $email eq '' || $login eq '' ) {
        return ( 0, '', '', '' );
    }

    my %userData = (
        'username'     => $login,
        'email'        => $email,
        'name'         => $user_href->{'first_name'} . ' ' . $user_href->{'last_name'},
        'phone'        => $user_href->{'phone_number'},
        'organization' => $user_href->{'institution'},
        'address'      => $user_href->{'address_1'},
        'state'        => $user_href->{'state'},
        'country'      => $user_href->{'country'},
        'city'         => $user_href->{'city'},
        'title'        => $user_href->{'prefix'},
        'department'   => $user_href->{'department'},
    );

    webLog(" 1, $login, lc($email),\n");
    return ( 1, $login, lc($email), \%userData );

=cut

        checkBannedUsers( $user_h->{username}, $user_h->{email}, $sess_data->{user}{email_address} );
=cut
        if ( $ans == 1 && $contact_oid eq "" ) {
            $login = CGI::unescape($login);
            $email = CGI::unescape( lc($email) );

            my $emailExists = emailExist( $dbh, $email );
            if ($emailExists) {

                # update user's old img account with caliban data
                updateUser( $login, $email, $user_id );
            } else {

                # user is an old jgi sso user, data not in img's contact table
                #insertUser( $login, $email, $user_id, $userData_href );

                imgAccounttForm( $email, $userData_href );
            }
            ( $contact_oid, $username, $super_user, $name, $email2 ) = getContactOid( $dbh, $user_id );
        }
=cut

	setSessionParam( "contact_oid",       $user_h->{contact_oid} );
	setSessionParam( "super_user",        $user_h->{super_user} );
	setSessionParam( "username",          $user_h->{username} );
	setSessionParam( "jgi_session_id",    $sess_data->{id} );
	setSessionParam( "name",              $sess_data->{first_name} . ' ' . $sess_data->{last_name} );
	setSessionParam( "email",             $user_h->{email} );
	setSessionParam( "caliban_id",        $sess_data->{user}{id} );
	setSessionParam( "caliban_user_name", $sess_data->{user}{login} );
	return 1;
}

#
# get user img contact oid via caliban_id
#
sub getContactOid {

    my ( $dbh, $user_id ) = @_;

	my @cols = qw( contact_oid username super_user name email );

    my $sql = 'select '
    	. join ( ", ", @cols )
		. ' from contact where caliban_id = ? ';

	my $cur = execSql( $dbh, $sql, $verbose, $user_id );

	my %contact;
	my $rslt = $cur->fetchrow_arrayref();

	return { @contact{ @cols } = @$rslt } || undef;

}




#  we need to touch the session to keep active
#
# curl -X PUT -d "" -D headers.txt https://signon.jgi-psf.org/api/sessions/e8b6ef108302e1e4
# ; cat headers.txt
#
#sub touch {
#    my($sid) = @_;
#
#    webLog("running: curl -i -X PUT $sso_url/api/sessions/$sid \n");
#

#}

# newer version
# new user json url
# https://signon.jgi-psf.org/api/sessions/01f3b5f748d90db59a4a4fbe5f1cbdb2.json
# {"ip":"128.3.44.193","id":"01f3b5f748d90db59a4a4fbe5f1cbdb2",
#  "user":{"created_at":"2011-02-15T14:52:51Z","email":"klchu@lbl.gov","id":3701,
#    "last_authenticated_at":"2015-04-28T18:31:26Z","login":"klchu","updated_at":"2015-01-07T18:55:00Z",
#    "contact_id":3696,"prefix":null,"first_name":"Ken","middle_name":null,"last_name":"Chu","suffix":null,
#    "gender":null,"institution":"Joint Genome Institute","institution_type":"DOE Lab","department":null,
#    "address_1":"2800 Mitchell Drive","address_2":"","city":"Walnut Creek","state":"CA","postal_code":"94598",
#    "country":"United States","phone_number":"925-296-5670",
#    "fax_number":null,"email_address":"klchu@lbl.gov",
#    "comments":null,"internal":true}
#    }
sub getUserInfo3 {
    my ( $id, $user_href ) = @_;

    my $contact_id = $user_href->{contact_id};
    my $login      = $user_href->{'login'};
    my $email      = $user_href->{'email_address'};

    if ( $email eq '' || $login eq '' ) {
        return ( 0, '', '', '' );
    }

    my %userData = (
        'username'     => $login,
        'email'        => $email,
        'name'         => $user_href->{'first_name'} . ' ' . $user_href->{'last_name'},
        'phone'        => $user_href->{'phone_number'},
        'organization' => $user_href->{'institution'},
        'address'      => $user_href->{'address_1'},
        'state'        => $user_href->{'state'},
        'country'      => $user_href->{'country'},
        'city'         => $user_href->{'city'},
        'title'        => $user_href->{'prefix'},
        'department'   => $user_href->{'department'},
    );

    webLog(" 1, $login, lc($email),\n");
    return ( 1, $login, lc($email), \%userData );
}

#
# check to see if username or email address has been banned
#
# - noly works for jgi sso logins
# - img accounts are not found in the IsCalibanUser.cgi - get popup of bad login
#
sub checkBannedUsers {
    my ( $cur_username, $curr_email, $curr_email2 ) = @_;

    my $ans = getSessionParam("banned_checked");
    if ( $ans eq 'Yes' ) {
        return;
    }

    my $dbh = DataEntryUtil::connectGoldDatabase();
    my $sql = qq{
    select username, email
    from cancelled_user
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $username, $email ) = $cur->fetchrow();
        last if !$username;

        if (   ( $cur_username eq $username )
            || ( lc($cur_username) eq lc($email) )
            || ( lc($curr_email)   eq lc($email) )
            || ( lc($curr_email2)  eq lc($email) ) )
        {
            my $text = qq{
Your account has been locked. <br>
If you believe this is an error please email us at:<br>
imgsupp at lists.jgi-psf.org (imgsupp\@lists.jgi-psf.org)
            };
            $cur->finish();

            main::printAppHeader("login");
            print $text;
            main::printContentEnd();
            main::printMainFooter();
            Caliban::logout(1);
            WebUtil::webExit(0);
        }
    }

    setSessionParam( "banned_checked", "Yes" );
}

# from TreeFile.pm

#
# file format:
# open list  of  ids \n
# or
# selected list od ids \n
#
sub readSession {
    my ($file) = @_;
    $file = WebUtil::checkFileName($file);
    my %hash = ();

    my $path = "$cgi_tmp_dir/$file";
    if ( !-e $path ) {

        #webLog("Tree state file does not exists or session time out\n");
        return \%hash;
    }

    my $res = newReadFileHandle( $path, "runJob" );

    while ( my $line = $res->getline() ) {
        chomp $line;
        next if ( $line eq "" );
        $hash{$line} = "";
    }

    close $res;
    return \%hash;
}

# write session file on what the user has done so far
sub writeSession {
    my ( $file, $ids_aref ) = @_;

    if ( $file eq "" ) {
        my $sid = getSessionId();
        $file = "treestate$$" . "_" . $sid;
    } elsif ( $file ne "" ) {
        $file = WebUtil::checkFileName($file);
        if ( !-e "$cgi_tmp_dir/$file" ) {
            webError("Your session timed out, please restart!");
        }
    }

    $file = WebUtil::checkFileName($file);

    my $prev_data_href = readSession($file);
    my $path           = "$cgi_tmp_dir/$file";
    my $res            = newWriteFileHandle( $path, "runJob" );

    # save new ids
    foreach my $id (@$ids_aref) {
        if ( exists $prev_data_href->{$id} ) {

            # skip
            next;
        } else {
            print $res "$id\n";
        }
    }

    foreach my $id ( keys %$prev_data_href ) {
        print $res "$id\n";
    }

    close $res;
    return $file;
}

# write session files but remove ids
sub writeSessionRemove {
    my ( $file, $ids_aref ) = @_;

    if ( $file eq "" ) {
        my $sid = getSessionId();
        $file = "treestate$$" . "_" . $sid;
    } elsif ( $file ne "" ) {
        $file = WebUtil::checkFileName($file);
        if ( !-e "$cgi_tmp_dir/$file" ) {
            my $url = "$section_cgi";
            $url = alink( $url, "Restart" );
            print qq{
              <p>
              $url
              </p>
            };
            webError("Your session timed out, please restart!");
        }
    }

    $file = WebUtil::checkFileName($file);

    my $prev_data_href = readSession($file);
    my $path           = "$cgi_tmp_dir/$file";
    my $res            = newWriteFileHandle( $path, "runJob" );

    # save new ids
    foreach my $id (@$ids_aref) {
        if ( exists $prev_data_href->{$id} ) {

            #webLog("=== delete ids $id \n");
            delete $prev_data_href->{$id};
        }
    }

    foreach my $id ( keys %$prev_data_href ) {
        print $res "$id\n";
    }

    close $res;
    return $file;
}

# load user prefs from workspace
sub loadUserPreferences {
    if ( $env->{user_restricted_site} ) {
        require Workspace;
        my $href = Workspace::loadUserPreferences();
        foreach my $key ( keys %$href ) {
            my $value = $href->{$key};
            setSessionParam( $key, $value );
        }
    }
}

# save users preferences in workspace
#
# default use is for preferences
# can be used for genome list cfg preferences
# given the filename mygenomelistprefs ??? - TODO
# - ken
#
sub saveUserPreferences {
    my ( $href, $customFilename ) = @_;
    return if ( !$user_restricted_site );

    my $sid      = getContactOid();
    my $filename = "$workspace_dir/$sid/mypreferences";
    if ( $customFilename ne '' ) {
        $filename = "$workspace_dir/$sid/$customFilename";
    }

    if ( !-e "$workspace_dir/$sid" ) {
        mkdir "$workspace_dir/$sid" or webError("Workspace is down!");
    }

    my $wfh = newWriteFileHandle($filename);
    foreach my $key ( sort keys %$href ) {
        my $value = $href->{$key};
        print $wfh "${key}=${value}\n";
    }

    close $wfh;
}

sub loadUserPreferences {
    my ($customFilename) = @_;

    my %hash;
    if ( !$user_restricted_site ) {
        return \%hash;
    }

    my $sid      = getContactOid();
    my $filename = "$workspace_dir/$sid/mypreferences";
    if ( $customFilename ne '' ) {
        $filename = "$workspace_dir/$sid/$customFilename";
    }

    if ( !-e $filename ) {
        return \%hash;
    }

    # read file
    # return hash
    my %hash;
    my $rfh = newReadFileHandle($filename);
    while ( my $line = $rfh->getline() ) {
        chomp $line;
        next if ( $line eq "" );
        my ( $key, $value ) = split( /=/, $line );
        $hash{$key} = $value;
    }
    close $rfh;
    return \%hash;
}


1;
