############################################################################
#
# Compare Gene Models
#
# edu tool
#
# DEPRICATED 2012-09-21 - ken
#
# $Id: CompareGeneModels.pm 31256 2014-06-25 06:27:22Z jinghuahuang $
############################################################################
package CompareGeneModels;
use strict;
use CGI qw( :standard );
use DBI;
use Class::Struct;
use Data::Dumper;
use WebConfig;
use WebUtil;
use InnerTable;
use HtmlUtil;

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
    oid          => '$',
    type         => '$',
    ref_taxon    => '$',
    target_taxon => '$',
    n_taxon      => '$',
    desc         => '$',
};

struct CompCounts => {
    comp_oid     => '$',
    category     => '$',
    identical    => '$',
    similar      => '$',
    different    => '$',
    newgene      => '$',
    missed       => '$',  
    gene_count   => '$',
    genome_count => '$',
};

############################################################################
# dispatch - Dispatch loop.
#
sub dispatch {
    my $page = param("page");

    if ($page eq "topPage") {
        printDefault();
    } elsif ($page eq "viewSummary") {
        printSummary();
    } elsif ($page eq "p") {
        printPairWiseDetails();
    } elsif ($page eq "n") {
        printNWiseDetails();
    }
}

#-----------------------------------------------------------------------------
# default form
#-----------------------------------------------------------------------------
sub printDefault() {
    my $dbh      = dbLogin();

    printMainForm();
    print "<h1>\n";
    print "Gene Model Comparisons\n";
    print "</h1>\n";
    print "<div class='clear'>\n";

    my $taxon_filter_oid_str = WebUtil::getTaxonFilterOidStr( );  # selected taxons
    my $modelcomps = getApplicableModelComparisons($dbh, $taxon_filter_oid_str); # applicable comparisons
    
    if (scalar(@$modelcomps) < 1) {
        print "No applicable gene model comparisons found.\n";
        print "<br>Select <em>All</em> genomes for list of applicable gene model comparisons.\n";
        print end_form();
        return;
    }

    print "The following gene model comparisons are availabe\n";
    print "<p>\n";
    print "<table class='img' border='1'>\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Description</th>\n";
    
    foreach my $comp (@$modelcomps) {
        print "<tr>\n";
        # we are re-using 'taxon_filter_oid' to leverage the select all and de-select all buttons,
        # however, this value is the MODEL_COMP.COMP_OID value
        print "<td class='img'><input type='checkbox' name='taxon_filter_oid' value='".$comp->oid."' checked /></td>\n";
        print "<td class='img'>".$comp->desc."</td>\n";
        print "</tr>\n";
    }
    print "</table>";
    
    print "<input type='hidden' name='section' value='CompareGeneModels'/>\n";
    print "<input type='hidden' name='page'    value='viewSummary'/>\n";

    print "<input type='submit' name='submit'  value='Display Results' class='smdefbutton'/>&nbsp;\n";
    print "<input type='button' name='selectAll' value='Select All' onClick='selectAllTaxons(1)' class='smbutton' />&nbsp;";
    print "<input type='button' name='clearAll' value='Clear All' onClick='selectAllTaxons(0)' class='smbutton' />&nbsp;";

    print end_form();

    return;
}

