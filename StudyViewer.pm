############################################################################
#
# $Id: StudyViewer.pm 32378 2014-12-03 22:17:10Z klchu $
############################################################################
package StudyViewer;
use strict;
use CGI qw( :standard );
use CGI::Cookie;
use DBI;
use WebUtil;
use WebConfig;
use TreeNode;
use TreeNode2;
use Data::Dumper;
use InnerTable;
use HtmlUtil;

my $section             = "StudyViewer";
my $env                 = getEnv();
my $main_cgi            = $env->{main_cgi};
my $base_url            = $env->{base_url};
my $section_cgi         = "$main_cgi?section=$section";
my $verbose             = $env->{verbose};
my $base_dir            = $env->{base_dir};
my $img_internal        = $env->{img_internal};
my $tmp_dir             = $env->{tmp_dir};
my $web_data_dir        = $env->{web_data_dir};
my $img_hmp             = $env->{img_hmp};
my $include_metagenomes = $env->{include_metagenomes};
my $rdbms               = getRdbms();
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};
my $YUI                 = $env->{yui_dir_28};

my $dir2 = WebUtil::getSessionDir();
$dir2 .= "/$section";
if ( !( -e "$dir2" ) ) {
    mkdir "$dir2" or webError("Can not make $dir2!");
}
$cgi_tmp_dir = $dir2;

$| = 1;

sub dispatch {
    my $page = param('page');
    if ( $page eq 'yui' ) {

        # TODO javascript tree viewer
        printViewer();
    } elsif ( $page eq 'sampletableview' ) {
        printHtmlSampleTableViewer();
    } elsif ( $page eq 'sampletaxonlist' ) {
        printSampleGenomeList();

    } elsif ( $page eq 'tableviewisolate' ) {
        printIsolateTableViewer();

    } elsif ( $page eq 'isolatelist' ) {
        printIsolatelist();

    } elsif ( $page eq 'tableview' ) {
        printHtmlTableViewer();
    } elsif ( $page eq 'samplelist' ) {
        printSampleList();
    } elsif ( $page eq 'datasetlist' ) {
        printGenomeList();

    } elsif ( $page eq 'projectlist' ) {
        printProjectSampleList();
    } else {

        # plain html tree
        printHtmlTreeViewer();
    }
}

sub printProjectSampleList {
    my $projectId = param('projectid');

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
select p.display_name
from project_info\@imgsg_dev p
where p.project_oid = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $projectId );
    my ($study_name) = $cur->fetchrow();
    $cur->finish();
    print qq{
        <h1> Study Samples Viewer </h1>
        <h3>$study_name</h3>
        <p>
        Sample Ids with duplicates are shown in <font color='red'>RED</font>
    };

    my $urClause  = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{

select t.taxon_oid, t.taxon_display_name, sub.submission_id, sub.sample_oid, env.sample_display_name, env.gold_id
from  taxon t, submission\@imgsg_dev sub, env_sample\@imgsg_dev env
where t.submission_id =  sub.submission_id
and sub.sample_oid = env.sample_oid
and sub.project_info = ?
$urClause
$imgClause
union 
select t.taxon_oid, t.taxon_display_name, nvl(t.submission_id, -1), env.sample_oid, env.sample_display_name, env.gold_id
from  taxon t, env_sample\@imgsg_dev env
where t.sample_gold_id = env.gold_id
and env.project_info = ?
$urClause
$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $projectId, $projectId );

    my @data;
    my %sampleIdCount;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $submission_id, $sample_oid, $sample_display_name, $gold_id ) =
          $cur->fetchrow();
        last if !$taxon_oid;
        my $str = "$taxon_oid\t$taxon_display_name\t$submission_id\t$sample_oid\t$sample_display_name\t$gold_id";
        push( @data, $str );

        if ( exists $sampleIdCount{$sample_oid} ) {
            $sampleIdCount{$sample_oid} = $sampleIdCount{$sample_oid} + 1;
        } else {
            $sampleIdCount{$sample_oid} = 1;
        }
    }

    my $txTableName = "projectsampletable";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 0 );
    my $sd          = $it->getSdDelim();
    $it->addColSpec( 'Sample Name (IMG)', "char asc", "left" );
    $it->addColSpec( "Submission ID",     "num asc",  "right" );
    $it->addColSpec( "Sample ID",         "num asc",  "right" );
    $it->addColSpec( 'Sample Name',       "char asc", "left" );
    $it->addColSpec( 'Sample GOLD ID',    "char asc", "left" );
    my $cnt = 0;

    foreach my $line (@data) {
        my ( $taxon_oid, $taxon_display_name, $submission_id, $sample_oid, $sample_display_name, $gold_id ) =
          split( /\t/, $line );
        $cnt++;

        my $r;
        my $url = alink( "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid", $taxon_display_name );
        $r .= $taxon_display_name . $sd . "$url\t";

        if ( $submission_id == -1 ) {
            $r .= ' ' . $sd . " \t";
        } else {
            my $url = alink(
"https://img.jgi.doe.gov/cgi-bin/submit/main.cgi?section=MSubmission&page=displaySubmission&submission_id=$submission_id",
                $submission_id
            );
            $r .= $submission_id . $sd . "$url\t";
        }

        if ( $sampleIdCount{$sample_oid} > 1 ) {
            $r .= $sample_oid . $sd . "<font color='red'>$sample_oid</font>\t";
        } else {
            $r .= $sample_oid . $sd . "$sample_oid\t";
        }

        $r .= $sample_display_name . $sd . "$sample_display_name\t";

        my $url = HtmlUtil::getGoldUrl($gold_id);
        $url = alink( $url, $gold_id );
        $r .= $gold_id . $sd . "$url\t";

        $it->addRow($r);
    }

    $it->printOuterTable(1);

    printStatusLine( "$cnt Loaded.", 2 );
}

