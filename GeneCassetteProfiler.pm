###########################################################################
#
#
# $Id: GeneCassetteProfiler.pm 33080 2015-03-31 06:17:01Z jinghuahuang $
#
#
#
# algorithms:
# where Gfin  - find in genome
#       Gcin  - collocated in genomes
#       Gcnot - collocated not in genomes
# IN
# 1. find all the boxes in common with Gfin with Gcin_1 to Gcin_n
#    using intersection. Getting all genomes common boxes via oracle,
# 2. boxes from 1. get all the cluster ids
# 3. get Gfin cassettes from 1. boxes
# 4. from 3. cassettes get genes filtered by clusters from 2.
#
# NOT IN
# 1. Get all common boxes between Gfin and for each Gcnot_1 ... Gcnot_n
#   a union of not intersection of Gcnot_1 ... Gcnot_n, then intersection with
#   Gfin
# 2. From 1. boxes get all clusters
# 3. From 1. boxes get all the Gfin cassettes genes
# 4  Remove those genes in 3.  with clusters found in 2.
#
# Special cases no IN choosen or no IN boxes in common
# in either case boxes found in NOT IN 1. are used to find cassettes - genes
# to display as the results
#
# - ken 2008-06-04
#
# Currently NOT IN - is experimental and not used - Ken 2010-04-14
#
package GeneCassetteProfiler;
my $section = "GeneCassetteProfiler";
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use InnerTable;
use MetagenomeGraph;
use GeneCassette;
use OracleUtil;
use HtmlUtil;
use StaticInnerTable;
use QueryUtil;
use Command;
use LWP::UserAgent;
use HTTP::Request::Common qw( GET POST);
use GenomeListJSON;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $tmp_url               = $env->{tmp_url};
my $tmp_dir               = $env->{tmp_dir};
my $verbose               = $env->{verbose};
my $web_data_dir          = $env->{web_data_dir};
my $preferences_url       = "$main_cgi?section=MyIMG&page=preferences";
my $img_lite              = $env->{img_lite};
my $img_internal          = $env->{img_internal};
my $include_cassette_bbh  = $env->{include_cassette_bbh};
my $include_cassette_pfam = $env->{include_cassette_pfam};
my $enable_cassette       = $env->{enable_cassette};
my $public_nologin_site   = $env->{public_nologin_site};
my $user_restricted_site  = $env->{user_restricted_site};
my $include_metagenomes   = $env->{include_metagenomes};
my $enable_fastbit        = $env->{enable_cassette_fastbit};
my $img_ken               = $env->{img_ken};
my $cgi_url               = $env->{cgi_url};

my $base_dir = $env->{base_dir};
my $base_url = $env->{base_url};

my $ENABLE_NOT_IN = 0;
my $MIN_GENES     = 2;
my $nvl           = getNvl();

# limit on the number of col. genomes to select
my $FASTBIT_LIMIT = 50;

my @stats_messages;

sub addMessage {
    my ($str) = @_;
    push( @stats_messages, $str );
}

sub printMessages {
    print "<p>\n";
    foreach my $str (@stats_messages) {
        print "$str<br/>\n";
    }
    print "</p>\n";
}

############################################################################
# dispatch - Dispatch loop.
#
# My coding style - starting now param() is only called in the
# dispatch() method or the first method called from the dispatch()
# such that other methods are reusable.
# -Ken
sub dispatch {
    my ($numTaxon) = @_;    # number of saved genomes
    $numTaxon = 0 if ( $numTaxon eq "" );

    return if ( !$enable_cassette );

    my $sid = getContactOid();

    #    if ($img_internal) {
    #        $ENABLE_NOT_IN = 1;
    #    } else {
    #        $ENABLE_NOT_IN = 0;
    #    }

    my $page = param("page");

    if ( $page eq "geneContextPhyloProfiler3" || $page eq "geneContextPhyloProfiler2" ) {
        printGeneContextPhyloProfiler3($numTaxon);

    } elsif ( $page eq "geneContextPhyloProfilerRun2" ) {

        my $ans = 1;    # do not use cache pages if $ans
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
            if ( !$ans ) {
                HtmlUtil::cgiCacheInitialize($section);
                HtmlUtil::cgiCacheStart() or return;
            }
        }

        # verison 2
        my $t = dateTimeStr();
        printGeneContextPhyloProfilerRun2();

        webLog("Cassette profiler start time was $t\n");
        my $t = dateTimeStr();
        webLog("end time was $t\n");

        HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );

    } elsif ( $page eq "note" ) {
        printNote();
    } elsif ( $page eq "genetools" ) {
        printTopPage();

        #    } elsif ( $page eq 'fastbit' ) {
        #        timeout( 60 * 20 );    # 20 minutes
        #        fastBitFindCommonPropsInTaxa();

    } elsif ( $page eq 'fastbit3' || $page eq 'fastbit' ) {
        timeout( 60 * 20 );    # 20 minutes
        fastBitFindCommonPropsInTaxa3();

    } else {
        printGeneContextPhyloProfiler3($numTaxon);
    }
}

#
# http://img-stage.jgi-psf.org/cgi-bin/img_ken/main.cgi?section=GeneCassetteProfiler&page=fastbit
#
#sub fastBitFindCommonPropsInTaxa_ken {
#    my $common_tmp_dir = $env->{common_tmp_dir};
#    my $cassetteDir    = $env->{fastbit_dir};
#    my $command        = $cassetteDir . "findCommonPropsInTaxa db 641522611 641522613 641228499 648028003 ";
#
#    my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile( $command, $cassetteDir );
#    my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );
#
#    my $rfh = WebUtil::newReadFileHandle($stdOutFile);
#    while ( my $line = $rfh->getline() ) {
#        chomp $line;
#        print "$line<br/>\n";
#    }
#    close $rfh;
#
#}
#
# test url
# http://img-stage.jgi-psf.org/cgi-bin/img_ken/main.cgi?section=GeneCassetteProfiler&page=fastbit
#
#
sub fastBitFindCommonPropsInTaxa {

    print qq{
        <h1> Phylogenetic Profiler for Gene Cassettes Results </h1>
        <p>
        Powered by <a href="https://sdm.lbl.gov/fastbit/">Fastbit</a>
        </p>        
    };

    my $type = param("cluster");    # cog or pfam

    my @taxonOids;                  # list of all taxon oids
    my @findList;                   # list of find   taxon   oids
    my @queryTaxons;                # list of taxon ids Collocated in

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv('working1');
    print "Getting cassette genomes<br/>\n";

    my $urClause  = urClause("gc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('gc.taxon');
    my $sql       = qq{
       select distinct gc.taxon 
       from gene_cassette gc
       where 1 = 1
       $urClause
       $imgClause
    };
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        push( @taxonOids, $taxon_oid );
    }
    $cur->finish();

    #
    # Now find what user had selected on the form
    #
    my $taxon_count = 0;
    foreach my $toid (@taxonOids) {
        my $profileVal = param("profile$toid");
        next if $profileVal eq "0" || $profileVal eq "";

        if ( $profileVal eq "find" ) {
            push( @findList, $toid );
        } elsif ( $profileVal eq "coll" ) {
            push( @queryTaxons, $toid );
        }

        if ( $#findList > 1 ) {

            #$dbh->disconnect();
            printStatusLine( "Loaded.", 2 );
            webLog( "Please select only 1 genome " . "in the \"Find In\" column 1.\n" );
            webError( "Please select only 1 genome " . "in the \"Find In\" column." );
            return;
        }
    }    # end for

    # check size of arrays
    if ( $#findList > 0 || $#findList < 0 ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        webLog( "Please select 1 genome " . "in the \"Find In\" column 2.\n" );
        webError( "Please select 1 genome " . "in the \"Find In\" column." );
        return;
    }
    if ( $#queryTaxons < 0 ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        webLog("Please select at least 1 genome in the \"Collocated In\" column\n");
        webError( "Please select at least 1 genome " . "in the \"Collocated In\" column" );
        return;
    }
    if ( $#queryTaxons > $FASTBIT_LIMIT ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        webError( "Please only select a max. of $FASTBIT_LIMIT genomes " . "in the \"Collocated In\" column" );
        return;
    }

    my $taxonName = QueryUtil::fetchTaxonName( $dbh, $findList[0] );
    print "Getting genome name<br/>\n";
    if ($img_ken) {
        print qq{ 
       </p> 
       </div>
       </div>
    };
    } else {
        printEndWorkingDiv('working1');
    }

    print "<p>$taxonName " . "<br/>By " . GeneCassette::getTypeTitle($type) . " Conserved Cassettes\n";
    printStartWorkingDiv();

    my $refTaxon = $findList[0];

    WebUtil::unsetEnvPath();
    $ENV{LD_LIBRARY_PATH} = $ENV{LD_LIBRARY_PATH} . $env->{fastbit_LD_LIBRARY_PATH};

    #my $lib = $ENV{LD_LIBRARY_PATH};

    my $cassetteDir = $env->{fastbit_dir};
    my $command     = $cassetteDir . "findCommonPropsInTaxa";

    $command = "$command db $refTaxon";
    foreach my $i (@queryTaxons) {
        $command = $command . " $i";
    }

    print "Running fastbit<br/>\n";
    if ($img_ken) {
        print "<br/>$command<br/>\n";
    }

    # you must go to the genome dir to access 'db' directory
    #chdir $cassetteDir;
    #my $cfh = newCmdFileHandle($command);
    print "Calling fastbit api<br/>\n";
    my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile( $command, $cassetteDir );
    my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );
    if ( $stdOutFile == -1 ) {

        # close working div but do not clear the data
        printEndWorkingDiv( '', 1 );

        #$dbh->disconnect();
        printStatusLine( "Error.", 2 );
        WebUtil::webExit(-1);
    }

    print "Fastbit done<br/>\n";
    print "Reading Fastbit output $stdOutFile<br/>\n";
    my $cfh = WebUtil::newReadFileHandle($stdOutFile);

    # lets read fastbit output
    my $funcs_aref;    # current function list
    my $ref_cid;       # find in genome cassette id
    my @query_cids;    # other genomes cassette id

    # cid => group number 1..n => list of functions
    my %conservedCassettes;

# e.g output
# ** pfam00004 pfam00271 pfam02824 pfam00753 pfam01926 COG0343 pfam01702 pfam07521 COG0012 COG1236 pfam10996 pfam08438 :
#   92641522664: 83641522732
# ** COG0043 pfam01977 :
#   37641522664: 11641522732 86641522732
# ** pfam02775 COG0078 pfam00185 pfam02729 pfam01035 pfam00037 COG0350 pfam01192 pfam01558 pfam01926 COG0674 COG1013 pfam0185 pfam00448 COG0552 pfam02996 pfam01918 :
#       90641522664: 14641522732
# ** pfam00006 pfam02874 pfam00185 pfam02729 pfam00306 pfam00137 COG1155 COG1156 COG1269 COG1390 COG1394 pfam01496 pfam01813 pfam01991 COG1527 pfam01992 :
#       90641522664: 73641522732
#
#** pfam00005 pfam00528 COG0573 COG0581 COG1117 KO:K02036 KO:K02037 KO:K02038:
#       64152266400090 : 64152273200023
#
#** pfam00005 pfam02653 COG0683 pfam01094 COG0410 COG0411 COG0559 COG4177 :
#       66641522664 67641522664 8641522664 89641522664: 61641522732
# above ^^^ list of ref cassette ids too
#
#
#** COG0438 pfam00534:
#       63641522664 69641522664 77641522664 92641522664 : 43641522732 : 5641228520 : 26648028045 27648028045 31648028045 32648028045 33648028045 58648028045 68648028045
#
# Notice that some cassettes 90641522664 appear mulitple times but should be all be there in teh results list
#
    while ( my $s = $cfh->getline() ) {
        chomp $s;

        next if ( $s =~ /^fileManager/ );    # ingore last line of output

        if ( $s =~ /^\*\*/ ) {
            my @allFuncs = split( /\s+/, $s );
            if ( $type eq "cog" ) {

                # list of functions pfam and cogs
                # eg pfam00696 COG1143 pfam00037
                $funcs_aref = getOnlyCogs( \@allFuncs );
            } else {

                # pfam
                $funcs_aref = getOnlyPfam( \@allFuncs );
            }
        } else {

            # cassette must be two or more genes
            #next if $#$funcs_aref < 1;    # no functions of given type found
            # do gene count in query

            $s = strTrim($s);
            my @a        = split( /:/,   $s );
            my @ref_cids = split( /\s+/, $a[0] );    # 1st array is the ref genome's casssette id list

            foreach my $ref_cid (@ref_cids) {
                next if ( $ref_cid eq '' || $ref_cid =~ /\s+/ );
                if ( exists $conservedCassettes{$ref_cid} ) {
                    my $href     = $conservedCassettes{$ref_cid};
                    my $maxKeyId = keys %$href;
                    $maxKeyId++;
                    $href->{$maxKeyId} = $funcs_aref;
                } else {
                    my %tmp;
                    $tmp{1} = $funcs_aref;
                    $conservedCassettes{$ref_cid} = \%tmp;
                }
            }
        }
    }
    close $cfh;
    WebUtil::resetEnvPath();

    # /global/homes/k/klchu/Dev/cassettes/v3/genome/findCommonPropsInTaxa db 641522611 641522613
    #'64152266400106' => { '1' => [ 'COG1733' ] },
    #'64152266400074' => { '1' => [ 'COG2207' ] },
    #'64152266400117' => { '4' => [ 'COG2200' ], '1' => [ 'COG2199' ], '3' => [ 'COG0007' ], '2' => [], '5' => [] },
    my $size = keys %conservedCassettes;
    print "Found $size conservered cassettes<br/>\n";
    print "Getting cassette gene information from db<br/>\n";

