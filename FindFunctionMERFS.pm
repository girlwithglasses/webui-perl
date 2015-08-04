#
#
# $Id: FindFunctionMERFS.pm 30511 2014-03-30 18:24:38Z jinghuahuang $
#
package FindFunctionMERFS;

use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use HtmlUtil;
use OracleUtil;
use InnerTable;
use MetaUtil;
use MerFsUtil;

my $section              = "FindFunctionMERFS";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $base_url             = $env->{base_url};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $img_internal         = $env->{img_internal};
my $show_private         = $env->{show_private};
my $tmp_dir              = $env->{tmp_dir};
my $web_data_dir         = $env->{web_data_dir};
my $taxon_faa_dir        = "$web_data_dir/taxon.faa";
my $swiss_prot_base_url  = $env->{swiss_prot_base_url};
my $user_restricted_site = $env->{user_restricted_site};
my $preferences_url      = "$main_cgi?section=MyIMG&page=preferences";
my $include_metagenomes  = $env->{include_metagenomes};
my $include_img_terms    = $env->{include_img_terms};
my $go_base_url          = $env->{go_base_url};
my $cog_base_url         = $env->{cog_base_url};
my $kog_base_url         = $env->{kog_base_url};
my $pfam_base_url        = $env->{pfam_base_url};
my $pfam_clan_base_url   = $env->{pfam_clan_base_url};
my $enzyme_base_url      = $env->{enzyme_base_url};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};

my $mer_data_dir = $env->{mer_data_dir};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

$| = 1;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    if ( $page eq 'geneDisplayNameGenes' ) {
        printGeneDisplayNameGenes();
    } elsif ( $page eq 'geneDisplayNameGenomes' ) {
        printGeneDisplayNameGenomes();
    } elsif ( $page eq 'ffgFindFunctionsGeneList' ) {
        printffgFindFunctionsGeneList();
    } elsif ( $page eq 'ffgFindFunctionsGenomeList' ) {
        printffgFindFunctionsGenomeList();
    } elsif ( $page eq 'findGene' ) {

        # from find gene tool
        printFindGene();
    } elsif ( $page eq 'domainList' ) {

        # from find genes pfam list
        printDomainList();
    }
}

sub printDomainList {
    my $searchFilter = param('searchFilter');
    my $searchTerm   = param('searchTerm');

    #my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my $mtaxon_oid      = param('mtaxon_oid');
    my $pfamIds_aref    = getSessionParam("pfamIds");
    my $notPfamIds_aref = getSessionParam("notPfamIds");

    print qq{
        <h1>Metagenome Search Results</h1>
        <p>
        $searchTerm
        </p>
    };

    my %pfamIds    = WebUtil::array2Hash(@$pfamIds_aref);
    my %notPfamIds = WebUtil::array2Hash(@$notPfamIds_aref);

    my %foundGenes;    # hash of hashes gene oid => 1
    my %genesName;
    printStartWorkingDiv();
    my $geneProductTxtFile = $mer_data_dir . '/' . $mtaxon_oid . '/assembled/pfam_genes.tbl';
    if ( -e $geneProductTxtFile ) {
        my @removeGenes;    # list of gene oids to be removed
        print "Check metagenome $mtaxon_oid ...<br/>\n";
        my $rfh = WebUtil::newReadFileHandle($geneProductTxtFile);
        while ( my $line = $rfh->getline() ) {
            chomp($line);
            my ( $pfamId, $geneOid ) = split( /\t/, $line );
            if ( exists $pfamIds{$pfamId} ) {
                $foundGenes{$geneOid} = 1;
            }
            if ( exists $notPfamIds{$pfamId} ) {
                push( @removeGenes, $geneOid );
            }
        }
        close $rfh;

        # remove not in genes
        foreach my $gid (@removeGenes) {
            if ( exists $foundGenes{$gid} ) {
                delete $foundGenes{$gid};
            }
        }
    }

    my $geneProductTxtFile = $mer_data_dir . '/' . $mtaxon_oid . '/assembled/gene_product.txt';
    if ( -e $geneProductTxtFile ) {
        print "Check metagenome $mtaxon_oid ...<br/>\n";
        my $rfh = WebUtil::newReadFileHandle($geneProductTxtFile);
        while ( my $line = $rfh->getline() ) {
            chomp($line);
            my ( $gene_oid, $product_name, $source ) = split( /\t/, $line );
            if (exists $foundGenes{$gene_oid}  ) {
                my $workspace_id = "$mtaxon_oid assembled $gene_oid";
                $foundGenes{$gene_oid}     = $workspace_id;
                $genesName{$gene_oid} = $product_name;
            }
        }
        close $rfh;
    }

    my $dbh         = dbLogin();
    my $taxons_href = getAllMetagenomeNames($dbh);
    #$dbh->disconnect();
    printEndWorkingDiv();

    printMainForm();
    my $count = printGeneList( \%foundGenes, $taxons_href, \%genesName );
    printStatusLine( "$count loaded", 2 );
    print end_form();    
}

