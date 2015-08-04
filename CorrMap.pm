############################################################################
# CorrMap.pm - Do correlation map.
#    --es 04/08/2007
############################################################################
package CorrMap;

use strict;
use CGI qw( :standard );
use DBI;
use InnerTable;
use WebConfig;
use WebUtil;
use DrawTree;
use DrawTreeNode;
use OracleUtil;
use GenomeListFilter;

my $section = "CorrMap";
my $env = getEnv( );
my $cgi_dir = $env->{ cgi_dir };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $tmp_dir = $env->{ tmp_dir };
my $tmp_url = $env->{ tmp_url };
my $cluster_bin = $env->{ cluster_bin };
my $r_bin = $env->{ r_bin };

############################################################################
# dispatch - Dispatch loop
############################################################################
sub dispatch {
    my $page = param( "page" );
    if( $page eq "corrMapResults" ) {
       printCorrMapResults( );
    }
    else {
       printCorrMapForm( );
    }
}

############################################################################
# printCorrMapForm - Show form for setting paramters for clustering.
############################################################################
sub printCorrMapForm {

   print "<h1>Correlation Map</h1>\n";
   print "<p>\n";
   print "You may show correlation between samples ";
   print "(genomes or metagenomes)<br/>";
   print "based on similar COG, Pfam, or enzyme profiles.<br/>\n";
   print "</p>\n";

   printMainForm( );

   print "<p>\n";
   print "<b>Select Genome(s)</b>:<br/>\n";
   print "</p>\n";

   my $dbh = dbLogin();
   GenomeListFilter::appendGenomeListFilter($dbh);
   #$dbh->disconnect();

   print "<p>\n";
   print "<b>Functional Profile</b>:<br/>\n";
   print "<input type='radio' name='func' value='cog' checked />COG<br/>\n";
   print "<input type='radio' name='func' value='cogCat' />";
   #print "COG Category<br/>\n";
   #print "<input type='radio' name='func' value='pfam' />";
   print "Pfam<br/>\n";
   print "<input type='radio' name='func' value='enzyme' />";
   print "Enzymes<br/>\n";
   print "</p>\n";

   print hiddenVar( "section", $section );
   print hiddenVar( "page", "corrMapResults" );

   my $name = "_section_${section}_corrMapResults";
   print submit( -id  => "go", -name => $name, -value => "Go",
      -class => "smdefbutton" );
   print nbsp( 1 );
   print reset( -id  => "reset", -class => "smbutton" );
   print "<br/>\n";

   printHint( "Hold down control key (or command key in the case " .
     "of the Mac)<br/>to select or deselect multiple values." );

   print end_form( );
}

############################################################################
# printCorrMapResults - Run correlation results.
############################################################################
sub printCorrMapResults {

   print "<h1>Correlation Map Results</h1>\n";

   print "<p>\n";
   print "</p>\n";

   my @taxon_oid = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");
   my $nTaxons = @taxon_oid;
   if( $nTaxons < 2 || $nTaxons > 26 ) {
       webError( "Please select between two and 26 genomes." );
   }
   printStatusLine( "Loading ...", 1 );
   my $dbh = dbLogin( );

   my %taxonProfiles;
   print "<p>\n";
   getProfileVectors( $dbh, \%taxonProfiles );
   normalizeProfileVectors( $dbh, \%taxonProfiles );

}

############################################################################
# getMetagenome - Get list of metagenomes.
############################################################################
sub getMetagenomes {
   my( $dbh, $metagenome_ref ) = @_;
   my $sql = qq{
       select taxon_oid
       from taxon
       where genome_type = 'metagenome'
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   for( ;; ) {
       my( $taxon_oid ) = $cur->fetchrow( );
       last if !$taxon_oid;
       $metagenome_ref->{ $taxon_oid } = 1;
   }
   $cur->finish( );
}

############################################################################
# getProfileVectors
############################################################################
sub getProfileVectors {
   my( $dbh, $taxonProfiles_ref ) = @_;

   my $func = param( "func" );
   if( $func eq "cog" ) {
      getCogVectors( $dbh, $taxonProfiles_ref );
   }
   elsif( $func eq "cogCat" ) {
      getCogCatVectors( $dbh, $taxonProfiles_ref );
   }
   elsif( $func eq "pfam" ) {
      getPfamVectors( $dbh, $taxonProfiles_ref );
   }
   elsif( $func eq "enzyme" ) {
      getEnzymeVectors( $dbh, $taxonProfiles_ref );
   }
}

############################################################################
# getCogVectors - Get profile vectors for COG.
############################################################################
sub getCogVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
       select c.cog_id
       from cog c
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id ) = $cur->fetchrow( );
       last if !$id;
       $tpl{ $id } = 0;
    }
    $cur->finish( );

    my @profileTaxonBinOids = param( "profileTaxonBinOid" );
    my @taxon_oids;
    for my $i( @profileTaxonBinOids ) {
       if( $i !~ /^t:/ ) {
           webLog( "getCogVectors: bad selection '$i'\n" );
	   next;
       }
       $i =~ s/t://;
       push( @taxon_oids, $i );
    }
    for my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
	print "Find profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";
	my $sql = qq{
	    select gcg.cog, count( distinct gcg.gene_oid )
	    from gene_cog_groups gcg
	    where gcg.taxon = $taxon_oid
	    group by gcg.cog
	    order by gcg.cog
	};
	my $cur = execSql( $dbh, $sql, $verbose );
	my %profile = %tpl;
	for( ;; ) {
	    my( $id, $cnt ) = $cur->fetchrow( );
	    last if !$id;
	    $profile{ $id } = $cnt;
	}
	$cur->finish( );
	$taxonProfiles_ref->{ $taxon_oid } = \%profile;
    }
}

