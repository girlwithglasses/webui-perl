############################################################################
# DataEntryUtil.pm - Commmon data entry utility code.
#   imachen 10/03/2006
#
# $Id: DataEntryUtil.pm 33190 2015-04-17 23:20:02Z jinghuahuang $
############################################################################
package DataEntryUtil;
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
  db_findMaxID
  db_findID
  db_findVal
  db_findSetVal
  db_findCount
  db_getValues
  db_getValues2
  db_getLineage
  db_getImgGroup
  db_getImgGroups
  db_isPublicUser
  db_sqlTrans
  getOraInClause
  getCategoryGoldIds
  getQueryGoldIds
  getCategoryNCBIProjIds
  getGoldAttrDistribution
  getCategoryCondTaxonCount
  getCategoryCondTaxons
  evalPhenotypeRule
);
use strict;
use CGI qw( :standard );
use MIME::Base64 qw( encode_base64 decode_base64 );
use DBI;
use Data::Dumper;
use FileHandle;
use WebConfig;
use WebUtil;
use OracleUtil;

$| = 1;    # force flush

my $env                    = getEnv();
my $verbose                = $env->{verbose};
my $img_ken                = $env->{img_ken};
my $img_ken_localhost      = $env->{img_ken_localhost};
my $img_gold_oracle_config = $env->{img_gold_oracle_config};
my $img_pheno_rule         = $env->{img_pheno_rule};
my $include_metagenomes  = $env->{include_metagenomes};

my @goldSingleAttrs = (
    'altitude',
    'assembly_method',
    'biotic_rel',
    'cell_shape',
    'cultured',
    'culture_type',
    'uncultured_type',      
    'ecosystem',
    'ecosystem_category',
    'ecosystem_type',
    'ecosystem_subtype',
    'geo_location',
    'gold_stamp_id',
    'gram_stain',
    'host_name',
    'host_gender',
    'host_health',
    'host_medication',
    'iso_country',
    'iso_year',
    'isolation',
    'latitude',
    'library_method',
    'loc_coord',
    'longitude',
    'motility',
    'ncbi_project_id',
    'oxygen_req',
    'ph',
    'pub_journal',
    'pub_vol',
    'pub_link',
    'pressure',
    'salinity',
    'seq_status',
    'specific_ecosystem',
    'sporulation',
    'symbiotic_interaction',
    'symbiotic_rel',
    'symbiont',
    'temp_range',
    'temp_optimum',
    'funding_program',
    'type_strain',
);

my @goldSampleSingleAttrs = (
    'assembly_method',
    'ecosystem',
    'ecosystem_category',
    'ecosystem_type',
    'ecosystem_subtype',
    'geo_location',
    'host_name',
    'host_gender',
    'iso_country',
    'latitude',
    'library_method',
    'longitude',
    'ncbi_project_id',
    'oxygen_req',
    'ph',
    'pub_journal',
    'pub_vol',
    'pub_link',
    'pressure',
    'salinity',
    'specific_ecosystem',
);

my %goldSetAttr2TableName = (
    cell_arrangement => 'project_info_cell_arrangement',
    body_product => 'project_info_body_products',
    diseases => 'project_info_diseases',
    energy_source => 'project_info_energy_source',
    habitat => 'project_info_habitat',
    metabolism => 'project_info_metabolism',
    phenotypes => 'project_info_phenotypes',
    project_relevance => 'project_info_project_relevance',
    sample_body_site => 'project_info_body_sites',
    sample_body_subsite => 'project_info_body_sites',
    seq_method => 'project_info_seq_method',

    #need special treatment for sql
    funding_agency => 1,
    seq_center => 1,
);

my %goldSetAttr2TableNameAlias = (
    cell_arrangement => 'tna',
    body_product => 'tnb',
    diseases => 'tnc',
    energy_source => 'tnd',
    habitat => 'tne',
    metabolism => 'tnf',
    phenotypes => 'tng',
    project_relevance => 'tnh',
    sample_body_site => 'tni',
    sample_body_subsite => 'tnj',
    seq_method => 'tnk',

    #need special treatment for sql
    funding_agency => 'tnl',
    seq_center => 'tnl',
);

my %goldSetAttr2TableName = (
    cell_arrangement => 'project_info_cell_arrangement',
    body_product => 'project_info_body_products',
    diseases => 'project_info_diseases',
    energy_source => 'project_info_energy_source',
    habitat => 'project_info_habitat',
    metabolism => 'project_info_metabolism',
    phenotypes => 'project_info_phenotypes',
    project_relevance => 'project_info_project_relevance',
    sample_body_site => 'project_info_body_sites',
    sample_body_subsite => 'project_info_body_sites',
    seq_method => 'project_info_seq_method',

    #need special treatment for sql
    funding_agency => 1,
    seq_center => 1,
);

my @goldCondAttrs = (
    'altitude',
    'biotic_rel',
    'cell_arrangement', 
    'cell_shape',
    'cultured',
    'culture_type',
    'uncultured_type',          
    'diseases',
    'ecosystem',
    'ecosystem_category',
    'ecosystem_type',
    'ecosystem_subtype',
    'energy_source',
    'geo_location',
    'gram_stain',
    'habitat',
    'host_gender',
    'host_name',
    'iso_country',
    'isolation',
    'latitude', 
    'longitude',           
    'metabolism',
    'motility',
    'oxygen_req',
    'phenotypes',
    'project_relevance',
    'salinity', 
    'sample_body_site', 
    'sample_body_subsite',
    'specific_ecosystem',
    'sporulation',
    'temp_range',
    'funding_program',
    'type_strain',
    'sample_oid',
    'project_info',
    'contact_name', 
    'contact_email', 
);

# see FindGenomesByMetadata::printOrgCategoryResults_ImgGold and FindGenomesByMetadata::printCategoryContent
# where I remove this column from the list for meta data search - ken
if($include_metagenomes) {
    push(@goldCondAttrs, 'mrn');
    push(@goldCondAttrs, 'date_collected');
}

my %goldAttr2Display = (
    altitude        => "Altitude",
    additional_body_sample_site => "Additional Body Sample Site",
    assembly_method => "Assembly Method",
    biotic_rel      => "Biotic Relationships",
    body_sample_site => "Body Sample Site",
    body_sample_subsite => "Body Sample Subsite",
    body_product    => "Body Product",
    cell_shape      => "Cell Shape",
    cell_arrangement => "Cell Arrangement",
    cultured        => "Cultured",
    culture_type    => "Culture Type",
    uncultured_type => 'Uncultured Type',
    disease         => "Disease",
    diseases        => "Diseases",
    ecosystem       => "Ecosystem",
    ecosystem_category => "Ecosystem Category",
    ecosystem_type  => "Ecosystem Type",
    ecosystem_subtype => "Ecosystem Subtype",
    energy_source   => "Energy Source",
    funding_agency  => "Funding Agency",
    gram_stain      => "Gram Staining",
    gold_stamp_id   => "GOLD ID",
    geo_location    => "Geographic Location",
    habitat         => "Habitat",
    host_name       => "Host Name",
    host_gender     => "Host Gender",
    host_age        => "Host Age",
    host_health     => "Host Health",
    host_medication => "Host Medication",
    iso_country     => "Isolation Country",
    iso_year        => "Isolation Year",
    isolation       => "Isolation",
    library_method  => "Library Method",
    loc_coord       => "Location Coordinates",
    longitude       => "Longitude",
    latitude        => "Latitude",
    metabolism      => "Metabolism",
    motility        => "Motility",
    ncbi_project_id => "NCBI Project ID",
    oxygen_req      => "Oxygen Requirement",
    ph              => "pH",
    phenotype       => "Phenotype",
    phenotypes      => "Phenotype",
    pressure        => "Pressure",
    project_relevance => "Relevance",
    pub_journal     => "Publication Journal",
    pub_vol         => "Publication Volume",
    pub_link        => "Publication Link",
    salinity        => "Salinity",
    sample_body_site => "Sample Body Site",
    sample_body_subsite => "Sample Body Subsite",
    seq_status      => "GOLD Sequencing Status",
    seq_center      => "Sequencing Center",
    seq_method      => "Project Sequencing Method",
    specific_ecosystem => "Specific Ecosystem",
    sporulation     => "Sporulation",
    symbiotic_interaction => "Symbiotic Physical Interaction",
    symbiotic_rel   => "Symbiotic Relationship",
    symbiont        => "Symbiont Name",
    temp_range      => "Temperature Range",
    temp_optimum    => "Temperature Optimum",
    funding_program => 'Funding Program',
    type_strain     => 'Type Strain',
    mrn             => "Medical Record Number",
    date_collected  => "Sample Collection Date",    
    sample_oid      => "IMG Sample ID",
    project_info    => 'IMG Project ID',  
    contact_name    => 'Contact Name', 
    contact_email   => 'Contact Email', 
);

my %goldAttr2CVTable = (
    body_product    => "body_productcv",
    cell_arrangement => "cell_arrcv",
    cell_shape      => "cell_shapecv",
    diseases        => "diseasecv",
    ecosystem       => "cvecosystem",
    ecosystem_category => "cvecosystem_category",
    ecosystem_subtype => "cvecosystem_subtype",
    ecosystem_type  => "cvecosystem_type",
    energy_source   => "energy_sourcecv",
    habitat         => "habitatcv",
    iso_country     => "countrycv",
    metabolism      => "metabolismcv",
    motility        => "motilitycv",
    oxygen_req      => "oxygencv",
    phenotypes      => "phenotypecv",
    project_relevance => "relevancecv",
    salinity        => "salinitycv",
    sample_body_site=> "body_sitecv",
    additional_body_sample_site => "body_sitecv",
    sample_body_subsite => "body_subsitecv",
    specific_ecosystem => "cvspecific_ecosystem",
    sporulation     => "sporulationcv",
    temp_range      => "temp_rangecv",
    uncultured_type => "cvuncultured_type",
    funding_program => "FUNDING_PROGRAMCV",
);

my %goldAttr2UseDistinctData = (
    altitude        => 1,
    biotic_rel      => 1,
    gram_stain      => 1,
    host_name       => 1,
    host_gender     => 1,
    host_age        => 1,
    host_health     => 1,
    host_medication => 1,
    latitude        => 1,
    longitude       => 1,
    ph              => 1,
    pressure        => 1,
    symbiont        => 1,
    symbiotic_interaction => 1,
    symbiotic_rel   => 1,
    temp_optimum    => 1,
);


############################################################################
# getGoldSampleSingleAttr
############################################################################
sub getGoldSampleSingleAttr {
    my @attrs = (
                  'ncbi_project_id',       'host_ncbi_taxid',
                  'sample_site',           'date_collected',
                  'iso_country',           'comments',
                  'sampling_strategy',     'sample_isolation',
                  'sample_volume',         'gc_perc',
                  'est_biomass',           'est_diversity',
                  'temp',                  'temp_range',
                  'salinity',              'pressure',
                  'ph',                    'library_method',
                  'assembly_method',       'binning_method',
                  'est_size',              'units',
                  'contig_count',          'singlet_count',
                  'gene_count',            'host_name',
                  'host_gender',           'host_age',
                  'host_health_condition', 'geo_location',
                  'longitude',             'latitude',
                  'altitude',              'seq_status',
                  'mrn', 'date_collected', 'sample_oid', 'project_info'
    );

    return @attrs;
}

############################################################################
# getGoldSampleAttrDisplayName
############################################################################
sub getGoldSampleAttrDisplayName {
    my ($attr) = @_;

    # 3.3 hmpm - ken
    my %other = (
    mrn             => "Medical Record Number",
    date_collected  => "Sample Collection Date",
    contact_name => 'Contact Name', 
    contact_email=>'Contact Email', 
    funding_program=>'Funding Program',
    seq_status => 'GOLD Sequencing Status',
    );
    
    if(exists $other{$attr}) {
        return $other{$attr};
    }

    if ( $attr eq 'sample_site' ) {
        return 'Sample Site';
    } elsif ( $attr eq 'ncbi_project_id' ) {
        return 'Sample NCBI Project ID';
    } elsif ( $attr eq 'host_ncbi_taxid' ) {
        return 'Host NCBI Taxon ID';
    } elsif ( $attr eq 'date_collected' ) {
        return 'Date Collected';
    } elsif ( $attr eq 'iso_country' ) {
        return 'Isolation Country';
    } elsif ( $attr eq 'geo_location' ) {
        return 'Sample Geographic Location';
    } elsif ( $attr eq 'longitude' ) {
        return 'Longitude';
    } elsif ( $attr eq 'latitude' ) {
        return 'Latitude';
    } elsif ( $attr eq 'altitude' ) {
        return 'Altitude';
    } elsif ( $attr eq 'comments' ) {
        return 'Comments';
    } elsif ( $attr eq 'sampling_strategy' ) {
        return 'Sampling Strategy';
    } elsif ( $attr eq 'sample_isolation' ) {
        return 'Sample Isolation';
    } elsif ( $attr eq 'sample_volume' ) {
        return 'Sample Volume';
    } elsif ( $attr eq 'gc_perc' ) {
        return 'GC Percent';
    } elsif ( $attr eq 'sample_body_site' ) {
        return 'Body Site';
    } elsif ( $attr eq 'est_biomass' ) {
        return 'Biomass';
    } elsif ( $attr eq 'est_diversity' ) {
        return 'Diversity';
    } elsif ( $attr eq 'temp' ) {
        return 'Temperature';
    } elsif ( $attr eq 'temp_range' ) {
        return 'Temperature Range';
    } elsif ( $attr eq 'salinity' ) {
        return 'Salinity';
    } elsif ( $attr eq 'pressure' ) {
        return 'Pressure';
    } elsif ( $attr eq 'ph' ) {
        return 'pH';
    } elsif ( $attr eq 'library_method' ) {
        return 'Sample Library Method';
    } elsif ( $attr eq 'assembly_method' ) {
        return 'Sample Assembly Method';
    } elsif ( $attr eq 'binning_method' ) {
        return 'Sample Binning Method';
    } elsif ( $attr eq 'est_size' ) {
        return 'Estimated Size';
    } elsif ( $attr eq 'units' ) {
        return 'Units';
    } elsif ( $attr eq 'contig_count' ) {
        return 'Contig Count';
    } elsif ( $attr eq 'singlet_count' ) {
        return 'Singlet Count';
    } elsif ( $attr eq 'gene_count' ) {
        return 'Gene Count';
    } elsif ( $attr eq 'host_name' ) {
        return 'Host Name';
    } elsif ( $attr eq 'host_gender' ) {
        return 'Host Gender';
    } elsif ( $attr eq 'host_age' ) {
        return 'Host Age';
    } elsif ( $attr eq 'host_health_condition' ) {
        return 'Host Health Condition';
    } elsif($attr eq 'sample_oid') {
        return 'IMG Sample ID';
    } elsif($attr eq 'project_info') {
        return 'IMG Project ID'
    }

    return '';
}

