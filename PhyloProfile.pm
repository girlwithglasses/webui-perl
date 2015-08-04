############################################################################
# PhyloProfile.pm - Phylogenetic profile matrix with gene counts.
#   Actually, functions vs. genomes. ("Function" are COG's, Pfam's,
#   enzymes, TIGRfams, etc.)  This is a generic module for handling
#   various function carts in terms of profiling.
#    --es 09/04/2005
#  Expected the following input records (tab delimited separator):
#    0: row id
#    1: row name
#    2: taxon_oid
#    3: bin_oid
#    4: gene_count
#
# $Id: PhyloProfile.pm 31915 2014-09-16 19:47:02Z jinghuahuang $
############################################################################
package PhyloProfile;
my $section = "PhyloProfile";
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

my $env          = getEnv();
my $img_internal = $env->{img_internal};
my $img_lite     = $env->{img_lite};
my $img_er       = $env->{img_er};

my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $tmp_dir     = $env->{tmp_dir};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};

my $in_file = $env->{in_file}; 
my $mer_data_dir   = $env->{mer_data_dir};

my $max_gene_batch = 250;

my $verbose = $env->{verbose};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq "phyloProfileGenes" ) {
        my $type   = param("type");
        my $procId = param("procId");
        my $pp     = new PhyloProfile( $type, $procId );
        $pp->printProfileGenes();
    } elsif ( $page eq "orthologGenes" ) {
        my $type   = param("type");
        my $procId = param("procId");
        my $pp     = new PhyloProfile( $type, $procId );
        $pp->printOrthologGenes();
    } else {
        webLog("PhyloProfile::dispatch: invalid page='$page'\n");
        warn("PhyloProfile::dispatch: invalid page='$page'\n");
    }
}

############################################################################
# new - New object instance.
############################################################################
sub new {
    my ( $myType, $type, $procId, $idLabel, $nameLabel, $baseUrl,
	    $sortBaseUrl, $rowIds_ref, $rowId2Name_ref,
        $taxon_oids_ref, $bin_oids_ref, $data_type, $recs_ref, $colorMap_ref,
	    $taxon_cell_sql_template, $bin_cell_sql_template, $znorm )
        = @_;

    my $self = {};
    bless( $self, $myType );
    my $stateFile = $self->getStateFile( $type, $procId );
    if ( param("sortIdx") ne "" && !-e ($stateFile) ) {
        webError( "Phylogenetic profile session expired. " 
		. "Please start over again." );
    }
    if ( -e $stateFile ) {
        webLog "retrieve '$stateFile'\n" if $verbose >= 1;
        $self = retrieve($stateFile);
    } else {
        webLog "new PhyloProfile\n" if $verbose >= 1;
        $self->{type}                    = $type;
        $self->{procId}                  = $procId;
        $self->{idLabel}                 = $idLabel;
        $self->{nameLabel}               = $nameLabel;
        $self->{baseUrl}                 = $baseUrl;
        $self->{sortBaseUrl}             = $sortBaseUrl;
        $self->{rowIds}                  = $rowIds_ref;
        $self->{rowId2Name}              = $rowId2Name_ref;
        $self->{taxon_oids}              = $taxon_oids_ref;
        $self->{bin_oids}                = $bin_oids_ref;
        $self->{data_type}               = $data_type;
        $self->{recs}                    = $recs_ref;
        $self->{colorMap}                = $colorMap_ref;
        $self->{taxon_cell_sql_template} = $taxon_cell_sql_template;
        $self->{bin_cell_sql_template}   = $bin_cell_sql_template;
        $self->{znorm}                   = $znorm;
        $self->process();
    }
    bless( $self, $myType );
    $self->save();
    return $self;
}

############################################################################
# getStateFile - Get state file for persistence.
############################################################################
sub getStateFile {
    my ( $self, $type, $procId ) = @_;
    my $sessionId = getSessionId();
    my $stateFile = "$cgi_tmp_dir/phyloProfile.$sessionId.$type.$procId.stor";
    webLog "stateFile='$stateFile'\n";
    return $stateFile;
}

############################################################################
# save - Save in persistent state.
############################################################################
sub save {
    my ($self) = @_;
    my $type   = $self->{type};
    my $procId = $self->{procId};
    store( $self, checkTmpPath( $self->getStateFile( $type, $procId ) ) );
}