############################################################################
# getCogCatVectors - Get profile vectors for COG categories.
############################################################################
sub getCogCatVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
       select cf.function_code
       from cog_function cf
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id ) = $cur->fetchrow( );
       last if !$id;
       $tpl{ $id } = 0;
    }
    $cur->finish( );

    my @profileTaxonBinOids = param( "profileTaxonBinOid" );
    my @taxon_oids;
    for my $i( @profileTaxonBinOids ) {
       if( $i !~ /^t:/ ) {
           webLog( "getCogCatVectors: bad selection '$i'\n" );
	   next;
       }
       $i =~ s/t://;
       push( @taxon_oids, $i );
    }
    for my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
	print "Find profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";
	my $sql = qq{
	    select cf.functions, count( distinct gcg.gene_oid )
	    from gene_cog_groups gcg, cog_functions cf
	    where gcg.taxon = $taxon_oid
	    and cf.cog_id = gcg.cog
	    group by cf.functions
	    order by cf.functions
	};
	my $cur = execSql( $dbh, $sql, $verbose );
	my %profile = %tpl;
	for( ;; ) {
	    my( $id, $cnt ) = $cur->fetchrow( );
	    last if !$id;
	    $profile{ $id } = $cnt;
	}
	$cur->finish( );
	$taxonProfiles_ref->{ $taxon_oid } = \%profile;
    }
}

############################################################################
# getPfamVectors - Get profile vectors for COG categories.
############################################################################
sub getPfamVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
       select pf.ext_accession
       from pfam_family pf
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id ) = $cur->fetchrow( );
       last if !$id;
       $tpl{ $id } = 0;
    }
    $cur->finish( );

    my @profileTaxonBinOids = param( "profileTaxonBinOid" );
    my @taxon_oids;
    for my $i( @profileTaxonBinOids ) {
       if( $i !~ /^t:/ ) {
           webLog( "getPfamVectors: bad selection '$i'\n" );
	   next;
       }
       $i =~ s/t://;
       push( @taxon_oids, $i );
    }
    for my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
	print "Find profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";
	my $sql = qq{
	    select gpf.pfam_family, count( distinct gpf.gene_oid )
	    from gene g, gene_pfam_families gpf
	    where g.gene_oid = gpf.gene_oid
	    and g.taxon = $taxon_oid
	    group by gpf.pfam_family
	    order by gpf.pfam_family
	};
	my $cur = execSql( $dbh, $sql, $verbose );
	my %profile = %tpl;
	for( ;; ) {
	    my( $id, $cnt ) = $cur->fetchrow( );
	    last if !$id;
	    $profile{ $id } = $cnt;
	}
	$cur->finish( );
	$taxonProfiles_ref->{ $taxon_oid } = \%profile;
    }
}

############################################################################
# getEnzymeVectors - Get profile vectors for COG categories.
############################################################################
sub getEnzymeVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    ## Template
    my $sql = qq{
       select ez.ec_number
       from enzyme ez
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %tpl;
    for( ;; ) {
       my( $id ) = $cur->fetchrow( );
       last if !$id;
       $tpl{ $id } = 0;
    }
    $cur->finish( );

    my @profileTaxonBinOids = param( "profileTaxonBinOid" );
    my @taxon_oids;
    for my $i( @profileTaxonBinOids ) {
       if( $i !~ /^t:/ ) {
           webLog( "getEnzymeVectors: bad selection '$i'\n" );
	   next;
       }
       $i =~ s/t://;
       push( @taxon_oids, $i );
    }
    for my $taxon_oid( @taxon_oids ) {
        my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
	print "Find profile for <i>" . escHtml( $taxon_name );
	print "</i> ...<br/>\n";
	my $sql = qq{
	    select ge.enzymes, count( distinct ge.gene_oid )
	    from gene g, gene_ko_enzymes ge
	    where g.gene_oid = ge.gene_oid
	    and g.taxon = $taxon_oid
	    group by ge.enzymes
	    order by ge.enzymes
	};
	my $cur = execSql( $dbh, $sql, $verbose );
	my %profile = %tpl;
	for( ;; ) {
	    my( $id, $cnt ) = $cur->fetchrow( );
	    last if !$id;
	    $profile{ $id } = $cnt;
	}
	$cur->finish( );
	$taxonProfiles_ref->{ $taxon_oid } = \%profile;
    }
}

############################################################################
# normalizeProfileVectors - Normalize value by genome size.
############################################################################
sub normalizeProfileVectors {
    my( $dbh, $taxonProfiles_ref ) = @_;

    print "Normalizing profiles by genome size ...<br/>\n";
    my @taxon_oids = sort( keys( %$taxonProfiles_ref ) );
    for my $taxon_oid( @taxon_oids ) {
        my $profile_ref = $taxonProfiles_ref->{ $taxon_oid };
	normalizeTaxonProfile( $dbh, $taxon_oid, $profile_ref );
    }
}

############################################################################
# normalizeTaxonProfile - Normalize profile for one taxon.
############################################################################
sub normalizeTaxonProfile {
    my( $dbh, $taxon_oid, $profile_ref ) = @_;

    my $sql = qq{
       select total_gene_count
       from taxon_stats
       where taxon_oid = $taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my( $total_gene_count ) = $cur->fetchrow( );
    $cur->finish( );
    if( $total_gene_count == 0 ) {
       webLog( "normalizeTaxonProfile: WARNING: total_gene_count=0\n" );
       warn( "normalizeTaxonProfile: WARNING: total_gene_count=0\n" );
       return;
    }
    my @keys = sort( keys( %$profile_ref ) );
    for my $k( @keys ) {
       my $cnt = $profile_ref->{ $k };
       my $v = ( $cnt / $total_gene_count ) * 1000;
       $profile_ref->{ $k } = $v;
    }
}

