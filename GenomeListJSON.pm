############################################################################
# $Id: GenomeListJSON.pm 32978 2015-03-10 17:43:42Z aratner $
#
# issues to fix
# 1. list name is static to genomeFilterSelection, tree view can be dynamic
#
# login site has private session json files
#
############################################################################
package GenomeListJSON;

use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use Data::Dumper;
use OracleUtil;
use JSON;
use HTML::Template;

my $section              = 'GenomeListJSON';
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $cgi_url              = $env->{cgi_url};
my $cgi_dir              = $env->{cgi_dir};
my $verbose              = $env->{verbose};
my $user_restricted_site = $env->{user_restricted_site};
my $img_internal         = $env->{img_internal};
my $include_metagenomes  = $env->{include_metagenomes};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $img_ken              = $env->{img_ken};
my $enable_workspace     = $env->{enable_workspace};
my $dir                  = WebUtil::getSessionDir($section);
$cgi_tmp_dir = $dir;

my $hideViruses = getSessionParam("hideViruses");
$hideViruses = "Yes" if $hideViruses eq "";

my $hidePlasmids = getSessionParam("hidePlasmids");
$hidePlasmids = "Yes" if $hidePlasmids eq "";

my $hideGFragment = getSessionParam("hideGFragment");
$hideGFragment = "Yes" if $hideGFragment eq "";

sub test {
    my $page = param('page');

    if ( $page eq '2' ) {
        printMainForm();
        my $xml_cgi = $cgi_url . '/xml.cgi';
        $include_metagenomes = 0 if ( $include_metagenomes eq "" );
        my $template = HTML::Template->new
	    ( filename => "$base_dir/genomeJsonTwoDiv.html" );
        
        # domain pick list options
        $template->param( isolate              => 1 );
        $template->param( include_metagenomes  => 1 );
        $template->param( gfr                  => 1 ) if ( $hideGFragment eq 'No' );
        $template->param( pla                  => 1 ) if ( $hidePlasmids eq 'No' );
        $template->param( vir                  => 1 ) if ( $hideViruses eq 'No' );
        $template->param( all                  => 1 );
        $template->param( cart                 => 1 );
        
        # ajax call base url
        $template->param( xml_cgi              => $xml_cgi );
        
        # it was used for t: and b: - but leave blank now
        $template->param( prefix               => '' );
        
        # display label for user's selected genomes sections
        $template->param( selectedGenome1Title => 'Find Genes In' );
        $template->param( selectedGenome2Title => 'With Homologs In' );
        
        # from which section
        # most cases its blank
        # from Gene Cassette profiler its the section name
        # the back end code will now restrict genomes by cassettes
        $template->param( from                 => '' );
        
        # max number of genomes a user can select -1 for no limit
        $template->param( maxSelected2         => -1 );
        # restrict user of what domain they can select 
        # "" - all
        # "isolate"
        # "metagenome"
        $template->param( domainType2         => '' );

        my $s = printMySubmitButtonXDiv( 'test', 'Submit', 'Submit' );
        $template->param( mySubmitButton => $s );

        print $template->output;

        print end_form();
    } else {
        printMainForm();
        my $xml_cgi = $cgi_url . '/xml.cgi';
        $include_metagenomes = 0 if ( $include_metagenomes eq "" );
        my $template = HTML::Template->new
	    ( filename => "$base_dir/genomeJsonThreeDiv.html" );
        $template->param( isolate              => 1 );
        $template->param( include_metagenomes  => 1 );
        $template->param( gfr                  => 1 ) if ( $hideGFragment eq 'No' );
        $template->param( pla                  => 1 ) if ( $hidePlasmids eq 'No' );
        $template->param( vir                  => 1 ) if ( $hideViruses eq 'No' );
        $template->param( all                  => 1 );
        $template->param( cart                 => 1 );
        $template->param( xml_cgi              => $xml_cgi );
        $template->param( prefix               => '' );
        $template->param( selectedGenome1Title => 'Find Genes In' );
        $template->param( selectedGenome2Title => 'With Homologs In (isolate)' );
        $template->param( selectedGenome3Title => 'Without Homologs In (metagenome)' );
        $template->param( from                 => '' );
        $template->param( maxSelected2         => 5 );
        $template->param( maxSelected3         => -1 );
        
	$template->param( domainType1         => 'isolate' ); # test of only adding isolates        
	$template->param( domainType2         => 'isolate' ); # test of only adding isolates
	$template->param( domainType3         => 'metagenome' ); # test of only adding metagenome
	
        my $s = printMySubmitButtonXDiv( 'test', 'Submit', 'Submit' );
        $template->param( mySubmitButton => $s );

        print $template->output;
        print end_form();
    }
}