############################################################################
# db_findMaxID - find the max ID of a table
############################################################################
sub db_findMaxID {
    my ( $dbh, $table_name, $attr_name ) = @_;

    # SQL statement
    my $sql = "select max($attr_name) from $table_name";

    my $cur = execSql( $dbh, $sql, $verbose );

    my $max_id = 0;
    for ( ; ; ) {
        my ($val) = $cur->fetchrow();
        last if !$val;

        # set max ID
        $max_id = $val;
    }

    return $max_id;
}

############################################################################
# db_findID - find ID given an attribute value
############################################################################
sub db_findID {
    my ( $dbh, $table_name, $id_name, $attr_name, $attr_val, $cond ) = @_;

    # SQL statement
    my $sql = "select $id_name from $table_name where $attr_name = ? ";
    if ( $cond && length($cond) > 0 ) {

        #append condition
        $sql .= " and " . $cond;
    }

    my $cur = execSql( $dbh, $sql, $verbose, $attr_val );

    my $return_id = -1;
    for ( ; ; ) {
        my ($val) = $cur->fetchrow();
        last if !$val;

        $return_id = $val;
    }

    $cur->finish();
    return $return_id;
}

############################################################################
# db_findVal - find attribute value given an ID
############################################################################
sub db_findVal {
    my ( $dbh, $table_name, $id_name, $id_val, $attr_name, $cond ) = @_;

    # SQL statement
    my $sql = "select $attr_name from $table_name where $id_name = ?";
    if ( $cond && length($cond) > 0 ) {
        #append condition
        $sql .= " and " . $cond;
    }
    #print "db_findVal() sql=$sql id_val=$id_val<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose, $id_val );

    my $return_val = "";
    for ( ; ; ) {
        my ($val) = $cur->fetchrow();
        last if !$val;

        $return_val = $val;
    }
    #$cur->finish();

    return $return_val;
}

############################################################################
# db_findSetVal - find set-valued attribute value given an ID
############################################################################
sub db_findSetVal {
    my ( $dbh, $table_name, $id_name, $id_val, $attr_name, $cond ) = @_;

    # SQL statement
    my $sql =
        "select $id_name, $attr_name from $table_name "
      . "where $id_name = ?";
    if ( $cond && length($cond) > 0 ) {

        #append condition
        $sql .= " and " . $cond;
    }

    my $cur = execSql( $dbh, $sql, $verbose , $id_val);

    my @vals = ();

    for ( ; ; ) {
        my ( $id2, $val ) = $cur->fetchrow();
        last if !$id2;

        if ( !blankStr($val) ) {
            push @vals, ($val);
        }
    }

    #$cur->finish();
    return @vals;
}

############################################################################
# db_findCount - find count given a table name and a condition
############################################################################
sub db_findCount {
    my ( $dbh, $table_name, $cond, @binds ) = @_;

    # SQL statement
    my $sql = "select count(*) from $table_name";
    if ( $cond && length($cond) > 0 ) {

        #append condition
        $sql .= " where " . $cond;
    }

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $return_cnt = 0;
    for ( ; ; ) {
        my ($val) = $cur->fetchrow();
        last if !$val;

        $return_cnt = $val;
    }

    #$cur->finish();
    return $return_cnt;
}

############################################################################
# db_getValues - execute a query to get set values
############################################################################
sub db_getValues {
    my ( $dbh, $sql ) = @_;

    my $cur  = execSql( $dbh, $sql, $verbose );
    my @vals = ();

    for ( ; ; ) {
        my ( $id, $val ) = $cur->fetchrow();
        last if !$id;

        if ( !blankStr($val) ) {
            push @vals, ("$id\t$val");
        }
    }

    $cur->finish();
    return @vals;
}

############################################################################
# db_getValues2 - execute a query to get set values
#                 (return values in a string)
############################################################################
sub db_getValues2 {
    my ( $dbh, $sql, $delim, @binds ) = @_;

    if ( blankStr($delim) ) {
        $delim = "; ";
    }

    my $cur  = execSql( $dbh, $sql, $verbose, @binds );
    my $vals = "";

    for ( ; ; ) {
        my ( $id, $val ) = $cur->fetchrow();
        last if !$id;

        if ( !blankStr($val) ) {
            if ( length($vals) == 0 ) {
                $vals = $val;
            } else {
                $vals .= $delim . $val;
            }
        }
    }

    #$cur->finish();

    return $vals;
}

############################################################################
# db_getLineage - get lineage for a taxon
############################################################################
sub db_getLineage {
    my ( $dbh, $taxon_oid ) = @_;

    my ($rclause) = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my $sql = qq{
      select tx.taxon_oid, 
         tx.domain, tx.phylum, tx.ir_class, tx.ir_order, 
         tx.family, tx.genus, tx.species, tx.strain
	     from taxon tx
	     where tx.taxon_oid = ?
         $rclause
         $imgClause
	 };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my %lineage;

    my ( $id,     $domain, $phylum,  $ir_class, $ir_order,
         $family, $genus,  $species, $strain
      )
      = $cur->fetchrow();
    $cur->finish();

    $lineage{'domain'}   = $domain;
    $lineage{'phylum'}   = $phylum;
    $lineage{'ir_class'} = $ir_class;
    $lineage{'ir_order'} = $ir_order;
    $lineage{'family'}   = $family;
    $lineage{'genus'}    = $genus;
    $lineage{'species'}  = $species;
    $lineage{'strain'}   = $strain;
    $lineage{'lineage'}  =
      "$domain;$phylum;$ir_class;$ir_order;$family;$genus;$species";

    return %lineage;
}


############################################################################
# db_getImgGroup - get img_group in the CONTACT table
# (obsolete)
############################################################################
sub db_getImgGroup {
    my ($contact_oid) = @_;

    my $dbh = dbLogin();
    my $sql =
        "select count(*) from user_tab_columns "
      . "where table_name = 'CONTACT' and column_name = 'IMG_GROUP'";
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    if ( !$cnt || $cnt == 0 ) {
        #$dbh->disconnect();
        return "";
    }

    $sql = "select img_group from contact where contact_oid = ?";
    $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my ($grp) = $cur->fetchrow();
    $cur->finish();
    #$dbh->disconnect();

    if ( !$grp ) {
        return "";
    }

    return $grp;
}

############################################################################
# db_getImgGroups - get img_group for contact
############################################################################
sub db_getImgGroups {
    my ($contact_oid) = @_;

    #    my $dbh = dbLogin();
    my $dbh = connectGoldDatabase();
    my $sql = qq{
	select cig.img_group, g.group_name
	    from contact_img_groups cig, img_group g
	    where cig.contact_oid = ?
	    and cig.img_group = g.group_id
	    order by 2
	};
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my @img_groups = ();
    for ( ; ; ) {
        my ( $g_id, $g_name ) = $cur->fetchrow();
        last if !$g_id;

        my $group = "$g_id\t$g_name";
        push @img_groups, ($group);
    }
    $cur->finish();
    #$dbh->disconnect();

    return @img_groups;
}

############################################################################
# db_isPublicUser - is public?
############################################################################
sub db_isPublicUser {
    my ($contact_oid) = @_;

    if ( !$contact_oid ) {
        return 1;
    }

    my $dbh = dbLogin();
    my $sql = "select username from contact where contact_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my ($uname) = $cur->fetchrow();
    $cur->finish();
    #$dbh->disconnect();

    if ( !$uname ) {
        return 1;
    }
    if ( lc($uname) eq 'public' ) {
        return 1;
    }

    return 0;
}

############################################################################
# db_sqlTrans - perform an SQL transaction
############################################################################
sub db_sqlTrans {
    my ($sqlList_ref) = @_;

    # login
    my $dbh = dbLogin();
    $dbh->{AutoCommit} = 0;

    my $last_sql = 0;

    # perform database update
    eval {
        for my $sql (@$sqlList_ref)
        {
            $last_sql++;
            execSql( $dbh, $sql, $verbose );
        }
    };

    if ($@) {
        $dbh->rollback();
        #$dbh->disconnect();
        return $last_sql;
    }

    $dbh->commit();
    #$dbh->disconnect();

    return 0;
}

############################################################################
# doesTableExist
############################################################################
sub doesTableExist {
    my ($table_name) = @_;

    $table_name = uc($table_name);

    my $dbh = dbLogin();
    my $cnt = db_findCount( $dbh, "user_tables", "table_name = '$table_name'" );
    #$dbh->disconnect();

    return $cnt;
}

#############################################################################
# getOraInClause
#############################################################################
sub getOraInClause {
    my ( $attr, $a_ref ) = @_;

    my $max_count = 1000;
    my $cl        = "";
    if ( scalar(@$a_ref) == 0 ) {
        return $cl;
    }

    if ( scalar(@$a_ref) > $max_count ) {
        $cl = "(";
    }

    my $cnt = 0;
    for my $i (@$a_ref) {
        if ( $cnt >= $max_count ) {
            $cl .= ") or ";
            $cnt = 0;
        }
        if ( $cnt == 0 ) {
            $cl .= "$attr in (" . $i;
        } else {
            $cl .= ", " . $i;
        }

        $cnt++;
    }

    $cl .= ")";

    if ( scalar(@$a_ref) > $max_count ) {
        $cl .= ")";
    }

    return $cl;
}

#############################################################################
# checkECNumber - check EC numbers
#############################################################################
sub checkECNumber {
    my ($input_s) = @_;

    my $res = "";
    $input_s =~ s/;/ /g;    # replace ; with space
    my @ecs = split( / /, $input_s );

    for my $k (@ecs) {

        # skip blanks
        if ( blankStr($k) ) {
            next;
        }

        # check EC number (e.g., EC:1.2.3.4 or EC:1.2.-.-)
        my ( $k1, $k2 ) = split( /\:/, $k );
        if ( $k1 ne 'EC' ) {
            $res = "Incorrect EC Number ($k does not start with 'EC:')";
            return $res;
        }

        my @ecs = split( /\./, $k2 );
        if ( scalar(@ecs) < 4 ) {
            my $n0 = scalar(@ecs);
            if ( $ecs[ $n0 - 1 ] eq '-' ) {

                # this is ok
            } else {
                $res =
"Incomplete EC Number ($k does not contain 4 numbers or ends with '-')";
                return $res;
            }
        } elsif ( scalar(@ecs) != 4 ) {
            $res = "Incorrect EC Number ($k contains too many components)";
            return $res;
        }

        for my $j (@ecs) {
            if ( $j eq '-' ) {
                next;
            } elsif ( isInt($j) ) {
                if ( $j <= 0 ) {
                    $res =
"Incorrect EC Number ($k contains incorrect component '$j')";
                    return $res;
                }
            } else {
                $res =
                  "Incorrect EC Number ($k contains incorrect component '$j')";
                return $res;
            }
        }
    }

    return $res;
}

#############################################################################
# checkPubmedId - check pubmed id
#############################################################################
sub checkPubmedId {
    my ($input_s) = @_;

    my $res = "";
    $input_s =~ s/;/ /g;    # replace ; with space
    my @ids = split( / /, $input_s );

    for my $k (@ids) {

        # skip blanks
        if ( blankStr($k) ) {
            next;
        }

        # --es 07/31/2007 Some Pubmed's are not integers.
        #if ( ! isInt($k) ) {
        #    $res = "Incorrect PUBMED ID: $k (must be an integer)";
        #    return $res;
        #}
    }

    return $res;
}


############################################################################
# connectGoldDatabase
#
# $isAjaxCall - connection via ajax call - send error back to ajax eg login page
# otherwise the ui just hangs
############################################################################
sub connectGoldDatabase {
    my ($isAjaxCall) = @_;
    
    # move to new location
    return WebUtil::dbGoldLogin($isAjaxCall);
    
}

############################################################################
# getGoldSingleAttr
############################################################################
sub getGoldSingleAttr {
    return @goldSingleAttrs;
}

############################################################################
# isGoldSetAttr
############################################################################
sub isGoldSingleAttr {
    my ($attr) = @_;
        
    return WebUtil::inArray($attr, @goldSingleAttrs);
}

############################################################################
# getGoldSetAttr
############################################################################
sub getGoldSetAttr {
    return keys(%goldSetAttr2TableName);
}

############################################################################
# isGoldSetAttr
############################################################################
sub isGoldSetAttr {
    my ($attr) = @_;
        
    return $goldSetAttr2TableName{$attr};
}

############################################################################
# getGoldCondAttr
############################################################################
sub getGoldCondAttr {
    return @goldCondAttrs;
}

############################################################################
# getGoldAttrDisplay
############################################################################
sub getGoldAttrDisplay {
    return %goldAttr2Display;
}

############################################################################
# getGoldAttrDisplayName
############################################################################
sub getGoldAttrDisplayName {
    my ($attr) = @_;

    my $val = $goldAttr2Display{$attr};
    return $attr if ($val eq '');
    
    return $val;
}

############################################################################
# getGoldAttrSection
############################################################################
sub getGoldAttrSection {
    my ($attr) = @_;

    if (    $attr eq 'oxygen_req'
         || $attr eq 'isolation'
         || $attr eq 'gram_stain'
         || $attr eq 'host_name'
         || $attr eq 'host_gender'
         || $attr eq 'host_health'
         || $attr eq 'host_medication'
         || $attr eq 'sample_body_site'
         || $attr eq 'sample_body_subsite'
         || $attr eq 'body_product'
         || $attr eq 'additional_body_sample_site'
         || $attr eq 'motility'
         || $attr eq 'sporulation'
         || $attr eq 'temp_range'
         || $attr eq 'temp_optimum'
         || $attr eq 'salinity'
         || $attr eq 'pressure'
         || $attr eq 'ph'
         || $attr eq 'library_method'
         || $attr eq 'assembly_method'
         || $attr eq 'phenotypes'
         || $attr eq 'diseases'
         || $attr eq 'project_relevance'
         || $attr eq 'habitat'
         || $attr eq 'ecosystem'
         || $attr eq 'ecosystem_category'
         || $attr eq 'ecosystem_type'
         || $attr eq 'ecosystem_subtype'
         || $attr eq 'specific_ecosystem'
         || $attr eq 'cell_arrangement'
         || $attr eq 'cell_shape'
         || $attr eq 'energy_source'
         || $attr eq 'metabolism'
         || $attr eq 'biotic_rel'
         || $attr eq 'symbiotic_interaction'
         || $attr eq 'symbiotic_rel'
         || $attr eq 'symbiont'
         || $attr eq 'type_strain' )
    {
        return 'Metadata';
    } elsif (    $attr eq 'gold_stamp_id'
              || $attr eq 'ncbi_project_id'
              || $attr eq 'pub_journal'
              || $attr eq 'pub_vol'
              || $attr eq 'pub_link'
              || $attr eq 'iso_country'
              || $attr eq 'iso_year'
              || $attr eq 'geo_location'
              || $attr eq 'loc_coord'
              || $attr eq 'longitude'
              || $attr eq 'latitude'
              || $attr eq 'altitude'
              || $attr eq 'cultured'        
              || $attr eq 'culture_type'    
              || $attr eq 'uncultured_type' 
              || $attr eq 'seq_status'
              || $attr eq 'seq_center'
              || $attr eq 'seq_method'
              || $attr eq 'funding_agency' )
    {
        return 'Project Information';
    }

    return '';
}