sub printSampleList {
    my $projectId = param('projectid');

    my $urClause  = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my @bind = ( $projectId, $projectId );
    my $projectClause = "and p.project_oid = ? ";
    if ( !$projectId || $projectId =~ /^Gm/ || $projectId eq 'n/a' ) {
        $projectClause = "and p.project_oid is null";
        @bind          = ();
    }

    printStatusLine( "Loading ...", 1 );
    my $sql = qq{
select p.project_oid, p.display_name, nvl(t.gold_id, 'n/a'),
nvl(t.sample_gold_id, 'n/a'), e.sample_display_name, 
t.taxon_oid, t.taxon_display_name
from taxon t, env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.obsolete_flag = 'No'
and t.genome_type = 'metagenome'
and t.gold_id = p.gold_stamp_id(+)
and t.sample_gold_id = e.gold_id(+)
$projectClause
$urClause
$imgClause
union
select p.project_oid, p.display_name, nvl(t.gold_id, 'n/a'),
nvl(t.sample_gold_id, 'n/a'), e.sample_display_name, 
t.taxon_oid, t.taxon_display_name
from taxon t, submission\@imgsg_dev s,  env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.obsolete_flag = 'No'
and t.genome_type = 'metagenome'
and t.submission_id = s.submission_id
and s.project_info = p.project_oid
and s.sample_oid = e.sample_oid
$projectClause
$urClause
$imgClause
    };

    my %sampleId2Name;
    my %sampleId2GenomeCnt;
    my $title;
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @bind );
    for ( ; ; ) {
        my ( $project_info, $display_name, $projectGoldId, $gold_id, $sampleName, $taxon_oid, $taxon_display_name ) =
          $cur->fetchrow();
        last if !$taxon_oid;
        $title = $display_name;
        $sampleId2Name{$gold_id} = $sampleName;
        if ( exists $sampleId2GenomeCnt{$gold_id} ) {
            $sampleId2GenomeCnt{$gold_id} = $sampleId2GenomeCnt{$gold_id} + 1;
        } else {
            $sampleId2GenomeCnt{$gold_id} = 1;
        }
    }

    print qq{
        <h1>Sample List</h1>
        <h2>$title</h2>
    };

    my $txTableName = "studytable";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 0 );
    my $sd          = $it->getSdDelim();

    $it->addColSpec( 'Sample Name',    "char asc", "left" );
    $it->addColSpec( 'Sample GOLD ID', "char asc", "left" );
    $it->addColSpec( "Data Set Count", "num asc",  "right" );

    foreach my $goldId ( keys %sampleId2Name ) {
        my $sampleName = $sampleId2Name{$goldId};
        my $dataCnt    = $sampleId2GenomeCnt{$goldId};
        my $url = HtmlUtil::getGoldUrl($goldId);
        $url        = alink( $url, $goldId );
        my $r;
        $r .= $sampleName . $sd . "$sampleName\t";
        if ( $goldId ne 'n/a' ) {
            $r .= $goldId . $sd . $url . "\t";
        } else {
            $r .= $goldId . $sd . $goldId . "\t";
        }
        my $url =
          alink( "main.cgi?section=StudyViewer&page=datasetlist&projectid=$projectId&sampleGoldId=$goldId", $dataCnt );
        $r .= $dataCnt . $sd . "$url\t";

        $it->addRow($r);
    }
    $it->printOuterTable(1);

    my $count = keys %sampleId2Name;
    printStatusLine( "$count Loaded.", 2 );
}

sub printGenomeList {
    my $projectId    = param('projectid');
    my $sampleGoldId = param('sampleGoldId');

    my $urClause  = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my @bind = ( $projectId, $sampleGoldId, $projectId, $sampleGoldId );

    my $title;
    my $sampleClause = "and t.sample_gold_id = ?";
    if ( $sampleGoldId eq 'n/a' ) {
        $sampleClause = "and t.sample_gold_id is null";
        @bind         = ( $projectId, $projectId );
        $title        = "Sample Data Set";
    } elsif ( $sampleGoldId eq '' ) {
        $sampleClause = '';
        @bind         = ( $projectId, $projectId );
        $title        = "Data Set List";
    }

    my $dbh = dbLogin();
    my $sql = qq{
select t.taxon_oid 
from taxon t, env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.genome_type = 'metagenome'
and t.gold_id = p.gold_stamp_id
and t.sample_gold_id = e.gold_id
and p.project_oid = ?
$sampleClause
$urClause
$imgClause
union
select t.taxon_oid
from taxon t, submission\@imgsg_dev s,  env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.genome_type = 'metagenome'
and t.submission_id = s.submission_id
and s.project_info = p.project_oid
and p.project_oid = ?
and s.sample_oid = e.sample_oid
$sampleClause
$urClause
$imgClause
    };

    require GenomeList;
    GenomeList::printGenomesViaSql( $dbh, $sql, $title, \@bind );
}