sub dispatch {
    my $page = param('page');
    if ( $page eq 'json' ) {
        printJSONFile();
    }
}

# for user login sites
#
# see taxonsJavascriptArray.pl on how public data json files are created
#
sub createJSONFiles {
    my $dbh            = WebUtil::dbLogin();
    my $urClause       = urClause('t');
    my $taxon_json_dir = $cgi_tmp_dir;

    webLog("============ $taxon_json_dir\n");

    my $outputFile1  = "$taxon_json_dir/taxonArrayBacAll.js";
    my $outputFile2  = "$taxon_json_dir/taxonArrayArcAll.js";
    my $outputFile3  = "$taxon_json_dir/taxonArrayEukAll.js";
    my $outputFile4  = "$taxon_json_dir/taxonArrayGFrAll.js";
    my $outputFile5  = "$taxon_json_dir/taxonArrayPlaAll.js";
    my $outputFile6  = "$taxon_json_dir/taxonArrayVirAll.js";
    my $outputFile7  = "$taxon_json_dir/taxonArrayMetAll.js";
    my $outputFile8  = "$taxon_json_dir/taxonArrayAllWAll.js";      # for tree
    my $outputFile9  = "$taxon_json_dir/taxonArrayAllMAll.js";      # for tree
    my $outputFile10 = "$taxon_json_dir/taxonArrayAllWAllList.js";  # for list
    my $outputFile11 = "$taxon_json_dir/taxonArrayAllMAllList.js";  # for list

    # all bacteria
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
and t.genome_type = 'isolate'
and t.domain = 'Bacteria'
order by t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile1, $isoate_aref );

    # all Archaea
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
and t.genome_type = 'isolate'
and t.domain = 'Archaea'
order by t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile2, $isoate_aref );

    # all Eukaryota
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
and t.genome_type = 'isolate'
and t.domain = 'Eukaryota'
order by t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile3, $isoate_aref );

    # all GFragment
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
and t.genome_type = 'isolate'
and t.domain like 'GFragment%'
order by t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile4, $isoate_aref );

    # all Plasmid
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
and t.genome_type = 'isolate'
and t.domain like 'Plasmid%'
order by t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile5, $isoate_aref );

    # all Virus
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
and t.genome_type = 'isolate'
and t.domain like 'Vir%'
order by t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile6, $isoate_aref );

    # all *Microbiome
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
and t.genome_type = 'metagenome'
and t.domain = '*Microbiome'
order by t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile7, $isoate_aref );

    # all isolate - tree view
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
and t.genome_type = 'isolate'
order by t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile8, $isoate_aref );

    # all isolate and metagenomes - tree view
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
order by t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile9, $isoate_aref );

    # all isolate - list view
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
and t.genome_type = 'isolate'
order by t.domain, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile10, $isoate_aref );

    # all isolate and metagenomes - list view
    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
