############################################################################
# Utility subroutines for queries
# $Id: FuncUtil.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package FuncUtil;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;

$| = 1;

my $env      = getEnv();
my $main_cgi = $env->{main_cgi};
my $verbose  = $env->{verbose};
my $base_url = $env->{base_url};
my $YUI      = $env->{yui_dir_28};
my $in_file  = $env->{in_file};
my $user_restricted_site = $env->{user_restricted_site};


my %class2oidAttr = (
    GENE            => "gene_oid",
    BIOCYC_PATHWAY  => "unique_id",
    COG             => "cog_id",
    KOG             => "kog_id",
    ENZYME          => "ec_number",
    GO_TERM         => "go_id",
    INTERPRO        => "ext_accession",
    PFAM_FAMILY     => "ext_accession",
    TIGRFAM         => "ext_accession",
    TC_FAMILY       => "tc_family_num",
    KO_TERM         => "ko_id",
    BIO_CLUSTER_FEATURES => "cluster_id",
    NATURAL_PRODUCT => "np_id",
    IMG_COMPOUND    => "compound_oid",
    IMG_PARTS_LIST  => "parts_list_oid",
    IMG_PATHWAY     => "pathway_oid",
    IMG_REACTION    => "rxn_oid",
    IMG_TERM        => "term_oid",
    PATHWAY_NETWORK => "network_oid",
    PHENOTYPE_RULE  => "rule_id",
);

my %class2nameAttr = (
    BIOCYC_PATHWAY  => "common_name",
    COG             => "cog_name",
    KOG             => "kog_name",
    ENZYME          => "enzyme_name",
    GENE            => "product_name",
    GO_TERM         => "go_term",
    INTERPRO        => "name",
    PFAM_FAMILY     => "name",
    TIGRFAM         => "expanded_name",
    TC_FAMILY       => "tc_family_name",
    KO_TERM         => "ko_name",
    BIO_CLUSTER_FEATURES => "null",
    NATURAL_PRODUCT => "null",
    IMG_COMPOUND    => "compound_name",
    IMG_PARTS_LIST  => "parts_list_name",
    IMG_PATHWAY     => "pathway_name",
    IMG_REACTION    => "rxn_name",
    IMG_TERM        => "term",
    PATHWAY_NETWORK => "network_name",
    PHENOTYPE_RULE  => "cv_value",
);

#
# function cart to add decription to name
#
my %class2nameAttrWithDescription = (
    BIOCYC_PATHWAY  => "null",
    COG             => "description",
    KOG             => "description",
    ENZYME          => "null",
    GENE            => "null",
    GO_TERM         => "definition",
    INTERPRO        => "name",
    PFAM_FAMILY     => "description",
    TIGRFAM         => "null",
    TC_FAMILY       => "null",
    KO_TERM         => "definition",
    BIO_CLUSTER_FEATURES => "null",
    NATURAL_PRODUCT => "null",
    IMG_COMPOUND    => "null",
    IMG_PARTS_LIST  => "null",
    IMG_PATHWAY     => "null",
    IMG_REACTION    => "null",
    IMG_TERM        => "null",
    PATHWAY_NETWORK => "null",
    PHENOTYPE_RULE  => "null",
);


############################################################################
# getOidAttr - get OID attribute name of a class
############################################################################
sub getOidAttr {
    my ($class_name) = @_;

    my $oid_name = $class2oidAttr{$class_name};
    return $oid_name;
}

############################################################################
# getNameAttr - get 'name' attribute name of a class
############################################################################
sub getNameAttr {
    my ($class_name) = @_;

    my $attr_name = $class2nameAttr{$class_name};
    return $attr_name;
}

# class2nameAttrWithDescription
sub getNameAttrDescription {
    my ($class_name) = @_;

    my $attr_name = $class2nameAttrWithDescription{$class_name};
    return $attr_name;
}


############################################################################
# getAttributes - get attribute definition of a class
############################################################################
sub getAttributes {
    my ($class_name) = @_;

    my @attrs = ();

    if ( $class_name eq "IMG_COMPOUND" ) {
        push @attrs, ("compound_name\tIMG Compound Name\tchar\t255\tU");
        push @attrs, ("db_source\tDB Source\t|CHEBI|KEGG LIGAND\t3\tN");
        push @attrs, ("ext_accession\tExt Accession\tchar\t50\tN");
        push @attrs, ("common_name\tCommon Name\tchar\t255\tN");
        push @attrs, ("class\tClass\tchar\t255\tN");
        push @attrs, ("composition\tComposition\tchar\t4000\tN");
        push @attrs, ("formula\tFormula\tchar\t4000\tN");
        push @attrs, ("cas_number\tCAS Number\tchar\t255\tN");
        push @attrs, ("status\tStatus\tchar\t10\tN");
        push @attrs, ("mol_weight\tMol. Weight\tnumber\t20\tN");
        push @attrs, ("num_atoms\tNum of Atoms\tint\t10\tN");
        push @attrs, ("num_bonds\tNum of Bonds\tint\t10\tN");
        push @attrs, ("np_class\tNP Class\tchar\t100\tN");
        push @attrs, ("np_sub_class\tNP Subclass\tchar\t100\tN");
        push @attrs, ("smiles\tSMILES\tchar\t4000\tN");
        push @attrs, ("inchi\tInChI\tchar\t4000\tN");
        push @attrs, ("inchi_key\tInChI Key\tchar\t4000\tN");

        #   push @attrs, ( "kegg\tKEGG Compound ID(s)\tchar\t1000\tN" );
    } elsif ( $class_name eq "IMG_PARTS_LIST" ) {
        push @attrs, ("parts_list_name\tParts List Name\tchar\t500\tU");
        push @attrs, ("definition\tDefinition\tchar\t4000\tN");
    } elsif ( $class_name eq "IMG_PATHWAY" ) {
        push @attrs, ("pathway_name\tPathway Name\tchar\t255\tU");
        push @attrs, ("handle\tHandle\tchar\t255\tN");
        push @attrs, ("is_valid\tIs Valid?\tYes|No\t2\tN");
    } elsif ( $class_name eq "IMG_REACTION" ) {
        push @attrs, ("rxn_name\tReaction Name\tchar\t1000\tU");
        push @attrs, ("rxn_type\tReaction Type\tchar\t255\tN");
        push @attrs, ("rxn_definition\tDefinition\tchar\t4000\tN");
        push @attrs, ("rxn_equation\tEquation\tchar\t4000\tN");
        push @attrs, ("is_reversible\tIs Reversible?\tYes|No|Unknown\t3\tN");
        push @attrs, ("comments\tComments\tchar\t4000\tN");
    } elsif ( $class_name eq "IMG_TERM" ) {
        push @attrs, ("term\tIMG Term\tchar\t1000\tU");
        push @attrs,
          (
"term_type\tTerm Type\tGENE PRODUCT|MODIFIED PROTEIN|PROTEIN COMPLEX\t3\tY"
          );
        push @attrs, ("definition\tDefinition\tchar\t4000\tN");
        push @attrs, ("pubmed_id\tPubmed ID\tchar\t1000\tN");
        push @attrs, ("comments\tComments\tchar\t1000\tN");
    } elsif ( $class_name eq "PATHWAY_NETWORK" ) {
        push @attrs, ("network_name\tNetwork Name\tchar\t1000\tU");
        push @attrs, ("eqn_grammer\tEQN Grammar\tchar\t4000\tN");
        push @attrs, ("description\tDescription\tchar\t4000\tN");
        push @attrs, ("comments\tComments\tchar\t4000\tN");
        push @attrs, ("image_id\tImage ID\tchar\t50\tN");
    } elsif ( $class_name eq "PHENOTYPE_RULE" ) {
        push @attrs, ("cv_type\tCategory\tchar\t80\tN");
        push @attrs, ("cv_value\tCategory Value\tchar\t225\tN");
        push @attrs, ("description\tDescription\tchar\t255\tN");
        push @attrs, ("rule\tRule\tchar\t2000\tN");
    }

    return @attrs;
}