sub printSampleGenomeList {
    my $sampleGoldId = param('sampleGoldId');
    my $title        = "$sampleGoldId Data Set";

    my @bind = ($sampleGoldId, $sampleGoldId);

    my $urClause     = WebUtil::urClause('t');
    my $imgClause    = WebUtil::imgClause('t');
    my $goldIdClause = "and t.sample_gold_id = ? ";
    if ( $sampleGoldId eq 'n/a' ) {
        @bind         = ();
        $goldIdClause = "and t.sample_gold_id is null ";
    } elsif($sampleGoldId =~ /^\d/) {
        @bind         = ($sampleGoldId, $sampleGoldId);
        $goldIdClause = "and e.sample_oid = ? ";        
    }

    my $sql = qq{
select t.taxon_oid
from taxon t, env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.genome_type = 'metagenome'
and t.gold_id = p.gold_stamp_id
and t.sample_gold_id = e.gold_id
$goldIdClause
$urClause
$imgClause        
union
select t.taxon_oid
from taxon t, submission\@imgsg_dev s, env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.genome_type = 'metagenome'
and t.submission_id = s.submission_id
and s.project_info = p.project_oid
and s.sample_oid = e.sample_oid
$goldIdClause
$urClause
$imgClause
    };

    my $dbh = dbLogin();
    require GenomeList;
    GenomeList::printGenomesViaSql( $dbh, $sql, $title, \@bind );
}

sub printHtmlSampleTableViewer {
    print qq{
        <h1> Sample Table Viewer </h1>
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $urClause  = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
select p.project_oid, p.display_name, nvl(t.gold_id, p.project_oid),
nvl(t.sample_gold_id, e.sample_oid), e.sample_display_name, 
t.taxon_oid, t.taxon_display_name
from taxon t, env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.genome_type = 'metagenome'
and t.gold_id = p.gold_stamp_id
and t.sample_gold_id = e.gold_id
$urClause
$imgClause
union
select p.project_oid, p.display_name, nvl(t.gold_id, p.project_oid),
nvl(t.sample_gold_id, e.sample_oid), e.sample_display_name, 
t.taxon_oid, t.taxon_display_name
from taxon t, submission\@imgsg_dev s, env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.genome_type = 'metagenome'
and t.submission_id = s.submission_id
and s.project_info = p.project_oid
and s.sample_oid = e.sample_oid
$urClause
$imgClause
    };

    # sample gold id => hash of taxon oids => taxon names
    my %sample2Taxon;
    my %projectId2Name;
    my %goldId2SampleName;
    my %sampleGoldId2ProjectId;
    my %taxon2Name;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $project_info, $display_name, $projectGoldId, $gold_id, $sampleName, $taxon_oid, $taxon_display_name ) =
          $cur->fetchrow();
        last if !$taxon_oid;

        $project_info = $projectGoldId if ( !$project_info );
        $display_name       =~ s/'|"/ /g;
        $taxon_display_name =~ s/'|"/ /g;

        $taxon2Name{$taxon_oid}         = $taxon_display_name;
        $projectId2Name{$projectGoldId} = $display_name;

        $goldId2SampleName{$gold_id} = $sampleName;

        # one smaple belongs to two studies
        if ( exists $sampleGoldId2ProjectId{$gold_id} ) {
            my $href = $sampleGoldId2ProjectId{$gold_id};
            $href->{$projectGoldId} = $project_info;
        } else {
            my %hash = ( $projectGoldId => $project_info );
            $sampleGoldId2ProjectId{$gold_id} = \%hash;
        }

        if ( exists $sample2Taxon{$gold_id} ) {
            my $href = $sample2Taxon{$gold_id};
            $href->{$taxon_oid} = $taxon_display_name;
        } else {
            my %hash = ( $taxon_oid => $taxon_display_name );
            $sample2Taxon{$gold_id} = \%hash;
        }
    }

    my $taxonCnt = keys %taxon2Name;
    print qq{
        <p>
        Data Sets: $taxonCnt
        <br>
        <br>
        * ER Id or Sample ER Id 
        </p>
    };

    WebUtil::printMainForm();

    my $txTableName = "studytable";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 0 );
    my $sd          = $it->getSdDelim();

    $it->addColSpec( 'Sample Name',    "char asc", "left" );
    $it->addColSpec( 'Sample GOLD ID', "char asc", "left" );
    $it->addColSpec( 'Study Name',     "char asc", "left" );
    $it->addColSpec( 'Study GOLD ID',  "char asc", "left" );
    $it->addColSpec( "Data Set Count", "num asc",  "right" );

    my $count = 0;
    foreach my $sampleGoldId ( keys %sample2Taxon ) {
        my $href             = $sample2Taxon{$sampleGoldId};
        my $taxonCnt         = keys %$href;
        my $sampleName       = $goldId2SampleName{$sampleGoldId};
        my $studyGoldId_href = $sampleGoldId2ProjectId{$sampleGoldId};
        my $studyName;
        my $studyGoldId;
        my $size = keys %$studyGoldId_href;
        my $x    = 0;

        foreach my $sGoldId ( keys %$studyGoldId_href ) {
            $studyName .= $projectId2Name{$sGoldId};

            my $url = HtmlUtil::getGoldUrl($sGoldId);
            my $purl = alink( $url, $sGoldId );
            if ( $sGoldId eq 'n/a' || $sGoldId =~ /^\d/) {
                $purl = $sGoldId . '*';
            }
            $studyGoldId .= $purl;
            $x++;
            if ( $x < $size ) {
                $studyName   .= ',<br>';
                $studyGoldId .= ',<br>';
            }
        }

        my $r;

        $r .= $sampleName . $sd . "$sampleName\t";

        my $url = HtmlUtil::getGoldUrl($sampleGoldId);
        $url = alink( $url, $sampleGoldId );
        if ( $sampleGoldId eq 'n/a' || $sampleGoldId =~ /^\d/) {
            $url = $sampleGoldId . '*';;
        }
        $r .= $sampleGoldId . $sd . "$url\t";
        $r .= $studyName . $sd . "$studyName\t";
        $r .= $studyGoldId . $sd . "$studyGoldId\t";

        my $url = alink( "main.cgi?section=StudyViewer&page=sampletaxonlist&sampleGoldId=$sampleGoldId", $taxonCnt );
        $r .= $taxonCnt . $sd . "$url\t";

        $it->addRow($r);

        $count++;
    }

    $it->printOuterTable(1);
    print end_form();
    printStatusLine( "$count Loaded.", 2 );
}

