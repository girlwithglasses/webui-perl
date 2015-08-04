############################################################################
# combined sample util / helper package
# $Id: CombinedSample.pm 29900 2014-01-23 20:07:20Z klchu $
############################################################################
package CombinedSample;
use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use OracleUtil;
use WebConfig;
use WebUtil;

$| = 1;

my $env      = getEnv();
my $cgi_dir  = $env->{cgi_dir};
my $tmp_url  = $env->{tmp_url};
my $tmp_dir  = $env->{tmp_dir};
my $main_cgi = $env->{main_cgi};
my $verbose  = $env->{verbose};
my $section  = "CombinedSample";

#
# not all samples will have gold ids
#
# $submissionId - combined sample submission id
#
sub getGoldIds {
    my ( $dbh_gold, $submissionId ) = @_;
    my $sql = qq{
select distinct es.gold_id
from submission_samples ss, env_sample es
where ss.submission_id = ?
and ss.sample_oid = es.sample_oid
and es.gold_id is not null
    };

    my @goldIds;
    my $cur = execSql( $dbh_gold, $sql, $verbose, $submissionId );
    for ( ; ; ) {
        my ($goldSampleId) = $cur->fetchrow();
        last if !$goldSampleId;
        push( @goldIds, $goldSampleId );
    }
    return \@goldIds;
}

sub getAllOtherSubmissionIds {
    my ( $dbh_gold, $submissionId ) = @_;
    my $sql = qq{
select distinct s.SUBMISSION_ID
from submission_samples s
where s.SAMPLE_OID in(
select ss.sample_oid
from submission_samples ss
where ss.submission_id = ?) 
    };
    
    my @ids;
    my $cur = execSql( $dbh_gold, $sql, $verbose, $submissionId );
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if (!$id);
        next if ($id eq $submissionId);
        push( @ids, $id );
    }
    return \@ids;   
    
}

# get all the taxon / sample names plus taxon_oid that made this combined sample
sub getTaxonNames {
    my ( $dbh, $dbh_gold, $submissionId ) = @_;

    # gold db
    # gets all samples that made this combined sample
    my $goldIds_aref = getGoldIds( $dbh_gold, $submissionId );

    my $subIds_aref = getAllOtherSubmissionIds($dbh_gold, $submissionId);

    # TODO
    # insert to tmp table
    OracleUtil::insertDataArray( $dbh, "gtt_func_id", $goldIds_aref );
    OracleUtil::insertDataArray( $dbh, "gtt_num_id", $subIds_aref );
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    # img db
    # get all the taxons from the above submissions
    my %taxons;    # taxon_oid => name
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name
from taxon t 
where t.obsolete_flag = 'No'
$rclause
$imgClause
and t.sample_gold_id in (select id from gtt_func_id)
union
select t.taxon_oid, t.taxon_display_name
from taxon t 
where t.obsolete_flag = 'No'
$rclause
$imgClause
and t.submission_id in (select id from gtt_num_id)   
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $taxons{$id} = $name;
    }
    return \%taxons;
}

sub getTaxonNames_old {
    my ( $dbh, $dbh_gold, $submissionId ) = @_;

    # gold db
    # gets all samples that made this combined sample
    my @submissionsIds;
    my $sql = qq{
select max(s.submission_id), s.sample_oid
from submission_samples ss, submission s
where ss.submission_id = ?
and ss.sample_oid = s.sample_oid
and species_code != 'TEST'
group by s.sample_oid
};
    my $cur = execSql( $dbh_gold, $sql, $verbose, $submissionId );
    for ( ; ; ) {
        my ( $sub, $sample ) = $cur->fetchrow();
        last if !$sub;
        push( @submissionsIds, $sub );
    }

    # TODO
    # insert to tmp table
    OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@submissionsIds );
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    # img db
    # get all the taxons from the above submissions
    my %taxons;    # taxon_oid => name
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name
from taxon t 
where obsolete_flag = 'No'
$rclause
$imgClause
and submission_id in (select id from gtt_num_id)   
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $taxons{$id} = $name;
    }
    return \%taxons;
}

1;