############################################################################
# getAttrValFromDB - get attribute values from database
############################################################################
sub getAttrValFromDB {
    my ( $class_name, $oid ) = @_;

    my %attr_val;

    # get attributes
    my $oid_name  = getOidAttr($class_name);
    my @attrs     = getAttributes($class_name);
    my @attrNames = ();
    for my $attr (@attrs) {
        my ( $n, $rest ) = split( /\t/, $attr );
        push @attrNames, ($n);
    }

    # prepare SQL
    my $sql = "select $oid_name";
    for my $attr (@attrNames) {
        $sql .= ", $attr";
    }
    $sql .= " from $class_name where $oid_name = ?";

    #print "<p>SQL: $sql</p>\n";

    my $dbh = dbLogin();

    #exec SQL
    my $cur = execSql( $dbh, $sql, $verbose, $oid );

    for ( ; ; ) {
        my (@val) = $cur->fetchrow();
        last if !$val[0];

        my $i = 0;
        while ( $i < scalar(@attrNames) && ( $i + 1 ) < scalar(@val) ) {
            if ( !blankStr( $val[ $i + 1 ] ) ) {
                $attr_val{ $attrNames[$i] } = $val[ $i + 1 ];
            }
            $i++;
        }
    }    # end for loop
    $cur->finish();

    #$dbh->disconnect();

    return %attr_val;
}



############################################################################
# getFuncId - get function id
############################################################################
sub getFuncId {
    my ( $class_name, $oid, $noPadding ) = @_;

    if ( !$noPadding ) {
        $oid = oidPadded( $class_name, $oid );            
    }

    if ( $class_name eq 'IMG_COMPOUND' ) {
        return "ICMPD:$oid";
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        return "IPWAY:$oid";
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        return "IREXN:$oid";
    } elsif ( $class_name eq 'IMG_TERM' ) {
        $oid = oidPadded( $class_name, $oid );
        return "ITERM:$oid";
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        return "PLIST:$oid";
    } elsif ( $class_name eq 'PATHWAY_NETWORK' ) {
        return "NETWK:$oid";
    } elsif ( $class_name eq 'PHENOTYPE_RULE' ) {
        return "PRULE:$oid";
    } else {
        return '';
    }
}


############################################################################
# oidPadded - Return padded value for oid
############################################################################
sub oidPadded {
    my ( $class_name, $oid ) = @_;

    if ( $class_name eq 'GENE' ) {
        return $oid;
    } elsif ( $class_name eq 'IMG_COMPOUND' ) {
        return sprintf( "%06d", $oid );
    } else {
        return sprintf( "%05d", $oid );
    }
}


############################################################################
# termOidPadded - Return padded value for term_oid.
############################################################################
sub termOidPadded {
    my ($term_oid) = @_;

    #return sprintf( "%05d", $term_oid );
    return $term_oid;
}

############################################################################
# pwayOidPadded - Return padded value for parts_list_oid.
############################################################################
sub pwayOidPadded {
    my ($pathway_oid) = @_;

    #return sprintf( "%05d", $pathway_oid );
    return $pathway_oid;
}
############################################################################
# partsListOidPadded - Return padded value for parts_list_oid.
############################################################################
sub partsListOidPadded {
    my ($parts_list_oid) = @_;

    #return sprintf( "%05d", $parts_list_oid );
    return $parts_list_oid;
}

############################################################################
# rxnOidPadded - Return padded value for rxn_oid.
############################################################################
sub rxnOidPadded {
    my ($rxn_oid) = @_;

    #return sprintf( "%05d", $rxn_oid );
    return $rxn_oid;
}

############################################################################
# compoundOidPadded - Return padded value for compound_oid.
############################################################################
sub compoundOidPadded {
    my ($compound_oid) = @_;
    return sprintf( "%06d", $compound_oid );
}


############################################################################
# funcIdToDisplayName - get class display name from function ID
############################################################################
sub funcIdToDisplayName {
    my ($func_id) = @_;
    my ( $tag, $oid ) = split( /:/, $func_id );

    if ( $tag eq 'ICMPD' ) {
        return 'IMG Compound';
    } elsif ( $tag eq 'IPWAY' ) {
        return 'IMG Pathway';
    } elsif ( $tag eq 'IREXN' ) {
        return 'IMG Reaction';
    } elsif ( $tag eq 'ITERM' ) {
        return 'IMG Term';
    } elsif ( $tag eq 'PLIST' ) {
        return 'IMG Parts List';
    } elsif ( $tag eq 'NETWK' ) {
        return 'Function Network';
    } elsif ( $tag eq 'PRULE' ) {
        return 'Phenotype Rule';
    } else {
        return "";
    }
}

############################################################################
# funcIdToClassName - get class name from function ID
############################################################################
sub funcIdToClassName {
    my ($func_id) = @_;

    my ( $tag, $oid ) = split( /:/, $func_id );

    if ( $tag eq 'ICMPD' ) {
        return 'IMG_COMPOUND';
    } elsif ( $tag eq 'IPWAY' ) {
        return 'IMG_PATHWAY';
    } elsif ( $tag eq 'IREXN' ) {
        return 'IMG_REACTION';
    } elsif ( $tag eq 'ITERM' ) {
        return 'IMG_TERM';
    } elsif ( $tag eq 'PLIST' ) {
        return "IMG_PARTS_LIST";
    } elsif ( $tag eq 'NETWK' ) {
        return 'PATHWAY_NETWORK';
    } elsif ( $tag eq 'PRULE' ) {
        return 'PHENOTYPE_RULE';
    } elsif ( $tag eq 'BC' ) {
        return 'BIO_CLUSTER_FEATURES';
    } elsif ( $tag eq 'NP' ) {
        return "NATURAL_PRODUCT";
    } else {
        if ( $func_id =~ /^GO/ ) {
            return 'GO_TERM';
        } elsif ( $func_id =~ /^COG/ ) {
            return 'COG';
        } elsif ( $func_id =~ /^KOG/ ) {
            return 'KOG';
        } elsif ( $func_id =~ /^pfam/ ) {
            return 'PFAM_FAMILY';
        } elsif ( $func_id =~ /^TIGR/ ) {
            return 'TIGRFAM';
        } elsif ( $func_id =~ /^IPR/ ) {
            return 'INTERPRO';
        } elsif ( $func_id =~ /^EC\:/ ) {
            return 'ENZYME';
        } elsif ( $func_id =~ /^TC\:/ ) {
            return 'TC_FAMILY';
        } elsif ( $func_id =~ /^KO\:/ ) {
            return 'KO_TERM';
        }

        return 'UNKNOWN';
    }
}