sub printIsolatelist {
    my $project_oid = param('projectid');    # can be blank - null
    my $projectName = param('projecName');
    my $title       = qq{
        <h1> Isolate List for </h1>
        <h3> $projectName</h3>
    };

    my $urClause  = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my @bind = ( $project_oid, $project_oid );
    my $nullClause;
    my $projectClause = 'and p.project_oid = ?';
    if ( $project_oid eq '' || $projectName eq 'n/a' ) {
        $projectClause = 'and p.project_oid is null';
        @bind          = ();
        $nullClause    = qq{
union
select t.taxon_oid
from taxon t 
where t.submission_id is null 
and t.gold_id is null
and t.genome_type = 'isolate'
$imgClause
$urClause               
        };
    }

    my $sql = qq{
select t.taxon_oid
from taxon t, project_info\@imgsg_dev p
where t.genome_type = 'isolate'
and t.gold_id = p.gold_stamp_id
$projectClause
$imgClause
$urClause
union 
select t.taxon_oid
from taxon t, project_info\@imgsg_dev p, submission s
where t.genome_type = 'isolate'
and t.submission_id = s.submission_id
and s.project_info = p.project_oid
$projectClause
$imgClause
$urClause
$nullClause
    };

    my $dbh = dbLogin();
    require GenomeList;
    GenomeList::printGenomesViaSql( $dbh, $sql, $title, \@bind );

}

sub printIsolateTableViewer {
    
    my $all = param('all');
    $all = 0 if($all eq '');
    
    print qq{
        <h1> Isolate Study Table Viewer </h1>
    };

    if($all) {
        print qq{
        <p>  <p> Show <a href='main.cgi?section=StudyViewer&page=tableviewisolate&all=0'> only duplicate isolates</a> 
        };
    } else {
        print qq{
        <p> Show <a href='main.cgi?section=StudyViewer&page=tableviewisolate&all=1'> all isolates</a>    
        };        
    }

    print "</p>\n";
    
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $urClause  = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
select t.taxon_oid,  nvl(t.gold_id, 'n/a'), t.submission_id, p.project_oid,  nvl(p.display_name, 'n/a')
from taxon t, project_info\@imgsg_dev p
where t.genome_type = 'isolate'
and t.gold_id = p.gold_stamp_id
$imgClause
$urClause
union 
select t.taxon_oid,  nvl(t.gold_id, 'n/a'), t.submission_id, p.project_oid,  nvl(p.display_name, 'n/a')
from taxon t, project_info\@imgsg_dev p, submission s
where t.genome_type = 'isolate'
and t.submission_id = s.submission_id
and s.project_info = p.project_oid
$imgClause
$urClause
union
select t.taxon_oid, 'n/a', null, null,  'n/a'
from taxon t 
where t.submission_id is null 
and t.gold_id is null
and t.genome_type = 'isolate'
$imgClause
$urClause
    };

    my %projectId2Name;
    my %projectId2GoldId;
    my %projectDataSetCnt;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $gold_id, $submission_id, $project_oid, $display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        $projectId2Name{$project_oid}   = $display_name;
        $projectId2GoldId{$project_oid} = $gold_id;
        if ( exists $projectDataSetCnt{$project_oid} ) {
            $projectDataSetCnt{$project_oid} = $projectDataSetCnt{$project_oid} + 1;
        } else {
            $projectDataSetCnt{$project_oid} = 1;
        }
    }

    WebUtil::printMainForm();

    my $txTableName = "studytableisolate";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 0 );
    my $sd          = $it->getSdDelim();

    $it->addColSpec( 'Study Name',     "char asc", "left" );
    $it->addColSpec( 'Study GOLD ID',  "char asc", "left" );
    $it->addColSpec( "Project ID",     "num asc",  "right" );
    $it->addColSpec( "Data Set Count", "num asc",  "right" );

    my $count = 0;

    foreach my $project_oid ( keys %projectDataSetCnt ) {
        my $dataSetCnt   = $projectDataSetCnt{$project_oid};
        my $gold_id      = $projectId2GoldId{$project_oid};
        my $display_name = $projectId2Name{$project_oid};

        next if(!$all && $dataSetCnt < 2);
        next if(!$all && $display_name eq 'n/a');
        
        my $r;
        $r .= $display_name . $sd . "$display_name\t";

        if ( $display_name eq 'n/a' ) {
            $r .= ' ' . $sd . " \t";    # do not show gold id
        } elsif ( $gold_id eq 'n/a' ) {
            $r .= ' ' . $sd . "$gold_id\t";
        } else {
            my $url = HtmlUtil::getGoldUrl($gold_id);
            $url = alink( $url, $gold_id );
            $r .= $gold_id . $sd . "$url\t";
        }

        if($project_oid ne '') {
            my $url = "https://img.jgi.doe.gov/cgi-bin/submit/main.cgi?section=ProjectInfo&page=displayProject&project_oid=$project_oid";
            $url = alink($url,  $project_oid);
            $r .= $project_oid . $sd . "$url\t";
        } else {
            $r .= $project_oid . $sd . "$project_oid\t";
        }
        
        my $tmp = WebUtil::massageToUrl2($display_name);
        my $url = alink("main.cgi?section=StudyViewer&page=isolatelist&projecName=$tmp&projectid=$project_oid", $dataSetCnt);
        $r .= $dataSetCnt . $sd . "$url\t";
        $it->addRow($r);
        $count++;

    }

    $it->printOuterTable(1);
    print end_form();
    printStatusLine( "$count Loaded.", 2 );
}

