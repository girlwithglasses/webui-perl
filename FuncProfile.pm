############################################################################
# FuncProfile.pm - Functional profile with gene counts.
#  Actually, genomes vs. functions (i.e., COG, Pfam, etc.).
#  This is a generic module to be used in COG, Pfam, TIGRfam, Enzyme
#  carts  for  "genome vs. function" profiles.
#    --es 09/04/2005
#  Expected the following input records (tab delimited separator):
#    0: taxon_oid/bin_oid
#    1: taxon_name/bin_display_name
#    2: id
#    3: gene_count
#
# $Id: FuncProfile.pm 31256 2014-06-25 06:27:22Z jinghuahuang $
############################################################################
package FuncProfile;
my $section = "FuncProfile";
use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use MerFsUtil;
use HtmlUtil;
use ProfileUtil;

my $env = getEnv( );
my $img_internal = $env->{ img_internal };
my $img_lite = $env->{ img_lite };
my $img_er = $env->{ img_er };
#my $use_gene_priam = $env->{ use_gene_priam };
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $yui_tables = $env->{ yui_tables }; # flag for  YUI tables +BSJ 03/04/10

my $in_file = $env->{in_file};
my $mer_data_dir   = $env->{mer_data_dir};

my $max_gene_batch = 250;

my $verbose = $env->{ verbose };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "funcProfileGenes" ) {
       my $type = param( "type" );
       my $procId = param( "procId" );
       my $pp = new FuncProfile( $type, $procId );
       $pp->printProfileGenes( );
    }
    elsif( $page eq "orthologGenes" ) {
       my $type = param( "type" );
       my $procId = param( "procId" );
       my $pp = new FuncProfile( $type, $procId );
       $pp->printOrthologGenes( );
    }
    else {
       webLog( "FuncProfile::dispatch: invalid page='$page'\n" );
       warn( "FuncProfile::dispatch: invalid page='$page'\n" );
    }
}

############################################################################
# new - New instance of this object.
############################################################################
sub new {
   my( $myType, $type, $procId, $baseUrl, $sortBaseUrl,
       $taxonBinOids_ref, $taxonBinOid2Name_ref,  $taxonBinOid2Domain_ref, $data_type, 
       $colIds_ref, $colId2Name_ref, $recs_ref, $colorMap_ref,
       $taxon_cell_sql_template, $bin_cell_sql_template, $znorm ) = @_;

   my $self = { };
   bless( $self, $myType );
   my $stateFile = $self->getStateFile( $type, $procId );
   if( param( "sortIdx" ) ne "" && !-e( $stateFile ) ) {
       webError( "Phylogenetic profile session expired. " .
         "Please start over again." );
   }
   if( -e $stateFile ) {
       webLog "retrieve '$stateFile'\n" if $verbose >= 1;
       $self = retrieve( $stateFile );
   }
   else {
       webLog "new FuncProfile\n" if $verbose >= 1;
       $self->{ type } = $type;
       $self->{ procId } = $procId;
       $self->{ baseUrl } = $baseUrl;
       $self->{ sortBaseUrl } = $sortBaseUrl;
       $self->{ taxonBinOids } = $taxonBinOids_ref;
       $self->{ taxonBinOid2Name } = $taxonBinOid2Name_ref;
       $self->{ taxonBinOid2Domain } = $taxonBinOid2Domain_ref;
       $self->{ data_type } = $data_type;
       $self->{ colIds } = $colIds_ref;
       $self->{ colId2Name } = $colId2Name_ref;
       $self->{ recs } =  $recs_ref;
       $self->{ colorMap } = $colorMap_ref;
       $self->{ taxon_cell_sql_template } = $taxon_cell_sql_template;
       $self->{ bin_cell_sql_template } = $bin_cell_sql_template;
       $self->{ znorm } = $znorm;
       $self->process( );
   }
   bless( $self, $myType );
   $self->save( );
   return $self;
}

###########################################################################
# getStateFile - Get state file for persistence.
############################################################################
sub getStateFile {
   my( $self, $type, $procId ) = @_;
   my $sessionId = getSessionId( );
   my $stateFile = "$cgi_tmp_dir/funcProfile.$sessionId.$type.$procId.stor";
   webLog "stateFile='$stateFile'\n";
   return $stateFile;
}

