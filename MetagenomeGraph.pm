############################################################################
#
# $Id: MetagenomeGraph.pm 33981 2015-08-13 01:12:00Z aireland $
#
# package to draw 2 recur plots and scatter plot
#
############################################################################
package MetagenomeGraph;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;

use CGI qw( :standard );
use DBI;
use MetagGraphPanel;
use ScaffoldPanel;
use Data::Dumper;
use WebConfig;
use WebUtil;
use POSIX qw(ceil floor);
use LWP::UserAgent;
use HTTP::Request::Common qw( GET POST );
use MetagJavaScript;
use HtmlUtil;
use OracleUtil;
use MetaUtil;
use QueryUtil;
use PhyloUtil;
use GraphUtil;

my $section              = "MetagenomeGraph";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $tmp_url              = $env->{tmp_url};
my $tmp_dir              = $env->{tmp_dir};
my $verbose              = $env->{verbose};
my $web_data_dir         = $env->{web_data_dir};
my $base_url             = $env->{base_url};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $user_restricted_site = $env->{user_restricted_site};
my $YUI                  = $env->{yui_dir_28};
my $yui_tables           = $env->{yui_tables};
my $img_ken               = $env->{img_ken};

my $unknown = "Unknown";

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    my $dbh  = dbLogin();

    my $sid       = getContactOid();
    my $taxon_oid = param("taxon_oid");
    timeout( 60 * 40 );    # timeout in 40 mins (from main.pl)

#    if ( $user_restricted_site && HtmlUtil::isCgiCacheEnable() ) {
#        my $x = WebUtil::isTaxonPublic( $dbh, $taxon_oid );
#        $sid = 0 if ($x);    # public cache
#    }
    HtmlUtil::cgiCacheInitialize( $section);
    HtmlUtil::cgiCacheStart() or return;

    if ( $page eq "fragRecView1" ) {
        GraphUtil::printFragment($dbh, $section);
    } elsif ( $page eq "fragRecView2" ) {

        # future button
        GraphUtil::printProtein($dbh, $section);
    } elsif ( $page eq "fragRecView3" ) {

        # can be 'all', 'pos' or 'neg'
        my $strand = param("strand");
        printScatter( $dbh, $strand );
    } elsif ( $page eq "binscatter" ) {
        GraphUtil::printBinScatterPlot($dbh, $section);
    } elsif ( $page eq "binfragRecView1" ) {
        GraphUtil::printBinFragment($dbh, $section);
    } elsif ( $page eq "binfragRecView2" ) {
        GraphUtil::printBinProtein($dbh, $section);
    } else {
        my $family = param("family");
        print "family $family\n";
    }

    #$dbh->disconnect();
    HtmlUtil::cgiCacheStop();
}