############################################################################
# classNameToTag - get tag from class name
############################################################################
sub classNameToTag {
    my ($class_name) = @_;

    if ( $class_name eq 'IMG_COMPOUND' ) {
        return 'ICMPD';
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        return 'IPWAY';
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        return 'IREXN';
    } elsif ( $class_name eq 'IMG_TERM' ) {
        return 'ITERM';
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        return 'PLIST';
    } elsif ( $class_name eq 'PATHWAY_NETWORK' ) {
        return 'NETWK';
    } elsif ( $class_name eq 'PHENOTYPE_RULE' ) {
        return 'PRULE';
    } else {
        return 'UNKNOWN';
    }
}


############################################################################
# classNameToDisplayName - get class display name from class name
############################################################################
sub classNameToDisplayName {
    my ($name) = @_;

    if ( $name eq "IMG_COMPOUND" ) {
        return "IMG Compound";
    } elsif ( $name eq "IMG_PARTS_LIST" ) {
        return "IMG Parts List";
    } elsif ( $name eq "IMG_PATHWAY" ) {
        return "IMG Pathway";
    } elsif ( $name eq "IMG_REACTION" ) {
        return "IMG Reaction";
    } elsif ( $name eq "IMG_TERM" ) {
        return "IMG Term";
    } elsif ( $name eq "PATHWAY_NETWORK" ) {
        return "Function Network";
    } elsif ( $name eq "GENE" ) {
        return "Gene";
    } elsif ( $name eq "PHENOTYPE_RULE" ) {
        return "Phenotype Rule";
    } else {
        return "";
    }
}

############################################################################
# classNameToAssocType - get association type from class name
############################################################################
sub classNameToAssocType {
    my ($name) = @_;

    if ( $name eq 'IMG_COMPOUND' ) {
        return 'Compound - Reaction';
    } elsif ( $name eq 'IMG_PARTS_LIST' ) {
        return 'Parts List - Term';
    } elsif ( $name eq 'IMG_PATHWAY' ) {
        return 'Pathway - Reaction';
    } elsif ( $name eq "IMG_REACTION" ) {
        return 'Reaction - Compound';
    } elsif ( $name eq 'IMG_TERM' ) {
        return 'Term - Reaction';
    } else {
        return "";
    }
}



############################################################################
# getDeleteTables - get table info for delete progation
#
# tbl1, label, a1, tbl2, a2, order_attr
############################################################################
sub getDeleteTables {
    my ($class_name) = @_;

    my @tbls = ();

    if ( $class_name eq 'IMG_COMPOUND' ) {
        push @tbls,
          (
"IMG_REACTION_C_COMPONENTS\tIMG Reaction - Compound\tcompound:Compound OID\tIMG_REACTION\trxn_oid:Reaction OID\t"
          );
        push @tbls,
          (
"IMG_PATHWAY_C_COMPONENTS\tIMG Pathway - Compound\tcompound:Compound OID\tIMG_PATHWAY\tpathway_oid:Pathway OID\t"
          );
        push @tbls,
          (
"PATHWAY_NETWORK_C_COMPONENTS\tFunction Network - Compound\tcompound:Compound OID\t\tnetwork_oid:Network OID\t"
          );
        push @tbls, ("IMG_COMPOUND_ALIASES\t\tcompound_oid\t\t\t");
        push @tbls, ("IMG_COMPOUND_KEGG_COMPOUNDS\t\tcompound_oid\t\t\t");
        push @tbls, ("IMG_COMPOUND_EXT_LINKS\t\tcompound_oid\t\t\t");
        push @tbls, ("IMG_COMPOUND_ACTIVITY\t\tcompound_oid\t\t\t");
        push @tbls, ("IMG_COMPOUND\t\tcompound_oid\t\t\t");
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        push @tbls,
          (
"IMG_PARTS_LIST_IMG_TERMS\tIMG Parts List - Term\tparts_list_oid:Parts List OID\tIMG_TERM\tterm:Term OID\tlist_order"
          );
        push @tbls,
          (
"PATHWAY_NETWORK_PARTS_LISTS\tIMG Parts List - Network\tparts_list:Parts List OID\t\tnetwork_oid:Network OID\tnetwork_oid"
          );
        push @tbls, ("IMG_PARTS_LIST\t\tparts_list_oid\t\t\t");
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        push @tbls, ("IMG_REACTION_ASSOC_PATHS\t\tpathway\t\t\t");
        push @tbls,
          (
"IMG_PATHWAY_REACTIONS\tIMG Pathway - Reaction\tpathway_oid:Pathway OID\tIMG_REACTION\trxn:Reaction OID\trxn_order"
          );
        push @tbls, ("IMG_PATHWAY_C_COMPONENTS\t\tpathway_oid\t\t\t");
        push @tbls, ("IMG_PATHWAY_T_COMPONENTS\t\tpathway_oid\t\t\t");
        push @tbls, ("IMG_PATHWAY_TAXONS\t\tpathway_oid\t\t\t");
        push @tbls, ("IMG_PATHWAY_ASSERTIONS\t\tpathway_oid\t\t\t");
        push @tbls,
          (
"PATHWAY_NETWORK_IMG_PATHWAYS\tIMG Pathway - Network\tpathway:Pathway OID\t\tnetwork_oid:Network OID\tnetwork_oid"
          );
        push @tbls, ("IMG_PATHWAY\t\tpathway_oid\t\t\t");
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        push @tbls, ("IMG_REACTION_ASSOC_RXNS\t\trxn_oid\t\t\t");
        push @tbls, ("IMG_REACTION_ASSOC_RXNS\t\trxn\t\t\t");
        push @tbls, ("IMG_REACTION_ASSOC_PATHS\t\trxn_oid\t\t\t");
        push @tbls, ("IMG_REACTION_ASSOC_NETWORKS\t\trxn_oid\t\t\t");
        push @tbls, ("IMG_REACTION_CATALYSTS\t\trxn_oid\t\t\t");
        push @tbls,
          (
"IMG_PATHWAY_REACTIONS\tIMG Pathway - Reaction\trxn: Reaction OID\tIMG_PATHWAY\tpathway_oid:Pathway OID\t"
          );
        push @tbls,
          (
"IMG_REACTION_C_COMPONENTS\tIMG Reaction - Compound\trxn_oid:Reaction OID\tIMG_COMPOUND\tcompound:Compound OID\t"
          );
        push @tbls,
          (
"IMG_REACTION_T_COMPONENTS\tIMG Reaction - Term\trxn_oid:Reaction OID\tIMG_TERM\tterm:Term OID\t"
          );
        push @tbls, ("IMG_REACTION_EXT_LINKS\t\trxn_oid\t\t\t");
        push @tbls, ("IMG_REACTION\t\trxn_oid\t\t\t");
    } elsif ( $class_name eq 'IMG_TERM' ) {
        push @tbls,
          (
"GENE_IMG_FUNCTIONS\tGene - IMG Term\tfunction:Term OID\tGENE\tgene_oid:Gene OID\t"
          );

# table removed in 2.4
#   push @tbls, ( "GENE_ALT_IMG_FUNCTIONS\tGene - Alt IMG Term\tfunction:Term OID\tGENE\tgene_oid:Gene OID\t" );

        #push @tbls, ("MCL_CLUSTER_IMG_FUNCTIONS\t\tfunction\t\t\t");
        push @tbls, ("IMG_REACTION_CATALYSTS\t\tcatalysts\t\t\t");
        push @tbls, ("IMG_REACTION_T_COMPONENTS\t\tterm\t\t\t");
        push @tbls, ("IMG_PATHWAY_T_COMPONENTS\t\tterm\t\t\t");
        push @tbls, ("PATHWAY_NETWORK_T_COMPONENTS\t\tterm\t\t\t");
        push @tbls,
          (
"IMG_PARTS_LIST_IMG_TERMS\tIMG Parts List - IMG Term\tterm:Term OID\tIMG_PARTS_LIST\tparts_list_oid:Parts List OID\t"
          );
        push @tbls,
          (
"IMG_TERM_CHILDREN\tIMG Term Parent-Child\tterm_oid:Parent Term OID\tIMG_TERM\tchild:Child Term OID\t"
          );
        push @tbls,
          (
"IMG_TERM_CHILDREN\tIMG Term Child-Parent\tchild:Child Term OID\tIMG_TERM\tterm_oid:Parent Term OID\t"
          );
        push @tbls, ("IMG_TERM_SYNONYMS\t\tterm_oid\t\t\t");
        push @tbls, ("IMG_TERM_ENZYMES\t\tterm_oid\t\t\t");
        push @tbls, ("IMG_TERM\t\tterm_oid\t\t\t");
    } elsif ( $class_name eq 'PATHWAY_NETWORK' ) {
        push @tbls,
          (
"IMG_REACTION_ASSOC_NETWORKS\tFunction Network - IMG Reaction\tnetwork:Network OID\tIMG_REACTION\trxn_oid:Reaction OID\trxn_oid"
          );
        push @tbls, ("PATHWAY_NETWORK_C_COMPONENTS\t\tnetwork_oid\t\t\t");
        push @tbls,
          (
"PATHWAY_NETWORK_IMG_PATHWAYS\tFunction Network - IMG Pathway\tnetwork_oid:Network OID\tIMG_PATHWAY\tpathway:Pathway OID\tpathway"
          );
        push @tbls,
          (
"PATHWAY_NETWORK_PARENTS\tFunction Network Parent-Child\tparent:Parent\tPATHWAY_NETWORK\tnetwork_oid:Child\tparent"
          );
        push @tbls,
          (
"PATHWAY_NETWORK_PARENTS\tFunction Network Child-Parent\tnetwork_oid:Child\tPATHWAY_NETWORK\tparent:Parent\tnetwork_oid"
          );
        push @tbls, ("PATHWAY_NETWORK_TAXONS\t\tnetwork_oid\t\t\t");
        push @tbls, ("PATHWAY_NETWORK_T_COMPONENTS\t\tnetwork_oid\t\t\t");
        push @tbls, ("PATHWAY_NETWORK\t\tnetwork_oid\t\t\t");
    } elsif ( $class_name eq 'PHENOTYPE_RULE' ) {
        push @tbls, ("phenotype_rule\t\trule_id\t\t\t");
    }

    return @tbls;
}

