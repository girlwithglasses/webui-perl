############################################################################
#
# Compare Gene Model Neighborhoods
#
# $Id: CompareGeneModelNeighborhood.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package CompareGeneModelNeighborhood;
use strict;
use CGI qw( :standard );
use DBI;
use Class::Struct;
use Data::Dumper;
use WebConfig;
use WebUtil;
use InnerTable;
use ScaffoldPanel;

my $section = "CompareGenomes";
my $env             = getEnv();
my $main_cgi        = $env->{main_cgi};
my $section_cgi     = "$main_cgi?section=$section";
my $tmp_url         = $env->{tmp_url};
my $tmp_dir         = $env->{tmp_dir};
my $verbose         = $env->{verbose};
my $web_data_dir    = $env->{web_data_dir};
my $preferences_url = "$main_cgi?section=MyIMG&page=preferences";
my $img_lite        = $env->{img_lite};

my $cog_base_url  = $env->{cog_base_url};
my $pfam_base_url = $env->{pfam_base_url};

my $flank_length     = 25000;
my $maxNeighborhoods = 15;
my $maxColors        = 246;


# Declare the Model Comparison data structure
struct ModelComp => {
    comp_oid     => '$',
    ref_taxon    => '$',
    target_taxon => '$',
};

struct ModelCompGenes => {
    model_comp  => '$',
    category    => '$',
};

struct Gene => {
    oid     => '$',
    start   => '$',
    end     => '$',
    strand  => '$',
    color   => '$',
    label   => '$',
};

############################################################################
# dispatch - Dispatch loop.
#
sub dispatch {
    my $page = param("page");

    if ($page eq "printNeighborhood") {
        printNeighborhood();
    } 
}

#-----------------------------------------------------------------------------
# print neighborhood
#-----------------------------------------------------------------------------
sub printNeighborhood {
    
    printMainForm();
    print "<h1>\n";
    print "Gene Model Neighborhood\n";
    print "</h1>\n";
    
    printStatusLine("Loading ...");
    
    # print gene information
    printGeneInfo();
    # print the summary table indicating how that gene is categorized 
    printSummary();
    # print the panels to depict location of gene
    printScaffold();

    printStatusLine("Loaded",2);

    print end_form();
    return;
}

