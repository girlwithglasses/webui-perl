############################################################################
# Run external NCBI Blast.
#    --es 09/14/2006
#
# $Id: NcbiBlast.pm 32060 2014-10-09 17:30:28Z klchu $
############################################################################
package NcbiBlast;
my $section = "NcbiBlast";
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
  runNcbiBlast
  processContent
);
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use ScaffoldPanel;
use LWP::UserAgent;
use HTTP::Request::Common qw( POST );
use WebConfig;
use WebUtil;

$| = 1;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $blast_data_dir       = $env->{blast_data_dir};
my $ncbi_blast_url       = $env->{ncbi_blast_url};
my $ncbi_entrez_base_url = $env->{ncbi_entrez_base_url};

$ENV{BLAST_DB} = $blast_data_dir;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( paramMatch("ncbiBlast") ) {
        #runNcbiBlast();
        NcbiBlast();
    } else {
        #runNcbiBlast();
        NcbiBlast();
    }
}

# ncbi is now using a ajax page for blast we cannot embedded their blast into our pages.
# so print the sequence for the user to copy and paste and a link to ncbi
# - ken
sub NcbiBlast {
    my $gene_oid     = param("genePageGeneOid");
    my $genome_type  = param("genome_type");
    my $scaffold_oid = param("scaffold_oid");
    
    print qq{
        <h1> Gene sequence to NCBI BLAST</h1>
        <p>
        Copy and paste sequence to NCBI Blast site.
        </p>
    };
    
    my $aa_residue;
    my $na_residue;
    my $url1 = $ncbi_blast_url;
    my $url2 = "http://blast.ncbi.nlm.nih.gov/Blast.cgi?PROGRAM=blastn&BLAST_PROGRAMS=megaBlast&PAGE_TYPE=BlastSearch";

    if ( $genome_type eq "metagenome" ) {        
        my $taxon_oid = param("taxon_oid");
        my $data_type = param("data_type");
        require MetaUtil;
        $aa_residue = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
        $aa_residue = wrapSeq($aa_residue);


        my $line = MetaUtil::getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );

        my $strand      = param('strand');
        my $start_coord = param('start_coord');
        my $end_coord   = param('end_coord');
        my $gene_seq    = "";
        if ( $strand eq '-' ) {
            $gene_seq = WebUtil::getSequence($line, $end_coord, $start_coord);
        } else {
            $gene_seq = WebUtil::getSequence($line, $start_coord, $end_coord);
        }

        
        $na_residue = wrapSeq($gene_seq);
    } else {
        my $dbh = dbLogin();
        $aa_residue = WebUtil::geneOid2AASeq( $dbh, $gene_oid );
        $aa_residue = wrapSeq($aa_residue);

        my @goids = ($gene_oid);
        require SequenceExportUtil;
        my $href = SequenceExportUtil::getGeneFnaSeqDb( \@goids );
        $na_residue = $href->{$gene_oid};
        $na_residue = wrapSeq($na_residue);
    }
    #print "NcbiBlast() aa_residue=$aa_residue<br/>\n";

    print qq{
        <p>
        <textarea rows="4" cols="80">
&gt;$gene_oid
$aa_residue
        </textarea>
        <br/>
        <input class="smdefbutton" type="button" 
        name="ncbi blast1" 
        value="NCBI BLASTP" 
        onclick="window.open('$url1', '_blank')">            
        <p>
    } if ( $aa_residue );

    print qq{
        <p>
        <textarea rows="4" cols="80">
&gt;$gene_oid
$na_residue
        </textarea>
        <br/>
        <input class="smdefbutton" type="button" 
        name="ncbi blast2" 
        value="NCBI BLASTN" 
        onclick="window.open('$url2', '_blank')"> 
        </p>
    } if ( $na_residue );


}

############################################################################
# runNcbiBlast - Run from external BLAST databases.
#   Inputs:
#      gene_oid - gene object identifier
############################################################################
sub runNcbiBlast {
    my $gene_oid     = param("genePageGeneOid");
    my $genome_type  = param("genome_type");
    my $scaffold_oid = param("scaffold_oid");

    my $aa_residue;
    if ( $genome_type eq "metagenome" ) {
        my $taxon_oid = param("taxon_oid");
        my $data_type = param("data_type");
        require MetaUtil;
        $aa_residue = MetaUtil::getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );
    } else {
        my $dbh = dbLogin();
        $aa_residue = WebUtil::geneOid2AASeq( $dbh, $gene_oid );

        #$dbh->disconnect( );
    }

    my $seq = wrapSeq($aa_residue);

    my $ua = WebUtil::myLwpUserAgent(); 
    $ua->agent("img/1.0");

    my $url = $ncbi_blast_url;
    if ( $genome_type eq "metagenome" ) {
        $url = "http://blast.ncbi.nlm.nih.gov/Blast.cgi?PROGRAM=blastn&BLAST_PROGRAMS=megaBlast&PAGE_TYPE=BlastSearch";
        $ncbi_blast_url = $url;
    }
    my $req = POST $url, [];
    my $res = $ua->request($req);
    if ( $res->is_success() ) {
        processContent( $res->content, $gene_oid, $seq );
    } else {
        webError( $res->status_line );
        webLog $res->status_line;
    }
    WebUtil::webExit(0);
}

############################################################################
# processContent
############################################################################
sub processContent {
    my ( $content, $gene_oid, $seq ) = @_;
    my @lines = split( /\n/, $content );
    my $fasta = ">$gene_oid\n";
    $fasta .= "$seq\n";
    for my $s (@lines) {

        #if(  $s =~ /textarea/ && $s =~ /QUERY/ ) {
        if ( $s =~ /textarea/ && $s =~ /"seq"/ ) {
            $s =~ s/><\/textarea>/>$fasta<\/textarea>/;
            print "$s\n";
        } elsif ( $s =~ /<head>/ ) {
            print "$s\n";
            print "<base href='$ncbi_blast_url' />\n";
        } else {
            print "$s\n";
        }
    }
}

1;

