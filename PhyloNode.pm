############################################################################
# PhyloNode - One tree node for phylogenetic tree.
#  --es 02/02/2005
#
# $Id: PhyloNode.pm 33887 2015-08-04 00:31:25Z aireland $
############################################################################
package PhyloNode;
my $section = "PhyloNode";
use strict;
use warnings;
use feature ':5.16';

use Data::Dumper;
use WebConfig;
use WebUtil;

my $env         = getEnv();
my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $verbose     = $env->{verbose};

############################################################################
# new - Allocate new instance.
############################################################################
sub new {
    my ( $myType, $taxon_oid, $taxon_display_name ) = @_;
    my $self = {};
    bless( $self, $myType );

    ###
    # Attributes
    #
    $self->{domain}               = "";
    $self->{node_oid}             = "";
    $self->{taxon_oid}            = $taxon_oid;
    $self->{taxon_display_name}   = $taxon_display_name;
    $self->{count}                = 0;
    $self->{taxon_oid_node_count} = 0;
    $self->{seq_center}           = "";
    $self->{seq_status}           = "";
    $self->{obsolete_flag}        = "";
    my @a;
    $self->{children} = \@a;
    $self->{parent} = undef;

    return $self;
}

############################################################################
# getLevel - Level (depth) of node.
############################################################################
sub getLevel {
    my ($self) = @_;
    my $parent = $self->{parent};
    my $count  = 0;
    for ( ; $parent ; $parent = $parent->{parent} ) {
        $count++;
    }
    return $count;
}

############################################################################
# getParentFenced - Get a parent fenced at a certain level.
############################################################################
sub getParentFenced {
    my ( $self, $minLevel ) = @_;
    my $parent = $self->{parent};
    my $count  = 0;
    for ( ; $parent ; $parent = $parent->{parent} ) {
        my $level = $parent->getLevel();
        return $parent if ( $level <= $minLevel );
    }
    return "";
}

############################################################################
# printNode - Print contents of the node out for debuggiag.
############################################################################
sub printNode {
    my ($self) = @_;
    my $level  = $self->getLevel();
    my $sp     = "  " x $level;
    my $c;
    my $seq_status = $self->{seq_status};
    $c = "($seq_status)" if $seq_status ne "";
    printf "%s%02d %d %s %s(%d)\n", $sp, $level, $self->{taxon_oid}, $self->{taxon_display_name}, $c, $self->{count};
    my $a      = $self->{children};
    my $nNodes = @$a;

    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        printNode($n2);
    }
}

############################################################################
# printHtmlCounted - Print in HTML format and highlight rows with counts
#   greater than zero.  The counts are hits on an genome with
#   homolog (ortholog) data.
############################################################################
sub printHtmlCounted {
    my ($self) = @_;
    my $level  = $self->getLevel();
    my $sp     = " ." x $level;
    my $c;
    my $seq_status = $self->{seq_status};
    $c = "[$seq_status]" if $seq_status ne "";
    my $url = $self->{taxon_display_name};
    if($self->{taxon_oid} ne '') {
        $url = alink("main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=" .$self->{taxon_oid} , $self->{taxon_display_name});
    }
    #webLog("===== $url\n");
    if ( $level != 0 && $level != 7 ) {
        if ( $self->{count} > 0 ) {
            print "<font color='red'>";
            print "<b>" if $self->{taxon_oid} ne "";
            print $self->{domain};
            printf "%s%02d %s %s(%d)", $sp, $level, $url, $c, $self->{count};
            print "</b>" if $self->{taxon_oid} ne "";
            print "</font>";
            print "\n";
        }
        else {
            print $self->{domain};
            printf "%s%02d %s %s\n", $sp, $level, $url, $c;
        }
    }
    my $a      = $self->{children};
    my $nNodes = @$a;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        printHtmlCounted($n2);
    }
}

