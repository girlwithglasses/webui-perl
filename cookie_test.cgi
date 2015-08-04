#!/webfs/projectdirs/microbial/img/bin/imgEnv perl
use strict;
use CGI;

my $q      = new CGI;
my $cookie = $q->cookie( -name => "img_test", -value => '123' );

print $q->header( -type => "text/html", -cookie => [ $cookie ], -expires => "-1d" );

my $cookie = $q->cookie( -name => "img_test" );


if ( defined $cookie ) {
    # cookies enabled
    #print $q->header( -type => "text/plain", -expires => "-1d" );
    print "hello";
    exit 0;
} else { 
    #print $q->header( -type => "text/html", -expires => "-1d" ),
    print $q->start_html( "Cookies Disabled" ),
    $q->h1( "Cookies Disabled" ),
    $q->p( "Your browser is not accepting cookies. Please enabled cookies to view IMG.");
    $q->end_html;
    exit -1;
}