############################################################################
# printSortHeaderLink - Print sorted header link.
############################################################################
sub printSortHeaderLink {
    my ( $self, $name, $sortIdx, $mouseOverName ) = @_;

    my $linkTarget  = $WebUtil::linkTarget;
    my $sortBaseUrl = $self->{sortBaseUrl};
    my $type        = $self->{type};
    my $procId      = $self->{procId};
    my $url         = $sortBaseUrl;
    $url .= "&type=$type";
    $url .= "&procId=$procId";
    $url .= "&sortIdx=$sortIdx";
    print "<th class='img'>";
    my $target;
    $target = "target='$linkTarget'" if $linkTarget ne "";
    my $title;
    $mouseOverName =~ s/'//g;
    $title = "title='$mouseOverName'" if $mouseOverName ne "";
    print "<a href='$url' $target $title>$name</a>";
    print "</th>\n";
}

############################################################################
# printTooltipCell
############################################################################
sub printTooltipCell {
    my ( $self, $id, $mouseOverName ) = @_;
    webLog("\nANNA: $id : $mouseOverName\n");

    $mouseOverName =~ s/'//g;
    my $title = "title='$mouseOverName'" if $mouseOverName ne "";
    my $cell = "<a $title style='cursor: default';>$id</a>";

    return $cell;
}

############################################################################
# sortedRecsArray - Return sorted records array.
#   sortIdx - is column index to sort on, starting from 0.
############################################################################
sub sortedRecsArray {
    my ( $self, $sortIdx, $outRecs_ref ) = @_;
    my $rows = $self->{matrixRows};
    my @a;
    my @idxVals;
    my %recs;
    for my $r (@$rows) {
        my @fields = split( /\t/, $r );
        my $id = $fields[0];
        $recs{$id} = $r;
        #print "PhyloProfile::writeDiv() sortedRecsArray id: $id; r: $r<br/>\n";

        my $sortRec;
        my $sortFieldVal = $fields[$sortIdx];
        $sortFieldVal = sprintf( "%.2f", $sortFieldVal ) if $sortIdx > 1;

        # handle empty values
        $sortRec = sprintf( "%s\t%s", $sortFieldVal, $id );
        push( @idxVals, $sortRec );
    }
    my @idxValsSorted;
    @idxValsSorted = sort(@idxVals) if $sortIdx <= 1;
    @idxValsSorted = reverse( sort { $a <=> $b } (@idxVals) ) if $sortIdx > 1;
    for my $i (@idxValsSorted) {
        my ( $idxVal, $id ) = split( /\t/, $i );
        my $r = $recs{$id};
        push( @$outRecs_ref, $r );
    }
}

