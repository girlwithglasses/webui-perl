###########################################################################
#
# $Id: GoldDataEntryUtil.pm 33841 2015-07-29 20:48:56Z klchu $
#
###########################################################################
package GoldDataEntryUtil;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;
use CGI qw( :standard );

$| = 1;

my $env                  = getEnv();
my $cgi_dir              = $env->{cgi_dir};
my $cgi_url              = $env->{cgi_url};
my $main_cgi             = $env->{main_cgi};
my $inner_cgi            = $env->{inner_cgi};
my $tmp_url              = $env->{tmp_url};
my $verbose              = $env->{verbose};
my $include_metagenomes  = $env->{include_metagenomes};


sub convetKey2Value {
    my ($aHash_ref) = @_;

    my %newHash = {};
    foreach my $key ( keys %$aHash_ref ) {
        next if ( $key eq '' );
        my $value = $aHash_ref->{$key};
        $newHash{$value} .= "$key";
    }
    return %newHash;
}

############################################################################
# getMetadataForAttrs_new
#
# use img submission_ids or gold ids to find metadata from GOLD
############################################################################
# TODO - what about submission ids for private data
#
#$VAR1 = [ 'biotic_rel', 'sample_body_site', 'sample_body_subsite', 'cell_arrangement',
#'cell_shape', 'diseases', 'energy_source', 'ecosystem', 'ecosystem_category', 'ecosystem_type',
#'ecosystem_subtype', 'specific_ecosystem', 'gram_stain', 'host_name', 'motility',
#'metabolism', 'oxygen_req', 'phenotypes', 'project_relevance', 'salinity', 'sporulation',
#'temp_range' ];
#
sub getMetadataForAttrs_new {
    my ( $tOids2SubmissionIds_href, $tOids2GoldIds_href, $metaAttrs_aref ) = @_;
    my @gold_ids           = values(%$tOids2GoldIds_href);
    my @sub_ids            = values(%$tOids2SubmissionIds_href);
    my %submissionId2tOids = convetKey2Value($tOids2SubmissionIds_href);
    my %goldId2tOids       = convetKey2Value($tOids2GoldIds_href);

    # sql @others hash meta to array index
    # the keys map to names found in $metaAttrs_aref
    # also see @goldCondAttrs in DataEntryUtil.pm
    # and TaxonTableConfiguration for column sorting
    my %sqlColumnMapping = (
                             biotic_rel          => 0,
                             sample_body_site    => 1,
                             sample_body_subsite => 2,
                             cell_arrangement    => 3,
                             cell_shape          => 4,
                             diseases            => 5,
                             energy_source       => 6,
                             ecosystem           => 7,
                             ecosystem_category  => 8,
                             ecosystem_type      => 9,
                             ecosystem_subtype   => 10,
                             specific_ecosystem  => 11,
                             gram_stain          => 12,
                             host_name           => 13,
                             motility            => 14,
                             metabolism          => 15,
                             oxygen_req          => 16,
                             phenotypes          => 17,
                             project_relevance   => 18,
                             salinity            => 19,
                             sporulation         => 20,
                             temp_range          => 21,
                             host_gender         => 22,
                             mrn                 => 23,
                             date_collected      => 24,
                             sample_oid          => 25,
                             project_info        => 26,
                             contact_name =>27, 
                             contact_email=>28, 
                             funding_program =>29,
    );

    my $dbh_gold = WebUtil::dbGoldLogin();

    my %tOids2Meta;

    # gold id clause
    my $str;
    if ( OracleUtil::useTempTable( $#gold_ids + 1 ) ) {
        OracleUtil::insertDataArray( $dbh_gold, "gtt_func_id", \@gold_ids );
        $str = "select id from gtt_func_id";
    } else {
        $str = "'" . join( "','", @gold_ids ) . "'";
    }

    # submission clause
    my $subClause1;
    my $subClause2;
    if ( $#sub_ids > -1 ) {
        if ( OracleUtil::useTempTable( $#sub_ids + 1 ) ) {
            OracleUtil::insertDataArray( $dbh_gold, "gtt_num_id", \@sub_ids );
            $subClause1 = qq{
where p.project_oid in (select s.project_info
                     from submission s
                     where s.sample_oid is null 
                     and s.submission_id in (select id from gtt_num_id))
            };

            $subClause2 = qq{
where en.sample_oid in (select s.sample_oid
                     from submission s
                     where s.sample_oid is not null 
                     and s.submission_id in (select id from gtt_num_id))
            };
        } else {
            my $tmp = join( ",", @sub_ids );
            $subClause1 = qq{
where p.project_oid in (select s.project_info
                     from submission s
                     where s.sample_oid is null  
                     and s.submission_id in ($tmp))
            };

            $subClause2 = qq{
where en.sample_oid in (select s.sample_oid
                     from submission s
                     where s.sample_oid is not null
                     and s.submission_id in ($tmp))
            };
        }
    }

    my $sql = qq{
select to_char(p.project_oid), p.gold_stamp_id, p.img_oid, s1.submission_id, s1.img_taxon_oid,
p.biotic_rel, ps.sample_body_site, ps.sample_body_subsite, 
pc.cell_arrangement, p.cell_shape, pd.diseases, pe.energy_source, 
p.ecosystem, p.ecosystem_category, p.ecosystem_type, p.ecosystem_subtype, 
p.specific_ecosystem, p.gram_stain, p.host_name, p.motility, pm.metabolism, p.oxygen_req,
pp.phenotypes, pr.project_relevance, p.salinity, p.sporulation, p.temp_range,
p.host_gender, null as mrn, null as date_collected, s1.sample_oid, p.project_oid,
p.contact_name, p.contact_email, p.funding_program
from project_info p
left join project_info_project_relevance pr on p.project_oid = pr.project_oid
left join project_info_body_sites ps on p.project_oid = ps.project_oid
left join project_info_cell_arrangement pc on p.project_oid = pc.project_oid 
left join project_info_diseases pd on p.project_oid = pd.project_oid
left join project_info_energy_source pe on p.project_oid = pe.project_oid
left join project_info_metabolism pm on p.project_oid = pm.project_oid
left join project_info_phenotypes pp on p.project_oid = pp.project_oid
left join submission s1 on p.project_oid = s1.project_info
where s1.sample_oid is null 
and p.gold_stamp_id in ($str)
     };

    if ( $subClause1 ne "" ) {
        $sql .= qq{
union
select to_char(p.project_oid), p.gold_stamp_id, p.img_oid, s1.submission_id, s1.img_taxon_oid,
p.biotic_rel, ps.sample_body_site, ps.sample_body_subsite, 
pc.cell_arrangement, p.cell_shape, pd.diseases, pe.energy_source, 
p.ecosystem, p.ecosystem_category, p.ecosystem_type, p.ecosystem_subtype, 
p.specific_ecosystem, p.gram_stain, p.host_name, p.motility, pm.metabolism, p.oxygen_req,
pp.phenotypes, pr.project_relevance, p.salinity, p.sporulation, p.temp_range,
p.host_gender, null as mrn, null as date_collected, s1.sample_oid, p.project_oid,
p.contact_name, p.contact_email, p.funding_program
from project_info p
left join project_info_project_relevance pr on p.project_oid = pr.project_oid
left join project_info_body_sites ps on p.project_oid = ps.project_oid
left join project_info_cell_arrangement pc on p.project_oid = pc.project_oid 
left join project_info_diseases pd on p.project_oid = pd.project_oid
left join project_info_energy_source pe on p.project_oid = pe.project_oid
left join project_info_metabolism pm on p.project_oid = pm.project_oid
left join project_info_phenotypes pp on p.project_oid = pp.project_oid
left join submission s1 on p.project_oid = s1.project_info
$subClause1
     };
    }

    if ($include_metagenomes) {
        $sql .= qq{
union
select  's' || en.sample_oid, en.gold_id, en.img_oid, s2.submission_id, s2.img_taxon_oid,
null, en.body_site, en.body_subsite, 
pc.cell_arrangement, null, ed.diseases, ee.energy_source, 
en.ecosystem, en.ecosystem_category, en.ecosystem_type, en.ecosystem_subtype, 
en.specific_ecosystem, null, en.host_name, null, em.metabolism, en.oxygen_req,
ep.phenotypes, pr.project_relevance, en.salinity, null, en.temp_range,
en.host_gender, en.mrn, en.date_collected, en.sample_oid, en.project_info,
null, null, null
from env_sample en
left join project_info_project_relevance pr on en.project_info = pr.project_oid
left join project_info_cell_arrangement pc on en.project_info = pc.project_oid 
left join env_sample_diseases ed on en.sample_oid = ed.sample_oid
left join env_sample_energy_source ee on en.sample_oid = ee.sample_oid
left join env_sample_metabolism em on en.sample_oid = em.sample_oid
left join env_sample_phenotypes ep on en.sample_oid = ep.sample_oid
left join submission s2 on en.sample_oid = s2.sample_oid
where s2.sample_oid is not null 
and en.gold_id in ($str)            
        };

        if ( $subClause2 ne "" ) {
            $sql .= qq{
union
select  's' || en.sample_oid, en.gold_id, en.img_oid, s2.submission_id, s2.img_taxon_oid,
null, en.body_site, en.body_subsite, 
pc.cell_arrangement, null, ed.diseases, ee.energy_source, 
en.ecosystem, en.ecosystem_category, en.ecosystem_type, en.ecosystem_subtype, 
en.specific_ecosystem, null, en.host_name, null, em.metabolism, en.oxygen_req,
ep.phenotypes, pr.project_relevance, en.salinity, null, en.temp_range,
en.host_gender, en.mrn, en.date_collected, en.sample_oid, en.project_info,
null, null, null
from env_sample en
left join project_info_project_relevance pr on en.project_info = pr.project_oid
left join project_info_cell_arrangement pc on en.project_info = pc.project_oid 
left join env_sample_diseases ed on en.sample_oid = ed.sample_oid
left join env_sample_energy_source ee on en.sample_oid = ee.sample_oid
left join env_sample_metabolism em on en.sample_oid = em.sample_oid
left join env_sample_phenotypes ep on en.sample_oid = ep.sample_oid
left join submission s2 on en.sample_oid = s2.sample_oid
$subClause2
            };
        }
    }

    $sql .= qq{
order by 1        
    };

    my $cur = execSql( $dbh_gold, $sql, $verbose );

    # for isolates project id for metagenome sample oid prefix with 's'
    my $last_project_oid;

    # taxon oid
    my $taxon_oid;
    my @last_others;
    for ( ; ; ) {
        my ( $project_oid, $gold_id, $img_oid, $submission_id, $sub_img_taxon_oid, @others ) =
          $cur->fetchrow();
        last if !$project_oid;

        if ( $img_oid eq "" && $sub_img_taxon_oid eq "" ) {
            next;
        } elsif (    exists $tOids2SubmissionIds_href->{$img_oid}
                  || exists $tOids2GoldIds_href->{$img_oid}
                  || exists $tOids2SubmissionIds_href->{$sub_img_taxon_oid}
                  || exists $tOids2GoldIds_href->{$sub_img_taxon_oid} )
        {

            # do nothing
        } else {

            #webLog("reejected $img_oid $sub_img_taxon_oid \n");
            next;
        }

        if ( $last_project_oid && $last_project_oid ne $project_oid ) {

            # save project save to hash

            my $rec;
            for ( my $i = 0 ; $i <= $#$metaAttrs_aref ; $i++ ) {
                my $selectedMetadata = $metaAttrs_aref->[$i];
                my $index            = $sqlColumnMapping{$selectedMetadata};
                my $value            = $last_others[$index];
                $rec .= $value;
                $rec .= "\t" if ( $i < $#$metaAttrs_aref );
            }
            $tOids2Meta{$taxon_oid} = $rec;

            @last_others = ();
        }

        if ( $#last_others < 0 ) {
            @last_others = @others;
        } else {
            for ( my $i = 0 ; $i <= $#others ; $i++ ) {
                my $value = $others[$i];
                next if $value eq "";
                if ( $last_others[$i] ne "" ) {

                 # only add if value is not already there - ken
                 # we have to do this because there can be many project rel. thus causing duplicates
                 # in other columns for meta data
                    $last_others[$i] = $last_others[$i] . ", " . $value
                      if ( $last_others[$i] !~ /$value/ );
                } else {
                    $last_others[$i] = $value;
                }
            }
        }

        if ( exists $goldId2tOids{$gold_id} ) {

            # remember gold_id in the hash will be GsXXXX first - overrides GmXXXx ids - ken
            $taxon_oid = $goldId2tOids{$gold_id};
        } elsif ( exists $submissionId2tOids{$submission_id} ) {
            $taxon_oid = $submissionId2tOids{$submission_id};
        }

        $last_project_oid = $project_oid;
    }

    # last record
    my $rec;
    for ( my $i = 0 ; $i <= $#$metaAttrs_aref ; $i++ ) {
        my $selectedMetadata = $metaAttrs_aref->[$i];
        my $index            = $sqlColumnMapping{$selectedMetadata};
        my $value            = $last_others[$index];
        $rec .= $value;
        $rec .= "\t" if ( $i < $#$metaAttrs_aref );
    }
    $tOids2Meta{$taxon_oid} = $rec;

    #$dbh_gold->disconnect();

    return %tOids2Meta;
}

############################################################################
# getMetadataForAttrs_new_2_0
#
# use img submission_ids or gold ids to find metadata from GOLD
#
# a newer one 2.0 - let just get all the data from gold -
# the original query is almost getting all the data
#
############################################################################
sub getMetadataForAttrs_new_2_0 {
    my ( $tOids2SubmissionIds_href, $tOids2GoldIds_href, $metaAttrs_aref, $tOids2ProjectGoldIds_href ) = @_;
    my @taxonOids          = keys %$tOids2GoldIds_href;
    my @tmp = keys %$tOids2SubmissionIds_href;
    push(@taxonOids, @tmp);
    my @gold_ids           = values(%$tOids2GoldIds_href);
    my @tmpgold            = values(%$tOids2ProjectGoldIds_href);
    push(@gold_ids, @tmpgold);
    my @sub_ids            = values(%$tOids2SubmissionIds_href);
    my %submissionId2tOids = convetKey2Value($tOids2SubmissionIds_href);
    my %goldId2tOids       = convetKey2Value($tOids2GoldIds_href);

    # sql @others hash meta to array index
    # the keys map to names found in $metaAttrs_aref
    # also see @goldCondAttrs in DataEntryUtil.pm
    # and TaxonTableConfiguration for column sorting
    my %sqlColumnMapping = (
                             biotic_rel          => 0,
                             sample_body_site    => 1,
                             sample_body_subsite => 2,
                             cell_arrangement    => 3,
                             cell_shape          => 4,
                             diseases            => 5,
                             energy_source       => 6,
                             ecosystem           => 7,
                             ecosystem_category  => 8,
                             ecosystem_type      => 9,
                             ecosystem_subtype   => 10,
                             isolation => 11,
                             specific_ecosystem  => 12,
                             gram_stain          => 13,
                             host_name           => 14,
                             motility            => 15,
                             metabolism          => 16,
                             oxygen_req          => 17,
                             phenotypes          => 18,
                             project_relevance   => 19,
                             salinity            => 20,
                             sporulation         => 21,
                             temp_range          => 22,
                             host_gender         => 23,
                             mrn                 => 24,
                             date_collected      => 25,
                             sample_oid          => 26,
                             project_info        => 27,
                             contact_name =>28, 
                             contact_email=>29, 
                             funding_program =>30,                             
                             gold_project_id =>31,                   
    );
    my %sqlColumnMapping2 = convetKey2Value( \%sqlColumnMapping );

    my $dbh_gold = WebUtil::dbGoldLogin();

    my %tOids2Meta;

    # gold id clause
    my $str;
    if ( OracleUtil::useTempTable( $#gold_ids + 1 ) ) {
        OracleUtil::insertDataArray( $dbh_gold, "gtt_func_id", \@gold_ids );
        $str = "select id from gtt_func_id";
    } else {
        $str = "'" . join( "','", @gold_ids ) . "'";
    }

    # taxon oid clause
    my $taxonOidsStr;
    if ( OracleUtil::useTempTable( $#taxonOids + 1 ) ) {
        OracleUtil::insertDataArray( $dbh_gold, "gtt_num_id1", \@taxonOids );
        $taxonOidsStr = "select id from gtt_num_id1";
    } else {
        $taxonOidsStr = "'" . join( "','", @taxonOids ) . "'";
    }
    

    # submission clause
    my $subClause1;
    my $subClause2;
    if ( $#sub_ids > -1 ) {
        if ( OracleUtil::useTempTable( $#sub_ids + 1 ) ) {
            OracleUtil::insertDataArray( $dbh_gold, "gtt_num_id", \@sub_ids );
            $subClause1 = qq{
where p.project_oid in (select s.project_info
                     from submission s
                     where s.submission_id in (select id from gtt_num_id))
            };

            $subClause2 = qq{
where en.sample_oid in (select s.sample_oid
                     from submission s
                     where s.submission_id in (select id from gtt_num_id))
            };
        } else {
            my $tmp = join( ",", @sub_ids );
            $subClause1 = qq{
where p.project_oid in (select s.project_info
                     from submission s
                     where s.submission_id in ($tmp))
            };

            $subClause2 = qq{
where en.sample_oid in (select s.sample_oid
                     from submission s
                     where s.submission_id in ($tmp))
            };
        }
    }

    my $sql = qq{
select to_char(p.project_oid), p.gold_stamp_id, p.img_oid, s1.submission_id, s1.img_taxon_oid,
p.biotic_rel, ps.sample_body_site, ps.sample_body_subsite, 
pc.cell_arrangement, p.cell_shape, pd.diseases, pe.energy_source, 
p.ecosystem, p.ecosystem_category, p.ecosystem_type, p.ecosystem_subtype, p.isolation,
p.specific_ecosystem, p.gram_stain, p.host_name, p.motility, pm.metabolism, p.oxygen_req,
pp.phenotypes, pr.project_relevance, p.salinity, p.sporulation, p.temp_range,
p.host_gender, null as mrn, null as date_collected, s1.sample_oid, p.project_oid,
p.contact_name, p.contact_email, p.funding_program, p.gold_stamp_id
from project_info p
left join project_info_project_relevance pr on p.project_oid = pr.project_oid
left join project_info_body_sites ps on p.project_oid = ps.project_oid
left join project_info_cell_arrangement pc on p.project_oid = pc.project_oid 
left join project_info_diseases pd on p.project_oid = pd.project_oid
left join project_info_energy_source pe on p.project_oid = pe.project_oid
left join project_info_metabolism pm on p.project_oid = pm.project_oid
left join project_info_phenotypes pp on p.project_oid = pp.project_oid
left join submission s1 on p.project_oid = s1.project_info
where p.img_oid in ($taxonOidsStr)
        
union
        
select to_char(p.project_oid), p.gold_stamp_id, p.img_oid, s1.submission_id, s1.img_taxon_oid,
p.biotic_rel, ps.sample_body_site, ps.sample_body_subsite, 
pc.cell_arrangement, p.cell_shape, pd.diseases, pe.energy_source, 
p.ecosystem, p.ecosystem_category, p.ecosystem_type, p.ecosystem_subtype, p.isolation,
p.specific_ecosystem, p.gram_stain, p.host_name, p.motility, pm.metabolism, p.oxygen_req,
pp.phenotypes, pr.project_relevance, p.salinity, p.sporulation, p.temp_range,
p.host_gender, null as mrn, null as date_collected, s1.sample_oid, p.project_oid,
p.contact_name, p.contact_email, p.funding_program, p.gold_stamp_id
from project_info p
left join project_info_project_relevance pr on p.project_oid = pr.project_oid
left join project_info_body_sites ps on p.project_oid = ps.project_oid
left join project_info_cell_arrangement pc on p.project_oid = pc.project_oid 
left join project_info_diseases pd on p.project_oid = pd.project_oid
left join project_info_energy_source pe on p.project_oid = pe.project_oid
left join project_info_metabolism pm on p.project_oid = pm.project_oid
left join project_info_phenotypes pp on p.project_oid = pp.project_oid
left join submission s1 on p.project_oid = s1.project_info
where p.gold_stamp_id in ($str)
     };

    if ( $subClause1 ne "" ) {
        $sql .= qq{
union
select to_char(p.project_oid), p.gold_stamp_id, p.img_oid, s1.submission_id, s1.img_taxon_oid,
p.biotic_rel, ps.sample_body_site, ps.sample_body_subsite, 
pc.cell_arrangement, p.cell_shape, pd.diseases, pe.energy_source, 
p.ecosystem, p.ecosystem_category, p.ecosystem_type, p.ecosystem_subtype, p.isolation,
p.specific_ecosystem, p.gram_stain, p.host_name, p.motility, pm.metabolism, p.oxygen_req,
pp.phenotypes, pr.project_relevance, p.salinity, p.sporulation, p.temp_range,
p.host_gender, null as mrn, null as date_collected, s1.sample_oid, p.project_oid,
p.contact_name, p.contact_email, p.funding_program, p.gold_stamp_id
from project_info p
left join project_info_project_relevance pr on p.project_oid = pr.project_oid
left join project_info_body_sites ps on p.project_oid = ps.project_oid
left join project_info_cell_arrangement pc on p.project_oid = pc.project_oid 
left join project_info_diseases pd on p.project_oid = pd.project_oid
left join project_info_energy_source pe on p.project_oid = pe.project_oid
left join project_info_metabolism pm on p.project_oid = pm.project_oid
left join project_info_phenotypes pp on p.project_oid = pp.project_oid
left join submission s1 on p.project_oid = s1.project_info
$subClause1
     };
    }

    if ($include_metagenomes) {
        $sql .= qq{
union
select  's' || en.sample_oid, en.gold_id, en.img_oid, s2.submission_id, s2.img_taxon_oid,
null, en.body_site, en.body_subsite, 
pc.cell_arrangement, null, ed.diseases, ee.energy_source, 
en.ecosystem, en.ecosystem_category, en.ecosystem_type, en.ecosystem_subtype, null,
en.specific_ecosystem, null, en.host_name, null, em.metabolism, en.oxygen_req,
ep.phenotypes, pr.project_relevance, en.salinity, null, en.temp_range,
en.host_gender, en.mrn, en.date_collected, en.sample_oid, en.project_info,
null, null, null, null
from env_sample en
left join project_info_project_relevance pr on en.project_info = pr.project_oid
left join project_info_cell_arrangement pc on en.project_info = pc.project_oid 
left join env_sample_diseases ed on en.sample_oid = ed.sample_oid
left join env_sample_energy_source ee on en.sample_oid = ee.sample_oid
left join env_sample_metabolism em on en.sample_oid = em.sample_oid
left join env_sample_phenotypes ep on en.sample_oid = ep.sample_oid
left join submission s2 on en.sample_oid = s2.sample_oid
where en.gold_id in ($str)            
        };

        if ( $subClause2 ne "" ) {
            $sql .= qq{
union
select  's' || en.sample_oid, en.gold_id, en.img_oid, s2.submission_id, s2.img_taxon_oid,
null, en.body_site, en.body_subsite, 
pc.cell_arrangement, null, ed.diseases, ee.energy_source, 
en.ecosystem, en.ecosystem_category, en.ecosystem_type, en.ecosystem_subtype, null,
en.specific_ecosystem, null, en.host_name, null, em.metabolism, en.oxygen_req,
ep.phenotypes, pr.project_relevance, en.salinity, null, en.temp_range,
en.host_gender, en.mrn, en.date_collected, en.sample_oid, en.project_info,
null, null, null, null
from env_sample en
left join project_info_project_relevance pr on en.project_info = pr.project_oid
left join project_info_cell_arrangement pc on en.project_info = pc.project_oid 
left join env_sample_diseases ed on en.sample_oid = ed.sample_oid
left join env_sample_energy_source ee on en.sample_oid = ee.sample_oid
left join env_sample_metabolism em on en.sample_oid = em.sample_oid
left join env_sample_phenotypes ep on en.sample_oid = ep.sample_oid
left join submission s2 on en.sample_oid = s2.sample_oid
$subClause2
            };
        }
    }

    #    $sql .= qq{
    #order by 1
    #    };

    my $cur = execSql( $dbh_gold, $sql, $verbose );

    # taxon oid => hash of metadata attributes
    my %hash;
    for ( ; ; ) {
        my ( $project_oid, $gold_id, $img_oid, $submission_id, $sub_img_taxon_oid, @others ) =
          $cur->fetchrow();
        last if !$project_oid;
        next if ( $img_oid eq '' && $sub_img_taxon_oid eq '' );

        # submission taxon oid overrides the img_oid in project
        $img_oid = $sub_img_taxon_oid if ( $sub_img_taxon_oid ne ''  &&  $img_oid eq '');
#print "$project_oid, $gold_id, $img_oid, $submission_id, $sub_img_taxon_oid <br/>\n";
        if ( $img_oid eq '' ) {
            # some old metagenomes have no sample id but should have gold project id?
            next; 
        }



        if ( exists $hash{$img_oid} ) {
            my $metadata_href = $hash{$img_oid};
            if ( $project_oid =~ /^s/ ) {
                $project_oid =~ s/^s//;
                $metadata_href->{'sample_oid'} = $project_oid;
            } else {
                $metadata_href->{'project_oid'} = $project_oid;
            }
            for ( my $i = 0 ; $i <= $#others ; $i++ ) {
                my $value = $sqlColumnMapping2{$i};
                if ( $others[$i] ne '' ) {
                    if ( $metadata_href->{$value} eq '' ) {
                        $metadata_href->{$value} = $others[$i];
                    } else {
                        # check for duplicates
                        my $found = 0;
                        my @a = split(/,-, /, $metadata_href->{$value});
                        foreach my $x (@a) {
                            if($x eq $others[$i]) {
                                $found = 1;
                                last;
                            }
                        }
                        if(!$found) {
                            $metadata_href->{$value} = $metadata_href->{$value} . ',-, ' . $others[$i];
                        }
                    }
                }
            }
        } else {
            my %metadata;
            if ( $project_oid =~ /^s/ ) {
                $project_oid =~ s/^s//;
                $metadata{'sample_oid'} = $project_oid;
            } else {
                $metadata{'project_oid'} = $project_oid;
            }
            $metadata{'gold_id'}       = $gold_id;
            $metadata{'submission_id'} = $submission_id;
            for ( my $i = 0 ; $i <= $#others ; $i++ ) {
                my $value = $sqlColumnMapping2{$i};
                $metadata{$value} = $others[$i] if ( $others[$i] ne '' );
            }

            $hash{$img_oid} = \%metadata;
        }
    }


    #$dbh_gold->disconnect();

    
    foreach my $taxon_oid (keys %$tOids2ProjectGoldIds_href) {
        next if (exists  $hash{$taxon_oid});
        # now we have a genome with gold projecet id but no metadata because the project_info has another taxon_oid linked
        # to it
        my $goldPrjId = $tOids2ProjectGoldIds_href->{$taxon_oid};
        foreach my $key (sort %hash) {
            # gold_project_id
            my $metadata_href = $hash{$key};
            my $gid = $metadata_href->{gold_project_id};
            if($goldPrjId eq $gid) {
                $hash{$taxon_oid} = $metadata_href;
                webLog("no metadata for $taxon_oid used data from $key ======================== \n");
                last;
            }
        }
    }

#    print "<br/>";
#    print Dumper \%hash;
#    print "<br/>";

    foreach my $taxon_oid ( keys %hash ) {
        my $metadata_href = $hash{$taxon_oid};
        my $rec;
        for ( my $i = 0 ; $i <= $#$metaAttrs_aref ; $i++ ) {
            my $selectedMetadata = $metaAttrs_aref->[$i];
            my $value            = $metadata_href->{$selectedMetadata};
            $value =~ s/,-,/, /g;
            # shift stopper - ken
            $value = '_' if ($value eq '' || blankStr($value));
            $rec .= $value;
            $rec .= "\t" if ( $i < $#$metaAttrs_aref );
        }
        $tOids2Meta{$taxon_oid} = $rec;
    }

    #print Dumper \%tOids2Meta;
    #print "<br/>\n";
    return %tOids2Meta;
}

sub getCategoryOperationGoldAndSumissionIds {
    my ( $toProcessVal, @cond_attrs ) = @_;

    my @outputAttrs    = ();

    my $outColClause = '';
    my $outColClause_p = '';
    my $fromClause = '';
    my $sampleFromClause = '';
    my $joinFromAndClause = '';
    my $sampleJoinFromAndClause = '';
    my $cond = '';
    my $cond_p = '';
    for my $attr (@cond_attrs) {
        if ( DataEntryUtil::isGoldSingleAttr($attr) ) {

            # single-valued
            my @vals = ();
            if ($toProcessVal) {
                @vals = processParamValue(param($attr));
            } else {
                @vals = param($attr);           
            }

            if ( scalar(@vals) > 0 ) {
                push(@outputAttrs, $attr);

                my $meta_table = "p";
		if ( $attr =~ /ecosystem/ || 
		     $attr eq 'altitude' ||
		     $attr eq 'iso_country' ||
		     $attr eq 'oxygen_req' ||
		     $attr eq 'temp_range' ||
		     $attr eq 'salinity' ) {
		    $meta_table = "es";
		}
                $outColClause .= ", $meta_table.$attr";
                $outColClause_p .= ", p.$attr";
                my $cond1 = "";
                my $cond2 = "";
                if (scalar(@vals) == 1 && !DataEntryUtil::getGoldAttrCVQuery($attr)) {
                    $cond1 = "$meta_table.$attr is not null " ;
                    $cond2 = "p.$attr is not null " ;
                }
                else {
                    for my $val (@vals) {
                        $val =~ s/'/''/g;    # replace ' with ''
                        if ( blankStr($cond1) ) {
                            $cond1 = "$meta_table.$attr in ('$val'";
                            $cond2 = "p.$attr in ('$val'";
                        } else {
                            $cond1 .= ", '" . $val . "'";
                            $cond2 .= ", '" . $val . "'";
                        }
                    }    # end for val                    
                    if ( !blankStr($cond1) ) {
                        $cond1 .= ")";
                        $cond2 .= ")";
                    }
                }

                if ( !blankStr($cond1) ) {
                    $cond .= " and $cond1";
                    $cond_p .= " and $cond2";
                }
            }
        } else {
            # set-valued
            my @vals = ();
            if ($toProcessVal) {
                @vals = processParamValue(param($attr));
            } else {
                @vals = param($attr);           
            }
            if ( scalar(@vals) > 0 ) {
                push(@outputAttrs, $attr);
                                
                my $table_name;
		my $sample_table_name;
                my $t_alias = DataEntryUtil::getGoldSetAttrTableNameAlias($attr);
                my $attrWithAlias;
                my $sampleAttrWithAlias;
                
                if ( $attr eq 'funding_agency' || $attr eq 'seq_center') {
                    my $link_type_val = '';
                    if ( $attr eq 'funding_agency' ) {
                        $link_type_val = 'Funding';
                    } elsif ( $attr eq 'seq_center' ) {
                        $link_type_val = 'Seq Center';
                    }
        
                    $table_name = "project_info_data_links";
                    $attrWithAlias = "$t_alias.db_name";
                    $sampleAttrWithAlias = "$t_alias.db_name";
                    $cond .= " and $t_alias.link_type = '$link_type_val'";
                    $cond_p .= " and $t_alias.link_type = '$link_type_val'";
                } 
                else {
                    $table_name = DataEntryUtil::getGoldSetAttrTableName($attr);
		    $sample_table_name = $table_name;

                    $attrWithAlias = "$t_alias.$attr";
                    $sampleAttrWithAlias = "$t_alias.$attr";

		    if ( $attr eq 'diseases' ) {
			$sample_table_name = 'env_sample_diseases';
		    }
		    elsif ( $attr eq 'energy_source' ) {
			$sample_table_name = 'env_sample_energy_source';
		    }
		    elsif ( $attr eq 'habitat' ) {
			$sample_table_name = 'env_sample_habitat_type';
			$sampleAttrWithAlias = "$t_alias.habitat_type";
		    }
		    elsif ( $attr eq 'metabolism' ) {
			$sample_table_name = 'env_sample_metabolism';
		    }
		    elsif ( $attr eq 'phenotypes' ) {
			$sample_table_name = 'env_sample_phenotypes';
		    }
                }                

                $outColClause .= ", $sampleAttrWithAlias";
                $outColClause_p .= ", $attrWithAlias";
                $fromClause .= ", $table_name $t_alias";
                $sampleFromClause .= ", $sample_table_name $t_alias";
                $joinFromAndClause .= " and p.project_oid = $t_alias.project_oid ";
                $sampleJoinFromAndClause .= " and es.sample_oid = $t_alias.sample_oid ";
		if ( $attr ne 'diseases' &&
		     $attr ne 'energy_source' &&
		     $attr ne 'habitat' &&
		     $attr ne 'metabolism' &&
		     $attr ne 'phenotypes' ) {
		    $sampleJoinFromAndClause = $joinFromAndClause;
		}

                my $cond1 = '';
                my $cond2 = '';
                for my $val (@vals) {
                    $val =~ s/'/''/g;    # replace ' with ''
                    if ( blankStr($cond1) ) {
                        $cond1 .= "$sampleAttrWithAlias in ('" . $val . "'";
                        $cond2 .= "$attrWithAlias in ('" . $val . "'";
                    } else {
                        $cond1 .= ", '" . $val . "'";
                        $cond2 .= ", '" . $val . "'";
                    }
                }    # end for val

                if ( !blankStr($cond1) ) {
                    $cond1 .= ")";
                    $cond2 .= ")";
                    $cond .= " and $cond1";
                    $cond_p .= " and $cond2";
                }
            }
        }
    }

    my $sql = qq{
        select p.project_oid, p.gold_stamp_id, es.gold_id, NULL $outColClause 
        from project_info p, env_sample es $sampleFromClause
        where p.project_oid = es.project_info
        and p.domain = 'MICROBIAL'
        $sampleJoinFromAndClause
        $cond
        UNION
        select p.project_oid, p.gold_stamp_id, NULL, s.submission_id $outColClause_p
        from project_info p, submission s $fromClause
        where p.project_oid = s.project_info (+)
        and p.domain != 'MICROBIAL'
        $joinFromAndClause
        $cond_p
    };
    #print "GoldDataEntryUtil::getQueryGoldAndSumissionIds() gold sql: $sql<br/>\n";

##    print "<p>*** SQL: $sql\n";

    my $dbh = WebUtil::dbGoldLogin();
    my $cur = execSql( $dbh, $sql, $verbose );

    my %gold_stamp_id2outColVals;
    my %gold_id2outColVals;
    my %submission_id2outColVals;    
    for ( ; ; ) {
        my ( $id, $gold_stamp_id, $gold_id, $submission_id, @outColVal ) = $cur->fetchrow();
        last if !$id;

	## this is project gold id
#        if ( !blankStr($gold_stamp_id) ) {
        if ( !blankStr($gold_stamp_id) && blankStr($gold_id) ) {
            $gold_stamp_id2outColVals{$gold_stamp_id} = \@outColVal;
        }

	## this is sample gold_id
        if ( !blankStr($gold_id) ) {
            $gold_id2outColVals{$gold_id} = \@outColVal;
        }

        if ( !blankStr($submission_id) && isInt($submission_id) ) {
            $submission_id2outColVals{$submission_id} = \@outColVal;
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    return (\%gold_stamp_id2outColVals, \%gold_id2outColVals, 
            \%submission_id2outColVals, \@outputAttrs);
}


sub getCategorySearchGoldAndSumissionIds {
    my ( $searchFilter, $searchTermLc ) = @_;

    my $outColClause = '';
    my $fromClause = '';
    my $joinFromAndClause = '';
    my $cond = '';
    if (DataEntryUtil::isGoldSingleAttr($searchFilter)) {
        $outColClause = ", p.$searchFilter";
        $cond = " and lower(p.$searchFilter) like '%$searchTermLc%' ";
    }
    elsif (DataEntryUtil::isGoldSetAttr($searchFilter)) {
        if ( $searchFilter eq 'funding_agency' || $searchFilter eq 'seq_center') {
            my $link_type_val = '';
            if ( $searchFilter eq 'funding_agency' ) {
                $link_type_val = 'Funding';
            } elsif ( $searchFilter eq 'seq_center' ) {
                $link_type_val = 'Seq Center';
            }

            $outColClause = ', tb.db_name';
            $fromClause = ', project_info_data_links tb';
            $joinFromAndClause = ' and p.project_oid = tb.project_oid ';
            $cond = " and tb.link_type = '$link_type_val'";
            $cond .= " and lower(tb.db_name) like '%$searchTermLc%' ";
        } 
        else {
            my $table_name = DataEntryUtil::getGoldSetAttrTableName($searchFilter);
            $outColClause = ", tb.$searchFilter";
            $fromClause = ", $table_name tb ";
            $joinFromAndClause = ' and p.project_oid = tb.project_oid ';
            $cond = " and lower(tb.$searchFilter) like '%$searchTermLc%' ";
        }
    }

    my $sql = qq{
        select p.project_oid, p.gold_stamp_id, es.gold_id, NULL $outColClause
        from project_info p, env_sample es $fromClause
        where p.project_oid = es.project_info (+)
        $joinFromAndClause
        $cond
        UNION
        select p.project_oid, p.gold_stamp_id, NULL, s.submission_id $outColClause
        from project_info p, submission s  $fromClause
        where p.project_oid = s.project_info (+)
        $joinFromAndClause
        $cond
    };
    #print "GoldDataEntryUtil::getCategorySearchGoldAndSumissionIds() gold sql: $sql<br/>\n";

    my $dbh = WebUtil::dbGoldLogin();
    my $cur = execSql( $dbh, $sql, $verbose );

    my %gold_stamp_id2outColVal;
    my %gold_id2outColVal;
    my %submission_id2outColVal;
    for ( ; ; ) {
        my ( $id, $gold_stamp_id, $gold_id, $submission_id, $outColVal ) = $cur->fetchrow();
        last if !$id;

        if ( !blankStr($gold_stamp_id) ) {
            $gold_stamp_id2outColVal{$gold_stamp_id} = $outColVal;
        }

        if ( !blankStr($gold_id) ) {
            $gold_id2outColVal{$gold_id} = $outColVal;
        }

        if ( !blankStr($submission_id) && isInt($submission_id) ) {
            $submission_id2outColVal{$submission_id} = $outColVal;
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    return (\%gold_stamp_id2outColVal, \%gold_id2outColVal, \%submission_id2outColVal);
}

sub getSampleGoldIdClause {
    my ($dbh, @ids) = @_;

    my $id_conds = '';
    if ( scalar(@ids) > 0 ) {
        my $ids_str = OracleUtil::getFuncIdsInClause1( $dbh, @ids );
        $id_conds .= "tx.sample_gold_id in ( $ids_str ) ";
    }

    return $id_conds;
}

sub getGoldIdClause {
    my ($dbh, @ids) = @_;

    my $id_conds = '';
    if ( scalar(@ids) > 0 ) {
        my $ids_str = OracleUtil::getFuncIdsInClause2( $dbh, @ids );
        $id_conds .= "tx.gold_id in ( $ids_str ) ";
    }

    return $id_conds;
}

sub getSubmissionIdClause {
    my ($dbh, @ids) = @_;

    my $id_conds = '';
    if ( scalar(@ids) > 0 ) {
        my $ids_str = OracleUtil::getNumberIdsInClause3( $dbh, @ids );
        $id_conds .= "tx.submission_id in( $ids_str ) ";
    }

    return $id_conds;
}


1;