#
# find gene tool - find gene product name results
#
sub printFindGene {
    my $searchFilter               = param('searchFilter');
    my $searchTermLc               = param('searchTermLc');
    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my $mtaxon_oid                 = param('mtaxon_oid');
    if ( $mtaxon_oid ne '' ) {
        my @a = ($mtaxon_oid);
        $genomeFilterSelections_ref = \@a;
    }

    print qq{
        <h1>Metagenome Search Results</h1>
        <p>
        $searchTermLc
        </p>
    };

    if ( $#$genomeFilterSelections_ref < 0 ) {
        webError("Please select at least one genome or one metagenome.");
    }

    printStartWorkingDiv();
    my @highlistterms;
    my %genes;
    my %genesName;
    if ( $searchFilter eq "gene_display_name_iex" ) {
        foreach my $toid (@$genomeFilterSelections_ref) {
            my $geneProductTxtFile = $mer_data_dir . '/' . $toid . '/assembled/gene_product.txt';
            if ( -e $geneProductTxtFile ) {
                print "Check metagenome $toid ...<br/>\n";
                my $rfh = WebUtil::newReadFileHandle($geneProductTxtFile);
                while ( my $line = $rfh->getline() ) {
                    chomp($line);
                    my ( $gene_oid, $product_name, $source ) = split( /\t/, $line );
                    $product_name = lc($product_name);
                    if ( $product_name =~ /$searchTermLc/i ) {
                        my $workspace_id = "$toid assembled $gene_oid";
                        $genes{$gene_oid}     = $workspace_id;
                        $genesName{$gene_oid} = $product_name;
                        push( @highlistterms, $searchTermLc );
                    }
                }
                close $rfh;
            }
        }
    } elsif ( ( $searchFilter eq 'locus_tag_merfs' || $searchFilter eq 'gene_oid_merfs' ) ) {
        my @term_list = WebUtil::splitTerm( $searchTermLc, 0, 0 );

        foreach my $toid (@$genomeFilterSelections_ref) {
            my $geneProductTxtFile = $mer_data_dir . '/' . $toid . '/assembled/gene_product.txt';
            if ( -e $geneProductTxtFile ) {
                print "Check metagenome $toid ...<br/>\n";
                my $rfh = WebUtil::newReadFileHandle($geneProductTxtFile);
                while ( my $line = $rfh->getline() ) {
                    chomp($line);
                    my ( $gene_oid, $product_name, $source ) = split( /\t/, $line );
                    my $tmp_gene_oid = lc($gene_oid);
                    foreach my $t (@term_list) {
                        if ( $tmp_gene_oid =~ /$t/i ) {
                            my $workspace_id = "$toid assembled $gene_oid";
                            $genes{$gene_oid}     = $workspace_id;
                            $genesName{$gene_oid} = $product_name;
                            push( @highlistterms, $t );
                        }
                    }
                }
                close $rfh;
            }
        }
    }

    my $dbh         = dbLogin();
    my $taxons_href = getAllMetagenomeNames($dbh);
    #$dbh->disconnect();
    printEndWorkingDiv();

    printMainForm();
    my $count = printGeneList( \%genes, $taxons_href, \%genesName, \@highlistterms );
    printStatusLine( "$count loaded", 2 );
    print end_form();
}