############################################################################
# getAssocAttributes - get association attribute definition of a class
############################################################################
sub getAssocAttributes {
    my ($class_name) = @_;

    my @attrs = ();

    if ( $class_name eq "IMG_COMPOUND" ) {
        push @attrs, ("rxn_oid\tReaction OID\tint\t5\tU\tIMG_REACTION");
        push @attrs, ("rxn_name\tReaction Name\tchar\t60\tN\t");
        push @attrs, ("c_type\tLeft/Right?\tLHS|RHS\t60\tY\t#eed0d0");
        push @attrs, ("main_flag\tIs Main?\tYes|No|Unknown\t80\tY\t#aaaabb");
        push @attrs, ("stoich\tStoichiometry Value\tint\t4\tY\t");
    } elsif ( $class_name eq "IMG_PARTS_LIST" ) {
        push @attrs, ("term\tTerm OID\tint\t5\tU\tIMG_TERM");
        push @attrs, ("term_name\tTerm\tchar\t60\tN\t");
        push @attrs, ("list_order\tList Order\torder\t4\tY\t");
    } elsif ( $class_name eq "IMG_PATHWAY" ) {
        push @attrs, ("rxn\tReaction OID\tint\t5\tU\tIMG_REACTION");
        push @attrs, ("rxn_name\tReaction Name\tchar\t60\tN\t");
        push @attrs, ("is_mandatory\tIs Mandatory?\tYes|No\t64\tY\t#33ee99");
        push @attrs, ("rxn_order\tReaction Order\torder\t4\tY\t");
    } elsif ( $class_name eq "IMG_REACTION" ) {
        push @attrs, ("compound\tCompound OID\tint\t5\tU\tIMG_COMPOUND");
        push @attrs, ("compound_name\tCompound Name\tchar\t60\tN\t");
        push @attrs, ("c_type\tLeft/Right?\tLHS|RHS\t60\tY\t#eed0d0");
        push @attrs, ("main_flag\tIs Main?\tYes|No|Unknown\t80\tY\t#aaaabb");
        push @attrs, ("stoich\tStoichiometry Value\tint\t4\tY\t");
        push @attrs,
          (
"sub_cell_loc\tSub-cell Localization\tCV:CELL_LOCALIZATION:loc_type\t200\tY\t"
          );
    } elsif ( $class_name eq "IMG_TERM" ) {
        push @attrs, ("rxn_oid\tReaction OID\tint\t5\tU\tIMG_REACTION");
        push @attrs, ("rxn_name\tReaction Name\tchar\t60\tN\t");
        push @attrs,
          (
"c_type\tAssociation_Type\tCatalyst|Product|Substrate\t64\tY\t#99e009"
          );
        push @attrs,
          (
"sub_cell_loc\tSub-cell Localization\tCV:CELL_LOCALIZATION:loc_type\t200\tY\t"
          );
    }

    return @attrs;
}

############################################################################
# getUrl - return URL based on class_name and oid
############################################################################
sub getUrl {
    my ( $main_cgi, $class_name, $oid ) = @_;

    my $url = "";

    if ( $class_name eq 'GENE' ) {
        $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$oid";
    } elsif ( $class_name eq 'IMG_COMPOUND' ) {
        $url =
          "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$oid";
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        $url =
"$main_cgi?section=ImgPartsListBrowser&page=partsListDetail&parts_list_oid=$oid";
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        $url =
          "$main_cgi?section=ImgPwayBrowser&page=imgPwayDetail&pway_oid=$oid";
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        $url = "$main_cgi?section=ImgReaction&page=imgRxnDetail&rxn_oid=$oid";
    } elsif ( $class_name eq 'IMG_TERM' ) {
        $url =
          "$main_cgi?section=ImgTermBrowser&page=imgTermDetail&term_oid=$oid";
    } elsif ( $class_name eq 'PATHWAY_NETWORK' ) {
        $url =
"$main_cgi?section=ImgNetworkBrowser&page=pathwayNetworkDetail&network_oid=$oid";
    } elsif ( $class_name eq 'PHENOTYPE_RULE' ) {
        $url =
"$main_cgi?section=CuraCartDataEntry&page=PhenotypeRuleDetail&rule_id=$oid";
    }

    return $url;
}