############################################################################
# process - Process input arguments and store matrix data.
############################################################################
sub process {
    my ($self) = @_;
    my $dbh = dbLogin();

    ## First order taxon phylogenetically for columns.
    my @taxonsOrdered;
    my $taxon_oids_ref = $self->{taxon_oids};
    my $taxon_oid_str = '';
    if ($taxon_oids_ref ne '' && defined($taxon_oids_ref)) {
        $taxon_oid_str = join( ',', @$taxon_oids_ref );        
    }
    if ( !blankStr($taxon_oid_str) ) {
        my $sql = qq{
          select tx.taxon_oid, tx.taxon_display_name
          from taxon tx
          where tx.taxon_oid in( $taxon_oid_str )
          order by tx.domain, tx.phylum, tx.ir_class, tx.ir_order,
            tx.family, tx.genus, tx.taxon_display_name
        };
        #print "PhyloProfile::process() taxon_oid_str sql: $sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
            last if !$taxon_oid;
            my $r = "$taxon_oid\t";
            $r .= "$taxon_display_name\t";
            push( @taxonsOrdered, $r );
        }
        $cur->finish();
    }

    # sort the array by name (subscript 1) +BSJ 03/03/10
    @taxonsOrdered = sort {
        my @first  = split( /\t/, $a );
        my @second = split( /\t/, $b );
        $first[1] cmp $second[1];
    } @taxonsOrdered;

    $self->{taxonsOrdered} = \@taxonsOrdered;

    ## Do same for bins.
    my @binsOrdered;
    my $bin_oids_ref = $self->{bin_oids};
    my $bin_oid_str = '';
    if ($bin_oid_str ne '' && defined($bin_oid_str)) {
        $bin_oid_str = join( ',', @$bin_oids_ref );
    }
    if ( !blankStr($bin_oid_str) ) {
        my $sql = qq{
          select b.bin_oid, b.display_name, es.sample_display_name
          from bin b, env_sample_gold es
          where b.bin_oid in( $bin_oid_str )
	      and b.env_sample = es.sample_oid
          order by b.display_name
        };
        #print "PhyloProfile::process() bin_oid_str sql: $sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $bin_oid, $bin_display_name, $es_display_name ) 
		= $cur->fetchrow();
            last if !$bin_oid;
            my $r = "$bin_oid\t";
            $r .= "$bin_display_name ($es_display_name)\t";
            push( @binsOrdered, $r );
        }
        $cur->finish();
    }

    # sort the array by name (subscript 1) +BSJ 03/03/10
    @binsOrdered = sort {
        my @first  = split( /\t/, $a );
        my @second = split( /\t/, $b );
        $first[1] cmp $second[1];
    } @binsOrdered;

    $self->{binsOrdered} = \@binsOrdered;

    ## Get the row ID's and hash for cell lookups.
    my $recs = $self->{recs};
    my %cells;
    for my $r (@$recs) {
        my ( $id, $name, $taxon_oid, $bin_oid, $gene_count )
	    = split( /\t/, $r );
        my $cellId = "$id\t$taxon_oid\t$bin_oid";
        $cells{$cellId} = $r;
        #print "PhyloProfile::process() recs $cellId: $r<br/>\n";
    }
    my $rowIds     = $self->{rowIds};
    my $rowId2Name = $self->{rowId2Name};
    $self->{cells} = \%cells;

    ## Order in terms of matrix rows.
    my @matrixRows;
    for my $rowId (@$rowIds) {
        my $rowName = $rowId2Name->{$rowId};
        my $r       = "$rowId\t";
        $r .= "$rowName\t";
        for my $tx (@taxonsOrdered) {
            my ( $taxon_oid, $taxon_display_name ) = split( /\t/, $tx );
            my $cellId = "$rowId\t$taxon_oid\t";
            my $cell   = $cells{$cellId};
            #print "PhyloProfile::process() cell $cellId: $cell<br/>\n";
            my ( $id, $name, $taxon_oid2, $bin_oid2, $gene_count ) =
              split( /\t/, $cell );
            $r .= "$taxon_oid\t";
            $r .= "\t";              # null bin_oid
            $r .= "$gene_count\t";
        }
        for my $bn (@binsOrdered) {
            my ( $bin_oid, $bin_display_name ) = split( /\t/, $bn );
            my $cellId = "$rowId\t\t$bin_oid";
            my $cell   = $cells{$cellId};
            my ( $id, $name, $taxon_oid2, $bin_oid2, $gene_count ) =
              split( /\t/, $cell );
            $r .= "\t";              # null taxon_oid
            $r .= "$bin_oid\t";
            $r .= "$gene_count\t";
        }
        push( @matrixRows, $r );
    }
    $self->{matrixRows} = \@matrixRows;

    #$dbh->disconnect();
    $self->save();
}

############################################################################
# printProfile - Show profile matrix.
############################################################################
sub printProfile {
    my ($self) = @_;
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

    print "<div id='fullView' style='display: block;'>\n";
    $self->writeDiv("full");
    print "</div>\n";

    print "<div id='slimView' style='display: none;'>\n";
    $self->writeDiv("slim");
    print "</div>\n";
}

