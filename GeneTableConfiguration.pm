############################################################################
# GeneTableConfiguration.pm - share use
#
# $Id: GeneTableConfiguration.pm 33841 2015-07-29 20:48:56Z klchu $
############################################################################
package GeneTableConfiguration;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use TreeViewFrame;
use GenomeList;
use MerFsUtil;

my $env                = getEnv();
my $main_cgi           = $env->{main_cgi};
my $verbose            = $env->{verbose};
my $base_url           = $env->{base_url};
my $cog_base_url       = $env->{cog_base_url};
my $pfam_base_url      = $env->{pfam_base_url};
my $tigrfam_base_url   = $env->{tigrfam_base_url};
my $enzyme_base_url    = $env->{enzyme_base_url};
my $kegg_orthology_url = $env->{kegg_orthology_url};

my $YUI        = $env->{yui_dir_28};
my $yui_tables = $env->{yui_tables};

my $dDelim = "===";
my $fDelim = "<<>>";

### optional gene field columns to configuration and display
my @gOptCols = (
    'gene_symbol',
    'protein_seq_accid',
    'chromosome',
    'start_coord',
    'end_coord',
    'strand',
    'dna_seq_length',
    'aa_seq_length',
    'locus_type',
    'is_pseudogene',
    'obsolete_flag',
    'partial_gene',
    #'img_orf_type',
    'add_date',
);

my @tOptCols = (
    'is_public',
    'taxon_oid',    
);

## optional scaffold/Contig field columns to configuration and display,
my @sfOptCols = ( 'scaffold_oid', 'ext_accession', 'scaffold_name', 'read_depth', );
my @ssOptCols = ( 'seq_length',   'gc_percent', );

##'ko_id, ko_name, definition',
my @fOptCols = (
    'cog_id,cog_name',
    'pfam_id,pfam_name',
    'tigrfam_id,tigrfam_name',
    'ec_number,enzyme_name',
    #'ko_id',
    #'ko_name',
    #'definition',
    'ko_id,ko_name,definition',
    'img_term'
);

### Maps database column name to UI friendly label.
my %colName2Label = (
      locus_tag                  => 'Locus Tag',
      locus_type                 => 'Locus Type',
      gene_symbol                => 'Gene Symbol',
      gene_display_name          => 'Gene Display Name',
      product_name               => 'Product Name',
      protein_seq_accid          => 'GenBank Accession',
      chromosome                 => 'Chromosome',
      start_coord                => 'Start Coord',
      end_coord                  => 'End Coord',
      strand                     => 'Strand',
      dna_seq_length             => 'DNA Sequence Length',
      aa_seq_length              => 'Amino Acid Sequence Length',
      is_pseudogene              => 'Is Pseudogene',
      obsolete_flag              => 'Is Obsolete',
      partial_gene               => 'Is Partial Gene',
      img_orf_type               => "IMG ORF Type",
      add_date                   => 'Add Date',
      is_public                  => 'Is Public',
      scaffold                   => 'Scaffold ID',
      scaffold_oid               => 'Scaffold ID',
      ext_accession              => 'Scaffold External Accession',
      scaffold_name              => 'Scaffold Name',
      read_depth                 => 'Scaffold Read Depth',
      seq_length                 => 'Scaffold Length',
      gc_percent                 => 'Scaffold GC %',
      cog_id                     => "COG ID",
      cog_name                   => "COG Name",
      'cog_id,cog_name'          => "COG ID and Name",
      pfam_id                    => "Pfam ID",
      pfam_name                  => "Pfam Name",
      'pfam_id,pfam_name'        => "Pfam ID and Name",
      tigrfam_id                 => "Tigrfam ID",
      tigrfam_name               => "Tigrfam Name",
      'tigrfam_id,tigrfam_name'  => "Tigrfam ID and Name",
      ec_number                  => "Enzyme ID",
      enzyme_name                => "Enzyme Name",
      'ec_number,enzyme_name'    => "Enzyme ID and Name",
      ko_id                      => "KO ID",
      ko_name                    => "KO Name",
      definition                 => "KO Definition",
      'ko_id,ko_name,definition' => "KEGG Orthology ID, Name and Definition",
      'img_term'                 => 'IMG Term',
      'taxon_oid'                => 'Genome ID',
);

my %colName2Label_special = (
      dna_seq_length => 'DNA Sequence Length<br/>(bp)',
      aa_seq_length  => 'Amino Acid Sequence Length<br/>(aa)',
      seq_length     => 'Scaffold Length<br/>(bp)',
);

my %colName2Align = (
      locus_tag         => 'char asc left',
      locus_type        => 'char asc left',
      gene_symbol       => 'char asc left',
      gene_display_name => 'char asc left',
      product_name      => 'char asc left',
      protein_seq_accid => 'char asc left',
      chromosome        => 'char asc left',
      start_coord       => 'num asc right',
      end_coord         => 'num asc right',
      strand            => 'char asc center',
      dna_seq_length    => 'num desc right',
      aa_seq_length     => 'num desc right',
      is_pseudogene     => 'char asc left',
      obsolete_flag     => 'char asc left',
      partial_gene      => 'char asc left',
      img_orf_type      => "char asc left",
      add_date          => 'char asc left',
      is_public         => 'char asc left',
      scaffold          => 'num asc right',
      scaffold_oid      => 'num asc right',
      ext_accession     => 'char asc left',
      scaffold_name     => 'char asc left',
      read_depth        => 'num desc right',
      seq_length        => 'num desc right',
      gc_percent        => 'num desc right',
      cog_id            => "char asc left",
      cog_name          => "char asc left",
      pfam_id           => "char asc left",
      pfam_name         => "char asc left",
      tigrfam_id        => "char asc left",
      tigrfam_name      => "char asc left",
      ec_number         => "char asc left",
      enzyme_name       => "char asc left",
      ko_id             => "char asc left",
      ko_name           => "char asc left",
      definition        => "char asc left",
      img_term          => "char asc left",
      'taxon_oid' =>'num desc right',
);

sub getGeneFieldAttrs {
    return @gOptCols;
}

sub getFunctionFieldAttrs {
    return @fOptCols;
}

############################################################################
# findColType - Find col belonging to which type
############################################################################
sub findColType {
    my ($col) = @_;

    if ( grep $_ eq $col, @gOptCols ) {
        return 'g';
    } elsif ( grep $_ eq $col, @tOptCols ) {
        return 't';
    } elsif ( grep $_ eq $col, @sfOptCols ) {
        return 'sf';
    } elsif ( grep $_ eq $col, @ssOptCols ) {
        return 'ss';
    } elsif ( grep $_ eq $col, @fOptCols ) {
        return 'f';
    } elsif (    $col =~ /cog_id/i
              || $col =~ /cog_name/i
              || $col =~ /pfam_id/i
              || $col =~ /pfam_name/i
              || $col =~ /tigrfam_id/i
              || $col =~ /tigrfam_name/i
              || $col =~ /ec_number/i
              || $col =~ /enzyme_name/i
              || $col =~ /ko_id/i
              || $col =~ /ko_name/i
              || $col =~ /definition/i )
    {
        return 'f';
    } elsif ( GenomeList::isProjectMetadataAttr($col) ) {
        return 'p';
    }        

    return '';
}

############################################################################
# getColLabel - get label for col
############################################################################
sub getColLabel {
    my ($col) = @_;
    my $val = $colName2Label{$col};
    return $col if ( $val eq '' );
    return $val;
}

############################################################################
# getColLabel - get label for col
############################################################################
sub getColLabelSpecial {
    my ($col) = @_;
    my $val = $colName2Label_special{$col};
    return $val;
}

############################################################################
# getColAlign - get Align for col
############################################################################
sub getColAlign {
    my ($col) = @_;
    my $val = $colName2Align{$col};
    return $val;
}