############################################################################
# getSearchQuery - get keyword search query
############################################################################
sub getSearchQuery {
    my ( $class_name, $searchKey ) = @_;

    my $searchTerm = lc($searchKey);    # use case insensitive search

    my $sql = "";
    my @bindList = ();

    if ( $class_name eq 'IMG_COMPOUND' ) {

        #   $sql = qq{
        #       select compound_oid, compound_name, common_name
        #       from img_compound
        #       where lower(compound_name) like '%$searchTerm%'
        #       or lower(common_name) like '%$searchTerm%'
        #       or compound_oid in
        #       (select ica.compound_oid
        #        from img_compound_aliases ica
        #        where lower(aliases) like '%$searchTerm%')
        #       };

        $sql = qq{
            select compound_oid, compound_name, common_name
            from img_compound
            where lower(compound_name) like '%$searchTerm%' 
            or lower(common_name) like '%$searchTerm%'
            order by compound_oid
        };
        #push(@bindList, "%$searchTerm%");
        #push(@bindList, "%$searchTerm%");      
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        $sql = qq{ 
            select ipr.parts_list_oid, ipr.parts_list_name, ipr.definition 
                from img_parts_list ipr
                    where lower( ipr.parts_list_name ) like '%$searchTerm%'
                        or lower( ipr.definition ) like '%$searchTerm%'
            order by ipr.parts_list_oid
        };
        #push(@bindList, "%$searchTerm%");
        #push(@bindList, "%$searchTerm%");       
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        $sql = qq{ 
            select ip.pathway_oid, ip.pathway_name
                from img_pathway ip 
                    where lower( ip.pathway_name ) like '%$searchTerm%' 
            order by ip.pathway_oid
        };
        #push(@bindList, "%$searchTerm%");
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        $sql = qq{ 
            select ir.rxn_oid, ir.rxn_name, ir.rxn_definition 
                from img_reaction ir 
                    where lower( ir.rxn_name ) like '%$searchTerm%' 
                        or lower( ir.rxn_definition ) like '%$searchTerm%'
            order by ir.rxn_oid
        };
        #push(@bindList, "%$searchTerm%");
        #push(@bindList, "%$searchTerm%");       
    } elsif ( $class_name eq 'IMG_TERM' ) {
        $sql = qq{
        select it.term_oid, it.term
        from img_term it
        where lower(term) like '%$searchTerm%' 
        or it.term_oid in
        (select its.term_oid
         from img_term_synonyms its
         where lower(term) like '%$searchTerm%' )
        order by it.term_oid
        };
        #push(@bindList, "%$searchTerm%");
        #push(@bindList, "%$searchTerm%");       
    } elsif ( $class_name eq 'PATHWAY_NETWORK' ) {
        $sql = qq{ 
        select pn.network_oid, pn.network_name, pn.description
                from pathway_network pn
                    where lower( pn.network_name ) like '%$searchTerm%' 
                        or lower( pn.description ) like '%$searchTerm%'
            order by pn.network_oid
        };
        #push(@bindList, "%$searchTerm%");
        #push(@bindList, "%$searchTerm%");       
    } elsif ( $class_name eq 'PHENOTYPE_RULE' ) {
        $sql = qq{ 
            select pr.rule_id, pr.name, pr.description
                from phenotype_rule pr
                    where lower( pr.name ) like '%$searchTerm%'
                        or lower( pr.description ) like '%$searchTerm%'
            order by pr.rule_id
        };
        #push(@bindList, "%$searchTerm%");
        #push(@bindList, "%$searchTerm%");       
    }

    return ($sql, @bindList);
}

############################################################################
# getSearchDefAttr - get "definition" attribute name for search result
############################################################################
sub getSearchDefAttr {
    my ($class_name) = @_;

    if ( $class_name eq 'IMG_COMPOUND' ) {
        return 'Common Name';
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        return 'Definition';
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        return '';
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        return 'Definition';
    } elsif ( $class_name eq 'IMG_TERM' ) {
        return 'Synonym';
    } elsif ( $class_name eq 'PATHWAY_NETWORK' ) {
        return 'Description';
    } elsif ( $class_name eq 'PHENOTYPE_RULE' ) {
        return 'Description';
    }

    return '';
}

############################################################################
# getListAllQuery - query to get all instances
############################################################################
sub getListAllQuery {
    my ($class_name) = @_;

    my $sql = "";

    if ( $class_name eq 'IMG_COMPOUND' ) {
        $sql = qq{
        select compound_oid, compound_name, common_name
        from img_compound
        order by compound_oid
        };
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        $sql = qq{ 
        select ipr.parts_list_oid, ipr.parts_list_name, ipr.definition 
                from img_parts_list ipr
        order by ipr.parts_list_oid
        };
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        $sql = qq{ 
        select ip.pathway_oid, ip.pathway_name
                from img_pathway ip 
        order by ip.pathway_oid
        };
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        $sql = qq{ 
        select ir.rxn_oid, ir.rxn_name, ir.rxn_definition 
                from img_reaction ir 
        order by ir.rxn_oid
        };
    } elsif ( $class_name eq 'IMG_TERM' ) {
        $sql = qq{
        select it.term_oid, it.term
        from img_term it
        order by it.term_oid
        };
    } elsif ( $class_name eq 'PATHWAY_NETWORK' ) {
        $sql = qq{ 
        select pn.network_oid, pn.network_name, pn.description
                from pathway_network pn
        order by pn.network_oid
        };
    } elsif ( $class_name eq 'PHENOTYPE_RULE' ) {
        $sql = qq{ 
        select pr.rule_id, pr.name, pr.description
                from phenotype_rule pr
        order by pr.rule_id
        };
    }

    return $sql;
}