#-----------------------------------------------------------------------------
# summary
#-----------------------------------------------------------------------------
sub printSummary() {
    my @compoids = param("taxon_filter_oid");
    my $dbh      = dbLogin();

    printMainForm();
    print "<h1>\n";
    print "Gene Model Comparisons\n";
    print "</h1>\n";
    print "<div class='clear'>\n";

    if (scalar (@compoids) < 1) {
        print "Select at least one gene model comparison.\n";
        print end_form();
        return;
    }

    printStatusLine("Loading ...");

    my $compmodels = getCompModels($dbh, \@compoids);
    
    # determine "grouping" for pair-wise comparisons
    my %refs = ();
    foreach my $c (@$compmodels) {
        $refs{$c->ref_taxon} = "";
    }
    # get the summary counts
    my $modelcounts = getModelCompSummary($dbh, \@compoids);

    # print menu
    my $haspair  = 0;
    my $hasmulti = 0;
    foreach my $c (@$compmodels) {
        $haspair = 1 if $c->type eq "P";
        $hasmulti = 1 if $c->type eq "N";
    }
    print "<p>\n";
    if ($haspair) {
        print "&nbsp;&nbsp;&nbsp;&nbsp;<a href='#b1.0'>Pair-wise Gene Model Comparisons</a>\n";
    } 
    if ($hasmulti) {
        print "<br>&nbsp;&nbsp;&nbsp;&nbsp;<a href='#b2.0'>Multi-genome Gene Model Comparisons</a>\n";
    } 
    print "<p><p>\n";
    
    # print the results for pair-wise comparisons
    if ($haspair) {
        print "<a name='b1.0' href='#'></a><h2>Pair-wise Gene Model Comparisons</h2>\n";
        print "<p>\n";
        print "<table class='img' border='1' cellpadding=5>\n";
            print "<tr>\n";
            print "<th class='img' colspan=2></th>\n";
            print "<th class='img'>Genes</th>\n";
            print "<th class='img'>Identical</th>\n";
            print "<th class='img'>Similar</th>\n";
            print "<th class='img'>Different</th>\n";
            print "<th class='img'>New</th>\n";
            print "<th class='img'>Missed</th>\n";
            print "</tr>\n";
        foreach my $ref (sort keys %refs) {
            next if ($ref eq "");
            my $r_name = taxonOid2Name($dbh, $ref, 0);
            
            print "<tr class='highlight'>\n";
            print "<th class='subhead' colspan=2><a href='main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$ref'>$r_name</a></th>\n";
            print "<th class='subhead' align=center>".getGeneCount($dbh, $ref)."</td>\n";
            print "<th class='subhead' colspan=5>&nbsp;</th>\n";
            print "</tr>\n";            
            
            foreach my $t (@$compmodels) {
                next if ($t->ref_taxon ne $ref);
                my $t_name = taxonOid2Name($dbh, $t->target_taxon, 0);
                print "<tr>\n";
                my $td = "<td class='img' align=center>";
                print "$td</td>\n";
                print "<td class='img'><a href='main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=".$t->target_taxon."'>$t_name</td>\n";
                foreach my $c (@$modelcounts) {
                    next if (!defined $c);
                    next if $c->comp_oid ne $t->oid;
                    print $td.getGeneCount($dbh, $t->target_taxon)."</td>\n";
                    print $td."<a href='main.cgi?section=CompareGeneModels&page=p&compoid=".$t->oid."&cat=I'>".$c->identical."</a></td>\n";
                    print $td."<a href='main.cgi?section=CompareGeneModels&page=p&compoid=".$t->oid."&cat=S'>".$c->similar."</td>\n";
                    print $td."<a href='main.cgi?section=CompareGeneModels&page=p&compoid=".$t->oid."&cat=D'>".$c->different."</td>\n";
                    print $td."<a href='main.cgi?section=CompareGeneModels&page=p&compoid=".$t->oid."&cat=N'>".$c->newgene."</td>\n";
                    print $td."<a href='main.cgi?section=CompareGeneModels&page=p&compoid=".$t->oid."&cat=M'>".$c->missed."</td>\n";
                    last;
                }            
            }
        }
        print "</table>";
    }

    # print the results for n-wise comparisons
    if ($hasmulti) {
        print "<p><p>\n";
        print "<a name='b2.0' href='#'></a><h2>Multi-genome Gene Model Comparisons</h2>\n";
        print "<p>\n";
        foreach my $comp (@$compmodels) {
            next if ($comp->type ne "N");
            my $ntaxon = $comp->n_taxon;
            my @taxons = split(",",$ntaxon);
            
            print "<table class='img' border='1' cellpadding=5>\n";
            print "<tr>\n";
            print "<th class='img'>";
            foreach my $taxon (@taxons) {
                print "<a href='main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon'>".taxonOid2Name($dbh,$taxon,0)."</a>\n<br>";
            }
            print "</th>\n";
            print "<th class='img'>Identical</th>\n";
            print "<th class='img'>Similar</th>\n";
            print "</tr>\n";
            my $counts = getModelCompCount($dbh,$comp->oid);  # get the summary counts
            for (my $i=scalar(@taxons); $i > 1; $i--) {
                my $igenecounts = 0;
                my $sgenecounts = 0;
                foreach my $cc (@$counts) {
                    if ($cc->category eq "I" && $cc->genome_count >= $i) {
                        $igenecounts += $cc->gene_count;
                        next;
                    }
                    if ($cc->category eq "S" && $cc->genome_count >= $i) {
                        $sgenecounts += $cc->gene_count;
                        next;
                    }
                }

                print "<tr>\n";
                print "<td class='img' align=center>n=$i</td>\n";
                print "<td class='img' align=center>";
                if ($igenecounts != 0) {
                    print "<a href='main.cgi?section=CompareGeneModels&page=n&compoid=".$comp->oid."&cat=I&nn=".scalar(@taxons)."&n=$i'>".$igenecounts;
                }
                print "</td>\n";

                print "<td class='img' align=center>";
                if ($sgenecounts != 0) {
                    print "<a href='main.cgi?section=CompareGeneModels&page=n&compoid=".$comp->oid."&cat=S&nn=".scalar(@taxons)."&n=$i'>".$sgenecounts;
                }
                print "</td>\n";

                print "</tr>\n";                
            }
            print "</table>"
        }
    }
    printStatusLine("Loaded", 2);
    print end_form();
    return;
}