############################################################################
# getGoldSetAttrTableName
############################################################################
sub getGoldSetAttrTableName {
    my ($attr) = @_;

    return $goldSetAttr2TableName{$attr};
}

############################################################################
# getGoldSetAttrTableNameAlias
############################################################################
sub getGoldSetAttrTableNameAlias {
    my ($attr) = @_;

    return $goldSetAttr2TableNameAlias{$attr};
}

############################################################################
# getGoldSetAttrSQL
############################################################################
sub getGoldSetAttrSQL {
    my ( $attr, $cond, $isPoidOnly ) = @_;

    my $sql = "";
    if ( $attr eq 'funding_agency' || $attr eq 'seq_center') {
        my $link_type_val = '';
        if ( $attr eq 'funding_agency' ) {
            $link_type_val = 'Funding';
        } elsif ( $attr eq 'seq_center' ) {
            $link_type_val = 'Seq Center';
        }
        
        if ($isPoidOnly) {
            $sql = "select project_oid ";
        }
        else {
            $sql = "select project_oid, db_name ";            
        }
        $sql .= "from project_info_data_links ";
        $sql .= "where link_type = '$link_type_val' ";
        if ($cond) {
            $sql .= " and " . $cond;
        }
    } else {
        my $table_name = getGoldSetAttrTableName($attr);
        if ($isPoidOnly) {
            $sql = "select project_oid ";
        }
        else {
            $sql = "select project_oid, $attr ";            
        }
        $sql .= "from $table_name ";
        if ($cond) {
            $sql .= " where " . $cond;
        }
    }

    return $sql;
}

############################################################################
# getGoldSingleAttrSQL
############################################################################
sub getGoldSingleAttrSQL {
    my ( $cond ) = @_;

    my @attrs1 = getGoldSingleAttr();
    my $sql = "select p.project_oid";
    for my $attr1 (@attrs1) {
        $sql .= ", p." . $attr1;
    }
    $sql .= " from project_info p ";
    if ($cond) {
        $sql .= " where " . $cond;
    }

    return $sql;
}

############################################################################
# getGoldAttrCVQuery
############################################################################
sub getGoldAttrCVQuery {
    my ($attr) = @_;

    if ($attr) {
        if ($goldAttr2CVTable{$attr}) {
            my $cvTable = $goldAttr2CVTable{$attr};
            return "select cv_term from $cvTable order by cv_term";
        }
        if ($goldAttr2UseDistinctData{$attr}) {
            return "select distinct $attr from project_info order by 1";
        }        
    }
    
    return '';
#    return $goldAttrCV2Query{$attr};
}

############################################################################
# getMetadataForAttrs
#
# use NCBI gbk project IDs or img submission_ids or gold ids or taxon oids
# to find metadata from GOLD
############################################################################
sub getMetadataForAttrs {
    my ($taxon_oids_ref, $tOids2GbkPids_ref, $tOids2SubmissionIds_ref,
	$tOids2GoldIds_ref, @metaAttrs ) = @_;
    my @taxon_oids = @$taxon_oids_ref;
    my @ncbi_pids = values(%$tOids2GbkPids_ref);
    my @submission_ids = values(%$tOids2SubmissionIds_ref);
    my @gold_ids = values(%$tOids2GoldIds_ref);

    my %gbkPid2tOids = convetKey2Value($tOids2GbkPids_ref);
    my %submissionId2tOids = convetKey2Value($tOids2SubmissionIds_ref);
    my %goldId2tOids = convetKey2Value($tOids2GoldIds_ref);

    my $dbh = connectGoldDatabase();

    my $tableName = 'gtt_num_id';
    my $createSql = qq{
        ID      NUMBER(16)
    };
    OracleUtil::createTempTableReady( $dbh, $tableName, $createSql);
    $tableName = 'gtt_num_id1';
    OracleUtil::createTempTableReady( $dbh, $tableName, $createSql);
    $tableName = 'gtt_num_id2';
    $createSql = qq{
        ID      NUMBER(38)
    };

    #used for gold ids, temp blocked due to error thrown
    #OracleUtil::createTempTableReady( $dbh, $tableName, $createSql);
    #$tableName = 'gtt_func_id';
    #$createSql = qq{
    #    ID      VARCHAR2(50)
    #};
    #OracleUtil::createTempTableReady( $dbh, $tableName, $createSql);
    #$tableName = 'gtt_func_id1';
    #OracleUtil::createTempTableReady( $dbh, $tableName, $createSql);

    # start to find corresponding project_oid through project_info table
    my $pidClause = OracleUtil::getIdClause($dbh, 'gtt_num_id', 'ncbi_project_id', \@ncbi_pids);
    my $txClause = OracleUtil::getIdClause($dbh, 'gtt_num_id1', 'img_oid', \@taxon_oids);
    my $allClause = '';
    if ($pidClause ne '' || $txClause ne '') {
        $allClause = 'and ( ';
        $allClause .= $pidClause;
        $allClause .= ' or ' if ($pidClause ne '' && $txClause ne '');
        $allClause .= $txClause;
        $allClause .= ' )';
    }
    my $sql = qq{
        select project_oid, img_oid, ncbi_project_id, 
	       gold_stamp_id, gold_id_old
        from project_info
        where 1 = 1
        $allClause
    };
    #print "getMetadataForAttrs ncbi_project_id \$sql: $sql<br/>\n"; 
    my $cur = execSql( $dbh, $sql, $verbose );

    my %tOids2Poids = {};
    my %tOids2Recs = {};
    for ( ; ; ) {
        my ($project_oid, $img_oid, $ncbi_pid, 
	    $gold_stamp_id, $gold_id_old) = $cur->fetchrow();
        last if !$project_oid;

        my $r = "$project_oid\t";
        $r .= "$img_oid\t";
        $r .= "$ncbi_pid\t";
        $r .= "$gold_stamp_id\t";
        $r .= "$gold_id_old\t";

        my @taxonOids = ();

	# first look at img oid, then ncbi id
	if ($img_oid ne '') {
            if ($tOids2GbkPids_ref->{$img_oid} eq '') {
                # at situation when $ncbi_pid is ''
                push(@taxonOids, $img_oid);
	    }
            if ($ncbi_pid ne ''
                && $tOids2GbkPids_ref->{$img_oid} eq $ncbi_pid) {
                push(@taxonOids, $img_oid);
            } 
	} else {
            if ($ncbi_pid ne '') {
                my $tOids_str = $gbkPid2tOids{$ncbi_pid}; 
                my @tOids = split( /\t/, $tOids_str );
                if (scalar(@tOids) > 0) { 
                    push(@taxonOids, @tOids);
                } 
            } 
	}

        if ($project_oid ne '' && scalar(@taxonOids) > 0) {
            addPoidToHash
		(\@taxonOids, $project_oid, \%tOids2Poids, $r, 
		 \%tOids2Recs, "ncbi_project_id in project_info table",
		 $tOids2GbkPids_ref, $tOids2SubmissionIds_ref, 
		 $tOids2GoldIds_ref);
        }
    }
    $cur->finish();
    
    # start to find corresponding project_oid through env_sample table
    my @tOidsNotFound = ();
    my @pidsNotFound = ();
    foreach my $tOid (@taxon_oids) {
    	my $p_oid = $tOids2Poids{$tOid};
    	if ($p_oid eq '') {
	    push(@tOidsNotFound, $tOid);
	    my $ncbi_pid = $tOids2GbkPids_ref->{$tOid};
            push(@pidsNotFound, $ncbi_pid) if ($ncbi_pid ne '');
    	}
    }

    if (scalar(@tOidsNotFound) > 0) {
        $pidClause = OracleUtil::getIdClause($dbh, 'gtt_num_id', 'ncbi_project_id', \@pidsNotFound);
        $txClause = OracleUtil::getIdClause($dbh, 'gtt_num_id1', 'img_oid', \@tOidsNotFound);
    	$allClause = '';
    	if ($pidClause ne '' || $txClause ne '') {
    	    $allClause = 'and ( ';
    	    $allClause .= $pidClause;
    	    $allClause .= ' or ' if ($pidClause ne '' && $txClause ne '');
    	    $allClause .= $txClause;
    	    $allClause .= ' )';
    	}
    	$sql = qq{
    	    select project_info, img_oid, ncbi_project_id
    	    from env_sample
    	    where 1 = 1
    	    $allClause
    	};
    	#print "getMetadataForAttrs env_sample \$sql: $sql<br/>\n";
        $cur = execSql( $dbh, $sql, $verbose );

	for ( ; ; ) {
	    my ($project_oid, $img_oid, $ncbi_pid) = $cur->fetchrow();
	    last if !$project_oid;
	    
	    my $r = "$project_oid\t";
	    $r .= "$img_oid\t";
	    $r .= "$ncbi_pid\t";

	    my @taxonOids = ();
	    if ($ncbi_pid ne '') {
		#try to take advantage of $img_oid to avoid loop
		if ($img_oid ne '' 
		    && $tOids2GbkPids_ref->{$img_oid} eq $ncbi_pid) {
		    push(@taxonOids, $img_oid);
		}
		else {
		    my $tOids_str = $gbkPid2tOids{$ncbi_pid};
		    my @tOids = split( /\t/, $tOids_str );
		    if (scalar(@tOids) > 0) {
			push(@taxonOids, @tOids);
		    }               
		}
	    }
	    else {
		if ($img_oid ne '' && $tOids2GbkPids_ref->{$img_oid} eq '') {
		    push(@taxonOids, $img_oid);
		}
	    }
	    
	    if ($project_oid ne '' && scalar(@taxonOids) > 0) {
		addPoidToHash
		    (\@taxonOids, $project_oid, \%tOids2Poids, $r, 
		     \%tOids2Recs, "ncbi_project_id in env_sample table",
		     $tOids2GbkPids_ref, $tOids2SubmissionIds_ref, 
		     $tOids2GoldIds_ref);
	    }	
	}
        $cur->finish();
	
	# start to find corresponding project_oid through submission table
	my @tOidsNotFound1 = ();
	my @submissionIdsNotFound = ();
	foreach my $tOid (@tOidsNotFound) {
	    my $p_oid = $tOids2Poids{$tOid};
	    if ($p_oid eq '') {
		push(@tOidsNotFound1, $tOid);
		my $submission_id = $tOids2SubmissionIds_ref->{$tOid};
		push(@submissionIdsNotFound, $submission_id)
		    if ($submission_id ne '');
	    }
	}
	
	if (scalar(@tOidsNotFound1) > 0) {
	    my $submissionIdClause = OracleUtil::getIdClause($dbh, 'gtt_num_id2', 'submission_id', \@submissionIdsNotFound);
	    $txClause = OracleUtil::getIdClause($dbh, 'gtt_num_id1', 'img_taxon_oid', \@tOidsNotFound1);
	    $allClause = '';
	    if ($submissionIdClause ne '' || $txClause ne '') {
    		$allClause = 'and ( ';
    		$allClause .= $submissionIdClause;
    		$allClause .= ' or '
		    if ($submissionIdClause ne '' && $txClause ne '');
        		$allClause .= $txClause;
        		$allClause .= ' )';
    	    }
	    $sql = qq{
		select project_info, img_taxon_oid, submission_id
	        from submission
		where 1 = 1
		$allClause
	    };
	    #print "getMetadataForAttrs submission \$sql: $sql<br/>\n";
	    $cur = execSql( $dbh, $sql, $verbose );
	    
	    for ( ; ; ) {
		my ($project_oid, $img_oid, $submission_id) = $cur->fetchrow();
		last if !$project_oid;
		
		my $r = "$project_oid\t";
		$r .= "$img_oid\t";
		$r .= "$submission_id\t";
		
		my @taxonOids = ();
		if ($submission_id ne '') {
		    # try to take advantage of $img_oid to avoid loop
		    if ($img_oid ne ''
			&& $tOids2SubmissionIds_ref->{$img_oid} 
			eq $submission_id) {
			push(@taxonOids, $img_oid);
		    }
		    else {
			my $tOids_str = $submissionId2tOids{$submission_id};
			my @tOids = split( /\t/, $tOids_str );
			if (scalar(@tOids) > 0) {
			    push(@taxonOids, @tOids);                   
			}               
		    }
		}
		else {
		    if ($img_oid ne '' 
			&& $tOids2SubmissionIds_ref->{$img_oid} eq '') {
			push(@taxonOids, $img_oid);
		    }
		}
		
		if ($project_oid ne '' && scalar(@taxonOids) > 0) {
		    addPoidToHash
			(\@taxonOids, $project_oid, \%tOids2Poids, $r, 
			 \%tOids2Recs, "submission_id in submission table",
			 $tOids2GbkPids_ref, $tOids2SubmissionIds_ref,
			 $tOids2GoldIds_ref);
		}
	    }
            $cur->finish();

=pod
    # start to find corresponding project_oid through two gold ids in project_info table
    # blocked due to encountering error "*** *** glibc detected *** /usr/local/bin/perl: double free or corruption (fasttop)"
    # that's perl's internal error, happened both here and when merged with previous ncbi_pid sql
    # when perl version is changed, unblock it to see whether it's OK or not

            my @tOidsNotFound2 = ();
            my @goldIdsNotFound = ();
	    foreach my $tOid (@tOidsNotFound1) {
		my $p_oid = $tOids2Poids{$tOid};
		if ($p_oid eq '') {
		    push(@tOidsNotFound2, $tOid);
		    my $gold_id = $tOids2GoldIds_ref->{$tOid};
		    push(@goldIdsNotFound, $gold_id) if ($gold_id ne '');
		}
	    }
	    
	    if (scalar(@tOidsNotFound2) > 0) {
		my $goldStampIdClause = '';
		$goldStampIdClause = OracleUtil::getIdClause($dbh, 'gtt_func_id', 'gold_stamp_id', \@gold_ids);

		my $goldOldIdClause = '';
		$goldOldIdClause = OracleUtil::getIdClause($dbh, 'gtt_func_id1', 'gold_id_old', \@gold_ids);

		$allClause = '';
		if ($goldStampIdClause ne '' 
		    || $goldOldIdClause ne '' 
		    || $txClause ne '') {
		    $allClause = 'and ( ';
		    $allClause .= $goldStampIdClause;
		    $allClause .= ' or '
			if ( $goldStampIdClause ne '' 
			     && $goldOldIdClause ne '');
		    $allClause .= $goldOldIdClause;
		    #$allClause .= ' or ' 
		    if (($goldStampIdClause ne '' 
			 || $goldOldIdClause ne '') && $txClause ne '');
		    #$allClause .= $txClause;
		    $allClause .= ' )';
		}

		my $sql = qq{
		    select project_oid, img_oid, ncbi_project_id,
		           gold_stamp_id, gold_id_old
		    from project_info
		    where 1 = 1
		    $allClause
		};
		#print "getMetadataForAttrs gold_id \$sql: $sql<br/>\n";
		
		$cur = execSql( $dbh, $sql, $verbose );
		
		for ( ; ; ) {
                    my ($project_oid, $img_oid, $ncbi_pid, 
			$gold_stamp_id, $gold_id_old) = $cur->fetchrow();
		    last if !$project_oid;
		    
		    my $r = "$project_oid\t";
		    $r .= "$img_oid\t";
		    $r .= "$ncbi_pid\t";
		    $r .= "$gold_stamp_id\t";
		    $r .= "$gold_id_old\t";
		    
                    my @taxonOids = ();
		    if ($gold_stamp_id ne '' || $gold_id_old ne '') {
			#try to take advantage of $img_oid to avoid loop
			if ($img_oid ne '' 
			    && ($tOids2GoldIds_ref->{$img_oid} eq $gold_stamp_id 
				|| $tOids2GoldIds_ref->{$img_oid} eq $gold_id_old)) {
			    push(@taxonOids, $img_oid);
			}
			else {
			    my $tOids_str = '';
			    $tOids_str .= $goldId2tOids{$gold_stamp_id} if ($gold_stamp_id ne '');
			    $tOids_str .= $goldId2tOids{$gold_id_old} if ($gold_id_old ne '');
			    my @tOids = split( /\t/, $tOids_str );
			    if (scalar(@tOids) > 0) {
				push(@taxonOids, @tOids);
			    }
			}
		    }
		    else {
			if ($img_oid ne '' && $tOids2GoldIds_ref->{$img_oid} eq '') {
			    push(@taxonOids, $img_oid);
			}
		    }
		    
		    if ($project_oid ne '' && scalar(@taxonOids) > 0) {
			addPoidToHash
			    (\@taxonOids, $project_oid, \%tOids2Poids, $r, \%tOids2Recs, 
			     "gold_stamp_id and gold_id_old in project_info table",
			     $tOids2GbkPids_ref, $tOids2SubmissionIds_ref,
			     $tOids2GoldIds_ref);
		    }
		}
		$cur->finish();	
            }   
=cut	            
}
    }

    my @project_oids = values(%tOids2Poids);
    @project_oids = grep { !/^$/ } @project_oids; #remove '' value
    my $poidClause = OracleUtil::getIdClause($dbh, 'gtt_num_id', 'project_oid', \@project_oids);

    # split metaAttrs into single and set pools
    my @singleMeta = ();
    my $singleMetaClause = '';
    my @setMeta = ();
    my %setMetaIdx = {};
    for (my $i = 0; $i < scalar(@metaAttrs); $i++) {
        my $attr = $metaAttrs[$i];
        if ( isGoldSingleAttr($attr) ) {
            push (@singleMeta, $attr);
            $singleMetaClause .= ", $attr";
        }
        else {
            push (@setMeta, $attr);
            $setMetaIdx{$attr} = $i;
        }
    }

    my %tOids2Meta = {};

    # get all single-valued at once
    if ($singleMetaClause ne '') {
        $sql = qq{
            select project_oid $singleMetaClause
            from project_info
            where $poidClause
        };
        #print "get all single-valued \$sql: $sql<br/>\n";
        $cur = execSql( $dbh, $sql, $verbose );

        my %poid2Vals = {};
        for ( ; ; ) {
	        my ( $p_oid, @vals ) = $cur->fetchrow();
	        last if !$p_oid;

            my $rec = '';
	        for ( my $i = 0; $i < scalar(@vals); $i++ ) {
	            $rec .= "$vals[$i]\t";
	        }
            $poid2Vals{$p_oid} = $rec;
        }
        my $dummyRec = '';
        foreach my $attr (@singleMeta) {
        	$dummyRec .= "\t";
        }
        foreach my $tOid (@taxon_oids) {
            my $p_oid = $tOids2Poids{$tOid};
            my $rec = '';
            if ($p_oid ne '') {
                $rec = $poid2Vals{$p_oid};            	
            }
            $rec = $dummyRec if ($rec eq '');
            $tOids2Meta{$tOid} = $rec;
        }
        $cur->finish();
    }

    # get set-valued one by one
    if (scalar(@setMeta) > 0) {
	    for my $attr (@setMeta) {
            $sql = getGoldSetAttrSQL( $attr, $poidClause );
            $sql .= ' order by project_oid ';
            #print "get set-valued \$sql: $sql<br/>\n";
    	    $cur = execSql( $dbh, $sql, $verbose );
	    
            my %poid2Vals = {};
    	    for ( ; ; ) {
        		my ( $p_oid, $val ) = $cur->fetchrow();
        		last if !$p_oid;
                
                if ($val ne '') {
                    my $vals = $poid2Vals{$p_oid};
                    if ($vals ne '') {
                        $poid2Vals{$p_oid} .= ", $val";
                    }
                    else {
                        $poid2Vals{$p_oid} = $val;                    	
                    }
                }
    	    }

            foreach my $tOid (@taxon_oids) {
            	my $p_oid = $tOids2Poids{$tOid};
                my $vals = $poid2Vals{$p_oid};
                my $idx = $setMetaIdx{$attr};
                if (scalar(@singleMeta) > 0) {
                    my $rec = $tOids2Meta{$tOid};
                    #print "before insert $vals at $idx for $p_oid into \$rec: $rec with length ". length($rec) ."<br/>\n" if ($tOid == 646311906);
                    $rec = insertIntoLine($vals, $rec, $idx);
                    #print "after insert at $idx \$rec: $rec with length ". length($rec) ."<br/>\n"  if ($tOid == 646311906);
                    $tOids2Meta{$tOid} = $rec;
                } else {
                    $tOids2Meta{$tOid} .= "$vals\t";
                }
            }
    	    $cur->finish();
    	}
    }

    #$dbh->disconnect();
    return %tOids2Meta;
}