############################################################################
# save - Save in persistent state.
############################################################################
sub save {
   my( $self ) = @_;
   my $type = $self->{ type };
   my $procId = $self->{ procId };
   store( $self, checkTmpPath( $self->getStateFile( $type, $procId ) ) );
}

############################################################################
# printSortHeaderLink - Print sorted header link.
############################################################################
sub printSortHeaderLink {
   my( $self, $name, $sortIdx, $mouseOverName ) = @_;

   my $linkTarget = $WebUtil::linkTarget;
   my $sortBaseUrl = $self->{ sortBaseUrl };
   my $type = $self->{ type };
   my $procId = $self->{ procId };
   my $url = $sortBaseUrl;
   $url .= "&type=$type";
   $url .= "&procId=$procId";
   $url .= "&sortIdx=$sortIdx";
   print "<th class='img'>";
   my $target;
   $target = "target='$linkTarget'" if $linkTarget ne "";
   my $title;
   $mouseOverName =~ s/'//g;
   $title = "title='$mouseOverName'" if $mouseOverName ne "";
   if($name =~ /^MetaCyc:/ && $mouseOverName ne "") {
      # metacyc
      my( $db, $intId ) = split(/:/, $name);
      $name = "$db:<br/>$intId";
   } elsif( $name =~ /^[a-zA-Z]+/ && $mouseOverName ne "" ) {
      $_ = $name;
      my( $db, $intId ) = /([a-zA-Z:]+)([0-9\.]+)/;
      $intId =~ s/\./<br\/>/g;
      $name = "$db<br/>$intId";
   }
   print "<a href='$url' $target $title>$name</a>";
   print "</th>\n";
}

############################################################################
# sortedRecsArray - Return sorted records array.
#   sortIdx - is column index to sort on, starting from 0.
############################################################################
sub sortedRecsArray {
    my( $self, $sortIdx, $outRecs_ref ) = @_;
    my $rows = $self->{ matrixRows };
    my @a;
    my @idxVals;
    my %recs;
    for my $r( @$rows ) {
       my @fields = split( /\t/, $r );
       my $id = $fields[ 0 ];
       $recs{ $id } = $r;
       my $sortRec;
       my $sortFieldVal = $fields[ $sortIdx ];
       $sortFieldVal = sprintf( "%.2f", $sortFieldVal ) if $sortIdx > 1;
           # handle empty values
       if( $sortIdx > 2 ) {
          $sortRec = sprintf( "%s\t%s", $sortFieldVal, $id );
       }
       ## Domain subsort
       elsif( $sortIdx == 2 ) {
	  my $subSortVal = $fields[ 1 ];
          $sortRec = sprintf( "%s.%s\t%s", $sortFieldVal, $subSortVal, $id );
       }
       else {
          $sortRec = sprintf( "%s\t%s", $sortFieldVal, $id );
       }
       push( @idxVals, $sortRec );
    }
    my @idxValsSorted;
    @idxValsSorted = sort( @idxVals ) if $sortIdx <= 2;
    @idxValsSorted = reverse( sort{ $a <=> $b }( @idxVals ) ) if $sortIdx > 2;
    for my $i( @idxValsSorted ) {
       my( $idxVal, $id ) = split( /\t/, $i );
       my $r = $recs{ $id };
       push( @$outRecs_ref, $r );
    }
}