############################################################################
# appendGeneTableConfiguration - Print output attributtes for optional
#   configuration information.
############################################################################
sub appendGeneTableConfiguration {
    my ( $outputColHash_ref, $name, $include_project_metadata ) = @_;

    printTreeViewMarkup();

    print "<h2>Table Configuration</h2>";
    print submit(
          -id    => "moreGo",
          -name  => $name,
          -value => "Display Genes Again",
          -class => "meddefbutton"
    );

    print qq{
        <div id='genomeConfiguration'>      
          <script type='text/javascript' src='$base_url/genomeConfig.js'></script>

          <table border='0'>
            <tr>
            <td>
              <span class='hand' id='plus_minus_span5' onclick="javascript:showFilter(5, '$base_url')">
                <img id='plus_minus1' alt='close' src='$base_url/images/elbow-minus-nl.gif'/>
              </span>
              Gene Field
            </td>
            <td>
              <span class='hand' id='plus_minus_span6' onclick="javascript:showFilter(6, '$base_url')">
                <img id='plus_minus3' alt='close' src='$base_url/images/elbow-minus-nl.gif'/>
              </span>
              Scaffold/Contig Field
            </td>
            <td style='width:550px;'>
              <span class='hand' id='plus_minus_span7' onclick="javascript:showFilter(7, '$base_url')">
                <img id='plus_minus4' alt='close' src='$base_url/images/elbow-minus-nl.gif'/>
              </span>
              Function Field
            </td>
    };
    if ($include_project_metadata) {
        print qq{
                <td>
                  <span class='hand' id='plus_minus_span2' onclick="javascript:showFilter(2, '$base_url')">
                    <img id='plus_minus2' alt='close' src='$base_url/images/elbow-minus-nl.gif'/>
                  </span>
                  Project Metadata
                </td>
        };
    }
    print "</tr><tr>";

    my @gtOptCols = ();   # add @gOptCols and @tOptCols into @gtOptCols
    push( @gtOptCols, @gOptCols, @tOptCols ); 

    my @sOptCols = ();    # add @sfOptCols and @ssOptCols into @sOptCols
    push( @sOptCols, @sfOptCols );
    splice( @sOptCols, 3, 0, @ssOptCols );

    my @categoryOptCols = ( \@gtOptCols, \@sOptCols, \@fOptCols );
    my @categoryOptColNames = ( "gene_field_col", "scaffold_field_col", "function_field_col" );
    my @categoryOptColIds = ( "geneField", "scaffoldField", "functionField" );

    my %projectMetadataColumns;
    if ($include_project_metadata) {
        %projectMetadataColumns = GenomeList::getProjectMetadataColumns();
        my @projectMetadataColumnsOrder = GenomeList::getProjectMetadataAttrs();
        push(@categoryOptCols, \@projectMetadataColumnsOrder );
        push(@categoryOptColNames, "metadata_col" );
        push(@categoryOptColIds, "projectMetadata" );
    }

    for ( my $i = 0; $i < scalar(@categoryOptColNames); $i++ ) {
        my $field_col_name = $categoryOptColNames[$i];
        my $field_col_id = $categoryOptColIds[$i];
        print qq{ 
            <td>
              <div id='$field_col_id' class='myborder'>
                <input type="button" value="All"   onclick="selectObject(1, '$field_col_name')">
                <input type="button" value="Clear" onclick="selectObject(0, '$field_col_name')">
                <br/>
        };
    
        # taxon attributes have a pre-defined sort order
        my $categoryOptCols_ref = $categoryOptCols[$i];
        foreach my $key (@$categoryOptCols_ref) {
            my $value;
            if ( $field_col_name eq 'metadata_col' ) {
                $value = $projectMetadataColumns{$key};                
            }
            else {
                $value = $colName2Label{$key};
            }

            my $str;
            if (    $outputColHash_ref->{$key} ne ''
                 || ( $key eq 'cog_id,cog_name'          && $outputColHash_ref->{'cog_id'}  ne '' )
                 || ( $key eq 'pfam_id,pfam_name'        && $outputColHash_ref->{'pfam_id'} ne '' )
                 || ( $key eq 'tigrfam_id,tigrfam_name'  && $outputColHash_ref->{'tigrfam_id'} ne '' )
                 || ( $key eq 'ec_number,enzyme_name'    && $outputColHash_ref->{'ec_number'} ne '' )
                 || ( $key eq 'ko_id,ko_name,definition' && $outputColHash_ref->{'ko_id'}   ne '' ) )
            {
                $str = 'checked';
            }

            print qq{
                <input type="checkbox" value="$key" name="$field_col_name" $str> $value <br/>
            };
        }
        
        print qq{
                  </div>
                </td>
    
        };            
    }

    print qq{
          </tr>
        </table>
      </div>\n
    };

    print submit(
          -id    => "moreGo",
          -name  => $name,
          -value => "Display Genes Again",
          -class => "meddefbutton"
    );

}


############################################################################
# appendGeneTableConfiguration_old - Print output attributtes for optional
#   configuration information.
# Keep the old one for potential use
############################################################################
sub appendGeneTableConfiguration_old {
    my ( $outputColHash_ref, $name ) = @_;

    printTreeViewMarkup();

    print "<h2>Table Configuration</h2>\n";
    print "<table id='configurationTable' class='img' border='0'>\n";
    print qq{
        <tr class='img'>
        <th class='img' colspan='3' nowrap>Additional Output Columns<br />
            <input type='button' class='khakibutton' id='moreExpand' name='expand' value='Expand All'>
            <input type='button' class='khakibutton' id='moreCollapse' name='collapse' value='Collapse All'>
        </th>
        </tr>
    };

    print "<tr valign='top'>\n";
    my @categoryNames = ( "Gene Field", "Scaffold/Contig Field", "Function Field" );
    my $numCategories = scalar(@categoryNames);
    my @gtOptCols = ();   # add @gOptCols and @tOptCols into @gtOptCols
    push( @gtOptCols, @gOptCols, @tOptCols ); 
    my @sOptCols = ();    # add @sfOptCols and @ssOptCols into @sOptCols
    push( @sOptCols, @sfOptCols );
    splice( @sOptCols, 3, 0, @ssOptCols );
    my @categoryOptCols = ( \@gtOptCols, \@sOptCols, \@fOptCols );
    my %categories = ();

    for ( my $i = 0 ; $i < $numCategories ; $i++ ) {
        my $treeId = $categoryNames[$i];
        print "<td class='img' nowrap>\n";
        print "<div id='$treeId' class='ygtv-checkbox'>\n";

        my $jsObject            = "{label:'<b>$treeId</b>', children: [";
        my $categoryOptCols_ref = $categoryOptCols[$i];
        my @optCols             = @$categoryOptCols_ref;
        my $hiLiteCnt           = 0;
        for ( my $j = 0 ; $j < scalar(@optCols) ; $j++ ) {
            my $key = $optCols[$j];
            next if ( $key eq 'locus_tag' || $key eq 'gene_display_name' );

            if ( $j != 0 ) {
                $jsObject .= ", ";
            }
            my $val = $colName2Label{$key};

            #print "$key => $val<br/>\n";
            #my $myLabel = "<input type='checkbox' name='outputCol' value='$key' />$val";
            #$jsObject .= "{id:\"$key\", label:\"$myLabel\"}";
            #$jsObject .= "{id:\"$key\", label:\"$val\"}";
            $jsObject .= "{id:\"$key\", label:\"$val\"";
            if (    $outputColHash_ref->{$key} ne ''
                 || ( $key eq 'cog_id,cog_name'          && $outputColHash_ref->{'cog_id'}  ne '' )
                 || ( $key eq 'pfam_id,pfam_name'        && $outputColHash_ref->{'pfam_id'} ne '' )
                 || ( $key eq 'tigrfam_id,tigrfam_name'  && $outputColHash_ref->{'tigrfam_id'} ne '' )
                 || ( $key eq 'ec_number,enzyme_name'    && $outputColHash_ref->{'ec_number'} ne '' )
                 || ( $key eq 'ko_id,ko_name,definition' && $outputColHash_ref->{'ko_id'}   ne '' ) )
            {
                $jsObject .= ", highlightState:1";
                $hiLiteCnt++;
            }
            $jsObject .= "}";
        }
        $jsObject .= "]";
        if ( $hiLiteCnt > 0 ) {
            if ( $hiLiteCnt == scalar(@optCols) ) {
                $jsObject .= ", highlightState:1";
            } else {
                $jsObject .= ", highlightState:2";
            }
        }
        $jsObject .= "}";

        $categories{ $categoryNames[$i] } = $jsObject;
        print "</div></td>\n";
    }

    print "</tr>\n";
    print "</table>\n";

    my $categoriesObj = "{category:[";
    for ( my $i = 0 ; $i < $numCategories ; $i++ ) {
        $categoriesObj .= "{name:'$categoryNames[$i]', ";
        #$categoriesObj .= "value : $categories{$categoryNames[$i]}}";
        $categoriesObj .= "value:[" . $categories{ $categoryNames[$i] } . "]}";
        if ( $i != $numCategories - 1 ) {
            $categoriesObj .= ", ";
        }
    }

    $categoriesObj .= "]}";

    setJSObjects($categoriesObj);

    print submit(
                  -id    => "moreGo",
                  -name  => $name,
                  -value => "Display Genes Again",
                  -class => "meddefbutton"
    );
    print nbsp(1);

    print "<input id='selAll' type=button name=SelectAll value='Select All' class='smbutton' />\n";
    print nbsp(1);
    print "<input id='clrAll' type=button name=ClearAll value='Clear All' class='smbutton' />\n";
}