#-----------------------------------------------------------------------------
# pair wise details
#-----------------------------------------------------------------------------
sub printPairWiseDetails() {
    my $compoid = param("compoid");
    my $cat     = param("cat");
    my $dbh     = dbLogin();

    my $sql = qq{
      select distinct g0.gene_oid, g0.gene_display_name
      from gene g0, model_comp_genes mcg
      where mcg.model_comp = $compoid
        and mcg.category = '$cat'
        and mcg.gene = g0.gene_oid
    };
    
    my $modelcomps = getApplicableModelComparisons($dbh, WebUtil::getTaxonFilterOidStr() );
    my $desc = "";
    my $mc;
    foreach my $_mc (@$modelcomps) {
        $mc = $_mc;
        if ($mc->oid eq $compoid) {
            $desc = $mc->desc;
            last; 
        }
    }
    if ($cat eq "I") {
        $desc = "Identical genes in " . $desc;
    } elsif ($cat eq "S") {
        $desc = "Similar genes in " . $desc;
    } elsif ($cat eq "D") {
        $desc = "Different genes in " . $desc; 
    } elsif ($cat eq "N") {
        my $tartaxonoid = $mc->target_taxon;
        my $tartaxonname = taxonOid2Name($dbh, $tartaxonoid, 0);
        $desc = "New genes in $tartaxonname [" . $desc . "]";
    } elsif ($cat eq "M") {
        my $reftaxonoid = $mc->ref_taxon;
        my $reftaxonname = taxonOid2Name($dbh, $reftaxonoid, 0);
        $desc = "Missing genes in $reftaxonname [". $desc ."]";
    }
    
    HtmlUtil::printGeneListSection( $sql, formatHtmlTitle($desc,60), 1 );
    return;
}

