############################################################################
#
# $Id: AnalysisProject.pm 31855 2014-09-05 03:51:52Z jinghuahuang $
############################################################################
package AnalysisProject;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use REST::Client;
use MIME::Base64;
use JSON;
use Storable;

use WebConfig;
use WebUtil;



my $section           = 'AnalysisProject';
my $env               = getEnv();
my $main_cgi          = $env->{main_cgi};
my $section_cgi       = "$main_cgi?section=$section";
my $base_dir          = $env->{base_dir};
my $base_url          = $env->{base_url};
my $verbose           = $env->{verbose};
my $gold_api_base_url = $env->{gold_api_base_url};
my $gold_auth_code    = $env->{gold_auth_code};
my $include_metagenomes      = $env->{include_metagenomes};

my $goldCacheDir = '/webfs/scratch/img/gold/';
my $isolateVisibilityFile = $goldCacheDir . 'isolateVisibility.bin';
my $metagenomeVisibilityFile = $goldCacheDir .'metagenomeVisibility.bin';

# cache of public Ga
my $globalVisibleHash_href;

my $timeout = 5; # gold api call timeout in seconds

# hash keys and ui label display name for metadata
my %keysToName = (
    goldProposalName           => 'Study Name (Proposal Name)',
    analysisProjectName        => 'Analysis Project Name',
    analysisProductName        => 'AP Product Name',
    visibility                 => 'Is Public',
    goldId                     => 'AP GOLD ID',
    goldAnalysisProjectType    => 'AP Type',
    itsSourceAnalysisProjectId => 'ITS Source AP ID',
    itsAnalysisProjectId       => 'ITS AP ID',

    ecosystem         => 'Ecosystem',
    ecosystemCategory => 'Ecosystem Category',
    ecosystemType     => 'Ecosystem Type',
    ecosystemSubtype  => 'Ecosystem Subtype',
    specificEcosystem => 'Specific Ecosystem',

    domain      => 'Domain',
    ncbiPhylum  => 'NCBI Phylum',
    ncbiClass   => 'NCBI Class',
    ncbiOrder   => 'NCBI Order',
    ncbiFamily  => 'NCBI Family',
    ncbiGenus   => 'NCBI Genus',
    ncbiSpecies => 'NCBI Species',

    piName              => 'PI Name',
    piEmail             => 'PI Email',
    submitterContactOid => '',

    projects => 'array of hashes',
);
my @keysOrder = (
                  'goldProposalName',        'analysisProjectName',
                  'analysisProductName',     'goldId',
                  'goldAnalysisProjectType', 'itsSourceAnalysisProjectId',
                  'itsAnalysisProjectId',    'projects',
                  'domain',                  'ncbiPhylum',
                  'ncbiClass',               'ncbiOrder',
                  'ncbiFamily',              'ncbiGenus',
                  'ncbiSpecies',             'ecosystem',
                  'ecosystemCategory',       'ecosystemType',
                  'ecosystemSubtype',        'specificEcosystem',
);

my %projectKeyToName = (
                         itsSpid    => 'ITS ID',
                         projectOid => 'IMG ER ID',
                         sampleOid  => 'IMG ER Sample ID',
);
my @projectNameOrder = ( 'itsSpid', 'projectOid', 'sampleOid' );

sub dispatch {
    my $page = param('page');

    if ( $page eq 'metadata' ) {
        getMetadataTest();
    } elsif ( $page eq 'metadata2' ) {
        my $dbh = WebUtil::dbLogin();
        printApMetadata( $dbh,  'Ga00002438' );
    }
}


# Is submission an analysis project
# return '' or analysis project id
#
sub isAnalysisProject {
    my ( $dbh, $submissionId ) = @_;
    my $sql = 'select analysis_project_id from submission where submission_id = ?';

    my $cur = execSql( $dbh, $sql, $verbose, $submissionId );
    my ($aid) = $cur->fetchrow();

    return $aid;
}