############################################################################
# process - Process input arguments and store matrix data.
############################################################################
sub process {
   my( $self ) = @_;
   my $dbh = dbLogin( );

   ## Get the row ID's and hash for cell lookups.
   my $recs = $self->{ recs };
   my %cells;
   for my $r( @$recs ) {
      my( $taxon_bin_oid, $taxon_bin_name, $id, $gene_count ) =
         split( /\t/, $r );
      my $cellId = "$taxon_bin_oid\t$id";
      $cells{ $cellId } = $r;
   }
   my $rowIds = $self->{ rowIds };
   my $rowId2Name = $self->{ rowId2Name };
   $self->{ cells } = \%cells;

   my $taxonBinOids = $self->{ taxonBinOids };
   my $taxonBinOid2Name = $self->{ taxonBinOid2Name };
   my $taxonBinOid2Domain = $self->{ taxonBinOid2Domain };
   my $colIds = $self->{ colIds };
   my $colId2Name = $self->{ colId2Name };

   ## Order in terms of matrix rows.
   my @matrixRows;
   my $count = 0;
   if ($colIds ne '' && defined($colIds) ) {
        @$colIds = sort @$colIds;  #sort the order that columns are displayed +BSJ 06/15/10       
   }
   for my $taxonBinOid( @$taxonBinOids ) {
      $count++;
      my $taxonBinName = $taxonBinOid2Name->{ $taxonBinOid };
      my $domain = $taxonBinOid2Domain->{ $taxonBinOid };
      my $r = "$taxonBinOid\t";
      $r .= "$taxonBinName\t";
      $r .= "$domain\t";
      for my $colId( @$colIds ) {
	 my $colName = $colId2Name->{ $colId };
	 my $cellId = "$taxonBinOid\t$colId";
	 my $cell = $cells{ $cellId };
	 my( $taxon_bin_oid, $taxon_bin_name, $id, $gene_count ) =
	    split( /\t/, $cell );
	 $r .= "$id\t";
	 $r .= "$gene_count\t";
      }
      push( @matrixRows, $r );
   }
   $self->{ matrixRows } = \@matrixRows;

   #$dbh->disconnect();
   $self->save( );
}

############################################################################
# printProfile - Show profile matrix.
############################################################################
sub printProfile {
    my( $self ) = @_;
    print qq{
	<script language='JavaScript' type='text/javascript'>
	function showView(type) {
	    if (type == 'slim') {
		document.getElementById('fullView').style.display = 'none';
		document.getElementById('slimView').style.display = 'block';
	    } else {
		document.getElementById('fullView').style.display = 'block';
		document.getElementById('slimView').style.display = 'none';
	    }
	}
        </script>
    };

    print "<div id='fullView' style='display: block;'>";
    $self->writeDiv("full");
    print "</div>\n";

    print "<div id='slimView' style='display: none;'>";
    $self->writeDiv("slim");
    print "</div>\n";
}

############################################################################
# writeDiv - writes out the table html for either the full or the slim view
############################################################################
sub writeDiv {
    my( $self, $which ) = @_;

    my $baseUrl = $self->{ baseUrl };
    my $type = $self->{ type };
    my $taxonBinOids = $self->{ taxonBinOids };
    my $taxonBinOid2Name =$self->{ taxonBinOid2Name };
    my $data_type = $self->{data_type};
    my $cells = $self->{ cells };
    my $matrixRows = $self->{ matrixRows };
    my $colorMap = $self->{ colorMap };
    my $colIds = $self->{ colIds };
    my $colId2Name = $self->{ colId2Name };
    my $procId = $self->{ procId };
    my $znorm = $self->{ znorm };
    my $orthologData = $self->{ orthologData };

    my $contact_oid = getContactOid( );
    my $dbh = dbLogin( );
    my $isEditor = canEditGeneTerm( $dbh, $contact_oid );

    my $s = "Mouse over function ID to see name.<br/>\n";
    if ($which eq "slim") {
        $s = "Mouse over column number to see function name.<br/>\n";
    }
    if( $znorm ) {
       $s .= "(Cell coloring is highlighting of z-scores (floored at 0): ";
       $s .= "white = 0, <span style='background-color:bisque'>bisque</span> = 1-4,
                         <span style='background-color:yellow'>yellow</span> >= 5.)<br/>\n";
    } else {
       $s .= "(Cell coloring is highlighting of gene counts: ";
       $s .= "white = 0, <span style='background-color:bisque'>bisque</span> = 1-4,
                         <span style='background-color:yellow'>yellow</span> >= 5.)<br/>\n";
    }

    if( defined( $orthologData ) ) {
        $s .= "Ortholog gene count is shown in parentheses.<br/>\n";
    }
    $s .= "Click on column name to sort.<br/>\n";
    printHint( $s );

    if ($which eq "full") {
        print "<p>\n";
        print domainLetterNote( 1 ) . "<br/>\n";
        print "</p>\n";
        print "<input type='button' class='medbutton' name='view'"
            . " value='Show Slim View'"
            . " onclick='showView(\"slim\")' />";
    } elsif ($which eq "slim") {
        print "<input type='button' class='medbutton' name='view'"
            . " value='Show Full View'"
            . " onclick='showView(\"full\")' />";
    }