#-----------------------------------------------------------------------------
# print gene info
#-----------------------------------------------------------------------------
sub printGeneInfo {
    my $goid = param ("goid");
    my $dbh = dbLogin();    
    
    # get the gene info
    my $sql = qq{
      select g.gene_oid, g.gene_symbol, 
           g.gene_display_name, 
           g.locus_type, g.locus_tag, g.start_coord, g.end_coord, g.strand,
	       g.aa_seq_length, g.scaffold
       from gene g
       where g.gene_oid = $goid 
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($gene_oid, $gene_symbol, $gene_display_name,
        $locus_type, $locus_tag, $start_coord, $end_coord, $strand,
        $aa_seq_length, $scaffold) = $cur->fetchrow();
    return if (!$gene_oid);
        
    my $label = $gene_symbol;
    $label = $locus_tag if $label eq "";
    $label = "gene $gene_oid" if $label eq "";
    $label .= " : $gene_display_name";
    $label .= " $start_coord..$end_coord";
    if( $locus_type eq "CDS" ) {
        $label .= "(${aa_seq_length}aa)";
    }
    else {
        my $len = $end_coord - $start_coord + 1;
        $label .= "(${len}bp)";
    }
    
    print "<p><a href='main.cgi?section=GeneDetail&page=geneDetail&gene_oid=$goid'>$goid</a> $label\n";
}

#-----------------------------------------------------------------------------
# print summary
#-----------------------------------------------------------------------------
sub printSummary {
    my $goid = param("goid");
    my $dbh = dbLogin();

    # determine how this gene is classified in pair-wise comparisons
    my @modelcompgenes = ();
    my $sql = qq{
        select mcg.model_comp, mcg.category
        from model_comp_genes mcg
        where mcg.gene = $goid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($model_comp, $category) = $cur->fetchrow();
        last if !$model_comp;
        my $mcg = ModelCompGenes->new;
        $mcg->model_comp($model_comp);
        $mcg->category($category);
        push @modelcompgenes, $mcg;
    }
    $cur->finish();

    # get the model comparisons where gene is in the reference taxon
    my @refmodelcomps = ();    
    my $sql = qq{
        select distinct mc.comp_oid, mc.ref_taxon, mc.target_taxon
        from model_comp mc, gene g
        where g.gene_oid = $goid
          and g.taxon = mc.ref_taxon
        order by ref_taxon asc 
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($comp_oid, $ref_taxon, $target_taxon) = $cur->fetchrow();
        last if !$comp_oid;
        my $mc = ModelComp->new;
        $mc->comp_oid($comp_oid);
        $mc->ref_taxon($ref_taxon);
        $mc->target_taxon($target_taxon);
        push @refmodelcomps, $mc;
    }
    $cur->finish();
    # get the model comparisons where gene is in the target taxon
    my @modelcomps = ();    
    my $sql = qq{
        select distinct mc.comp_oid, mc.ref_taxon, mc.target_taxon
        from model_comp mc, gene g
        where g.gene_oid = $goid
          and g.taxon = mc.target_taxon
        order by ref_taxon asc 
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($comp_oid, $ref_taxon, $target_taxon) = $cur->fetchrow();
        last if !$comp_oid;
        my $mc = ModelComp->new;
        $mc->comp_oid($comp_oid);
        $mc->ref_taxon($ref_taxon);
        $mc->target_taxon($target_taxon);
        push @modelcomps, $mc;
    }
    $cur->finish();

    # print the summary table
    print "<p>\n";
    print "<table class='img' border='1' cellpadding=5>\n";
    print "<tr>\n";
    print "<th class='img' colspan=2></th>\n";
    print "<th class='img'>Identical</th>\n";
    print "<th class='img'>Similar</th>\n";
    print "<th class='img'>Different</th>\n";
    print "<th class='img'>New</th>\n";
    print "<th class='img'>Missed</th>\n";
    print "</tr>\n";
    # first display the instance where the taxon is the reference model
    my $mc = $refmodelcomps[0];
    my $r_name = taxonOid2Name($dbh, $mc->ref_taxon, 0);
    print "<tr class='highlight'>\n";
    print "<th class='subhead' colspan=2>$r_name</th>\n";
    print "<th class='subhead' colspan=5>&nbsp;</th>\n";
    print "</tr>\n";
    foreach my $mc (@refmodelcomps) {
        my $t_name = taxonOid2Name($dbh, $mc->target_taxon, 0);
        print "<tr>\n";
        print "<td class='img'></td>\n";
        print "<td class='img'>$t_name</td>\n";

        # find the category to mark
        my $category = "";
        foreach my $mcg (@modelcompgenes) {
            next if ($mc->comp_oid ne $mcg->model_comp);
            $category = $mcg->category;
            last;
        }
        my $tdempty = "<td class='img'>&nbsp;</td>\n";
        my $tdmark  = "<td class='img' align=center>x</td>\n";
        if ($category eq "I") {
            print "$tdmark $tdempty $tdempty $tdempty $tdempty";
        } elsif ($category eq "S") {
            print "$tdempty $tdmark $tdempty $tdempty $tdempty";
        } elsif ($category eq "D") {
            print "$tdempty $tdempty $tdmark $tdempty $tdempty";
        } elsif ($category eq "N") {
            print "$tdempty $tdempty $tdempty $tdmark $tdempty";
        } elsif ($category eq "M") {
            print "$tdempty $tdempty $tdempty $tdempty $tdmark";
        } else {
            print "$tdempty $tdempty $tdempty $tdempty $tdempty";
        }
        print "</tr>\n";
    }
    # display the instances where the taxon is the target model
    foreach my $mc (@modelcomps) {
        my $r_name = taxonOid2Name($dbh, $mc->ref_taxon, 0);
        print "<tr class='highlight'>\n";
        print "<th class='subhead' colspan=2>$r_name</th>\n";
        print "<th class='subhead' colspan=5>&nbsp;</th>\n";
        print "</tr>\n";
        
        my $t_name = taxonOid2Name($dbh, $mc->target_taxon, 0);
        print "<tr>\n";
        print "<td class='img'></td>\n";
        print "<td class='img'>$t_name</td>\n";
        
        # find the category to mark
        my $category = "";
        foreach my $mcg (@modelcompgenes) {
            next if ($mc->comp_oid ne $mcg->model_comp);
            $category = $mcg->category;
            last;
        }
        my $tdempty = "<td class='img'>&nbsp;</td>\n";
        my $tdmark  = "<td class='img' align=center>x</td>\n";
        if ($category eq "I") {
            print "$tdmark $tdempty $tdempty $tdempty $tdempty";
        } elsif ($category eq "S") {
            print "$tdempty $tdmark $tdempty $tdempty $tdempty";
        } elsif ($category eq "D") {
            print "$tdempty $tdempty $tdmark $tdempty $tdempty";
        } elsif ($category eq "N") {
            print "$tdempty $tdempty $tdempty $tdmark $tdempty";
        } elsif ($category eq "M") {
            print "$tdempty $tdempty $tdempty $tdempty $tdmark";
        }
        print "</tr>\n";
    }
    print "</table>\n";
    
    return;
}

#-----------------------------------------------------------------------------
# print neighborhood
#-----------------------------------------------------------------------------
sub printScaffold() {
    my $goid     = param("goid");
    my $dbh      = dbLogin();

    my $flank_length     = 25000;

    # initial query for the gene of interest
    my $sql = qq{
        select gene_symbol, gene_display_name, aa_seq_length, locus_tag, locus_type,
               start_coord, end_coord, strand, 
               scaffold, taxon, t.taxon_name, t.taxon_display_name
        from gene, taxon t
        where gene_oid = $goid
          and gene.taxon = t.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($gene_symbol, $gene_display_name, $aa_seq_length, $locus_tag, $locus_type,
        $start_coord, $end_coord, $strand, $scaffold, $taxonoid, $taxonname, $taxondisplay) = $cur->fetchrow();
    if (!defined $start_coord) {
        print "<p><font color=red><em>ERROR: Cannot find gene ".$goid."</em></font>\n";
        return;
    }
    # determine flanking coordinates for the panel
    my $mid_coord   = int ( ( $end_coord - $start_coord) / 2) + $start_coord + 1;
    my $left_flank  = $mid_coord - $flank_length + 1;
    my $right_flank = $mid_coord + $flank_length + 1;
    $left_flank = 0 if ($left_flank < 0);
    
    # build the panel
	my $args = {
        id                 => "gn.gm.$goid.$scaffold.$left_flank.x.$right_flank",
        start_coord        => $left_flank,
        end_coord          => $right_flank,
	strand		   => "+",
        coord_incr         => 5000,
        title              => $taxondisplay,
        has_frame          => 1,
        gene_page_base_url => "$main_cgi?section=GeneDetail&page=geneDetail",
        color_array_file   => $env->{large_color_array_file},
        tmp_dir            => $tmp_dir,
        tmp_url            => $tmp_url,
    };
    my $sp = new ScaffoldPanel( $args );
       
    # gene of interest
    my $goi = Gene->new;

    # get all the genes within the flanking region
    my $sql = qq{
      select distinct g.gene_oid, g.gene_symbol, 
           g.gene_display_name, 
           g.locus_type, g.locus_tag, g.start_coord, g.end_coord, g.strand,
	       g.aa_seq_length, g.scaffold
       from gene g
       where g.taxon = $taxonoid
       and g.start_coord > 0
       and g.end_coord > 0
       and ( 
          ( g.start_coord >= $left_flank and g.end_coord <= $right_flank ) or
    	  ( ( g.end_coord + g.start_coord ) / 2 >= $left_flank and
	        ( g.end_coord + g.start_coord ) / 2 <= $right_flank )
       )        
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($gene_oid, $gene_symbol, $gene_display_name,
            $locus_type, $locus_tag, $start_coord, $end_coord, $strand,
            $aa_seq_length, $scaffold) = $cur->fetchrow();
        last if !$gene_oid;

        my $label = $gene_symbol;
        $label = $locus_tag if $label eq "";
        $label = "gene $gene_oid" if $label eq "";
        $label .= " : $gene_display_name";
        $label .= " $start_coord..$end_coord";
        if( $locus_type eq "CDS" ) {
            $label .= "(${aa_seq_length}aa)";
        }
        else {
            my $len = $end_coord - $start_coord + 1;
            $label .= "(${len}bp)";
        }
        if ($gene_oid == $goid) {
            $goi->oid($gene_oid);
            $goi->start($start_coord);
            $goi->end($end_coord);
            $goi->strand($strand);
            $goi->color($sp->{ color_red });
            $goi->label($label);
            $sp->addGene( $goi->oid, $goi->start, $goi->end, $goi->strand, $goi->color, $goi->label);
        }
         else {
            $sp->addGene( $gene_oid, $start_coord, $end_coord, $strand, $sp->{ color_yellow }, $label );
        }   
    }
    $cur->finish();
    $sp->addGene( $goi->oid, $goi->start, $goi->end, $goi->strand, $goi->color, $goi->label);

    my $s = $sp->getMapHtml( $taxondisplay );
    
    print "<p><br>\n";    
    print "$s\n";

    # get all the taxons for comparable gene models
    my $sql = qq{
      select target_taxon
      from model_comp
      where ref_taxon = $taxonoid
       order by target_taxon asc  
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @targettaxons = ();
    for ( ; ; ) {
        my ( $target_taxon ) = $cur->fetchrow();
        last if !$target_taxon;
        push @targettaxons, $target_taxon;
    }
    $cur->finish();
    foreach my $t (@targettaxons) {
        my $_s = buildPanel($dbh, $t, $goi, $left_flank, $right_flank);
        print $_s->getMapHtml($t);
    }

    print "<font color=red>red = Current Gene</font>\n";
    print "<br><font color=purple>purple = Identical Gene</font>\n";
    print "<br><font color=blue>blue = Similar Gene</font>\n";

    print toolTipCode();
    return;
}

#-----------------------------------------------------------------------------
# builds individual taxon-based gene model panel
#-----------------------------------------------------------------------------
sub buildPanel {
    my @args = @_;
    my $dbh             = shift @args;
    my $taxonoid        = shift @args;
    my $goi             = shift @args;
    my $left_flank      = shift @args;
    my $right_flank     = shift @args;

    # get taxon name
    my $taxonname = taxonOid2Name($dbh, $taxonoid, 0);

    # build the panel
	my $args = {
        id                 => "gn.gm.$taxonoid.$left_flank.x.$right_flank",
        start_coord        => $left_flank,
        end_coord          => $right_flank,
	strand		   => "+",
        coord_incr         => 5000,
        title              => $taxonname,
        has_frame          => 1,
        gene_page_base_url => "$main_cgi?section=GeneDetail&page=geneDetail",
        color_array_file   => $env->{large_color_array_file},
        tmp_dir            => $tmp_dir,
        tmp_url            => $tmp_url,
    };
    my $sp = new ScaffoldPanel( $args );

    # get all the genes within the flanking region
    my $sql = qq{
      select distinct g.gene_oid, g.gene_symbol, 
           g.gene_display_name, 
           g.locus_type, g.locus_tag, g.start_coord, g.end_coord, g.strand,
	       g.aa_seq_length, g.scaffold
       from gene g
       where g.taxon = $taxonoid
       and g.start_coord > 0
       and g.end_coord > 0
       and ( 
          ( g.start_coord >= $left_flank and g.end_coord <= $right_flank ) or
    	  ( ( g.end_coord + g.start_coord ) / 2 >= $left_flank and
	        ( g.end_coord + g.start_coord ) / 2 <= $right_flank )
       )        
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $tmpg = Gene->new;
    for ( ; ; ) {
        my ($gene_oid, $gene_symbol, $gene_display_name,
            $locus_type, $locus_tag, $start_coord, $end_coord, $strand,
            $aa_seq_length, $scaffold) = $cur->fetchrow();
        last if !$gene_oid;

        my $label = $gene_symbol;
        $label = $locus_tag if $label eq "";
        $label = "gene $gene_oid" if $label eq "";
        $label .= " : $gene_display_name";
        $label .= " $start_coord..$end_coord";
        if( $locus_type eq "CDS" ) {
            $label .= "(${aa_seq_length}aa)";
        }
        else {
            my $len = $end_coord - $start_coord + 1;
            $label .= "(${len}bp)";
        }
        my $color = $sp->{ color_yellow };
        if ($goi->start == $start_coord && $goi->end == $end_coord && $goi->strand eq $strand) {
            $color = $sp->{ color_purple };
            $tmpg->oid($gene_oid);
            $tmpg->start($start_coord);
            $tmpg->end($end_coord);
            $tmpg->strand($strand);
            $tmpg->color($color);
            $tmpg->label($label);
        } 
        elsif ($goi->strand eq '+' && $goi->strand eq $strand && $goi->end == $end_coord) {
            $color = $sp->{ color_blue };
            $tmpg->oid($gene_oid);
            $tmpg->start($start_coord);
            $tmpg->end($end_coord);
            $tmpg->strand($strand);
            $tmpg->color($color);
            $tmpg->label($label);
        }
        elsif ($goi->strand eq '-' && $goi->strand eq $strand && $goi->start == $start_coord) {
            $color = $sp->{ color_blue };
            $tmpg->oid($gene_oid);
            $tmpg->start($start_coord);
            $tmpg->end($end_coord);
            $tmpg->strand($strand);
            $tmpg->color($color);
            $tmpg->label($label);
        } 
        $sp->addGene( $gene_oid, $start_coord, $end_coord, $strand, $color, $label );
    }
    $cur->finish();
    if (defined $tmpg->oid) {
        $sp->addGene( $tmpg->oid, $tmpg->start, $tmpg->end, $tmpg->strand, $tmpg->color, $tmpg->label );
    }
    
    return $sp;    
}


1;