sub printHtmlTableViewer {

    print qq{
        <h1> Study Table Viewer </h1>
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $urClause  = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
select p.project_oid, p.display_name, nvl(t.gold_id, 'n/a'),
nvl(t.sample_gold_id, 'n/a'), e.sample_display_name, 
t.taxon_oid, t.taxon_display_name, e.sample_oid
from taxon t, env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.obsolete_flag = 'No'
and t.genome_type = 'metagenome'
and t.gold_id = p.gold_stamp_id
and t.sample_gold_id = e.gold_id
$urClause
$imgClause
union
select p.project_oid, p.display_name, nvl(t.gold_id, 'n/a'),
nvl(t.sample_gold_id, 'n/a'), e.sample_display_name, 
t.taxon_oid, t.taxon_display_name, e.sample_oid
from taxon t, submission\@imgsg_dev s,  env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.obsolete_flag = 'No'
and t.genome_type = 'metagenome'
and t.submission_id = s.submission_id
and s.project_info = p.project_oid
and s.sample_oid = e.sample_oid
$urClause
$imgClause
    };

    # project id => gold id => taxon id
    my %tree;
    my %projectId2Name;
    my %projectId2GoldId;
    my %taxonID2Name;
    my %goldIdDistinct;
    my %projectId2SampleId; # hash of array of sample ids
    my %projectId2SampleName; # hash of hash of sample Names
    my %sampleId2Name;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $project_info, $display_name, $projectGoldId, $gold_id, $sampleName, $taxon_oid, $taxon_display_name,
        $sample_oid ) =
          $cur->fetchrow();
        last if !$taxon_oid;

        $project_info = $projectGoldId if ( !$project_info );

        $display_name       =~ s/'|"/ /g;
        $taxon_display_name =~ s/'|"/ /g;

        $projectId2Name{$project_info}   = $display_name;
        $projectId2GoldId{$project_info} = $projectGoldId;
        $taxonID2Name{$taxon_oid}        = $taxon_display_name;
        $goldIdDistinct{$gold_id}        = $sampleName;
        $sampleId2Name{$sample_oid} = $sampleName;

        if(exists $projectId2SampleId{$project_info}) {
            my $aref = $projectId2SampleId{$project_info};
            push(@$aref, $sample_oid);
        } else {
            my @a = ($sample_oid);
            $projectId2SampleId{$project_info} = \@a;
        }

        if(exists $projectId2SampleName{$project_info}) {
            my $href = $projectId2SampleName{$project_info};
            $href->{$sampleName} = $sampleName;
        } else {
            my %h = ($sampleName => $sampleName);
            $projectId2SampleName{$project_info} = \%h;
        }


        if ( exists $tree{$project_info} ) {

            my $ghref = $tree{$project_info};
            if ( exists $ghref->{$gold_id} ) {
                my $tref = $ghref->{$gold_id};
                $tref->{$taxon_oid} = $taxon_oid;
            } else {
                my %thash = ( $taxon_oid => $taxon_oid );
                $ghref->{$gold_id} = \%thash;
            }
        } else {
            my %thash = ( $taxon_oid => $taxon_oid );
            my %ghash = ( $gold_id   => \%thash );
            $tree{$project_info} = \%ghash;
        }

    }

    my $size      = keys %projectId2Name;
    my $taxonCnt  = keys %taxonID2Name;
    my $goldIdCnt = keys %goldIdDistinct;

    print qq{
        <p>
        Studies: $size &nbsp;&nbsp;
        Samples: $goldIdCnt &nbsp;&nbsp;
        Data Sets: $taxonCnt
        </p>
    };

    WebUtil::printMainForm();

    my $txTableName = "studytable";
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 0 );
    my $sd          = $it->getSdDelim();

    $it->addColSpec( 'Study Name',     "char asc", "left" );
    $it->addColSpec( 'Study GOLD ID',  "char asc", "left" );
    $it->addColSpec( "Project ID",     "num asc",  "right" );
    #$it->addColSpec( "Sample Count",   "num asc",  "right" );
    $it->addColSpec( "Sample Name Count",   "num asc",  "right" );
    $it->addColSpec( "Sample GOLD ID Count",   "num asc",  "right" );
    $it->addColSpec( "Data Set Count", "num asc",  "right" );

    my $count = 0;

    foreach my $project_id (
                             sort { $projectId2Name{$a} cmp $projectId2Name{$b} }
                             keys %projectId2Name
      )
    {
        my $projectName   = $projectId2Name{$project_id};
        my $gold_href     = $tree{$project_id};
        my $cnt           = keys %$gold_href;
        foreach my $key (%$gold_href) {
            if($key eq 'n/a') {
                $cnt--;
            }
        }
        my $taxonCnt      = getTaxonCnt($gold_href);
        my $projectGoldId = $projectId2GoldId{$project_id};
        my $url = HtmlUtil::getGoldUrl($projectGoldId);
        my $purl          =
          alink( $url, $projectGoldId );

        my $r;

        $r .= $projectName . $sd . "$projectName\t";
        if ( $projectGoldId ne 'n/a' ) {
            $r .= $projectGoldId . $sd . $purl . "\t";
        } else {
            $r .= $projectGoldId . $sd . $projectGoldId . "\t";
        }

        if ( $projectGoldId eq $project_id ) {
            $r .= ' ' . $sd . " \t";
        } else {
            my $url = alink( "main.cgi?section=StudyViewer&page=projectlist&projectid=$project_id", $project_id );
            $r .= $project_id . $sd . "$url\t";
        }
        
        # sample count
        #my $url = alink( "main.cgi?section=StudyViewer&page=samplelist&projectid=$project_id", $cnt );
        #$r .= $cnt . $sd . "$url\t";
        my $href = $projectId2SampleName{$project_id};
        my $snamecnt = keys %$href;
        #my $aref = $projectId2SampleId{$project_id};
        #my $scount = $#$aref + 1;
        #$r .= $scount . $sd . $scount . "\t";
        $r .= $snamecnt . $sd . $snamecnt . "\t";
        $r .= $cnt . $sd . "$cnt\t";
        
        my $url = alink( "main.cgi?section=StudyViewer&page=datasetlist&projectid=$project_id", $taxonCnt );
        $r .= $taxonCnt . $sd . "$url\t";

        $it->addRow($r);
        $count++;
    }

    $it->printOuterTable(1);
    print end_form();
    printStatusLine( "$count Loaded.", 2 );
}