# to be use in the genome detail page to print the AP metadata section
sub printApMetadata {
    my ( $dbh, $apGoldId ) = @_;

    my $data_href = getMetadata($apGoldId);
    if ( $data_href eq '' ) {
        print qq{
            <p> GOLD AP Web Service is current down </p>
        };
        return;
    }

    # projects array of hashes
    my $projects_aref = $data_href->{projects};

    print "<table class='img'  border='1' >\n";
    print "<tr class='highlight'>\n";
    print "<th class='subhead'>" . "Analysis Project" . "</th> <th class='subhead'> &nbsp; </th></tr>\n";

    foreach my $key (@keysOrder) {
        if ( $key eq 'projects' ) {
            my $str;
            my $size = 0;
            foreach my $href (@$projects_aref) {
                foreach my $k2 (@projectNameOrder) {
                    my $label = $projectKeyToName{$k2};
                    my $value = $href->{$k2};
                    next if $value eq '';
                    $str .= "$label: $value ";
                }
                $str .= "<br> ";
                $size++;
            }
            print qq{
<tr class='img'>
<th class='subhead'> Combined AP ($size)</th>
<td class='img'>$str</td>
</tr>
            };
        } else {
            my $label = $keysToName{$key};
            my $value = $data_href->{$key};
            printAttrRow( $label, $value );
        }
    }
    
    # PI 'piName' 'piEmail'
    my $value = $data_href->{piName} . ' ' . $data_href->{piEmail};
    printAttrRow( 'PI', $value );
    
    # get contact info via contact oid
    my $contactOid = $data_href->{submitterContactOid};
    #$contactOid = 3038 if !$contactOid;
    my $value = getContactInfo($dbh, $contactOid);
    printAttrRow( 'Submitted By', $value );
    
    print "</table>\n";
}

sub getContactInfo {
    my($dbh, $contactOid) = @_;
    
    if(!$contactOid) {
        return '';
    }
    
    my $sql = qq{
select name, email from contact where contact_oid = ?
    };
    
    my $cur = execSql( $dbh, $sql, $verbose, $contactOid );
    my ($name, $email) = $cur->fetchrow();
    
    return "$name $email";    
}

#
# gets metadata for one analysis project via gold web service
#
#
# select * from submission
#where ANALYSIS_PROJECT_ID is not null;
#--'Ga0010876'
#
#select * from GOLD_ANALYSIS_PROJECT where GOLD_ANALYSIS_PROJECT_ID = 10876;
#
sub getMetadata {
    my ($goldId) = @_;

    my $headers = {
                    Content_Type  => 'application/json',
                    Accept        => 'application/json',
                    Authorization => 'Basic ' . $gold_auth_code
    };
    my $client = REST::Client->new();
    $client->setTimeout($timeout);
    $client->GET( $gold_api_base_url . 'gold_prod/rest/analysis_project/' . $goldId, $headers );
    my $status = $client->responseCode();

    if ( $status eq '200' ) {
        my $res = $client->responseContent();
        return decode_json($res);
    } else {
        return '';
    }
}

sub getMetadataTest {
    my $goldId = param('goldId');

    $goldId = 'Ga00002438' if ( $goldId eq '' );

    my $headers = {
                    Content_Type  => 'application/json',
                    Accept        => 'application/json',
                    Authorization => 'Basic ' . $gold_auth_code
    };
    my $client = REST::Client->new();
    $client->setTimeout($timeout);

    $client->GET( $gold_api_base_url . 'gold_prod/rest/analysis_project/' . $goldId, $headers );

    my $status = $client->responseCode();

    print "<p> $status <p>\n";

    if ( $status eq '200' ) {
        my $res = $client->responseContent();

        # TODO - error handling - not 200 or false
        print "<pre>\n";
        print Dumper decode_json($res);
        print "</pre>\n";

    } else {
        print qq{
          GOLD web service is down  
        };

    }
}


#
# read perl ref object array / hash etc on disk back to memory
#
sub readData {
    my ($file) = @_;
    my $ref = retrieve("$file");
    
    #print Dumper $ref;
    #print "\n";
    return $ref;
}

#
# hash of visiable Ga
#
sub getVisibilityData {
    if($globalVisibleHash_href ne '') {
        webLog("cached globalVisibleHash_href \n");
        return $globalVisibleHash_href;
    }

    if(!-e $isolateVisibilityFile) {
        my %empty;
        return \%empty;
    }
    
    # all vis is in one file
    my $iRef = readData($isolateVisibilityFile);
    
    
#    if($include_metagenomes && -e $metagenomeVisibilityFile) {
#        my $mRef = readData($metagenomeVisibilityFile);
#        my %newHash = (%$iRef, %$mRef);
#        $iRef = \%newHash; 
#    }
    
    webLog("new globalVisibleHash_href \n");
    $globalVisibleHash_href = $iRef;
    return $iRef;
}

1;