############################################################################
# printSelectableTree - Print tree for group taxon selecting.
#
# $editor - taxon editor
############################################################################
sub printSelectableTree {
    my ( $self, $taxon_filter_ref, $taxon_filter_cnt, $taxonOid2Idx_ref, $editor ) = @_;
    my $level                = $self->getLevel();
    my $sp                   = "&nbsp;" x ( $level * 4 );
    my $node_oid             = $self->{node_oid};
    my $taxon_oid            = $self->{taxon_oid};
    my $domain               = $self->{domain};
    my $taxon_display_name   = $self->{taxon_display_name};
    my $seq_center           = $self->{seq_center};
    my $seq_status           = $self->{seq_status};
    my $taxon_oid_node_count = $self->{taxon_oid_node_count};
    my $obsolete_flag        = $self->{obsolete_flag};
    if ( ( $level != 0 && $level != 7 ) || ( $editor && $level == 7 && $domain =~ /^\*/ ) ) {
        printf "%s%02d ", $sp, $level;
        my $dcolor = "black";
        if ( $domain =~ /^A/ ) {
            $dcolor = "purple";
        } elsif ( $domain =~ /^B/ ) {
            $dcolor = "blue";
        } elsif ( $domain =~ /^E/ ) {
            $dcolor = "darkgreen";
        } elsif ( $domain =~ /^\*/ ) {
            $dcolor = "navy";
        } elsif ( $domain =~ /^P/ ) {
            $dcolor = "chocolate";
        } elsif ( $domain =~ /^V/ ) {
            $dcolor = "firebrick";
        }
        if ( $level == 1 ) {
            print "<font size='+1'>\n";
        }
        if ( $level == 1 || $level == 2 ) {
            print "<b>\n";
        }
        print "<font color='$dcolor'>\n";
        if ( $taxon_oid ne "" ) {
            my $checked;
            $checked = "checked" if $taxon_filter_ref->{$taxon_oid} ne "";
            $checked = "checked" if $taxon_filter_cnt == 0;
            print "<input type='checkbox' name='taxon_filter_oid' $checked " . " value='$taxon_oid' />\n";
            my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
            if ($editor) {
                my $o = "";
                if ( $obsolete_flag eq "Yes" ) {
                    $o = " &nbsp;&nbsp; <font color='red'> obsolete </font>";
                }
                print "<font color='black'> $taxon_display_name &nbsp;&nbsp; $taxon_oid </font> $o ";
            } else {
                print WebUtil::alink( $url, $taxon_display_name );
            }
            print "&nbsp;[$seq_status]";
            print " <font color='red'>(JGI)</font> " if $seq_center =~ /JGI/;
            if ($editor) {
                my $url = "main-edit.cgi?section=TaxonEdit&page=taxonOneEdit&taxon_oid=$taxon_oid";
                print qq{<input type='button' value='Edit' Class='tinybutton'
            onClick='javascript:window.open("$url", "_self");' />};
            }
        } else {
            my ( $minRange, $maxRange ) = getMinMaxRange( $self, $taxonOid2Idx_ref );
            print WebUtil::escHtml($taxon_display_name);

            #print "($taxon_oid_node_count)\n";
            print "&nbsp;";
            $self->printSelectButton( $node_oid, $minRange, $maxRange, $editor, $level, $taxon_display_name );
        }
        print "</font>\n";    # dcolor
                              #print " <font color='red'>(JGI)</font> " if $seq_center =~ /JGI/;
        print "<br/>\n";
        if ( $level == 1 || $level == 2 ) {
            print "</b>\n";
        }
        if ( $level == 1 ) {
            print "</font>\n";
        }
    }
    my $a      = $self->{children};
    my $nNodes = @$a;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        printSelectableTree( $n2, $taxon_filter_ref, $taxon_filter_cnt, $taxonOid2Idx_ref, $editor );
    }
}

