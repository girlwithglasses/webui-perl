#!/webfs/projectdirs/microbial/img/bin/imgPerlEnv perl

#
# web service for the portal
#
#
#
#
# $Id: portal.cgi 30936 2014-05-20 21:54:02Z klchu $
#
use strict;
use CGI qw( :standard  );
use CGI::Carp qw( carpout set_message fatalsToBrowser );
use DBI;
use Data::Dumper;
use URI::Escape;
use WebConfig;
use WebUtil;

maxCgiProcCheck();

#WebUtil::initialize();
my $env   = getEnv();
my $cgi   = WebUtil::getCgi();
my $https = $cgi->https();       # if on its not null
if ( !$https ) {
    print header( -type => "text/html", -status => '497' );
}
my $session     = getSession();
my $session_id  = $session->id();
my $contact_oid = getContactOid();

# validate login sso
my $dbh_main = dbLogin();
if ( !$contact_oid ) {
    my $ans = Caliban::validateUser($dbh_main);
    if ( !$ans ) {
        printNotLogin();
        WebUtil::webExit(0);
    }
}
my $ans = Caliban::isValidSession();
if ( !$ans ) {
    printNotLogin();
    WebUtil::webExit(0);
}

print header( -type => "text/html", -status => '200' );
print "hello\n";

exit 0;

#
# http://en.wikipedia.org/wiki/List_of_HTTP_status_codes#4xx_Client_Error
#
sub printNotLogin {
    print header( -type => "text/html", -status => '401' );
}