############################################################################
# getAdvSearchAttributes - get attribute definition for advanced search
############################################################################
sub getAdvSearchAttributes {
    my ($class_name) = @_;

    my %attrs;

    if ( $class_name eq "IMG_COMPOUND" ) {
        $attrs{'r0.compound_oid'}  = "Compound OID\t$class_name\tr0\tint\t";
        $attrs{'r0.compound_name'} = "Compound Name\t$class_name\tr0\tchar\t";
        $attrs{'r0.db_source'}     = "DB Source\t$class_name\tr0\tchar\t";
        $attrs{'r0.ext_accession'} = "Ext Accession\t$class_name\tr0\tchar\t";
        $attrs{'r0.common_name'}   = "Common Name\t$class_name\tr0\tchar\t";
        $attrs{'r0.class'}         = "Class\t$class_name\tr0\tchar\t";
        $attrs{'r0.composition'}   = "Composition\t$class_name\tr0\tchar\t";
        $attrs{'r0.formula'}       = "Formula\t$class_name\tr0\tchar\t";
        $attrs{'r0.cas_number'}    = "CAS Number\t$class_name\tr0\tchar\t";
        $attrs{'r0.status'}        = "Status\t$class_name\tr0\tchar\t";
        $attrs{'r0.add_date'}      = "Add Date\t$class_name\tr0\tdate\t";
        $attrs{'r0.mod_date'}      = "Modify Date\t$class_name\tr0\tdate\t";
        $attrs{'r1.name'}          =
          "Modified By\tCONTACT\tr1\tchar\tr0.modified_by = r1.contact_oid";
    } elsif ( $class_name eq "IMG_PARTS_LIST" ) {
        $attrs{'r0.parts_list_oid'}  = "Parts List OID\t$class_name\tr0\tint\t";
        $attrs{'r0.parts_list_name'} =
          "Parts List Name\t$class_name\tr0\tchar\t";
        $attrs{'r0.definition'} = "Definition\t$class_name\tr0\tchar\t";
        $attrs{'r0.add_date'}   = "Add Date\t$class_name\tr0\tdate\t";
        $attrs{'r0.mod_date'}   = "Modify Date\t$class_name\tr0\tdate\t";
        $attrs{'r1.name'}       =
          "Modified By\tCONTACT\tr1\tchar\tr0.modified_by = r1.contact_oid";
    } elsif ( $class_name eq "IMG_PATHWAY" ) {
        $attrs{'r0.pathway_oid'}  = "Pathway OID\t$class_name\tr0\tint\t";
        $attrs{'r0.pathway_name'} = "Pathway Name\t$class_name\tr0\tchar\t";
        $attrs{'r0.handle'}       = "Handle\t$class_name\tr0\tchar\t";
        $attrs{'r0.is_valid'}     = "Is Valid?\t$class_name\tr0\tchar\t";
        $attrs{'r0.add_date'}     = "Add Date\t$class_name\tr0\tdate\t";
        $attrs{'r0.mod_date'}     = "Modify Date\t$class_name\tr0\tdate\t";
        $attrs{'r1.name'}         =
          "Modified By\tCONTACT\tr1\tchar\tr0.modified_by = r1.contact_oid";
    } elsif ( $class_name eq "IMG_REACTION" ) {
        $attrs{'r0.rxn_oid'}        = "Reaction OID\t$class_name\tr0\tint\t";
        $attrs{'r0.rxn_name'}       = "Reaction Name\t$class_name\tr0\tchar\t";
        $attrs{'r0.rxn_definition'} = "Definition\t$class_name\tr0\tchar\t";
        $attrs{'r0.rxn_equation'}   = "Equation\t$class_name\tr0\tchar\t";
        $attrs{'r0.is_reversible'}  = "Is Reversible?\t$class_name\tr0\tchar\t";
        $attrs{'r0.comments'}       = "Comments\t$class_name\tr0\tchar\t";
        $attrs{'r0.add_date'}       = "Add Date\t$class_name\tr0\tdate\t";
        $attrs{'r0.mod_date'}       = "Modify Date\t$class_name\tr0\tdate\t";
        $attrs{'r1.name'}           =
          "Modified By\tCONTACT\tr1\tchar\tr0.modified_by = r1.contact_oid";
    } elsif ( $class_name eq "IMG_TERM" ) {
        $attrs{'r0.term_oid'}   = "Term OID\t$class_name\tr0\tint\t";
        $attrs{'r0.term'}       = "Term\t$class_name\tr0\tchar\t";
        $attrs{'r0.term_type'}  = "Term Type\t$class_name\tr0\tchar\t";
        $attrs{'r0.definition'} = "Definition\t$class_name\tr0\tchar\t";
        $attrs{'r0.pubmed_id'}  = "Pubmed ID\t$class_name\tr0\tchar\t";
        $attrs{'r0.comments'}   = "Comments\t$class_name\tr0\tchar\t";
        $attrs{'r0.add_date'}   = "Add Date\t$class_name\tr0\tdate\t";
        $attrs{'r0.mod_date'}   = "Modify Date\t$class_name\tr0\tdate\t";
        $attrs{'r1.name'}       =
          "Modified By\tCONTACT\tr1\tchar\tr0.modified_by = r1.contact_oid";

 #  $attrs{'r2.f_flag'} = "Flag\tIMG_TERM\tr0\tchar\tr0.term_oid *= r2.function";
    } elsif ( $class_name eq "PATHWAY_NETWORK" ) {
        $attrs{'r0.network_oid'}  = "Network OID\t$class_name\tr0\tint\t";
        $attrs{'r0.network_name'} = "Network Name\t$class_name\tr0\tchar\t";
        $attrs{'r0.eqn_grammer'}  = "EQN Grammar\t$class_name\tr0\tchar\t";
        $attrs{'r0.description'}  = "Description\t$class_name\tr0\tchar\t";
        $attrs{'r0.comments'}     = "Comments\t$class_name\tr0\tchar\t";
        $attrs{'r0.image_id'}     = "Image ID\t$class_name\tr0\tchar\t";
        $attrs{'r0.add_date'}     = "Add Date\t$class_name\tr0\tdate\t";
        $attrs{'r0.mod_date'}     = "Modify Date\t$class_name\tr0\tdate\t";
        $attrs{'r1.name'}         =
          "Modified By\tCONTACT\tr1\tchar\tr0.modified_by = r1.contact_oid";
    } elsif ( $class_name eq "GENE" ) {
        $attrs{'r0.gene_oid'}          = "Gene OID\t$class_name\tr0\tint\t";
        $attrs{'r0.gene_symbol'}       = "Gene Symbol\t$class_name\tr0\tchar\t";
        $attrs{'r0.gene_display_name'} =
          "Gene Display Name\t$class_name\tr0\tchar\t";
        $attrs{'r0.product_name'} = "Product Name\t$class_name\tr0\tchar\t";
        $attrs{'r0.locus_tag'}    = "Locus Tag\t$class_name\tr0\tchar\t";
        $attrs{'r0.locus_type'}   = "Locus Type\t$class_name\tr0\tchar\t";
        $attrs{'r0.protein_seq_accid'} =
          "Protein Acc ID\t$class_name\tr0\tchar\t";
        $attrs{'r0.taxon'}       = "Taxon OID\t$class_name\tr0\tint\t";
        $attrs{'r2.taxon_.name'} =
          "Taxon Name\tTAXON\tr1\tchar\tr0.taxon = r2.taxon_oid";
        $attrs{'r0.add_date'} = "Add Date\t$class_name\tr0\tdate\t";
        $attrs{'r0.mod_date'} = "Modify Date\t$class_name\tr0\tdate\t";
        $attrs{'r1.name'}     =
          "Modified By\tCONTACT\tr1\tchar\tr0.modified_by = r1.contact_oid";
    }

    return %attrs;
}

############################################################################
# getAdvSearchRelations
############################################################################
sub getAdvSearchRelations {
    my ($class_name) = @_;

    my @rels;

    if ( $class_name eq 'IMG_COMPOUND' ) {
        push @rels,
          (
"IMG_COMPOUND_KEGG_COMPOUNDS\tr11\tcompound_oid\tKEGG Compound Associations"
          );
        push @rels,
          (
"IMG_REACTION_C_COMPONENTS\tr12\tcompound\tReaction - Compound Associations"
          );
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        push @rels,
          (
"IMG_PARTS_LIST_IMG_TERMS\tr11\tparts_list_oid\tParts List - Term Associations"
          );
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        push @rels,
          (
"IMG_PATHWAY_REACTIONS\tr11\tpathway_oid\tPathway - Reaction Associations"
          );
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        push @rels,
          ("IMG_PATHWAY_REACTIONS\tr11\trxn\tPathway - Reaction Associations");
        push @rels,
          (
"IMG_REACTION_C_COMPONENTS\tr12\trxn_oid\tReaction - Compound Associations"
          );

#   push @rels, ( "IMG_REACTION_T_COMPONENTS\tr13\trxn_oid\tReaction - Term Associations" );
    } elsif ( $class_name eq 'IMG_TERM' ) {
        push @rels,
          ("GENE_IMG_FUNCTIONS\tr11\tfunction\tGene - Term Associations");
        push @rels, ("IMG_TERM_SYNONYMS\tr12\tterm_oid\tSynonyms");
    } elsif ( $class_name eq 'PATHWAY_NETWORK' ) {
        push @rels,
          (
"PATHWAY_NETWORK_IMG_PATHWAYS\tr11\tnetwork_oid\tFunction Network - Pathway Associations"
          );
    } elsif ( $class_name eq 'GENE' ) {
        push @rels,
          ("GENE_IMG_FUNCTIONS\tr11\tgene_oid\tGene - Term Associations");
    }

    return @rels;
}