############################################################################
# printExpandableTree - Print tree for expanding and collapsing.
############################################################################
sub printExpandableTree {
    my ( $self, $expandNodes_ref, $master_taxon_oid, $return_page, $last_changed_node, $selectedTaxonOids_ref ) = @_;
    my $level                = $self->getLevel();
    my $sp                   = "&nbsp;" x ( $level * 2 );
    my $node_oid             = $self->{node_oid};
    my $domainLetter         = substr( $self->{domain}, 0, 1 );
    my $taxon_oid            = $self->{taxon_oid};
    my $taxon_display_name   = $self->{taxon_display_name};
    my $seq_center           = $self->{seq_center};
    my $seq_status           = $self->{seq_status};
    my $a                    = $self->{children};
    my $nNodes               = @$a;
    my $all_level_open       = 6;
    my $taxon_oid_node_count = $self->{taxon_oid_node_count};
    if ( $level != 0 && $level != 6 && $level != 7 ) {
        print "<a name='$node_oid' id='$node_oid'></a>";
        printf "$domainLetter%s ", $sp;
        if ( $taxon_oid ne "" ) {
            my $checked;
            if ( $master_taxon_oid eq $taxon_oid ) {
                $checked = "checked";
            }
            my $leftBracket  = "[";
            my $rightBracket = "]";
            if ( $last_changed_node eq $node_oid ) {
                $leftBracket  = "<font color='red'>[</font>";
                $rightBracket = "<font color='red'>]</font>";
            }
            if ( $selectedTaxonOids_ref->{$taxon_oid} ne "" ) {
                my $url = "$section_cgi&page=$return_page";
                $url .= "&deselect_taxon_oid=$taxon_oid";
                $url .= "&master_taxon_oid=$master_taxon_oid";
                $url .= "&last_changed_node=$node_oid";
                $url .= "#$node_oid";
                print "*$leftBracket" . WebUtil::alink( $url, "Rem" ) . "$rightBracket ";
            } else {
                my $url = "$section_cgi&page=$return_page";
                $url .= "&select_taxon_oid=$taxon_oid";
                $url .= "&master_taxon_oid=$master_taxon_oid";
                $url .= "&last_changed_node=$node_oid";
                $url .= "#$node_oid";
                print $leftBracket . WebUtil::alink( $url, "Add" ) . "$rightBracket ";
            }

            #print "<input type='checkbox' name='taxon_oid' $checked " .
            #   " value='$taxon_oid' />";
            my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
            print WebUtil::alink( $url, $taxon_display_name );
            if ( $master_taxon_oid eq $taxon_oid ) {
                print " <font color='red'>(Master)</font>";
            }
        } else {
            my $url = "$section_cgi&page=$return_page";
            $url .= "&master_taxon_oid=$master_taxon_oid";
            my $button;
            if (    $expandNodes_ref->{$node_oid} eq ""
                 && $nNodes > 0
                 && $level < $all_level_open )
            {
                $url .= "&expand=$node_oid#$node_oid";
                $button = "[" . WebUtil::alink( $url, "O" ) . "]";
            } elsif ( $level < $all_level_open ) {
                $url .= "&collapse=$node_oid#$node_oid";
                $button = "[" . WebUtil::alink( $url, "C" ) . "]";
            }
            print "$button ";
            print "<b>" if ( $level == 1 || $level == 2 );
            print "<font color='red'><b>" if $node_oid eq $last_changed_node;
            print WebUtil::escHtml($taxon_display_name);
            print "</b></font>" if $node_oid eq $last_changed_node;
            print "</b>" if ( $level == 1 || $level == 2 );
            print "($taxon_oid_node_count)" if $taxon_oid_node_count ne "";
        }

        #print " <font color='red'>(JGI)</font> " if $seq_center =~ /JGI/;
        print "\n";

        #print "<br/>\n";
    }
    my $expand = $expandNodes_ref->{$node_oid};
    webLog( "node_oid=$node_oid val='$expand' level=$level " . "$taxon_display_name\n" ) if $expand ne "" && $verbose >= 5;
    return if $expand eq "" && $level >= 1 && $level < $all_level_open;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        printExpandableTree( $n2, $expandNodes_ref, $master_taxon_oid, $return_page, $last_changed_node,
                             $selectedTaxonOids_ref );
    }
}

############################################################################
# countTaxonOidNodes - Count the number of taxon  OID nodes aggregated
#   up the tree.
############################################################################
sub countTaxonOidNodes {
    my ($self)    = @_;
    my $taxon_oid = $self->{taxon_oid};
    my $a         = $self->{children};
    my $nNodes    = @$a;
    my $count     = 0;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        $count += countTaxonOidNodes($n2);
    }
    if ( $taxon_oid ne "" ) {
        $self->{taxon_oid_node_count} = 1;
    } else {
        $self->{taxon_oid_node_count} = $count;
    }
    return $self->{taxon_oid_node_count};
}

############################################################################
# trimBranches - Trim branches if no terminal taxon_oid_node's.
############################################################################
sub trimBranches {
    my ($self) = @_;
    my $a      = $self->{children};
    my $nNodes = @$a;
    my $count  = 0;
    my @b;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2                   = $self->{children}->[$i];
        my $taxon_oid_node_count = $n2->{taxon_oid_node_count};
        next if $taxon_oid_node_count == 0;
        push( @b, $n2 );
    }
    $self->{children} = [ @b ];
    for ( my $i = 0 ; $i < scalar(@b) ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        trimBranches($n2);
    }
}