sub printTreeViewMarkup {
    printTreeMarkup();
    print qq{
        <script language='JavaScript' type='text/javascript' src='$base_url/findGenesTree.js'>
        </script>
    };
}

sub setJSObjects {
    my ($categoriesObj) = @_;
    print qq{
        <script type="text/javascript">
           setMoreJSObjects($categoriesObj);
           setExpandAll();
           moreTreeInit();
        </script>
    };
}

sub compareTwoArrays {
    my ( $first, $second ) = @_;
    return 0 unless @$first == @$second;
    for ( my $i = 0 ; $i < @$first ; $i++ ) {
        return 0 if $first->[$i] ne $second->[$i];
    }
    return 1;
}

sub getOutputCols {
    my ($fixedColIDs, $tool) = @_;

    my @outputCols;
    
    my @geneFieldCols      = param('gene_field_col');
    my @scaffoldFieldCols  = param('scaffold_field_col');
    my @functionFieldCols = param('function_field_col');
    my @projectMetadataCols = param('metadata_col');
    push(@outputCols, @geneFieldCols, @scaffoldFieldCols, @functionFieldCols, @projectMetadataCols);

    #To keep the old implementation intact
    if ( scalar(@outputCols) == 0 ) {
        my $outputColStr = param("outputCol");
        #my @fixedCols = WebUtil::processParamValue($fixedColIDs);
        #foreach my $c (@fixedCols) {
        #    $outputColStr  =~ s/$c//i;
        #}
        @outputCols = WebUtil::processParamValue($outputColStr);        
    } 

    if (scalar(@outputCols) == 0 &&
        paramMatch("setGeneOutputCol") eq '') {
        my $colIDsExist = readColIdFile($tool);
        if ($colIDsExist ne "") {
            $colIDsExist =~ s/$fixedColIDs//i;
            my @outColsExist = WebUtil::processParamValue($colIDsExist);
            push(@outputCols, @outColsExist);
        }
    }

    return \@outputCols;
}

sub getOutputColClauses {
    my ($fixedColIDs, $tool) = @_;
    
    my $outputCols_ref = getOutputCols($fixedColIDs, $tool);

    my $outColClause;
    my $taxonJoinClause;
    my $scfJoinClause;
    my $ssJoinClause;

    my $cogQueryClause;
    my $pfamQueryClause;
    my $tigrfamQueryClause;
    my $ecQueryClause;
    my $koQueryClause;
    my $imgTermQueryClause;

    my $get_taxon_public = 0;
    my $get_taxon_oid    = 0;
    my $get_gene_info    = 0;
    my $get_gene_faa     = 0;
    my $get_scaf_info    = 0;

    my @projectMetadataCols;
    
    for (my $i = 0 ; $i < scalar(@$outputCols_ref) ; $i++) {
        my $c = $outputCols_ref->[$i];
    	if ($c eq 'is_public') {
    	    $get_taxon_public = 1;
    	} elsif ($c eq 'taxon_oid') {
            $get_taxon_oid = 1;

    	} elsif ($c eq 'locus_type'
    	      || $c eq '$start_coord'
    	      || $c eq '$end_coord'
    	      || $c eq '$strand'
    	      || $c eq 'dna_seq_length'
    	      || $c eq 'scaffold_oid') {
    	    $get_gene_info = 1;
    	} elsif ($c eq 'aa_seq_length') {
    	    $get_gene_faa = 1;
    	} elsif ($c eq 'seq_length'
    	      || $c eq 'gc_percent'
    	      || $c eq 'read_depth') {
    	    $get_gene_info = 1;
    	    $get_scaf_info = 1;
    	}

        my $tableType = findColType($c);
        
        webLog("tableType === $tableType\n");
        if ($tableType eq 'g') {
            if ($c =~ /add_date/i) {
                # use iso format yyyy-mm-dd s.t. its ascii sortable - ken
                $outColClause .= ", to_char(g.$c, 'yyyy-mm-dd') ";
            } else {
                $outColClause .= ", g.$c ";
            }
        } elsif ($tableType eq 't') {
            $outColClause .= ", tx.$c ";
            $taxonJoinClause = qq{
                left join taxon tx on g.taxon = tx.taxon_oid
            } if ($scfJoinClause eq '');
        } elsif ($tableType eq 'sf') {
            $outColClause .= ", scf.$c ";
            $scfJoinClause = qq{
                left join scaffold scf on g.scaffold = scf.scaffold_oid
            } if ($scfJoinClause eq '');

        } elsif ($tableType eq 'ss') {
            $outColClause .= ", ss.$c ";
            $ssJoinClause = qq{
                left join scaffold_stats ss on g.scaffold = ss.scaffold_oid
            } if ($ssJoinClause eq '');

        } elsif ($tableType eq 'f') {
            if ($c =~ /cog_id/i || $c =~ /cog_name/i) {
                $cogQueryClause .= ", cg.$c ";
            } elsif ($c =~ /pfam_id/i || $c =~ /pfam_name/i) {
                $pfamQueryClause .= ", pf.ext_accession " if ($c =~ /pfam_id/i);
                $pfamQueryClause .= ", pf.name "          if ($c =~ /pfam_name/i);
            } elsif ($c =~ /tigrfam_id/i || $c =~ /tigrfam_name/i) {
                $tigrfamQueryClause .= ", tf.ext_accession " if ($c =~ /tigrfam_id/i);
                $tigrfamQueryClause .= ", tf.expanded_name " if ($c =~ /tigrfam_name/i);
            } elsif ($c =~ /ec_number/i || $c =~ /enzyme_name/i) {
                $ecQueryClause .= ", ec.$c ";
            } elsif ($c =~ /ko_id/i || $c =~ /ko_name/i || $c =~ /definition/i) {
                $koQueryClause .= ", kt.$c ";
            } elsif ($c eq 'img_term') {
                $imgTermQueryClause .= ", itx.term_oid, itx.term ";
            }
        } elsif ($tableType eq 'p') {
            push(@projectMetadataCols, $c);
        }
    }

    return ($outColClause, $taxonJoinClause, $scfJoinClause, $ssJoinClause, 
	    $cogQueryClause, $pfamQueryClause, $tigrfamQueryClause, 
	    $ecQueryClause, $koQueryClause, $imgTermQueryClause, 
	    \@projectMetadataCols, $outputCols_ref, $get_taxon_public, 
	    $get_gene_info, $get_gene_faa, $get_scaf_info, $get_taxon_oid);
}