sub convetKey2Value{
    my ($aHash_ref) = @_;

    my %newHash = {};
    foreach my $key ( keys %$aHash_ref ) {
        next if ($key eq '');
        my $value = $aHash_ref->{$key};
        if ($value ne '') {
        	$newHash{$value} .= "$key\t";
        }
    }    
    return %newHash;
}

sub insertIntoLine {
    my ($colVal, $line, $stopAtWhichTab, $toPrint) = @_;

    my $num = 0;
    my $offset = 0;
    my $idx = index($line, "\t", $offset);
    #print "\$num: $num\t\$offset: $offset\t\$idx: $idx\t<br/>\n" if ($toPrint);
    while ($idx != -1) {
        $num++;
        last if ($num == $stopAtWhichTab);
        $offset = $idx + 1;
        $idx = index($line, "\t", $offset);
        #print "\$num: $num\t\$offset: $offset\t\$idx: $idx\t<br/>\n" if ($toPrint);
    }
    #print "\$num: $num\t\$idx: $idx\t\$colVal: $colVal\t<br/>\n" if ($toPrint);
    if ($idx == -1 && $num <= $stopAtWhichTab) {
        my $diff = $stopAtWhichTab - $num;
        for (my $i = 0; $i < $diff; $i++) {
        	$line .= "\t";
        }
        $line .= "$colVal\t";
        #print "added $colVal\t at the end of line<br/>\n" if ($toPrint);
    }
    else {
        substr($line, $idx+1, 0) = "$colVal\t";    	
        #print "added $colVal\t at " .($idx+1)."<br/>\n" if ($toPrint);
    }

    return $line;
}

sub addPoidToHash {
    my ($taxonOids_ref, $project_oid, $tOids2Poids_ref, $r, 
	$tOids2Recs_ref, $throughMsg, $tOids2GbkPids_ref, 
	$tOids2SubmissionIds_ref, $tOids2GoldIds_ref) = @_;

    if (scalar(@$taxonOids_ref) > 0) {
        foreach my $tOid (@$taxonOids_ref) {
            my $existPoid = $tOids2Poids_ref->{$tOid};
            if ($existPoid ne '' && $existPoid eq $project_oid) {
                next;
            }
            elsif ($existPoid ne '' && $existPoid ne $project_oid) {
                my $gbk_pid_img = $tOids2GbkPids_ref->{$tOid};
                my $gold_id_img = $tOids2GoldIds_ref->{$tOid};
                my $submission_id_img = $tOids2SubmissionIds_ref->{$tOid};
                my $existRec = $tOids2Recs_ref->{$tOid};            	
            	if ($throughMsg =~ /project_info/i) {
		    my ($project_oid_exist, $img_oid_exist,
			$ncbi_pid_exist, $gold_stamp_id_exist,
			$gold_id_old_exist) = split( /\t/, $existRec );
                    my ($project_oid, $img_oid, $ncbi_pid,
			$gold_stamp_id, $gold_id_old) = split( /\t/, $r );
				    
		    if ($ncbi_pid eq $ncbi_pid_exist
			&& $gold_stamp_id eq $gold_stamp_id_exist 
			&& $gold_id_old eq $gold_id_old_exist) {
                        webLog("Through $throughMsg, taxon $tOid links to different project_OID: $existPoid and $project_oid, but with same ncbi_project_id $ncbi_pid, gold_stamp_id $gold_stamp_id and gold_id_old $gold_id_old, continue to use existing $existPoid\n");
		    }
		    else {
			if ($gbk_pid_img eq $ncbi_pid 
			    && $gbk_pid_img ne $ncbi_pid_exist) {
			    if ($project_oid ne '') {
				$tOids2Poids_ref->{$tOid} = $project_oid;
				$tOids2Recs_ref->{$tOid} = $r;
                                webLog("Through $throughMsg, taxon $tOid links to different project_OID: $existPoid and $project_oid, new ncbi_project_id $ncbi_pid same as IMG database, replace existing with new $project_oid\n");
			    }                  
			}
			elsif ( (($gold_id_img eq $gold_stamp_id
			       && $gold_id_img eq $gold_id_old)
			       && ($gold_id_img ne $gold_stamp_id_exist 
			        || $gold_id_img ne $gold_id_old_exist))
			       || (($gold_id_img eq $gold_stamp_id
			         || $gold_id_img eq $gold_id_old)
			       && !($gold_id_img eq $gold_stamp_id_exist
			         || $gold_id_img eq $gold_id_old_exist))) {
                            if ($project_oid ne '') {
                                $tOids2Poids_ref->{$tOid} = $project_oid;
                                $tOids2Recs_ref->{$tOid} = $r;
                                webLog("Through $throughMsg, taxon $tOid links to different project_OID: $existPoid and $project_oid, new gold_ids same as IMG database $gold_id_img, replace existing with new $project_oid\n");
                            }	                        
			}
			else {
                            webLog("Through $throughMsg, taxon $tOid found to have different project_OID: $existPoid and $project_oid, continue to use the existing $existPoid\n");	                    	
			}			    	
		    }            		
            	}
                elsif ($throughMsg =~ /env_sample/i) {
                    my ($project_oid_exist, $img_oid_exist,
			$ncbi_pid_exist) = split( /\t/, $existRec );
                    my ($project_oid, $img_oid, $ncbi_pid) = split( /\t/, $r );
		    
                    if ($ncbi_pid eq $ncbi_pid_exist) {
                        webLog("Through $throughMsg, taxon $tOid links to different project_OID: $existPoid and $project_oid, but with same ncbi_project_id $ncbi_pid, continue to use existing $existPoid\n");
                    }
                    else {
                        if ($gbk_pid_img eq $ncbi_pid 
			    && $gbk_pid_img ne $ncbi_pid_exist) {
                            if ($project_oid ne '') {
                                $tOids2Poids_ref->{$tOid} = $project_oid;
                                $tOids2Recs_ref->{$tOid} = $r;
                                webLog("Through $throughMsg, taxon $tOid links to different project_OID: $existPoid and $project_oid, new ncbi_project_id $ncbi_pid same as IMG database, replace existing with new $project_oid\n");
                            }
                        }
                        else {
                            webLog("Through $throughMsg, taxon $tOid found to have different project_OID: $existPoid and $project_oid, continue to use the existing $existPoid\n");
                        }
                    }               
                }
                elsif ($throughMsg =~ /submission/i) {
                    my ($project_oid_exist, $img_oid_exist,
			$submission_id_exist) = split( /\t/, $existRec );
                    my ($project_oid, $img_oid, 
			$submission_id) = split( /\t/, $r );

                    if ($submission_id eq $submission_id_exist) {
                        webLog("Through $throughMsg, taxon $tOid links to different project_OID: $existPoid and $project_oid, but with same submission_id $submission_id, continue to use existing $existPoid\n");
                    }
                    else {
                        if ($submission_id_img eq $submission_id
			    && $submission_id_img ne $submission_id_exist) {
                            if ($project_oid ne '') {
                                $tOids2Poids_ref->{$tOid} = $project_oid;
                                $tOids2Recs_ref->{$tOid} = $r;
                                webLog("Through $throughMsg, taxon $tOid links to different project_OID: $existPoid and $project_oid, new submission_id $submission_id same as IMG database, replace existing with new $project_oid\n");
                            }
                        }
                        else {
                            webLog("Through $throughMsg, taxon $tOid found to have different project_OID: $existPoid and $project_oid, continue to use the existing $existPoid\n");
                        }
                    }               
                }            	
            }
            else {
            	if ($project_oid ne '') {
                    $tOids2Poids_ref->{$tOid} = $project_oid;
                    $tOids2Recs_ref->{$tOid} = $r;
            	}
            }
        }
    }
}