############################################################################
# sortLeafNodes - Sort leaf nodes by taxon_display_name.
############################################################################
sub sortLeafNodes {
    my ($self)    = @_;
    my $a         = $self->{children};
    my $nNodes    = @$a;
    my $leafCount = 0;
    my @recs;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2      = $self->{children}->[$i];
        my $a2      = $n2->{children};
        my $nNodes2 = @$a2;
        $leafCount += $nNodes2;
        push( @recs, $n2->{taxon_display_name} . "\t$i" );
    }
    ## All child nodes have no more children.
    ## This is the right level to sort.
    if ( $leafCount == 0 ) {
        my @recs2 = sort(@recs);
        my @sorted;
        for my $r2 (@recs2) {
            my ( $taxon_display_name, $i ) = split( /\t/, $r2 );
            my $n2 = $self->{children}->[$i];
            push( @sorted, $n2 );
        }
        $self->{children} = \@sorted;
        @recs = ();
    }
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        sortLeafNodes($n2);
    }
}

############################################################################
# getMinMaxRange - Get minimum and maximum index for taxon oids under
#   this node.
############################################################################
sub getMinMaxRange {
    my ( $self, $taxonOid2Idx_ref ) = @_;
    my $min    = 999999999;
    my $max    = -1;
    my $a      = $self->{children};
    my $nNodes = @$a;
    my @taxon_oids;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        getAllTaxonOids( $n2, \@taxon_oids );
    }
    my @keys  = keys(%$taxonOid2Idx_ref);
    my $nKeys = @keys;
    for my $taxon_oid (@taxon_oids) {
        my $idx = $taxonOid2Idx_ref->{$taxon_oid};
        $min = $min < $idx ? $min : $idx;
        $max = $max > $idx ? $max : $idx;
    }
    return ( $min, $max );
}

############################################################################
# getAllTaxonOids - Get all taxon oids from children.
############################################################################
sub getAllTaxonOids {
    my ( $self, $taxonOids_ref ) = @_;
    my $taxon_oid = $self->{taxon_oid};
    if ( $taxon_oid ne "" ) {
        push( @$taxonOids_ref, $taxon_oid );
    }
    my $a      = $self->{children};
    my $nNodes = @$a;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        getAllTaxonOids( $n2, $taxonOids_ref );
    }
}

############################################################################
# getTaxonOid2IdxMap - Get taxonOid to line index mapping, for
#   javascript group selections.
############################################################################
sub getTaxonOid2IdxMap {
    my ( $self, $map_ref, $cnt_ref ) = @_;
    my $level = $self->getLevel();
    if ( $level != 0 && $level != 6 && $level != 7 ) {
        my $taxon_oid = $self->{taxon_oid};
        if ( $taxon_oid ne "" ) {
            $map_ref->{$taxon_oid} = $$cnt_ref;
            $$cnt_ref++;
        }
    }
    my $a      = $self->{children};
    my $nNodes = @$a;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        getTaxonOid2IdxMap( $n2, $map_ref, $cnt_ref );
    }
}

############################################################################
# addNode - Add one node.  Set the dual pointers.
############################################################################
sub addNode {
    my ( $self, $node ) = @_;
    my $a = $self->{children};
    push( @$a, $node );
    $node->{parent} = $self;
}

############################################################################
# aggCount - Aggregate counts. Show cumulative counts higher up
#   on the tree.
############################################################################
sub aggCount {
    my ($self)    = @_;
    my $children  = $self->{children};
    my $nChildren = @$children;
    for ( my $i = 0 ; $i < $nChildren ; $i++ ) {
        my $n2   = $children->[$i];
        my $cnt2 = $n2->aggCount();
        $self->{count} += $cnt2;
    }
    return $self->{count};
}

############################################################################
# loadAllDomains - Transfer child domain letters to parents.
#   Set the 'B'acterial, 'A'rchael, 'E'ukarya domains for higher
#   level nodes.
############################################################################
sub loadAllDomains {
    my ($self)    = @_;
    my $children  = $self->{children};
    my $nChildren = @$children;
    for ( my $i = 0 ; $i < $nChildren ; $i++ ) {
        my $n2 = $children->[$i];
        $n2->loadAllDomains();
    }
    if ( $nChildren == 0 ) {
        my $parent = $self->{parent};
        for ( ; $parent ; $parent = $parent->{parent} ) {
            $parent->{domain} = $self->{domain};
        }
    }
}