order by t.domain, t.taxon_display_name 
    };
    my $isoate_aref = getTaxon( $dbh, $sql );
    createFile( $outputFile11, $isoate_aref );

    $env->{taxon_json_bac}      = "$taxon_json_dir/taxonArrayBac.js";
    $env->{taxon_json_arc}      = "$taxon_json_dir/taxonArrayArc.js";
    $env->{taxon_json_euk}      = "$taxon_json_dir/taxonArrayEuk.js";
    $env->{taxon_json_gfr}      = "$taxon_json_dir/taxonArrayGFr.js";
    $env->{taxon_json_pla}      = "$taxon_json_dir/taxonArrayPla.js";
    $env->{taxon_json_vir}      = "$taxon_json_dir/taxonArrayVir.js";
    $env->{taxon_json_met}      = "$taxon_json_dir/taxonArrayMet.js";
    $env->{taxon_json_allw}     = "$taxon_json_dir/taxonArrayAllW.js";    #tree
    $env->{taxon_json_allm}     = "$taxon_json_dir/taxonArrayAllM.js";    #tree
    $env->{taxon_json_allwlist} = "$taxon_json_dir/taxonArrayAllWList.js";#list
    $env->{taxon_json_allmlist} = "$taxon_json_dir/taxonArrayAllMList.js";#list
}

sub getCassetteTaxons {
    my ( $dbh, $goodTaxons_href ) = @_;

    my $sql = qq{
select taxon_oid
from taxon_stats
where nvl(total_cassettes, 0) > 0
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $goodTaxons_href->{$taxon_oid} = $taxon_oid;
    }
}

sub getOnlyMetagenomes {
    my ( $dbh, $goodTaxons_href ) = @_;
    my $urClause  = urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause('t');
    
    my $sql = qq{
select t.taxon_oid
from taxon t
where t.genome_type = 'metagenome'
$urClause
$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $goodTaxons_href->{$taxon_oid} = $taxon_oid;
    }

}

sub getOnlyDistanceGenomes {
    my ( $dbh, $goodTaxons_href ) = @_;
    my $urClause  = urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
select t.taxon_oid
from taxon t
where t.distmatrix_date is not null
$urClause
$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $goodTaxons_href->{$taxon_oid} = $taxon_oid;
    }
}

sub getOnlyScaffoldSearchGenomes {
    my ( $dbh, $goodTaxons_href ) = @_;
    my $urClause  = urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause('t');
    
    my $sqlm;
    if ($include_metagenomes) {
       $sqlm = qq{
select taxon_oid
from TAXON_STATS_MERFS
where datatype = 'assembled'
union 
       };
    }
    
    my $sql = qq{
$sqlm        
select t.taxon_oid
from taxon t
where t.genome_type = 'isolate'
$urClause
$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $goodTaxons_href->{$taxon_oid} = $taxon_oid;
    }    
}