############################################################################
# getAdvSearchSetAttrs - get set-valued attribute definition for
#                        advanced search
############################################################################
sub getAdvSearchSetAttrs {
    my ( $class_name, $set_name ) = @_;

    my %attrs;

    if ( $class_name eq 'IMG_COMPOUND' ) {
        if ( $set_name eq 'IMG_COMPOUND_KEGG_COMPOUNDS' ) {
            $attrs{'r11.compound'} = "KEGG Compound\t$set_name\tr11\tchar\t";
            $attrs{'r11.mod_date'} = "Modify Date\t$set_name\tr11\tdate\t";
            $attrs{'r21.name'}     =
"Modified By\tCONTACT\tr21\tchar\tr11.modified_by = r21.contact_oid";
        } elsif ( $set_name eq 'IMG_REACTION_C_COMPONENTS' ) {
            $attrs{'r12.c_type'}   = "Type (LHS|RHS)\t$set_name\tr12\tchar\t";
            $attrs{'r12.rxn_oid'}  = "Reaction OID\t$set_name\tr12\tint\t";
            $attrs{'r22.rxn_name'} =
"Reaction Name\tIMG_REACTION\tr22\tchar\tr12.rxn_oid = r22.rxn_oid";
            $attrs{'r12.main_flag'} =
              "Is Main? (Yes|No|Unknown)\t$set_name\tr12\tchar\t";
            $attrs{'r12.stoich'} = "Stoichiometry Value\t$set_name\tr12\tint\t";
        }
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        if ( $set_name eq 'IMG_PARTS_LIST_IMG_TERMS' ) {
            $attrs{'r11.list_order'} = "List Order\t$set_name\tr11\tint\t";
            $attrs{'r11.term'}       = "Term OID\t$set_name\tr11\tint\t";
            $attrs{'r22.term'}       =
              "Term Name\tIMG_TERM\tr22\tchar\tr11.term = r22.term_oid";
        }
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        if ( $set_name eq 'IMG_PATHWAY_REACTIONS' ) {
            $attrs{'r11.rxn_order'} = "Reaction Order\t$set_name\tr11\tint\t";
            $attrs{'r11.rxn'}       = "Reaction OID\t$set_name\tr11\tint\t";
            $attrs{'r22.rxn_name'}  =
              "Reaction Name\tIMG_REACTION\tr22\tchar\tr11.rxn = r22.rxn_oid";
            $attrs{'r11.is_mandatory'} =
              "Is Mandatory?\t$set_name\tr11\tchar\t";
        }
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        if ( $set_name eq 'IMG_PATHWAY_REACTIONS' ) {
            $attrs{'r11.rxn_order'}   = "Reaction Order\t$set_name\tr11\tint\t";
            $attrs{'r11.pathway_oid'} = "Pathway OID\t$set_name\tr11\tint\t";
            $attrs{'r21.pathway_name'} =
"Pathway Name\tIMG_PATHWAY\tr21\tchar\tr11.pathway_oid = r21.pathway_oid";
            $attrs{'r11.is_mandatory'} =
              "Is Mandatory?\t$set_name\tr11\tchar\t";
        } elsif ( $set_name eq 'IMG_REACTION_C_COMPONENTS' ) {
            $attrs{'r12.c_type'}   = "Type (LHS|RHS)\t$set_name\tr12\tchar\t";
            $attrs{'r12.compound'} = "Compound OID\t$set_name\tr12\tint\t";
            $attrs{'r22.compound_name'} =
"Compound Name\tIMG_COMPOUND\tr22\tchar\tr12.compound = r22.compound_oid";
            $attrs{'r12.main_flag'} =
              "Is Main? (Yes|No|Unknown)\t$set_name\tr12\tchar\t";
            $attrs{'r12.stoich'} = "Stoichiometry Value\t$set_name\tr12\tint\t";
        }
    } elsif ( $class_name eq 'IMG_TERM' ) {
        if ( $set_name eq 'GENE_IMG_FUNCTIONS' ) {
            $attrs{'r11.f_flag'}     = "F_flag\t$set_name\tr11\tchar\t";
            $attrs{'r11.f_order'}    = "F_order\t$set_name\tr11\tint\t";
            $attrs{'r11.evidence'}   = "Evidence\t$set_name\tr11\tchar\t";
            $attrs{'r11.confidence'} = "Confidence\t$set_name\tr11\tchar\t";
            $attrs{'r11.mod_date'}   = "Modify Date\t$set_name\tr11\tdate\t";
            $attrs{'r21.name'}       =
"Modified By\tCONTACT\tr21\tchar\tr11.modified_by = r21.contact_oid";
        } elsif ( $set_name eq 'IMG_TERM_SYNONYMS' ) {
            $attrs{'r12.synonyms'} = "Synonym\t$set_name\tr12\tchar\t";
            $attrs{'r12.add_date'} = "Add Date\t$set_name\tr12\tdate\t";
            $attrs{'r12.mod_date'} = "Modify Date\t$set_name\tr12\tdate\t";
            $attrs{'r22.name'}     =
"Modified By\tCONTACT\tr22\tchar\tr12.modified_by = r22.contact_oid";
        }
    } elsif ( $class_name eq 'PATHWAY_NETWORK' ) {
        if ( $set_name eq 'PATHWAY_NETWORK_IMG_PATHWAYS' ) {
            $attrs{'r11.pathway'}      = "Pathway OID\t$set_name\tr11\tint\t";
            $attrs{'r22.pathway_name'} =
"Pathway Name\tIMG_PATHWAY\tr22\tchar\tr11.pathway = r22.pathway_oid";
            $attrs{'r11.mod_date'} = "Modify Date\t$set_name\tr11\tdate\t";
            $attrs{'r21.name'}     =
"Modified By\tCONTACT\tr21\tchar\tr11.modified_by = r21.contact_oid";
        }
    } elsif ( $class_name eq 'GENE' ) {
        if ( $set_name eq 'GENE_IMG_FUNCTIONS' ) {
            $attrs{'r11.f_flag'}     = "F_flag\t$set_name\tr11\tchar\t";
            $attrs{'r11.f_order'}    = "F_order\t$set_name\tr11\tint\t";
            $attrs{'r11.evidence'}   = "Evidence\t$set_name\tr11\tchar\t";
            $attrs{'r11.confidence'} = "Confidence\t$set_name\tr11\tchar\t";
            $attrs{'r11.mod_date'}   = "Modify Date\t$set_name\tr11\tdate\t";
            $attrs{'r21.name'}       =
"Modified By\tCONTACT\tr21\tchar\tr11.modified_by = r21.contact_oid";
        }
    }

    return %attrs;
}