#-----------------------------------------------------------------------------
# multi-genome details
#-----------------------------------------------------------------------------
sub printNWiseDetails() {
    my $compoid = param("compoid");
    my $cat     = param("cat");
    my $nn      = param("nn");  # all genomes
    my $n       = param("n");   # n genomes

    my $dbh     = dbLogin();
    
    # all applicable model comparisons (we want the description field)
    my $modelcomps = getApplicableModelComparisons($dbh, WebUtil::getTaxonFilterOidStr() );

    # retrieve all the coordinates to plot against
    my $coordinates = getNWiseCoordinates($dbh, $compoid, $cat, $n);
    
    # retrieve the model comparison
    my $compmodel;
    foreach my $m (@$modelcomps) {
        $compmodel = $m if ($m->oid == $compoid);
    }
    my @taxons = split(",", $compmodel->n_taxon);
    
    # for each of the taxons in comparison, build the model for display iteration
    my %taxonhash = ();
    foreach my $taxon (@taxons) {
        my $taxongenes = getNWiseGenes($dbh, $taxon, $compoid, $cat, $n);
        $taxonhash{$taxon} = $taxongenes;
    }    

   # print the output
   printMainForm( );
   my $title = "";
   if ($cat eq "I") {
       $title = "Identical genes (at least $n genomes) in ".$compmodel->desc."\n";
   } elsif ($cat eq "S") {
       $title = "Similar genes (at least $n genomes) in ".$compmodel->desc."\n";
   }
   print "<h1>\n";
   print formatHtmlTitle($title, 60);
   print "</h1>\n";
   printGeneCartFooter( );
   printStatusLine( "Loading ...", 1 );
   print "<p>\n";
   
   print "<table class='img' border='1' cellpadding=5>\n";
   print "<tr>\n";
   for (my $i=0; $i < @taxons; $i++) {
       my $t = $taxons[$i];
       my $tname = taxonOid2Name($dbh, $t, 0);
       print "<th class='img' align=center>$tname</th>\n";
   }
   print "</tr>\n";
   
   my $genedetails = "main.cgi?section=GeneDetail&page=geneDetail&gene_oid=";
   foreach my $coord (@$coordinates) {
       print "<tr>\n";
       foreach my $taxon (@taxons) {
           my $taxongenes = $taxonhash{$taxon};
           print "<td class='img' align=center>\n";
           if (defined $taxongenes->{$coord}) {
               my $geneoid = $taxongenes->{$coord};
               print "<input type='checkbox' name='gene_oid' value='$geneoid'><a href='$genedetails$geneoid'>$geneoid</a>";
           } 
           print "</td>\n";
       }
       print "</tr>\n";
   }
   print "</table>\n";

    printStatusLine ( scalar(@$coordinates)." comparison rows displayed", 2);   
   print end_form( );
    return;
}

#-----------------------------------------------------------------------------
# sub get n-wise taxon gene information
#-----------------------------------------------------------------------------
sub getNWiseGenes() {
    my (@args) = @_;
    my $dbh     = shift @args;
    my $taxon   = shift @args;
    my $compoid = shift @args;
    my $cat     = shift @args;
    my $n       = shift @args;
    
    my %coordinates = ();    
    my $sql = qq{
        select coord, gene
        from model_comp_genes, gene
        where gene.taxon = $taxon
          and gene.gene_oid = model_comp_genes.gene
          and model_comp = $compoid
          and category = '$cat'
          and genome_count >= $n
        order by coord asc
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($coord, $gene) = $cur->fetchrow();
        last if !$coord;
        $coordinates{$coord} = $gene;
    }
    $cur->finish();
    return \%coordinates;
}

#-----------------------------------------------------------------------------
# sub get coordinates to plot against
#-----------------------------------------------------------------------------
sub getNWiseCoordinates() {
    my (@args) = @_;
    my $dbh     = shift @args;
    my $compoid = shift @args;
    my $cat     = shift @args;
    my $n       = shift @args;

    my @coordinates = ();    
    my $sql = qq{
        select coord
        from model_comp_genes
        where model_comp = $compoid
          and category = '$cat'
          and genome_count >= $n
        group by coord
        order by coord asc
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($coord) = $cur->fetchrow();
        last if !$coord;
        push @coordinates, $coord;
    }
    $cur->finish();
    return \@coordinates;
}