#
# AJAX call to get json file and to be printed as plain text
#
sub printJSONFile {
    my $displayType = param('displayType');     # tree or list
    my $domainType  = param('domainfilter');    # Archaea, Bacteria Eukaryota *Microbiome GFr Pla Vir All cart
    my $seq_status  = param('seqstatus');       # both, Finished, Permanent Draft, Draft

    # TODO - from which form
    # eg cassatte show only genomes with cassette data
    my %goodTaxons;
    my $from = param('from');
    my $dbh  = WebUtil::dbLogin();
    if ( $from eq 'GeneCassetteProfiler' || $from eq 'GeneCassetteSearch') {
        getCassetteTaxons( $dbh, \%goodTaxons );
    } elsif ($from eq 'MetagPhyloDist') {
        getOnlyMetagenomes( $dbh, \%goodTaxons );
    } elsif ($from eq 'DistanceTree') {
        getOnlyDistanceGenomes($dbh, \%goodTaxons);
    } elsif ($from eq 'ScaffoldSearch') {
        getOnlyScaffoldSearchGenomes($dbh, \%goodTaxons);
    }

    my $super_user = getSuperUser();
    my %validTaxons;
    # create session specific taxon json objects.
    if ($user_restricted_site) {
        
        webLog("======== $super_user\n");
        
        if ( $super_user ne "Yes" ) {
            %validTaxons = WebUtil::getAllTaxonsHashed($dbh);
            my $size = keys %validTaxons;
            webLog("======== got all taxon hash $size\n");
        }

        # '/webfs/projectdirs/microbial/img/web_data/taxon_json'
        my $taxon_json_dir =  $env->{taxon_json_dir};  #$cgi_tmp_dir;
        $env->{taxon_json_bac}      = "$taxon_json_dir/taxonArrayBacAll.js";
        $env->{taxon_json_arc}      = "$taxon_json_dir/taxonArrayArcAll.js";
        $env->{taxon_json_euk}      = "$taxon_json_dir/taxonArrayEukAll.js";
        $env->{taxon_json_gfr}      = "$taxon_json_dir/taxonArrayGFrAll.js";
        $env->{taxon_json_pla}      = "$taxon_json_dir/taxonArrayPlaAll.js";
        $env->{taxon_json_vir}      = "$taxon_json_dir/taxonArrayVirAll.js";
        $env->{taxon_json_met}      = "$taxon_json_dir/taxonArrayMetAll.js";
        $env->{taxon_json_allw}     = "$taxon_json_dir/taxonArrayAllWAll.js";        # for tree
        $env->{taxon_json_allm}     = "$taxon_json_dir/taxonArrayAllMAll.js";        # for tree
        $env->{taxon_json_allwlist} = "$taxon_json_dir/taxonArrayAllWAllList.js";    # for list
        $env->{taxon_json_allmlist} = "$taxon_json_dir/taxonArrayAllMAllList.js";    # for list

        # file test
#        if ( !-e $env->{taxon_json_bac} ) {
#            createJSONFiles();
#        }
    }

    # what if vir and pal and gfr are hidden - filter out in "All" selection
    # for cart see if anything in genome cart
    my $file;
    if ( $domainType eq 'All' && $displayType eq 'tree' ) {
        if ($include_metagenomes) {
            $file = $env->{taxon_json_allm};
        } else {
            $file = $env->{taxon_json_allw};
        }
    } elsif ( $domainType eq 'All' && $displayType eq 'list' ) {
        if ($include_metagenomes) {
            $file = $env->{taxon_json_allmlist};
        } else {
            $file = $env->{taxon_json_allwlist};
        }
    } elsif ( $domainType eq 'Archaea' ) {
        $file = $env->{taxon_json_arc};
    } elsif ( $domainType eq 'Bacteria' ) {
        $file = $env->{taxon_json_bac};
    } elsif ( $domainType eq 'Eukaryota' ) {
        $file = $env->{taxon_json_euk};
    } elsif ( $domainType eq '*Microbiome' ) {
        $file = $env->{taxon_json_met};
    } elsif ( $domainType eq 'GFr' ) {
        $file = $env->{taxon_json_gfr};
    } elsif ( $domainType eq 'Pla' ) {
        $file = $env->{taxon_json_pla};
    } elsif ( $domainType eq 'Vir' ) {
        $file = $env->{taxon_json_vir};
    } elsif ( $domainType eq 'cart' ) {

        # read cart and query db
        require GenomeCart;
        my $taxon_oids_aref = GenomeCart::getAllGenomeOids();

        if ( $#$taxon_oids_aref < 0 ) {
            print "[]";
            exit 0;
        }

        $file = $cgi_tmp_dir . "/myCartJson.js";
        
        #webLog("here 1 ==== \n");
        
        createCartFile( $file, $taxon_oids_aref );
        
        #webLog("here 2 ==== \n");
    }

    webLog(" ==== $file \n");
    my $rfh       = WebUtil::newReadFileHandle($file);
    my $json_text = '';
    while ( my $line = $rfh->getline() ) {
        $json_text = $json_text . $line;

    }
    close $rfh;

# good for debugging - ken
# use FF and json viewer plugin
# - it should dump the line number of error
#
#print $json_text;
#exit;

    my @decoded_json = @{ decode_json($json_text) };
    my @good;
    foreach my $aref (@decoded_json) {
        if ( $domainType ne 'cart' ) {
            my $taxon_oid = $aref->[0];
            my $domain    = $aref->[2];
            my $seqstatus = $aref->[9];
            next if ( $domainType eq 'All' && $hideViruses   eq "Yes" && $domain =~ /Vir/ );
            next if ( $domainType eq 'All' && $hidePlasmids  eq "Yes" && $domain =~ /Pla/ );
            next if ( $domainType eq 'All' && $hideGFragment eq "Yes" && $domain =~ /GFr/ );
            next if ( $seq_status ne 'both' && $seqstatus ne $seq_status );
            next if ( $from ne '' && !exists $goodTaxons{$taxon_oid} );
            if ($user_restricted_site && $super_user ne "Yes" ) {
                if (!$validTaxons{$taxon_oid}) {
                    # user is not allowed to see this taxon
                    next;
                } 
            }            
            
        } elsif ($domainType eq 'cart' ) {
            my $taxon_oid = $aref->[0];
            my $seqstatus = $aref->[9];
            #next if ( !exists $goodTaxons{$taxon_oid} );
            next if ( $seq_status ne 'both' && $seqstatus ne $seq_status );
            next if ( $from ne '' && !exists $goodTaxons{$taxon_oid} );
        }
        push( @good, $aref );
    }

    if ( $domainType ne 'All' && $displayType eq 'list' ) {

        # for list sort by taxon name - for tree view DO NOT sort - ken
        @good = sort { lc( $a->[1] ) cmp lc( $b->[1] ) } @good;
    }

    print encode_json( \@good );
}

