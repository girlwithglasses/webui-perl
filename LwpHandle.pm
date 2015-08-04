############################################################################
# LwpHandle.pm - Simplified analog to FileHandle for accessing "web files"
#   given a "path" (URL).
############################################################################
package LwpHandle;
use strict;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common qw( GET POST );
use WebUtil;

############################################################################
# new - Allocate new instance.
############################################################################
sub new {
    my( $myType, $url, $postArgs_ref ) = @_;
    my $self = { };
    bless( $self, $myType );

    my $ua = WebUtil::myLwpUserAgent(); 
    $ua->timeout( 1000 );
    $ua->agent( "img2.x/LwpHandle" );
    my $req;
    if( defined( $postArgs_ref ) ) {
        $req = POST( $url, $postArgs_ref );
    }
    else {
        $req = GET( $url );
    }
    $req->header( 'Accept' => "test/html" );
    my $res = $ua->request( $req );
    if( $res->is_success ) {
       my @lines = split( /\n/, $res->content );
       $self->{ idx } = 0;
       $self->{ lines } = \@lines;
       my $nLines = @lines;
       $self->{ nLines } = $nLines;
    }
    else {
       warn( $res->status_line( ) . "\n" );
    }

    return $self;
}

############################################################################
# close 
############################################################################
sub close {
    my( $self ) = @_;

    %$self = ( );
}


###########################################################################
# getline - Get one line
############################################################################
sub getline {
    my( $self ) = @_;

    my $idx = $self->{ idx };
    my $lines = $self->{ lines };
    my $nLines = $self->{ nLines };
    my $s;
    if( $idx < $nLines ) {
        $s = $lines->[ $idx ] . "\n";
    }
    $self->{ idx }++;
    return $s;
}

1;