############################################################################
# writeDiv - writes out the table html for either the full or the slim view
############################################################################
sub writeDiv {
    my ( $self, $which ) = @_;

    my $baseUrl       = $self->{baseUrl};
    my $type          = $self->{type};
    my $procId        = $self->{procId};
    my $idLabel       = $self->{idLabel};
    my $nameLabel     = $self->{nameLabel};
    my $taxon_oids_ref = $self->{taxon_oids};
    my $taxonsOrdered = $self->{taxonsOrdered};
    my $binsOrdered   = $self->{binsOrdered};
    my $data_type     = $self->{data_type};
    my $rowIds        = $self->{rowIds};
    my $cells         = $self->{cells};
    my $colorMap      = $self->{colorMap};
    my $znorm         = $self->{znorm};
    my $orthologData  = $self->{orthologData};

    my $contact_oid = getContactOid();
    my $dbh         = dbLogin();

    ## get MER-FS taxons 
    my %mer_fs_taxons;
    if ( $in_file ) {
        %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile($dbh, @$taxon_oids_ref);
    } 

    my $isEditor    = canEditGeneTerm( $dbh, $contact_oid );

    my $s = "Mouse over genome abbreviation to see genome name.<br/>\n";
    if ( $which eq "slim" ) {
        $s = "Mouse over column number to see genome name.<br/>\n";
        $s .= "Mouse over function id to see function name.<br/>\n";
    }

    # added <span> with background colors for YUI table compatibility
    # +BSJ 03/04/10
    if ($znorm) {
        $s .= "Cell coloring is based on z-score (floored at 0): ";
        $s .= "white = 0, ";
        $s .= "<span style='background-color:bisque'>bisque</span> = 1-4, ";
        $s .= "<span style='background-color:#FFFF66'>yellow</span> >= 5.<br/>\n";
    } else {
        $s .= "Cell coloring is based on gene count: ";
        $s .= "white = 0, ";
        $s .= "<span style='background-color:bisque'>bisque</span> = 1-4, ";
        $s .= "<span style='background-color:#FFFF66'>yellow</span> >= 5.<br/>\n";
    }
    if ( defined($orthologData) ) {
        $s .= "Ortholog gene count is shown in parentheses.<br/>\n";
    }

    printHint($s);

    if ( $which eq "full" ) {
        print "<input type='button' class='medbutton' name='view'"
          . " value='Show Slim View'"
          . " onclick='showView(\"slim\")' />\n";
    } elsif ( $which eq "slim" ) {
        print "<input type='button' class='medbutton' name='view'"
          . " value='Show Full View'"
          . " onclick='showView(\"full\")' />\n";
    }

    my $it = new InnerTable( 1, "Function$which$$", "Function$which", 0 );
    my $sd = $it->getSdDelim();

    $it->addColSpec( $idLabel, "asc" );
    if ( $which eq "full" && $nameLabel ne 'NONAME' ) { #NONAME means no display of Name column
        $it->addColSpec( $nameLabel, "asc" );
    }

    my $count = 0;
    for my $tx (@$taxonsOrdered) {
        $count++;
        my ( $taxon_oid, $taxon_display_name ) = split( /\t/, $tx );
        my $colName;
        if ( $which eq "slim" ) {
            $colName = $count;
        } else {
            $colName = WebUtil::abbrColName( $taxon_oid, $taxon_display_name, 1 );
        }

    	if ( $mer_fs_taxons{$taxon_oid} ) {
    	    $colName = HtmlUtil::appendMetaTaxonNameWithDataTypeAtBreak( $colName, $data_type );
    	} 

        $it->addColSpec( $colName, "desc", "right", "", $taxon_display_name );
    }

    for my $bn (@$binsOrdered) {
        $count++;
        my ( $bin_oid, $bin_display_name ) = split( /\t/, $bn );
        my $colName = WebUtil::abbrBinColName( $bin_oid, $bin_display_name, 1 );
        $it->addColSpec( $colName, "desc", "right", "", $bin_display_name );
    }

    my @sortedRecs;
    my $sortIdx = param("sortIdx");
    $sortIdx = 0 if $sortIdx eq "";
    $self->sortedRecsArray( $sortIdx, \@sortedRecs );

    my $style = "style='text-align:right;'";

    for my $r (@sortedRecs) {
        #print "PhyloProfile::writeDiv() sortedRecs r: $r<br/>\n";
        my ( $rowId, $name, @taxonBinGeneCount ) = split( /\t/, $r );
        my $sortIdx2 = $sortIdx + 1;
        my $url      = "$section_cgi&page=phyloProfileGenes";
        $url .= "&type=$type";
        $url .= "&procId=$procId";
        $url .= "&id=". WebUtil::massageToUrl2($rowId);

    	my $m_url = ""; 
    	if ( $rowId =~ /COG/ ) { 
    	    $m_url = "$main_cgi?section=MetaDetail&page=cogGeneList" . 
    		"&cog_id=$rowId"; 
    	} 
    	elsif ( $rowId =~ /pfam/ ) { 
    	    $m_url = "$main_cgi?section=MetaDetail&page=pfamGeneList" . 
    		"&ext_accession=$rowId"; 
    	} 
    	elsif ( $rowId =~ /TIGR/ ) { 
    	    $m_url = "$main_cgi?section=MetaDetail&page=tigrfamGeneList" . 
    		"&ext_accession=$rowId"; 
    	} 
    	elsif ( $rowId =~ /KO/ ) { 
    	    $m_url = "$main_cgi?section=MetaDetail&page=koGenes" . 
    		"&koid=$rowId"; 
    	} 
    	elsif ( $rowId =~ /EC/ ) { 
    	    $m_url = "$main_cgi?section=MetaDetail&page=enzymeGeneList" . 
    		"&ec_number=$rowId";
    	}
        elsif ( $rowId =~ /BC/ ) { 
            $m_url = "$main_cgi?section=BiosyntheticDetail&page=biosynthetic_genes" . 
            "&func_id=$rowId";
        }
        elsif ( $rowId =~ /MetaCyc/ ) { 
            $m_url = "$main_cgi?section=MetaDetail&page=metaCycGenes" . 
            "&func_id=$rowId";
        }

        my $n  = @taxonBinGeneCount;
        my $n3 = $n / 3;
        my $row;

        if ( $which eq "slim" ) {
            # first check if the row is empty in which
            # case it will not be displayed in slim view
            my $found = 0;
            for ( my $i = 0 ; $i < $n3 ; $i++ ) {
                my $taxon_oid  = $taxonBinGeneCount[ $i * 3 + 0 ];
                my $bin_oid    = $taxonBinGeneCount[ $i * 3 + 1 ];
                my $gene_count = $taxonBinGeneCount[ $i * 3 + 2 ];
                if ( $gene_count > 0 ) {
                    $found = 1;
                    last;
                }
            }
            next if ( !$found );
            $row .= escHtml($rowId) . $sd
        		. $self->printTooltipCell( escHtml($rowId), escHtml($name) )
        		. "\t";
        } else {
            $row .= $rowId . $sd . escHtml($rowId) . "\t";
            if ( $nameLabel ne 'NONAME' ) { #NONAME means no display of Name column
                $row .= $name . $sd . escHtml($name) . "\t";
            }
        }

        for ( my $i = 0 ; $i < $n3 ; $i++ ) {
            my $taxon_oid  = $taxonBinGeneCount[ $i * 3 + 0 ];
            my $bin_oid    = $taxonBinGeneCount[ $i * 3 + 1 ];
            my $gene_count = $taxonBinGeneCount[ $i * 3 + 2 ];
            #print "PhyloProfile::writeDiv() taxon_oid: $taxon_oid; gene_count: $gene_count<br/>\n";
            my $url2       = "$url&taxon_oid=$taxon_oid&bin_oid=$bin_oid";
    	    
    	    if ( $mer_fs_taxons{$taxon_oid} ) { 
        		if ( $m_url ) {
        		    $url2 = "$m_url&taxon_oid=$taxon_oid"; 
        		    if ( $data_type ) {
        		        $url2 .= "&data_type=$data_type";
        		    }
        		} 
        		else { 
        		    $url2 = ""; 
        		} 
    	    } 

            my $od = showOrthologCounts( $self, $rowId, "t:$taxon_oid" );

            if ( $gene_count == 0 || $gene_count eq "" ) {
        		# no genes
        		if ( $mer_fs_taxons{$taxon_oid} ) { 
        		    $row .= "0" . $sd; 
        		    $row .= "<div $style>0$od</div>\t";
        		} 
                elsif (( ( $img_er && $rowId =~ /ITERM:/ && $isEditor )
    		      #  || ($use_gene_priam && $rowId =~ /EC:/)) &&
    		      || ( $rowId =~ /EC:/ )
                        )
                        && $bin_oid eq "")
                {
                    my $url = "$main_cgi?section=MissingGenes";
                    $url .= "&page=candidatesForm";
                    $url .= "&taxon_oid=$taxon_oid";
                    $url .= "&funcId=$rowId";
                    my $otherTaxonOids;
                    for ( my $j = 0 ; $j < $n3 ; $j++ ) {
                        my $taxon_oid_other = $taxonBinGeneCount[ $j * 3 + 0 ];
                        next if $taxon_oid_other eq $taxon_oid;
                        $otherTaxonOids .= "$taxon_oid_other,";
                    }
                    chop $otherTaxonOids;
                    $url .= "&otherTaxonOids=$otherTaxonOids";
                    $url .= "&procId=$procId";
                    $url .= "&fromPm=PhyloProfile";
                    my $link = alink( $url, "0" );
                    $row .= "0" . $sd;
                    $row .= "<div $style>$link$od</div>\t";
                } else {
                    $row .= "0" . $sd;
                    $row .= "<div $style>0$od</div>\t";
                }
            } else {
                #print "PhyloProfile::writeDiv() taxon_oid: $taxon_oid; gene_count: $gene_count<br/>\n";
        		# has genes
                my $colorClause;
                for my $c (@$colorMap) {
                    my ( $lo, $hi, $color ) = split( /:/, $c );
                    if ( $lo <= $gene_count && $gene_count < $hi ) {
                        $colorClause = $color;
                        last;
                    }
                }
                $row .= $gene_count . $sd 
	                 . "<div style='text-align:right; background-color:$colorClause;'>";
                if ( $mer_fs_taxons{$taxon_oid} && $rowId =~ /MetaCyc:/ ) {
                    $row .= "<= ";
                }
                $row .= alink( $url2, $gene_count );
                $row .= "$od</div>\t";
            }
        }
        $it->addRow($row);
    }
    $it->printOuterTable(1);

    if ( $which eq "slim" ) {
    	print "<h2>Column ID to Name Map</h2>";
    
        # write a table legend column id:name
    	use StaticInnerTable;
    	my $it = new StaticInnerTable();
    	my $sd = $it->getSdDelim();    # sort delimiter
    	$it->addColSpec( "Column ID", "asc", "right" );
    	$it->addColSpec( "Column Name", "asc" );

        my $count = 0;
        for my $tx (@$taxonsOrdered) {
            my $row;
            $count++;
            my ( $taxon_oid, $taxon_display_name ) = split( /\t/, $tx );
            $row .= $sd . $count . "\t";
            $row .= $sd . $taxon_display_name . "\t";
    	    $it->addRow($row);
        }

    	$it->printOuterTable();
    }
    #$dbh->disconnect();

    $self->save();
}