# get all the cassette genes function list locus tag
# cassette id =>
#   gene id =>  'locus_tag' => value,
#               'gene_display_name'=> value,
#               'aa_seq_length' => value,
#               func id 1 => '',
#               func id 2 => '',
#
#'64152266400102' => { '641614299' => { 'COG0330' => '', 'locus_tag' => 'Kcr_1222', 'aa_seq_length' => '987', 'gene_display_name' => 'band 7 protein' } },
#'64152266400019' => { '641613411' => { 'COG0330' => '', 'locus_tag' => 'Kcr_0328', 'aa_seq_length' => '705', 'gene_display_name' => 'Membrane protease subunit, stomatin/prohibitin-like protein' } },
#'64152266400046' => { '641613677' => { 'locus_tag' => 'Kcr_0599', 'COG2814' => '', 'aa_seq_length' => '1305', 'gene_display_name' => 'major facilitator superfamily MFS_1' },
#                      '641613678' => { 'locus_tag' => 'Kcr_0600', 'COG1028' => '', 'aa_seq_length' => '765', 'gene_display_name' => 'short-chain dehydrogenase/reductase SDR' } },
#'64152266400103' => { '641614323' => { 'locus_tag' => 'Kcr_1245', 'aa_seq_length' => '726', 'COG1136' => '', 'gene_display_name' => 'ABC transporter related' } },
#'64152266400111' => { '641614541' => { 'locus_tag' => 'Kcr_1440', 'COG0206' => '', 'aa_seq_length' => '1161', 'gene_display_name' => 'cell division protein FtsZ' } },
#'64152266400043' => { '641613625' => { 'locus_tag' => 'Kcr_0547', 'COG3264' => '', 'aa_seq_length' => '594', 'gene_display_name' => 'Small-conductance mechanosensitive channel' } },
#'64152266400018' => { '641613398' => { 'locus_tag' => 'Kcr_0315', 'COG2814' => '', 'aa_seq_length' => '1167', 'gene_display_name' => 'permease of the major facilitator superfamily' } },
#'64152266400108' => { '641614435' => { 'locus_tag' => 'Kcr_1343', 'COG0206' => '', 'aa_seq_length' => '1194', 'gene_display_name' => 'cell division protein FtsZ' },
#                      '641614465' => { 'locus_tag' => 'Kcr_1370', 'COG0689' => '', 'aa_seq_length' => '747', 'gene_display_name' => 'exosome complex exonuclease 1' } },
#'64152266400028' => { '641613493' => { 'locus_tag' => 'Kcr_0412', 'aa_seq_length' => '504', 'COG2226' => '', 'gene_display_name' => 'Methyltransferase type 11' } },
#'64152266400088' => { '641613955' => { 'locus_tag' => 'Kcr_0884', 'COG1028' => '', 'aa_seq_length' => '780', 'gene_display_name' => 'short-chain dehydrogenase/reductase SDR' } },
#'64152266400113' => { '641614611' => { 'locus_tag' => 'Kcr_1503', 'aa_seq_length' => '1665', 'COG0459' => '', 'gene_display_name' => 'Chaperonin GroEL (HSP60 family)' } }
    my $cassetteInfo_href = getAllCassetteGenes_fastbit( $dbh, \%conservedCassettes, $type, $refTaxon );

    print "Found cassette gene information from db<br/>\n";
    if ($img_ken) {
        print qq{ 
       </p> 
       </div>
       </div>
    };
    } else {
        printEndWorkingDiv();
    }

    # create cassette sets with gene oids
    # cid => hash 1 to N => list of gene oids
    my %conservedCassettesToGenes = %conservedCassettes;    # lets initialize this hash
    foreach my $cid ( keys %conservedCassettes ) {

        #print "$cid -------------- <br/>\n";
        my $nhref  = $conservedCassettes{$cid};             # for a cassette and its functions sets
        my $nhref2 = $conservedCassettesToGenes{$cid};
        my $ghref  = $cassetteInfo_href->{$cid};            # hash of all the genes in this cassette

        #        print Dumper $nhref;
        #        print "<br/>\n";
        #
        #        print Dumper $nhref2;
        #        print "<br/>\n";
        #        print Dumper $ghref;
        #        print "<br/>\n";

        foreach my $n ( keys %$nhref ) {
            my $aref = $nhref->{$n};                        # list of func ids
            my @empty;
            $nhref2->{$n} = \@empty;
            foreach my $funcId (@$aref) {
                foreach my $gene_oid ( keys %$ghref ) {
                    my $ginfo_href = $ghref->{$gene_oid};
                    if ( exists $ginfo_href->{$funcId} ) {
                        my $aref2 = $nhref2->{$n};  # list of gene oids
                                                    # make sure gene is not there already since some genes hit multiple pfams
                        my $ans = existsInArray( $aref2, $gene_oid );
                        if ( !$ans ) {
                            push( @$aref2, $gene_oid );
                        }
                    }
                }
            }
        }
    }

    #    print "<br/>";
    #    print "------ <br/>";
    #    print Dumper \%conservedCassettesToGenes;
    #        print "<br/>";
    #    print "<br/>";

    # TODO - do a new print here with %conservedCassettesToGenes
    # ignore sets with one gene - ken
    #
    # a number 1 to N (one set to print)=> array of tab delimited str if values to print for the set
    my %printedList;
    my $setCnt = 1;

    # $key is cassette id
    foreach my $key ( sort keys %conservedCassettesToGenes ) {
        my $genesInfo_href = $cassetteInfo_href->{$key};
        my $nhref          = $conservedCassettesToGenes{$key};

        # sort by gene array size
        # $n is just a number from 1 to N
        #
        foreach my $n ( sort { $#{ $nhref->{$b} } <=> $#{ $nhref->{$a} } } keys %$nhref ) {
            my $gene_aref = $nhref->{$n};
            if ( $#$gene_aref < ( $MIN_GENES - 1 ) ) {

                # we must have min. of 2 genes in a set
                #print "index " . $#$gene_aref;
                #print "<br/>\n";
                next;
            }

            my @set;
            foreach my $gene_oid ( sort @$gene_aref ) {
                my $href              = $genesInfo_href->{$gene_oid};
                my $locus_tag         = $href->{locus_tag};
                my $gene_display_name = $href->{gene_display_name};
                my $aa_seq_length     = $href->{aa_seq_length};

                # I'll have to group them before the print and dump the entire set
                my $str = "$key\t";    # cassette id
                $str .= "$gene_oid\t";
                $str .= "$gene_display_name\t";
                $str .= "$aa_seq_length\t";
                $str .= "$locus_tag";
                push( @set, $str );
            }
            $printedList{ $setCnt++ } = \@set;
        }    # end for loop $n
    }

    # look ahead now because the filter is on gene oids ???
    # no  filter for now - ken
    #
    #    my %distinctGenes;
    my %printKeyToIgnore;

    #    foreach my $key ( sort { $#{ $printedList{$b} } <=> $#{ $printedList{$a} } } keys %printedList ) {
    #        my $aref = $printedList{$key};
    #        print "$key =========== <br/>\n";
    #        foreach my $line (@$aref) {
    #            my ( $cassetteId, $gene_oid, $gene_display_name, $aa_seq_length, $locus_tag ) = split( /\t/, $line );
    #            if ( exists $distinctGenes{$gene_oid} ) {
    #                print " $cassetteId,  $gene_oid skip<br/>\n";
    #
    #                #                $printKeyToIgnore{$key} = $key;
    #                #                last;
    #            } else {
    #                print " $cassetteId,  $gene_oid<br/>\n";
    #                $distinctGenes{$gene_oid} = 1;
    #            }
    #        }
    #    }

    #print "<br/>";
    #print "<br/>";
    #    print Dumper \%printedList;
    #    print "<br/>";
    #    print "<br/>";
    #    print Dumper \%printKeyToIgnore;
    #    print "<br/>";
    #    print "<br/>";

    print "<h3>Statistics</h3>\n";
    printStatsTable_fastbit( \%printedList, \%printKeyToIgnore );

    print "<h3>Details</h3>\n";
    printMainForm();
    printGeneCartFooter();
    my $rows = printTable_fastbit( \%printedList, $type, \%printKeyToIgnore );
    print end_form();

    #$dbh->disconnect();
    printStatusLine( "$rows Loaded.", 2 );
}

# for new genome list form
sub fastBitFindCommonPropsInTaxa3 {

    print qq{
        <h1> Phylogenetic Profiler for Gene Cassettes Results</h1>
        <p>
        Powered by <a href="https://sdm.lbl.gov/fastbit/">Fastbit</a>
        </p>        
    };

    my $type = param("cluster");    # cog or pfam

    my @findList    = param('selectedGenome1');    # list of find   taxon   oids
    my @queryTaxons = param('selectedGenome2');    # list of taxon ids Collocated in

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv('working1');

    # check size of arrays
    if ( $#findList > 0 || $#findList < 0 ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        webLog( "Please select 1 genome " . "in the \"Find In\" column 2.\n" );
        webError( "Please select 1 genome " . "in the \"Find In\" column." );
        return;
    }
    if ( $#queryTaxons < 0 ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        webLog("Please select at least 1 genome in the \"Collocated In\" column\n");
        webError( "Please select at least 1 genome " . "in the \"Collocated In\" column" );
        return;
    }
    if ( $#queryTaxons > $FASTBIT_LIMIT ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        my $size = $#queryTaxons + 1;
        webError( "Please only select a max. of $FASTBIT_LIMIT genomes ($size) " . "in the \"Collocated In\" column" );
        return;
    }

    my $dbh = dbLogin();
    my $taxonName = QueryUtil::fetchTaxonName( $dbh, $findList[0] );
    print "Getting genome name<br/>\n";
    if ($img_ken) {
        print qq{ 
       </p> 
       </div>
       </div>
    };
    } else {
        printEndWorkingDiv('working1');
    }

    print "<p>$taxonName " . "<br/>By " . GeneCassette::getTypeTitle($type) . " Conserved Cassettes\n";
    printStartWorkingDiv();

    my $refTaxon = $findList[0];

    WebUtil::unsetEnvPath();
    $ENV{LD_LIBRARY_PATH} = $ENV{LD_LIBRARY_PATH} . $env->{fastbit_LD_LIBRARY_PATH};

    #my $lib = $ENV{LD_LIBRARY_PATH};

    my $cassetteDir = $env->{fastbit_dir};
    my $command     = $cassetteDir . "findCommonPropsInTaxa";

    $command = "$command db $refTaxon";
    foreach my $i (@queryTaxons) {
        $command = $command . " $i";
    }

    print "Running fastbit<br/>\n";
    if ($img_ken) {
        print "<br/>$command<br/>\n";
    }

    # you must go to the genome dir to access 'db' directory
    #chdir $cassetteDir;
    #my $cfh = newCmdFileHandle($command);
    print "Calling fastbit api<br/>\n";
    my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile( $command, $cassetteDir );
    my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );
    if ( $stdOutFile == -1 ) {

        # close working div but do not clear the data
        printEndWorkingDiv( '', 1 );

        #$dbh->disconnect();
        printStatusLine( "Error.", 2 );
        WebUtil::webExit(-1);
    }

    print "Fastbit done<br/>\n";
    print "Reading Fastbit output $stdOutFile<br/>\n";
    my $cfh = WebUtil::newReadFileHandle($stdOutFile);

    # lets read fastbit output
    my $funcs_aref;    # current function list
    my $ref_cid;       # find in genome cassette id
    my @query_cids;    # other genomes cassette id

    # cid => group number 1..n => list of functions
    my %conservedCassettes;

# e.g output
# ** pfam00004 pfam00271 pfam02824 pfam00753 pfam01926 COG0343 pfam01702 pfam07521 COG0012 COG1236 pfam10996 pfam08438 :
#   92641522664: 83641522732
# ** COG0043 pfam01977 :
#   37641522664: 11641522732 86641522732
# ** pfam02775 COG0078 pfam00185 pfam02729 pfam01035 pfam00037 COG0350 pfam01192 pfam01558 pfam01926 COG0674 COG1013 pfam0185 pfam00448 COG0552 pfam02996 pfam01918 :
#       90641522664: 14641522732
# ** pfam00006 pfam02874 pfam00185 pfam02729 pfam00306 pfam00137 COG1155 COG1156 COG1269 COG1390 COG1394 pfam01496 pfam01813 pfam01991 COG1527 pfam01992 :
#       90641522664: 73641522732
#
#** pfam00005 pfam00528 COG0573 COG0581 COG1117 KO:K02036 KO:K02037 KO:K02038:
#       64152266400090 : 64152273200023
#
#** pfam00005 pfam02653 COG0683 pfam01094 COG0410 COG0411 COG0559 COG4177 :
#       66641522664 67641522664 8641522664 89641522664: 61641522732
# above ^^^ list of ref cassette ids too
#
#
#** COG0438 pfam00534:
#       63641522664 69641522664 77641522664 92641522664 : 43641522732 : 5641228520 : 26648028045 27648028045 31648028045 32648028045 33648028045 58648028045 68648028045
#
# Notice that some cassettes 90641522664 appear mulitple times but should be all be there in teh results list
#
    while ( my $s = $cfh->getline() ) {
        chomp $s;

        next if ( $s =~ /^fileManager/ );    # ingore last line of output

        if ( $s =~ /^\*\*/ ) {
            my @allFuncs = split( /\s+/, $s );
            if ( $type eq "cog" ) {

                # list of functions pfam and cogs
                # eg pfam00696 COG1143 pfam00037
                $funcs_aref = getOnlyCogs( \@allFuncs );
            } else {

                # pfam
                $funcs_aref = getOnlyPfam( \@allFuncs );
            }
        } else {

            # cassette must be two or more genes
            #next if $#$funcs_aref < 1;    # no functions of given type found
            # do gene count in query

            $s = strTrim($s);
            my @a        = split( /:/,   $s );
            my @ref_cids = split( /\s+/, $a[0] );    # 1st array is the ref genome's casssette id list

            foreach my $ref_cid (@ref_cids) {
                next if ( $ref_cid eq '' || $ref_cid =~ /\s+/ );
                if ( exists $conservedCassettes{$ref_cid} ) {
                    my $href     = $conservedCassettes{$ref_cid};
                    my $maxKeyId = keys %$href;
                    $maxKeyId++;
                    $href->{$maxKeyId} = $funcs_aref;
                } else {
                    my %tmp;
                    $tmp{1} = $funcs_aref;
                    $conservedCassettes{$ref_cid} = \%tmp;
                }
            }
        }
    }
    close $cfh;
    WebUtil::resetEnvPath();

    # /global/homes/k/klchu/Dev/cassettes/v3/genome/findCommonPropsInTaxa db 641522611 641522613
    #'64152266400106' => { '1' => [ 'COG1733' ] },
    #'64152266400074' => { '1' => [ 'COG2207' ] },
    #'64152266400117' => { '4' => [ 'COG2200' ], '1' => [ 'COG2199' ], '3' => [ 'COG0007' ], '2' => [], '5' => [] },
    my $size = keys %conservedCassettes;
    print "Found $size conservered cassettes<br/>\n";
    print "Getting cassette gene information from db<br/>\n";