# i think this is not used - ken
sub getOutputColValues {
    my ( $fixedColIDs, $tool, $gene_oids_aref, $taxon_oid, $data_type ) = @_;

    my $outputCols_ref = getOutputCols( $fixedColIDs, $tool );

    my @genes = @$gene_oids_aref;

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(@genes);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;
    my $dbh = dbLogin();
    my (
        $outColClause,   $taxonJoinClause,  $scfJoinClause, $ssJoinClause,
        $cogQueryClause, $pfamQueryClause,  $tigrfamQueryClause,
        $ecQueryClause,  $koQueryClause,    $imgTermQueryClause,
        $outputCol_ref,  $get_taxon_public, $get_gene_info,
        $get_gene_faa,   $get_scaf_info, $get_taxon_oid
    ) = getOutputColClauses( $fixedColIDs, $tool );

    my $gene2cogs_href;
    my $gene2pfams_href;
    my $gene2tigrfams_href;
    my $gene2ecs_href;
    my $gene2kos_href;
    my $gene2imgTerms_href;

    my %recs;
    if ( scalar(@dbOids) > 0 ) {
        $gene2cogs_href = getGene2Cog( $dbh, \@genes, $cogQueryClause );
        $gene2pfams_href = getGene2Pfam( $dbh, \@genes, $pfamQueryClause );
        $gene2tigrfams_href =
          getGene2Tigrfam( $dbh, \@genes, $tigrfamQueryClause );
        $gene2ecs_href = getGene2Ec( $dbh, \@genes, $ecQueryClause );
        $gene2kos_href = getGene2Ko( $dbh, \@genes, $koQueryClause );
        $gene2imgTerms_href =
          getGene2Term( $dbh, \@genes, $imgTermQueryClause );

        my $gidInClause = OracleUtil::getIdClause( $dbh, 'gtt_num_id', '', $dbOids_ref );

        my $scf_ext_accession_idx = -1;
        for ( my $i = 0 ; $i < scalar(@$outputCols_ref) ; $i++ ) {
            if ( $outputCols_ref->[$i] eq 'ext_accession' ) {
                $scf_ext_accession_idx = $i;
                last;
            }
        }

        my %scaffold2Bin;
        if ( $scf_ext_accession_idx >= 0 ) {
            my $sql = qq{
                select distinct bs.scaffold, b.bin_oid, b.display_name
                from gene g, bin_scaffolds bs, bin b
                where g.gene_oid $gidInClause
                and g.scaffold = bs.scaffold
                and bs.bin_oid = b.bin_oid
                order by bs.scaffold, b.display_name
            };
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $scaffold, $bin_oid, $bin_display_name ) =
                  $cur->fetchrow();
                last if !$scaffold;
                $scaffold2Bin{$scaffold} .= " $bin_display_name;";
            }
            $cur->finish();
        }

        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql       = qq{
            select distinct g.gene_oid, g.locus_type, g.locus_tag,
                   g.gene_symbol, g.gene_display_name, g.scaffold,
                   tx.taxon_oid, tx.taxon_display_name
                   $outColClause
            from gene g
            left join taxon tx on g.taxon = tx.taxon_oid
            $rclause
            $imgClause
            $scfJoinClause
            $ssJoinClause
            where g.gene_oid $gidInClause
            order by g.gene_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my (
                $gene_oid,    $locus_type,         $locus_tag,
                $gene_symbol, $gene_display_name,  $scaffold,
                $taxon_oid,   $taxon_display_name, @outColVals
            ) = $cur->fetchrow();
            last if !$gene_oid;

            my $desc = $gene_display_name;
            $desc = "($locus_type $gene_symbol)" if $locus_type =~ /RNA/;
            my $desc_orig = $desc;

            my $r;

            for ( my $j = 0 ; $j < scalar(@outColVals) ; $j++ ) {
                if (   $scf_ext_accession_idx >= 0
                    && $scf_ext_accession_idx == $j )
                {
                    my $scf_ext_accession = $outColVals[$j];
                    my $bin_display_names = $scaffold2Bin{$scaffold};
                    chop $bin_display_names;
                    $scf_ext_accession .= " (bin(s):$bin_display_names)"
                      if $bin_display_names ne "";
                    $r .= "$scf_ext_accession\t";
                }
                else {
                    $r .= "$outColVals[$j]\t";
                }
            }

            if ($cogQueryClause) {
                my $val = $gene2cogs_href->{$gene_oid};
                $r .= "$val\t\t";
            }
            if ($pfamQueryClause) {
                my $val = $gene2pfams_href->{$gene_oid};
                $r .= "$val\t\t";
            }
            if ($tigrfamQueryClause) {
                my $val = $gene2tigrfams_href->{$gene_oid};
                $r .= "$val\t\t";
            }
            if ($ecQueryClause) {
                my $val = $gene2ecs_href->{$gene_oid};
                $r .= "$val\t\t";
            }
            if ($koQueryClause) {
                my $val = $gene2kos_href->{$gene_oid};
                $r .= "$val\t\t\t";
            }
            if ($imgTermQueryClause) {
                my $val = $gene2imgTerms_href->{$gene_oid};
                $r .= "$val\t";
            }

            $recs{$gene_oid} = $r;
        }

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $gidInClause =~ /gtt_num_id/i );
    }

    if ( scalar(@metaOids) > 0 ) {
        my %genes_h;
        my %taxon_oid_h;

        printStartWorkingDiv();    ### hmm... this is odd
        foreach my $workspace_id (@metaOids) {
            if ( $taxon_oid ne "" && $data_type ne "" ) {
                $genes_h{"$taxon_oid $data_type $workspace_id"} = 1;
                $taxon_oid_h{$taxon_oid} = 1;
            }
            else {
                $genes_h{$workspace_id} = 1;
                my @vals = split( / /, $workspace_id );
                if ( scalar(@vals) >= 3 ) {
                    $taxon_oid_h{ $vals[0] } = 1;
                }
            }
        }
        my @taxonOids = keys(%taxon_oid_h);
        my %taxon_name_h;
        my %genome_type_h;
        if ( scalar(@taxonOids) > 0 ) {
            my ( $taxon_name_h_ref, $genome_type_h_ref ) =
              QueryUtil::fetchTaxonOid2NameGenomeTypeHash( $dbh, \@taxonOids );
            %taxon_name_h  = %$taxon_name_h_ref;
            %genome_type_h = %$genome_type_h_ref;
        }

        my %taxon_public_h;
        if ( $get_taxon_public && scalar(@taxonOids) > 0 ) {
            %taxon_public_h =
              QueryUtil::fetchTaxonOid2PublicHash( $dbh, \@taxonOids );
        }

        my @meta_oids   = keys %genes_h;
        my $ncount      = scalar @meta_oids;
        my %taxon_genes = MetaUtil::getOrganizedTaxonGenes(@meta_oids);

        my %gene_name_h;
        MetaUtil::getAllMetaGeneNames( \%genes_h, \@meta_oids, \%gene_name_h,
            \%taxon_genes, 1 );

        my %gene_info_h;
        my %scaf_id_h;
        if ( $get_gene_info && $ncount > 0 ) {
            MetaUtil::getAllMetaGeneInfo( \%genes_h, \@meta_oids,
                \%gene_info_h, \%scaf_id_h, \%taxon_genes, 1, 0, 1 );
        }

        my %gene_faa_h;
        if ( $get_gene_faa && $ncount > 0 ) {
            MetaUtil::getAllMetaGeneFaa( \%genes_h, \@meta_oids, \%gene_faa_h,
                \%taxon_genes, 1 );
        }

        my %scaffold_h;
        if ( $get_scaf_info && scalar( keys %scaf_id_h ) > 0 ) {
            MetaUtil::getAllScaffoldInfo( \%scaf_id_h, \%scaffold_h );
        }

        my %gene_cog_h;
        my %cog_name_h;
        if ( $cogQueryClause && $cogQueryClause ne "" && $ncount > 0 ) {
            MetaUtil::getAllMetaGeneFuncs( 'cog', '', \%genes_h, \%gene_cog_h );
            QueryUtil::fetchAllCogIdNameHash( $dbh, \%cog_name_h );
        }

        my %gene_pfam_h;
        my %pfam_name_h;
        if ( $pfamQueryClause && $pfamQueryClause ne "" ) {
            MetaUtil::getAllMetaGeneFuncs( 'pfam', '', \%genes_h, \%gene_pfam_h );
            QueryUtil::fetchAllPfamIdNameHash( $dbh, \%pfam_name_h );
        }

        my %gene_tigrfam_h;
        my %tigrfam_name_h;
        if ( $tigrfamQueryClause && $tigrfamQueryClause ne "" && $ncount > 0 ) {
            MetaUtil::getAllMetaGeneFuncs( 'tigr', '', \%genes_h,
                \%gene_tigrfam_h );
            QueryUtil::fetchAllTigrfamIdNameHash( $dbh, \%tigrfam_name_h );
        }

        my %gene_ec_h;
        my %ec_name_h;
        if ( $ecQueryClause && $ecQueryClause ne "" && $ncount > 0 ) {
            MetaUtil::getAllMetaGeneFuncs( 'ec', '', \%genes_h, \%gene_ec_h );
            QueryUtil::fetchAllEnzymeNumberNameHash( $dbh, \%ec_name_h );
        }

        my %gene_ko_h;
        my %ko_name_h;
        my %ko_def_h;
        if ( $koQueryClause && $koQueryClause ne "" && $ncount > 0 ) {
            MetaUtil::getAllMetaGeneFuncs( 'ko', '', \%genes_h, \%gene_ko_h );
            QueryUtil::fetchAllKoIdNameDefHash( $dbh, \%ko_name_h, \%ko_def_h );
        }

        printEndWorkingDiv();    ### hmm... this is odd
        foreach my $workspace_id (@meta_oids) {
            my ( $taxon_oid, $data_type, $gene_oid ) =
              split( / /, $workspace_id );
            if ( !exists( $taxon_name_h{$taxon_oid} ) ) {
                next;
            }

            my (
                $locus_type,   $locus_tag, $gene_display_name,
                $start_coord,  $end_coord, $strand,
                $scaffold_oid, $tid2,      $dtype2
            );
            if ( exists( $gene_info_h{$workspace_id} ) ) {
                (
                    $locus_type,   $locus_tag, $gene_display_name,
                    $start_coord,  $end_coord, $strand,
                    $scaffold_oid, $tid2,      $dtype2
                ) = split( /\t/, $gene_info_h{$workspace_id} );
            }
            else {
                $locus_tag = $gene_oid;
            }

            if ( !$taxon_oid && $tid2 ) {
                $taxon_oid = $tid2;
                if ( !exists( $taxon_name_h{$taxon_oid} ) ) {
                    my $taxon_name =
                      QueryUtil::fetchSingleTaxonName( $dbh, $taxon_oid );
                    $taxon_name_h{$taxon_oid} = $taxon_name;
                }
            }

            my $taxon_display_name = $taxon_name_h{$taxon_oid};
            my $genome_type        = $genome_type_h{$taxon_oid};
            $taxon_display_name .= " (*)"
              if ( $genome_type eq "metagenome" );

            if ( $gene_name_h{$workspace_id} ) {
                $gene_display_name = $gene_name_h{$workspace_id};
            }
            if ( !$gene_display_name ) {
                $gene_display_name = 'hypothetical protein';
            }
            my $desc      = $gene_display_name;
            my $desc_orig = $desc;

            my $scaf_len;
            my $scaf_gc;
            my $scaf_gene_cnt;
            my $scaf_depth;
            if (   $data_type eq 'assembled'
                && $scaffold_oid
                && scalar( keys %scaffold_h ) > 0 )
            {
                my $ws_scaf_id = "$taxon_oid $data_type $scaffold_oid";
                ( $scaf_len, $scaf_gc, $scaf_gene_cnt, $scaf_depth ) =
                  split( /\t/, $scaffold_h{$ws_scaf_id} );
                if ( !$scaf_depth ) {
                    $scaf_depth = 1;
                }
                $scaf_gc = sprintf( "%.2f", $scaf_gc );
            }

            my $r;

            # iterate through the output cols:
            for ( my $i = 0 ; $i < scalar(@$outputCols_ref) ; $i++ ) {
                my $c = $outputCols_ref->[$i];
                if ( $c eq 'dna_seq_length' ) {
                    my $dna_seq_length = $end_coord - $start_coord + 1;
                    $r .= "$dna_seq_length\t";
                }
                elsif ( $c eq 'aa_seq_length' ) {
                    my $faa           = $gene_faa_h{$workspace_id};
                    my $aa_seq_length = length($faa);
                    $r .= "$aa_seq_length\t";
                }
                elsif ( $c eq 'start_coord' ) {
                    $r .= "$start_coord\t";
                }
                elsif ( $c eq 'end_coord' ) {
                    $r .= "$end_coord\t";
                }
                elsif ( $c eq 'strand' ) {
                    $r .= "$strand\t";
                }
                elsif ( $c eq 'locus_type' ) {
                    $r .= "$locus_type\t";
                }
                elsif ( $c eq 'is_public' ) {
                    my $is_public = $taxon_public_h{$taxon_oid};
                    $r .= "$is_public\t";
                }
                elsif ( $c eq 'taxon_oid' ) {
                    
                    $r .= "$taxon_oid\t";
                }

                elsif ( $c eq 'scaffold_oid' ) {
                    $r .= "$scaffold_oid\t";
                }
                elsif ( $c eq 'scaffold_name' ) {
                    $r .= "$scaffold_oid\t";
                }
                elsif ( $c eq 'seq_length' ) {
                    $r .= "$scaf_len\t";
                }
                elsif ( $c eq 'gc_percent' ) {
                    $r .= "$scaf_gc\t";
                }
                elsif ( $c eq 'read_depth' ) {
                    $r .= "$scaf_depth\t";
                }
                elsif ( $c eq 'cog_id' ) {
                    my @cog_recs;
                    my $cogs = $gene_cog_h{$workspace_id};
                    if ($cogs) {
                        @cog_recs = split( /\t/, $cogs );
                    }

                    my $cog_all;
                    foreach my $cog_id (@cog_recs) {
                        my $cog_name = $cog_name_h{$cog_id};
                        if ($cog_all) {
                            $cog_all .= "$fDelim$r";
                        }
                        $cog_all = $cog_id . $dDelim . $cog_name;
                    }
                    $r .= "$cog_all\t";

                }
                elsif ( $c eq 'pfam_id' ) {
                    my @pfam_recs;
                    my $pfams = $gene_pfam_h{$workspace_id};
                    if ($pfams) {
                        @pfam_recs = split( /\t/, $pfams );
                    }

                    my $pfam_all;
                    for my $pfam_id (@pfam_recs) {
                        my $pfam_name = $pfam_name_h{$pfam_id};
                        if ($pfam_all) {
                            $pfam_all .= "$fDelim$r";
                        }
                        $pfam_all = $pfam_id . $dDelim . $pfam_name;
                    }
                    $r .= "$pfam_all\t";

                }
                elsif ( $c eq 'tigrfam_id' ) {
                    my @tigrfam_recs;
                    my $tigrfams = $gene_tigrfam_h{$workspace_id};
                    if ($tigrfams) {
                        @tigrfam_recs = split( /\t/, $tigrfams );
                    }

                    my $tigrfam_all;
                    for my $tigrfam_id (@tigrfam_recs) {
                        my $tigrfam_name = $tigrfam_name_h{$tigrfam_id};
                        if ($tigrfam_all) {
                            $tigrfam_all .= "$fDelim$r";
                        }
                        $tigrfam_all = $tigrfam_id . $dDelim . $tigrfam_name;
                    }
                    $r .= "$tigrfam_all\t";

                }
                elsif ( $c eq 'ec_number' ) {
                    my @ec_recs;
                    my $ecs = $gene_ec_h{$workspace_id};
                    if ($ecs) {
                        @ec_recs = split( /\t/, $ecs );
                    }

                    my $ec_all;
                    for my $ec_id (@ec_recs) {
                        my $ec_name = $ec_name_h{$ec_id};
                        if ($ec_all) {
                            $ec_all .= "$fDelim$r";
                        }
                        $ec_all = $ec_id . $dDelim . $ec_name;
                    }
                    $r .= "$ec_all\t";

                }
                elsif ( $c eq 'ko_id' ) {
                    my @ko_recs;
                    my $kos = $gene_ko_h{$workspace_id};
                    if ($kos) {
                        @ko_recs = split( /\t/, $kos );
                    }

                    my $ko_all;
                    for my $ko_id (@ko_recs) {
                        my $ko_name = $ko_name_h{$ko_id};
                        my $ko_def  = $ko_def_h{$ko_id};
                        if ($ko_all) {
                            $ko_all .= "$fDelim$r";
                        }
                        $ko_all =
                          $ko_id . $dDelim . $ko_name . $dDelim . $ko_def;
                    }
                    $r .= "$ko_all\t";

                }
                else {
                    $r .= "\t";
                }
            }

            $recs{$workspace_id} = $r;
        }
    }

    #my $colIDs = $fixedColIDs;
    #foreach my $col (@$outputCols_ref) {
    #    $colIDs .= "$col,";
    #}
    #writeColIdFile($colIDs, $tool);
    return \%recs;
}