############################################################################
# printProfileGenes - Print profile count genes.
############################################################################
sub printProfileGenes {
    my ($self)    = @_;
    
    my $taxon_sql = $self->{taxon_cell_sql_template};
    my $bin_sql   = $self->{bin_cell_sql_template};

    ProfileUtil::printProfileGenes( $taxon_sql, $bin_sql );
}

############################################################################
# showOrthologCounts - Get counts for orthologs.
############################################################################
sub showOrthologCounts {
    my ( $self, $funcId, $taxonBinOid ) = @_;

    my $type   = $self->{type};
    my $procId = $self->{procId};

    my $orthologData = $self->{orthologData};
    return "" if !defined($orthologData);

    my $k      = "$funcId,$taxonBinOid";
    my $genes  = $orthologData->{$k};
    my @keys   = keys(%$genes);
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
    my ($self) = @_;

    my $funcId      = param("funcId");
    my $taxonBinOid = param("taxonBinOid");

    my $orthologData = $self->{orthologData};
    return "" if !defined($orthologData);

    my $k         = "$funcId,$taxonBinOid";
    my $genes     = $orthologData->{$k};
    my @gene_oids = sort( keys(%$genes) );

    my $count = scalar(@gene_oids);
    if ( $count == 1 ) {
        use GeneDetail;
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();
    print "<h1>Ortholog Genes</h1>\n";
    printGeneCartFooter() if $count > 10;
    my $dbh = dbLogin();
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

1;