# get all the cassette genes function list locus tag
# cassette id =>
#   gene id =>  'locus_tag' => value,
#               'gene_display_name'=> value,
#               'aa_seq_length' => value,
#               func id 1 => '',
#               func id 2 => '',
#
#'64152266400102' => { '641614299' => { 'COG0330' => '', 'locus_tag' => 'Kcr_1222', 'aa_seq_length' => '987', 'gene_display_name' => 'band 7 protein' } },
#'64152266400019' => { '641613411' => { 'COG0330' => '', 'locus_tag' => 'Kcr_0328', 'aa_seq_length' => '705', 'gene_display_name' => 'Membrane protease subunit, stomatin/prohibitin-like protein' } },
#'64152266400046' => { '641613677' => { 'locus_tag' => 'Kcr_0599', 'COG2814' => '', 'aa_seq_length' => '1305', 'gene_display_name' => 'major facilitator superfamily MFS_1' },
#                      '641613678' => { 'locus_tag' => 'Kcr_0600', 'COG1028' => '', 'aa_seq_length' => '765', 'gene_display_name' => 'short-chain dehydrogenase/reductase SDR' } },
#'64152266400103' => { '641614323' => { 'locus_tag' => 'Kcr_1245', 'aa_seq_length' => '726', 'COG1136' => '', 'gene_display_name' => 'ABC transporter related' } },
#'64152266400111' => { '641614541' => { 'locus_tag' => 'Kcr_1440', 'COG0206' => '', 'aa_seq_length' => '1161', 'gene_display_name' => 'cell division protein FtsZ' } },
#'64152266400043' => { '641613625' => { 'locus_tag' => 'Kcr_0547', 'COG3264' => '', 'aa_seq_length' => '594', 'gene_display_name' => 'Small-conductance mechanosensitive channel' } },
#'64152266400018' => { '641613398' => { 'locus_tag' => 'Kcr_0315', 'COG2814' => '', 'aa_seq_length' => '1167', 'gene_display_name' => 'permease of the major facilitator superfamily' } },
#'64152266400108' => { '641614435' => { 'locus_tag' => 'Kcr_1343', 'COG0206' => '', 'aa_seq_length' => '1194', 'gene_display_name' => 'cell division protein FtsZ' },
#                      '641614465' => { 'locus_tag' => 'Kcr_1370', 'COG0689' => '', 'aa_seq_length' => '747', 'gene_display_name' => 'exosome complex exonuclease 1' } },
#'64152266400028' => { '641613493' => { 'locus_tag' => 'Kcr_0412', 'aa_seq_length' => '504', 'COG2226' => '', 'gene_display_name' => 'Methyltransferase type 11' } },
#'64152266400088' => { '641613955' => { 'locus_tag' => 'Kcr_0884', 'COG1028' => '', 'aa_seq_length' => '780', 'gene_display_name' => 'short-chain dehydrogenase/reductase SDR' } },
#'64152266400113' => { '641614611' => { 'locus_tag' => 'Kcr_1503', 'aa_seq_length' => '1665', 'COG0459' => '', 'gene_display_name' => 'Chaperonin GroEL (HSP60 family)' } }
    my $cassetteInfo_href = getAllCassetteGenes_fastbit( $dbh, \%conservedCassettes, $type, $refTaxon );

    print "Found cassette gene information from db<br/>\n";
    if ($img_ken) {
        print qq{ 
       </p> 
       </div>
       </div>
    };
    } else {
        printEndWorkingDiv();
    }

    # create cassette sets with gene oids
    # cid => hash 1 to N => list of gene oids
    my %conservedCassettesToGenes = %conservedCassettes;    # lets initialize this hash
    foreach my $cid ( keys %conservedCassettes ) {

        #print "$cid -------------- <br/>\n";
        my $nhref  = $conservedCassettes{$cid};             # for a cassette and its functions sets
        my $nhref2 = $conservedCassettesToGenes{$cid};
        my $ghref  = $cassetteInfo_href->{$cid};            # hash of all the genes in this cassette

        #        print Dumper $nhref;
        #        print "<br/>\n";
        #
        #        print Dumper $nhref2;
        #        print "<br/>\n";
        #        print Dumper $ghref;
        #        print "<br/>\n";

        foreach my $n ( keys %$nhref ) {
            my $aref = $nhref->{$n};                        # list of func ids
            my @empty;
            $nhref2->{$n} = \@empty;
            foreach my $funcId (@$aref) {
                foreach my $gene_oid ( keys %$ghref ) {
                    my $ginfo_href = $ghref->{$gene_oid};
                    if ( exists $ginfo_href->{$funcId} ) {
                        my $aref2 = $nhref2->{$n};  # list of gene oids
                                                    # make sure gene is not there already since some genes hit multiple pfams
                        my $ans = existsInArray( $aref2, $gene_oid );
                        if ( !$ans ) {
                            push( @$aref2, $gene_oid );
                        }
                    }
                }
            }
        }
    }

    #    print "<br/>";
    #    print "------ <br/>";
    #    print Dumper \%conservedCassettesToGenes;
    #        print "<br/>";
    #    print "<br/>";

    # TODO - do a new print here with %conservedCassettesToGenes
    # ignore sets with one gene - ken
    #
    # a number 1 to N (one set to print)=> array of tab delimited str if values to print for the set
    my %printedList;
    my $setCnt = 1;

    # $key is cassette id
    foreach my $key ( sort keys %conservedCassettesToGenes ) {
        my $genesInfo_href = $cassetteInfo_href->{$key};
        my $nhref          = $conservedCassettesToGenes{$key};

        # sort by gene array size
        # $n is just a number from 1 to N
        #
        foreach my $n ( sort { $#{ $nhref->{$b} } <=> $#{ $nhref->{$a} } } keys %$nhref ) {
            my $gene_aref = $nhref->{$n};
            if ( $#$gene_aref < ( $MIN_GENES - 1 ) ) {

                # we must have min. of 2 genes in a set
                #print "index " . $#$gene_aref;
                #print "<br/>\n";
                next;
            }

            my @set;
            foreach my $gene_oid ( sort @$gene_aref ) {
                my $href              = $genesInfo_href->{$gene_oid};
                my $locus_tag         = $href->{locus_tag};
                my $gene_display_name = $href->{gene_display_name};
                my $aa_seq_length     = $href->{aa_seq_length};

                # I'll have to group them before the print and dump the entire set
                my $str = "$key\t";    # cassette id
                $str .= "$gene_oid\t";
                $str .= "$gene_display_name\t";
                $str .= "$aa_seq_length\t";
                $str .= "$locus_tag";
                push( @set, $str );
            }
            $printedList{ $setCnt++ } = \@set;
        }    # end for loop $n
    }

    # look ahead now because the filter is on gene oids ???
    # no  filter for now - ken
    #
    #    my %distinctGenes;
    my %printKeyToIgnore;

    #    foreach my $key ( sort { $#{ $printedList{$b} } <=> $#{ $printedList{$a} } } keys %printedList ) {
    #        my $aref = $printedList{$key};
    #        print "$key =========== <br/>\n";
    #        foreach my $line (@$aref) {
    #            my ( $cassetteId, $gene_oid, $gene_display_name, $aa_seq_length, $locus_tag ) = split( /\t/, $line );
    #            if ( exists $distinctGenes{$gene_oid} ) {
    #                print " $cassetteId,  $gene_oid skip<br/>\n";
    #
    #                #                $printKeyToIgnore{$key} = $key;
    #                #                last;
    #            } else {
    #                print " $cassetteId,  $gene_oid<br/>\n";
    #                $distinctGenes{$gene_oid} = 1;
    #            }
    #        }
    #    }

    #print "<br/>";
    #print "<br/>";
    #    print Dumper \%printedList;
    #    print "<br/>";
    #    print "<br/>";
    #    print Dumper \%printKeyToIgnore;
    #    print "<br/>";
    #    print "<br/>";

    print "<h3>Statistics</h3>\n";
    printStatsTable_fastbit( \%printedList, \%printKeyToIgnore );

    print "<h3>Details</h3>\n";
    printMainForm();
    printGeneCartFooter();
    my $rows = printTable_fastbit( \%printedList, $type, \%printKeyToIgnore );
    print end_form();

    #$dbh->disconnect();
    printStatusLine( "$rows Loaded.", 2 );
}

# -------------------------------------------------------------------------------------------------------------

sub existsInArray {
    my ( $aref, $value ) = @_;
    foreach my $x (@$aref) {
        if ( $x eq $value ) {
            return 1;
        }
    }
    return 0;
}

sub printStatsTable_fastbit {
    my ( $printedList_href, $printKeyToIgnore_href ) = @_;

    my %occurrences;    #number of genes => count
    foreach my $key ( keys %$printedList_href ) {
        next if ( exists $printKeyToIgnore_href->{$key} );
        my $aref = $printedList_href->{$key};

        #next if ( $#$aref < ( $MIN_GENES - 1 ) );    # min num of genes
        my $size = $#$aref + 1;
        if ( exists $occurrences{$size} ) {
            $occurrences{$size} = $occurrences{$size} + 1;
        } else {
            $occurrences{$size} = 1;
        }
    }

    my $sit = new StaticInnerTable();
    my $sd  = $sit->getSdDelim();
    $sit->addColSpec( "No of Collocated Genes", '', 'right' );
    $sit->addColSpec( "Occurrences",            '', 'right' );

    foreach my $key ( sort { $b <=> $a } keys %occurrences ) {
        my $value = $occurrences{$key};
        my $row   = "$key\t";
        $row .= "$value\t";
        $sit->addRow($row);
    }
    $sit->printTable();
}