############################################################################
# printSelectButton - Show All or None buttons for group of taxons.
#   Inputs:
#     node_oid - node object identifer (from dt_taxon_node_lite)
#     minRange - minimum start of range
#     maxRange - maximum end of range
############################################################################
sub printSelectButton {
    my ( $self, $node_oid, $minRange, $maxRange, $editor, $level, $taxon_display_name ) = @_;
    print "<input type='button' value='All' Class='tinybutton' ";
    print "  onClick='selectTaxonRange($minRange,$maxRange,1)' />\n";
    print "<input type='button' value='None' Class='tinybutton' ";
    print "  onClick='selectTaxonRange($minRange,$maxRange,0)' />\n";
    if ( $editor && $level > 1 ) {
        my $string = $self->getDomainString($editor);
        $string = WebUtil::massageToUrl2($string);
        my $url = "main-edit.cgi?section=TaxonEdit&page=domain&value=$string";

        #$url = escHtml($url);
        print qq{<input type='button' value='Edit $taxon_display_name' Class='tinybutton'
         onClick='javascript:window.open("$url", "_self");' />
        };
    }
}

#
# string return example
# ,Bacteria,Actinobacteria,Actinobacteria,Actinomycetales,Tsukamurellaceae
# i can us a query to get the taxons with something like this
#select *
#from taxon
#where domain = 'Bacteria'
#and phylum = 'Actinobacteria'
#and ir_class = 'Actinobacteria'
#and ir_order = 'Actinomycetales'
#and family = 'Tsukamurellaceae'
#--and genus = ''
#--and species = ''
# -- Bacteria,Actinobacteria,Actinobacteria,Actinomycetales,Corynebacteriaceae
# order by domain, phylum, ir_class, ir_order, family, taxon_display_name
sub getDomainString {
    my ( $self, $editor ) = @_;
    if ( $self->{parent} ne "" ) {
        if ($editor) {

            return $self->{parent}->getDomainString($editor) . ",_," . $self->{taxon_display_name};
        } else {

            return $self->{parent}->getDomainString() . "," . $self->{taxon_display_name};
        }
    } else {
        return $self->{taxon_display_name};
    }
}

############################################################################
# printTreeviewNodes - Print Treeview nodes.
############################################################################
sub printTreeviewNodes {
    my ($self)               = @_;
    my $node_oid             = $self->{node_oid};
    my $p                    = $self->{parent};
    my $p_node_oid           = $p->{node_oid};
    my $taxon_oid            = $self->{taxon_oid};
    my $level                = $self->getLevel();
    my $taxon_display_name   = $self->{taxon_display_name};
    my $taxon_oid_node_count = $self->{taxon_oid_node_count};
    my $fenceLevel           = 6;
    if ( $node_oid ne "root" ) {
        $taxon_display_name =~ s/"/\\\"/g;
        $taxon_display_name =~ s/'/\\\'/g;
        if ( $taxon_oid ne "" ) {
            my $p          = $self->getParentFenced($fenceLevel);
            my $p_node_oid = $p->{node_oid};
            print "var n${node_oid} = ";
            print "gLnk( \"S\", \"$taxon_display_name\", ";
            print "\"javascript:remoteTaxonSend(%22";
            print "node_oid=$node_oid&taxon_oid=$taxon_oid%22)\" );\n";
            my $x = "<input type=checkbox " . "name=taxon_filter_oid value=$taxon_oid />";
            print "n${node_oid}.prependHTML = \"$x\";\n";
            print "insDoc( n${p_node_oid}, n${node_oid} );\n";
        } elsif ( $level <= $fenceLevel ) {
            print "var n${node_oid} = ";
            print "gFld( \"$taxon_display_name-($taxon_oid_node_count)\", ";
            print "\"javascript:remoteTaxonSend(%22";
            print "node_oid=$node_oid%22)\" );\n";
            print "insFld( n${p_node_oid}, n${node_oid} );\n";
        }
    }
    my $children_r = $self->{children};
    for my $c (@$children_r) {
        $c->printTreeviewNodes();
    }
}