#
# find function cog pfam etc metagenome gene list
#
sub printffgFindFunctionsGeneList {
    my $funnctionId                = param('id');
    my $searchFilter               = param('searchFilter');                       # cog, pfam etc
    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");

    if ( $#$genomeFilterSelections_ref < 0 ) {
        webError("Please select at least one genome or one metagenome.");
    }

    my $filename;
    my $sql;
    if ( $searchFilter eq "cog" ) {
        $filename = 'cog_genes.tbl';
        $sql      = qq{
            select cog_id, cog_name
            from cog
            where cog_id = ?
        };
    } elsif ( $searchFilter eq "pfam" ) {
        $filename = 'pfam_genes.tbl';
        $sql      = qq{
            select ext_accession, name ||' - '|| description
            from pfam_family
            where ext_accession = ?
        };
    } elsif ( $searchFilter eq "tigrfam" ) {
        $filename = 'tigr_genes.tbl';
        $sql      = qq{
            select ext_accession, abbr_name ||' - '|| expanded_name
            from tigrfam
            where ext_accession = ?
        };
    } elsif ( $searchFilter eq "ec" 
    || $searchFilter eq "ec_ex" 
    || $searchFilter eq "ec_iex") {
        $filename = 'ec_genes.tbl';
        $sql      = qq{
            select ec_number, enzyme_name 
            from enzyme
            where ec_number = ?
        };
    } else {
        return;
    }

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );
    my $cur = execSql( $dbh, $sql, $verbose, $funnctionId );
    my ( $id, $functionName ) = $cur->fetchrow();
    print qq{
        <h1>
        Genes in $funnctionId $functionName 
        </h1>
    };

    printStartWorkingDiv();

    my %taxon_in_file = MerFsUtil::getTaxonsInFile($dbh);
    my %genes;
    foreach my $toid (@$genomeFilterSelections_ref) {
        next if ( !exists $taxon_in_file{$toid} );
        my $searchFile = $mer_data_dir . '/' . $toid . '/assembled/' . $filename;
        if ( -e $searchFile ) {
            print "Check metagenome $toid ...<br/>\n";
            my $rfh = WebUtil::newReadFileHandle($searchFile);
            while ( my $line = $rfh->getline() ) {
                chomp($line);
                my ( $funcId, $gene_oid ) = split( /\s+/, $line );
                if ( $funnctionId eq $funcId ) {
                    my $workspace_id = "$toid assembled $gene_oid";
                    $genes{$gene_oid} = $workspace_id;
                }
            }
            close $rfh;
        }
    }

    my $taxons_href = getAllMetagenomeNames($dbh);

    #$dbh->disconnect();
    printEndWorkingDiv();

    printMainForm();
    my $count = printGeneList( \%genes, $taxons_href );
    printStatusLine( "$count loaded", 2 );
    print end_form();
}

sub getFindFunctionsGeneList {
    my ( $dbh, $funnctionId, $searchFilter, $genomeFilterSelections_ref ) = @_;
    
    my @genes;

    if ( scalar(@$genomeFilterSelections_ref) <= 0 ) {
        return @genes;
    }

    my $filename;
    if ( $searchFilter eq "cog" ) {
        $filename = 'cog_genes.tbl';
    } elsif ( $searchFilter eq "pfam" ) {
        $filename = 'pfam_genes.tbl';
    } elsif ( $searchFilter eq "tigrfam" ) {
        $filename = 'tigr_genes.tbl';
    } elsif ( $searchFilter eq "ec" 
    || $searchFilter eq "ec_ex" 
    || $searchFilter eq "ec_iex") {
        $filename = 'ec_genes.tbl';
    } else {
        return @genes;
    }

    printStartWorkingDiv();

    #already validated
    #my %taxon_in_file = MerFsUtil::getTaxonsInFile($dbh);
    foreach my $toid (@$genomeFilterSelections_ref) {
        #next if ( !exists $taxon_in_file{$toid} );
        my $searchFile = $mer_data_dir . '/' . $toid . '/assembled/' . $filename;
        if ( -e $searchFile ) {
            print "Check metagenome $toid ...<br/>\n";
            my $rfh = WebUtil::newReadFileHandle($searchFile);
            while ( my $line = $rfh->getline() ) {
                chomp($line);
                my ( $funcId, $gene_oid ) = split( /\s+/, $line );
                if ( uc($funnctionId) eq uc($funcId) ) {
                    my $workspace_id = "$toid assembled $gene_oid";
                    push(@genes, $workspace_id);
                }
            }
            close $rfh;
        }
    }

    printEndWorkingDiv();

    return (@genes);

}