sub printTable_fastbit {
    my ( $printedList_href, $type, $printKeyToIgnore_href ) = @_;

    my $gurl = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";
    my $curl = "$main_cgi?section=GeneCassette&page=cassetteBox" . "&type=$type&cassette_oid=";

    my $row_count  = 0;    # number of genes
    my $cass_count = 0;    # used to highlight sets
    my %distinctCassetteIds;
    my %distinctGeneIds;

    print "<table class='img' border='1'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Result<br>Row</th>\n";
    print "<th class='img'>Gene ID</th>\n";
    print "<th class='img'>Gene Product Name</th>\n";
    print "<th class='img'>Length</th>\n";
    print "<th class='img'>Cassette ID</th>\n";
    print "<th class='img' title='Locus Tag'>" . "Conserved Neighborhood Viewer Centered on this Gene</th>\n";

    foreach my $key ( sort { $#{ $printedList_href->{$b} } <=> $#{ $printedList_href->{$a} } } keys %$printedList_href ) {
        next if ( exists $printKeyToIgnore_href->{$key} );
        my $aref = $printedList_href->{$key};

        #next if ( $#$aref < ( $MIN_GENES - 1 ) );    # min num of genes
        $cass_count++;

        my $count = 1;
        foreach my $line (@$aref) {
            my ( $cassetteId, $gene_oid, $gene_display_name, $aa_seq_length, $locus_tag ) = split( /\t/, $line );

            if ( $cass_count % 2 != 0 ) {
                print "<tr class='highlight' >\n";
            } else {
                print "<tr class='img' >\n";
            }

            # column 1
            print "<td class='img' >\n";
            print qq{
                <input type='checkbox' name='gene_oid' value='$gene_oid'  />
            };
            print "</td>\n";

            # column 2
            print "<td class='img' align='right'>\n";
            print $count++;
            print "</td>\n";

            print "<td class='img' >\n";
            print alink( "$gurl" . "$gene_oid", "$gene_oid" );
            print "</td>\n";
            $row_count++;
            $distinctGeneIds{$gene_oid} = 1;

            print "<td class='img' >\n";
            print "$gene_display_name";
            print "</td>\n";

            print "<td class='img' align='right'>\n";
            print "$aa_seq_length";
            print "</td>\n";

            print "<td class='img' >\n";
            if ( $count == 2 ) {
                print alink( "$curl" . $cassetteId, $cassetteId );
            } else {
                print "&nbsp;";
            }
            print "</td>\n";
            $distinctCassetteIds{$cassetteId} = 1;

            # locus tag
            my $url = "main.cgi?section=GeneCassette" . "&page=geneCassette&gene_oid=$gene_oid&type=$type";
            $locus_tag = "view" if ( $locus_tag eq "" );
            print "<td class='img' >\n";
            print "<a href='" . $url . "'>  $locus_tag </a>";
            print "</td></tr>\n";
        }

        print qq{
            <tr>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            </tr>            
        };
    }
    print "</table>";

    my $size  = keys %distinctCassetteIds;
    my $size2 = keys %distinctGeneIds;
    print qq{
        <p>
        Gene count: $size2
        &nbsp;&nbsp;&nbsp; 
        Set Count: $cass_count
        &nbsp;&nbsp;&nbsp; 
        Cassette Count: $size
        </p>
    };

    return $row_count;
}

sub getAllCassetteGenes_fastbit {
    my ( $dbh, $conservedCassettes_href, $type, $taxon_oid ) = @_;
    my @cassetteIds;
    my @functions;

    foreach my $cid ( keys %$conservedCassettes_href ) {
        push( @cassetteIds, $cid );
        my $href = $conservedCassettes_href->{$cid};
        foreach my $x ( keys %$href ) {
            my $aref = $href->{$x};
            push( @functions, @$aref );
        }
    }

    # lets get distinct function set
    my %distinctFnc;
    foreach my $f (@functions) {
        $distinctFnc{$f} = 1;
    }
    @functions = ();
    foreach my $f ( keys %distinctFnc ) {
        push( @functions, $f );
    }

    my $sql;
    my $clause;

    my $size  = $#functions + 1;
    my $size2 = $#cassetteIds + 1;
    print "Looking for genes with $size functions in $size2 cassettes<br/>\n";
    if ($img_ken) {
        print "<br/>\n";
        print Dumper \@functions;
        print "<br/>\n";
    }

    $clause = '';    # do filter in UI code not sql
    if ( $type eq 'cog' ) {
        $sql = qq{
select c.cassette_oid, c.gene, f.cog, g.locus_tag, g.gene_display_name, g.dna_seq_length
from gene_cassette_genes c, gene_cog_groups f, gene g
where c.gene = f.gene_oid
and c.gene = g.gene_oid
and g.taxon = ?
and g.taxon = f.taxon

        };
    } else {
        $sql = qq{
select c.cassette_oid, c.gene, f.pfam_family, g.locus_tag, g.gene_display_name, g.dna_seq_length
from gene_cassette_genes c, gene_pfam_families f, gene g
where c.gene = f.gene_oid
and c.gene = g.gene_oid
and g.taxon = ?
and g.taxon = f.taxon
$clause
        };
    }

    # cassette id =>
    #   gene id =>  'locus_tag' => value,
    #               'gene_display_name'=> value,
    #               func id 1 => '',
    #               func id 2 => '',
    my %cassetteInfo;
    my $cur    = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count  = 0;
    my $colCnt = 0;
    for ( ; ; ) {
        my ( $cassetteId, $gene_oid, $func_id, $locus_tag, $gene_display_name, $aa_seq_length ) = $cur->fetchrow();
        last if !$cassetteId;

        next if ( !exists $conservedCassettes_href->{$cassetteId} );
        next if ( !exists $distinctFnc{$func_id} );

        if ( exists $cassetteInfo{$cassetteId} ) {
            my $ghref = $cassetteInfo{$cassetteId};
            if ( exists $ghref->{$gene_oid} ) {
                my $href = $ghref->{$gene_oid};
                $href->{locus_tag}         = $locus_tag;
                $href->{gene_display_name} = $gene_display_name;
                $href->{aa_seq_length}     = $aa_seq_length;
                $href->{$func_id}          = '';
            } else {
                my %h = (
                          locus_tag         => $locus_tag,
                          gene_display_name => $gene_display_name,
                          aa_seq_length     => $aa_seq_length,
                          $func_id          => ''
                );
                $ghref->{$gene_oid} = \%h;
            }
        } else {
            my %h = (
                      locus_tag         => $locus_tag,
                      gene_display_name => $gene_display_name,
                      aa_seq_length     => $aa_seq_length,
                      $func_id          => ''
            );
            my %gh;
            $gh{$gene_oid}             = \%h;
            $cassetteInfo{$cassetteId} = \%gh;
        }

        if ( $count % 100 == 0 ) {
            print ".";
            $colCnt++;
            if ( $colCnt > 80 ) {
                $colCnt = 0;
                print "<br/>\n";
            }
        }
        $count++;
    }

    print "<br/>Found $count <br/>\n";

    return \%cassetteInfo;
}

sub getOnlyCogs {
    my ($allFuncs_aref) = @_;
    my @funcs;
    foreach my $f (@$allFuncs_aref) {
        if ( $f =~ /^COG/ ) {
            $f =~ s/://;
            push( @funcs, $f );
        }
    }
    return \@funcs;
}

sub getOnlyPfam {
    my ($allFuncs_aref) = @_;
    my @funcs;
    foreach my $f (@$allFuncs_aref) {
        if ( $f =~ /^pfam/ ) {
            $f =~ s/://;
            push( @funcs, $f );
        }
    }
    return \@funcs;
}

sub runCmd2 {
    my ( $cmd, $v ) = @_;

    webLog("Status: Running $cmd\n");

    # a better untaint to system exec
    #  http://www.boards.ie/vbulletin/showthread.php?p=55944778
    $ENV{'PATH'} = "";

    #delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

    my $cfh;

    # manually set the ENV for threads
    # see http://perldoc.perl.org/threads.html#BUGS-AND-LIMITATIONS on ENV
    # http://perldoc.perl.org/perlipc.html#Using-open()-for-IPC
    # newCmdFileHandle();
    # $cfh = new FileHandle("PATH=/bin:/usr/bin:/usr/local/bin; IFS=''; CDPATH=''; ENV=''; BASH_ENV=''; $cmd 2>\&1 |");
    $cfh = new FileHandle("$cmd |");

    if ( !$cfh ) {
        webLog("Failure: runCmd2 $cmd\n");
        WebUtil::webExit(-1);
    }

    while ( my $s = $cfh->getline() ) {
        chomp $s;
        print "$s <br/>\n";
        webLog("Status: $s\n");
    }

    $cfh->close();
}

############################################################################
# printTopPage - Print top page for gene tools
############################################################################
sub printTopPage {

    print "<h1>Phylogenetic Profilers</h1>\n";

    print "<p>\n";
    print "<table class='img' border='1'>\n";

    print "<th class='img'>Tool</th>\n";
    print "<th class='img'>Description</th>\n";

    print "<tr class='img'>\n";
    print "<td class='img'>\n";
    my $url = "main.cgi?section=PhylogenProfiler&page=phyloProfileForm";
    print alink( $url, "Single Genes" );
    print "</td>\n";
    print "<td class='img'>\n";
    print qq{
        Find genes in genome (bin) of interest qualified by similarity to 
        sequences in other genomes (based on BLASTP alignments). 
        Only user-selected genomes appear in the profiler.        
    };
    print "</td>\n";
    print "</tr>\n";

    #    print "<tr class='img'>\n";
    #    print "<td class='img'>\n";
    #    my $url =
    #      "$main_cgi?section=GeneCassetteProfiler&page=geneContextPhyloProfiler";
    #    print alink( $url, "Gene Cassettes" );
    #    print "</td>\n";
    #    print "<td class='img'>\n";
    #    print qq{
    #        IMG Cassette Profiler.
    #        Find collocated genes that are part of a cassette in a query genome,
    #        that are also part of gene cassettes in other genomes of interest
    #    };
    #    print "</td>\n";
    #    print "</tr>\n";

    if ( !$include_metagenomes ) {
        print "<tr class='img'>\n";
        print "<td class='img'>\n";
        my $url = "$main_cgi?section=GeneCassetteProfiler&page=geneContextPhyloProfiler2";
        print alink( $url, "Gene Cassettes" );
        print "</td>\n";
        print "<td class='img'>\n";
        print qq{
        IMG Cassette Profiler.
        Find collocated genes that are part of a cassette in a query genome, 
        that are also part of gene cassettes in other genomes of interest        
    };
        print "</td>\n";
        print "</tr>\n";
    }

    #    print "<tr class='img'>\n";
    #    print "<td class='img'>\n";
    #    my $url = "main.cgi?section=GeneCartStor&page=geneCart&from=geneTool#tools2";
    #    print alink( $url, "Selective Gene Profile" );
    #    print "</td>\n";
    #    print "<td class='img'>\n";
    #    print qq{
    #        Gene Profile. View selected protein coding genes against selected genomes
    #        using unidirectional seqeuence similarities.
    #    };
    #    print "</td>\n";
    #    print "</tr>\n";

    print "</table>\n";
    print "</p>\n";
}

#
# prints algorithm notes
#
sub printNote {
    print qq{
        <p>
        <b>Collocated IN:</b><br>
        B<sub>set_in</sub> =  G<sub>fin</sub> &cap; (G<sub>cin_1</sub> &cap; ... &cap; G<sub>cin_i</sub> ) <br>
        CL<sub>set_in</sub> = All clusters found in B<sub>set</sub> <br>
        CA<sub>set_in</sub> = G<sub>fin</sub> cassettes found in B<sub>set</sub> <br>
        </p>

        <p>
        <b>NOT Collocated IN:</b><br>
        B<sub>set_not</sub> =  G<sub>fin</sub> &cap; (G<sub>cnot_1</sub> &cup; ... &cup; G<sub>cnot_j</sub> ) <br> 
        CL<sub>set_not</sub> = All clusters found in B<sub>set_not</sub> <br>
        CA<sub>set_not</sub> = G<sub>fin</sub> cassettes found in B<sub>set_not</sub> <br>
        </p>

        <p>
        <b>Output:</b><br>
        GL = (CA<sub>set</sub> genes cluster &cap; CL<sub>set</sub>) - CL<sub>set_not</sub>
        <br>
        <br>
        Special Case 1:<br>
        Colloacted IN was not selected or B<sub>set_in</sub> was null <br>
        GL = CA<sub>set_not</sub> - CL<sub>set_not</sub>
        </p>
        
        <p>
        <b>Where:</b><br>
        G<sub>fin</sub> - Find In Genome<br>
        G<sub>cin_i</sub> - Collocated In Genomes<br>
        G<sub>cnot_j</sub> - Not Collocated In Genomes<br>

        B<sub>set_in</sub> - Collocated In Boxes<br>
        B<sub>set_not</sub> - Not Collocated In Boxes<br>

        CL<sub>set_in</sub> - Collocated In Clusters <br>
        CL<sub>set_not</sub> - Not Collocated In Clusters <br>

        CA<sub>set_in</sub> - Collocated In Cassettes <br>
        CA<sub>set_not</sub> - Not Collocated In Cassettes <br>

        GL - Gene List
        </p>        
        
    }
}

sub printGeneContextPhyloProfiler3 {
    my($numTaxon) = @_;
    print "<h1>Phylogenetic Profiler for Gene Cassettes</h1>\n";

    print qq{
        <p>
        Find genes in a query genome, that are collocated in the query genome
        as well as across other genomes of interest, based on their inclusion
        in cassettes. <br/>
        <b>Limitation: </b> Currently you can only select up to <b>$FASTBIT_LIMIT Collocated In</b> Genomes.
    };
    print qq{
        <br/>
        Powered by <a href="https://sdm.lbl.gov/fastbit/">Fastbit</a>
        
    } if ($enable_fastbit);

    print "</p> <p>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    # radio buttons
    print "<p>\n";
    print "Select Protein Cluster <br>";
    print "<input type='radio' name='cluster' value='cog' checked />";
    print "COG<br>\n";
    if ($include_cassette_pfam) {
        print "<input type='radio' name='cluster' value='pfam' />";
        print "Pfam<br>\n";
    }
    print "</p>\n";

    my $xml_cgi = $cgi_url . '/xml.cgi';
    my $template = HTML::Template->new( filename => "$base_dir/genomeJsonTwoDiv.html" );
    $template->param( isolate              => 1 );
    $template->param( include_metagenomes  => 0 );
    $template->param( gfr                  => 0 );
    $template->param( pla                  => 0 );
    $template->param( vir                  => 0 );
    $template->param( all                  => 1 );
    $template->param( cart                 => 1 );
    $template->param( xml_cgi              => $xml_cgi );
    $template->param( prefix               => '' );
    $template->param( selectedGenome1Title => 'Find Genes In' );
    $template->param( selectedGenome2Title => 'Collocated In (50 max.)' );
    $template->param( from                 => 'GeneCassetteProfiler' );
    $template->param( maxSelected2         => $FASTBIT_LIMIT );

    my $s = GenomeListJSON::printMySubmitButtonXDiv( '', 'Submit', 'Submit', '', $section, 'fastbit3' );
    $template->param( mySubmitButton => $s );

    print $template->output;

    GenomeListJSON::printHiddenInputType( $section, 'fastbit3' );

    GenomeListJSON::showGenomeCart($numTaxon);
    printStatusLine( "Loaded.", 2 );
    print end_form();

}

# Profiler main form page
# filter taxon list via cassette table of taxon ids
#
#
# version 2
#
sub printGeneContextPhyloProfiler2 {
    print "<h1>Phylogenetic Profiler for Gene Cassettes</h1>\n";
    if ($img_internal) {
        print "<p><b>Experimental - Internal Version</b></p>\n";
    }

    print qq{
        <p>
        Find genes in a query genome, that are collocated in the query genome
        as well as across other genomes of interest, based on their inclusion
        in cassettes. <br/>
        <b>Limitation: </b> Currently you can only select up to <b>$FASTBIT_LIMIT Collocated In</b> Genomes.
    };
    print qq{
        <br/>
        Powered by <a href="https://sdm.lbl.gov/fastbit/">Fastbit</a>
        
    } if ($enable_fastbit);

    print "</p> <p>\n";
    print completionLetterNoteParen() . "<br/>\n";
    if ($img_internal) {
        print "<a href='$section_cgi&page=note'>Algorithm</a>";
    }
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $dbh         = dbLogin();
    my @bindList    = ();
    my $taxonClause = txsClause( "tx1", $dbh );

    my ( $rclause, @bindList_ur ) = urClauseBind("tx1");
    if ( scalar(@bindList_ur) > 0 ) {
        push( @bindList, @bindList_ur );
    }

    my $imgClause = WebUtil::imgClause('tx1');

    my $publicClause = "";
    if ( $public_nologin_site && !$user_restricted_site ) {
        $publicClause = "and tx1.taxon_oid in " . "(select tx2.taxon_oid from taxon tx2 " . "where tx2.is_public = ? )";
        push( @bindList, 'Yes' );
    }

    # find only taxon with cassettes
    # faster than doing join
    my $sql_phylo = qq{
       select  tx1.domain, tx1.phylum, tx1.ir_class, tx1.ir_order, tx1.family, 
          tx1.genus, tx1.species, tx1.strain, 
          tx1.taxon_display_name, tx1.taxon_oid, tx1.seq_status
       from taxon tx1
       where tx1.taxon_oid in (select distinct gc.taxon from gene_cassette gc)
       $taxonClause
       $rclause
       $imgClause
       $publicClause
       order by tx1.domain, tx1.phylum, tx1.ir_class, tx1.ir_order, tx1.family, 
          tx1.genus, tx1.species, tx1.strain, tx1.taxon_display_name
    };
    my $sql = $sql_phylo;

    #print "printGeneContextPhyloProfiler2 \$sql: $sql<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    # where the query data is stored
    my @recs;
    my $old_domain;
    my $old_phylum;
    my $old_genus;
    my $old_taxon_oid;

    # run query and store the data in @recs
    # for each rec, the values are tab delimited
    # also add '__lineRange__' used to for the UI display and
    # javascript event actions
    #
    for ( ; ; ) {
        my (
             $domain,  $phylum, $ir_class,           $ir_order,  $family, $genus,
             $species, $strain, $taxon_display_name, $taxon_oid, $seq_status
          )
          = $cur->fetchrow();
        last if !$domain;
        if ( $old_domain ne $domain ) {
            my $rec = "domain\t";
            $rec .= "$domain\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            push( @recs, $rec );
        }
        if ( $old_phylum ne $phylum ) {
            my $rec = "phylum\t";
            $rec .= "$phylum\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum";
            push( @recs, $rec );
        }
        if ( $old_genus ne $genus ) {
            my $rec = "genus\t";
            $rec .= "$genus\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus";
            push( @recs, $rec );
        }
        if ( $old_taxon_oid ne $taxon_oid ) {
            my $rec = "taxon_display_name\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus\t";
            $rec .= "$taxon_oid\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "$seq_status\t";
            push( @recs, $rec );
        }
        $old_domain    = $domain;
        $old_phylum    = $phylum;
        $old_genus     = $genus;
        $old_taxon_oid = $taxon_oid;
    }

    $cur->finish();

    # fill in the javascript event actions func calls
    my @recs2 = fillLineRange( \@recs );

    #  test js
    printJavaScript2();

    #    print "<script language='JavaScript' type='text/javascript'\n";
    #    print "src='$base_url/test.js'>\n";
    #    print "</script>\n";

    # radio buttons
    print "<p>\n";
    print "Select Protein Cluster <br>";
    print "<input type='radio' name='cluster' value='cog' checked />";
    print "COG<br>\n";
    if ($include_cassette_pfam) {
        print "<input type='radio' name='cluster' value='pfam' />";
        print "Pfam<br>\n";
    }
    if ($include_cassette_bbh) {
        print "<input type='radio' name='cluster' value='bbh' />";
        print "IMG Ortholog Cluster\n";
    }
    print "</p>\n";

    # table column headers
    print "<table class='img' border='1'>\n";
    print "<th class='img'>Find<br/>Genes<br/>In*</th>\n";
    print "<th class='img'>Collocated<br/>In</th>\n";
    if ($ENABLE_NOT_IN) {
        print "<th class='img'>Not<br>Collocated<br/>In</th>\n";
    }
    print "<th class='img'>Ignoring</th>\n";

    my $count     = 0;
    my $taxon_cnt = 0;
    for my $r (@recs2) {
        $count++;
        my ( $type, $type_value, $lineRange, $domain, undef ) =
          split( /\t/, $r );
        if ( $type eq "domain" || $type eq "phylum" || $type eq "genus" ) {
            my ( $line1, $line2 ) = split( /:/, $lineRange );

            print "<tr class='highlight'>\n";

            my $func = "selectGroupProfile($line1,$line2,0,'find')";
            print "<td class='img' >\n";
            print "  <input type='hidden' onClick=\"$func\" " . "name='groupProfile.$count' value='find' />\n";
            print "</td>\n";

            print "<td class='img' >\n";
            my $func = "selectGroupProfile($line1,$line2,1,'collocated')";
            print "  <input type='radio' onClick=\"$func\" " . "name='groupProfile.$count' value='coll'/>\n";
            print "</td>\n";

            if ($ENABLE_NOT_IN) {
                print "<td class='img' >\n";
                my $func = "selectGroupProfile($line1,$line2,2,'notCollocated')";
                print "  <input type='radio' onClick=\"$func\" " . "name='groupProfile.$count' value='notColl'/>\n";
                print "</td>\n";

                print "<td class='img' >\n";
                my $func = "selectGroupProfile($line1,$line2,3,'ignore')";
                print "  <input type='radio' onClick=\"$func\" " . "name='groupProfile.$count' value='ignore' />\n";
                print "</td>\n";
            } else {

                print "<td class='img' >\n";
                my $func = "selectGroupProfile($line1,$line2,2,'ignore')";
                print "  <input type='radio' onClick=\"$func\" " . "name='groupProfile.$count' value='ignore' />\n";
                print "</td>\n";
            }

            my $sp;
            $sp = nbsp(2) if $type eq "phylum";
            $sp = nbsp(4) if $type eq "genus";

            print "<td class='img' >\n";
            print $sp;
            my $incr = '+0';
            $incr = "+1" if $type eq "domain";
            $incr = "+1" if $type eq "phylum";
            print "<font size='$incr'>\n";
            print "<b>\n";
            print escHtml($type_value);
            print "</b>\n";
            print "</font>\n";
            print "</td>\n";

            print "</tr>\n";

        } elsif ( $type eq "taxon_display_name" && $domain ne '*Microbiome' ) {
            my ( $type, $type_value, $lineRange, $domain, $phylum, $genus, $taxon_oid, $taxon_display_name, $seq_status ) =
              split( /\t/, $r );
            $seq_status = substr( $seq_status, 0, 1 );
            print "<tr class='img' >\n";

            print "<td class='img' >\n";
            print "<input type='radio' onClick=\""
              . "checkFindCount(mainForm.elements['profile$taxon_oid'])\""
              . " name='profile$taxon_oid' "
              . "value='find' />\n";
            print "</td>\n";

            print "<td class='img' >\n";
            print "<input type='radio' onClick=\""
              . "checkCollCount(mainForm.elements['profile$taxon_oid'])\""
              . " name='profile$taxon_oid' "
              . "value='coll' />\n";
            print "</td>\n";

            if ($ENABLE_NOT_IN) {
                print "<td class='img' >\n";
                print "<input type='radio' onClick=\""
                  . "checkNotCollCount(mainForm.elements['profile$taxon_oid'])\""
                  . " name='profile$taxon_oid' "
                  . "value='notColl' />\n";
                print "</td>\n";
            }

            print "<td class='img' >\n";
            print "  <input type='radio' name='profile$taxon_oid' value='0' ";
            print "   checked />\n";
            print "</td>\n";

            print "<td class='img' >\n";
            print nbsp(6);
            my $c;
            $c = "[$seq_status]" if $seq_status ne "";
            my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail" . "&taxon_oid=$taxon_oid";
            if ($img_internal) {
                print alink( $url, "$taxon_display_name ($taxon_oid)" );
            } else {
                print alink( $url, "$taxon_display_name" );
            }
            print nbsp(1) . $c;
            print "</td>\n";
            print "</tr>\n";
            $taxon_cnt++;
        }
    }
    print "</table>\n";

    # tell main.pl where to go on submit
    print hiddenVar( "section", $section );

    if ($enable_fastbit) {
        print hiddenVar( "page", "fastbit" );
    } else {
        print hiddenVar( "page", "geneContextPhyloProfilerRun2" );
    }

    print submit( -class => 'smdefbutton', -name => 'submit', -value => 'Go' );
    print nbsp(1);
    print reset( -class => 'smbutton' );

    #$dbh->disconnect();
    printStatusLine( "$taxon_cnt Loaded.", 2 );
    print end_form();
}

# form page helper
#
# calculate the radio button information
#
sub fillLineRange {
    my ($recs_ref) = @_;
    my @recs2;
    my $nRecs = @$recs_ref;
    for ( my $i = 0 ; $i < $nRecs ; $i++ ) {
        my $r = $recs_ref->[$i];
        my ( $type, $type_val, $lineRange, $domain, $phylum, $genus, $taxon_oid, $taxon_display_name ) = split( /\t/, $r );
        if ( $type eq "domain" || $type eq "phylum" || $type eq "genus" ) {
            my $j = $i + 1;
            for ( ; $j < $nRecs ; $j++ ) {
                my $r2 = $recs_ref->[$j];
                my ( $type2, $type_val2, $lineRange2, $domain, $phylum, $genus, $taxon_oid, $taxon_display_name ) =
                  split( /\t/, $r2 );
                last if ( $domain ne $type_val ) && $type eq "domain";
                last if ( $phylum ne $type_val ) && $type eq "phylum";
                last if ( $genus  ne $type_val ) && $type eq "genus";
            }
            $r =~ s/__lineRange__/$i:$j/;
        }
        if ( $type eq "taxon_display_name" && $domain eq "*Microbiome" ) {
            my $j = $i + 1;
            for ( ; $j < $nRecs ; $j++ ) {
                my $r2 = $recs_ref->[$j];
                my ( $type2, $type_val2, $lineRange2, $domain2, $phylum2, $genus2, $taxon_oid2, $taxon_display_name2 ) =
                  split( /\t/, $r2 );
                last if ( $taxon_oid ne $taxon_oid2 );
            }
            $r =~ s/__lineRange__/$i:$j/;
        }
        push( @recs2, $r );
    }
    return @recs2;
}

# gets genomes cassette count
sub getCassetteCount {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
        select count(*)
        from gene_cassette
        where taxon = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($count) = $cur->fetchrow();
    $cur->finish();
    return $count;
}

# gets genomes count of distinct genes using in cassettes
sub getCassettteGeneCount {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
        select count(distinct gcg.gene)
        from gene_cassette_genes gcg, gene g
        where gcg.gene = g.gene_oid
        and g.taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($count) = $cur->fetchrow();
    $cur->finish();
    return $count;

}

sub getGenomeGeneCount {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
        select count(*)
        from gene g
        where g.taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($count) = $cur->fetchrow();
    $cur->finish();
    return $count;

}

# stats table of profiler's run results
# - cache restuls from profilers?
# - if cache removed - do sql again?
# - if yes sql then need a javascript form
# - hidden param - name=profile$toid value=find, coll, notColl
# - set param stats=true to reuse the printGeneContextPhyloProfilerRun
#   to recalc data again and cache it and then run my stats page
#
# $cass_gene_href - cassette id => hash set of genes
#
sub printProfilerStats {
    my ( $dbh, $cass_gene_href, $type, $taxon_oid ) = @_;

    # hash gene count => cassette occurrence
    my %gene_count;

    my $cass_count = 0;     # number or result cassettes
    my %gene_count_hash;    # set of unique genes

    foreach my $cid ( keys %$cass_gene_href ) {
        my $href = $cass_gene_href->{$cid};
        my $size = keys %$href;               # gene count

        if ( exists $gene_count{$size} ) {
            $gene_count{$size} = $gene_count{$size} + 1;
        } else {
            $gene_count{$size} = 1;
        }

        if ( $size >= $MIN_GENES ) {
            $cass_count++;

            foreach my $gid ( keys %$href ) {
                $gene_count_hash{$gid} = "";
            }
        }

    }

    print "<h3>Statistics</h3>\n";

    printMessages();

    my $genome_cass_count        = getCassetteCount( $dbh,      $taxon_oid );
    my $genome_genes_in_cass_cnt = getCassettteGeneCount( $dbh, $taxon_oid );
    my $genome_genes_cnt         = getGenomeGeneCount( $dbh,    $taxon_oid );
    my $tmp                      = keys %gene_count_hash;

    # percent
    my $cass = 100 * $cass_count / $genome_cass_count;
    $cass = sprintf( "%.2f%%", $cass );
    my $cass2 = 100 * $tmp / $genome_genes_in_cass_cnt;
    $cass2 = sprintf( "%.2f%%", $cass2 );
    my $cass3 = 100 * $tmp / $genome_genes_cnt;
    $cass3 = sprintf( "%.2f%%", $cass3 );

    #    print qq{
    #        <p>
    #        Cassette Count: $cass_count / $genome_cass_count ($cass)
    #        <br/>
    #        Gene Count: $tmp / $genome_genes_in_cass_cnt ($cass2),
    #        $genome_genes_cnt ($cass3)
    #        </p>
    #    };

    print qq{
        <p>
        <ul>
        <li>
        <b>$cass_count ($cass)</b> gene cassettes in <b>query genome</b> 
        from a total of <b>$genome_cass_count</b> gene cassettes considered.
        </li>
        <li>
        <b>$tmp ($cass2)</b> genes in <b>query genome</b> 
        from a total of <b>$genome_genes_in_cass_cnt</b> genes, 
        have collocated cassettes across all other genomes.
        </li>
        </ul>
        </p>
    };

    print "<p>\n";
    my $it = new InnerTable( 1, "cassetteBox" . $type . "$$", "cassetteBox$type", 0 );

    $it->addColSpec( "No of Collocated Genes", "number desc", "right" );
    $it->addColSpec( "Occurrences",            "number desc", "right" );

    my $sd = $it->getSdDelim();    # sort delimiter

    #my $url = "$section_cgi&page=cassetteBoxDetail&type=$type";

    foreach my $gcount ( sort keys %gene_count ) {
        my $occurrence = $gene_count{$gcount};

        next if ( $gcount < $MIN_GENES );

        #my $tmpurl = $url . "&cluster_count=$cluster_count";
        #$tmpurl = alink( $tmpurl, $cluster_count );
        my $r;
        $r .= $gcount . $sd . "\t";
        $r .= $occurrence . $sd . "\t";
        $it->addRow($r);
    }

    $it->printOuterTable(1);
    print "</p>\n";
}

#
# new version to sdhow only interesting of boxes not union and the
# the biggest box and ignore the small boxes within if within a big box
#
sub printGeneContextPhyloProfilerRun2 {
    my $type = param("cluster");

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();

    my @taxonOids;    # list of all taxon oids
    my @findList;     # list of find   taxon   oids
    my @collList;     # list of taxon ids Collocated in
    my @notCollList;

    my $urClause  = urClause("gc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('gc.taxon');
    my $sql       = qq{
       select distinct gc.taxon 
       from gene_cassette gc
       where 1 = 1
       $urClause
       $imgClause
    };
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        push( @taxonOids, $taxon_oid );
    }

    $cur->finish();

    #
    # Now find what user had selected on the form
    #
    my $taxon_count = 0;
    foreach my $toid (@taxonOids) {
        my $profileVal = param("profile$toid");
        next if $profileVal eq "0" || $profileVal eq "";

        if ( $profileVal eq "find" ) {
            push( @findList, $toid );
        } elsif ( $profileVal eq "coll" ) {
            push( @collList, $toid );
        } elsif ( $profileVal eq "notColl" ) {
            push( @notCollList, $toid );
        }

        if ( $#findList > 1 ) {

            #$dbh->disconnect();
            printStatusLine( "Loaded.", 2 );
            printEndWorkingDiv();
            webLog( "Please select only 1 genome " . "in the \"Find In\" column 1.\n" );
            webError( "Please select only 1 genome " . "in the \"Find In\" column." );
            return;
        }
    }    # end for

    # check size of arrays
    if ( $#findList > 0 || $#findList < 0 ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        printEndWorkingDiv();
        webLog( "Please select 1 genome " . "in the \"Find In\" column 2.\n" );
        webError( "Please select 1 genome " . "in the \"Find In\" column." );
        return;
    }
    if ( $#collList < 0 && $#notCollList < 0 ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );

        printEndWorkingDiv();
        webLog(   "Please select at least 1 genome "
                . "in the \"Collocated In\" column"
                . " or in the \"Not Collocated In\" column.\n" );

        webError( "Please select at least 1 genome " . "in the \"Collocated In\" column" );
        return;
    }
    my $oraclemax = WebUtil::getORACLEMAX();
    if ( $#collList >= $oraclemax ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        printEndWorkingDiv();
        webError( "Please select less than $oraclemax genomes " . "in the \"Collocated In\" column" );
        return;
    } elsif ( $#notCollList >= $oraclemax ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );

        printEndWorkingDiv();
        webError( "Please select less than $oraclemax genomes " . "in the \"Not Collocated In\" column." );
        return;
    }

    # split the code to run IN and NOT IN sections

    #  $boxCluster_href - box id => hash of cluster ids
    #  $cassette_ids_href - hash of cassettes ids => hash set of box ids
    my $boxCluster_href   = "";
    my $cassette_ids_href = "";

    if ( $#collList > -1 ) {
        ( $boxCluster_href, $cassette_ids_href ) = runIn( $dbh, \@findList, \@collList, $type, $findList[0] );
    }

    my $notin_boxCluster_href   = "";
    my $notin_cassette_ids_href = "";
    if ( $ENABLE_NOT_IN && $#notCollList > -1 ) {

        # NOT in section
        # $notin_boxCluster_href - box id => hash of cluster ids
        # $notin_cassette_ids_href - hash of cassettes ids => hash set of box ids
        ( $notin_boxCluster_href, $notin_cassette_ids_href ) = runNotIn( $dbh, \@findList, \@notCollList, $type );

        if ( $cassette_ids_href eq "" && $notin_cassette_ids_href eq "" ) {

            #$dbh->disconnect();
            printStatusLine( "Loaded.", 2 );
            return;
        }

        # what if  $cassette_ids_href eq "" && $notin_cassette_ids_href ne ""
        # special case - no IN genome selected or found
        if ( $cassette_ids_href eq "" && $notin_cassette_ids_href ne "" ) {
            $cassette_ids_href = $notin_cassette_ids_href;
        }
    } else {
        if ( $cassette_ids_href eq "" ) {

            #$dbh->disconnect();
            printStatusLine( "Loaded.", 2 );
            printEndWorkingDiv();

            print qq{
                <p>
                No Cassette Data Found
            };
            return;
        }
    }

    # pass in the cluster box and use it to filter the matches
    # cassette id => hash set of genes
    # this also filters the data from common cluster
    #
    #
    my $t = dateTimeStr();
    webLog("getCassetteGenes2 start time was $t\n");
    my ( $cass_gene_href, $rejectedClusterCount, $commonClusterCount ) =
      getCassetteGenes2( $dbh, $cassette_ids_href, $boxCluster_href, $type, $notin_boxCluster_href, $notin_cassette_ids_href,
                         $findList[0] );
    my $t = dateTimeStr();
    webLog("getCassetteGenes2 end time was $t\n");

    # -------------------------------------------------
    #
    # filter boxes
    #  - remove smaller boxes within a bigger box
    # algorithm
    # 1 - sort boxes, biggest gene count 1st
    # 2 - go thru the list of sorted
    # 3 - compare it to ones before it, (bigger ones)
    #     to see if the gene already exist
    #    - if no add
    #    - if yes skip this cassette entirely
    #
    # Assumptions: boxes can be within another box BUT
    # boxes DO NOT overlap each other
    # -------------------------------------------------
    # NOW do another filter of the data  ken
    # sort hash by gene size
    #
    # number of genes in a cassette
    # hash cid,boxid => size
    my %gene_cassette_cnt;
    foreach my $cid ( keys %$cass_gene_href ) {
        my $href = $cass_gene_href->{$cid};
        my $size = keys %$href;
        $gene_cassette_cnt{$cid} = $size;
    }

    # list of cassid,boxid to keep
    my @keepIds;

    # sorted cassettes by genesize
    my @sorted =
      sort { $gene_cassette_cnt{$b} <=> $gene_cassette_cnt{$a} }
      keys %gene_cassette_cnt;

    # keep the 1st one, since its the biggest
    push( @keepIds, $sorted[0] ) if ( $#sorted > -1 );
    for ( my $i = 1 ; $i <= $#sorted ; $i++ ) {

        # cass, box id i'm interested in
        my $cbid1 = $sorted[$i];

        # key are cass id , box id
        my ( $cid, $bid ) = split( /,/, $cbid1 );
        my $add = 1;

        # i only need to check the bigger cassettes
        # but what if the cassette size is the same - i miss it
        for ( my $j = 0 ; $j < $i ; $j++ ) {

            # cass ids, box ids to compare against cbid1
            # cbid2 are the one 0 to $i of sorted array
            my $cbid2 = $sorted[$j];

            next if ( $cbid2 eq $cbid1 );
            my ( $cid2, $bid2 ) = split( /,/, $cbid2 );
            if ( $cid eq $cid2 ) {

                # same cassette id
                my $gene_href2 = $cass_gene_href->{$cbid2};
                my $gene_href1 = $cass_gene_href->{$cbid1};
                foreach my $gene1 ( keys %$gene_href1 ) {
                    if ( exists( $gene_href2->{$gene1} ) ) {

                        # gene exist in a box pervious looked at
                        # so skip this cass,box
                        $add = 0;
                        last;
                    } else {
                        $add = 1;
                    }
                }
                last if ( $add == 0 );
            }
        }
        if ( $add == 1 ) {
            push( @keepIds, $cbid1 );
        }
    }

    #print Dumper \@sorted;
    #print "<br/>";
    #print Dumper \@keepIds;
    my %distinct_box_hash;
    foreach my $id (@keepIds) {
        my ( $c, $b ) = split( /,/, $id );
        $distinct_box_hash{$b} = "";

        #print "$id<br/> \n";
    }

    my %cass_gene_tmp;
    foreach my $cbid (@keepIds) {
        $cass_gene_tmp{$cbid} = $cass_gene_href->{$cbid};
    }
    $cass_gene_href = {};
    $cass_gene_href = \%cass_gene_tmp;    # new filter list

    #
    # end of last filter
    #
    # -------------------------------------------------

    my $taxonName = QueryUtil::fetchTaxonName( $dbh, $findList[0] );

    printEndWorkingDiv();

    print "<h1>$taxonName "
      . "<br>Phylogenetic Profiler for Gene Cassettes Results"
      . "<br>By "
      . GeneCassette::getTypeTitle($type)
      . " Conserved Cassettes</h1>\n";

    if ($img_internal) {
        print "<p>";
        print Dumper \@findList;
        print "<br> in list: ";
        print Dumper \@collList;
        print "<br> not in list: ";
        print Dumper \@notCollList;
        print "</p>\n";
    }

    my $inCnt  = $#collList + 1;
    my $notCnt = $#notCollList + 1;

    print "<p>\n";

    if ( $inCnt > 0 ) {
        print "$inCnt Collocated In genomes.<br/>\n";

        #if ($img_internal) {
        my $names_aref = getTaxonNameList( $dbh, \@collList );
        foreach my $line (@$names_aref) {
            my ( $id, $name ) = split( /\t/, $line );
            my $url = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$id";
            $url = alink( $url, $name );
            print "&nbsp;&nbsp;&nbsp;&nbsp; $url <br/>\n";
        }

        #}
    }

    if ( $notCnt > 0 && $img_internal ) {
        print "$notCnt Not Collocated In genomes.<br/>\n";
        if ($img_internal) {
            my $names_aref = getTaxonNameList( $dbh, \@notCollList );
            foreach my $line (@$names_aref) {
                my ( $id, $name ) = split( /\t/, $line );
                print "&nbsp;&nbsp;&nbsp;&nbsp; $name<br/>\n";
            }
        }
    }
    print "</p>\n";

    # print stats table now
    printProfilerStats( $dbh, $cass_gene_href, $type, $findList[0] );
    my $size = keys %distinct_box_hash;
    print qq{
        <p>
        Conserved cassette boxes: $size
        </p>
    };

    print "<p>\n";
    print "<h3>Details</h3>\n";
    print "</p>\n";

    #    print qq{
    #    <p>
    #    <b>Notes.</b><br/>
    #    <ol>
    #    <li>
    #        The list of collocated genes below is grouped by
    #        <b>chromosomal cassettes</b> in the <b>query genome</b>.
    #    </li>
    #    <li>
    #        In a <b>specific group</b> of collocated genes in the query genome:
    #        <ul>
    #        <li>
    #            Genes may correspond to (potentially <b>conserved</b>)
    #            parts of <b>multiple chromosomal cassettes</b> in the
    #            <b>other genomes</b> involved in the profiler condition.
    #        </li>
    #        <li>
    #            The <b>conserved part</b> of a chromosomal cassette involving
    #            a specific gene in the query genome can be examined using the
    #            links provided in the <b>&quot;Conserved Neighborhood Viewer
    #            Centered on this Gene&quot;</b> column of the table below.
    #        </li>
    #        </ul>
    #    </li>
    #    </ol>
    #    </p>
    #    };

    printMainForm();
    printGeneCartFooter();
    printCassetteGeneDetails2( $dbh, $cass_gene_href, $type, $rejectedClusterCount, $commonClusterCount );
    print end_form();

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
}

#
# gets taxon names given a l ist of taxon oids
#
sub getTaxonNameList {
    my ( $dbh, $taxon_aref ) = @_;

    my $str;
    if ( OracleUtil::useTempTable( scalar(@$taxon_aref) ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", $taxon_aref );
        $str = " select id from gtt_num_id ";
    } else {
        $str = join( ",", @$taxon_aref );
    }

    my $sql = qq{
        select taxon_oid, $nvl(taxon_display_name, taxon_name)
        from taxon 
        where taxon_oid in ($str)
        order by 2
        };

    my $cur = execSql( $dbh, $sql, $verbose );
    my @names;
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        push( @names, "$id\t$name" );
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" );
    return \@names;
}

# using temp tables to store common box ids
sub insertTemp {
    my ( $dbh, $taxon_aref, $in_taxon_aref, $type ) = @_;

    my $str   = join( ",", @$taxon_aref );
    my $instr = join( ",", @$in_taxon_aref );
    my $insize = $#$in_taxon_aref + 1 + 1;

    my $sql;

    if ( $type eq "bbh" ) {
        print "<font color='red'>Please wait this may take 2-5 mins." . "<br/> Scanning 70+ million records </font> <br/>\n";

        $sql = qq{
           select cbcc2.box_oid, cbcc2.taxon
            from cassette_box_cassettes_bbh cbcc2, cassette_box_cassettes_bbh b2
            where cbcc2.taxon in ($str, $instr)
            and cbcc2.box_oid = b2.box_oid
            and b2.taxon = ?            
        };

    } elsif ( $type eq "pfam" ) {
        print "<font color='red'>Please wait this may take 5-10 mins."
          . "<br/> Scanning 850+ million records </font> <br/>\n";

        $sql = qq{
           select cbcc2.box_oid, cbcc2.taxon
            from cassette_box_cassettes_pfam cbcc2, cassette_box_cassettes_pfam b2
            where cbcc2.taxon in ($str, $instr)
            and cbcc2.box_oid = b2.box_oid
            and b2.taxon = ?            
        };

    } elsif ( $type eq "cog" ) {
        print "<font color='red'>Please wait this may take 2-5 mins."
          . "<br/> Scanning 170+ million records </font> <br/>\n";

        $sql = qq{
           select cbcc2.box_oid, cbcc2.taxon
            from cassette_box_cassettes_cog cbcc2, cassette_box_cassettes_cog b2
            where cbcc2.taxon in ($str, $instr)
            and cbcc2.box_oid = b2.box_oid
            and b2.taxon = ?            
        };
    }

    # box id => hash of taxon ids
    my %hash;

    my $cur = execSql( $dbh, $sql, $verbose, $str );
    my $count = 0;
    for ( ; ; ) {
        my ( $boid, $toid ) = $cur->fetchrow();
        last if !$boid;

        # we need to distinct the taxon oid counts too
        if ( exists $hash{$boid} ) {
            my $href = $hash{$boid};
            $href->{$toid} = 1;
        } else {
            my %h;
            $h{$toid}    = 1;
            $hash{$boid} = \%h;
        }

        $count++;
        if ( $count % 1000 == 0 ) {
            print " $count ... ";
        }
        if ( $count % 10000 == 0 ) {
            print " <br/>\n ";
        }
    }
    print "<br/>\n";
    $cur->finish();

    my @list;
    foreach my $id ( keys %hash ) {
        my $href = $hash{$id};
        my $cnt  = keys %$href;
        if ( $cnt == $insize ) {
            push( @list, $id );
        }
    }
    my $tmp = $#list + 1;
    print "Found $tmp records in commond between $insize genomes <br/> \n";

    print "Inserting into temp tables<br/>\n";
    my $t = dateTimeStr();
    webLog("insertTemp2 start time was $t\n");
    OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@list );
    my $t = dateTimeStr();
    webLog("insertTemp2 end time was $t\n");

}

# Find all the IN data I need
#
# param
#   dbh
#   find in array of genomes
#   collocated in array genomes
#   type - cluster type
#
# return
#  $boxCluster_href - box id => hash of cluster ids
#  $cassette_ids_href - hash of cassettes ids => hash set of box ids
sub runIn {
    my ( $dbh, $findList_aref, $collList_aref, $type, $query_taxon_oid ) = @_;

    # get all common boxes between given taxons
    print "Getting conserved cassette boxes.<br>\n";

    # ORACLE global temp table
    my $t = dateTimeStr();
    webLog("insertTemp start time was $t\n");
    insertTemp( $dbh, $findList_aref, $collList_aref, $type );
    my $t = dateTimeStr();
    webLog("insertTemp end time was $t\n");

    # list of box ids
    my $boxes_aref = getCassetteBoxes( $dbh, $findList_aref, $collList_aref, $type );

    if ( $boxes_aref eq "pfam" || $boxes_aref eq "cog" || $boxes_aref eq "bbh" ) {

        # do nothing
    } elsif ( $#$boxes_aref < 0 ) {
        print "<br>No IN boxes<br>";

        ##$dbh->disconnect();
        #printStatusLine( "Loaded.", 2 );
        return ( "", "" );
    }

    my $tmps = 0;
    if ( $boxes_aref eq "pfam" || $boxes_aref eq "cog" || $boxes_aref eq "bbh" ) {

        # do nothing
    } else {
        my $tmps = $#$boxes_aref + 1;

        #addMessage("$tmps common boxes found.");

        print "Found $tmps boxes.<br>\n";
    }
    print "Getting genes in cassette boxes.<br>\n";

    # now get hash of hashes
    # box id => hash of cluster ids
    # from x_cog_xlog table
    # match size of 2 min $MIN_GENES - BUT 2 different genes not 2 different
    #   - min genes filter done during printing html table - ken
    # protein for the same gene, ie pfams for a gene
    print "Finding box clusters<br>\n";

    #webLog("Running getBoxCluster.\n");
    my $t = dateTimeStr();
    webLog("getBoxCluster start time was $t\n");
    my $boxCluster_href = getBoxCluster( $dbh, $boxes_aref, $type, $query_taxon_oid );
    my $t = dateTimeStr();
    webLog("getBoxCluster end time was $t\n");

    $tmps = keys(%$boxCluster_href);
    print "Found $tmps box clusters.<br>\n";

    webLog("Running getContextBoxesCassettes.\n");

    #  get a hash of cassettes ids => hash set of box ids
    my $t = dateTimeStr();
    webLog("getContextBoxesCassettes start time was $t\n");
    my $cassette_ids_href = getContextBoxesCassettes( $dbh, $findList_aref, $boxes_aref, $type );
    my $t = dateTimeStr();
    webLog("getContextBoxesCassettes start time was $t\n");

    if ( keys(%$cassette_ids_href) < 1 ) {
        print "<br>No IN cassetttes<br>";

        ##$dbh->disconnect();
        #printStatusLine( "Loaded.", 2 );
        return ( $boxCluster_href, "" );
    }
    $tmps = keys(%$cassette_ids_href);
    print "Found $tmps cassettes.<br>\n";

    return $boxCluster_href, $cassette_ids_href;

}

# Find all the NOT IN data I need
#
# 1, get all the in common boxes in Gin that are in (Gc1 ... Gcn1) union
# not AND
# similar to getCassetteBoxes() but without the count(*) and having
# statements
#
# 2. get all the cassettes for the boxes in 1.
# 3. get all the clusters from boxes in 1.
# these are the cluster to reject
#
# return the cassette list and cluster list
sub runNotIn {
    my ( $dbh, $findList_aref, $notCollList_aref, $type ) = @_;

    # get all common boxes between given taxons
    # union not the intersection
    print "Getting NOT IN  conserved cassette boxes.<br>\n";
    my $boxes_aref = getCassetteBoxesNotIn( $dbh, $findList_aref, $notCollList_aref, $type );

    if ( $#$boxes_aref < 0 ) {
        print "<br>No NOT IN boxes<br>";
        return ( "", "" );
    }

    my $tmps = $#$boxes_aref + 1;
    print "Found $tmps NOT IN boxes.<br>\n";
    print "Getting NOT IN genes in cassette boxes.<br>\n";
    print "Finding NOT IN box clusters<br>\n";

    #  box id => hash set of cluster ids
    my $boxCluster_href = getBoxCluster( $dbh, $boxes_aref, $type );
    $tmps = keys(%$boxCluster_href);
    print "Found $tmps NOT IN box clusters.<br>\n";

    #  get a hash of cassettes ids => hash set of box ids
    my $cassette_ids_href = getContextBoxesCassettes( $dbh, $findList_aref, $boxes_aref, $type );
    if ( keys(%$cassette_ids_href) < 1 ) {
        print "<br>No NOT IN cassetttes<br>";
        return ( $boxCluster_href, "" );
    }
    $tmps = keys(%$cassette_ids_href);
    print "Found $tmps NOT IN cassettes.<br>\n";

    return ( $boxCluster_href, $cassette_ids_href );
}

# prints results html tables
# $cass_gene_href - cassette id => hash set of genes
#
#
sub printCassetteGeneDetails2 {
    my ( $dbh, $cass_gene_href, $type, $rejectedClusterCount, $commonClusterCount ) = @_;

    # sort hash by gene size
    my %gene_cassette_cnt;
    foreach my $cid ( keys %$cass_gene_href ) {
        my $href = $cass_gene_href->{$cid};
        my $size = keys %$href;
        $gene_cassette_cnt{$cid} = $size;
    }

    my @sorted =
      sort { $gene_cassette_cnt{$b} <=> $gene_cassette_cnt{$a} }
      keys %gene_cassette_cnt;

    #print "$#sorted + 1 = " . keys %$cass_gene_href;

    # print table header
    # table column headers
    print "<table class='img' border='1'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Result<br>Row</th>\n";
    print "<th class='img'>Gene ID</th>\n";

    #print "<th class='img'>Locus Tag</th>\n";
    print "<th class='img'>Gene Product Name</th>\n";
    print "<th class='img'>Length</th>\n";
    print "<th class='img'>Cassette ID</th>\n";
    print "<th class='img' title='Locus Tag'>" . "Conserved Neighborhood Viewer Centered on this Gene</th>\n";

    my $row_count  = 0;
    my $cass_count = 0;
    my $gurl       = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";

    # to cassette details page
    my $curl = "$main_cgi?section=GeneCassette&page=cassetteBox" . "&type=$type&cassette_oid=";

    # to cassette neighborhood viewer
    #my $curl = "$main_cgi?section=GeneCassette&page=geneCassette"
    #  . "&type=$type&cassette_oid=";

    #foreach my $coid ( keys %$cass_gene_href ) {

    my %genesPrinted;
    my $dup_gene_count = 0;

    foreach my $coid (@sorted) {
        my $gene_href = $cass_gene_href->{$coid};
        my $size      = keys %$gene_href;

        # $MIN_GENES = 2
        next if ( $size < $MIN_GENES );
        $cass_count++;

        my $gene_detail_aref = getGeneDetails( $dbh, $gene_href );

        my $count = 1;
        foreach my $line (@$gene_detail_aref) {
            my ( $gene_oid, $locus_tag, $gene_display_name, $dna_seq_length ) =
              split( /\t/, $line );

            # removed genes already printed???
            # what about if there is only one left?
            if ( exists $genesPrinted{$gene_oid} ) {
                $dup_gene_count++;

                #next;
            }
            $genesPrinted{$gene_oid} = "";

            if ( $cass_count % 2 != 0 ) {
                print "<tr class='highlight' >\n";
            } else {
                print "<tr class='img' >\n";
            }

            # column 1
            print "<td class='img' >\n";
            print qq{
                <input type='checkbox' name='gene_oid' value='$gene_oid'  />
            };
            print "</td>\n";

            # column 2
            print "<td class='img' align='right'>\n";
            print $count;
            print "</td>\n";

            # column 3
            print "<td class='img' >\n";
            print alink( "$gurl" . "$gene_oid", "$gene_oid" );
            print "</td>\n";

            print "<td class='img' >\n";
            print "$gene_display_name";
            print "</td>\n";

            print "<td class='img' align='right'>\n";
            print "$dna_seq_length";
            print "</td>\n";

            print "<td class='img' >\n";

            if ( $count == 1 ) {
                my ( $c2, $b2 ) = split( /,/, $coid );
                if ($img_internal) {

                    # print box id
                    print alink( "$curl" . "$c2", "$c2 ($b2)" );
                } else {
                    print alink( "$curl" . "$c2", "$c2" );
                }
            } else {

                print "&nbsp;";

                #print alink( "$curl" . "$c2", "$coid" );
            }
            print "</td>\n";

            # locus tag
            my $url = "main.cgi?section=GeneCassette" . "&page=geneCassette&gene_oid=$gene_oid&type=$type";
            $locus_tag = "view" if ( $locus_tag eq "" );
            print "<td class='img' >\n";

            #print "$locus_tag";
            print "<a href='" . $url . "'>  $locus_tag </a>";
            print "</td>\n";

            $count++;        # number of rows of the given cassette
            $row_count++;    # actual number of rows printed
        }
        print qq{
            <tr>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            <td class='img' >&nbsp; </td>
            </tr>            
        };
    }

    print "</table>";
    print qq{
        <p>
        Gene count: $row_count 
        &nbsp;&nbsp;&nbsp; 
        Cassette Count: $cass_count
        &nbsp;&nbsp;&nbsp; 
        <!--
        Duplicate Genes: $dup_gene_count 
        &nbsp;&nbsp;&nbsp;
        <br> 

        Rejected Clusters: $rejectedClusterCount
        &nbsp;&nbsp;&nbsp; 
        Common Clusters: $commonClusterCount
        -->
        </p>
    };
}

#
# gets gene details
#
# param
#   dbh
#   hash of genes
# return
#   array of tab delimited gene details
sub getGeneDetails {
    my ( $dbh, $gene_href ) = @_;

    my @gene_array;
    my @questions_marks;
    foreach my $gid ( keys %$gene_href ) {
        push( @gene_array,      $gid );
        push( @questions_marks, "?" );
    }

    my $gene_str = join( ",", @questions_marks );    #join( ",", @gene_array );

    my $sql = qq{
        select gene_oid, locus_tag, gene_display_name, dna_seq_length
        from gene
        where gene_oid in ($gene_str)
        order by gene_oid
    };

    my @list;

    my $cur = execSql( $dbh, $sql, $verbose, @gene_array );

    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $gene_display_name, $dna_seq_length ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @list, "$gene_oid\t$locus_tag\t$gene_display_name\t$dna_seq_length" );
    }

    #$cur->finish(); do not call in a loop - ken 2010-03-31

    return \@list;

}