############################################################################
# printPhenotypeTree - Print tree for IMG phenotype
#
# $phentoype: phenotype
# $show_all: 1 - show all; 0 - show selected only
############################################################################
sub printPhenotypeTree {
    my ( $self, $taxon_filter_ref, $taxon_filter_cnt, $taxonOid2Idx_ref, $phenotype, $rule_id, $show_all ) = @_;
    my $level                = $self->getLevel();
    my $sp                   = "&nbsp;" x ( $level * 4 );
    my $node_oid             = $self->{node_oid};
    my $taxon_oid            = $self->{taxon_oid};
    my $domain               = $self->{domain};
    my $taxon_display_name   = $self->{taxon_display_name};
    my $seq_center           = $self->{seq_center};
    my $seq_status           = $self->{seq_status};
    my $taxon_oid_node_count = $self->{taxon_oid_node_count};
    my $obsolete_flag        = $self->{obsolete_flag};

    my $editor = 0;

    if ( $level != 0 && $level != 7 ) {
        printf "%s%02d ", $sp, $level;
        my $dcolor = "black";
        if ( $domain =~ /^A/ ) {
            $dcolor = "purple";
        } elsif ( $domain =~ /^B/ ) {
            $dcolor = "blue";
        } elsif ( $domain =~ /^E/ ) {
            $dcolor = "darkgreen";
        } elsif ( $domain =~ /^\*/ ) {
            $dcolor = "navy";
        } elsif ( $domain =~ /^P/ ) {
            $dcolor = "chocolate";
        } elsif ( $domain =~ /^V/ ) {
            $dcolor = "firebrick";
        }
        if ( $level == 1 ) {
            print "<font size='+1'>\n";
        }
        if ( $level == 1 || $level == 2 ) {
            print "<b>\n";
        }
        print "<font color='$dcolor'>\n";
        if ( $taxon_oid ne "" ) {
            if ( $show_all || $taxon_filter_ref->{$taxon_oid} ne "" ) {
                my $checked;
                $checked = "checked" if $taxon_filter_ref->{$taxon_oid} ne "";
                $checked = "checked" if $taxon_filter_cnt == 0;
                print "<input type='checkbox' name='taxon_filter_oid' $checked " . " value='$taxon_oid' />\n";
                my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
                if ($editor) {
                    my $o = "";
                    if ( $obsolete_flag eq "Yes" ) {
                        $o = " &nbsp;&nbsp; <font color='red'> obsolete </font>";
                    }
                    print "<font color='black'> $taxon_display_name &nbsp;&nbsp; $taxon_oid </font> $o ";
                } else {
                    print WebUtil::alink( $url, $taxon_display_name );
                }
                print "&nbsp;[$seq_status]";
                print " <font color='red'>(JGI)</font> " if $seq_center =~ /JGI/;

                my $p_result = "   (x)";
                if ( $phenotype && $taxon_filter_ref->{$taxon_oid} ne "" ) {
                    print " <font color='firebrick'> -- ";
                    print WebUtil::escHtml($phenotype);
                    print "</font>\n";
                    $p_result = "   (v)";
                }

                my $url2 =
                  "$main_cgi?section=TaxonDetail" . "&page=taxonPhenoRuleDetail&taxon_oid=$taxon_oid&rule_id=$rule_id";
                print WebUtil::alink( $url2, $p_result );
            }
        } else {
            my ( $minRange, $maxRange ) = getMinMaxRange( $self, $taxonOid2Idx_ref );
            print WebUtil::escHtml($taxon_display_name) . "&nbsp;";

            #	  $self->printSelectButton( $node_oid, $minRange, $maxRange, $editor,  $level, $taxon_display_name );
        }
        print "</font>\n";    # dcolor
                              #print " <font color='red'>(JGI)</font> " if $seq_center =~ /JGI/;
        print "<br/>\n";
        if ( $level == 1 || $level == 2 ) {
            print "</b>\n";
        }

        if ( $level == 1 ) {
            print "</font>\n";
        }
    }
    my $a      = $self->{children};
    my $nNodes = @$a;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        printPhenotypeTree( $n2, $taxon_filter_ref, $taxon_filter_cnt, $taxonOid2Idx_ref, $phenotype, $rule_id, $show_all );
    }
}