############################################################################
# getAssocQuery - get association query
############################################################################
sub getAssocQuery {
    my ( $class_name, $oid ) = @_;

    my $sql = "";

    if ( $class_name eq 'IMG_COMPOUND' ) {
        $sql = qq{ 
        select ircc.rxn_oid, r.rxn_name, ircc.c_type, ircc.main_flag,
        ircc.stoich
        from img_reaction_c_components ircc, img_reaction r
        where ircc.compound = $oid
        and ircc.rxn_oid = r.rxn_oid
        order by ircc.rxn_oid
        };
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        $sql = qq{ 
        select ipt.term, t.term, ipt.list_order
        from img_parts_list_img_terms ipt, img_term t
        where ipt.parts_list_oid = $oid
        and ipt.term = t.term_oid
        order by ipt.list_order, ipt.term
        };
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        $sql = qq{ 
        select ipr.rxn, r.rxn_name, ipr.is_mandatory, ipr.rxn_order
        from img_pathway_reactions ipr, img_reaction r
        where ipr.pathway_oid = $oid
        and ipr.rxn = r.rxn_oid
        order by ipr.rxn_order, ipr.rxn
        };
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        $sql = qq{ 
        select ircc.compound, c.compound_name, ircc.c_type,
        ircc.main_flag, ircc.stoich, ircc.sub_cell_loc
        from img_reaction_c_components ircc, img_compound c
        where ircc.rxn_oid = $oid
        and ircc.compound = c.compound_oid
        order by ircc.compound
        };
    } elsif ( $class_name eq 'IMG_TERM' ) {
        $sql = qq{
        select irc.rxn_oid, ir.rxn_name, 'Catalyst', ''
        from img_reaction_catalysts irc, img_reaction ir
        where irc.catalysts = $oid
        and irc.rxn_oid = ir.rxn_oid
        union select irtc.rxn_oid, ir2.rxn_name,
        decode(upper(irtc.c_type), 'LHS', 'Substrate', 'RHS',
               'Product', ''), irtc.sub_cell_loc
        from img_reaction_t_components irtc, img_reaction ir2
        where irtc.term = $oid
        and irtc.rxn_oid = ir2.rxn_oid
        };
    }

    return $sql;
}

############################################################################
# getAssocTable - get association table name
############################################################################
sub getAssocTable {
    my ($class_name) = @_;

    my $t_name = "";

    if ( $class_name eq 'IMG_COMPOUND' ) {
        $t_name = "img_reaction_c_components";
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        $t_name = "img_parts_list_img_terms";
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        $t_name = "img_pathway_reactions";
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        $t_name = "img_reaction_c_components";
    } elsif ( $class_name eq 'IMG_TERM' ) {
        $t_name = "img_reaction_t_components";
    }

    return $t_name;
}

############################################################################
# getAssocTableKey - get key attribute of association table name
############################################################################
sub getAssocTableKey {
    my ($class_name) = @_;

    my $k_name = "";

    if ( $class_name eq 'IMG_COMPOUND' ) {
        $k_name = "compound";
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        $k_name = "parts_list_oid";
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        $k_name = "pathway_oid";
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        $k_name = "rxn_oid";
    } elsif ( $class_name eq 'IMG_TERM' ) {
        $k_name = "term";
    }

    return $k_name;
}

############################################################################
# getAssocClass - get association class
############################################################################
sub getAssocClass {
    my ($class_name) = @_;

    my $cl2 = "";

    if ( $class_name eq 'IMG_COMPOUND' ) {
        $cl2 = "IMG_REACTION";
    } elsif ( $class_name eq 'IMG_PARTS_LIST' ) {
        $cl2 = "IMG_TERM";
    } elsif ( $class_name eq 'IMG_PATHWAY' ) {
        $cl2 = "IMG_REACTION";
    } elsif ( $class_name eq 'IMG_REACTION' ) {
        $cl2 = "IMG_COMPOUND";
    } elsif ( $class_name eq 'IMG_TERM' ) {
        $cl2 = "IMG_REACTION";
    }

    return $cl2;
}

############################################################################
# getUploadAttributes - get upload file attribute definition
############################################################################
sub getUploadAttributes {
    my ($file_type) = @_;

    my @attrs = ();

    if ( $file_type eq 'cr' ) {

        # compound - reaction
        push @attrs, ("compound\tCompound OID\tint\t5\tU\tIMG_COMPOUND");
        push @attrs, ("rxn_oid\tReaction OID\tint\t5\tU\tIMG_REACTION");
        push @attrs, ("c_type\tLHS/RHS?\tLHS|RHS\t60\tY\t#eed0d0");
        push @attrs, ("main_flag\tIs Main?\tYes|No|Unknown\t80\tY\t#aaaabb");
        push @attrs, ("stoich\tStoichiometry Value\tint\t4\tY\t");
    } elsif ( $file_type eq 'pt' ) {

        # parts list - term
        push @attrs,
          ("parts_list_oid\tParts List OID\tint\t5\tU\tIMG_PARTS_LIST");
        push @attrs, ("term\tTerm OID\tint\t5\tU\tIMG_TERM");
        push @attrs, ("list_order\tList Order\torder\t4\tR\t");
    } elsif ( $file_type eq 'pr' ) {

        # pathway - reaction
        push @attrs, ("pathway_oid\tPathway OID\tint\t5\tU\tIMG_PATHWAY");
        push @attrs, ("rxn\tReaction OID\tint\t5\tU\tIMG_REACTION");
        push @attrs, ("is_mandatory\tIs Mandatory?\tYes|No\t64\tY\t#33ee99");
        push @attrs, ("rxn_order\tReaction Order\torder\t4\tR\t");
    } elsif ( $file_type eq 'tr' ) {

        # term - reaction
        push @attrs, ("term_oid\tTerm OID\tint\t5\tU\tIMG_TERM");
        push @attrs, ("rxn_oid\tReaction OID\tint\t5\tU\tIMG_REACTION");
        push @attrs,
          (
"a_type\tAssociation Type\tCatalyst|Substrate|Product\t60\tR\t#eed0d0"
          );
    }

    return @attrs;
}

############################################################################
# getUploadDisplayType - upload file type to display
############################################################################
sub getUploadDisplayType {
    my ($file_type) = @_;

    my $display_type = '';

    if ( $file_type eq 'cr' ) {
        $display_type = 'Compound - Reaction';
    } elsif ( $file_type eq 'pt' ) {
        $display_type = 'Parts List - Term';
    } elsif ( $file_type eq 'pr' ) {
        $display_type = 'Pathway - Reaction';
    } elsif ( $file_type eq 'tr' ) {
        $display_type = 'Term - Reaction';
    }

    return $display_type;
}

############################################################################
# getUploadTable - get upload table name
############################################################################
sub getUploadTable {
    my ($file_type) = @_;

    my $t_name = '';

    if ( $file_type eq 'cr' ) {
        $t_name = 'IMG_REACTION_C_COMPONENTS';
    } elsif ( $file_type eq 'pt' ) {
        $t_name = 'IMG_PARTS_LIST_IMG_TERMS';
    } elsif ( $file_type eq 'pr' ) {
        $t_name = 'IMG_PATHWAY_REACTIONS';
    } elsif ( $file_type eq 'tr' ) {
        $t_name = 'IMG_REACTION_T_COMPONENTS';
    }

    return $t_name;
}

############################################################################
# getUploadAttr1 - get attribute 1 of upload file
############################################################################
sub getUploadAttr1 {
    my ($file_type) = @_;

    my $a_name = "";

    if ( $file_type eq 'cr' ) {
        $a_name = 'compound';
    } elsif ( $file_type eq 'pt' ) {
        $a_name = 'parts_list_oid';
    } elsif ( $file_type eq 'pr' ) {
        $a_name = 'pathway_oid';
    } elsif ( $file_type eq 'tr' ) {
        $a_name = 'term';
    }

    return $a_name;
}

############################################################################
# getUploadAttr2 - get attribute 2 of upload file
############################################################################
sub getUploadAttr2 {
    my ($file_type) = @_;

    my $a_name = "";

    if ( $file_type eq 'cr' ) {
        $a_name = 'rxn_oid';
    } elsif ( $file_type eq 'pt' ) {
        $a_name = 'term';
    } elsif ( $file_type eq 'pr' ) {
        $a_name = 'rxn';
    } elsif ( $file_type eq 'tr' ) {
        $a_name = 'rxn_oid';
    }

    return $a_name;
}


1;