# gets all common boxes between given taxons
#
# param
#   dbh
#   array of find in genomes
#   array of collocate in genomes
#   cluster type
#
# return
#   array of box oids
sub getCassetteBoxes {
    my ( $dbh, $taxon_aref, $in_taxon_aref, $type ) = @_;

    #    my $str   = join( ",", @$taxon_aref );
    #    my $instr = join( ",", @$in_taxon_aref );
    #
    #    my $insize = $#$in_taxon_aref + 1 + 1;
    #    my $sql;

    if ( $type eq "bbh" ) {
        return "bbh";

    } elsif ( $type eq "pfam" ) {

        return "pfam";
    } else {
        return "cog";
    }

    #    my $cur = execSql( $dbh, $sql, $verbose );
    #
    #    my @boids_list;
    #    for ( ; ; ) {
    #        my ($boid) = $cur->fetchrow();
    #        last if !$boid;
    #        push( @boids_list, $boid );
    #    }
    #    $cur->finish();
    #
    #    return \@boids_list;

}

# gets cassettte boxes for not in
#
# param
#   dbh
#   array of find in genomes
#   array of not collocate in genomes
#   cluster type
#
# return
#   array of box oids
sub getCassetteBoxesNotIn {
    my ( $dbh, $taxon_aref, $notin_taxon_aref, $type ) = @_;

    my $str   = join( ",", @$taxon_aref );
    my $instr = join( ",", @$notin_taxon_aref );

    #my $insize = $#$notin_taxon_aref + 1;

    my $sql;

    if ( $type eq "bbh" ) {
        $sql = qq{
        select distinct cbcc1.box_oid
        from gene_cassette gc1, cassette_box_cassettes_bbh cbcc1
        where gc1.cassette_oid = cbcc1.cassettes
        and gc1.taxon in ($str)        
        and cbcc1.box_oid in (
            select distinct cbcc2.box_oid
            from gene_cassette gc2, cassette_box_cassettes_bbh cbcc2
            where gc2.cassette_oid = cbcc2.cassettes
            and gc2.taxon in ($instr)   
        )
        };

    } elsif ( $type eq "pfam" ) {
        $sql = qq{
        select distinct cbcc1.box_oid
        from gene_cassette gc1, cassette_box_cassettes_pfam cbcc1
        where gc1.cassette_oid = cbcc1.cassettes
        and gc1.taxon in ($str)        
        and cbcc1.box_oid in (
            select distinct cbcc2.box_oid
            from gene_cassette gc2, cassette_box_cassettes_pfam cbcc2
            where gc2.cassette_oid = cbcc2.cassettes
            and gc2.taxon in ($instr)
        )  
        };

    } else {
        $sql = qq{
        select distinct cbcc1.box_oid
        from gene_cassette gc1, cassette_box_cassettes_cog cbcc1
        where gc1.cassette_oid = cbcc1.cassettes
        and gc1.taxon in ($str)        
        and cbcc1.box_oid in (
            select distinct cbcc2.box_oid
            from gene_cassette gc2, cassette_box_cassettes_cog cbcc2
            where gc2.cassette_oid = cbcc2.cassettes
            and gc2.taxon in ($instr)
        )   
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose );

    my @boids_list;
    for ( ; ; ) {
        my ($boid) = $cur->fetchrow();
        last if !$boid;
        push( @boids_list, $boid );
    }
    $cur->finish();

    return \@boids_list;

}

# now get the cassette ids
#
# param
#   dbh
#   array of find in genomes
#   array of box ids
#   cluster type
#
# return
#   cassette ids => hash of box ids
sub getContextBoxesCassettes {
    my ( $dbh, $taxon_aref, $boxes_aref, $type ) = @_;

    my $str = join( ",", @$taxon_aref );

    my $sql;
    if ( $type eq "bbh" ) {
        $sql = qq{
        select b1.cassettes, b1.box_oid
        from cassette_box_cassettes_bbh b1
        where b1.taxon = ?
        and exists(
            select 1
            from gtt_num_id
            where id = b1.box_oid
         )        
        };

    } elsif ( $type eq "pfam" ) {
        $sql = qq{
        select b1.cassettes, b1.box_oid
        from cassette_box_cassettes_pfam b1
        where b1.taxon = ?
        and exists(
            select 1
            from gtt_num_id
            where id = b1.box_oid
         )        
        };

    } else {
        $sql = qq{
        select b1.cassettes, b1.box_oid
        from cassette_box_cassettes_cog b1
        where b1.taxon = ?
        and exists(
            select 1
            from gtt_num_id
            where id = b1.box_oid
         )        
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose, $str );

    # cassette ids => hash of box ids
    my %cassetteHash;
    for ( ; ; ) {
        my ( $coid, $boxid ) = $cur->fetchrow();
        last if !$coid;
        if ( exists $cassetteHash{$coid} ) {
            my $href = $cassetteHash{$coid};
            $href->{$boxid} = "";
        } else {
            my %hash;
            $hash{$boxid}        = "";
            $cassetteHash{$coid} = \%hash;
        }
    }
    $cur->finish();

    return \%cassetteHash;
}

# gets cassette genes
#
# filtering by cluster is done here
#
# $cassette_href - hash of cassettes ids => hash set of box ids
# $boxCluster_href - box id => hash of cluster ids
# cluster type
# $notin_boxCluster_href - box id => hash of cluster ids
# $notin_cassette_ids_href - hash of cassettes ids => hash set of box ids
#
# return cassette id => hash gene oids
#
#
# newer testing version
#
# $cassette_href - hash of cassettes ids => hash set of box ids
# $boxCluster_href - box id => hash of cluster ids
sub getCassetteGenes2 {
    my ( $dbh, $cassette_href, $boxCluster_href, $type, $notin_boxCluster_href, $notin_cassette_ids_href, $query_taxon_oid )
      = @_;

    my $oraclemax = WebUtil::getORACLEMAX();
    my $boxClause = "";
    if ( keys %$boxCluster_href < $oraclemax ) {
        my @a;
        foreach my $key ( keys %$boxCluster_href ) {
            push( @a, $key );
        }

        my $str = join( ",", @a );
        $boxClause = "and box.box_oid in ($str)";
    }

    # check this box set

    # IN
    # list of all clusters from _xlogs tables
    my %commonCluster;

    #my %rejectedCluster;
    my @cassetteList;

    # list of cassette ids for sql
    foreach my $cid ( keys %$cassette_href ) {
        push( @cassetteList, $cid );
    }

    # TODO - fixed not working NOT IN
    # cluster to be removed
    my %notinCluster;
    if ( $notin_boxCluster_href ne "" ) {
        foreach my $box_id ( keys %$notin_boxCluster_href ) {
            my $cluster_href = $notin_boxCluster_href->{$box_id};

            foreach my $cid ( keys %$cluster_href ) {
                $notinCluster{$cid} = "";
            }
        }
    }

    my $oraclemax = WebUtil::getORACLEMAX();
    my $sql;
    if ( $type eq "bbh" ) {
        my $str;
        if ( $#cassetteList < $oraclemax ) {
            $str = join( ",", @cassetteList );
        } else {
            OracleUtil::insertDataArray( $dbh, "gtt_num_id2", \@cassetteList );
            $str = " select id from gtt_num_id2 ";
        }

        $sql = qq{
        select gc.cassette_oid, gc.gene, bg.cluster_id as func, box.box_oid
        from cassette_box_cassettes_bbh box,
        gene_cassette_genes gc,
        bbh_cluster_member_genes bg
        where box.taxon = ?
        and box.cassettes = gc.cassette_oid
        and box.cassettes in ($str)
        and gc.gene       = bg.member_genes
        and exists (
            select 1
            from gtt_num_id
            where id = box.box_oid        
        )
        };
    } elsif ( $type eq "pfam" ) {

        # TODO fix 999 limit
        my $str;
        if ( $#cassetteList < $oraclemax ) {
            $str = join( ",", @cassetteList );
        } else {
            OracleUtil::insertDataArray( $dbh, "gtt_num_id2", \@cassetteList );
            $str = " select id from gtt_num_id2 ";
        }

        $sql = qq{
        select gc.cassette_oid, gc.gene, gpf.pfam_family as func, box.box_oid
        from cassette_box_cassettes_pfam box,
        gene_cassette_genes gc,
        gene_pfam_families gpf
        where box.taxon = ?
        and box.cassettes = gc.cassette_oid
        and box.cassettes in ($str)
        and gc.gene       = gpf.gene_oid
        and exists (
            select 1
            from gtt_num_id
            where id = box.box_oid        
        )
        };
    } else {
        my $str;
        if ( $#cassetteList < $oraclemax ) {
            $str = join( ",", @cassetteList );
        } else {
            OracleUtil::insertDataArray( $dbh, "gtt_num_id2", \@cassetteList );
            $str = " select id from gtt_num_id2 ";
        }

        $sql = qq{
        select gc.cassette_oid, gc.gene, gcg.cog as func, box.box_oid
        from cassette_box_cassettes_cog box,
        gene_cassette_genes gc,
        gene_cog_groups gcg
        where box.taxon = ?
        and box.cassettes = gc.cassette_oid
        and box.cassettes in ($str)
        and gc.gene       = gcg.gene_oid
        and exists (
            select 1
            from gtt_num_id
            where id = box.box_oid        
        )
        };
    }

    # cassette id, box id => hash gene oids
    my %hash;

    my $cur = execSql( $dbh, $sql, $verbose, $query_taxon_oid );

    #my $last_coid = "";
    my $count  = 0;
    my $dotcnt = 0;
    print "Looking for gene cassette details<br/>";
    for ( ; ; ) {
        my ( $coid, $goid, $cluster, $box_oid ) = $cur->fetchrow();
        last if !$coid;
        next if ( !exists $cassette_href->{$coid} );

        $count++;
        if ( $count % 1000 == 0 ) {
            $dotcnt++;
            print "..";
            if ( $dotcnt > 10 ) {
                print "<br/>Found $count records...still searching ...\n";
                $dotcnt = 0;
            }
        }

        my $box_href = $cassette_href->{$coid};
        if ( !exists( $box_href->{$box_oid} ) ) {
            next;
        }

        my $cluster_href = $boxCluster_href->{$box_oid};
        if ( !exists( $cluster_href->{$cluster} ) ) {
            next;
        }

        # reject cluster if in NOT IN list
        if ( exists $notinCluster{$cluster} ) {

            #$rejectedCluster{$cluster} = "";
            next;
        }

        my $key = "$coid,$box_oid";
        if ( exists $hash{$key} ) {
            my $href = $hash{$key};
            $href->{$goid} = "";
        } else {
            my %htmp;
            $htmp{$goid} = "";
            $hash{$key}  = \%htmp;
        }

    }
    $cur->finish();
    print "<br/> Found total of $count records<br/>\n";

    my $tmps = -1;    #keys %commonCluster;
    my $tmpr = -1;    # keys %rejectedCluster;

    #addMessage("$tmpr protein rejected in query genome cassettes");

    return ( \%hash, $tmpr, $tmps );
}

# gets box to cluster
#
# param
#   dbh
#   array of box ids
#   cluster type
# return
# hash of box id => hash set of cluster ids
sub getBoxCluster {
    my ( $dbh, $boxes_aref, $type, $query_taxon_oid ) = @_;

    my $sql;
    if ( $type eq "bbh" ) {
        $sql = qq{
        select b1.box_oid, b1.bbh_cluster
        from cassette_box_bbh_xlogs b1, cassette_box_cassettes_bbh b2
        where b2.taxon = ?
        and b1.box_oid = b2.box_oid
        and exists (            
            select 1
            from gtt_num_id
            where id = b1.box_oid
        )
        };

    } elsif ( $type eq "pfam" ) {

        $sql = qq{
        select b1.box_oid, b1.pfam_cluster
        from cassette_box_pfam_xlogs b1, cassette_box_cassettes_pfam b2
        where b2.taxon = ?
        and b1.box_oid = b2.box_oid
        and exists (            
            select 1
            from gtt_num_id
            where id = b1.box_oid
        )
        };
    } else {
        $sql = qq{
        select b1.box_oid, b1.cog_cluster
        from cassette_box_cog_xlogs b1, cassette_box_cassettes_cog b2
        where b2.taxon = ?
        and b1.box_oid = b2.box_oid
        and exists (            
            select 1
            from gtt_num_id
            where id = b1.box_oid
        )
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose, $query_taxon_oid );

    # hash of box id => hash set of cluster ids
    my %boxHash;

    #my %distinct;
    my $count  = 0;
    my $dotcnt = 0;

    for ( ; ; ) {
        my ( $bid, $clusid ) = $cur->fetchrow();
        last if !$bid;

        $count++;
        if ( $count % 10 == 0 ) {
            $dotcnt++;
            print "..";
            if ( $dotcnt >= 80 ) {
                print "<br/>Found $count matching records...still searching.\n";
                $dotcnt = 0;
            }
        }

        if ( exists $boxHash{$bid} ) {
            my $href = $boxHash{$bid};
            $href->{$clusid} = "";
        } else {
            my %hash;
            $hash{$clusid} = "";
            $boxHash{$bid} = \%hash;
        }

        #$distinct{$clusid} = "";
    }
    $cur->finish();
    print "<br/>Found a total of $count matching records.<br/>\n";

    #my $cluster_count = keys %distinct;

    webLog("Done getBoxCluster\n");

    #addMessage("$cluster_count box protein clusters.");

    return \%boxHash;
}

#
# prints form page javascript
#
sub printJavaScript2 {

    #my $oraclemax = WebUtil::getORACLEMAX();
    my $oraclemax = $FASTBIT_LIMIT;    # fastbit limitation max 5 genome selection

    my $obj = 1;                       #  for cog radio button

    if ($include_cassette_pfam) {
        $obj++;
    }

    if ($include_cassette_bbh) {
        $obj++;
    }

    print <<EOF;
    
    <script language='JavaScript' type='text/javascript'>

// document element start location of Find radio button
var findButton = $obj;
// document element start location of Collocated radio button
var collButton = findButton + 1;
var notCollButton = findButton + 2;

// max number a user can select
var maxFind = 1;
var maxColl = $oraclemax;
EOF

    if ($ENABLE_NOT_IN) {
        print qq{
// number of radio button cols
var numOfCols = 4;
        };
    } else {
        print qq{
// number of radio button cols
var numOfCols = 3;
        };
    }

    print <<EOF;
/*
 * When user selects a radio button highlight in blue, 'a parent taxon' not a
 * child / leaf taxon param begin item number offest by findButton param end last
 * radio button param offset which column param type which column type
 */
function selectGroupProfile(begin, end, offset, type) {
    var f = document.mainForm;
    var count = 0;
    var idx1 = begin * numOfCols;
    var idx2 = end * numOfCols;
    for ( var i = idx1; i < f.length && i < idx2; i++) {
        var e = f.elements[i + findButton];
        if (e.type == "radio" && i % numOfCols == offset) {
            e.checked = true;
        }
    }

    /*
     * now count the number of leafs selected max is 10
     */
    if (type == 'find' && !checkFindCount(null)) {
        selectGroupProfile(begin, end, (numOfCols - 1), 'ignore');
    } else if (type == 'collocated' && !checkCollCount(null)) {
        selectGroupProfile(begin, end, (numOfCols - 1), 'ignore');
    } else if (type == 'notCollocated' && !checkNotCollCount(null)) {
        selectGroupProfile(begin, end, (numOfCols - 1), 'ignore');
    }   
}

/*
 */
function checkFindCount(obj) {
    var f = document.mainForm;
    var count = 0;

    // I KNOW where the objects are located in the form
    for ( var i = findButton; i < f.length; i = i + numOfCols) {
        var e = f.elements[i];
        var name = e.name;
        if (e.type == "radio" && e.checked == true
                && name.indexOf("profile") > -1) {
            // alert("radio button is checked " + name);
            count++;
            if (count > maxFind) {
                alert("Please select only " + maxFind + " genome");
                if (obj != null) {
                    // i know which taxon leaf to un-check
                    obj[0].checked = false;
                    obj[numOfCols - 1].checked = true;
                }
                return false;
            }
        }
    }
    return true;
}

/*
 * 
 */
function checkCollCount(obj) {
    var f = document.mainForm;
    var count = 0;

    // I KNOW where the objects are located in the form
    for ( var i = collButton; i < f.length; i = i + numOfCols) {
        var e = f.elements[i];
        var name = e.name;
        if (e.type == "radio" && e.checked == true
                && name.indexOf("profile") > -1) {
            // alert("radio button is checked " + name);
            count++;
            if (count > maxColl) {
                alert("Please select " + maxColl + " or less genomes");
                if (obj != null) {
                    obj[1].checked = false;
                    obj[numOfCols - 1].checked = true;
                }
                return false;
            }
        }
    }
    return true;
}

function checkNotCollCount(obj) {
    var f = document.mainForm;
    var count = 0;

    // I KNOW where the objects are located in the form
    for ( var i = notCollButton; i < f.length; i = i + numOfCols) {
        var e = f.elements[i];
        var name = e.name;
        if (e.type == "radio" && e.checked == true
                && name.indexOf("profile") > -1) {
            // alert("radio button is checked " + name);
            count++;
            if (count > maxColl) {
                alert("Please select " + maxColl + " or less genomes");
                if (obj != null) {
                    obj[3].checked = false;
                    obj[numOfCols - 1].checked = true;
                }
                return false;
            }
        }
    }
    return true;
}

    
    </script>
    
EOF

}

1;
