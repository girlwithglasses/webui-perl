#!/usr/common/usg/languages/perl/5.16.0/bin/perl

# create new userusing caliban info.
# user create new accounts using caliban
# caliban notifies img via this cgi posting data.
#
# $Id: CalibanUser.cgi 30929 2014-05-20 20:01:20Z klchu $
#
use strict;
use CGI qw( :standard  );
use CGI::Carp qw( carpout set_message fatalsToBrowser );
use Data::Dumper;
use DataEntryUtil;
use WebConfig;
use WebUtil;
use MailUtil;
use URI::Escape;
use Caliban;

$| = 1;


# NO longer used - ken
exit 0;

# only POST
my $REQUEST_METHOD = uc( $ENV{REQUEST_METHOD} );

#if ( $REQUEST_METHOD ne 'POST' ) {
#    printNotPost("It must be POST not $REQUEST_METHOD");
#}

#my $env     = getEnv();
my $verbose = -1;
timeout( 60 * 5 );    # timeout in 5 minutes

# limit access to certain ip addresses
# check visitor ip address
my $visitorIP = $ENV{REMOTE_ADDR};
my %allowedIps = (
                   '::1'       => 'localhost',
                   '127.0.0.1' => 'localhost',
                   '198.129.'  => 'jgi',
                   '198.128.'  => 'jgi',
                   '128.3.5.'  => 'lbl',
);
my $match = 0;
foreach my $ip ( keys %allowedIps ) {
    if ( $visitorIP =~ /^$ip/ ) {
        $match = 1;
        last;
    }
}
if ( !$match ) {
    printNotFound("2 $visitorIP");
}

my ( $contact_oid_max, $login, $email, $caliban_id ) = calibanData();
sendEmail( $contact_oid_max, $login, $email, $caliban_id );

# No Content
print header( -type => "text/html", -status => 204 );
WebUtil::webExit(0);

#
# Send email to Amy and Ken that a user was created in contact table.
#
sub sendEmail {
    my ( $contact_oid, $username, $email, $calban_id ) = @_;

    my $content = qq{
New user created by Caliban.
contact_oid: $contact_oid
username: $username
email: $email
caliban id: $calban_id 
    };

}

sub sendEmailFailed {
    my ($text) = @_;

    my $content = qq{
$text        
    };

    #MailUtil::sendMail( 'klchu@lbl.gov', '', 'Failed to created new user via Caliban', $content );
}