sub createCartFile {
    my ( $file, $taxon_oids_aref ) = @_;

    my $dbh = WebUtil::dbLogin();

    my $urClause = urClause('t');
    OracleUtil::insertDataArray( $dbh, 'gtt_num_id', $taxon_oids_aref );

    my $sql = qq{
select t.taxon_oid, t.taxon_display_name,
  t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.seq_status
from taxon t
where t.obsolete_flag = 'No'
$urClause
and t.taxon_oid in (select id from gtt_num_id)
order by t.domain, t.phylum,  t.ir_class,  t.ir_order,
  t.family, t.genus, t.species, t.taxon_display_name 
    };

    my $data_aref = getTaxon( $dbh, $sql );
    createFile( $file, $data_aref );
}

sub createFile {
    my ( $filename, $data_aref ) = @_;
    my $wfh = newWriteFileHandle($filename);
    print $wfh "[\n";

    for ( my $i = 0 ; $i <= $#$data_aref ; $i++ ) {
        my $line = $data_aref->[$i];
        my @a    = split( /\t/, $line );
        my $str  = join( '","', @a );
        print $wfh "[\"$str\"]";
        if ( $i < $#$data_aref ) {
            print $wfh ",\n";
        } else {
            print $wfh "\n";
        }
    }
    print $wfh "]\n";
    close $wfh;
}