sub getGene2Cog {
    my ($dbh, $gene_oids_aref, $cogQueryClause, $gidInClause) = @_;

    my %gene2cogs;
    return \%gene2cogs if (!$cogQueryClause || $cogQueryClause eq "");

    if ( ! $gidInClause ) {
        $gidInClause = OracleUtil::getIdClause($dbh, 'gtt_num_id', '', $gene_oids_aref);        
    }
    my $cog_sql = qq{
        select distinct g.gene_oid $cogQueryClause
        from gene_cog_groups g, cog cg
        where g.gene_oid $gidInClause
        and g.cog = cg.cog_id
    };

    my $cur = execSql($dbh, $cog_sql, $verbose);
    for ( ;; ) {
    	my ($gene_oid, @colVals) = $cur->fetchrow();
    	last if !$gene_oid;
    	my $r;
    	for (my $j = 0; $j < scalar(@colVals); $j++) {
    	    if ($j != 0) {
    		$r .= "$dDelim";
    	    }
    	    $r .= "$colVals[$j]";
    	}
    	if ($gene2cogs{$gene_oid}) {
    	    $gene2cogs{$gene_oid} .= "$fDelim$r";
    	} else {
    	    $gene2cogs{$gene_oid} = $r;
    	}
    }
    $cur->finish();

    return \%gene2cogs;
}