############################################################################
# printFuncTree - Print tree for IMG functions
#
# $show_all: 1 - show all; 0 - show selected only
############################################################################
sub printFuncTree {
    my ( $self, $taxon_filter_ref, $taxon_filter_cnt, $taxonOid2Idx_ref, $func_url, $show_all ) = @_;
    my $level                = $self->getLevel();
    my $sp                   = "&nbsp;" x ( $level * 4 );
    my $node_oid             = $self->{node_oid};
    my $taxon_oid            = $self->{taxon_oid};
    my $domain               = $self->{domain};
    my $taxon_display_name   = $self->{taxon_display_name};
    my $seq_center           = $self->{seq_center};
    my $seq_status           = $self->{seq_status};
    my $taxon_oid_node_count = $self->{taxon_oid_node_count};
    my $obsolete_flag        = $self->{obsolete_flag};

    my $editor = 0;

    if ( $level != 0 && $level != 7 ) {
        printf "%s%02d ", $sp, $level;
        my $dcolor = "black";
        if ( $domain =~ /^A/ ) {
            $dcolor = "purple";
        } elsif ( $domain =~ /^B/ ) {
            $dcolor = "blue";
        } elsif ( $domain =~ /^E/ ) {
            $dcolor = "darkgreen";
        } elsif ( $domain =~ /^\*/ ) {
            $dcolor = "navy";
        } elsif ( $domain =~ /^P/ ) {
            $dcolor = "chocolate";
        } elsif ( $domain =~ /^V/ ) {
            $dcolor = "firebrick";
        }
        if ( $level == 1 ) {
            print "<font size='+1'>\n";
        }
        if ( $level == 1 || $level == 2 ) {
            print "<b>\n";
        }
        print "<font color='$dcolor'>\n";
        if ( $taxon_oid ne "" ) {
            if ( $show_all || defined( $taxon_filter_ref->{$taxon_oid} ) ) {
                my $checked;
                $checked = "checked" if !blankStr( $taxon_filter_ref->{$taxon_oid} );
                $checked = "checked" if $taxon_filter_cnt == 0;
                print "<input type='checkbox' name='taxon_filter_oid' $checked " . " value='$taxon_oid' />\n";
                my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
                if ($editor) {
                    my $o = "";
                    if ( $obsolete_flag eq "Yes" ) {
                        $o = " &nbsp;&nbsp; <font color='red'> obsolete </font>";
                    }
                    print "<font color='black'> $taxon_display_name &nbsp;&nbsp; $taxon_oid </font> $o ";
                } else {
                    print WebUtil::alink( $url, $taxon_display_name );
                }
                print "&nbsp;[$seq_status]";
                print " <font color='red'>(JGI)</font> " if $seq_center =~ /JGI/;

                if ( !blankStr( $taxon_filter_ref->{$taxon_oid} ) ) {
                    print " <font color='firebrick'> -- ";
                    my @funcs = split( /\t/, $taxon_filter_ref->{$taxon_oid} );
                    my $is_first = 1;
                    for my $func_id (@funcs) {
                        if ($is_first) {
                            $is_first = 0;
                        } else {
                            print ", ";
                        }

                        if ($func_url) {
                            my $url3 = $func_url . $func_id . "&taxon_oid=$taxon_oid";

                            # print WebUtil::alink($url3, $func_id);
                            print $func_id . " " . WebUtil::alink( $url3, "(v)" );
                        } else {
                            print WebUtil::escHtml($func_id);
                        }
                    }
                    print "</font>\n";
                }

                #	       my $url2 = "$main_cgi?section=TaxonDetail" .
                #		   "&page=taxonPhenoRuleDetail&taxon_oid=$taxon_oid&rule_id=$rule_id";
                #	       print WebUtil::alink( $url2, "   (?)" );
            }
        } else {
            my ( $minRange, $maxRange ) = getMinMaxRange( $self, $taxonOid2Idx_ref );
            print WebUtil::escHtml($taxon_display_name);
            print "&nbsp;";
        }
        print "</font>\n";    # dcolor
                              #print " <font color='red'>(JGI)</font> " if $seq_center =~ /JGI/;
        print "<br/>\n";
        if ( $level == 1 || $level == 2 ) {
            print "</b>\n";
        }

        if ( $level == 1 ) {
            print "</font>\n";
        }
    }
    my $a      = $self->{children};
    my $nNodes = @$a;
    for ( my $i = 0 ; $i < $nNodes ; $i++ ) {
        my $n2 = $self->{children}->[$i];
        printFuncTree( $n2, $taxon_filter_ref, $taxon_filter_cnt, $taxonOid2Idx_ref, $func_url, $show_all );
    }
}

1;
