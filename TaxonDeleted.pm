# $Id: TaxonDeleted.pm 31234 2014-06-19 03:38:04Z klchu $

package TaxonDeleted;
my $section = "TaxonDeleted";
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use OracleUtil;
use HtmlUtil;
use InnerTable;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $img_ken              = $env->{img_ken};
my $cgi_url              = $env->{cgi_url};
my $include_metagenomes  = $env->{include_metagenomes};
my $user_restricted_site = $env->{user_restricted_site};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $tmp_url              = $env->{tmp_url};
my $tmp_dir              = $env->{tmp_dir};
my $verbose              = $env->{verbose};
my $web_data_dir         = $env->{web_data_dir};
my $img_edu              = $env->{img_edu};


#
#
sub dispatch {
    my ($numTaxon) = @_;
    $numTaxon = 0 if ( $numTaxon eq "" );

    printDeletedTaxon();
}

#
#
sub printDeletedTaxon {
    print qq{
        <h1>Deleted Genomes</h1>
        <p>
        A list of genomes removed from IMG for various reasons.
    };
    printStatusLine( "Loading ...", 1 );
    my $dbh       = dbLogin();
    my $data_aref = getTaxon($dbh);

    my $it = new InnerTable( 1, "taxondelete$$", "taxondelete", 3 );
    $it->addColSpec( "Genome ID",     "number asc", "right" );
    $it->addColSpec( "Submission ID",     "number asc", "right" );
    $it->addColSpec( "Domain",        "char asc",   "left" );
    $it->addColSpec( "Genome Name",   "char asc",   "left" );
    $it->addColSpec( "Modified Date", "char desc",  "left" );
    $it->addColSpec( "Modified By",   "char asc",   "left" );
    $it->addColSpec( "Is Public",     "char asc",   "left" );
    $it->addColSpec("Comments");
    my $sd = $it->getSdDelim();

    my $cnt = 0;
    foreach my $line (@$data_aref) {
        my ( $taxon_oid, $submission_id, $is_public, $domain, $taxon_display_name, $mod_date, $name, $comments ) = split( /\t/, $line );
        my $r .= $taxon_oid . $sd . $taxon_oid . "\t";
        $r    .= $submission_id . $sd . $submission_id . "\t";
        $r    .= $domain . $sd . $domain . "\t";
        $r    .= $taxon_display_name . $sd . $taxon_display_name . "\t";
        $r    .= $mod_date . $sd . $mod_date . "\t";
        $r    .= $name . $sd . $name . "\t";
        $r    .= $is_public . $sd . $is_public . "\t";
        $r    .= $sd . $comments . "\t";
        $it->addRow($r);
        $cnt++;
    }

    $it->printOuterTable(1);
    printStatusLine( "$cnt Loaded.", 2 );
}

# get all delete genomes from itaxon
sub getTaxon {
    my ($dbh) = @_;

    my $urClause = urClause('tx');

    my $imgClause;

    if ( !$include_metagenomes ) {
        $imgClause = " and tx.genome_type = 'isolate' ";
    }

    if ( !$user_restricted_site ) {
        $imgClause .= " and tx.is_public = 'Yes' ";
    }

    my $sql = qq{
select tx.taxon_oid, tx.taxon_display_name,
  to_char(t.mod_date, 'yyyy-mm-dd'),
  c.name,
  t.comments, tx.is_public, tx.domain, tx.submission_id
from taxon tx, taxon\@img_i_taxon t, contact c
where t.obsolete_flag = 'Yes'
and t.modified_by     = c.contact_oid
and tx.taxon_oid = t.taxon_oid
$imgClause
$urClause
    };

    # order by t.mod_date desc
    my @data;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $mod_date, $name, $comments, $is_public, $domain, $submission_id ) = $cur->fetchrow();
        last if !$taxon_oid;
        $comments =~ s/\s+/ /g;
        push( @data, "$taxon_oid\t$submission_id\t$is_public\t$domain\t$taxon_display_name\t$mod_date\t$name\t$comments" );
    }
    return \@data;
}

1;