# for validation purpose, currently not used
sub validateGold2Img {
    my ($tOid, $ncbi_pid, $gold_stamp_id, $gold_id_old, $img_oid,
	$tOids2GbkPids_ref, $tOids2SubmissionIds_ref, 
	$tOids2GoldIds_ref) = @_;

    my $gbk_pid_img = $tOids2GbkPids_ref->{$tOid};
    my $gold_id_img = $tOids2GoldIds_ref->{$tOid};

    if (($tOid ne '' || $img_oid ne '') 
	&& $tOid ne $img_oid) {
        webLog("Taxon OID $img_oid <<<>>> $tOid different: Gold $ncbi_pid, $gold_stamp_id or $gold_id_old, $img_oid <<>> IMG $gbk_pid_img, $gold_id_img, $tOid\n");
    }
    elsif (($ncbi_pid ne '' || $gbk_pid_img ne '') 
	   && $ncbi_pid ne $gbk_pid_img) {
        webLog("NCBI Project ID $ncbi_pid <<<>>> $gbk_pid_img different: Gold $ncbi_pid, $gold_stamp_id or $gold_id_old, $img_oid <<>> IMG $gbk_pid_img, $gold_id_img, $tOid\n");
    }
    elsif (($gold_stamp_id ne '' || $gold_id_old ne '' || $gold_id_img ne '') 
	   && $gold_stamp_id ne $gold_id_img && $gold_id_old ne $gold_id_img) {
        webLog("Gold ID $gold_stamp_id or $gold_id_old <<<>>> $gold_id_img different: Gold $ncbi_pid, $gold_stamp_id or $gold_id_old, $img_oid <<>> IMG $gbk_pid_img, $gold_id_img, $tOid\n");
    }
}



