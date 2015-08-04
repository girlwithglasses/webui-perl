# $Id: Fastbit.pm 30632 2014-04-15 17:50:16Z klchu $

package Fastbit;
my $section = "Fastbit";
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use OracleUtil;
use HtmlUtil;
use Command;
use LWP::UserAgent;
use HTTP::Request::Common qw( GET POST);
use GenomeListJSON;

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

sub dispatch {
    my ($numTaxon) = @_;
    $numTaxon = 0 if ( $numTaxon eq "" );

    my $page = param('page');
    if ( $page eq 'run' ) {
        timeout( 60 * 20 );    # timeout in 20 minutes
        run();
    } elsif ( $page eq 'form' ) {
        printForm($numTaxon);
    } else {
        #printFormTest();
        printForm($numTaxon);
    }
}

sub printForm {
    my ($numTaxon) = @_;
    printMainForm();

    # radio buttons
    print "<p>\n";
    print "FASTBIT Test <br>";
    print "</p>\n";

    GenomeListJSON::printHiddenInputType( $section, 'run' );
    my $xml_cgi = $cgi_url . '/xml.cgi';
    $include_metagenomes = 0 if ( $include_metagenomes eq "" );
    my $template = HTML::Template->new( filename => "$base_dir/genomeJson.html" );
    $template->param( isolate             => 0 );
    $template->param( include_metagenomes => 1 );
    $template->param( gfr                 => 0 );
    $template->param( pla                 => 0 );
    $template->param( vir                 => 0 );
    $template->param( all                 => 0 );
    $template->param( cart                => 1 );
    $template->param( xml_cgi             => $xml_cgi );

    # TODO - for some forms show only metagenome or show only isolates
    $template->param( from => '' );

    # prefix
    $template->param( prefix => '' );
    print $template->output;

    GenomeListJSON::printMySubmitButton( "", '', "Go", '', $section, 'run', 'meddefbutton' );

    GenomeListJSON::showGenomeCart($numTaxon);
    print end_form();
}

sub run {
    print qq{
      <p>
      output <br>  
    };

    my @taxon_oids = param('taxon_oid');
    my @more_oids  = param('genomeFilterSelections');
    push( @taxon_oids, @more_oids );

    #my @taxon_oids = (3300001184);

    print Dumper \@taxon_oids;

    #
    # /global/projectb/sandbox/IMG_web/fastbit/geneMaps
    # getProfile cassette/geneMaps/7000000338.a/
    my $cassetteDir = $env->{fastbit_dir};

    #printStartWorkingDiv();
    print "<br>Running fastbit<br/>\n";

    # hash of hash
    # taxon oids + .a or .u => hash of function id and gene count
    my %taxonHash;

    # assembled
    foreach my $toid (@taxon_oids) {
        my %funcGeneCnt;
        my $dfile   = '/global/projectb/sandbox/IMG_web/fastbit/geneMaps/' . $toid . '.a';
        my $command = $cassetteDir . 'getProfile ' . $dfile;
        if ( !-e $dfile ) {
            print "No data file for $dfile <br>\n";
            next;
        }

        if ($img_ken) {
            print "<br/>$command<br/>\n";
        }

        print "Calling fastbit api<br/>\n";
        my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile( $command, $cassetteDir );
        my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );

        print "stdOutFile: $stdOutFile <br>\n";
        if ( $stdOutFile ne ' - 1 ' ) {
            print "Fastbit done<br/>\n";
            print "Reading Fastbit output $stdOutFile<br/>\n";
            my $cfh = WebUtil::newReadFileHandle($stdOutFile);
            while ( my $s = $cfh->getline() ) {
                chomp $s;
                next if blankStr($s);
                next if ( $s =~ /^\/global/ );

                #print $s . " ==== ";
                my ( $func, $cnt ) = split( /:\s/, $s );

                #print "$func, $cnt <br>\n";
                $funcGeneCnt{$func} = $cnt;
            }
            close $cfh;
        }
        $taxonHash{ $toid . ' . a ' } = \%funcGeneCnt;
    }

    # unassembled
    foreach my $toid (@taxon_oids) {
        my %funcGeneCnt;
        my $dfile   = '/global/projectb/sandbox/IMG_web/fastbit/geneMaps/' . $toid . '.u';
        my $command = $cassetteDir . 'getProfile ' . $dfile;
        if ( !-e $dfile ) {
            print "No data file for $dfile <br>\n";
            next;
        }

        if ($img_ken) {
            print "<br/>$command<br/>\n";
        }

        print "Calling fastbit api<br/>\n";
        my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile( $command, $cassetteDir );
        my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );

        print "stdOutFile: $stdOutFile <br>\n";
        if ( $stdOutFile ne ' - 1 ' ) {
            print "Fastbit done<br/>\n";
            print "Reading Fastbit output $stdOutFile<br/>\n";
            my $cfh = WebUtil::newReadFileHandle($stdOutFile);
            while ( my $s = $cfh->getline() ) {
                chomp $s;
                next if blankStr($s);
                next if ( $s =~ /^\/global/ );

                #print $s . " ==== ";
                my ( $func, $cnt ) = split( /:\s/, $s );

                #print "$func, $cnt <br>\n";
                $funcGeneCnt{$func} = $cnt;
            }
            close $cfh;
        }
        $taxonHash{ $toid . ' . u ' } = \%funcGeneCnt;
    }

    #printEndWorkingDiv( '', 1 );
    print "<pre>\n";
    print Dumper \%taxonHash;
    print "\n</pre>\n";
}

sub printFormTest {
    print qq{
    <h1> fastbit test</h1>
    };
    printMainForm();

    print hiddenVar( "section", $section );
    print hiddenVar( "page",    "run" );

    print hiddenVar( "taxon_oid", "2051774002" );
    print hiddenVar( "taxon_oid", "2166559000" );
    print hiddenVar( "taxon_oid", "3300001130" );
    print hiddenVar( "taxon_oid", "3300001184" );
    print hiddenVar( "taxon_oid", "3300001916" );
    print hiddenVar( "taxon_oid", "3300001440" );
    print hiddenVar( "taxon_oid", "7000000089" );
    print hiddenVar( "taxon_oid", "7000000170" );
    print hiddenVar( "taxon_oid", "7000000206" );
    print hiddenVar( "taxon_oid", "7000000338" );
    print hiddenVar( "taxon_oid", "7000000522" );

    print qq{
      <p>
        2051774002.a/ <br>
        2166559000.a/ <br>
        3300001130.a/ <br>
        3300001184.a/ <br>
        3300001916.a/ <br>
        3300001440.a/ <br>
        7000000089.a/ <br>
        plus 3 other hmp genomes <br>
    };

    print submit( -class => ' smdefbutton ', -name => ' submit ', -value => ' Go ' );
    print end_form();
}

1;