sub getTaxon {
    my ( $dbh, $sql ) = @_;

    my @data;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
             $seq_status ) = $cur->fetchrow();
        last if ( !$taxon_oid );

        chomp $taxon_display_name;
        chomp $domain;
        chomp $phylum;
        chomp $ir_class;
        chomp $ir_order;
        chomp $family;
        chomp $genus;
        chomp $species;
        chomp $seq_status;


        $taxon_display_name =~ s/^\W+//g;
        $taxon_display_name =~ s/"//g;
        $taxon_display_name =~ s/'//g;
        $taxon_display_name =~ s/\t/ /g;
        $taxon_display_name = CGI::escapeHTML($taxon_display_name);

        $domain   =~ s/"//g;
        $domain   =~ s/'//g;
        $domain =~ s/\t/ /g;
        
        $phylum   =~ s/"//g;
        $phylum   =~ s/'//g;
        $phylum =~ s/\t/ /g;
        
        $ir_class =~ s/"//g;
        $ir_class =~ s/'//g;
        $ir_class =~ s/\t/ /g;
        
        $ir_order =~ s/"//g;
        $ir_order =~ s/'//g;
        $ir_order =~ s/\t/ /g;
        
        $family   =~ s/"//g;
        $family   =~ s/'//g;
        $family =~ s/\t/ /g;
        
        $genus    =~ s/"//g;
        $genus    =~ s/'//g;
        $genus =~ s/\t/ /g;
        
        $species  =~ s/"//g;
        $species  =~ s/'//g;
        $species =~ s/\t/ /g;

         if ( $domain   eq '' ) {
            $domain   = 'unclassified';
         } else {
             $domain = CGI::escapeHTML($domain);
         }
         if ( $phylum   eq '' ) {
            $phylum   = 'unclassified';
         } else {
             $phylum = CGI::escapeHTML($phylum);
         }
         if ( $ir_class   eq '' ) {
            $ir_class   = 'unclassified';
         } else {
             $ir_class = CGI::escapeHTML($ir_class);
         }
         if ( $ir_order   eq '' ) {
            $ir_order   = 'unclassified';
         } else {
             $ir_order = CGI::escapeHTML($ir_order);
         }
         if ( $family   eq '' ) {
            $family   = 'unclassified';
         } else {
             $family = CGI::escapeHTML($family);
         }
         if ( $genus   eq '' ) {
            $genus   = 'unclassified';
         } else {
             $genus = CGI::escapeHTML($genus);
         }
         if ( $species   eq '' ) {
            $species   = 'unclassified';
         } else {
             $species = CGI::escapeHTML($species);
         }
         
        push( @data,
"$taxon_oid\t$taxon_display_name\t$domain\t$phylum\t$ir_class\t$ir_order\t$family\t$genus\t$species\t$seq_status"
        );
    }
    $cur->finish();
    return \@data;
}

#
#
# $showOnly - TODO show only some types of genomes values
#       isolate - show only isolate no genomes, all isolate and cart isolate - i must pass it to ajax call too?
#       metagenome - show only metagenome , no all, and cart metagenome only - i must pass it to ajax call too?
#
sub printGenomeListJsonDiv {
    my ( $prefix, $showOnly ) = @_;
    my $xml_cgi = $cgi_url . '/xml.cgi';
    $include_metagenomes = 0 if ( $include_metagenomes eq "" );
    my $template = HTML::Template->new( filename => "$base_dir/genomeJson.html" );
    $template->param( isolate             => 1 );
    $template->param( include_metagenomes => $include_metagenomes );
    $template->param( gfr                 => 1 ) if ( $hideGFragment eq 'No' );
    $template->param( pla                 => 1 ) if ( $hidePlasmids eq 'No' );
    $template->param( vir                 => 1 ) if ( $hideViruses eq 'No' );
    $template->param( all                 => 1 );
    $template->param( cart                => 1 );
    $template->param( xml_cgi             => $xml_cgi );

    # TODO - for some forms show only metagenome or show only islates
    $template->param( from => '' );

    # prefix
    $template->param( prefix => $prefix );
    print $template->output;
}

sub printHiddenInputType {
    my ( $section, $page ) = @_;
    print hiddenVar( "section", $section );
    print hiddenVar( "page",    $page );

    print qq{
    <input type='hidden' id='paramMatchJson' name='$page' value='$page' />
    };
}

sub printMySubmitButton {
    my ( $id, $name, $value, $title, $section, $page, $class, $form_id ) = @_;

    print "<input type='button' ";
    print qq{ id="$id" } if ( $id ne '' );
    if ( $class ne '' ) {
        print qq{ class="$class" };
    } else {
        print qq{ class="meddefbutton" };
    }
    print qq{ value="$value" } if ( $value ne '' );
    print qq{ name="$name" }   if ( $name  ne '' );
    print qq{ title="$title" } if ( $title ne '' );
    print qq{ onclick="mySubmitJson('$section', '$page', '$form_id' );" >};
}

