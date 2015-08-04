############################################################################
# GzWrap - Simplified gunzip wrapper.
#    --es 07/23/2007
############################################################################
package GzWrap;
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw( newReadGzFileHandle );
use strict;
use IO::Uncompress::Gunzip qw( $GunzipError );
use WebUtil;

############################################################################
# newReadGzFileHandle
############################################################################
sub newReadGzFileHandle {
    my( $fileName, $tool ) = @_;

    my $z = new IO::Uncompress::Gunzip( $fileName ) or
       webDie( "$tool: Cannot read '$fileName': $GunzipError\n" );
    return $z;
}

1;