sub printHtmlTreeViewer {
    print qq{
        <h1> Study Tree Viewer </h1>
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $urClause  = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
select p.project_oid, p.display_name, nvl(t.gold_id, 'n/a'),
nvl(t.sample_gold_id, 'n/a'), e.sample_display_name, 
t.taxon_oid, t.taxon_display_name
from taxon t, env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.genome_type = 'metagenome'
and t.gold_id = p.gold_stamp_id
and t.sample_gold_id = e.gold_id
$urClause
$imgClause
union
select p.project_oid, p.display_name, nvl(t.gold_id, 'n/a'),
nvl(t.sample_gold_id, 'n/a'), e.sample_display_name, 
t.taxon_oid, t.taxon_display_name
from taxon t, submission\@imgsg_dev s, env_sample\@imgsg_dev e, project_info\@imgsg_dev p
where t.obsolete_flag = 'No'
and t.genome_type = 'metagenome'
and t.submission_id = s.submission_id
and s.project_info = p.project_oid
and s.sample_oid = e.sample_oid
$urClause
$imgClause
    };

    # project id => gold id => taxon id
    my %tree;
    my %projectId2Name;
    my %projectId2GoldId;
    my %taxonID2Name;
    my %goldIdDistinct;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $project_info, $display_name, $projectGoldId, $gold_id, $sampleName, $taxon_oid, $taxon_display_name ) =
          $cur->fetchrow();
        last if !$taxon_oid;

        $project_info = $projectGoldId if ( !$project_info );

        $display_name       =~ s/'|"/ /g;
        $taxon_display_name =~ s/'|"/ /g;

        $projectId2Name{$project_info}   = $display_name;
        $projectId2GoldId{$project_info} = $projectGoldId;
        $taxonID2Name{$taxon_oid}        = $taxon_display_name;
        $goldIdDistinct{$gold_id}        = $sampleName;

        if ( exists $tree{$project_info} ) {

            my $ghref = $tree{$project_info};
            if ( exists $ghref->{$gold_id} ) {
                my $tref = $ghref->{$gold_id};
                $tref->{$taxon_oid} = $taxon_oid;
            } else {
                my %thash = ( $taxon_oid => $taxon_oid );
                $ghref->{$gold_id} = \%thash;
            }
        } else {
            my %thash = ( $taxon_oid => $taxon_oid );
            my %ghash = ( $gold_id   => \%thash );
            $tree{$project_info} = \%ghash;
        }

    }

    my $size      = keys %projectId2Name;
    my $taxonCnt  = keys %taxonID2Name;
    my $goldIdCnt = keys %goldIdDistinct;

    print qq{
        <p>
        Studies: $size &nbsp;&nbsp;
        Samples: $goldIdCnt &nbsp;&nbsp;
        Data Sets: $taxonCnt
        </p>
    };

    WebUtil::printMainForm();
    printJS();
    print submit(
                  -name    => 'setTaxonFilter',
                  -value   => 'Add Selected to Genome Cart',
                  -class   => 'medbutton',
                  -onClick => "return isGenomeSelected('studyViewer');"
    );

    print qq{
&nbsp;&nbsp;
<input class="smdefbutton" type="button" name="Select All" value="Select All" onclick="javascript:svSelect(1)">
&nbsp;&nbsp;        
<input class="smdefbutton" type="button" name="Clear All" value="Clear All" onclick="javascript:svSelect(0)">
<br/>
    };

    print qq{
<table border=0>
    <tr>
    <td nowrap>
    };

    foreach my $project_id (
                             sort { $projectId2Name{$a} cmp $projectId2Name{$b} }
                             keys %projectId2Name
      )
    {
        my $projectName   = $projectId2Name{$project_id};
        my $gold_href     = $tree{$project_id};
        my $cnt           = keys %$gold_href;
        my $taxonCnt      = getTaxonCnt($gold_href);
        my $projectGoldId = $projectId2GoldId{$project_id};
        my $url = HtmlUtil::getGoldUrl($projectGoldId);
        my $purl          =
          alink( $url, $projectGoldId );
        $purl = $projectGoldId if ( $projectGoldId eq 'n/a' );
        print nbsp(2);
        print
" <input type='checkbox' name='project_oid' value='$project_id' onclick=\"javascript:projectSelect('project_oid', '$project_id')\" />";
        print " <b>$projectName  - $purl (Samples: $cnt Data Sets: $taxonCnt)</b><br/>\n";

        my $row = 0;
        foreach my $gold_id ( sort keys %$gold_href ) {
            my $taxon_href = $gold_href->{$gold_id};
            my $cnt        = keys %$taxon_href;
            print nbsp(6);

            if ( $gold_id ne 'n/a' ) {
                my $sampleName = $goldIdDistinct{$gold_id};
                print
" <input type='checkbox' name='gold_oid' value='$gold_id' onclick=\"javascript:goldSelect('gold_oid', '$gold_id')\"/>";
                my $url = HtmlUtil::getGoldUrl($gold_id);
                $url = alink( $url, $gold_id );
                print "$sampleName - $url ($cnt)<br/>\n";
            } else {
                my $tmpId = $project_id . '_' . $row++;    # I need a unique id for the checkbox select
                print
" <input type='checkbox' name='gold_oid' value='$tmpId' onclick=\"javascript:goldSelect('gold_oid', '$tmpId')\"/>";
                print " $gold_id ($cnt)<br/>\n";
            }

            foreach my $taxon_oid ( keys %$taxon_href ) {
                my $taxon_name = $taxonID2Name{$taxon_oid};
                print nbsp(10);
                print " <input type='checkbox' name='taxon_filter_oid' value='$taxon_oid'/>";
                my $url = alink( "main.cgi?section=TaxonDetail&taxon_oid=$taxon_oid", $taxon_name );
                print " $url<br/>\n";
            }
        }
    }

    print qq{
    </td>
    </tr>
</table>
    };
    print end_form();
    printStatusLine( "Loaded.", 2 );
}