sub getPhylumGeneFilePercentInfo {
    my ( $dbh, $taxon_oid,
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $recs_aref,
        $homolog_start_coord_min, $homolog_end_coord_max,
        $gene_oids_href, $homolog_gene_oids_href, $gene2homolog_hits_href
        )
      = @_;

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my @gene_oids = keys(%$gene_oids_href);
    my $str = OracleUtil::getNumberIdsInClause( $dbh, @gene_oids );

    my $sql = qq{
        select g.gene_oid, t.taxon_oid, t.taxon_display_name,
            g.scaffold, s.scaffold_name,
            g.start_coord, g.end_coord, g.strand, g.product_name
        from taxon t, gene g, scaffold s
        where t.taxon_oid = ?
        and t.taxon_oid = g.taxon
        and g.gene_oid in ($str)
        and g.scaffold = s.scaffold_oid
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my %geneInfo;
    for ( ; ; ) {
        my ( $gene_oid,    $taxon_oid, $taxon_name,   $scaffold,  $scaffold_name,
             $metag_start, $metag_end, $metag_strand, $product_name )
          = $cur->fetchrow();
        last if !$gene_oid;

        my $r = $taxon_oid . "\t";
        $r .= $taxon_name. "\t";
        $r .= $scaffold. "\t";
        $r .= $scaffold_name. "\t";
        $r .= $metag_start . "\t";
        $r .= $metag_end . "\t";
        $r .= $metag_strand . "\t";
        $r .= $product_name;
        $geneInfo{$gene_oid} = $r;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $str =~ /gtt_num_id/i );

    my @binds;

    my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2(
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push(@binds, @$binds_t_clause_ref) if ( $binds_t_clause_ref );

    my @homolog_gene_oids = keys(%$homolog_gene_oids_href);
    my $str = OracleUtil::getNumberIdsInClause( $dbh, @homolog_gene_oids );

    my $sql = qq{
        select g.gene_oid, s.scaffold_oid, s.scaffold_name,
            g.strand, g.start_coord, g.end_coord
        from gene g, taxon t, scaffold s
        where g.gene_oid in ($str)
        and g.taxon = t.taxon_oid
        and g.scaffold = s.scaffold_oid
        $taxonomyClause
        $rclause
        $imgClause
    };
    #print "getPhylumGeneFilePercentInfo() sql: $sql<br/>\n";
    #print "getPhylumGeneFilePercentInfo() binds: @binds<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my %homologGeneInfo;
    for ( ; ; ) {
        my ( $homolog_gene_oid,  $homolog_scaffold_oid,  $homolog_scaffold_name,
             $strand,            $start,                 $end )
          = $cur->fetchrow();
        last if !$homolog_gene_oid;

        my $r = $homolog_scaffold_oid. "\t";
        $r .= $homolog_scaffold_name. "\t";
        $r .= $strand . "\t";
        $r .= $start . "\t";
        $r .= $end;
        $homologGeneInfo{$homolog_gene_oid} = $r;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $str =~ /gtt_num_id/i );

    for my $key (keys %$gene2homolog_hits_href) {
        my $r = $gene2homolog_hits_href->{$key};
        my ( $workspace_id, $percent,  $homolog_gene2,
             $homo_family, $homo_genus, $homo_species,  $homo_taxon_name )
          = split( /\t/, $r );

        my ($gene_oid, $homolog_gene) = split(/ /, $key);

        my ( $taxon_oid, $taxon_name,   $scaffold,  $scaffold_name,
             $metag_start, $metag_end, $metag_strand, $product_name )
          = split( /\t/, $geneInfo{$gene_oid} );

        my $homologGeneInfo_r = $homologGeneInfo{$homolog_gene};
        my ( $homolog_scaffold_oid, $homolog_scaffold_name, $strand, $start, $end )
          = split( /\t/, $homologGeneInfo{$homolog_gene} );

        # doing this range selection here is faster than doing it in oracle
        if (    ( $start >= $homolog_start_coord_min && $start <= $homolog_end_coord_max )
             || ( $end >= $homolog_start_coord_min && $end <= $homolog_end_coord_max ) )
        {
            # do nothing
        } else {
            # skip
            next;
        }

        my @rec;

        # list is consistent with the array index global variables
        push( @rec,        $gene_oid );
        push( @rec,        $taxon_oid );
        push( @rec,        $percent );
        push( @rec,        $taxon_name );
        push( @rec,        $strand );
        push( @rec,        $start );
        push( @rec,        $end );
        push( @rec,        $scaffold );
        push( @rec,        $scaffold_name );
        push( @rec,        0 );
        push( @rec,        0 );
        push( @rec,        $homolog_gene );
        push( @rec,        '' );
        push( @rec,        $metag_start );
        push( @rec,        $metag_end );
        push( @rec,        $metag_strand );
        push( @rec,        $homolog_scaffold_name );
        push( @rec,        $product_name );
        push( @$recs_aref, \@rec );

    }
    $cur->finish();
}

sub getPhylumGeneFilePercentInfoMinMax {
    my ( $dbh, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $homolog_gene_oids_href ) = @_;

    my @binds;

    my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2(
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push(@binds, @$binds_t_clause_ref) if ( $binds_t_clause_ref );

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my @homolog_gene_oids = keys(%$homolog_gene_oids_href);
    my $str = OracleUtil::getNumberIdsInClause( $dbh, @homolog_gene_oids );

    my $sql = qq{
        select min( g.start_coord), max(g.end_coord)
        from gene g, taxon t
        where g.gene_oid in ($str)
            and g.taxon = t.taxon_oid
            $taxonomyClause
            $rclause
            $imgClause
    };
    #print "getPhylumGeneFilePercentInfoMinMax() sql: $sql<br/>\n";
    #print "getPhylumGeneFilePercentInfoMinMax() binds: @binds<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my ( $min, $max ) = $cur->fetchrow();

    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $str =~ /gtt_num_id/i );

    return ( $min, $max );
}

#
# creates scatter plot page
#
# param $dbh datbase handler
# param others see url
#
# $strand - all, pos or neg
#
# no longer used
#
sub printScatter {
    my ( $dbh, $strand ) = @_;

    # this is te query taxon id
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $rna16s    = param('rna16s');
    my $plus      = param("plus");

    my $domain    = param("domain");
    my $phylum    = param("phylum");
    my $ir_class  = param("ir_class");
    my $ir_order  = param("ir_order");
    my $family    = param("family");
    my $genus     = param("genus");
    my $species   = param("species");

    my $range     = param("range");
    my $merfsGenome = param("merfs");

# TODO genomes from a file
# family level rec. plot -mer ???
# https://img-stage.jgi-psf.org/cgi-bin/mer/main.cgi?section=MetaFileHits&page=family&xcopy=gene_count&taxon_oid=3300000294&data_type=assembled&domain=Bacteria&phylum=Bacteroidetes&ir_class=&perc=1&hist=1
# genus species level rec. plot - mer
# https://img-stage.jgi-psf.org/cgi-bin/mer/main.cgi?section=MetaFileHits&page=species&xcopy=gene_count&taxon_oid=3300000294&data_type=assembled&domain=Bacteria&phylum=Bacteroidetes&family=Bacteroidaceae
#
# oracle db metagenoe eg
# family
# https://img-stage.jgi-psf.org/cgi-bin/mer/main.cgi?section=MetagenomeHits&page=species&taxon_oid=2035918002&domain=Bacteria&phylum=Proteobacteria&ir_class=Betaproteobacteria&family=Comamonadaceae
# genus species
# https://img-stage.jgi-psf.org/cgi-bin/mer/main.cgi?section=MetagenomeHits&page=speciesForm&taxon_oid=2035918002&domain=Bacteria&phylum=Proteobacteria&ir_class=Betaproteobacteria&family=Comamonadaceae&genus=Polaromonas&species=naphthalenivorans
#

    print "<h1>Protein Recruitment Plot</h1>\n";
    PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    my $tname = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonNameWithDataType( $dbh, $taxon_oid, $tname, $data_type );

    my $limit = '';
    if(lc($data_type) eq 'both' || lc($data_type) eq 'unassembled') {
        $limit = 10000;
        print qq{
        Because of size limitation unassembled gene data will be truncated to $limit per file.
        };
    }



    my $colorExplain = "<p><font size=1>"
          . "<font color='red'>Red 90%</font><br>\n"
          . "<font color='green'>Green 60%</font><br>\n"
          . "<font color='blue'>Blue 30%</font><br>\n"
          . "</font></p>\n";

    printMainForm();
    printStatusLine("Loading ...");

    my @records;
    my $min1;
    my $max1;

    print $colorExplain;
    printStartWorkingDiv();

    if ( $merfsGenome ) {

        my %gene_oids_h;
        my %homolog_gene_oids_h;
        my %gene2homolog_hits;

        my @percent_list = ( 30, 60, 90 );
        for my $percent_identity (@percent_list) {
            my @workspace_ids_data;
            PhyloUtil::getFilePhyloGeneList(
                $taxon_oid, $data_type, $percent_identity, $plus,
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
                $rna16s, 0, $limit, \@workspace_ids_data ); # 10000

            for my $r (@workspace_ids_data) {
                my (
                    $workspace_id, $per_cent, $homolog_gene,
                    $homo_taxon, $copies, @rest
                  )
                  = split( /\t/, $r );

                my ($taxon4, $data_type4, $gene_oid2) = split(/ /, $workspace_id);
                $gene_oids_h{$gene_oid2} = 1;
                $homolog_gene_oids_h{$homolog_gene} = 1;

                my $gene2homolog = "$gene_oid2 $homolog_gene";
                $gene2homolog_hits{$gene2homolog} = $r;
            }

            if($limit) {
                my $size = $#workspace_ids_data;
                if($percent_identity == 30 && $size > $limit) {
                    next;
                } elsif($percent_identity == 60 && $size > $limit) {
                    next;
                } elsif($percent_identity == 90 && $size > $limit) {
                    next;
                }
            }

        }

        if ( $range eq "" ) {
            # gets min max of start and end coord of metag on ref genome
            ( $min1, $max1 ) = getPhylumGeneFilePercentInfoMinMax( $dbh,
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, \%homolog_gene_oids_h );
        } else {
            ( $min1, $max1 ) = split( /-/, $range );
        }
        #print "printScatter() min1: $min1; max1: $max1<br/>\n";

        getPhylumGeneFilePercentInfoMERFS( $dbh, $taxon_oid, $data_type,
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, \@records, $min1, $max1,
            \%gene_oids_h, \%homolog_gene_oids_h, \%gene2homolog_hits, $limit );

    }
    else {

        my $use_phylo_file = 0;
        my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid );
        if ( -e $phylo_dir_name ) {
            $use_phylo_file = 1;
        }

        if ( $use_phylo_file ) {
            my %gene_oids_h;
            my %homolog_gene_oids_h;
            my %gene2homolog_hits;

            my @percent_list = ( 30, 60, 90 );
            for my $percent_identity (@percent_list) {
                my @workspace_ids_data;
                PhyloUtil::getFilePhyloGeneList(
                    $taxon_oid, $data_type, $percent_identity, $plus,
                    $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
                    $rna16s, 0, '', \@workspace_ids_data );

                for my $r (@workspace_ids_data) {
                    my (
                        $workspace_id, $per_cent, $homolog_gene,
                        $homo_taxon, $copies, @rest
                      )
                      = split( /\t/, $r );

                    my ($taxon4, $data_type4, $gene_oid2) = split(/ /, $workspace_id);
                    $gene_oids_h{$gene_oid2} = 1;
                    $homolog_gene_oids_h{$homolog_gene} = 1;

                    my $gene2homolog = "$gene_oid2 $homolog_gene";
                    $gene2homolog_hits{$gene2homolog} = $r;
                }
            }

            if ( $range eq "" ) {
                # gets min max of start and end coord of metag on ref genome
                ( $min1, $max1 ) = getPhylumGeneFilePercentInfoMinMax( $dbh,
                    $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, \%homolog_gene_oids_h );
            } else {
                ( $min1, $max1 ) = split( /-/, $range );
            }
            #print "printScatter() min1: $min1; max1: $max1<br/>\n";

            getPhylumGeneFilePercentInfo( $dbh, $taxon_oid,
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, \@records, $min1, $max1,
                \%gene_oids_h, \%homolog_gene_oids_h, \%gene2homolog_hits );

        }
        else {

            if ( $range eq "" ) {
                # gets min max of start and end coord of metag on ref genome
                ( $min1, $max1 ) = GraphUtil::getPhylumGenePercentInfoMinMax( $dbh, $taxon_oid,
                    $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, "" );
            } else {
                ( $min1, $max1 ) = split( /-/, $range );
            }

            GraphUtil::getPhylumGenePercentInfo( $dbh, $taxon_oid,
                $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
                \@records, $min1, $max1, "" );
        }

    }


    if($img_ken) {
        printEndWorkingDiv('',1);
    } else {
        printEndWorkingDiv();
    }

    my $seq_length = $max1 - $min1 + 1;
    $seq_length = $max1 if ( $range eq "" );

    my $xincr = ceil( $seq_length / 10 );


    my $geneoids_href;

    if ( $strand eq "pos" ) {
        print "<p>Positive Strands Plot<p>\n";
        if ( $range eq "" ) {
            GraphUtil::drawScatterPanel( 0, $seq_length, \@records, $geneoids_href,
                       $xincr, "+", $merfsGenome, $taxon_oid, 1 );
        } else {
            GraphUtil::drawScatterPanel( $min1, $max1, \@records, $geneoids_href,
                       $xincr, "+", $merfsGenome, $taxon_oid, 1 );
        }
    } elsif ( $strand eq "neg" ) {
        print "<p>Negative Strands Plot<p>\n";
        if ( $range eq "" ) {
            GraphUtil::drawScatterPanel( 0, $seq_length, \@records, $geneoids_href,
                       $xincr, "-", $merfsGenome, $taxon_oid, 1 );
        } else {
            GraphUtil::drawScatterPanel( $min1, $max1, \@records, $geneoids_href,
                       $xincr, "-", $merfsGenome, $taxon_oid, 1 );
        }
    } else {
        print "<p>All Strands Plot<p>\n";
        if ( $range eq "" ) {
            GraphUtil::drawScatterPanel( 0, $seq_length, \@records, $geneoids_href,
                       $xincr, "+-", $merfsGenome, $taxon_oid, 1 );
        } else {
            #  test zoom selection
            GraphUtil::drawScatterPanel( $min1, $max1, \@records, $geneoids_href,
                       $xincr, "+-", $merfsGenome, $taxon_oid, 1 );
        }
    }

    # zoom for nomral plots and xincr must be greater than 5000
    if ( $xincr > 5000 && param("size") eq "" ) {
        print "<p>View Range &nbsp;&nbsp;";
        print "<SELECT name='zoom_select' onChange='plotZoom(\"$main_cgi\")'>\n";
        print "<OPTION value='-' selected='true'>-</option>";
        for ( my $i = $min1 ; $i <= $max1 ; $i = $i + $xincr ) {
            my $tmp = $i + $xincr;
            print "<OPTION value='$i-$tmp'>$i .. $tmp</option>";
        }
        print "</SELECT>";

        MetagJavaScript::printMetagSpeciesPlotJS();

        print hiddenVar( "family",    $family );
        print hiddenVar( "taxon_oid", $taxon_oid );
        print hiddenVar( "domain",    $domain );
        print hiddenVar( "phylum",    $phylum );
        print hiddenVar( "ir_class",  $ir_class );
        print hiddenVar( "ir_order",  $ir_order );
        print hiddenVar( "genus",     $genus );
        print hiddenVar( "species",   $species );
        print hiddenVar( "range",     $range );
        print hiddenVar( "strand",    $strand );
        print hiddenVar("merfs", $merfsGenome);
    }
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

sub getPhylumGeneFilePercentInfoMERFS {
    my ( $dbh, $taxon_oid, $data_type,
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $recs_aref,
        $homolog_start_coord_min, $homolog_end_coord_max,
        $gene_oids_href, $homolog_gene_oids_href, $gene2homolog_hits_href, $max_count )
      = @_;

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $taxon_name = QueryUtil::fetchSingleTaxonName( $dbh, $taxon_oid, $rclause, $imgClause );

    my %allGenes;
    for my $gene_oid (keys %$gene_oids_href) {
        my $workspace_id = "$taxon_oid $data_type $gene_oid";
        $allGenes{$workspace_id} = 1;
    }

    my %geneInfo;
    MetaUtil::getAllMetaGeneInfo( \%allGenes, '', \%geneInfo, '', '', 1, '', '', $max_count );

    my (%names) = MetaUtil::getGeneProdNamesForTaxon($taxon_oid, $data_type, $max_count, 1);

    my @binds;
    my ($taxonomyClause, $binds_t_clause_ref) = PhyloUtil::getTaxonomyClause2(
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    push(@binds, @$binds_t_clause_ref) if ( $binds_t_clause_ref );

    my @homolog_gene_oids = keys(%$homolog_gene_oids_href);
    my $str = OracleUtil::getNumberIdsInClause( $dbh, @homolog_gene_oids );

    my $sql = qq{
        select g.gene_oid, s.scaffold_oid, s.scaffold_name,
            g.strand, g.start_coord, g.end_coord
        from gene g, taxon t, scaffold s
        where g.gene_oid in ($str)
        and g.taxon = t.taxon_oid
        and g.scaffold = s.scaffold_oid
        $taxonomyClause
        $rclause
        $imgClause
    };
    #print "getPhylumGeneFilePercentInfoMERFS() sql: $sql<br/>\n";
    #print "getPhylumGeneFilePercentInfoMERFS() binds: @binds<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my %homologGeneInfo;
    for ( ; ; ) {
        my ( $homolog_gene_oid,  $homolog_scaffold_oid,  $homolog_scaffold_name,
             $strand,            $start,                 $end )
          = $cur->fetchrow();
        last if !$homolog_gene_oid;

        my $r = $homolog_scaffold_oid. "\t";
        $r .= $homolog_scaffold_name. "\t";
        $r .= $strand . "\t";
        $r .= $start . "\t";
        $r .= $end;
        $homologGeneInfo{$homolog_gene_oid} = $r;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $str =~ /gtt_num_id/i );


    for my $key (keys %$gene2homolog_hits_href) {
        my $r = $gene2homolog_hits_href->{$key};
        my ( $workspace_id, $percent,  $homolog_gene2,
             $homo_family, $homo_genus, $homo_species,  $homo_taxon_name )
          = split( /\t/, $r );

        my ($gene_oid, $homolog_gene) = split(/ /, $key);

        my ($locus_type, $locus_tag, $gene_display_name, $metag_start, $metag_end, $metag_strand, $scaffold, $tid2, $dtype2)
            = split(/\t/, $geneInfo{$workspace_id});
        my $scaffold_name = $scaffold; #$scaffold_name is the same as $scaffold for metagenome in file ?

        my $product_name = $names{$gene_oid};

        my $homologGeneInfo_r = $homologGeneInfo{$homolog_gene};
        my ( $homolog_scaffold_oid, $homolog_scaffold_name, $strand, $start, $end )
          = split( /\t/, $homologGeneInfo{$homolog_gene} );

        # doing this range selection here is faster than doing it in oracle
        if (    ( $start >= $homolog_start_coord_min && $start <= $homolog_end_coord_max )
             || ( $end >= $homolog_start_coord_min && $end <= $homolog_end_coord_max ) )
        {
            # do nothing
        } else {
            # skip
            next;
        }

        my @rec;

        # list is consistent with the array index global variables
        push( @rec,        $gene_oid );
        push( @rec,        $taxon_oid );
        push( @rec,        $percent );
        push( @rec,        $taxon_name );
        push( @rec,        $strand );
        push( @rec,        $start );
        push( @rec,        $end );
        push( @rec,        $scaffold );
        push( @rec,        $scaffold_name );
        push( @rec,        0 );
        push( @rec,        0 );
        push( @rec,        $homolog_gene );
        push( @rec,        '' );
        push( @rec,        $metag_start );
        push( @rec,        $metag_end );
        push( @rec,        $metag_strand );
        push( @rec,        $homolog_scaffold_name );
        push( @rec,        $product_name );
        push( @$recs_aref, \@rec );
    }
    $cur->finish();
}



1;