sub getGene2Pfam {
    my ($dbh, $gene_oids_aref, $pfamQueryClause, $gidInClause) = @_;

    my %gene2pfams;
    return \%gene2pfams if (!$pfamQueryClause || $pfamQueryClause eq "");

    if ( ! $gidInClause ) {
        $gidInClause = OracleUtil::getIdClause($dbh, 'gtt_num_id', '', $gene_oids_aref);        
    }
    my $pfam_sql = qq{
        select distinct g.gene_oid $pfamQueryClause
        from gene_pfam_families g, pfam_family pf
        where g.gene_oid $gidInClause
        and g.pfam_family = pf.ext_accession
    };

    my $cur = execSql($dbh, $pfam_sql, $verbose);
    for ( ;; ) {
        my ($gene_oid, @colVals) = $cur->fetchrow();
        last if !$gene_oid;
        my $r;
        for (my $j = 0; $j < scalar(@colVals); $j++) {
            if ($j != 0) {
                $r .= "$dDelim";
            }
            $r .= "$colVals[$j]";
        }
        if ($gene2pfams{$gene_oid}) {
            $gene2pfams{$gene_oid} .= "$fDelim$r";
        } else {
            $gene2pfams{$gene_oid} = $r;
        }
    }
    $cur->finish();

    return \%gene2pfams;
}

sub getGene2Tigrfam {
    my ($dbh, $gene_oids_aref, $tigrfamQueryClause, $gidInClause) = @_;

    my %gene2tigrfams;
    return \%gene2tigrfams
	if (!$tigrfamQueryClause || $tigrfamQueryClause eq "");

    if ( ! $gidInClause ) {
        $gidInClause = OracleUtil::getIdClause($dbh, 'gtt_num_id', '', $gene_oids_aref);        
    }
    my $tigrfam_sql = qq{
        select distinct g.gene_oid $tigrfamQueryClause
        from gene_tigrfams g, tigrfam tf
        where g.gene_oid $gidInClause
        and g.ext_accession = tf.ext_accession
    };

    my $cur = execSql($dbh, $tigrfam_sql, $verbose);
    for ( ;; ) {
    	my ($gene_oid, @colVals) = $cur->fetchrow();
    	last if !$gene_oid;
    	my $r;
    	for (my $j = 0; $j < scalar(@colVals); $j++) {
    	    if ($j != 0) {
    		$r .= "$dDelim";
    	    }
    	    $r .= "$colVals[$j]";
    	}
    	if ($gene2tigrfams{$gene_oid}) {
    	    $gene2tigrfams{$gene_oid} .= "$fDelim$r";
    	} else {
    	    $gene2tigrfams{$gene_oid} = $r;
    	}
    }
    $cur->finish();

    return \%gene2tigrfams;
}

sub getGene2Ec {
    my ($dbh, $gene_oids_aref, $ecQueryClause, $gidInClause) = @_;

    my %gene2ecs;
    return \%gene2ecs if (!$ecQueryClause || $ecQueryClause eq "");

    if ( ! $gidInClause ) {
        $gidInClause = OracleUtil::OracleUtil::getIdClause($dbh, 'gtt_num_id', '', $gene_oids_aref);        
    }
    my $ec_sql = qq{
        select distinct g.gene_oid $ecQueryClause
        from gene_ko_enzymes g, enzyme ec
        where g.gene_oid $gidInClause
        and g.enzymes = ec.ec_number
    };

    my $cur = execSql($dbh, $ec_sql, $verbose);
    for ( ;; ) {
    	my ($gene_oid, @colVals) = $cur->fetchrow();
    	last if !$gene_oid;
    	my $r;
    	for (my $j = 0; $j < scalar(@colVals); $j++)  {
    	    if ($j != 0) {
    		$r .= "$dDelim";
    	    }
    	    $r .= "$colVals[$j]";
    	}
    	if ($gene2ecs{$gene_oid}) {
    	    $gene2ecs{$gene_oid} .= "$fDelim$r";
    	} else {
    	    $gene2ecs{$gene_oid} = $r;
    	}
    }
    $cur->finish();

    return \%gene2ecs;
}

sub getGene2Ko {
    my ($dbh, $gene_oids_aref, $koQueryClause, $gidInClause) = @_;

    my %gene2kos;
    return \%gene2kos if (!$koQueryClause || $koQueryClause eq "");

    if ( ! $gidInClause ) {
        $gidInClause = getIdClause($dbh, 'gtt_num_id', '', $gene_oids_aref);        
    }
    my $ko_sql = qq{
        select distinct g.gene_oid $koQueryClause
        from gene_ko_terms g, ko_term kt
        where g.gene_oid $gidInClause
        and g.ko_terms = kt.ko_id
    };

    my $cur = execSql($dbh, $ko_sql, $verbose);
    for ( ;; ) {
    	my ($gene_oid, @colVals) = $cur->fetchrow();
    	last if !$gene_oid;
    	my $r;
    	for (my $j = 0; $j < scalar(@colVals); $j++) {
    	    if ($j != 0) {
    		$r .= "$dDelim";
    	    }
    	    $r .= "$colVals[$j]";
    	}
    	if ($gene2kos{$gene_oid}) {
    	    $gene2kos{$gene_oid} .= "$fDelim$r";
    	} else {
    	    $gene2kos{$gene_oid} = $r;
    	}
    }
    $cur->finish();

    return \%gene2kos;
}

sub getGene2Term {
    my ($dbh, $gene_oids_aref, $imgTermQueryClause, $gidInClause) = @_;

    my %gene2terms;
    return \%gene2terms if (!$imgTermQueryClause || $imgTermQueryClause eq "");

    if ( ! $gidInClause ) {
        $gidInClause = OracleUtil::getIdClause($dbh, 'gtt_num_id', '', $gene_oids_aref);        
    }
    my $img_sql = qq{
        select distinct g.gene_oid $imgTermQueryClause
        from gene_img_functions g, img_term itx
        where g.gene_oid $gidInClause
        and g.function = itx.term_oid
    };

    my $cur = execSql($dbh, $img_sql, $verbose);
    for ( ;; ) {
    	my ($gene_oid, @colVals) = $cur->fetchrow();
    	last if !$gene_oid;
    	my $r;
    	for (my $j = 0; $j < scalar(@colVals); $j++) {
    	    if ($j != 0) {
    		$r .= "$dDelim";
    	    }
    	    $r .= "$colVals[$j]";
    	}
    	if ($gene2terms{$gene_oid}) {
    	    $gene2terms{$gene_oid} .= "$fDelim$r";
    	} else {
    	    $gene2terms{$gene_oid} = $r;
    	}
    }
    $cur->finish();

    return \%gene2terms;
}