sub printMySubmitButtonBlast {
    my ( $id, $name, $value, $title, $section, $page, $class ) = @_;

    print "<input type='button' ";
    print qq{ id="$id" } if ( $id ne '' );
    if ( $class ne '' ) {
        print qq{ class="$class" };
    } else {
        print qq{ class="meddefbutton" };
    }
    print qq{ value="$value" } if ( $value ne '' );
    print qq{ name="$name" }   if ( $name  ne '' );
    print qq{ title="$title" } if ( $title ne '' );
    print qq{ onclick="mySubmitJsonBlast('$section', '$page' );" >};
}

sub cleanTaxonOid {
    my @oids = @_;
    my @clean;
    foreach my $id (@oids) {
        $id =~ s/t://;
        $id =~ s/b://;
        push( @clean, $id );
    }
    return @clean;
}

#
# does not print returns a string to print
#
sub printMySubmitButtonXDiv {
    my ( $id, $name, $value, $title, $section, $page, $class,
	 $el1, $min1, $el2, $min2, $form_id ) = @_;

    my $s = "<input type='button' ";
    $s .= qq{ id="$id" } if ( $id ne '' );
    if ( $class ne '' ) {
        $s .= qq{ class="$class" };
    } else {
        $s .= qq{ class="meddefbutton" };
    }
    $s .= qq{ value="$value" } if ( $value ne '' );
    $s .= qq{ name="$name" }   if ( $name  ne '' );
    $s .= qq{ title="$title" } if ( $title ne '' );
    $s .= qq{ onclick="mySubmitWithCheck('$section', '$page', '$el1', '$min1', '$el2', '$min2', '$form_id' );" >};

    return $s;
}


# pre-select the genome cart and show genes
# this javacsript call show be called at the end see GenomeHits::printForm3();
#
sub showGenomeCart {
    my ($numTaxon) = @_;
    return if ($numTaxon eq '' || $numTaxon < 1);
    
    print qq{
    <script language="javascript">
    var obj = document.getElementById('domainfilter');
    selectItemByValue(obj, 'cart');

    var obj = document.getElementById('seqstatus');
    selectItemByValue(obj, 'both');
    
    document.getElementById('showButton').click();
    </script>        
    };
}

# from blast from genome detail page
# - seq status - All
# I need taxon oid and domain
# Archaea
# <option value="Bacteria">Bacteria</option>
#<option value="Eukaryota">Eukaryota</option>
#<option value="GFr">GFragment</option>
#<option value="Pla">Plasmid</option>
#<option value="Vir">Viruses</option>
#<option value="All">All (Slow)</option>
#<option value="cart">Genome Cart</option>
sub preSelectGenome {
    my($taxon_oid, $domain) = @_;
    return if ($taxon_oid eq '' || $domain eq '');
 
    if ($domain =~ /^GF/) {
        $domain = 'GFr';
    } elsif ($domain =~ /^Pla/) {
        $domain = 'Pla';
    } elsif ($domain =~ /^Vir/) {
        $domain = 'Vir';
    } elsif ($domain =~ /^Meta/) {
        $domain = '*Microbiome';
    }

#    var obj = document.getElementById('tax');
#    selectItemByValue(obj, '$taxon_oid');
    
    print qq{
    <input id="blastTaxonOid" type="hidden" value="$taxon_oid" name="blastTaxonOid">
    <script language="javascript">
        var obj = document.getElementById('domainfilter');
        selectItemByValue(obj, '$domain');

        var obj = document.getElementById('seqstatus');
        selectItemByValue(obj, 'both');

        document.getElementById('showButton').click();
    </script>
    };  
}