#curl -i --request POST \
#--url  http://img-stage.jgi-psf.org/cgi-bin/img_ken/CalibanUser.cgi \
#--form "login=klchu11@lbl.gov" \
#--form "email=klchu11@lbl.gov" \
#--form "id=999999"
#
# curl -i -X POST 'http://localhost/~ken/cgi-bin/web25.htd/CalibanUser.cgi'  --form "email=klchu@lbl.gov" --form "login=klchu" --form "id=9999999" --form "first_name=ken" --form "last_name=chu"
#
#curl -i --request POST \
#--url  http://localhost/~ken/cgi-bin/web25.htd/CalibanUser.cgi \
#--form "login=klchu11@lbl.gov" \
#--form "email=klchu11@lbl.gov" \
#--form "id=999999" \
#--form "prefix=" \
#--form "first_name=ken" \
#--form "middle_name=" \
#--form "last_name=chu" \
#--form "institution=LBNL" \
#--form "department=BDMTC" \
#--form "address_1=1 Abc St" \
#--form "city=Berkeley" \
#--form "state=CA" \
#--form "postal_code=94708" \
#--form "country=USA" \
#--form "phone_number=510 486-4865"
#
# a successful return
#HTTP/1.1 100 Continue
#
#HTTP/1.1 204 No Content
#Date: Thu, 18 Aug 2011 20:55:40 GMT
#Server: Apache/2.2.14 (Ubuntu)
#Content-Length: 0
#Content-Type: text/html; charset=ISO-8859-1
#
# otherwise a 4xx error
#HTTP/1.1 100 Continue
#
#HTTP/1.1 400 Bad Request
#Date: Thu, 18 Aug 2011 20:56:02 GMT
#Server: Apache/2.2.14 (Ubuntu)
#Connection: close
#Transfer-Encoding: chunked
#Content-Type: text/html; charset=ISO-8859-1
#
# Or a 404 error
# OR  500
sub calibanData {
    my $login        = param('login');          # cannot be null - username in caliban
    my $email        = param('email');          # cannot be null
    my $caliban_id   = param('sso_id');         # cannot be null
    my $prefix       = param('prefix');
    my $first_name   = param('first_name');
    my $middle_name  = param('middle_name');
    my $last_name    = param('last_name');
    my $institution  = param('institution');
    my $department   = param('department');
    my $address_1    = param('address_1');
    my $city         = param('city');
    my $state        = param('state');
    my $postal_code  = param('postal_code');
    my $country      = param('country');
    my $phone_number = param('phone_number');

    if ( blankStr($caliban_id) ) {
        printNotPost("caliban_id cannot be blank");
    }

    # TODO now get Caliban data
    my ( $suc, $l, $e, $href ) = Caliban::getUserInfo($caliban_id);
    $login = uri_unescape($l);
    $email = uri_unescape($e);

    if ( blankStr($email) ) {
        printNotPost("email cannot be blank for $caliban_id");
    }

    if ( blankStr($login) ) {
        printNotPost("login/username cannot be blank for $caliban_id");
    }
    
    if(!$suc) {
        printNotPost("Failed to get id: $caliban_id data");
    }

    my $dbh = DataEntryUtil::connectGoldDatabase();
    $dbh->{AutoCommit} = 0;
    $dbh->{RaiseError} = 1;

    # Does caliban id exists
    my $sql = qq{
        select contact_oid
        from contact
        where caliban_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $caliban_id );
    my ($id) = $cur->fetchrow();
    if ($id) {
        printNotPost( "Caliban ID $caliban_id already exists", $dbh );
    }

    # Does caliban user exists
    if ( !blankStr($login) ) {
        my $sql = qq{
        select contact_oid
        from contact
        where caliban_user_name = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $login );
        my ($id) = $cur->fetchrow();
        if ($id) {
            printNotPost( "Caliban username $login already exists caliban id: $caliban_id", $dbh );
        }
    }

    # Does email exists
    if ( !blankStr($email) ) {
        my $sql = qq{
        select contact_oid
        from contact
        where email = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $email );
        my ($id) = $cur->fetchrow();
        if ($id) {
            printNotPost( "Email $email already exists caliban id: $caliban_id", $dbh );
        }
    }
    
# NoContent
# Insert move to img login
# 2012-02-13 - ken
#
$dbh->commit;
#$dbh->disconnect();
print header( -type => "text/html", -status => 204 );
WebUtil::webExit(0);    

    # get max contact_oid
    my $sql = qq{
        select max(contact_oid)
        from contact
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($contact_oid_max) = $cur->fetchrow();
    $contact_oid_max = $contact_oid_max + 1;

    # insert into contact table
    my $sql = qq{
        insert into contact 
        (contact_oid, username, password, name, title, 
        department, email, phone, organization, address, 
        city, state, country, comments, add_date, 
        caliban_id, caliban_user_name)
        values
        (?,?,?,?,?,
         ?,?,?,?,?,
         ?,?,?,?,sysdate,
         ?, ?)
    };
    my $cur = $dbh->prepare($sql) or printNotPost( "cannot preparse statement: $DBI::errstr\n", $dbh );

    my $i    = 1;
    my $name = $first_name;
    $name .= " $middle_name" if ( !blankStr($middle_name) );
    $name .= " $last_name"   if ( !blankStr($last_name) );
    my $comment = 'user created via caliban cgi';

    $cur->bind_param( $i++, $contact_oid_max ) or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $login )           or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, 'no_password!!' )  or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $name )            or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $prefix )          or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $department )      or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $email )           or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $phone_number )    or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $institution )     or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $address_1 )       or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $city )            or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $state )           or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $country )         or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $comment )         or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $caliban_id )      or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );
    $cur->bind_param( $i++, $login )           or printNotPost( "$i-1 cannot bind param: $DBI::errstr\n", $dbh );

    $cur->execute() or printNotPost( "cannot execute: $DBI::errstr\n", $dbh );
    $dbh->commit;
    #$dbh->disconnect();

    return ( $contact_oid_max, $login, $email, $caliban_id );
}

sub printNotPost {
    my ( $text, $dbh ) = @_;

    if ( $dbh ne "" ) {
        $dbh->rollback;
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
    sendEmailFailed($text);
    WebUtil::webExit(0);
}

sub printNotFound {
    my ( $text, $dbh ) = @_;

    if ( $dbh ne "" ) {
        $dbh->rollback;
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