#
# find function cog pfam etc metagenome list
#
sub printffgFindFunctionsGenomeList {
    my $funnctionId                = param('id');
    my $searchFilter               = param('searchFilter');                       # cog, pfam etc
    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");

    if ( $#$genomeFilterSelections_ref < 0 ) {
        webError("Please select at least one genome or one metagenome.");
    }

    my $funnctionId  = param('id');
    my $searchFilter = param('searchFilter');                                     # cog, pfam etc

    my $filename;
    my $sql;
    if ( $searchFilter eq "cog" ) {
        $filename = 'cog_genes.tbl';
        $sql      = qq{
            select cog_id, cog_name
            from cog
            where cog_id = ?
        };
    } elsif ( $searchFilter eq "pfam" ) {
        $filename = 'pfam_genes.tbl';
        $sql      = qq{
            select ext_accession, name ||' - '|| description
            from pfam_family
            where ext_accession = ?
        };
    } elsif ( $searchFilter eq "tigrfam" ) {
        $filename = 'tigr_genes.tbl';
        $sql      = qq{
            select ext_accession, abbr_name ||' - '|| expanded_name
            from tigrfam
            where ext_accession = ?
        };
    } elsif ( $searchFilter eq "ec" 
    || $searchFilter eq "ec_ex" 
    || $searchFilter eq "ec_iex") {
        $filename = 'ec_genes.tbl';
        $sql      = qq{
            select ec_number, enzyme_name 
            from enzyme
            where ec_number = ?
        };
    } else {
        return;
    }

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );
    #my $cur = execSql( $dbh, $sql, $verbose, $funnctionId );
    #my ( $id, $functionName ) = $cur->fetchrow();

    printStartWorkingDiv();
    my @foundTaxons;
    foreach my $toid (@$genomeFilterSelections_ref) {
        my $searchFile = $mer_data_dir . '/' . $toid . '/assembled/' . $filename;
        if ( -e $searchFile ) {
            print "Check metagenome $toid ...<br/>\n";
            my $rfh = WebUtil::newReadFileHandle($searchFile);
            while ( my $line = $rfh->getline() ) {
                chomp($line);
                my ( $funcId, $gene_oid ) = split( /\s+/, $line );
                if ( $funnctionId eq $funcId ) {
                    push( @foundTaxons, $toid );
                    last;
                }
            }
            close $rfh;
        }
    }
    printEndWorkingDiv();

    my $title = "Genomes In $funnctionId";
    HtmlUtil::printGenomeListHtmlTable( $title, $funnctionId, $dbh, \@foundTaxons );
    #$dbh->disconnect();
}

sub getFindFunctionsGenomeList {
    my ( $funnctionId, $searchFilter, $genomeFilterSelections_ref ) = @_;
    
    my @foundTaxons;

    if ( scalar(@$genomeFilterSelections_ref) <= 0 ) {
        return @foundTaxons;
    }

    my $filename;
    if ( $searchFilter eq "cog" ) {
        $filename = 'cog_genes.tbl';
    } elsif ( $searchFilter eq "pfam" ) {
        $filename = 'pfam_genes.tbl';
    } elsif ( $searchFilter eq "tigrfam" ) {
        $filename = 'tigr_genes.tbl';
    } elsif ( $searchFilter eq "ec" 
    || $searchFilter eq "ec_ex" 
    || $searchFilter eq "ec_iex") {
        $filename = 'ec_genes.tbl';
    } else {
        return @foundTaxons;
    }

    printStartWorkingDiv();

    foreach my $toid (@$genomeFilterSelections_ref) {
        my $searchFile = $mer_data_dir . '/' . $toid . '/assembled/' . $filename;
        if ( -e $searchFile ) {
            print "Check metagenome $toid ...<br/>\n";
            my $rfh = WebUtil::newReadFileHandle($searchFile);
            while ( my $line = $rfh->getline() ) {
                chomp($line);
                my ( $funcId, $gene_oid ) = split( /\s+/, $line );
                if ( uc($funnctionId) eq uc($funcId) ) {
                    push( @foundTaxons, $toid );
                    last;
                }
            }
            close $rfh;
        }
    }

    printEndWorkingDiv();

    return (@foundTaxons);
}