#-----------------------------------------------------------------------------
# helper query
#   Based on the current taxon selections, retrieve the applicable
# model comparisons 
#-----------------------------------------------------------------------------
sub getApplicableModelComparisons() {
    my (@args) = @_;
    my $dbh                = shift @args;
    my $selectedtaxons_str = shift @args;
    
    # split the current selection into a hash
    my @selectedtaxons_arr  = split(",", $selectedtaxons_str);
    my %selectedtaxons_hash = WebUtil::array2Hash(@selectedtaxons_arr);

    # get all the model comparisons
    my @modelcomps = ();
    my $sql = qq{
        select comp_oid, comp_type, ref_taxon, target_taxon, n_taxon
        from model_comp
        order by comp_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    # determine the relevant models and push it into @modelcomps
    for ( ; ; ) {
        my ( $comp_oid, $comp_type, $ref_taxon, $target_taxon, $n_taxon) = $cur->fetchrow();
        last if !$comp_oid;

        my $mc = ModelComp->new();
        $mc->oid($comp_oid);
        $mc->type($comp_type);
        $mc->ref_taxon($ref_taxon);
        $mc->target_taxon($target_taxon);
        $mc->n_taxon($n_taxon);
        
        # if $selectedtaxons_str eq "" then *ALL* taxons are selected by default
        if (!defined $selectedtaxons_str || "" eq $selectedtaxons_str) {
            push @modelcomps, $mc;
        }
        elsif ("P" eq $comp_type && (exists $selectedtaxons_hash{$ref_taxon} || exists $selectedtaxons_hash{$target_taxon})) {
            push @modelcomps, $mc;
        }
        elsif ("N" eq $comp_type) {
            my @n = split(",", $n_taxon);
            foreach my $_n (@n) {
                if (exists $selectedtaxons_hash{$_n}) {
                    push @modelcomps, $mc;
                    last;
                }
            }
        }
    }
    $cur->finish();
    # Populate the description field -- this is something we'll do dynamically
    my %taxonnamehash=();
    foreach my $comp (@modelcomps) {
        my $comp_type = $comp->type;
        my $ref_taxon = $comp->ref_taxon;
        my $target_taxon = $comp->target_taxon;
        my @n_taxons  = split(",", $comp->n_taxon);
        my $taxonname = "";
        my $taxontmp  = "";
        my $refname       = "";
        my $refversion    = "";
        my $targetname    = "";
        my $targetversion = "";
        if ($comp_type eq "P") {
            # determine taxon name
            if (exists $taxonnamehash{$ref_taxon}) {
                $taxontmp = $taxonnamehash{$ref_taxon};
            } else {
                $taxontmp = taxonOid2Name($dbh, $ref_taxon, 0);
                $taxonnamehash{$ref_taxon} = $taxontmp;
            }
            my ($taxonname, @toks) = split("\\(", $taxontmp);
            # determine model version
            $refname = $taxonnamehash{$ref_taxon};
            $refversion = grabString($refname, "(", ")");
            if (exists $taxonnamehash{$target_taxon}) {
                $targetname = $taxonnamehash{$target_taxon};
            } else {
                $targetname = taxonOid2Name($dbh, $target_taxon, 0);
                $taxonnamehash{$target_taxon} = $targetname;
            }
            $targetversion = grabString($targetname, "(", ")");
            # generate readable names
            if ($refversion ne $refname && $targetversion ne $targetname) { 
                $comp->desc("$taxonname pair-wise $refversion vs $targetversion gene model comparison");
            } else {
                $comp->desc("$refversion vs $targetversion pair-wise gene model comparison");
            }
        }
        elsif ($comp_type eq "N") {
            if (exists $taxonnamehash{$n_taxons[0]}) {
                $taxontmp = $taxonnamehash{$n_taxons[0]};
            } else {
                $taxontmp = taxonOid2Name($dbh, $n_taxons[0], 0);
                $taxonnamehash{$n_taxons[0]} = $taxontmp;
            }
            my ($taxonname, @toks) = split("\\(", $taxontmp);
            # get version names
            my $nversionnames = "";
            foreach my $n (@n_taxons) {
                my $tmpname = "";
                if (exists $taxonnamehash{$n}) {
                    $taxontmp = $taxonnamehash{$n};
                } else {
                    $taxontmp = taxonOid2Name($dbh, $n, 0);
                    $taxonnamehash{$n} = $taxontmp;
                }
                $tmpname = grabString($taxontmp, "(", ")");
                $nversionnames .= $tmpname.", ";
            }
            chop $nversionnames; chop $nversionnames;
            $comp->desc("$taxonname multi-genome $nversionnames gene model comparison");
        }
    }
    return \@modelcomps;
}

#-----------------------------------------------------------------------------
# grab the word between given bounds
#-----------------------------------------------------------------------------
sub grabString() {
    my (@args) = @_;
    my $word  = shift @args;
    my $left  = shift @args;
    my $right = shift @args;
    
    my $lidx = index($word, $left);
    my $ridx = index($word, $right);
    
    if ($lidx > 0 && $ridx > 0) {
        return substr($word, $lidx+1, $ridx-$lidx-1); 
    }
    return $word;
}

#-----------------------------------------------------------------------------
# retrieve the comp model details given the comp oids
#-----------------------------------------------------------------------------
sub getCompModels() {
    my (@args) = @_;
    my $dbh         = shift @args;
    my $compoids    = shift @args;

    my $inclause = "";
    foreach my $m (@$compoids) {
        $inclause .= $m.",";
    }
    chop ($inclause);

    # get all the model comparisons
    my @modelcomps = ();
    my $sql = qq{
        select comp_oid, comp_type, ref_taxon, target_taxon, n_taxon
        from model_comp
        where comp_oid in ($inclause)
        order by comp_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $comp_oid, $comp_type, $ref_taxon, $target_taxon, $n_taxon) = $cur->fetchrow();
        last if !$comp_oid;

        my $mc = ModelComp->new();
        $mc->oid($comp_oid);
        $mc->type($comp_type);
        $mc->ref_taxon($ref_taxon);
        $mc->target_taxon($target_taxon);
        $mc->n_taxon($n_taxon);

        push @modelcomps, $mc;
    }
    $cur->finish();
    return \@modelcomps;
}