#### BEGIN updated table using InnerTable +BSJ 03/03/10

    my $it = new InnerTable( 1, "Function$which$$", "Function$which", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter

    $it->addColSpec( "Genome", "char asc" );
    if ($which eq "full") {
        $it->addColSpec( "Domain", "char asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    }
    my $count = 0;

    for my $colId( @$colIds ) {
        $count++;
        my $colName = $colId2Name->{ $colId };
        my $colId2 = $colId;
        if ($which eq "slim") {
            $colId2 = $count;
        }
        #webLog("$colId2,  2*$count+2  $colId - $colName\n");
        $it->addColSpec( $colId2, "char desc", "right", "", "$colId - $colName" );
    }

    my @sortedRecs;
    my $sortIdx = param( "sortIdx" );
    $sortIdx = 1 if $sortIdx eq "";
    $self->sortedRecsArray( $sortIdx, \@sortedRecs );

    my $nSortedRecs = @sortedRecs;
    my $vPadding = ($yui_tables) ? 4 : 0;  # YUI tables look better with more vertical padding +BSJ 03/03/10

    my @all_taxon_oids;
    for my $r( @sortedRecs ) {
        my( $taxonBinOid, $taxonBinName, $domain, @funcGeneCount ) =
            split( /\t/, $r );
        my( $t, $taxonBinOid2 ) = split( /:/, $taxonBinOid );
        push( @all_taxon_oids, $taxonBinOid2 );
    }

    ## get MER-FS taxons
    my %mer_fs_taxons;
    if ( $in_file ) {
        %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile($dbh, @all_taxon_oids);
    } 

    for my $r( @sortedRecs ) {
        my( $taxonBinOid, $taxonBinName, $domain, @funcGeneCount ) =
            split( /\t/, $r );
        my $taxonBinOid2 = $taxonBinOid;
        my( $t, $taxonBinOid2 ) = split( /:/, $taxonBinOid );
        my $url = "$main_cgi?section=TaxonDetail" .
            "&page=taxonDetail&taxon_oid=$taxonBinOid2";
        $url = "$main_cgi?section=Metagenome" .
            "&page=binDetail&bin_oid=$taxonBinOid2" if $t eq "b";

        if ( $t eq "t" && $mer_fs_taxons{$taxonBinOid2} ) {
    	    $url = "$main_cgi?section=MetaDetail" .
    	        "&page=metaDetail&taxon_oid=$taxonBinOid2";
    	    $taxonBinName .= " (MER-FS)";
            if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                $taxonBinName .= " ($data_type)";
            }
        }

        my $n2 = @$colIds;

        my $row;

        if ($which eq "slim") {
            # first check if the row is empty in which
            # case it will not be displayed in slim view
            my $found = 0;
            for( my $i = 0; $i < $n2; $i++ ) {
                my $id = $funcGeneCount[ $i*2 ];
                my $colId = $colIds->[ $i ];
                my $gene_count = $funcGeneCount[ $i*2 + 1 ];
                if ( $gene_count > 0 ) {
                    $found = 1;
                    last;
                }
            }
            next if (!$found);
	        $row .= $taxonBinName . $sd . alink( $url, $taxonBinName ) . "\t";
        } else {
	        $row .= $taxonBinName . $sd . alink( $url, $taxonBinName ) . "\t";
	        $row .= $domain . $sd . $domain . "\t";
        }

        my $sortIdx2 = $sortIdx + 1;
        my $url = "$section_cgi&page=funcProfileGenes";
        $url .= "&type=$type";
        $url .= "&procId=$procId";
        if( $t eq "b" ) {
            $url .= "&bin_oid=$taxonBinOid2";
        }
        else {
            $url .= "&taxon_oid=$taxonBinOid2";
        }

        if ( $t eq "t" && $mer_fs_taxons{$taxonBinOid2} ) {
    	    $url = "$main_cgi?section=MetaDetail&taxon_oid=$taxonBinOid2&data_type=$data_type";
        }

      for( my $i = 0; $i < $n2; $i++ ) {
          my $id = $funcGeneCount[ $i*2 ];
    	  my $colId = $colIds->[ $i ];
    	  my $gene_count = $funcGeneCount[ $i*2 + 1 ];
          my $url2 = "$url&id=$id";
    
    	  if ( $t eq "t" && $mer_fs_taxons{$taxonBinOid2} ) {
    	      if ( $id =~ /COG/ ) {
        		  $url2 = $url . "&page=cogGeneList&cog_id=$id";
    	      }
    	      elsif ( $id =~ /pfam/ ) {
        		  $url2 = $url . "&page=pfamGeneList&ext_accession=$id";
    	      }
    	      elsif ( $id =~ /TIGR/ ) {
        		  $url2 = $url . "&page=tigrfamGeneList&ext_accession=$id";
    	      }
    	      elsif ( $id =~ /KO/ ) {
        		  $url2 = $url . "&page=koGenes&koid=$id";
    	      }
    	      elsif ( $id =~ /EC/ ) {
        		  $url2 = $url . "&page=enzymeGeneList&ec_number=$id";
    	      }
              elsif ( $id =~ /BC/ ) { 
                  my $url0 = "$main_cgi?section=BiosyntheticDetail&taxon_oid=$taxonBinOid2&data_type=$data_type";
                  $url2 = $url0 . "&page=biosynthetic_genes&func_id=$id";
              }
              elsif ( $id =~ /MetaCyc/ ) { 
                  $url2 = $url . "&page=metaCycGenes&func_id=$id";
              }
    	      else {
        		  $url2 = "";
    	      }
          }

    	  my $od = showOrthologCounts( $self, $colId, $taxonBinOid );
          if( $gene_count == 0 || $gene_count eq "" ) {
    	      if( (($img_er && $colId =~ /ITERM:/ && $isEditor) ||
    		   #($use_gene_priam && $colId =~ /EC:/)) &&
    		   ($colId =~ /EC:/)) 
    		   && $t ne "b" ) {
        		  my $taxon_oid = $taxonBinOid2;
        		  my $url = "$main_cgi?section=MissingGenes";
        		  $url .= "&page=candidatesForm";
        		  $url .= "&taxon_oid=$taxon_oid";
        		  $url .= "&funcId=$colId";
        		  my $otherTaxonOids;
        		  for my $taxon_oid2( @all_taxon_oids ) {
        		      next if $taxon_oid2 eq $taxon_oid;
        		      $otherTaxonOids .= "$taxon_oid2,";
        		  }
        		  chop $otherTaxonOids;
        		  $url .= "&otherTaxonOids=$otherTaxonOids";
        		  $url .= "&procId=$procId";
        		  $url .= "&fromPm=FuncProfile";
        		  my $link = alink( $url, "0" );
        		  $row .= "0" . $sd;
        		  $row .= "<span style='padding:${vPadding}px 10px;'>";
        		  $row .= "$link$od</span>\t";
	          }
    	      else {
        		  $row .= "0" . $sd;
        		  $row .= "<span style='padding:${vPadding}px 10px;'>";
        		  $row .= "0$od</span>\t";
    	      }
          }
          else {
    	      my $colorClause;
    	      for my $c( @$colorMap ) {
    	          my( $lo, $hi, $color ) = split( /:/, $c );
    	          if( $lo <= $gene_count && $gene_count < $hi ) {
    	              #$colorClause = "bgcolor='$color'";          # -BSJ 03/03/10
    	              $colorClause = $color; # updated for YUI tables +BSJ 03/03/10
    		          last;
    	          }
    	       }
    
    	       $row .= $gene_count . $sd . "<span style='background-color:$colorClause; padding:${vPadding}px 10px;'>";
    	       if ( $url2 ) {
                   if ( $mer_fs_taxons{$taxonBinOid2} && $id =~ /MetaCyc:/ ) {
                       $row .= "<= ";
                   }
        		   $row .= alink( $url2, $gene_count );
                   $row .= "$od</span>\t";
    	       }
    	       else {
        		   $row .= $gene_count . "$od</span>\t";
    	       }
           }
        }
        $it->addRow($row);
    }
   $it->printOuterTable(1);

   if ($which eq "slim") {
       print "<br/>\n";
       # write a table legend column id:name

       my $it;
       my $sd;

       # This will be the 3rd table on this page. InnerTable_old supports only 2 tables
       # So render this table as plain HTML if not using Yahoo Tables +BSJ 03/04/10
       if ($yui_tables) {
    	   $it = new InnerTable( 1, "TableLegend$$", "TableLegend", 0);
    	   $sd = $it->getSdDelim();    # sort delimiter
    	   $it->addColSpec("Column ID", "number asc", "right");
    	   $it->addColSpec("Column Name", "char asc");
       } else {
    	   print "<table class='img' border='0'>\n";
    	   print "<th class='img' >Column ID</th>";
    	   print "<th class='img' >Column Name</th>";
       }

       my $count = 0;
       for my $colId( @$colIds ) {
           my $row;
    	   $count++;
    	   my $colName = $colId2Name->{ $colId };
    	   $row .= $sd . $count . "\t";
    	   $row .= $sd . "$colId - $colName" . "\t";

    	   if ($yui_tables) {
    	       $it->addRow($row);
    	   } else {
    	       print "<tr class='img'>\n";
    	       print "<td class='img' align='right'>$count</td>\n";
    	       print "<td class='img'>$colId - $colName</td>\n";
    	       print "</tr>\n";
     	   }
        }

        if ($yui_tables) {
    	    if ($count > 20 ) { # Show pagination only if there are more than 20 rows +BSJ 03/05/10
    	        $it->printOuterTable(1);
    	    } else {
    	        $it->printOuterTable("nopage");
    	    }
        } else {
    	    print "</table>\n";
        }
    }

#### END updated table using InnerTable +BSJ 03/03/10

    #$dbh->disconnect();
    $self->save( );
}

############################################################################
# printProfileGenes - Print profile count genes.
############################################################################
sub printProfileGenes {
    my( $self ) = @_;

    my $taxon_sql = $self->{taxon_cell_sql_template};
    my $bin_sql   = $self->{bin_cell_sql_template};

    ProfileUtil::printProfileGenes( $taxon_sql, $bin_sql );    
}

############################################################################
# showOrthologCounts - Get counts for orthologs.
############################################################################
sub showOrthologCounts {
   my( $self, $funcId, $taxonBinOid ) = @_;

   my $type = $self->{ type };
   my $procId = $self->{ procId };

   my $orthologData = $self->{ orthologData };
   return "" if !defined( $orthologData );

   my $k = "$funcId,$taxonBinOid";
   my $genes = $orthologData->{ $k };
   my @keys = keys( %$genes );
   my $nGenes = @keys;
   return "(0)" if $nGenes == 0;

   my $url = "$section_cgi&page=orthologGenes";
   $url .= "&type=$type&procId=$procId";
   $url .= "&funcId=$funcId&taxonBinOid=$taxonBinOid";
   my $s = "(" . alink( $url, $nGenes ) . ")";
   return $s;
}

############################################################################
# printOrthologGenes - Show list of ortholog genes.
############################################################################
sub printOrthologGenes {
    my( $self ) = @_;

    my $funcId = param( "funcId" );
    my $taxonBinOid = param( "taxonBinOid" );

    my $orthologData = $self->{ orthologData };
    return "" if !defined( $orthologData );

    my $k = "$funcId,$taxonBinOid";
    my $genes = $orthologData->{ $k };
    my @gene_oids = sort( keys( %$genes ) );

    my $count = scalar(@gene_oids);
    if( $count == 1 ) {
        use GeneDetail;
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm( );
    print "<h1>Ortholog Genes</h1>\n";
    print "<p>\n";

    printGeneCartFooter() if ( $count > 10 );
    my $dbh = dbLogin( );
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form( );
}

1;
