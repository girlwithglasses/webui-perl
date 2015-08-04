# Configuration for JGI  microbes.
# Edit this file if necessary.
# Links out to JGI Microbial Genome Portals.
#  --es 12/28/2004
package JgiMicrobesConfig;
use WebUtil;
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
    getJgiMicrobeUrl
);


my $base_url = "http://genome.jgi-psf.org";

############################################################################
# getJgiMicrobeUrl - Get URL give database values.
############################################################################
sub getJgiMicrobeUrl {
   my( $domain, $seq_status, $jgi_species_code, $seq_center ) = @_;

   if( $domain eq "" || $jgi_species_code eq "" || $seq_status eq "" ) {
       return "";
   }
   my $sub_url = "draft_microbes";
   $sub_url = "finished_microbes" if $seq_status eq "Finished";
   $sub_url = "" if $domain eq "Eukaryota" && $seq_center eq "JGI";
   if( $seq_status ne "Finished" && $seq_status ne "Draft" ) {
      webLog( "getJgiMicrobeUrl: invalid seq_status='$seq_status'\n" );
   }
   my $url = "$base_url/$sub_url/$jgi_species_code/$jgi_species_code.home.html";
   return $url;
}



1;