sub printAutoComplete {
    my ($myinput, $mycontainer) = @_;

    my $autocomplete_url = getMyAutoCompleteUrl();
    if ($autocomplete_url eq "") {
	my $top_base_url  = $env->{top_base_url};
        $autocomplete_url = "$top_base_url" . "api/";
        if ($include_metagenomes) {
            $autocomplete_url .= 'autocompleteAll.php';
        } else {
            $autocomplete_url .= 'autocompleteIsolate.php';
        }
    }

    print qq{
    <script type="text/javascript">
    YAHOO.util.Event.addListener(window, "load", function() {
        YAHOO.example.BasicRemote = function() {
            // Use an XHRDataSource
            var oDS = new YAHOO.util.XHRDataSource("$autocomplete_url");
            // Set the responseType
            oDS.responseType = YAHOO.util.XHRDataSource.TYPE_TEXT;
            // Define the schema of the delimited results
            oDS.responseSchema = {
                  recordDelim: "\\n",
                  fieldDelim: "\\t"
            };
            // Enable caching
            oDS.maxCacheEntries = 5;

            // Instantiate the AutoComplete
            var oAC = new YAHOO.widget.AutoComplete
                ("$myinput", "$mycontainer", oDS);

            return {
              oDS: oDS,
              oAC: oAC
            };
        }();
    });
    </script>
    };
}

# with private genomes included
# the file does not exists for w and m sites
sub getMyAutoCompleteFile {
    if ($user_restricted_site && $enable_workspace) {
        my $dir = WebUtil::getSessionTmpDir();
        my $myGenomesFile = $dir . '/myAutocompleteAll.php';
        return $myGenomesFile;
    } else {
        return "";
    }
}

sub getMyAutoCompleteUrl {
    if ($user_restricted_site && $enable_workspace) {
        my $url = WebUtil::getSessionTmpDirUrl();
        my $myGenomesUrl = $url . '/myAutocompleteAll.php';
        return $myGenomesUrl;
    } else {
        return "";
    }    
}

# currently this is just for ANI, so no metagenomes ...
sub myAutoCompleteGenomeList {
    my ($myGenomesFile) = @_;
    my $dbh = WebUtil::dbLogin();
    
    my $urClause = urClause('t');
    my $taxonClause;
    $taxonClause = " and t.genome_type != 'metagenome' ";

    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name
        from taxon t
        where obsolete_flag = 'No'
        $urClause
        $taxonClause
        order by t.taxon_display_name             
    };
    
    my %hash;
    use MerFsUtil;
    my %taxons_in_file = MerFsUtil::getTaxonsInFile($dbh);
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
        my ( $taxon_oid, $name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
	next if ( $taxons_in_file{$taxon_oid} ); # not for metagenomes
        $name =~ s/^\W+//g;
        $name =~ s/"//g;
        $name =~ s/'//g;
        my $letter = lc( substr( $name, 0, 1 ) );
        if ( exists $hash{$letter} ) {
            my $aref = $hash{$letter};
            push( @$aref, "$name\t$taxon_oid" );
        } else {
            my @a = ("$name\t$taxon_oid");
            $hash{$letter} = \@a;
        }
    }
    
    createPhpFile( $myGenomesFile, \%hash );
}

sub createPhpFile {
    my ( $filename, $data_href ) = @_;

    my $str;
    my $size  = keys %$data_href;
    my $count = 0;
    foreach my $letter ( sort keys %$data_href ) {
        my $aref = $data_href->{$letter};
        $str .= "'$letter' => array(\n";

        foreach my $name (@$aref) {
            $str .= qq{"$name",\n};
        }

        $count++;
        if ( $size == $count ) {
            $str .= ")\n";
        } else {
            $str .= "),\n";
        }
    }

    my $temp;
    my $rfh   = newReadFileHandle("$cgi_dir/autocomplete_templ.txt");

    while ( my $line = $rfh->getline() ) {
        #chomp $line;
        $temp .= $line;
    }
    close $rfh;

    my $wfh = newWriteFileHandle($filename);
    $temp =~ s/__array__/$str/;

    print $wfh $temp;
    close $wfh;
    
    chmod( 0777, $filename );
}

1;