#
# gene product name gene list
#

sub printGeneDisplayNameGenes {
    my $gene_display_name = param('gene_display_name');
    $gene_display_name = lc($gene_display_name);
    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");

    print qq{
        <h1>Genes In Gene Product Name </h1>
    };

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();
    my $dbh           = dbLogin();
    my %taxon_in_file = MerFsUtil::getTaxonsInFile($dbh);
    my %genes;
    foreach my $toid (@$genomeFilterSelections_ref) {
        next if ( !exists $taxon_in_file{$toid} );
        my $geneProductTxtFile = $mer_data_dir . '/' . $toid . '/assembled/gene_product.txt';
        if ( -e $geneProductTxtFile ) {
            print "Check metagenome $toid ...<br/>\n";
            my $rfh = WebUtil::newReadFileHandle($geneProductTxtFile);
            while ( my $line = $rfh->getline() ) {
                chomp($line);
                my ( $gene_oid, $product_name, $source ) = split( /\t/, $line );
                $product_name = lc($product_name);
                if ( $product_name eq $gene_display_name ) {

                    # TODO
                    my $workspace_id = "$toid assembled $gene_oid";
                    $genes{$gene_oid} = $workspace_id;
                }
            }
            close $rfh;
        }
    }

    my $taxons_href = getAllMetagenomeNames($dbh);

    #$dbh->disconnect();
    printEndWorkingDiv();

    printMainForm();
    my $count = printGeneList( \%genes, $taxons_href );
    printStatusLine( "$count loaded", 2 );
    print end_form();
}

sub getGeneDisplayNameGenes {
    my ( $dbh, $gene_display_name, $genomeFilterSelections_ref ) = @_;
    $gene_display_name = lc($gene_display_name);

    my @genes;

    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    if ( scalar(@$genomeFilterSelections_ref) <= 0 ) {
        return @genes;
    }

    #already validated
    #my %taxon_in_file = MerFsUtil::getTaxonsInFile($dbh);
    foreach my $toid (@$genomeFilterSelections_ref) {
        #next if ( !exists $taxon_in_file{$toid} );
        my $geneProductTxtFile = $mer_data_dir . '/' . $toid . '/assembled/gene_product.txt';
        if ( -e $geneProductTxtFile ) {
            print "Check metagenome $toid ...<br/>\n";
            my $rfh = WebUtil::newReadFileHandle($geneProductTxtFile);
            while ( my $line = $rfh->getline() ) {
                chomp($line);
                my ( $gene_oid, $product_name, $source ) = split( /\t/, $line );
                $product_name = lc($product_name);
                if ( $product_name eq $gene_display_name ) {
                    my $workspace_id = "$toid assembled $gene_oid";
                    push(@genes, $workspace_id);
                }
            }
            close $rfh;
        }
    }

    return (@genes);

}

#
# gets all metagenome names
#
sub getAllMetagenomeNames {
    my ($dbh) = @_;

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select tx.taxon_oid, tx.taxon_display_name
        from taxon tx
        where tx.genome_type = 'metagenome'
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my %taxons;
    for ( ; ; ) {
        my ( $taxon_oid, $name ) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxons{$taxon_oid} = $name;
    }

    return \%taxons;
}