sub printJS {
    print <<EOF;
    <script type="text/javascript">
    function projectSelect(name, id) {
        var f = document.mainForm;
        var inProject = false;
        var x;
        for ( var i = 0; i < f.length; i++) {
            var e = f.elements[i];
            if(inProject && e.type == "checkbox" && e.name == name) {
                break;
            }
            
            if(!inProject && e.type == "checkbox" && e.name == name && e.value == id) {
                inProject = true;
                x = e.checked;
                continue;
            }
            
            if (inProject && e.type == "checkbox" ) {
                e.checked = x;
            }
        }       
    }

    function goldSelect(name, id) {
        var f = document.mainForm;
        var inProject = false;
        var x;
        for ( var i = 0; i < f.length; i++) {
            var e = f.elements[i];
            if(inProject && e.type == "checkbox" && (e.name == name || e.name == "project_oid")) {
                break;
            }
            
            if(!inProject && e.type == "checkbox" && e.name == name && e.value == id) {
                inProject = true;
                x = e.checked;
                continue;
            }
            
            if (inProject && e.type == "checkbox" ) {
                e.checked = x;
            }
        }       
    }
    
    function svSelect(x) {
        var f = document.mainForm;
        for ( var i = 0; i < f.length; i++) {
            var e = f.elements[i];
            if (e.type == "checkbox" ) {
                e.checked = (x == 0 ? false : true);
            }
        }
    }

    </script>
EOF
}

sub getTaxonCnt {
    my ($gold_href) = @_;
    my $total = 0;
    foreach my $gold_id ( keys %$gold_href ) {
        my $taxon_href = $gold_href->{$gold_id};
        my $cnt        = keys %$taxon_href;
        $total += $cnt;
    }

    return $total;
}

