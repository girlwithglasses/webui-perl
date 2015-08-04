############################################################################
# img-act web services package, using xml.cgi xml.pl
# $Id: ACT.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package ACT;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;

$| = 1;
my $section = "ACT";
my $env      = getEnv();
my $main_cgi = $env->{main_cgi};
my $verbose  = $env->{verbose};
my $base_url = $env->{base_url};
my $YUI      = $env->{yui_dir_28};

sub dispatch {
    my $page = param("page");
    if ( $page eq "genedetail" ) {
         
        # xml header
        print header( -type => "text/html" );
        printGeneDetail();
    } else {
         
        # xml header
        print header( -type => "text/html" );
        printForm();
    }
}

sub printForm {
    print qq{
        <form method="post" action="xml.cgi" enctype="multipart/form-data" name="mainForm">
        
    };

    print "gene oids: 637000026 637000027</br>\n";

    print hiddenVar( "gene_oid", "637000026" );
    print hiddenVar( "gene_oid", "637000027" );

    print hiddenVar( "section", "ACT" );
    print hiddenVar( "page",    "genedetail" );

    print submit(
                  -name  => "_section_ACT_genedetail",
                  -value => "Test",
                  -class => "meddefbutton"
    );

    print end_form;
}

sub printGeneDetail {
    my @genes = param("gene_oid");

    my $str = join( ",", @genes );

    my $dbh = dbLogin();
    my $rclause    = WebUtil::urClause("g.taxon");
    my $imgClause  = WebUtil::imgClauseNoTaxon("g.taxon");
    my $sql = qq{
       select g.gene_oid, g.gene_display_name, g.start_coord, g.end_coord
       from gene g
       where g.gene_oid in ($str)
       $rclause
       $imgClause
    };

    print "gene_oid, gene_display_name, start_coord, end_coord</br>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $start_coord, $end_coord ) =
          $cur->fetchrow();
        last if ( !$gene_oid );

        print "$gene_oid, $gene_display_name, $start_coord, $end_coord</br>\n";
    }
    $cur->finish();
    #$dbh->disconnect();
}

1;