#
# gene product name genome list
#
sub printGeneDisplayNameGenomes {
    my $gene_display_name          = param('gene_display_name');
    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();
    my @foundTaxons;
    foreach my $toid (@$genomeFilterSelections_ref) {
        my $geneProductTxtFile = $mer_data_dir . '/' . $toid . '/assembled/gene_product.txt';
        if ( -e $geneProductTxtFile ) {
            print "Check metagenome $toid ...<br/>\n";
            my $rfh = WebUtil::newReadFileHandle($geneProductTxtFile);
            while ( my $line = $rfh->getline() ) {
                chomp($line);
                my ( $gene_oid, $product_name, $source ) = split( /\t/, $line );
                $product_name = lc($product_name);
                if ( $product_name eq $gene_display_name ) {

                    # TODO
                    #my $workspace_id = "$toid assembled $gene_oid";
                    #$genes{$gene_oid} = $workspace_id;
                    push( @foundTaxons, $toid );
                    last;
                }
            }
            close $rfh;
        }
    }
    printEndWorkingDiv();
    my $dbh   = dbLogin();
    my $title = "Genomes In Gene Product Name";
    HtmlUtil::printGenomeListHtmlTable( $title, "$gene_display_name", $dbh, \@foundTaxons );
    #$dbh->disconnect();

    #printStatusLine( "Loading ...", 2 );
}

sub getGeneDisplayNameGenomes {
    my ( $gene_display_name, $genomeFilterSelections_ref ) = @_;
    $gene_display_name = lc($gene_display_name);

    my @foundTaxons;

    if ( scalar(@$genomeFilterSelections_ref) <= 0 ) {
        return @foundTaxons;
    }

    printStartWorkingDiv();

    my @foundTaxons;
    foreach my $toid (@$genomeFilterSelections_ref) {
        my $geneProductTxtFile = $mer_data_dir . '/' . $toid . '/assembled/gene_product.txt';
        if ( -e $geneProductTxtFile ) {
            print "Check metagenome $toid ...<br/>\n";
            my $rfh = WebUtil::newReadFileHandle($geneProductTxtFile);
            while ( my $line = $rfh->getline() ) {
                chomp($line);
                my ( $gene_oid, $product_name, $source ) = split( /\t/, $line );
                $product_name = lc($product_name);
                if ( $product_name eq $gene_display_name ) {
                    push( @foundTaxons, $toid );
                    last;
                }
            }
            close $rfh;
        }
    }
    printEndWorkingDiv();

    return (@foundTaxons);
}

#
# print FS metagenomes' gene list
#
# $genelist_href: gene_oid => workspace_id a space delimited values of: taxon_oid type gene_oid
#   where type is: assembled or unassembled
# $taxon_names_href: taxon_oid => taxon name
# $genesName_href:
# $highlightterms_aref: search terms to highlight green <font color="green"> <b> term </b> </font>
#
sub printGeneList {
    my ( $genelist_href, $taxon_names_href, $genesName_href, $highlightterms_aref ) = @_;

    my $maxGeneListResults = 1000;
    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my $gene_count     = 0;
    my $show_gene_name = 1;
    my $trunc          = 0;
    require InnerTable;
    my $it = new InnerTable( 1, "printGeneList$$", "printGeneList", 1 );
    my $sd = $it->getSdDelim();

    my @gene_oids = ( keys %$genelist_href );
    if ( scalar(@gene_oids) > 100 ) {
        $show_gene_name = 0;
    }

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID", "char asc", "left" );
    if ( $show_gene_name || $genesName_href ne '' ) {
        $it->addColSpec( "Gene Product Name", "char asc", "left" );
    }
    $it->addColSpec( "Genome Name", "char asc", "left" );

    my $select_id_name = "gene_oid";

    my $count = 0;
    for my $key (@gene_oids) {
        my $workspace_id = $genelist_href->{$key};
        my ( $tid, $dt, $id2 ) = split( / /, $workspace_id );

        my $row = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";

        my $text = isMatch( $key, $highlightterms_aref );
        $row .=
            $workspace_id . $sd
          . "<a href='main.cgi?section=MetaGeneDetail"
          . "&page=metaGeneDetail&taxon_oid=$tid"
          . "&data_type=$dt&gene_oid=$key'> $text </a>\t";

        if ($show_gene_name) {
            my ( $value, $source ) = MetaUtil::getGeneProdNameSource( $key, $tid, $dt );
            my $text = isMatch( $value, $highlightterms_aref );
            $row .= $value . $sd . $text . "\t";
        } elsif ( exists $genesName_href->{$key} ) {
            my $value = $genesName_href->{$key};
            my $text = isMatch( $value, $highlightterms_aref );
            $row .= $value . $sd . $text . "\t";
        }

        my $taxon_name = $taxon_names_href->{$tid};
        $row .=
          $taxon_name . $sd . "<a href='main.cgi?section=MetaDetail" . "&page=metaDetail&taxon_oid=$tid'>$taxon_name</a>\t";

        $it->addRow($row);
        $gene_count++;

        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        $count++;
    }

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    return $count;
}

