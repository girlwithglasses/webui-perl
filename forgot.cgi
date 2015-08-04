#!/webfs/projectdirs/microbial/img/bin/imgPerlEnv perl

#
# user forgot password or username - they must supply email
#
# for scecurity if email not found have a delay of 5 seconds before saying "email not found"
#
# use recap keys for email submit
#
# $Id: forgot.cgi 33494 2015-06-02 20:40:42Z klchu $
#
use strict;
use CGI qw( :standard  );
use CGI::Carp qw( carpout set_message fatalsToBrowser );
use DBI;
use Data::Dumper;   
use MIME::Lite;     
use URI::Escape;    
use Digest::MD5 qw( md5_base64 );   
use MIME::Base64 qw( encode_base64 decode_base64 );

my $cgi = new CGI;

print header( -type => "text/html" );

printForm();


exit 0;

sub printHeader {
    print qq{
<!DOCTYPE html>
<head>
<title>IMG</title>
<meta charset="UTF-8">
<meta name="description" content="Integrated Microbial Genomes" />
<meta http-equiv="Cache-Control" content="max-age=3600"/>
<link rel="stylesheet" type="text/css" href="https://img.jgi.doe.gov/css/jgi.css" />
<link rel="stylesheet" type="text/css" href="https://img.jgi.doe.gov/w/div-v33.css" />
<link rel="icon" href="https://img.jgi.doe.gov/favicon.ico"/>
<link rel="SHORTCUT ICON" href="https://img.jgi.doe.gov/favicon.ico" />
</head>
<body>
<header id="jgi-header">
<div id="jgi-logo">
<a title="DOE Joint Genome Institute - IMG" href="http://jgi.doe.gov/">
<img width="480" height="70" alt="DOE Joint Genome Institute's IMG logo" src="https://img.jgi.doe.gov//images/logo-JGI-IMG.png">
</a>
</div>
<nav class="jgi-nav">
    <ul>
    <li><a href="http://jgi.doe.gov">JGI Home</a></li>
    <li><a href="https://sites.google.com/a/lbl.gov/img-form/contact-us">Contact Us</a></li>
    </ul>
</nav>
</header>
    
<div id="content_other">        
    };
}



sub printForm {

    printHeader();
    print qq{
    <h2> IMG Accounts Deprecated</h2>
    <p> IMG accounts are being deprecated. <br>
    As of <b>Jan 1 2016</b> all IMG accounts will be disabled.<br>
    Please sign up for a JGI SSO account <a href='http://contacts.jgi-psf.org/registration/new'>JGI SSO </a>
    </div>
    };

}