sub getGene2TaxonInfo {
    my ($dbh, $gene_oids_aref, $gidInClause) = @_;

    my %gene2TaxonInfo;
    my %taxon2metaInfo;
    return (\%gene2TaxonInfo, \%taxon2metaInfo)
        if (!$gene_oids_aref || $gene_oids_aref eq "");

    if ( ! $gidInClause ) {
        $gidInClause = OracleUtil::getIdClause($dbh, 'gtt_num_id', '', $gene_oids_aref);        
    }

    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql       = qq{
        select distinct g.gene_oid, t.taxon_oid, t.taxon_display_name, 
            t.sequencing_gold_id, t.sample_gold_id, t.submission_id, t.is_public, t.analysis_project_id
        from gene g, taxon t
        where g.gene_oid $gidInClause
        and g.taxon = t.taxon_oid
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($gene_oid, $taxon_oid, $taxon_display_name, @colVals) = $cur->fetchrow();
        last if !$gene_oid;

        $gene2TaxonInfo{$gene_oid} = "$taxon_oid\t$taxon_display_name";

        if ( ! $taxon2metaInfo{$taxon_oid} ) {
            my $r;
            for (my $j = 0; $j < scalar(@colVals); $j++) {
                if ($j != 0) {
                    $r .= "\t";
                }
                $r .= "$colVals[$j]";
            }
            $taxon2metaInfo{$taxon_oid} = $r;            
        }
    }
    $cur->finish();
    #print "getGene2TaxonInfo() gene2TaxonInfo: <br/>\n";
    #print Dumper(\%gene2TaxonInfo);
    #print "<br/>\n";
    #print "getGene2TaxonInfo() taxon2metaInfo: <br/>\n";
    #print Dumper(\%taxon2metaInfo);
    #print "<br/>\n";

    return (\%gene2TaxonInfo, \%taxon2metaInfo);
}

sub getTaxon2projectMetadataInfo {
    my ($taxon2metaInfo_href) = @_;

    my %taxon_data;           # hash of hashes taxon oid => hash columns name to value
    my %goldId_data;          # gold id => hash of taxon_oid
    #my %sampleId_data;        # sample id => hash of taxon oid
    #my %submissionId_data;    # submission_id => hash of taxon_oid
    #my %taxon_public_data;    # taxon_oid => Yes or No for is public
    #my %analysisId_data;      # Ga id => taxon oid

    for my $taxon_oid (keys %$taxon2metaInfo_href) {
        my $taxon_meta_info = $taxon2metaInfo_href->{$taxon_oid};
        my ($gold_id, $sample_gold_id, $submission_id, $is_public, $analysis_project_id) = split(/\t/, $taxon_meta_info);

        #$taxon_public_data{$taxon_oid}         = $is_public;
        #$analysisId_data{$analysis_project_id} = $taxon_oid;

        my %hash;
        $taxon_data{$taxon_oid} = \%hash;
        $hash{gold_id} = $gold_id;
        if ( $gold_id ne '' ) {
            if ( exists $goldId_data{$gold_id} ) {
                my $href = $goldId_data{$gold_id};
                $href->{$taxon_oid} = 1;
            } else {
                my %h = ( $taxon_oid => 1 );
                $goldId_data{$gold_id} = \%h;
            }
        }

        #if ( $sample_gold_id ne '' ) {
        #    if ( exists $sampleId_data{$sample_gold_id} ) {
        #        my $href = $sampleId_data{$sample_gold_id};
        #        $href->{$taxon_oid} = 1;
        #    } else {
        #        my %h = ( $taxon_oid => 1 );
        #        $sampleId_data{$sample_gold_id} = \%h;
        #    }
        #}
        #
        #if ( $submission_id ne '' ) {
        #    $hash{submissionId} = $submission_id;
        #    if ( exists $submissionId_data{$submission_id} ) {
        #        my $href = $submissionId_data{$submission_id};
        #        $href->{$taxon_oid} = 1;
        #    } else {
        #        my %h = ( $taxon_oid => 1 );
        #        $submissionId_data{$submission_id} = \%h;
        #    }
        #}
            
    }

    GenomeList::getProjectMetadata( \%taxon_data, \%goldId_data);
    #print "getTaxon2projectMetadataInfo() taxon_data: <br/>\n";
    #print Dumper(\%taxon_data);
    #print "<br/>\n";
    #print "getTaxon2projectMetadataInfo() goldId_data: <br/>\n";
    #print Dumper(\%goldId_data);
    #print "<br/>\n";

    return \%taxon_data;
}

sub addColIDs {
    my ($it, $outCols_aref) = @_;
    my @outCols = @$outCols_aref;

    if (scalar(@outCols) > 0) {
        foreach my $col (@outCols) {
            next if (   $col eq 'cog_name'
		     || $col eq 'pfam_name'
		     || $col eq 'tigrfam_name'
		     || $col eq 'enzyme_name'
		     || $col eq 'ko_name'
		     || $col eq 'definition');

            my $colAlign;
            my $colName;
            my $tooltip;
            
            if ($col eq 'dna_seq_length') {
                $colName = "DNA Sequence Length<br/>(bp)";
            } elsif ($col eq 'aa_seq_length') {
                $colName = "Amino Acid Sequence Length<br/>(aa)";
            } elsif ($col eq 'cog_id') {
                $colName = "COG";
                $tooltip = 'COG ID and Name';
            } elsif ($col eq 'pfam_id') {
                $colName = "Pfam";
                $tooltip = 'Pfam ID and Name';
            } elsif ($col eq 'tigrfam_id') {
                $colName = "Tigrfam";
                $tooltip = 'Tigrfam ID and Name';
            } elsif ($col eq 'ec_number') {
                $colName = "Enzyme";
                $tooltip = 'Enzyme ID and Name';
            } elsif ($col eq 'ko_id') {
                $colName = "KO";
                $tooltip = 'KO ID, Name and Definition';
            } elsif ( GenomeList::isProjectMetadataAttr($col) ) {
                $colName = GenomeList::getProjectMetadataColName($col);                
                $colAlign = GenomeList::getProjectMetadataColAlign($col);
            } else {
                $colName = getColLabelSpecial($col);
                $colName = getColLabel($col) if ($colName eq '');
            }

            $colAlign = getColAlign($col) if ( !$colAlign );
            
            if ($colAlign eq "num asc right") {
                $it->addColSpec("$colName", "asc", "right", "", $tooltip);
            } elsif ($colAlign eq "num desc right") {
                $it->addColSpec("$colName", "desc", "right", "", $tooltip);
            } elsif ($colAlign eq "num desc left") {
                $it->addColSpec("$colName", "desc", "left", "", $tooltip);
            } elsif ($colAlign eq "char asc left") {
                $it->addColSpec("$colName", "asc", "left", "", $tooltip);
            } elsif ($colAlign eq "char desc left") {
                $it->addColSpec("$colName", "desc", "left", "", $tooltip);
            } elsif ($colAlign eq "char asc center") {
                $it->addColSpec("$colName", "asc", "center", "", $tooltip);
            } else {
                $it->addColSpec("$colName", "", "", "", $tooltip);
            }
        }
    }

    return $it;
}