sub printViewer {
    print qq{
        <h1> Study Tree Viewer </h1>
    };

    my $dbh = dbLogin();

    my $urClause  = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
select e.project_info, p.display_name ,nvl(e.gold_id, 'n/a'), t.taxon_oid, t.taxon_display_name
from project_info\@imgsg_dev p, env_sample\@imgsg_dev e, submission\@imgsg_dev s, taxon t
where p.project_oid = e.project_info 
and s.sample_oid = e.sample_oid
and s.submission_id = t.submission_id
and t.obsolete_flag = 'No'
and t.genome_type = 'metagenome'
and e.gold_id is not null
$urClause
$imgClause
order by 1, 3, 5 
    };

    # project id => gold id => taxon id
    my %tree;
    my %projectId2Name;
    my %taxonID2Name;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $project_info, $display_name, $gold_id, $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if !$project_info;

        $display_name       =~ s/'|"/ /g;
        $taxon_display_name =~ s/'|"/ /g;

        $projectId2Name{$project_info} = $display_name;
        $taxonID2Name{$taxon_oid}      = $taxon_display_name;

        if ( exists $tree{$project_info} ) {

            my $ghref = $tree{$project_info};
            if ( exists $ghref->{$gold_id} ) {
                my $tref = $ghref->{$gold_id};
                $tref->{$taxon_oid} = $taxon_oid;
            } else {
                my %thash = ( $taxon_oid => $taxon_oid );
                $ghref->{$gold_id} = \%thash;
            }
        } else {
            my %thash = ( $taxon_oid => $taxon_oid );
            my %ghash = ( $gold_id   => \%thash );
            $tree{$project_info} = \%ghash;
        }

    }

    #var employees = [
    #{ "firstName":"John" , "lastName":"Doe" },
    #{ "firstName":"Anna" , "lastName":"Smith" },
    #{ "firstName":"Peter" , "lastName": "Jones" }
    #];
    #
    #{
    #    "firstName": "John",
    #    "lastName": "Smith",
    #    "age": 25,
    #    "address": {
    #        "streetAddress": "21 2nd Street",
    #        "city": "New York",
    #        "state": "NY",
    #        "postalCode": 10021
    #    },
    #    "phoneNumbers": [
    #        {
    #            "type": "home",
    #            "number": "212 555-1234"
    #        },
    #        {
    #            "type": "fax",
    #            "number": "646 555-4567"
    #        }
    #    ]
    #}

    #{ project_id : '10719', project_name : 'Simulated microbial communities',
    #    goldIds : [{gold_id : 'Gs0000250',
    #    taxons : [
    #{taxon_id : '2017108004', taxon_name : 'Sample 10205'},
    #{taxon_id : '2065487019', taxon_name : 'Sample 10205 (HMP - Mock-even-Illumina-PE-200904-SOAP)'},
    #{taxon_id : '2065487020', taxon_name : 'Sample 10205 (HMP - Mock-stg-Illumina-PE-200904-SOAP)'},
    #{taxon_id : '3300000314', taxon_name : 'Sample 10205'},
    #{taxon_id : '3300000562', taxon_name : 'Sample 10205'},
    #        ]
    #{gold_id : 'Gs0000252',
    #    taxons : [
    #{taxon_id : '2030936004', taxon_name : 'Sample 10326'},
    #        ]
    #    ]},
    my $str = 'var nodes = [';
    foreach my $projectId ( sort keys %tree ) {
        my $pname = $projectId2Name{$projectId};
        $str .= "{ project_id : '$projectId', project_name : '$pname',\n    ";

        my $ghref = $tree{$projectId};
        $str .= "goldIds : [";
        foreach my $goldId ( sort keys %$ghref ) {
            $str .= "{gold_id : '$goldId',\n    taxons : [\n";

            my $thref = $ghref->{$goldId};
            foreach my $taxon_oid ( sort keys %$thref ) {
                my $tname = $taxonID2Name{$taxon_oid};
                $str .= "{taxon_id : '$taxon_oid', taxon_name : '$tname'},\n";
            }
            $str .= "        ]\n";
        }
        $str .= "    ]},\n";
    }
    $str .= '];';

    #    print qq{
    #<pre>
    #$str
    #</pre>
    #    };

    # http://stackoverflow.com/questions/3757495/javascript-looping-through-a-json-string

    print <<EOF;
<div id="treeDiv1"  class="whitebg ygtv-checkbox"></div>    
    
<script type="text/javascript">

$str;

//global variable to allow console inspection of tree:
var tree1;

var i;
var j;
for(i=0;i<nodes.length;i++) {
    var pname = nodes[i].project_name;
    var goldids = nodes[i].goldIds;
    
}

//anonymous function wraps the remainder of the logic:
(function() {



    var makeBranch = function (parent,label) {
        label = label || '';
        var n = Math.random() * (6 - (label.length || 0));
        for (var i = 0;i < n;i++) {
            var tmpNode = new YAHOO.widget.TextNode('label' + label + '-' + i, parent, Math.random() > .5);
            makeBranch(tmpNode,label + '-' + i);
        }
    }


    var treeInit = function() {
        tree1 = new YAHOO.widget.TreeView("treeDiv1");
        makeBranch(tree1.getRoot());
        tree1.setNodesProperty('propagateHighlightUp',true);
        tree1.setNodesProperty('propagateHighlightDown',true);
        tree1.subscribe('clickEvent',tree1.onEventToggleHighlight);     
        tree1.render();
    };

    //Add an onDOMReady handler to build the tree when the document is ready
    YAHOO.util.Event.onDOMReady(treeInit);

})();
</script>    
    
EOF
}

1;