##########################################################################
# getCategoryGoldIds
##########################################################################
sub getCategoryGoldIds {
    my ( $attr, $attr_val ) = @_;

    my @gold_ids = ();
    my $sql      =
        "select p.project_oid, p.gold_stamp_id, p.gold_id_old "
      . "from project_info p";

    if ( isGoldSingleAttr($attr) ) {
        # single valued
        $sql .= " where p.$attr = ? ";
    } elsif ( isGoldSetAttr($attr) ) {
        # set valued
        $sql .= " where p.project_oid in ( "
          . getGoldSetAttrSQL($attr, '', 1)
          . " where $attr = ? )";
    } else {
        return @gold_ids;
    }

    my $dbh = connectGoldDatabase();
    my $cur = execSql( $dbh, $sql, $verbose, $attr_val );
    for ( ; ; ) {
        my ( $id, $gold_id, $old_gold_id ) = $cur->fetchrow();
        last if !$id;

        if ( ! blankStr($gold_id) && ! WebUtil::inArray( $gold_id, @gold_ids ) ) {
            push @gold_ids, ($gold_id);
        }
        if ( ! blankStr($old_gold_id) && ! WebUtil::inArray( $old_gold_id, @gold_ids ) ) {
            push @gold_ids, ($old_gold_id);
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    return @gold_ids;
}

##########################################################################
# getQueryGoldIds
#
# (use param to get query condition)
##########################################################################
sub getQueryGoldIds {
    my @gold_ids = ();

    my @cond_attrs   = getGoldCondAttr();

    my $cond = "";
    for my $attr (@cond_attrs) {
        if ( isGoldSingleAttr($attr) ) {
            # single-valued
            my @vals = param($attr);
            if ( scalar(@vals) > 0 ) {
                my $cond1 = "";
                for my $val (@vals) {
                    $val =~ s/'/''/g;    # replace ' with ''
                    if ( blankStr($cond1) ) {
                        $cond1 = "p.$attr in ('$val'";
                    } else {
                        $cond1 .= ", '" . $val . "'";
                    }
                }    # end for val

                if ( !blankStr($cond1) ) {
                    $cond1 .= ")";
                    if ( blankStr($cond) ) {
                        $cond = " where " . $cond1;
                    } else {
                        $cond .= " and $cond1";
                    }
                }
            }
        } else {

            # set-valued
            my @vals = param($attr);
            if ( scalar(@vals) > 0 ) {
                my $cond1 = "";
                for my $val (@vals) {
                    $val =~ s/'/''/g;    # replace ' with ''
                    if ( blankStr($cond1) ) {
                        $cond1 .= "p.project_oid in ( "
                          . getGoldSetAttrSQL($attr, '', 1)
                          . " where $attr in ('"
                          . $val . "'";
                    } else {
                        $cond1 .= ", '" . $val . "'";
                    }
                }    # end for val

                if ( !blankStr($cond1) ) {
                    $cond1 .= "))";
                    if ( blankStr($cond) ) {
                        $cond = " where " . $cond1;
                    } else {
                        $cond .= " and $cond1";
                    }
                }
            }
        }
    }

    my $sql =
        "select p.project_oid, p.gold_stamp_id, p.gold_id_old "
      . "from project_info p";
    if ( !blankStr($cond) ) {
        $sql .= $cond;
    }

    #print "<p>SQL: $sql</p>\n";

    my $dbh = connectGoldDatabase();
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $gold_id, $old_gold_id ) = $cur->fetchrow();
        last if !$id;

        if ( ! blankStr($gold_id) && ! WebUtil::inArray( $gold_id, @gold_ids ) ) {
            push @gold_ids, ($gold_id);
        }
        if ( ! blankStr($old_gold_id) && ! WebUtil::inArray( $old_gold_id, @gold_ids ) ) {
            push @gold_ids, ($old_gold_id);
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    return @gold_ids;
}

##########################################################################
# getMetadataForGoldId
##########################################################################
sub getMetadataForGoldId {
    my ( $gold_id, $attr_ref ) = @_;

    my %metadata;
    if ( blankStr($gold_id) || !$attr_ref || scalar(@$attr_ref) == 0 ) {
        return %metadata;
    }

    # find corresponding project_oid
    my $dbh = connectGoldDatabase();
    my $sql =
      "select project_oid from project_info where gold_stamp_id = ? ";
    my $cur = execSql( $dbh, $sql, $verbose, $gold_id );
    my ($project_oid) = $cur->fetchrow();
    $cur->finish();
    if ( !$project_oid ) {
        $sql = "select project_oid from project_info "
	     . "where gold_id_old = ? ";
        $cur = execSql( $dbh, $sql, $verbose, $gold_id );
        ($project_oid) = $cur->fetchrow();
        $cur->finish();
    }
    if ( !$project_oid ) {
        #$dbh->disconnect();
        return %metadata;
    }

    # get single-valued
    my @select1 = ();
    $sql = "select p.project_oid";
    for my $attr (@$attr_ref) {
        if ( isGoldSingleAttr($attr) ) {
            push @select1, ($attr);
            $sql .= ", " . $attr;
        }
    }
    $sql .= " from project_info p where p.project_oid = ? ";
    if ( scalar(@select1) > 0 ) {
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        my ( $p_oid, @vals ) = $cur->fetchrow();
        $cur->finish();
        if ($p_oid) {
            my $cnt = 0;
            for my $attr1 (@select1) {
                if ( scalar(@vals) > $cnt ) {
                    my $val1 = $vals[$cnt];
                    if ( defined($val1) ) {
                        $metadata{$attr1} = $val1;
                    }
                }

                # next
                $cnt++;
            }
        }
    }

    # get set-valued
    for my $attr (@$attr_ref) {
        if ( isGoldSingleAttr($attr) ) {
            # skip single-valued
            next;
        }

        # set-valued
        $sql = getGoldSetAttrSQL( $attr, "project_oid = ?" );
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        my $str = "";
        for ( ; ; ) {
            my ( $p_id, $val ) = $cur->fetchrow();
            last if !$p_id;

            if ( !blankStr($val) ) {
                if ( blankStr($str) ) {
                    $str = $val;
                } else {
                    $str .= "\t" . $val;
                }
            }
        }
        $cur->finish();

        if ( !blankStr($str) ) {
            $metadata{$attr} = $str;
        }
    }

    #$dbh->disconnect();
    return %metadata;
}

##########################################################################
# getMetadataForSubmissionId
##########################################################################
sub getMetadataForSubmissionId {
    my ( $submission_id, $attr_ref ) = @_;

    my %metadata;
    if ( blankStr($submission_id) || !$attr_ref || scalar(@$attr_ref) == 0 ) {
        return %metadata;
    }

    # find corresponding project_oid
    my $dbh = connectGoldDatabase();
    my $sql =
      "select project_info from submission where submission_id = ? ";
    my $cur = execSql( $dbh, $sql, $verbose, $submission_id );
    my ($project_oid) = $cur->fetchrow();
    $cur->finish();
    if ( !$project_oid ) {
        #$dbh->disconnect();
        return %metadata;
    }

    # get single-valued
    my @select1 = ();
    $sql = "select p.project_oid";
    for my $attr (@$attr_ref) {
        if ( isGoldSingleAttr($attr) ) {
            push @select1, ($attr);
            $sql .= ", " . $attr;
        }
    }
    $sql .= " from project_info p where p.project_oid = ? ";
    if ( scalar(@select1) > 0 ) {
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        my ( $p_oid, @vals ) = $cur->fetchrow();
        $cur->finish();
        if ($p_oid) {
            my $cnt = 0;
            for my $attr1 (@select1) {
                if ( scalar(@vals) > $cnt ) {
                    my $val1 = $vals[$cnt];
                    if ( defined($val1) ) {
                        $metadata{$attr1} = $val1;
                    }
                }

                # next
                $cnt++;
            }
        }
    }

    # get set-valued
    for my $attr (@$attr_ref) {
        if ( isGoldSingleAttr($attr) ) {
            # skip single-valued
            next;
        }

        # set-valued
        $sql = getGoldSetAttrSQL( $attr, "project_oid = ?" );
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        
        my $str = "";
        for ( ; ; ) {
            my ( $p_id, $val ) = $cur->fetchrow();
            last if !$p_id;

            if ( !blankStr($val) ) {
                if ( blankStr($str) ) {
                    $str = $val;
                } else {
                    $str .= "\t" . $val;
                }
            }
        }
        $cur->finish();

        if ( !blankStr($str) ) {
            $metadata{$attr} = $str;
        }
    }

    #$dbh->disconnect();
    return %metadata;
}


##########################################################################
# getCategoryNCBIProjIds
##########################################################################
sub getCategoryNCBIProjIds {
    my ( $attr, $attr_val ) = @_;

    my @ncbi_proj_ids = ();
    my $sql           =
        "select p.project_oid, p.ncbi_project_id, s.ncbi_project_id"
      . " from project_info p, env_sample s"
      . " where p.project_oid = s.project_info (+)";

    if ( isGoldSingleAttr($attr) ) {

        # single valued
        $sql .= " and p.$attr = ? ";
    } elsif ( isGoldSetAttr($attr) ) {

        # set valued
        $sql .= " and p.project_oid in ( "
          . getGoldSetAttrSQL($attr, '', 1)
          . " where $attr = ? )";
    } else {
        return @ncbi_proj_ids;
    }
    #print "getCategoryNCBIProjIds SQL: $sql<br/>\n";
    #print "getCategoryNCBIProjIds $attr_val: $attr_val<br/>\n";

    my $dbh = connectGoldDatabase();
    my $cur = execSql( $dbh, $sql, $verbose, $attr_val );
    for ( ; ; ) {
        my ( $id, $ncbi_id, $sample_ncbi_id ) = $cur->fetchrow();
        last if !$id;

        if (    ! blankStr($ncbi_id)
             && isInt($ncbi_id)
             && ! WebUtil::inArray( $ncbi_id, @ncbi_proj_ids ) )
        {
            push @ncbi_proj_ids, ($ncbi_id);
        }

        if (    ! blankStr($sample_ncbi_id)
             && isInt($sample_ncbi_id)
             && ! WebUtil::inArray( $sample_ncbi_id, @ncbi_proj_ids ) )
        {
            push @ncbi_proj_ids, ($sample_ncbi_id);
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    return @ncbi_proj_ids;
}

##########################################################################
# getQueryNCBIProjIds
#
# (use param to get query condition)
##########################################################################
sub getQueryNCBIProjIds {
    my ( $toProcessVal ) = @_;

    my @ncbi_proj_ids = ();

    my @cond_attrs   = getGoldCondAttr();

    my $cond = "";
    for my $attr (@cond_attrs) {
        if ( isGoldSingleAttr($attr) ) {

            # single-valued
            #my @vals = param($attr);
            my @vals = ();
            if ($toProcessVal) {
                @vals = processParamValue(param($attr));
            } else {
                @vals = param($attr);           
            }
            if ( scalar(@vals) > 0 ) {
                my $cond1 = "";
                for my $val (@vals) {
                    $val =~ s/'/''/g;    # replace ' with ''
                    if ( blankStr($cond1) ) {
                        $cond1 = "p.$attr in ('$val'";
                    } else {
                        $cond1 .= ", '" . $val . "'";
                    }
                }    # end for val

                if ( !blankStr($cond1) ) {
                    $cond1 .= ")";
                    if ( blankStr($cond) ) {
                        $cond = " where " . $cond1;
                    } else {
                        $cond .= " and $cond1";
                    }
                }
            }
        } else {

            # set-valued
            #my @vals = param($attr);
            my @vals = ();
            if ($toProcessVal) {
                @vals = processParamValue(param($attr));
            } else {
                @vals = param($attr);           
            }
            if ( scalar(@vals) > 0 ) {
                my $cond1 = "";
                for my $val (@vals) {
                    $val =~ s/'/''/g;    # replace ' with ''
                    if ( blankStr($cond1) ) {
                        $cond1 .= "p.project_oid in ("
                          . getGoldSetAttrSQL($attr, '', 1)
                          . " where $attr in ('"
                          . $val . "'";
                    } else {
                        $cond1 .= ", '" . $val . "'";
                    }
                }    # end for val

                if ( !blankStr($cond1) ) {
                    $cond1 .= "))";
                    if ( blankStr($cond) ) {
                        $cond = " where " . $cond1;
                    } else {
                        $cond .= " and $cond1";
                    }
                }
            }
        }
    }

    my $sql =
        "select p.project_oid, p.ncbi_project_id, s.gold_id "
      . "from project_info p, env_sample s";
    if ( !blankStr($cond) ) {
        $sql .= $cond;
        $sql .= " and p.project_oid = s.project_info (+)";
    } else {
        $sql .= " where p.project_oid = s.project_info (+)";
    }
    print "DataEntryUtil::getQueryNCBIProjIds() gold sql: $sql<br/>\n";

    my $dbh = connectGoldDatabase();
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $ncbi_id, $sample_ncbi_id ) = $cur->fetchrow();
        last if !$id;

        if (    ! blankStr($ncbi_id)
             && isInt($ncbi_id)
             && ! WebUtil::inArray( $ncbi_id, @ncbi_proj_ids ) )
        {
            push(@ncbi_proj_ids, $ncbi_id);
        }

        if (    ! blankStr($sample_ncbi_id)
             && isInt($sample_ncbi_id)
             && ! WebUtil::inArray( $sample_ncbi_id, @ncbi_proj_ids ) )
        {
            push(@ncbi_proj_ids, $sample_ncbi_id);
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    return @ncbi_proj_ids;
}

##########################################################################
# getMetadataForNCBIProjId
##########################################################################
sub getMetadataForNCBIProjId {
    my ( $ncbi_proj_id, $attr_ref ) = @_;

    my %metadata;
    
    # do not search metadata by ncbi project id - ken
    # metagenome sample all have teh same ncbi project ids
    # instead all should have a gold sample id or submission id if private
    webLog("getMetadataForNCBIProjId\n");
    return %metadata;


    if (    blankStr($ncbi_proj_id)
         || !isInt($ncbi_proj_id)
         || !$attr_ref
         || scalar(@$attr_ref) == 0 )
    {
        return %metadata;
    }

    # find corresponding project_oid
    my $dbh = connectGoldDatabase();
    my $sql =
"select project_oid from project_info where ncbi_project_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $ncbi_proj_id );
    my ($project_oid) = $cur->fetchrow();
    $cur->finish();

    if ( !$project_oid ) {

        # check env_sample
        $sql =
"select project_info from env_sample where ncbi_project_id = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $ncbi_proj_id );
        ($project_oid) = $cur->fetchrow();
        $cur->finish();

        if ( !$project_oid ) {
            #$dbh->disconnect();
            return %metadata;
        }
    }

    # get single-valued
    my @select1 = ();
    $sql = "select p.project_oid";
    for my $attr (@$attr_ref) {
        if ( isGoldSingleAttr($attr) ) {
            push @select1, ($attr);
            $sql .= ", " . $attr;
        }
    }
    $sql .= " from project_info p where p.project_oid = ?";
    if ( scalar(@select1) > 0 ) {
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        my ( $p_oid, @vals ) = $cur->fetchrow();
        $cur->finish();
        if ($p_oid) {
            my $cnt = 0;
            for my $attr1 (@select1) {
                if ( scalar(@vals) > $cnt ) {
                    my $val1 = $vals[$cnt];
                    if ( defined($val1) ) {
                        $metadata{$attr1} = $val1;
                    }
                }

                # next
                $cnt++;
            }
        }
    }

    # get set-valued
    for my $attr (@$attr_ref) {
        if ( isGoldSingleAttr($attr) ) {

            # skip single-valued
            next;
        }

        # set-valued
        $sql = getGoldSetAttrSQL( $attr, "project_oid = ?" );
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        my $str = "";
        for ( ; ; ) {
            my ( $p_id, $val ) = $cur->fetchrow();
            last if !$p_id;

            if ( !blankStr($val) ) {
                if ( blankStr($str) ) {
                    $str = $val;
                } else {
                    $str .= "\t" . $val;
                }
            }
        }
        $cur->finish();

        if ( !blankStr($str) ) {
            $metadata{$attr} = $str;
        }
    }

    #$dbh->disconnect();
    return %metadata;
}

##########################################################################
# getProjectMetadataForNCBIProjId
##########################################################################
sub getProjectMetadataForNCBIProjId {
    my ($ncbi_proj_id) = @_;

    my %metadata;
    
    webLog("getProjectMetadataForNCBIProjId\n");
    return %metadata;
   
    if ( blankStr($ncbi_proj_id) || !isInt($ncbi_proj_id) ) {
        return %metadata;
    }

    # find corresponding project_oid
    my $dbh = connectGoldDatabase();
    my $sql = "select project_oid from project_info "
	    . "where ncbi_project_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $ncbi_proj_id );
    my ($project_oid) = $cur->fetchrow();
    $cur->finish();

    if ( !$project_oid ) {
        # check env_sample
        $sql = "select project_info from env_sample "
	     . "where ncbi_project_id = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $ncbi_proj_id );
        ($project_oid) = $cur->fetchrow();
        $cur->finish();

        if ( !$project_oid ) {
            #$dbh->disconnect();
            return %metadata;
        }
    }

    if ( $project_oid ) {
        
        # get single-valued
        $sql = getGoldSingleAttrSQL( "p.project_oid = ?" );
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        my ( $p_oid, @vals ) = $cur->fetchrow();
        $cur->finish();
    
        if ($p_oid) {
            my $cnt = 0;
            my @attrs1 = getGoldSingleAttr();
            for my $attr1 (@attrs1) {
                if ( scalar(@vals) > $cnt ) {
                    my $val1 = $vals[$cnt];
                    if ( defined($val1) ) {
                        $metadata{$attr1} = $val1;
                    }
                }
                # next
                $cnt++;
            }
        }
    
        # get set-valued
        my @attrs2 = getGoldSetAttr();
        for my $attr (@attrs2) {
            $sql = getGoldSetAttrSQL( $attr, "project_oid = ?" );
            $cur = execSql( $dbh, $sql, $verbose, $project_oid );
            my $str = "";
            for ( ; ; ) {
                my ( $p_id, $val ) = $cur->fetchrow();
                last if !$p_id;
    
                if ( !blankStr($val) ) {
                    if ( blankStr($str) ) {
                        $str = $val;
                    } else {
                        $str .= ", " . $val;
                    }
                }
            }
            $cur->finish();
    
            if ( !blankStr($str) ) {
                $metadata{$attr} = $str;
            }
        }

    }

    #$dbh->disconnect();
    return %metadata;
}

# ga project info
sub getAllMetadataForGa {
    my ($gaId) = @_;
    my %metadata;
    
    
    my $dbh = connectGoldDatabase();
    my $sql;
    my $cur;
    my ($sample_oid, $gsId, $project_oid);
    if($include_metagenomes) {
        my $sql = qq{
select s.sample_oid, s.gold_id, s.PROJECT_INFO
from gold_analysis_project_lookup2 l,
     env_sample s
where l.gold_id = ?
and l.sample_oid = s.sample_oid
        };
      
        my $cur = execSql( $dbh, $sql, $verbose, $gaId );
        ($sample_oid, $gsId, $project_oid) = $cur->fetchrow();    
    }

    if ( !$project_oid  ) {
        my $sql = qq{
select p.GOLD_STAMP_ID, p.PROJECT_OID
from gold_analysis_project_lookup2 l,
     project_info p
where l.gold_id = ?
and l.project_oid = p.project_oid            
        };
        my $cur = execSql( $dbh, $sql, $verbose, $gaId );
        ($gsId, $project_oid) = $cur->fetchrow();
    }


    if ( $project_oid ) {

        # get single-valued
        $sql = getGoldSingleAttrSQL( "p.project_oid = ?" );
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        my ( $p_oid, @vals ) = $cur->fetchrow();
        $cur->finish();
        if ($p_oid) {
            my $cnt = 0;
            my @attrs1 = getGoldSingleAttr();
            for my $attr1 (@attrs1) {
                if ( scalar(@vals) > $cnt ) {
                    my $val1 = $vals[$cnt];
                    if ( defined($val1) ) {
                        $metadata{$attr1} = $val1;
                    }
                }
    
                # next
                $cnt++;
            }
        }
    
        # get set-valued
        my @attrs2 = getGoldSetAttr();
        for my $attr (@attrs2) {
            $sql = getGoldSetAttrSQL( $attr, "project_oid = ?" );
            $cur = execSql( $dbh, $sql, $verbose, $project_oid );
            my $str = "";
            for ( ; ; ) {
                my ( $p_id, $val ) = $cur->fetchrow();
                last if !$p_id;
    
                if ( !blankStr($val) ) {
                    if ( blankStr($str) ) {
                        $str = $val;
                    } else {
                        $str .= ", " . $val;
                    }
                }
            }
            $cur->finish();
    
            if ( !blankStr($str) ) {
                $metadata{$attr} = $str;
            }
        }

    }

    # check sample
    if ( $sample_oid ) {
        # use sample metadata instead
        my $sql3 = "select s.sample_oid";
        for my $sample_attr ( @goldSampleSingleAttrs ) {
            $sql3 .= ", s." . $sample_attr;
        }
        $sql3 .= " from env_sample s where s.sample_oid = ?";
    
        my $cur3 = execSql( $dbh, $sql3, $verbose, $sample_oid );
        my ( $s_oid, @vals3 ) = $cur3->fetchrow();
        $cur3->finish();

        if ( $s_oid ) {
            my $j = 0;
            my $val3 = '';
            for my $attr3 (@goldSampleSingleAttrs) {
            if ( scalar(@vals3) > $j ) {
                $val3 = $vals3[$j];
            }
    
            if ( !blankStr($val3) ) {
                $metadata{$attr3} = $val3;
            }
            $j++;
            }
        }
    }

    return %metadata;

    
}

##########################################################################
# getAllMetadataForSubmissionId
##########################################################################
sub getAllMetadataForSubmissionId {
    my ($submission_id) = @_;

    my %metadata;
    if ( blankStr($submission_id) || !isInt($submission_id) ) {
        return %metadata;
    }

    # find corresponding project_oid
    my $dbh = connectGoldDatabase();
    my $sql = 
	"select project_info, sample_oid from submission where submission_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $submission_id );
    my ($project_oid, $sample_oid) = $cur->fetchrow();
    $cur->finish();

    if ( !$project_oid && $sample_oid ) {
        # check env_sample
        $sql =
	    "select project_info from env_sample where sample_oid = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
        ($project_oid) = $cur->fetchrow();
        $cur->finish();

        if ( !$project_oid ) {
            #$dbh->disconnect();
            return %metadata;
        }
    }

    if ( $project_oid && ! $sample_oid ) {
        # check env_sample
    	my $sql = "select count(*) from submission_samples where submission_id = ?";
            my $cur = execSql( $dbh, $sql, $verbose, $submission_id );
    	my ($cnt0) = $cur->fetchrow();
    	$cur->finish();
    
    	if ( $cnt0 == 1 ) {
    	    $sql =
    		"select sample_oid from submission_samples where submission_id = ?";
    	    $cur = execSql( $dbh, $sql, $verbose, $submission_id );
    	    ($sample_oid) = $cur->fetchrow();
    	    $cur->finish();
    	}
    }

    if ( $project_oid ) {

        # get single-valued
        $sql = getGoldSingleAttrSQL( "p.project_oid = ?" );
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        my ( $p_oid, @vals ) = $cur->fetchrow();
        $cur->finish();
        if ($p_oid) {
            my $cnt = 0;
            my @attrs1 = getGoldSingleAttr();
            for my $attr1 (@attrs1) {
                if ( scalar(@vals) > $cnt ) {
                    my $val1 = $vals[$cnt];
                    if ( defined($val1) ) {
                        $metadata{$attr1} = $val1;
                    }
                }
    
                # next
                $cnt++;
            }
        }
    
        # get set-valued
        my @attrs2 = getGoldSetAttr();
        for my $attr (@attrs2) {
            $sql = getGoldSetAttrSQL( $attr, "project_oid = ?" );
            $cur = execSql( $dbh, $sql, $verbose, $project_oid );
            my $str = "";
            for ( ; ; ) {
                my ( $p_id, $val ) = $cur->fetchrow();
                last if !$p_id;
    
                if ( !blankStr($val) ) {
                    if ( blankStr($str) ) {
                        $str = $val;
                    } else {
                        $str .= ", " . $val;
                    }
                }
            }
            $cur->finish();
    
            if ( !blankStr($str) ) {
                $metadata{$attr} = $str;
            }
        }

    }

    # check sample
    if ( $sample_oid ) {
    	# use sample metadata instead
    	my $sql3 = "select s.sample_oid";
    	for my $sample_attr ( @goldSampleSingleAttrs ) {
    	    $sql3 .= ", s." . $sample_attr;
    	}
    	$sql3 .= " from env_sample s where s.sample_oid = ?";
    
    	my $cur3 = execSql( $dbh, $sql3, $verbose, $sample_oid );
    	my ( $s_oid, @vals3 ) = $cur3->fetchrow();
    	$cur3->finish();

    	if ( $s_oid ) {
    	    my $j = 0;
    	    my $val3 = '';
    	    for my $attr3 (@goldSampleSingleAttrs) {
    		if ( scalar(@vals3) > $j ) {
    		    $val3 = $vals3[$j];
    		}
    
    		if ( !blankStr($val3) ) {
    		    $metadata{$attr3} = $val3;
    		}
    		$j++;
    	    }
    	}
    }

    #$dbh->disconnect();
    return %metadata;
}


##########################################################################
# getAllMetadataForGoldId
##########################################################################
sub getAllMetadataForGoldId {
    my ($project_gold_id, $sample_gold_id) = @_;

    my %metadata;
    if ( blankStr($project_gold_id) || blankStr($sample_gold_id) ) {
        return %metadata;
    }

    # find corresponding project_oid
    my $dbh = connectGoldDatabase();

    my $sql = "select project_oid from project_info where gold_stamp_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $project_gold_id );
    my ($project_oid) = $cur->fetchrow();
    $cur->finish();
    #print "getAllMetadataForGoldId() project_oid=$project_oid after using project_gold_id=$project_gold_id in project_info<br/>\n";

    if ( $project_oid ) {
        # get single-valued
        $sql = getGoldSingleAttrSQL( "p.project_oid = ?" );
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        my ( $p_oid, @vals ) = $cur->fetchrow();
        $cur->finish();
    
        if ($p_oid) {
            my $cnt = 0;
            my @attrs1 = getGoldSingleAttr();
            for my $attr1 (@attrs1) {
                if ( scalar(@vals) > $cnt ) {
                    my $val1 = $vals[$cnt];
                    if ( defined($val1) ) {
                        $metadata{$attr1} = $val1;
                    }
                }
    
                # next
                $cnt++;
            }
        }

        # get set-valued
        my @attrs2 = getGoldSetAttr();
        for my $attr (@attrs2) {
            $sql = getGoldSetAttrSQL( $attr, "project_oid = ?" );
            #print "getAllMetadataForGoldId() $attr called getGoldSetAttrSQL sql: $sql<br/>\n";
            $cur = execSql( $dbh, $sql, $verbose, $project_oid );
            my $str = "";
            for ( ; ; ) {
                my ( $p_id, $val ) = $cur->fetchrow();
                last if !$p_id;
    
                if ( !blankStr($val) ) {
                    if ( blankStr($str) ) {
                        $str = $val;
                    } else {
                        $str .= ", " . $val;
                    }
                }
            }
            $cur->finish();
    
            if ( !blankStr($str) ) {
                $metadata{$attr} = $str;
            }
        }
    }

    if ( $sample_gold_id ) {
        # use sample metadata instead
        my $sql3 = "select s.sample_oid";
        for my $sample_attr ( @goldSampleSingleAttrs ) {
            $sql3 .= ", s." . $sample_attr;
        }
        $sql3 .= " from env_sample s where s.gold_id = ?";
        my $cur3 = execSql( $dbh, $sql3, $verbose, $sample_gold_id );
        my ( $sample_oid, @vals3 ) = $cur3->fetchrow();
        $cur3->finish();
    
        if ( $sample_oid ) {
            my $j = 0;
            my $val3 = '';
            for my $attr3 (@goldSampleSingleAttrs) {
                if ( scalar(@vals3) > $j ) {
                    $val3 = $vals3[$j];
                }
        
                if ( !blankStr($val3) ) {
                    $metadata{$attr3} = $val3;
                }
        
                $j++;
            }
        }
    }

    #$dbh->disconnect();
    return %metadata;
}

# Ga
sub getSampleMetadataForGa {
    my ($gaId) = @_;
    
    my $dbh = connectGoldDatabase();
    my $sql = qq{
select s.sample_oid, s.gold_id
from gold_analysis_project_lookup2 l,
     env_sample s
where l.gold_id = ?
and l.sample_oid = s.sample_oid
    };
      
    my $cur = execSql( $dbh, $sql, $verbose, $gaId );
    my ($sample_oid, $gsId) = $cur->fetchrow();
    
    my %metadata = {};
    if ( !$sample_oid ) {
        return %metadata;
    }

    # get single-valued
    my @attrs1 = getGoldSampleSingleAttr();
    $sql = "select s.sample_oid";
    for my $attr (@attrs1) {
        $sql .= ", " . $attr;
    }
    $sql .= " from env_sample s where s.sample_oid = ?";
    $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
    my ( $s_oid, @vals ) = $cur->fetchrow();
    $cur->finish();
    if ($s_oid) {
        my $cnt = 0;
        for my $attr1 (@attrs1) {
            if ( scalar(@vals) > $cnt ) {
                my $val1 = $vals[$cnt];
                if ( defined($val1) ) {
                    $metadata{$attr1} = $val1;
                }
            }

            # next
            $cnt++;
        }
    }

    return %metadata;
    
}


##########################################################################
# getSampleMetadataForSubmissionId
##########################################################################
sub getSampleMetadataForSubmissionId {
    my ($submission_id) = @_;

    my %metadata = {};
    if ( blankStr($submission_id) || !isInt($submission_id) ) {
        return %metadata;
    }

    # find corresponding sample_oid
    my $dbh = connectGoldDatabase();
    my $sql =
      "select sample_oid from submission where submission_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $submission_id );
    my ($sample_oid) = $cur->fetchrow();
    $cur->finish();

    my %metadata = {};
    if ( !$sample_oid ) {
        #$dbh->disconnect();
        return %metadata;
    }

    # get single-valued
    my @attrs1 = getGoldSampleSingleAttr();
    $sql = "select s.sample_oid";
    for my $attr (@attrs1) {
        $sql .= ", " . $attr;
    }
    $sql .= " from env_sample s where s.sample_oid = ?";
    $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
    my ( $s_oid, @vals ) = $cur->fetchrow();
    $cur->finish();
    if ($s_oid) {
        my $cnt = 0;
        for my $attr1 (@attrs1) {
            if ( scalar(@vals) > $cnt ) {
                my $val1 = $vals[$cnt];
                if ( defined($val1) ) {
                    $metadata{$attr1} = $val1;
                }
            }

            # next
            $cnt++;
        }
    }

    #$dbh->disconnect();
    return %metadata;
}

##########################################################################
# getSampleMetadataForNCBIProjId
##########################################################################
sub getSampleMetadataForNCBIProjId {
    my ($ncbi_proj_id) = @_;

    my %metadata;
    
    # do not search metadata by ncbi project id - ken
    # metagenome sample all have teh same ncbi project ids
    # instead all should have a gold sample id or submission id if private
    webLog("getSampleMetadataForNCBIProjId\n");
    return %metadata;
    if ( blankStr($ncbi_proj_id) || !isInt($ncbi_proj_id) ) {
        return %metadata;
    }

    # find corresponding sample_oid
    my $dbh = connectGoldDatabase();
    my $sql = "select sample_oid from env_sample where ncbi_project_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $ncbi_proj_id );
    my ($sample_oid) = $cur->fetchrow();
    $cur->finish();

    if ( !$sample_oid ) {
        #$dbh->disconnect();
        return %metadata;
    }

    # get single-valued
    my @attrs1 = getGoldSampleSingleAttr();
    $sql = "select s.sample_oid";
    for my $attr (@attrs1) {
        $sql .= ", " . $attr;
    }
    $sql .= " from env_sample s where s.sample_oid = ?";
    $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
    my ( $s_oid, @vals ) = $cur->fetchrow();
    $cur->finish();
    if ($s_oid) {
        my $cnt = 0;
        for my $attr1 (@attrs1) {
            if ( scalar(@vals) > $cnt ) {
                my $val1 = $vals[$cnt];
                if ( defined($val1) ) {
                    $metadata{$attr1} = $val1;
                }
            }

            # next
            $cnt++;
        }
    }

    #$dbh->disconnect();
    return %metadata;
}

##########################################################################
# getProjectMetadataForIds
##########################################################################
sub getProjectMetadataForIds {
    my ( $img_oid_str, $ncbi_project_id_str ) = @_;

    my $img_oid;
    my $txClause;
    my %metadata;

    my @img_oids = split( /\,/, $img_oid_str );
    if ( scalar(@img_oids) == 1 ) {
        $img_oid  = $img_oids[0];
        $txClause = "img_oid = $img_oid";
        if ( blankStr($img_oid) || !isInt($img_oid) ) {
            return %metadata;
        }
    } elsif ( scalar(@img_oids) == 0 ) {
        return %metadata;
    } else {
        $txClause = "img_oid in ($img_oid_str)";
    }

    # find corresponding project_oid
    my $dbh = connectGoldDatabase();

    # check env_sample
    my $sql = "select project_info from env_sample where $txClause";
    my $cur = execSql( $dbh, $sql, $verbose );
    my %projectHash;

    for ( ; ; ) {
        my ($project_oid) = $cur->fetchrow();
        last if !$project_oid;
        $projectHash{$project_oid}++;
    }
    $cur->finish();

    $sql = "select project_oid from project_info where $txClause";
    $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($project_oid) = $cur->fetchrow();
        last if !$project_oid;
        $projectHash{$project_oid}++;
    }
    $cur->finish();

    my @projects = sort( keys(%projectHash) );
    if ( scalar(@projects) == 0 ) {
        #$dbh->disconnect();
        return %metadata;
    }

    if ( scalar(@projects) > 0 ) {
        my $project_oid_str = join( ",", @projects );
    
        # get single-valued
        $sql = getGoldSingleAttrSQL( "p.project_oid in ($project_oid_str)" );
        $cur = execSql( $dbh, $sql, $verbose );
    
        my %attvalues;
        for ( ; ; ) {
            my ( $p_id, @vals ) = $cur->fetchrow();
            last if !$p_id;
    
            my $cnt = 0;
            my @attrs1 = getGoldSingleAttr();
            for my $attr1 (@attrs1) {
                if ( scalar(@vals) > $cnt ) {
                    my $val1 = $vals[$cnt];
                    if ( defined($val1)
                         && !$attvalues{"$attr1 . $val1"} )
                    {
                        my $text = $metadata{$attr1};
                        if ( $text ne "" ) {
                            $text .= "; ";
                        }
                        $metadata{$attr1} = $text . $val1;
                        $attvalues{"$attr1 . $val1"}++;
                    }
                }
                $cnt++;
            }
        }
        $cur->finish();
    
        # get set-valued
        my @attrs2 = getGoldSetAttr();
        for my $attr (@attrs2) {
            $sql = getGoldSetAttrSQL( $attr, "project_oid in ($project_oid_str)" );
            $cur = execSql( $dbh, $sql, $verbose );
            my %items;
            for ( ; ; ) {
                my ( $p_id, $val ) = $cur->fetchrow();
                last if !$p_id;
                if ( !blankStr($val) ) {
                    $items{$val}++;
                }
            }
            $cur->finish();
    
            my @keys = sort( keys(%items) );
            my $text;
            for my $k (@keys) {
                if ( $text ne "" ) {
                    $text .= "; ";
                }
                $text .= $k;
            }
            if ( !blankStr($text) ) {
                $metadata{$attr} = $text;
            }
        }
    }

    #$dbh->disconnect();
    return %metadata;
}

##########################################################################
# getProjectMetadataForImgOid
##########################################################################
sub getProjectMetadataForImgOid {
    my ($img_oid, $project_gold_id, $sample_gold_id) = @_;

    my %metadata;
    if ( blankStr($img_oid) || !isInt($img_oid) ) {
        return %metadata;
    }

    # find corresponding project_oid
    my $dbh = connectGoldDatabase();

    my $sql = "select project_oid from project_info where img_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $img_oid );
    my ($project_oid) = $cur->fetchrow();
    $cur->finish();
    #print "getProjectMetadataForImgOid() project_oid=$project_oid after using img_oid=$img_oid in project_info<br/>\n";

    if ( !$project_oid ) {
        # check env_sample
        $sql = "select project_info from env_sample where img_oid = ?";
        $cur = execSql( $dbh, $sql, $verbose, $img_oid );
        ($project_oid) = $cur->fetchrow();
        $cur->finish();
        #print "getProjectMetadataForImgOid() project_oid=$project_oid after using img_oid=$img_oid in env_sample<br/>\n";
    }

    if ( $project_oid ) {
        # get single-valued
        $sql = getGoldSingleAttrSQL( "p.project_oid = ?" );
        $cur = execSql( $dbh, $sql, $verbose, $project_oid );
        my ( $p_oid, @vals ) = $cur->fetchrow();
        $cur->finish();
    
        if ($p_oid) {
            my $cnt = 0;
            my @attrs1 = getGoldSingleAttr();
            for my $attr1 (@attrs1) {
                if ( scalar(@vals) > $cnt ) {
                    my $val1 = $vals[$cnt];
                    if ( defined($val1) ) {
                        $metadata{$attr1} = $val1;
                    }
                }
    
                # next
                $cnt++;
            }
        }

        # get set-valued
        my @attrs2 = getGoldSetAttr();
        for my $attr (@attrs2) {
            $sql = getGoldSetAttrSQL( $attr, "project_oid = ?" );
            #print "getProjectMetadataForImgOid() $attr called getGoldSetAttrSQL sql: $sql<br/>\n";
            $cur = execSql( $dbh, $sql, $verbose, $project_oid );
            my $str = "";
            for ( ; ; ) {
                my ( $p_id, $val ) = $cur->fetchrow();
                last if !$p_id;
    
                if ( !blankStr($val) ) {
                    if ( blankStr($str) ) {
                        $str = $val;
                    } else {
                        $str .= ", " . $val;
                    }
                }
            }
            $cur->finish();
    
            if ( !blankStr($str) ) {
                $metadata{$attr} = $str;
            }
        }
    }

    #$dbh->disconnect();
    return %metadata;
}

##########################################################################
# getSampleMetadataForImgOid
##########################################################################
sub getSampleMetadataForImgOid {
    my ($img_oid) = @_;

    my %metadata;
    if ( blankStr($img_oid) || !isInt($img_oid) ) {
        return %metadata;
    }

    # find corresponding sample_oid
    my $dbh = connectGoldDatabase();
    my $sql = "select sample_oid from env_sample where img_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $img_oid );
    my ($sample_oid) = $cur->fetchrow();
    $cur->finish();

    if ( !$sample_oid ) {
        #$dbh->disconnect();
        return %metadata;
    }

    # get single-valued
    my @attrs1 = getGoldSampleSingleAttr();
    $sql = "select s.sample_oid";
    for my $attr (@attrs1) {
        $sql .= ", " . $attr;
    }
    $sql .= " from env_sample s where s.sample_oid = ?";
    $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
    my ( $s_oid, @vals ) = $cur->fetchrow();
    $cur->finish();
    if ($s_oid) {
        my $cnt = 0;
        for my $attr1 (@attrs1) {
            if ( scalar(@vals) > $cnt ) {
                my $val1 = $vals[$cnt];
                if ( defined($val1) ) {
                    $metadata{$attr1} = $val1;
                }
            }

            # next
            $cnt++;
        }
    }

    #$dbh->disconnect();
    return %metadata;
}

##########################################################################
# getSampleMetadataFromGold
#
# use $submission_id, img_oid or NCBI project ID to find metadata from GOLD
##########################################################################
sub getSampleMetadataFromGold {
    my ( $submission_id, $img_oid, $ncbi_project_id, $analysis_project_id ) = @_;

    my %metadata;

    # use Ga id
    if($analysis_project_id) {
        %metadata = getSampleMetadataForGa($analysis_project_id);
        if ( scalar(keys %metadata) > 0 ) {
            return %metadata;
        }  
    }

    # use submission id first
    if ($submission_id) {
        %metadata = getSampleMetadataForSubmissionId($submission_id);
        if ( scalar(keys %metadata) > 0 ) {
            return %metadata;
        }    	
    }

    # use IMG OID second
    if ($img_oid) {
        %metadata = getSampleMetadataForImgOid($img_oid);
        if ( scalar(keys %metadata) > 0 ) {
            return %metadata;
        }
    }

    # use NCBI project ID
    if ($ncbi_project_id) {
        %metadata = getSampleMetadataForNCBIProjId($ncbi_project_id);
    }

    return %metadata;
}


##########################################################################
# getAllMetadataFromGold
#
# use submission id, gold id, img_oid or NCBI project ID to find metadata from GOLD
##########################################################################
sub getAllMetadataFromGold {
    my ( $submission_id, $img_oid_str, $ncbi_project_id_str, $project_gold_id, $sample_gold_id, $analysis_project_id ) = @_;

    my %metadata;

    if($analysis_project_id) {
        %metadata = getAllMetadataForGa($analysis_project_id);
        if ( scalar(keys %metadata) > 0 ) {
            return %metadata;
        }
    }

    # use submission id first
    if ($submission_id) {
        %metadata = getAllMetadataForSubmissionId($submission_id);
        if ( scalar(keys %metadata) > 0 ) {
            #print "getAllMetadataFromGold() used submission_id = $submission_id<br/>\n";
            return %metadata;
        }
    } 

    if ($project_gold_id || $sample_gold_id) {
        %metadata = getAllMetadataForGoldId($project_gold_id, $sample_gold_id);
        if ( scalar(keys %metadata) > 0 ) {
            #print "getAllMetadataFromGold() used project_gold_id=$project_gold_id sample_gold_id=$sample_gold_id<br/>\n";
            return %metadata;
        }
    } 

    my $img_oid;
    my @img_oids = split( /\,/, $img_oid_str );
    if ( scalar(@img_oids) == 1 ) {
        $img_oid = $img_oids[0];
    }
    
    my $ncbi_project_id;
    my @ncbi_ids = split( /\,/, $ncbi_project_id_str );
    if ( scalar(@ncbi_ids) == 1 ) {
        $ncbi_project_id = $ncbi_ids[0];
    }

    # use IMG OID first
    if ($img_oid_str) {
        if ( scalar(@img_oids) == 1 ) {
            %metadata = getProjectMetadataForImgOid($img_oid);
        } else {
            %metadata =
              getProjectMetadataForIds( $img_oid_str, $ncbi_project_id_str );
        }
        if ( scalar(keys %metadata) > 0 ) {
            #print "getAllMetadataFromGold() used img_oid=$img_oid or img_oid_str=$img_oid_str, ncbi_project_id_str=$ncbi_project_id_str<br/>\n";
            return %metadata;
        }
    }

    # use NCBI project ID
    if ($ncbi_project_id) {
        %metadata = getProjectMetadataForNCBIProjId($ncbi_project_id);
        if ( scalar(keys %metadata) > 0 ) {
            #print "getAllMetadataFromGold() used ncbi_project_id=$ncbi_project_id<br/>\n";
            return %metadata;
        }
    }

    return %metadata;
}


##########################################################################
# getGoldAttrDistribution
##########################################################################
sub getGoldAttrDistribution {
    my ($gold_attr) = @_;

    my %dist;
    if ( blankStr($gold_attr) ) {
        return %dist;
    }

    # find corresponding sample_oid
    my $dbh     = connectGoldDatabase();
    my $sql     = getGoldAttrCVQuery($gold_attr);
    my $cur     = execSql( $dbh, $sql, $verbose );
    my $cnt     = 0;
    my @cv_vals = ();
    for ( ; ; ) {
        my ($cv_val) = $cur->fetchrow();
        last if !defined($cv_val);

        push @cv_vals, ($cv_val);
    }
    $cur->finish();

    for my $val1 (@cv_vals) {
        my $res = getCategoryCondTaxonCount( $gold_attr, $val1 );

        $dist{$val1} = $res;
    }

    #$dbh->disconnect();
    return %dist;
}

##########################################################################
# getCategoryCondTaxonCount
#
##########################################################################
sub getCategoryCondTaxonCount {
    my ( $category, $cate_val ) = @_;

    my @res = getCategoryCondTaxons( $category, $cate_val );

    return scalar(@res);
}

##########################################################################
# getCategoryCondTaxons
#
##########################################################################
sub getCategoryCondTaxons {
    my ( $category, $cate_val ) = @_;

    my @ncbi_proj_ids = ();
    my @taxon_oids    = ();

    if ( blankStr($category) || blankStr($cate_val) ) {
        return @taxon_oids;
    }

    my $cond = "";
    my $val  = $cate_val;
    $val =~ s/'/''/g;    # replace ' with ''

    if ( isGoldSingleAttr($category) ) {
        # single-valued
        $cond = " where p.$category = '$val'";
    } else {
        # set-valued
        $cond =
            " where p.project_oid in ("
          . getGoldSetAttrSQL($category, '', 1)
          . " where $category = '"
          . $val . "')";
    }

    my $sql =
        "select p.project_oid, p.ncbi_project_id, s.ncbi_project_id "
      . "from project_info p, env_sample s";
    if ( !blankStr($cond) ) {
        $sql .= $cond;
        $sql .= " and p.project_oid = s.project_info (+)";
    } else {
        $sql .= " where p.project_oid = s.project_info (+)";
    }
    #print "<p>SQL: $sql</p>\n";

    my $dbh = connectGoldDatabase();
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $ncbi_id, $sample_ncbi_id ) = $cur->fetchrow();
        last if !$id;

        if (    ! blankStr($ncbi_id)
             && isInt($ncbi_id)
             && ! WebUtil::inArray( $ncbi_id, @ncbi_proj_ids ) )
        {
            push @ncbi_proj_ids, ($ncbi_id);
        }

        if (    ! blankStr($sample_ncbi_id)
             && isInt($sample_ncbi_id)
             && ! WebUtil::inArray( $sample_ncbi_id, @ncbi_proj_ids ) )
        {
            push @ncbi_proj_ids, ($sample_ncbi_id);
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    if ( scalar(@ncbi_proj_ids) == 0 ) {
        return @taxon_oids;
    }

    my $dbh2 = dbLogin();
    my $ncbi_proj_id_conds = getNCBIProjIdWhereClause($dbh2, @ncbi_proj_ids);

    my ($rclause, @bindList) = urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');

    $sql = qq{ 
       select tx.taxon_oid
           from taxon tx
           $ncbi_proj_id_conds
           $rclause
           $imgClause
           order by tx.taxon_display_name 
    };
    #print "<p>SQL: $sql</p>\n";

    my $cur = execSqlBind( $dbh2, $sql, \@bindList, $verbose );

    my $count = 0;
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        $count++;

        push @taxon_oids, ($taxon_oid);
    }
    $cur->finish();

    #$dbh2->disconnect();

    return @taxon_oids;
}

##########################################################################
# getCategoryTaxonCount
#
# a faster version for count. only work for single-valued attr.
##########################################################################
sub getCategoryTaxonCount {
    my ( $category, $domain ) = @_;

    my @taxon_oids = ();

    my %dist;
    my %dist_count;

    if ( blankStr($category) ) {
        return %dist_count;
    }

    if ( !isGoldSingleAttr($category) ) {
        return %dist_count;
    }

    my $sql = qq{
	    select p.project_oid, p.$category, p.ncbi_project_id,
	    s.ncbi_project_id
	    from project_info p, env_sample s
	    where p.$category is not null
	    and p.project_oid = s.project_info (+)
	    order by 2
	};
    #print "<p>SQL: $sql</p>\n";

    my $dbh           = connectGoldDatabase();
    my $cur           = execSql( $dbh, $sql, $verbose );
    my $ncbi_proj_ids = '';
    my $prev_val      = '';
    for ( ; ; ) {
        my ( $id, $cate_val, $ncbi_id, $sample_ncbi_id ) = $cur->fetchrow();
        last if !$id;

        if ( $cate_val eq $prev_val ) {

            # same value
            if ( !blankStr($ncbi_id) && isInt($ncbi_id) ) {
            	if ($ncbi_proj_ids eq '') {
                    $ncbi_proj_ids .= $ncbi_id;
            	}
            	else {
                    $ncbi_proj_ids .= ' ' . $ncbi_id;            		
            	}
            }
            if ( !blankStr($sample_ncbi_id) && isInt($sample_ncbi_id) ) {
                if ($ncbi_proj_ids eq '') {
                    $ncbi_proj_ids .= $sample_ncbi_id;
                }
                else {
                    $ncbi_proj_ids .= ' ' . $sample_ncbi_id;
                }
            }
        } else {

            # different values
            if ( !blankStr($prev_val) && !blankStr($ncbi_proj_ids) ) {

                # save old dist
                $dist{$prev_val} = $ncbi_proj_ids;
                $ncbi_proj_ids = '';
            }

            if ( !blankStr($ncbi_id) && isInt($ncbi_id) ) {
                $ncbi_proj_ids = $ncbi_id;
                if ( !blankStr($sample_ncbi_id) && isInt($sample_ncbi_id) ) {
                    $ncbi_proj_ids .= ' ' . $sample_ncbi_id;
                }
            } elsif ( !blankStr($sample_ncbi_id) && isInt($sample_ncbi_id) ) {
                $ncbi_proj_ids = $sample_ncbi_id;
            }

            $prev_val = $cate_val;
        }
    }
    $cur->finish();

    if ( !blankStr($prev_val) && !blankStr($ncbi_proj_ids) ) {
        # save old dist
        $dist{$prev_val} = $ncbi_proj_ids;
        $ncbi_proj_ids = '';
    }

    #$dbh->disconnect();

    my $dbh2 = dbLogin();
    for my $key ( keys %dist ) {
        #print "getCategoryTaxonCount \$key: $key<br/>\n";
        my @ncbi_proj_ids = split( / /, $dist{$key} );
	    #print "getCategoryTaxonCount \@ncbi_proj_ids size: ".scalar(@ncbi_proj_ids)."<br/>\n";
	    #print "getCategoryTaxonCount \@ncbi_proj_ids: @ncbi_proj_ids<br/>\n";
        my $ncbi_proj_id_conds = getNCBIProjIdWhereClause($dbh2, @ncbi_proj_ids);

        my ($rclause, @bindList) = urClauseBind("tx");
        my $imgClause = WebUtil::imgClause('tx');

        $sql = qq{ 
		    select count(*)
			from taxon tx
            $ncbi_proj_id_conds
			$rclause
			$imgClause
	    };
        if ( !blankStr($domain) ) {
            $sql .= " and tx.domain = ? ";
            push(@bindList, '$domain');
        }

	    #print "getCategoryTaxonCount \$sql: $sql<br/>\n";
	    #print "\@bindList size: ".scalar(@bindList)."<br/>\n";
	    #print "\@bindList: @bindList<br/>\n";

        my $cur = execSqlBind( $dbh2, $sql, \@bindList, $verbose );

        my ($taxon_cnt) = $cur->fetchrow();
        $cur->finish();
        if ( $taxon_cnt > 0 ) {
            $dist_count{$key} = $taxon_cnt;
        }
    }    # end for my key
    #$dbh2->disconnect();

    return %dist_count;
}

##########################################################################
# evalPhenotypeRule
#
# true: 1
# false: 0
# unknown: -1
##########################################################################
sub evalPhenotypeRule {
    my ( $taxon_oid, $rule_id ) = @_;

    if ( !$img_pheno_rule || !$rule_id || !$taxon_oid ) {
        return 0;
    }

    my $dbh = dbLogin();
    my $sql =
      "select rule_type, rule from phenotype_rule where rule_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $rule_id );
    my ( $rule_type, $rule ) = $cur->fetchrow();
    $cur->finish();

    if ( blankStr($rule) ) {
        return 0;
    }

    my $r_type = 0;
    my @rules = split( /\,/, $rule );
    if ( $rule_type =~ /OR/ ) {
        @rules = split( /\|/, $rule );
        $r_type = 1;
    }

    if ( scalar(@rules) == 0 ) {
        return 0;
    }

    my $res = 1;
    if ($r_type) {
        $res = 0;
    }

    for my $r2 (@rules) {
        my $r_res = 0;
        if ($r_type) {

            # OR rule
            $r_res = 1;
        }

        if ( blankStr($r2) ) {
            next;
        }

        $r2 =~ s/\(//;
        $r2 =~ s/\)//;
        my @components = split( /\|/, $r2 );
        if ($r_type) {
            @components = split( /\,/, $r2 );
        }

        my $c_res = 0;
        for my $c2 (@components) {

            # check pathway certification
            my $not_flag    = 0;
            my $pathway_oid = 0;
            if ( $c2 =~ /\!(\d+)/ ) {
                $pathway_oid = $1;
                $not_flag    = 1;
            } elsif ( $c2 =~ /(\d+)/ ) {
                $pathway_oid = $1;
            }

            if ( !isInt($pathway_oid) ) {
                next;
            }

            $sql = qq{
		        select status from img_pathway_assertions
		        where pathway_oid = ?
		        and taxon = ?
		        order by mod_date desc
		};
            $cur = execSql( $dbh, $sql, $verbose, $pathway_oid, $taxon_oid );
            my ($st) = $cur->fetchrow();
            $cur->finish();
            if (    $st eq 'asserted'
                 || $st eq 'MANDATORY'
                 || $st =~ /FULL/ )
            {
                $c_res = 1;
            } elsif ( $st eq 'not asserted' ) {
                $c_res = 0;
            } else {

                # unknown
                $c_res = -1;
            }

            if ($not_flag) {

                # switch true and false
                if ( $c_res == 1 ) {
                    $c_res = 0;
                } elsif ( $c_res == 0 ) {
                    $c_res = 1;
                }
            }

            if ($r_type) {

                # OR rule with and-component
                if ( $c_res != 1 ) {
                    $r_res = 0;
                }

                if ( $r_res != 0 ) {
                    if ( $c_res == -1 ) {
                        $r_res = -1;
                    }
                }
            } else {

                # AND rule with or-component
                if ( $c_res == 1 ) {
                    $r_res = 1;
                }

                if ( $r_res != 1 ) {
                    if ( $c_res == -1 ) {
                        $r_res = -1;
                    }
                }
            }
        }    # end for c2

        if ($r_type) {

            # OR rule
            if ( $r_res == 1 ) {
                $res = 1;
            }

            if ( $res != 1 ) {
                if ( $r_res == -1 ) {
                    $res = -1;
                }
            }
        } else {

            # AND rule
            if ( $r_res != 1 ) {
                $res = 0;
            }

            if ( $res != 0 ) {
                if ( $r_res = -1 ) {
                    $res = -1;
                }
            }
        }
    }

    if ( $res == 1 ) {
        return 1;
    } else {
        return 0;
    }
}

sub getNCBIProjIdWhereClause {
    my ($dbh, @ncbi_proj_ids) = @_;

    my $ncbi_proj_id_conds = "where ";
    if ( scalar(@ncbi_proj_ids) > 0 ) {
        my $ncbi_pid_str = OracleUtil::getNumberIdsInClause( $dbh, @ncbi_proj_ids );
        $ncbi_proj_id_conds .= "tx.gbk_project_id in ( $ncbi_pid_str ) ";
    }

    return $ncbi_proj_id_conds;
}

1;