#-----------------------------------------------------------------------------
# get gene count
#-----------------------------------------------------------------------------
sub getGeneCount() {
    my (@args) = @_;
    my $dbh         = shift @args;
    my $taxonoid    = shift @args;

    my $count = 0;
    my $sql = qq{
        select count(*)
        from gene
        where taxon = $taxonoid
    };
    
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($_count) = $cur->fetchrow();
        last if !$_count;
        $count = $_count;
    }
    $cur->finish();
    return $count;
}

#-----------------------------------------------------------------------------
# retrieve count summaries for pair-wise comparisons
#-----------------------------------------------------------------------------
sub getModelCompSummary() {
    my (@args) = @_;
    my $dbh         = shift @args;
    my $compoids    = shift @args;
    
    my $inclause = "";
    foreach my $m (@$compoids) {
        $inclause .= $m.",";
    }
    chop ($inclause);

    # generate sql    
    my @compsummary = ();
    my $sql = qq{
        select distinct(category), count(*), model_comp
        from model_comp_genes
        where model_comp in ($inclause)
        group by category, model_comp
        order by model_comp
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    # determine the relevant models and push it into @modelcomps
    for ( ; ; ) {
        my ( $category, $count, $model_comp )= $cur->fetchrow();
        last if !$category;
        
        my $cc;
        if (defined $compsummary[$model_comp]) {
            $cc = $compsummary[$model_comp];
        } else {
            $cc = CompCounts->new();
            $cc->comp_oid($model_comp);
        }
        if ("I" eq $category) {
            $cc->identical($count);
        } elsif ("S" eq $category) {
            $cc->similar($count);
        } elsif ("D" eq $category) {
            $cc->different($count);
        } elsif ("N" eq $category) {
            $cc->newgene($count);
        } elsif ("M" eq $category) {
            $cc->missed($count);
        }
        $compsummary[$model_comp] = $cc;
    }
    $cur->finish();
    return \@compsummary;
}

#-----------------------------------------------------------------------------
# get gene count
#-----------------------------------------------------------------------------
sub getModelCompCount() {
    my (@args) = @_;
    my $dbh          = shift @args;
    my $modelcompoid = shift @args;

    my @counts = ();

    my $sql = qq{
        select category, genome_count, gene_count
        from model_comp_count
        where model_comp = $modelcompoid
    };
    
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($category, $genome_count, $gene_count) = $cur->fetchrow();
        last if !$category;
        
        my $cc = CompCounts->new();
        $cc->comp_oid($modelcompoid);
        $cc->category($category);
        $cc->genome_count($genome_count);
        $cc->gene_count($gene_count);
        push @counts, $cc;
    }
    $cur->finish();
    return \@counts;
}

#-----------------------------------------------------------------------------
# format html title
#-----------------------------------------------------------------------------
sub formatHtmlTitle() {
    my (@args) = @_;
    my $title = shift @args;
    my $width = shift @args;
    
    my $newtitle = "";
    my @toks = split("\\s+", $title);
    my $idx=1;
    foreach my $tok (@toks) {
        if ($idx+length($tok) < $width) {
            $newtitle .= $tok." ";
            $idx += length($tok)+1;
        } else {
            $newtitle .= "<br>".$tok." ";
            $idx = length($tok)+1;
        }
    }
    return $newtitle;
}

1;