#
# search term found, if yes highlight
#
sub isMatch {
    my ( $text, $terms_aref ) = @_;
    return $text if $terms_aref eq '';

    foreach my $x (@$terms_aref) {
        if ( $text =~ /$x/i ) {
            my $h = "<font color='green'><b>$x</b></font>";
            $text =~ s/$x/$h/i;
            return $text;
        }
    }
    return $text;
}

#
# Find function cog, pfam tigrfam continuing code for mer fs
# $filename
#   - cog_genes.tbl - COG0001   ARcpr5yngRDRAFT_0453111
#
sub getFindFunction {
    my ( $dbh, $searchFilter, $genomeFilterSelections_aref, $searchTermLc ) = @_;

    my $filename;
    my $sql;
    if ( $searchFilter eq "cog" ) {
        $filename = 'cog_genes.tbl';
        $sql      = qq{
            select cog_id, cog_name
            from cog
        };
    } elsif ( $searchFilter eq "pfam" ) {
        $filename = 'pfam_genes.tbl';
        $sql      = qq{
            select ext_accession, name ||' - '|| description
            from pfam_family
        };
    } elsif ( $searchFilter eq "tigrfam" ) {
        $filename = 'tigr_genes.tbl';
        $sql      = qq{
            select ext_accession, abbr_name ||' - '|| expanded_name
            from tigrfam
        };
    } elsif ( $searchFilter eq "ec" 
    || $searchFilter eq "ec_ex" 
    || $searchFilter eq "ec_iex") {
        $filename = 'ec_genes.tbl';
        $sql      = qq{
            select ec_number, enzyme_name 
            from enzyme
        };
    } else {
        return;
    }

    # get all function names
    my %functionNames;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name, ) = $cur->fetchrow();
        last if ( !$id );
        $functionNames{$id} = $name;
    }

    # get all the terms if a list of terms
    my @terms = WebUtil::splitTerm( $searchTermLc, 0, 0 );
    my %terms_hash;
    foreach my $x (@terms) {
        $terms_hash{ uc($x) } = 1;
    }

    printStartWorkingDiv();

    my %merfs_genecnt;
    my %merfs_genomecnt;
    print "Check FS...<br/>\n";
    #already validated
    #my %taxon_in_file = MerFsUtil::getTaxonsInFile($dbh);
    foreach my $toid (@$genomeFilterSelections_aref) {
        my $cnt = 0;
        #already validated
        #next if ( !exists $taxon_in_file{$toid} );
        my $searchFile = $mer_data_dir . '/' . $toid . '/assembled/' . $filename;
        if ( -e $searchFile ) {
            print "Check metagenome $toid ...<br/>\n";
            my $rfh = WebUtil::newReadFileHandle($searchFile);
            while ( my $line = $rfh->getline() ) {
                chomp($line);
                my ( $func_id, $gene_oid ) = split( /\t/, $line );
                if ( exists $terms_hash{ uc($func_id) } ) {
                    #print "FindFunctionMERFS::getFindFunction() $toid $func_id $gene_oid<br/>\n";
                    $merfs_genecnt{$func_id} = $merfs_genecnt{$func_id} + 1;
                    if ( !exists $merfs_genomecnt{$func_id} ) {
                        $merfs_genomecnt{$func_id} = 1;
                        #print "FindFunctionMERFS::getFindFunction() $toid $func_id merfs_genomecnt: 1 <br/>\n";
                        $cnt = 1;
                    } elsif ( $cnt == 0 ) {
                        $merfs_genomecnt{$func_id} = $merfs_genomecnt{$func_id} + 1;
                        #print "FindFunctionMERFS::getFindFunction() $toid $func_id merfs_genomecnt: $merfs_genomecnt{$func_id} <br/>\n";
                        $cnt = 1;
                    }
                }
            }
            close $rfh;
        }
    }
    
    printEndWorkingDiv();
    
    return ( \%merfs_genecnt, \%merfs_genomecnt, \%functionNames );
}

1;