############################################################################
# addCols2Row - adds the selected output column values to the row
############################################################################
sub addCols2Row {
    my ($gene_oid, $data_type, $taxon_oid, $scaffold_oid, 
    	$row, $sd, $outCols_ref, $outColVals_ref) = @_;

    my @outCols = @$outCols_ref;
    my $cols = join(",", @outCols);

    my @outColVals = @$outColVals_ref;
    my $vals = join(",", @outColVals);

    for (my $j = 0; $j < scalar(@outCols); $j++) {
    	my $col = $outCols[$j];
        next
          if (    $col eq 'cog_name'
               || $col eq 'pfam_name'
               || $col eq 'tigrfam_name'
               || $col eq 'enzyme_name'
               || $col eq 'ko_name'
        	   || $col eq 'definition' );

    	my $colVal = $outColVals[$j];

    	if ($col eq 'gc_percent' && $colVal) {
    	    $colVal = sprintf("%.2f", $colVal);
    	    $row .= $colVal . $sd . $colVal . "\t";
    	} elsif ($col eq 'read_depth' && $colVal) {
    	    $row .= $colVal . $sd . $colVal . "\t";
    	} elsif ($col eq 'scaffold_oid' && $colVal) {
    	    $scaffold_oid = $colVal;
    	    my $scaffold_url;
    	    if ($data_type eq 'database' && WebUtil::isInt($colVal)) {
        		$scaffold_url = 
        		    "$main_cgi?section=ScaffoldGraph"
        		  . "&page=scaffoldDetail&scaffold_oid=$colVal";
    	    } else {
        		$scaffold_url =
        		    "$main_cgi?section=MetaDetail"
        		  . "&page=metaScaffoldDetail&scaffold_oid=$colVal"
        		  . "&taxon_oid=$taxon_oid&data_type=$data_type";
    	    }
    	    $scaffold_url = alink($scaffold_url, $colVal);
    	    $row .= $colVal . $sd . $scaffold_url . "\t";
    
    	} elsif ($col eq 'seq_length' && $colVal) {
    	    my $scaf_len_url;
    	    if ($scaffold_oid ne '') {
        		if ($data_type eq 'database' && WebUtil::isInt($colVal)) {
        		    $scaf_len_url =
        			"$main_cgi?section=ScaffoldGraph"
        		       . "&page=scaffoldGraph&scaffold_oid=$scaffold_oid"
        		       . "&taxon_oid=$taxon_oid"
        		       . "&start_coord=1&end_coord=$colVal"
        		       . "&marker_gene=$gene_oid&seq_length=$colVal";
        		} elsif ($data_type eq 'assembled') {
        		    $scaf_len_url =
        			"$main_cgi?section=MetaScaffoldGraph"
                              . "&page=metaScaffoldGraph&scaffold_oid=$scaffold_oid"
        		      . "&taxon_oid=$taxon_oid"
        		      . "&start_coord=1&end_coord=$colVal"
        		      . "&marker_gene=$gene_oid&seq_length=$colVal";
        		}
    	    }
    	    if ($scaf_len_url ne '') {
        		$row .= $colVal . $sd . alink($scaf_len_url, $colVal) . "\t";
    	    } else {
        		$row .= $colVal . $sd . $colVal . "\t";
    	    }
    
    	} elsif ($col eq 'cog_id' && $colVal) {
    	    my $cog_all;
    	    my @cogIdNameGroups = split($fDelim, $colVal);
    	    foreach my $cogIdName (@cogIdNameGroups) {
        		my ($cogId, $cogName) = split($dDelim, $cogIdName);
        		my $cogid_url = alink($cog_base_url . $cogId, $cogId);
        		$cog_all .= $cogid_url . " - " . $cogName . "<br/><br/>";
    	    }
    	    $row .= $colVal . $sd . $cog_all . "\t";
    	} elsif ($col eq 'pfam_id' && $colVal) {
    	    my $pfam_all;
    	    my @pfamIdNameGroups = split($fDelim, $colVal);
    	    foreach my $pfamIdName (@pfamIdNameGroups) {
        		my ($pfamId, $pfamName) = split($dDelim, $pfamIdName);
        		my $pfam_id2 = $pfamId;
        		$pfam_id2 =~ s/pfam/PF/i;
        		my $pfamid_url = alink($pfam_base_url . $pfam_id2, $pfamId);
        		$pfam_all .= $pfamid_url . " - " . $pfamName . "<br/><br/>";
    	    }
    	    $row .= $colVal . $sd . $pfam_all . "\t";
    
    	} elsif ($col eq 'tigrfam_id' && $colVal) {
    	    my $tigrfam_all;
    	    my @tigrfamIdNameGroups = split($fDelim, $colVal);
    	    foreach my $tigrfamIdName (@tigrfamIdNameGroups) {
        		my ($tigrfamId, $tigrfamName) = split($dDelim, $tigrfamIdName);
        		my $tigrfamid_url = alink($tigrfam_base_url . $tigrfamId, $tigrfamId);
        		$tigrfam_all .= $tigrfamid_url . " - " . $tigrfamName . "<br/><br/>";
    	    }
    	    $row .= $colVal . $sd . $tigrfam_all . "\t";
    
    	} elsif ($col eq 'ec_number' && $colVal) {
    	    my $ec_all;
    	    my @ecIdNameGroups = split($fDelim, $colVal);
    	    foreach my $ecIdName (@ecIdNameGroups) {
        		my ($ecId, $ecName) = split($dDelim, $ecIdName);
        		my $ecid_url = alink($enzyme_base_url . $ecId, $ecId);
        		$ec_all .= $ecid_url . " - " . $ecName . "<br/><br/>";
    	    }
    	    $row .= $colVal . $sd . $ec_all . "\t";
    	} elsif ($col eq 'ko_id' && $colVal) {
    	    my $ko_all;
    	    my @koIdNameDefGroups = split($fDelim, $colVal);
    	    foreach my $koIdNameDef (@koIdNameDefGroups) {
        		my ($ko_id, $ko_name, $ko_def) = split($dDelim, $koIdNameDef);
        		my $koid_url = alink($kegg_orthology_url . $ko_id, $ko_id);
                my $koname_url =
                    "main.cgi?section=KeggPathwayDetail"
                  . "&page=keggModulePathway"
                  . "&ko_id=$ko_id&ko_name=$ko_name"
                  . "&ko_def=$ko_def&gene_oid=$gene_oid"
                  . "&taxon_oid=$taxon_oid";
        		$koname_url = alink($koname_url, $ko_name);
        		$ko_all .= $koid_url . " - " . $koname_url . "; " . $ko_def . "<br/><br/>";
    	    }
    	    $row .= $colVal . $sd . $ko_all . "\t";
    	} elsif ($col eq 'img_term' && $colVal) {
    	    my $imgterm_all;
    	    my @imgTermIdNameGroups = split($fDelim, $colVal);
    	    foreach my $imgTermIdName (@imgTermIdNameGroups) {
        		my ($imgTermId, $imgTermName) = split($dDelim, $imgTermIdName);
        		my $imgterm_url = "main.cgi?section=ImgTermBrowser" 
	                . "&page=imgTermDetail&term_oid=$imgTermId";
        		$imgterm_url = alink( $imgterm_url, $imgTermId );
        		$imgterm_all .= $imgterm_url . " - " . $imgTermName . "<br/><br/>";
    	    }
    	    $row .= $colVal . $sd . $imgterm_all . "\t";
        } elsif ( GenomeList::isProjectMetadataAttr($col) ) {
            #print "addCols2Row() col=$col colVal=$colVal<br/>\n";
            if ( $colVal eq '' || blankStr($colVal) ) {
                my $tmp = GenomeList::getProjectMetadataColAlign($col);
                if ( $tmp =~ /^char/ ) {
                    $row .= 'zzz' . $sd . '_' . "\t";
                } else {
                    $row .= '0' . $sd . '_' . "\t";
                }
            } elsif ( GenomeList::getColAsUrl($col) ) {
                my $url;
                if ( $col eq 'p.gold_stamp_id' ) {
                    # Gs or Gp
                    $url = HtmlUtil::getGoldUrl($colVal);
                    $url = "<a href='$url'>$colVal</a>";                    
                }
                else {
                    $url = GenomeList::getColAsUrl($col) . $colVal;
                    $url = alink( $url, $colVal );                    
                }
                $row .= $colVal . $sd . $url . "\t";
            } else {
                $row .= $colVal . $sd . $colVal . "\t";
            }
    	} else {
    	    $colVal = nbsp(1) if !$colVal;
    	    $row .= $colVal . $sd . $colVal . "\t";
    	}
    }

    return $row;
}

sub readColIdFile {
    my ($tool) = @_;
    my $colIDs = "";
    my $res = newReadFileHandle(getFile("colid", $tool), "runJob", 1);
    if ($res) {
        my $line = $res->getline();
        chomp $line;
        $colIDs = $line;
        close $res;
    }
    return $colIDs;
}

sub writeColIdFile {
    my ($colIDs, $tool) = @_;
    if ($colIDs eq "") {
        wunlink(getFile("colid", $tool)); # remove col id file
    } else {
        my $res = newWriteFileHandle(getFile("colid", $tool), "runJob", 1);
        if ($res) {
            print $res "$colIDs\n";
            close $res;
        }
    }
}

sub getFile {
    my ($fileNameEnd, $tool) = @_;
    my ($cartDir, $sessionId) = WebUtil::getCartDir();
    my $sessionFile = "$cartDir/$tool.$sessionId." . $fileNameEnd;
    return $sessionFile;
}



1;
