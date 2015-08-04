############################################################################
#
# Also, see PhyloNode::printSelectButton for which level of nodes name
# can be edited.
#
# $Id: TaxonEdit.pm 30606 2014-04-10 20:27:50Z klchu $
############################################################################
package TaxonEdit;
my $section = "TaxonEdit";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use TaxonSearchUtil;
use TaxonList;
use InnerTable_yui;
use Class::Struct;

$| = 1;

my $env                  = getEnv();
my $cgi_dir              = $env->{cgi_dir};
my $tmp_url              = $env->{tmp_url};
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_url             = $env->{base_url};
my $web_data_dir         = $env->{web_data_dir};
my $img_internal         = $env->{img_internal};
my $user_restricted_site = $env->{user_restricted_site};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $oracle_home          = $ENV{ORACLE_HOME};
my $sqlldr               = "$oracle_home/bin/sqlldr";
my $img_taxon_edit       = $env->{img_taxon_edit};

# ER url and starting taxon oid
# 2,000,000,000
my $er_start_taxon_oid = "2000000000";
my $er_cgi_url         = $ENV{er_cgi_url};

# taxon domian order
my @domainList = ( "domain", "phylum", "ir_class", "ir_order", "family", "genus", "species" );

my $unclassified = "unclassified";

my $YUI = $env->{yui_dir_28};

# oracle config stuff
my $img_i_taxon_oracle_config = $env->{img_i_taxon_oracle_config};
my $maxClobSize               = 38000;
my $oracle_config             = $env->{img_i_taxon_oracle_config};
require $oracle_config if $oracle_config ne "";
my ( $dsn,      $user,     $pw );
my ( $ora_port, $ora_host, $ora_sid );
if ( $oracle_config ne "" ) {
    $dsn      = $ENV{ORA_DBI_DSN};
    $user     = $ENV{ORA_USER};
    $pw       = $ENV{ORA_PASSWORD};
    $ora_port = $ENV{ORA_PORT};
    $ora_host = $ENV{ORA_HOST};
    $ora_sid  = $ENV{ORA_SID};
}
my $service = $ENV{ORA_SERVICE};

#
#
#
struct Phylum => {
    taxon_oid          => '$',
    taxon_display_name => '$',
    ncbi_taxon_id      => '$',
    phylum             => '$',
    ir_class           => '$',
    ir_order           => '$',
    family             => '$',
    genus              => '$',
    species            => '$',
    domain             => '$'
};

my $allncbi_file = $env->{allncbi_file};    #"/home/ken/allncbi.txt";

# see PhyloNode::getDomainString
my $delimiter = ",_,";                      # get url delimiter for phyla

# js select box delimiter for values
my $delimiter_selectbox = ";";

sub dispatch {

    my $page = param("page");

    # what is the value? - "Yes"
    my $user_status = getSuperUser();

    if (   $user_restricted_site
        && $img_i_taxon_oracle_config ne ""
        && $user_status eq "Yes" )
    {
        if ( $page eq "update" ) {

            # update changes to local db
            taxonUpdate();

        } elsif ( $page eq "commit" ) {

            # commit changes to all clones
            print qq{
                <p>
                TODO - calls script to commit changes to all clones.
                <br/>
                <a href='main-edit.cgi?section=TaxonEdit'>Back to Genome tree.</a>
                </p>
            };

        } elsif ( $page eq "taxonListPhylo" ) {

            printTaxonTree();
        } elsif ( $page eq "domain" ) {

            # edit a domain tree name
            printDomainEdit();

        } elsif ( $page eq "updatedomain" ) {

            domainUpdate();
        } elsif ( $page eq "taxonOneEdit" ) {

            taxonOneEditForm();
        } elsif ( $page eq "updateOne" ) {

            taxonOneUpdate();
        } elsif ( $page eq "taxonEditForm" ) {
            taxonEditForm_new();
        } elsif ( $page eq "searchresults" || $page eq "orgsearch" ) {
            printSearchResults();
        } elsif ( $page eq "list" ) {
            printList();

        } elsif ( $page eq "tools" ) {
            printToolsPage();
        } elsif ( $page eq "search" ) {
            printSearch();
        } elsif ( $page eq "runsearch" ) {
            runSearch();
        } elsif ( $page eq "difference" ) {
            print "TODO\n";

            ncbiCompare();

        } else {

            #taxonEditForm();
            printTaxonTree();

        }
    } else {
        print qq{
            Oops!<br/>
            $user_restricted_site<br/>
            $img_i_taxon_oracle_config<br/>
            $user_status<br/>
        } if ($img_internal);
        webError("You do not have access to this page!");
    }
}

# run search
sub runSearch {

    # TODO - domain_filter to be used

    print qq{
        <h1> Search Results </h1>
    };

    WebUtil::printStatusLine_old( "Loading ...", 1 );

    #my @phylum_params;
    my $any = 0;
    my $clause;
    my @binds;
    foreach my $p (@domainList) {
        my $x = param($p);
        $any = 1 if ( $x ne "any" );

        #push(@phylum_params, $x);

        if ( $x ne "any" ) {
            if ( $x eq $unclassified ) {
                $clause .= " and ( $p = ? ";
            } else {
                $clause .= " and $p = ? \n";
            }
            push( @binds, $x );

            if ( $x eq $unclassified ) {

                # it can be null too
                $clause .= " or $p is null ) \n";
            }

            webLog("binds = $x \n");
        }
    }

    if ( !$any ) {
        WebUtil::printStatusLine_old( "Error.", 2 );
        webError("Please select a value!");
    }

    printMainForm();

    print submit(
        -name  => 'edit',
        -value => 'Edit Selections',
        -class => 'smdefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All'  "
      . "onClick='selectAllTaxons(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All'  " . "onClick='selectAllTaxons(0)' class='smbutton' />\n";
    print nbsp(1);

    my $dbh           = dbLogin();
    my $contacts_href = getContacts($dbh);

    #$dbh->disconnect();

    my $taxon_dbh = taxonDbLogin();

    my $andClause;
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    $andClause .= "and domain not like 'Vir%'\n"
      if $hideViruses eq "Yes";
    $andClause .= "and domain not like 'Plasmid%'\n"
      if $hidePlasmids eq "Yes";

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    $andClause .= "and domain not like 'GFragment%'\n"
      if $hideGFragment eq "Yes";

    my $hideObsoleteTaxon = getSessionParam("hideObsoleteTaxon");
    $hideObsoleteTaxon = "Yes" if $hideObsoleteTaxon eq "";
    $andClause .= " and obsolete_flag ='No'\n " if $hideObsoleteTaxon eq "Yes";

    my $sql = qq{
        select taxon_oid, taxon_display_name, genus, species, 
        strain, ncbi_taxon_id, 
        domain, phylum, ir_class, ir_order, family, comments, 
        to_char(mod_date, 'yyyy-mm-dd hh24:mi'), 
        modified_by, seq_status
        from taxon 
        where 1 = 1
        $clause
        $andClause
        order by taxon_display_name     
    };

    my $cur = WebUtil::execSqlBind( $taxon_dbh, $sql, \@binds, $verbose );
    my %data;
    for ( ; ; ) {
        my (
            $taxon_oid,     $taxon_display_name, $genus,    $species,     $strain,
            $ncbi_taxon_id, $domain,             $phylum,   $ir_class,    $ir_order,
            $family,        $comments,           $mod_date, $modified_by, $seq_status
          )
          = $cur->fetchrow();
        last if !$taxon_oid;

        $data{$taxon_oid} =
            "$taxon_display_name\t$genus\t$species\t"
          . "$strain\t$ncbi_taxon_id\t$domain\t$phylum\t"
          . "$ir_class\t$ir_order\t$family\t$comments\t"
          . "$mod_date\t$modified_by\t$seq_status";

    }

    $cur->finish();
    $taxon_dbh->disconnect();

    print qq{
        <table class='img' border='1'>
        <th class='img'>Select</th>
        <th class='img'>Genome ID</th>
        <th class='img'>Name</th>
        <th class='img'>Strain</th>
        <th class='img'>NCBI Taxon ID</th>
        <th class='img'>Domain</th>
        <th class='img'>Phylum</th>
        <th class='img'>IR Class</th>
        <th class='img'>IR Order</th>
        <th class='img'>Family</th>
        <th class='img'>Genus</th>
        <th class='img'>Species</th>
        <th class='img'>Comments</th>
        <th class='img'>Seq Status</th>
        <th class='img'>Mod Date</th>
        <th class='img'>Modified By</th>
    };

    foreach my $taxon_oid ( sort keys %data ) {
        my $line = $data{$taxon_oid};
        my (
            $taxon_display_name, $genus,    $species,     $strain,   $ncbi_taxon_id,
            $domain,             $phylum,   $ir_class,    $ir_order, $family,
            $comments,           $mod_date, $modified_by, $seq_status
          )
          = split( /\t/, $line );

        my $username = $contacts_href->{$modified_by};

        $mod_date = "&nbsp;" if ( $mod_date eq "" );
        $username = "&nbsp;" if ( $username eq "" );

        print qq{
            <tr class='img'>
            
            <td class='img'>
             <input type='checkbox' name='taxon_filter_oid' value='$taxon_oid' />
            </td>
            
            <td class='img'> 
        };
        if ( $taxon_oid >= $er_start_taxon_oid ) {
            print qq{  $taxon_oid  };
        } else {
            print qq{ <a href='main-edit.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid'> $taxon_oid </a> };
        }
        print qq{    </td>
            
            <td class='img'> $taxon_display_name </td>
            <td class='img'>$strain </td>            
            <td class='img'>$ncbi_taxon_id </td>   
            <td class='img'>$domain </td>   
            <td class='img'>$phylum </td>  
            <td class='img'>$ir_class </td>  
            <td class='img'>$ir_order </td>             
            <td class='img'> $family </td>  
            <td class='img'>$genus </td> 
            <td class='img'>$species </td>

            <td class='img'>$comments </td>  
            <td class='img'> $seq_status </td> 
            <td class='img'> $mod_date </td>
            <td class='img'> $username </td>
            
            </tr>
        };
    }
    print "</table>\n";
    my $count = keys %data;
    WebUtil::printStatusLine_old( "$count Loaded.", 2 );

    print hiddenVar( "page",    "taxonEditForm" );
    print hiddenVar( "section", "TaxonEdit" );
    print submit(
        -name  => 'Edit',
        -value => 'Edit Selections',
        -class => 'smdefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All'  "
      . "onClick='selectAllTaxons(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All'  " . "onClick='selectAllTaxons(0)', class='smbutton' />\n";
    print end_form();

}

sub printSearch {

    # Bacteria, Archaea, Eukaryota, *Microbiome, Plasmid%, Vir% == Viruses
    my @domain_filter = param("domain_filter");
    my %domain_filter_hash;
    foreach my $key (@domain_filter) {
        $domain_filter_hash{$key} = '';
    }

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";

    print qq{
      <h1> Search </h1>  
    };

    printJavaScript();

    WebUtil::printStatusLine_old( "Loading ...", 1 );
    my $taxon_dbh = taxonDbLogin();
    print qq{
       <form method="post" 
       action="main-edit.cgi" 
       enctype="multipart/form-data" 
       onReset="return confirm('Do you really want to reset the form?')"
       name="mainForm">
    };

    # print domain filter
    my $size = keys %domain_filter_hash;

    #print "$size === <br/>\n";
    my $ck = "checked";
    $ck = "" if ( $size > 0 && !exists $domain_filter_hash{"Bacteria"} );
    print qq{
        <p>
        Filter CV by domain. <br/>
        <input type='checkbox' name='domain_filter' value='Bacteria' $ck /> 
        &nbsp; Bacteria &nbsp;&nbsp;
    };
    my $ck = "checked";
    $ck = "" if ( $size > 0 && !exists $domain_filter_hash{"Archaea"} );
    print qq{
        <input type='checkbox' name='domain_filter' value='Archaea' $ck /> 
        &nbsp; Archaea &nbsp;&nbsp;
    };
    my $ck = "checked";
    $ck = "" if ( $size > 0 && !exists $domain_filter_hash{"Eukaryota"} );
    print qq{
        <input type='checkbox' name='domain_filter' value='Eukaryota' $ck /> 
        &nbsp; Eukaryota &nbsp;&nbsp;
    };
    my $ck = "checked";
    $ck = "" if ( $size > 0 && !exists $domain_filter_hash{"*Microbiome"} );
    print qq{
        <input type='checkbox' name='domain_filter' value='*Microbiome' $ck /> 
        &nbsp; Microbiome &nbsp;&nbsp;
    };

    if ( $hidePlasmids ne "Yes" ) {
        my $ck = "checked";
        $ck = "" if ( $size > 0 && !exists $domain_filter_hash{"Plasmid"} );
        print qq{
        <input type='checkbox' name='domain_filter' value='Plasmid' $ck /> 
        &nbsp; Plasmid &nbsp;&nbsp;
        };
    }

    if ( $hideGFragment ne "Yes" ) {
        my $ck = "checked";
        $ck = "" if ( $size > 0 && !exists $domain_filter_hash{"GFragment"} );
        print qq{
        <input type='checkbox' name='domain_filter' value='GFragment' $ck /> 
        &nbsp; GFragment &nbsp;&nbsp;
        };
    }

    if ( $hideViruses ne "Yes" ) {
        my $ck = "checked";
        $ck = "" if ( $size > 0 && !exists $domain_filter_hash{"Vir"} );
        print qq{
        <input type='checkbox' name='domain_filter' value='Vir' $ck /> 
        &nbsp; Viruses
        };
    }

    print qq{
        <br/>
        <input type='button' name='Filter' value='Filter' 
        onclick='javascript:mySubmit("search")'
        />
        </p>
    };

    # "domain", "phylum", "ir_class", "ir_order", "family", "genus", "species"
    my @phylum_array;
    my @phylum_array_counts;
    foreach my $phyla (@domainList) {
        my ( $aref, $count_aref ) = getCVPhylum2( $taxon_dbh, $phyla, \@domain_filter );
        push( @phylum_array,        $aref );
        push( @phylum_array_counts, $count_aref );
    }

    print qq{
        <table class='img'>
        <th class='img'> Phylum </th>
        <th class='img'> CV </th>
    };

    for ( my $i = 0 ; $i <= $#phylum_array ; $i++ ) {
        my $aref       = $phylum_array[$i];
        my $count_aref = $phylum_array_counts[$i];
        my $name       = $domainList[$i];

        print qq{
            <tr class='img'>
            <td class='img'> $name </td>
            <td class='img'>
        };

        print "<select name='$name'> \n";
        print "<option value='any' selected=\"selected\"> Any </option> \n";
        for ( my $j = 0 ; $j <= $#$aref ; $j++ ) {
            my $x   = $aref->[$j];
            my $cnt = $count_aref->[$j];

            #$x = CGI::escape($x);
            print "<option value='$x'> $x ( $cnt ) </option> \n";
        }
        print "</select> \n";
        print "</td> </tr>\n ";
    }

    print "</table>\n";

    print qq{
        <input type='hidden' name='page' value='runsearch' />
        <input type='hidden' name='section' value='TaxonEdit' />        
        <br/>
        <input type='reset' value='Reset Form' class='medbutton'>
        <input type='submit' name='search' value='Search' class='smdefbutton'/>        
    };

    print end_form();
    $taxon_dbh->disconnect();
    WebUtil::printStatusLine_old( "Loaded.", 2 );
}

sub printToolsPage {

    my $url1    = $section_cgi . "&page=search";
    my $url_tmp = $section_cgi . "&page=difference";
    $url1 = alink( $url1, "Search via phylum" );

    my $url2 = alink( $url_tmp,                       "Taxonomy Difference" );
    my $url3 = alink( $url_tmp . "&domain=Bacteria",  "Bacteria" );
    my $url4 = alink( $url_tmp . "&domain=Archaea",   "Archaea" );
    my $url5 = alink( $url_tmp . "&domain=Eukaryota", "Eukaryota" );
    my $url6 = alink( $url_tmp . "&domain=Viruses",   "Viruses" );
    my $url7 = alink( $url_tmp . "&domain=Plasmids",  "Plasmids" );
    my $url8 = alink( $url_tmp . "&domain=GFragment", "GFragment" );

    # Microbiome
    my $url9 = alink( $url_tmp . "&domain=Microbiome", "Microbiome" );

    print qq{
        <h1> Tools </h1>

        <p>
        <table class='img'>
        <th class='img'>Tool</th>
        <th class='img'>Description</th>
        <tr class='img'>
            <td class='img'> $url1 </td> 
            <td class='img'>
            Search genomes by phylum CV
            </td> 
        </tr>

        <tr class='img'>
            <td class='img'> 
            $url2 <br/> 
            &nbsp;&nbsp;&nbsp;&nbsp; $url3 <br/>
            &nbsp;&nbsp;&nbsp;&nbsp; $url4 <br/>
            &nbsp;&nbsp;&nbsp;&nbsp; $url5 <br/>
            &nbsp;&nbsp;&nbsp;&nbsp; $url6 <br/>
            &nbsp;&nbsp;&nbsp;&nbsp; $url7 <br/>
            &nbsp;&nbsp;&nbsp;&nbsp; $url8 <br/>
            &nbsp;&nbsp;&nbsp;&nbsp; $url9 
            </td> 
            <td class='img'>
            TODO - IMG vs NCBI
            </td> 
        </tr>
        </table>
        </p>
    };

}

# print column filter
sub printColumnFilterTable {
    my @hide_column = param("hide_column");
    my %hide_hash   = WebUtil::array2Hash(@hide_column);

    print qq{
        <h3> Hide Column Filter </h3>
        <table class='img'>
        <th class='img'> Select </th>
        <th class='img'> Column Name </th>
    };

    my @columns = (
        "domain",  "phylum",     "ir_class", "ir_order", "family",   "genus",
        "species", "seq_status", "obsolete", "add_date", "mod_date", "edit_flag"
    );

    foreach my $name (@columns) {
        my $ck = "";
        $ck = "checked='checked'" if ( exists $hide_hash{$name} );

        my $tmp = ucfirst($name);
        print qq{
        <tr class='img'>
            <td class='img'> <input type='checkbox' name='hide_column' value='$name' $ck/> </td>
            <td class='img'> $tmp </td>
        </tr>
        };
    }

    print "</table>\n";

    print qq{
        <br/>
        <input class='smdefbutton' type='button' name='Redisplay' value='Redisplay'
        onclick='javascript:mySubmit2("list")' 
        />
        
        <script type="text/javascript">
        function mySubmit2(page) {
            document.mainForm.page.value = page;
            document.mainForm.submit();
        }             
        </script>
    };

}

# prints list of all genomes via domain if given
sub printList {
    my $domain      = param("domain");
    my $unknown     = param("unknown");
    my @hide_column = param("hide_column");
    my %hide_hash   = WebUtil::array2Hash(@hide_column);

    print qq{
      <h1> Genome List $domain </h1>  
    };

    #print Dumper \@hide_column;
    #print "<br/>\n";

    printMainForm();

    print submit(
        -name  => 'edit',
        -value => 'Edit Selections',
        -class => 'smdefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All'  "
      . "onClick='selectAllTaxons(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All'  " . "onClick='selectAllTaxons(0)' class='smbutton' />\n";
    print nbsp(1);

    WebUtil::printStatusLine_old( "Loading ...", 1 );

    my $domainClause = "";
    my $andClause;
    if ( $domain eq "Viruses" ) {
        $domainClause = "and domain like 'Vir%'";
    } elsif ( $domain eq "Plasmids" ) {
        $domainClause = "and domain like 'Pla%'";
    } elsif ( $domain eq "GFragment" ) {
        $domainClause = "and domain like 'GFragment%'";
    } elsif ( $domain ne "" ) {
        $domainClause = "and domain = '$domain'";
    } else {

        # all
        TaxonSearchUtil::printNotes();
        my $hideViruses = getSessionParam("hideViruses");
        $hideViruses = "Yes" if $hideViruses eq "";
        my $hidePlasmids = getSessionParam("hidePlasmids");
        $hidePlasmids = "Yes" if $hidePlasmids eq "";
        my $hideGFragment = getSessionParam("hideGFragment");
        $hideGFragment = "Yes" if $hideGFragment eq "";
        $andClause .= "and domain not like 'Vir%'\n"
          if $hideViruses eq "Yes";
        $andClause .= "and domain not like 'Plasmid%'\n"
          if $hidePlasmids eq "Yes";
        $andClause .= "and domain not like 'GFragment%'\n"
          if $hideGFragment eq "Yes";
    }

    my $hideObsoleteTaxon = getSessionParam("hideObsoleteTaxon");
    $hideObsoleteTaxon = "Yes" if $hideObsoleteTaxon eq "";
    $andClause .= "and nvl(obsolete_flag, 'No') ='No'\n" if $hideObsoleteTaxon eq "Yes";

    my $unknownClause;
    if ( $unknown eq "yes" ) {
        $unknownClause = qq{
            and (  lower(phylum) like 'uncl%' or lower(phylum) like 'unkn%' or phylum is null
                or lower(ir_class) like 'uncl%' or lower(ir_class) like 'unkn%' or ir_class is null
                or lower(ir_order) like 'uncl%' or lower(ir_order) like 'unkn%' or ir_order is null
                or lower(family) like 'uncl%' or lower(family) like 'unkn%' or family is null
                or lower(genus) like 'uncl%' or lower(genus) like 'unkn%' or genus is null
                or lower(species) like 'uncl%' or lower(species) like 'unkn%' or species is null
            )
        };
    }

    my $sql = qq{
        select taxon_oid, taxon_display_name, domain, 
        phylum, ir_class, ir_order, family, genus, species,
        seq_status, nvl(obsolete_flag, 'No'), 
        to_char(add_date, 'yyyy-mm-dd'), 
        to_char(mod_date, 'yyyy-mm-dd'),
        nvl(edit_flag, 'No'), nvl(combined_sample_flag, 'No'), nvl(taxonomy_lock, 'No')
        from taxon
        where 1 = 1
        $domainClause
        $andClause
        $unknownClause
    };

    my $it = new InnerTable( 1, "tedit$$", "tedit", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Genome ID",   "number desc", "right" );
    $it->addColSpec( "Genome Name", "char asc",    "left" );
    $it->addColSpec( "Domain",      "char asc",    "left" )
      if ( !exists $hide_hash{"domain"} );
    $it->addColSpec( "Phylum", "char asc", "left" )
      if ( !exists $hide_hash{"phylum"} );
    $it->addColSpec( "IR Class", "char asc", "left" )
      if ( !exists $hide_hash{"ir_class"} );
    $it->addColSpec( "IR Order", "char asc", "left" )
      if ( !exists $hide_hash{"ir_order"} );
    $it->addColSpec( "Family", "char asc", "left" )
      if ( !exists $hide_hash{"family"} );
    $it->addColSpec( "Genus", "char asc", "left" )
      if ( !exists $hide_hash{"genus"} );
    $it->addColSpec( "Species", "char asc", "left" )
      if ( !exists $hide_hash{"species"} );
    $it->addColSpec( "Seq. Status", "char asc", "left" )
      if ( !exists $hide_hash{"seq_status"} );
    $it->addColSpec( "Obsolete", "char asc", "left" )
      if ( !exists $hide_hash{"obsolete"} );

    $it->addColSpec( "Combined Sample", "char asc", "left" );

    $it->addColSpec( "Add Date", "char asc", "left" )
      if ( !exists $hide_hash{"add_date"} );
    $it->addColSpec( "Mod Date", "char asc", "left" )
      if ( !exists $hide_hash{"mod_date"} );
    $it->addColSpec( "Edit Flag", "char asc", "left" )
      if ( !exists $hide_hash{"edit_flag"} );

    $it->addColSpec( "Taxonomy Locked", "char asc", "left" );

    my $taxon_dbh = taxonDbLogin();
    my $cur       = execSql( $taxon_dbh, $sql, $verbose );
    my $row_cnt   = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $seq_status,
            $obsolete, $add_date, $mod_date, $edit_flag, $combined_sample_flag, $taxonomy_lock )
          = $cur->fetchrow();
        last if ( !$taxon_oid );
        my $r;
        $r = "$sd<input type='checkbox' name='taxon_filter_oid' " . " value='$taxon_oid' />\t";

        my $url = "main-edit.cgi?section=TaxonEdit&page=taxonOneEdit" . "&taxon_oid=$taxon_oid";
        $url = alink( $url, $taxon_oid );
        $r .= $taxon_oid . $sd . $url . "\t";
        $r .= $taxon_display_name . $sd . $taxon_display_name . "\t";
        $r .= $domain . $sd . $domain . "\t"
          if ( !exists $hide_hash{"domain"} );
        $r .= $phylum . $sd . formatFont($phylum) . "\t"
          if ( !exists $hide_hash{"phylum"} );
        $r .= $ir_class . $sd . formatFont($ir_class) . "\t"
          if ( !exists $hide_hash{"ir_class"} );
        $r .= $ir_order . $sd . formatFont($ir_order) . "\t"
          if ( !exists $hide_hash{"ir_order"} );
        $r .= $family . $sd . formatFont($family) . "\t"
          if ( !exists $hide_hash{"family"} );
        $r .= $genus . $sd . formatFont($genus) . "\t"
          if ( !exists $hide_hash{"genus"} );
        $r .= $species . $sd . formatFont($species) . "\t"
          if ( !exists $hide_hash{"species"} );
        $r .= $seq_status . $sd . $seq_status . "\t"
          if ( !exists $hide_hash{"seq_status"} );
        $r .= $obsolete . $sd . $obsolete . "\t"
          if ( !exists $hide_hash{"obsolete"} );

        $r .= $combined_sample_flag . $sd . $combined_sample_flag . "\t";

        $r .= $add_date . $sd . $add_date . "\t"
          if ( !exists $hide_hash{"add_date"} );
        $r .= $mod_date . $sd . $mod_date . "\t"
          if ( !exists $hide_hash{"mod_date"} );

        if ( $edit_flag eq "Yes" && !exists $hide_hash{"edit_flag"} ) {
            $r .= $edit_flag . $sd . "<font color='red'> $edit_flag </font>" . "\t";
        } elsif ( !exists $hide_hash{"edit_flag"} ) {
            $r .= $edit_flag . $sd . $edit_flag . "\t";
        }

        $r .= $taxonomy_lock . $sd . $taxonomy_lock . "\t";
        

        $it->addRow($r);
        $row_cnt++;
    }
    $cur->finish();

    $taxon_dbh->disconnect();

    $it->printOuterTable(1);

    print hiddenVar( "page",    "taxonEditForm" );
    print hiddenVar( "section", "TaxonEdit" );
    print hiddenVar( "domain",  $domain );
    print submit(
        -name  => 'Edit',
        -value => 'Edit Selections',
        -class => 'smdefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All'  "
      . "onClick='selectAllTaxons(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All'  " . "onClick='selectAllTaxons(0)', class='smbutton' />\n";

    printColumnFilterTable();

    print end_form();

    WebUtil::printStatusLine_old( "$row_cnt Rows Loaded.", 2 );
}

# color the matching text if un%
sub formatFont {
    my ($text) = @_;
    my $unknown = param("unknown");

    if ( $unknown eq "yes" ) {
        if ( lc($text) =~ /^uncl/ || lc($text) =~ /^unkn/ ) {
            $text = "<font color='red'> $text </font>";
        }
    }
    return $text;
}

# search for taxon id  or taxon name
sub printSearchResults {
    my $text = param("searchTerm");
    $text = strTrim($text);
    $text = lc($text);

    my $taxonTerm = param("taxonTerm");
    if ( $text eq "" && $taxonTerm ne "" ) {
        $text = strTrim(lc($taxonTerm));
    }

    print qq{
        <h1> Search Results </h1>
        <p>
        Click genome id to edit genome
        </p>
    };

    my $taxon_dbh = taxonDbLogin();
    my @results;

    my $sql;

    if ( WebUtil::isInt($text) ) {

        $sql = qq{
        select taxon_oid, taxon_display_name
        from taxon
        where taxon_oid like ? || '%'
        };
    } else {
        $sql = qq{
        select taxon_oid, taxon_display_name
        from taxon
        where lower(taxon_display_name) like  '%' || ? || '%'
        };
    }

    print qq{
        <table class='img'>
        <th class='img'> Geneome ID </th>
        <th class='img'> Name </th>
    };

    my $url = "main-edit.cgi?section=TaxonEdit&page=taxonOneEdit&taxon_oid=";

    my $cur = execSql( $taxon_dbh, $sql, $verbose, $text );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if ( !$id );
        print "<tr class='img'>\n";

        my $tmp = $url . $id;
        $tmp = alink( $tmp, $id );
        print "<td class='img'> $tmp </td>\n";
        print "<td class='img'> $name </td>\n";

        print "</tr>\n";
    }
    print "</table>\n";

    $cur->finish();

    $taxon_dbh->disconnect();
}

#
# login into taxon edit database
#
sub taxonDbLogin {
    if ( $ora_port ne "" && $ora_host ne "" && $ora_sid ne "" ) {
        $dsn = "dbi:Oracle:host=$ora_host;port=$ora_port;sid=$ora_sid;";
    } else {
    }
    my $dbh = DBI->connect( $dsn, $user, pwDecode($pw), { AutoCommit => 0 } );
    if ( !defined($dbh) ) {
        webDie("dbLogin: cannot login '$user' \@ '$dsn'\n");
    }
    $dbh->{LongReadLen} = $maxClobSize;
    $dbh->{LongTruncOk} = 1;
    return $dbh;
}

sub domainUpdate {

    my $column      = param("column");
    my $columValue  = param("$column");
    my $domain      = param("domain");
    my @domains     = split( /$delimiter/, $domain );
    my $modified_by = getContactOid();

    print "<h1>Updating Genome Data</h1>\n";

    print qq{
    <p>
    <input type='button' class='medbutton' value='Back to Genome edit tree'
    onClick='javascript:window.open("main-edit.cgi?section=TaxonEdit&page=taxonListPhylo", "_self");' />
    </p>
    <br/>       
    };

    WebUtil::printStatusLine_old( "<font color='red'><blink>Updating ... </blink></font>", 1 );

    print "$column = $columValue";
    print "<br/> ";

    #print Dumper \@domains;

    my $clause;

    # 1 because the the value begins with a , so the [0] is blank
    for ( my $i = 1 ; $i <= $#domains ; $i++ ) {
        if ( $domains[$i] eq "" ) {
            $clause .= "and " . $domainList[ $i - 1 ] . " is null \n";
        } else {
            $clause .= "and " . $domainList[ $i - 1 ] . " = '" . $domains[$i] . "'\n";
        }
    }

    if ( $clause eq "" ) {
        webError("Error in creating update statement!.");
    }

    my $sql = qq{
        update taxon 
        set $column = ?,
        mod_date = sysdate,
        modified_by = ?,
        taxonomy_lock = 'Yes',
        locked_by = '$modified_by',
        lock_date = sysdate
        where 1 = 1 
        $clause
    };

    my @data = ( $columValue, $modified_by );

    my $taxon_dbh = taxonDbLogin();
    my $cur = WebUtil::execSqlBind( $taxon_dbh, $sql, \@data, $verbose );
    print "<p>Number of rows updated : " . $cur->rows;
    print "<br/>\n";

    $cur->finish();
    $taxon_dbh->commit();

    processDtTaxonNodeLite($taxon_dbh);

    $taxon_dbh->disconnect();

    print "</p>\n";

    print qq{
    <p>
    <input type='button' class='medbutton' value='Back to Genome edit tree'
    onClick='javascript:window.open("main-edit.cgi?section=TaxonEdit&page=taxonListPhylo", "_self");' />
    </p>
    <br/>       
    };

    WebUtil::printStatusLine_old( "Updated", 2 );
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
sub printDomainEdit {

    my $value = param("value");

    print "<h1>Genome Phylum Editor</h1>\n";

    WebUtil::printStatusLine_old( "Loading ...", 1 );

    my @domains = split( /$delimiter/, $value );

    #print Dumper \@domains;

    # db to standard img
    my $dbh           = dbLogin();
    my $contacts_href = getContacts($dbh);

    #$dbh->disconnect();

    print qq{
       <form method="post" 
       action="main-edit.cgi" 
       enctype="multipart/form-data" 
       onReset="return confirm('Do you really want to reset the form?')"
       name="mainForm">
    };

    my $column      = $domainList[ $#domains - 1 ];
    my $columnValue = $domains[$#domains];

    # edit db connection
    my $taxon_dbh   = taxonDbLogin();
    my $phylum_aref = getCVPhylum( $taxon_dbh, $domains[1], $column );
    my $str         = join( $delimiter_selectbox, @$phylum_aref );

    # <input type='text' name='$column' size='50' value='$columnValue'/>
    print qq{
        <p> <b>Editing phylum column: $column</b> 
        <br/>
         <input type='hidden' name='column' value='$column'/>
         <input type='hidden' name='domain' value='$value'/>
         
         <input type="text" name="$column" value="$columnValue" size='50' selectBoxOptions="$str">
        </p>
    };

    print qq{
    <input type='hidden' name='page' value='updatedomain' />
    <input type='hidden' name='section' value='TaxonEdit' />

    <input type=reset value="Reset Form" class='medbutton'>
    <input type="submit" name="update" value="Update" class="smdefbutton" 
    title='ONLY updates changes to staging db'/>
    };

    print end_form();

    print qq{
    <script type="text/javascript">
    createEditableSelect(document.mainForm.$column);
    </script>        
    };

    my $clause;

    # 1 because the the value begins with a , so the [0] is blank
    for ( my $i = 1 ; $i <= $#domains ; $i++ ) {
        if ( $domains[$i] eq "" ) {
            $clause .= "and " . $domainList[ $i - 1 ] . " is null \n";
        } else {
            $clause .= "and " . $domainList[ $i - 1 ] . " = '" . $domains[$i] . "'\n";
        }
    }

    my $sql = qq{
        select taxon_oid, taxon_display_name, genus, species, 
        strain, ncbi_taxon_id, 
        domain, phylum, ir_class, ir_order, family, comments, 
        to_char(mod_date, 'yyyy-mm-dd hh24:mi'), 
        modified_by, seq_status, nvl(taxonomy_lock, 'No')
        from taxon 
        where 1 = 1
        $clause
        order by  taxon_display_name     
    };

    my $cur = execSql( $taxon_dbh, $sql, $verbose );

    my %data;
    for ( ; ; ) {
        my (
            $taxon_oid,     $taxon_display_name, $genus,    $species,     $strain,
            $ncbi_taxon_id, $domain,             $phylum,   $ir_class,    $ir_order,
            $family,        $comments,           $mod_date, $modified_by, $seq_status, $taxonomy_lock
          )
          = $cur->fetchrow();
        last if !$taxon_oid;

        $data{$taxon_oid} =
            "$taxon_display_name\t$genus\t$species\t"
          . "$strain\t$ncbi_taxon_id\t$domain\t$phylum\t"
          . "$ir_class\t$ir_order\t$family\t$comments\t"
          . "$mod_date\t$modified_by\t$seq_status\t$taxonomy_lock";

    }
    $cur->finish();

    $taxon_dbh->disconnect();

    print qq{
        <h2>
        List of genomes that will be modified.
        </h2>
    };

    print qq{
        <table class='img' border='1'>
        <th class='img'>Genome ID</th>
        <th class='img'>Name</th>
        <th class='img'>Genus</th>
        <th class='img'>Species</th>
        <th class='img'>Strain</th>
        <th class='img'>NCBI Taxon ID</th>
        <th class='img'>Domain</th>
        <th class='img'>Phylum</th>
        <th class='img'>IR Class</th>
        <th class='img'>IR Order</th>
        <th class='img'>Family</th>
        <th class='img'>Comments</th>
        <th class='img'>Seq Status</th>
        <th class='img'>Mod Date</th>
        <th class='img'>Modified By</th>
        <th class='img'>Taxonomy Locked</th>
    };

    foreach my $taxon_oid ( sort keys %data ) {
        my $line = $data{$taxon_oid};
        my (
            $taxon_display_name, $genus,    $species,     $strain,   $ncbi_taxon_id,
            $domain,             $phylum,   $ir_class,    $ir_order, $family,
            $comments,           $mod_date, $modified_by, $seq_status, $taxonomy_lock
          )
          = split( /\t/, $line );

        my $username = $contacts_href->{$modified_by};

        $mod_date = "&nbsp;" if ( $mod_date eq "" );
        $username = "&nbsp;" if ( $username eq "" );

        print qq{
            <tr class='img'>
            <td class='img'> 
	    };
        if ( $taxon_oid >= $er_start_taxon_oid ) {
            print qq{  $taxon_oid  };
        } else {
            print qq{ <a href='main-edit.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid'> $taxon_oid </a> };
        }
        print qq{    </td>
            
            <td class='img'> $taxon_display_name </td>
 
            <td class='img'>$genus </td>
 
            <td class='img'>$species </td>
            
            <td class='img'>$strain </td>            

            <td class='img'>$ncbi_taxon_id </td>   
            
            <td class='img'>$domain </td>   

            <td class='img'>$phylum </td>  

            <td class='img'>$ir_class </td>  

            <td class='img'>$ir_order </td>             

            <td class='img'> $family </td>  

            <td class='img'>$comments </td>  
            <td class='img'> $seq_status </td> 
            <td class='img'> $mod_date </td>
            <td class='img'> $username </td>
            <td class='img'> $taxonomy_lock </td>
            </tr>
        };
    }
    print "</table>\n";
    my $count = keys %data;
    WebUtil::printStatusLine_old( "$count Loaded.", 2 );
}

#
# update taxon changes to taxon edit db
# - update dt_ table using sqlloader
#
sub taxonUpdate {
    print "<h1>Updating Genome Data</h1>\n";
    WebUtil::printStatusLine_old( "<font color='red'><blink>Updating ... </blink></font>", 1 );

    print qq{
    <p>
    <input type='button' class='medbutton' value='Back to Genome edit tree'
    onClick='javascript:window.open("main-edit.cgi?section=TaxonEdit&page=taxonListPhylo", "_self");' />
    </p>
    <br/>       
    };

    my $count = param("count");
    print "<p>You have selected $count genomes.<br/>\n";

    # db to standard img
    my $dbh         = dbLogin();
    my $taxon_dbh   = taxonDbLogin();
    my $modified_by = getContactOid();

    #print "modified_by =  $modified_by<br/>\n";

    my $data_href = getTaxons( $dbh, $taxon_dbh );

    #$dbh->disconnect();

    # flag to indicate there was one update stmt exceuted
    # print hiddenVar( "taxonomy_lock$count", "$domain\t$phylum\t$ir_class\t$ir_order\t$family\t$genus\t$species\t$strain");
    my $rowsupdate = 0;
    for ( my $i = 0 ; $i < $count ; $i++ ) {
        my $taxon_oid            = param("taxon_oid$i");
        my $taxon_display_name   = param("name$i");
        my $genus                = param("genus$i");
        my $species              = param("species$i");
        my $strain               = param("strain$i");
        my $ncbi_taxon_id        = param("ncbi_taxon_id$i");
        my $domain               = param("domain$i");
        my $phylum               = param("phylum$i");
        my $ir_class             = param("ir_class$i");
        my $ir_order             = param("ir_order$i");
        my $family               = param("family$i");
        my $comments             = param("comments$i");
        my $seq_status           = param("seq_status$i");
        my $obsolete_flag        = param("obsolete_flag$i");
        my $refseq_project_id    = param("refseq_project_id$i");
        my $gbk_project_id       = param("gbk_project_id$i");
        my $is_low_quality       = param("is_low_quality$i");
        my $combined_sample_flag = param("combined_sample_flag$i");
        my $taxonomy_lock        = param("taxonomy_lock$i");

        # compare to whats in the taxon db
        # only update the rows that changed
        my $line = $data_href->{$taxon_oid};
        my (
            $taxon_display_name2, $genus2,             $species2,        $strain2,        $ncbi_taxon_id2,
            $domain2,             $phylum2,            $ir_class2,       $ir_order2,      $family2,
            $comments2,           $mod_date2,          $modified_by2,    $seq_status2,    $add_date2,
            $img_version2,        $refseq_project_id2, $gbk_project_id2, $obsolete_flag2, $is_low_quality2,
            $combined_sample_flag2
          )
          = split( /\t/, $line );
        my $formLine =
            "$taxon_display_name\t$genus\t$species\t"
          . "$strain\t$ncbi_taxon_id\t$domain\t$phylum\t"
          . "$ir_class\t$ir_order\t$family\t$comments\t$seq_status\t"
          . "$refseq_project_id\t$gbk_project_id\t$obsolete_flag\t$is_low_quality\t$combined_sample_flag";
        my $dbLine =
            "$taxon_display_name2\t$genus2\t$species2\t"
          . "$strain2\t$ncbi_taxon_id2\t$domain2\t$phylum2\t"
          . "$ir_class2\t$ir_order2\t$family2\t$comments2\t$seq_status2\t"
          . "$refseq_project_id2\t$gbk_project_id2\t$obsolete_flag2\t$is_low_quality2\t$combined_sample_flag2";
        next if ( $formLine eq $dbLine );    # only update rows with changes

        print "$formLine<br>\n";
        print "$dbLine<br>\n";

        # lock from form
        my $taxonomy_lock_new = "$domain\t$phylum\t$ir_class\t$ir_order\t$family\t$genus\t$species\t$strain";
        
        print "$taxonomy_lock<br>\n";
        print "$taxonomy_lock_new<br>\n";
        
        my $lock_sql          = '';
        if ( $taxonomy_lock ne $taxonomy_lock_new ) {

            # TODO set lock on
            $lock_sql = qq{
        update taxon
        set taxonomy_lock = 'Yes',
        locked_by = '$modified_by',
        lock_date = sysdate
        where taxon_oid = ?
        };
        }

        # do update
        # undef used to bind null in sql
        if ( blankStr($taxon_display_name) ) {
            webError("Genome name cannot be null.");
        }
        if ( blankStr($genus) ) {
            webError("Genus name cannot be null.");
        }

        if ( blankStr($domain) ) {
            webError("Domain cannot be null.");
        }

        if ( blankStr($seq_status) ) {
            webError("Seq Status name cannot be null.");
        } elsif ( $seq_status ne "Draft"
            && $seq_status ne "Finished"
            && $seq_status ne "Permanent Draft" )
        {
            webError("Seq Status must be Draft, Permanent Draft or Finished.");
        }

        if ( blankStr($species) ) {

            #webError("Species name cannot be null.");
            $species = undef;
        }

        if ( blankStr($strain) ) {

            #webError("Strain name cannot be null.");
            $strain = undef;
        }

        if ( blankStr($ncbi_taxon_id) ) {
            $ncbi_taxon_id = undef;
        } elsif ( $ncbi_taxon_id =~ /^\d+$/ ) {

            # is all digits
        } else {
            webError("NCBI Taxon ID can only be a number.");
        }

        if ( blankStr($refseq_project_id) ) {
            $refseq_project_id = undef;
        } elsif ( $refseq_project_id =~ /^\d+$/ ) {

            # is all digits
        } else {
            webError("RefSeq Project ID can only be a number.");
        }

        if ( blankStr($gbk_project_id) ) {
            $gbk_project_id = undef;
        } elsif ( $gbk_project_id =~ /^\d+$/ ) {

            # is all digits
        } else {
            webError("GenBank Project ID can only be a number.");
        }

        if ( blankStr($domain) ) {
            webError("Domain name cannot be null.");
        }
        if ( blankStr($phylum) ) {
            $phylum = undef;
        }
        if ( blankStr($ir_class) ) {
            $ir_class = undef;
        }
        if ( blankStr($ir_order) ) {
            $ir_order = undef;
        }
        if ( blankStr($family) ) {
            $family = undef;
        }
        if ( blankStr($comments) ) {
            $comments = undef;
        }

        print qq{
            Updating $taxon_oid, $taxon_display_name
            <br/>           
       };

        my @data = (
            $taxon_display_name, $genus,          $species,    $strain,            $ncbi_taxon_id,
            $domain,             $phylum,         $ir_class,   $ir_order,          $family,
            $comments,           $modified_by,    $seq_status, $refseq_project_id, $gbk_project_id,
            $obsolete_flag,      $is_low_quality, $combined_sample_flag
        );

        my $sql2 = qq{
           update taxon
           set taxon_display_name = ?,
               genus = ?,
               species = ?,
               strain = ?,
               ncbi_taxon_id = ?,
               domain = ?,
               phylum = ?,
               ir_class = ?,
               ir_order = ?,
               family = ?,
               comments = ?,
               mod_date = sysdate,
               modified_by = ?,
               seq_status = ?,
               refseq_project_id = ?,
               gbk_project_id = ?,
               obsolete_flag = ?, 
               is_low_quality = ?,
               combined_sample_flag = ?
           where taxon_oid = $taxon_oid
       };

        my $cur2 = WebUtil::execSqlBind( $taxon_dbh, $sql2, \@data, $verbose );

        #$cur2->finish();

        if ( $lock_sql ne '' ) {
            print "Taxonomy Lock set to: Yes<br/>\n";
            my $cur = WebUtil::execSql( $taxon_dbh, $lock_sql, $verbose, $taxon_oid );
        }

        $rowsupdate++;
    }

    #$taxon_dbh->commit();
    print "</p>\n";

    #WebUtil::printStatusLine_old( "$rowsupdate Rows Updated.", 2 );
    print "<p>$rowsupdate Rows Updated<br/>\n";

    if ( $rowsupdate == 0 ) {
        print "</p>\n";
        print qq{
        <p>
        <a href='main-edit.cgi?section=TaxonEdit'>Back to Genome tree.</a>
        </p>
        };
        $taxon_dbh->disconnect();
        return;
    }

#$taxon_dbh->rollback();
#print "TEST <br>\n";
#exit 0;

    # commits update
    $taxon_dbh->commit();

    processDtTaxonNodeLite($taxon_dbh);

    $taxon_dbh->disconnect();

    print qq{
    <p>
    <input type='button' class='medbutton' value='Back to Genome edit tree'
    onClick='javascript:window.open("main-edit.cgi?section=TaxonEdit&page=taxonListPhylo", "_self");' />
    </p>
    <br/>       
    };

    WebUtil::printStatusLine_old( "Updated", 2 );
}

sub taxonOneUpdate {
    print "<h1>Updating Genome Data</h1>\n";

    WebUtil::printStatusLine_old( "<font color='red'><blink>Updating ... </blink></font>", 1 );

    my $taxon_oid            = param("taxon_oid");
    my $taxon_display_name   = param("name");
    my $genus                = param("genus");
    my $species              = param("species");
    my $strain               = param("strain");
    my $ncbi_taxon_id        = param("ncbi_taxon_id");
    my $phylum               = param("phylum");
    my $ir_class             = param("ir_class");
    my $ir_order             = param("ir_order");
    my $family               = param("family");
    my $comments             = param("comments");
    my $seq_status           = param("seq_status");
    my $refseq_project_id    = param("refseq_project_id");
    my $gbk_project_id       = param("gbk_project_id");
    my $obsolete_flag        = param("obsolete_flag");
    my $domain               = param("domain");
    my $combined_sample_flag = param("combined_sample_flag");
    my $high_quality_flag    = param('high_quality_flag');
    my $taxonomy_lock        = param('taxonomy_lock');

    # is_low_quality
    my $is_low_quality = param("is_low_quality");

    # db to standard img
    my $taxon_dbh   = taxonDbLogin();
    my $modified_by = getContactOid();

    #print hiddenVar( 'taxonomy_lock', "$domain\t$phylum\t$ir_class\t$ir_order\t$family\t$genus\t$species\t$strain");
    my $taxonomy_lock_new = "$domain\t$phylum\t$ir_class\t$ir_order\t$family\t$genus\t$species\t$strain";

    my $lock_sql = '';
    if ( $taxonomy_lock ne $taxonomy_lock_new ) {

        # TODO set lock on
        $lock_sql = qq{
        update taxon
        set taxonomy_lock = 'Yes',
        locked_by = '$modified_by',
        lock_date = sysdate
        where taxon_oid = ?
        };
    }

    print qq{
    <input type='button' class='medbutton' value='Back to Genome edit form'
    onClick='javascript:window.open("main-edit.cgi?section=TaxonEdit&page=taxonOneEdit&taxon_oid=$taxon_oid", "_self");' />
    <br/>       
    };

    # do update
    # undef used to bind null in sql
    if ( blankStr($taxon_display_name) ) {
        webError("Genome name cannot be null.");
    }
    if ( blankStr($domain) ) {
        webError("Domain cannot be null.");
    }

    if ( blankStr($genus) ) {
        webError("Genus name cannot be null.");
    }
    if ( blankStr($seq_status) ) {
        webError("Seq Status name cannot be null.");
    } elsif ( $seq_status ne "Draft"
        && $seq_status ne "Finished"
        && $seq_status ne "Permanent Draft" )
    {
        webError("Seq Status must be Draft, Permanent Draft, or Finished.");
    }

    if ( blankStr($species) ) {

        #webError("Species name cannot be null.");
        $species = undef;
    }

    if ( blankStr($strain) ) {

        #webError("Strain name cannot be null.");
        $strain = undef;
    }

    if ( blankStr($ncbi_taxon_id) ) {
        $ncbi_taxon_id = undef;
    } elsif ( $ncbi_taxon_id =~ /^\d+$/ ) {

        # is all digits
    } else {
        webError("NCBI Taxon ID can only be a number.");
    }

    if ( blankStr($refseq_project_id) ) {
        $refseq_project_id = undef;
    } elsif ( $refseq_project_id =~ /^\d+$/ ) {

        # is all digits
    } else {
        webError("Refseq Project ID can only be a number.");
    }

    if ( blankStr($gbk_project_id) ) {
        $gbk_project_id = undef;
    } elsif ( $gbk_project_id =~ /^\d+$/ ) {

        # is all digits
    } else {
        webError("GebBank Project ID can only be a number.");
    }

    if ( blankStr($phylum) ) {
        $phylum = undef;
    }
    if ( blankStr($ir_class) ) {
        $ir_class = undef;
    }
    if ( blankStr($ir_order) ) {
        $ir_order = undef;
    }
    if ( blankStr($family) ) {
        $family = undef;
    }
    if ( blankStr($comments) ) {
        $comments = undef;
    }

    print qq{
        <p>
            Updating $taxon_oid, $taxon_display_name
        </p>
            <br/>
       };

    my @data = (
        $taxon_display_name, $genus,          $species,              $strain,            $ncbi_taxon_id,
        $phylum,             $ir_class,       $ir_order,             $family,            $comments,
        $modified_by,        $seq_status,     $refseq_project_id,    $gbk_project_id,    $obsolete_flag,
        $domain,             $is_low_quality, $combined_sample_flag, $high_quality_flag, $taxon_oid
    );

    my $sql2 = qq{
           update taxon
           set taxon_display_name = ?,
               genus = ?,
               species = ?,
               strain = ?,
               ncbi_taxon_id = ?,
               phylum = ?,
               ir_class = ?,
               ir_order = ?,
               family = ?,
               comments = ?,
               mod_date = sysdate,
               modified_by = ?,
               seq_status = ?,
               refseq_project_id = ?,
               gbk_project_id = ?,
               obsolete_flag = ?,
               domain = ?,
               is_low_quality = ?,
               combined_sample_flag = ?,
               high_quality_flag = ?
           where taxon_oid = ?
       };

    my $cur2 = WebUtil::execSqlBind( $taxon_dbh, $sql2, \@data, $verbose );
    $cur2->finish();

    print "<p>Row Updated<br/>\n";

    if ( $lock_sql ne '' ) {
        print "Taxonomy Lock set to: Yes<br/>\n";
        print "$lock_sql <br>\n";
        my $cur = WebUtil::execSql( $taxon_dbh, $lock_sql, $verbose, $taxon_oid );
        $cur->finish();
    }

#    $taxon_dbh->rollback();
#    print "test done <br>\n";
#    exit 0;
    
    $taxon_dbh->commit();

    processDtTaxonNodeLite($taxon_dbh);
    $taxon_dbh->disconnect();

    print qq{
    <input type='button' class='medbutton' value='Back to Genome edit form'
    onClick='javascript:window.open("main-edit.cgi?section=TaxonEdit&page=taxonOneEdit&taxon_oid=$taxon_oid", "_self");' />       
    };

    WebUtil::printStatusLine_old( "Updated", 2 );
}

sub processDtTaxonNodeLite {
    my ($taxon_dbh) = @_;

    # now update the dt tables
    print "Getting taxon rank data<br/>\n";
    my $data_aref = getTaxonRank($taxon_dbh);
    print "Processing data to create tree<br/>\n";
    my %taxonTree;
    processFile( $data_aref, \%taxonTree );

    my $sessionId = getSessionId();
    my @data_array;

    my $outFile = "$cgi_tmp_dir/dt_taxon_node_lite.tab.txt";
    print "outFile $outFile<br/>\n";
    open( Fout, "> $outFile" ) || webDie("cannot write '$outFile'\n");
    print Fout "node_oid\t";
    print Fout "display_name\t";
    print Fout "rank_name\t";
    print Fout "taxon\t";
    print Fout "parent\n";
    printTree( \*Fout, \%taxonTree, \@data_array );
    close Fout;

    print "deleting table dt_taxon_node_lite<br/>\n";
    deleteTable($taxon_dbh);

    # non sql loader way
    print "<p>\n";
    insertDtTaxonNodeLite( $taxon_dbh, \@data_array );

    $taxon_dbh->commit();

    # sqlloader
    #print "Starting sql loader<br/>\n";
    #sqlLoader($taxon_dbh);

    print "</p>\n";

}

# insert into DtTaxonNodeLite
sub insertDtTaxonNodeLite {
    my ( $taxon_dbh, $data_aref ) = @_;

    print "Inserting into table dt_taxon_node_lite <br/>\n";
    my $t = currDateTime();
    webLog("$t Start\n");
    my $sql = qq{
        insert into dt_taxon_node_lite
        (node_oid, display_name, rank_name, taxon, parent)
        values
        (?,?,?,?,?)
    };
    my $cur = $taxon_dbh->prepare($sql)
      || webDie("execSqlBind: cannot preparse statement: $DBI::errstr\n");
    my $count = 0;
    foreach my $line (@$data_aref) {
        my ( $nodeCount, $name, $rank_name, $taxon_oid, $parentNode ) =
          split( /\t/, $line );
        $cur->bind_param( 1, $nodeCount )
          || webDie("execSqlBind: cannot bind param: $DBI::errstr\n");
        $cur->bind_param( 2, $name )
          || webDie("execSqlBind: cannot bind param: $DBI::errstr\n");
        $cur->bind_param( 3, $rank_name )
          || webDie("execSqlBind: cannot bind param: $DBI::errstr\n");
        $cur->bind_param( 4, $taxon_oid )
          || webDie("execSqlBind: cannot bind param: $DBI::errstr\n");
        $cur->bind_param( 5, $parentNode )
          || webDie("execSqlBind: cannot bind param: $DBI::errstr\n");
        $cur->execute()
          || webDie("execSqlBind: cannot execute: $DBI::errstr\n");
        $count++;

        if ( $count % 500 == 0 ) {
            print "Inserted $count records<br/>\n";
        }
    }
    $cur->finish();
    print "Finised insert $count records<br/>\n";

    $t = currDateTime();
    webLog("$t done \n");
    print "Done inserting into table dt_taxon_node_lite <br/>\n";

}

sub printPanel {
    my ( $title, $list_aref, $panel_name ) = @_;

    print qq{
    <div id="$panel_name" style="visibility: hidden;">
        <div class="hd"> $title </div>
        <div class="bd" style='overflow:auto;'>
    
    <table border='0'>
    };

    foreach my $text (@$list_aref) {
        $text = escapeHTML($text);
        print qq{
            <tr><td nowrap>
            <a href="javascript:void(0)" onClick='return select_item("$text");' > $text </a>
            </td></tr> 
        };
    }
    print qq{
    </table>  
        </div>
        <div class="ft"></div>
    </div>    
};
}

#
# taxon edit form - selected genomes
#
sub taxonEditForm_new {

    print "<h1>Genome Editor - User Selected</h1>\n";

    # user selected taxons
    my @taxon_filter_oid = param("taxon_filter_oid");
    if ( $#taxon_filter_oid < 0 ) {
        webError("Please select some genomes to edit");
    }

    printJavaScript();

    WebUtil::printStatusLine_old( "Loading ...", 1 );

    # db to standard img
    my $dbh       = dbLogin();
    my $taxon_dbh = taxonDbLogin();

    my $domain_aref = getCVDomain($taxon_dbh);

    print qq{
       <div id="container"> 
        
       <form method="post" 
       action="main-edit.cgi" 
       enctype="multipart/form-data" 
       onReset="return confirm('Do you really want to reset the form?')"
       name="mainForm">
    };

    # taxon oid => line of tab delimited
    my $data_href = getTaxons( $dbh, $taxon_dbh );

    my $contacts_href = getContacts($dbh);

    #$dbh->disconnect();

    # table header
    print qq{
        <table class='img' border='1'>
        <th class='img'>Genome ID</th>
        <th class='img'>Name</th>
        <th class='img'>Genus</th>
        <th class='img'>Species</th>
        <th class='img'>Strain</th>
        <th class='img'>NCBI Taxon ID</th>
        <th class='img'>RefSeq Project ID</th>
        <th class='img'>GenBank Project ID</th>
        <th class='img'>Domain</th>
        <th class='img'>Phylum</th>
        <th class='img'>IR Class</th>
        <th class='img'>IR Order</th>
        <th class='img'>Family</th>
        <th class='img'>Comments</th>
        <th class='img'>Seq Status</th>
        <th class='img'>Obsolete</th>
        <th class='img'>Is Low Quality</th>
        <th class='img'>Combined Sample</th>
        <th class='img'>IMG Version</th>
        <th class='img'>Add Date</th>
        <th class='img'>Mod Date</th>
        <th class='img'>Modified By</th>
    };

    my $count = 0;

    foreach my $taxon_oid ( sort keys %$data_href ) {
        my $line = $data_href->{$taxon_oid};
        my (
            $taxon_display_name, $genus,             $species,        $strain,        $ncbi_taxon_id,
            $domain,             $phylum,            $ir_class,       $ir_order,      $family,
            $comments,           $mod_date,          $modified_by,    $seq_status,    $add_date,
            $img_version,        $refseq_project_id, $gbk_project_id, $obsolete_flag, $is_low_quality,
            $combined_sample_flag
          )
          = split( /\t/, $line );

        my $domain_label = $domain;
        $domain_label = 'Microbiome' if ( $domain eq '*Microbiome' );
        $domain_label =~ s/:/_/g;

        my $username = $contacts_href->{$modified_by};

        $mod_date = "&nbsp;" if ( $mod_date eq "" );
        $username = "&nbsp;" if ( $username eq "" );

        print qq{
            <tr class='img'>
            <td class='img'>
	    };

        # lock value
        print hiddenVar( "taxonomy_lock$count",
            "$domain\t$phylum\t$ir_class\t$ir_order\t$family\t$genus\t$species\t$strain" );

        if ( $taxon_oid >= $er_start_taxon_oid ) {
            print qq{  $taxon_oid  };
        } else {
            print qq{ 
                <a href='main-edit.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid'> $taxon_oid </a> 
            };
        }
        print qq{
	    <input type='hidden' name='taxon_oid$count' value='$taxon_oid' />
	    <input type='hidden' name='taxon_filter_oid' value='$taxon_oid' />
            </td>
            
            <td class='img'>
            <input type='text' name='name$count' size='25' 
            value='$taxon_display_name'/> </td>
        };

        # TODO - select box
        print qq{
            <td class='img' nowrap>
            <input type="text" name="genus$count" value="$genus" >
            <input type='button' 
            onClick='targetitem = document.forms[1].genus$count; myshow(event, YAHOO.example.container.panel_genus);'
            value="List" >            
            </td>
        };

        # <input type='text' name='species$count' size='10' value='$species'/>
        print qq{
            <td class='img' nowrap>
            <input type="text" name="species$count" value="$species"> 
            <input type='button' 
            onClick='targetitem = document.forms[1].species$count; myshow(event, YAHOO.example.container.panel_species);'
            value="List" >             
            </td>
        };

        print qq{            
            <td class='img'>
            <input type='text' name='strain$count' size='10' value='$strain'/> 
            </td>            

            <td class='img'>
            <input type='text' name='ncbi_taxon_id$count' size='10'
            onKeyPress="return numbersonly(event)"  
            value='$ncbi_taxon_id'/> 
            </td>   

            <td class='img'>
            <input type='text' name='refseq_project_id$count' size='10'
            onKeyPress="return numbersonly(event)"  
            value='$refseq_project_id'/> 
            </td>  

            <td class='img'>
            <input type='text' name='gbk_project_id$count' size='10'
            onKeyPress="return numbersonly(event)"  
            value='$gbk_project_id'/> 
            </td>  
        };

        # domain
        # <input type='hidden' name='domain$count' value='$domain'/>
        print qq{
            <td class='img'> $domain 
            
        };
        printDomainSelectBox( $domain_aref, $domain, $count );

        print "</td>\n";

        # <input type='text' name='phylum$count' size='10' value='$phylum'/>
        print qq{
            <td class='img' nowrap>
            <input type="text" name="phylum$count" value="$phylum">
            <input type='button' 
            onClick='targetitem = document.forms[1].phylum$count; myshow(event, YAHOO.example.container.panel_phylum);'
            value="List" >             
            </td>
        };

        # <input type='text' name='ir_class$count' size='10' value='$ir_class'/>
        print qq{
            <td class='img' nowrap>
            <input type="text" name="ir_class$count" value="$ir_class">
            <input type='button' 
            onClick='targetitem = document.forms[1].ir_class$count; myshow(event, YAHOO.example.container.panel_ir_class);'
            value="List" >                
            </td>  
        };

        # <input type='text' name='ir_order$count' size='10' value='$ir_order'/>
        print qq{
            <td class='img' nowrap>
            <input type="text" name="ir_order$count" value="$ir_order">
          <input type='button' 
            onClick='targetitem = document.forms[1].ir_order$count; myshow(event, YAHOO.example.container.panel_ir_order);'
            value="List" >              
            </td>             
        };

        # <input type='text' name='family$count' size='10' value='$family'/>
        print qq{
            <td class='img' nowrap> 
            <input type="text" name="family$count" value="$family">
          <input type='button' 
            onClick='targetitem = document.forms[1].family$count; myshow(event, YAHOO.example.container.panel_family);'
            value="List" >             
            </td>  
        };

        print qq{
            <td class='img'>
            <input type='text' name='comments$count' size='10' 
            value='$comments'/> 
            </td>  
        };

        # seq status
        print qq{
            <td class='img'>
        };
        if ( $seq_status eq "Finished" ) {
            print qq{
            <select name='seq_status$count'>
            <option value="Draft">Draft</option>
            <option value="Permanent Draft">Permanent Draft</option>
            <option selected="selected" value="Finished">Finished</option>
            </select>
            };
        } elsif ( $seq_status eq "Permanent Draft" ) {

            # "Permanent Draft"
            print qq{
            <select name='seq_status$count'>
            <option value="Draft">Draft</option>
            <option selected="selected" value="Permanent Draft">Permanent Draft</option>
            <option value="Finished">Finished</option>
            </select>
            };
        } else {

            # "Draft"
            print qq{
            <select name='seq_status$count'>
            <option selected="selected" value="Draft">Draft</option>
            <option value="Permanent Draft">Permanent Draft</option>
            <option value="Finished">Finished</option>
            </select>
            };
        }
        print "</td>";

        # Obsolete
        print qq{
            <td class='img'>
        };
        if ( $obsolete_flag eq "Yes" ) {
            print qq{
            <select name='obsolete_flag$count'>
            <option value="No">No</option>
            <option selected="selected" value="Yes">Yes</option>
            </select>
        };
        } else {
            print qq{
            <select name='obsolete_flag$count'>
            <option selected="selected" value="No">No</option>
            <option value="Yes">Yes</option>
            </select>
        };
        }
        print "</td>";

        # is low quality $is_low_quality
        print qq{
            <td class='img'>
        };
        if ( $is_low_quality eq "Yes" ) {
            print qq{
            <select name='is_low_quality$count'>
            <option value="No">No</option>
            <option selected="selected" value="Yes">Yes</option>
            </select>
        };
        } else {
            print qq{
            <select name='is_low_quality$count'>
            <option selected="selected" value="No">No</option>
            <option value="Yes">Yes</option>
            </select>
        };
        }
        print "</td>";

        # combined sample
        print qq{
            <td class='img'>
        };
        if ( $combined_sample_flag eq "Yes" ) {
            print qq{
            <select name='combined_sample_flag$count'>
            <option value="No">No</option>
            <option selected="selected" value="Yes">Yes</option>
            </select>
        };
        } else {
            print qq{
            <select name='combined_sample_flag$count'>
            <option selected="selected" value="No">No</option>
            <option value="Yes">Yes</option>
            </select>
        };
        }
        print "</td>";

        print qq{
            <td class='img'> $img_version </td>
            <td class='img'> $add_date </td>
            <td class='img'> $mod_date </td>
            <td class='img'> $username </td>
            
            </tr>
        };
        $count++;
    }

    print "</table>\n";

    print qq{
    <input type='hidden' name='page' value='update' />
    <input type='hidden' name='section' value='TaxonEdit' />
    <input type='hidden' name='count' value='$count' />

    <input type=reset value="Reset Form" class='medbutton'>
    <input type="submit" name="update" value="Update" class="smdefbutton" 
    title='ONLY updates changes to staging db'/>
    &nbsp; 
    };

    my $url = "$section_cgi&page=taxonListPhylo";
    $url .= TaxonList::taxonListPhyloRestrictions();

    print qq{
    <input type='button' class='medbutton' value='View Phylogenetically'
    title='view tree created from staging database' 
    onClick='javascript:window.open("$url", "_self");' />       
    };

    print end_form();

    my $phylum_aref;
    my $ir_class_aref;
    my $ir_order_aref;
    my $family_aref;
    my $genus_aref;
    my $species_aref;

    $phylum_aref   = getCVPhylum( $taxon_dbh, '', "phylum" );
    $ir_class_aref = getCVPhylum( $taxon_dbh, '', "ir_class" );
    $ir_order_aref = getCVPhylum( $taxon_dbh, '', "ir_order" );
    $family_aref   = getCVPhylum( $taxon_dbh, '', "family" );
    $genus_aref    = getCVPhylum( $taxon_dbh, '', "genus" );
    $species_aref  = getCVPhylum( $taxon_dbh, '', "species" );

    printPanel( "phylum",   $phylum_aref,   "panel_phylum" );
    printPanel( "ir_class", $ir_class_aref, "panel_ir_class" );
    printPanel( "ir_order", $ir_order_aref, "panel_ir_order" );
    printPanel( "family",   $family_aref,   "panel_family" );
    printPanel( "genus",    $genus_aref,    "panel_genus" );
    printPanel( "species",  $species_aref,  "panel_species" );

    print "</div>\n";

    $taxon_dbh->disconnect();

    WebUtil::printStatusLine_old( "$count Loaded.", 2 );

    print <<YUI;

<script>
        YAHOO.namespace("example.container");

        function init() {
            // Instantiate a Panel from markup

            YAHOO.example.container.panel_phylum = new YAHOO.widget.Panel("panel_phylum", { width:"320px", height:"300px", visible:false, constraintoviewport:true } );
            YAHOO.example.container.panel_phylum.render();

            YAHOO.example.container.panel_ir_class = new YAHOO.widget.Panel("panel_ir_class", { width:"320px", height:"300px", visible:false, constraintoviewport:true } );
            YAHOO.example.container.panel_ir_class.render();                

            YAHOO.example.container.panel_ir_order = new YAHOO.widget.Panel("panel_ir_order", { width:"320px", height:"300px", visible:false, constraintoviewport:true } );
            YAHOO.example.container.panel_ir_order.render();                

            YAHOO.example.container.panel_family = new YAHOO.widget.Panel("panel_family", { width:"320px", height:"300px", visible:false, constraintoviewport:true } );
            YAHOO.example.container.panel_family.render();                

            YAHOO.example.container.panel_genus = new YAHOO.widget.Panel("panel_genus", { width:"320px", height:"300px", visible:false, constraintoviewport:true } );
            YAHOO.example.container.panel_genus.render();                

            YAHOO.example.container.panel_species = new YAHOO.widget.Panel("panel_species", { width:"320px", height:"300px", visible:false, constraintoviewport:true } );
            YAHOO.example.container.panel_species.render();                
        }

        YAHOO.util.Event.addListener(window, "load", init);

        function select_item(item) {
            targetitem.value = item;
            YAHOO.example.container.panel_phylum.hide();
            YAHOO.example.container.panel_ir_class.hide();
            YAHOO.example.container.panel_ir_order.hide();
            YAHOO.example.container.panel_family.hide();
            YAHOO.example.container.panel_genus.hide();
            YAHOO.example.container.panel_species.hide();
        }
        
        function myshow(e, panel) {
            e = e || window.event;
            var mouseXY = YAHOO.util.Event.getXY(e);
            panel.moveTo(mouseXY[0], mouseXY[1]); 
            panel.show();
        }
        
</script>
YUI

}

#
# old
#
sub taxonEditForm {

    print "<h1>Genome Editor - User Selected</h1>\n";

    # user selected taxons
    my @taxon_filter_oid = param("taxon_filter_oid");
    if ( $#taxon_filter_oid < 0 ) {
        webError("Please select some genomes to edit");
    }

    printJavaScript();

    WebUtil::printStatusLine_old( "Loading ...", 1 );

    print qq{
       <form method="post" 
       action="main-edit.cgi" 
       enctype="multipart/form-data" 
       onReset="return confirm('Do you really want to reset the form?')"
       name="mainForm">
    };

    # db to standard img
    my $dbh       = dbLogin();
    my $taxon_dbh = taxonDbLogin();

    # taxon oid => line of tab delimited
    my $data_href = getTaxons( $dbh, $taxon_dbh );

    my $contacts_href = getContacts($dbh);

    #$dbh->disconnect();

    # table header
    print qq{
        <table class='img' border='1'>
        <th class='img'>Genome ID</th>
        <th class='img'>Name</th>
        <th class='img'>Genus</th>
        <th class='img'>Species</th>
        <th class='img'>Strain</th>
        <th class='img'>NCBI Taxon ID</th>
        <th class='img'>RefSeq Project ID</th>
        <th class='img'>GenBank Project ID</th>
        <th class='img'>Domain</th>
        <th class='img'>Phylum</th>
        <th class='img'>IR Class</th>
        <th class='img'>IR Order</th>
        <th class='img'>Family</th>
        <th class='img'>Comments</th>
        <th class='img'>Seq Status</th>
        <th class='img'>Obsolete</th>
        <th class='img'>Is Low Quality</th>
        <th class='img'>Combined Sample</th>
        <th class='img'>IMG Version</th>
        <th class='img'>Add Date</th>
        <th class='img'>Mod Date</th>
        <th class='img'>Modified By</th>
    };

    my $count       = 0;
    my $last_domain = "";
    my $phylum_aref;
    my $ir_class_aref;
    my $ir_order_aref;
    my $family_aref;
    my $genus_aref;
    my $species_aref;

    my $domain_aref = getCVDomain($taxon_dbh);

    foreach my $taxon_oid ( sort keys %$data_href ) {
        my $line = $data_href->{$taxon_oid};
        my (
            $taxon_display_name, $genus,             $species,        $strain,        $ncbi_taxon_id,
            $domain,             $phylum,            $ir_class,       $ir_order,      $family,
            $comments,           $mod_date,          $modified_by,    $seq_status,    $add_date,
            $img_version,        $refseq_project_id, $gbk_project_id, $obsolete_flag, $is_low_quality,
            $combined_sample_flag
          )
          = split( /\t/, $line );

        # get CV for phylum, ir_class, ir_order, family, genus, species
        if ( $domain ne $last_domain ) {
            $phylum_aref   = getCVPhylum( $taxon_dbh, $domain, "phylum" );
            $ir_class_aref = getCVPhylum( $taxon_dbh, $domain, "ir_class" );
            $ir_order_aref = getCVPhylum( $taxon_dbh, $domain, "ir_order" );
            $family_aref   = getCVPhylum( $taxon_dbh, $domain, "family" );
            $genus_aref    = getCVPhylum( $taxon_dbh, $domain, "genus" );
            $species_aref  = getCVPhylum( $taxon_dbh, $domain, "species" );
        }
        $last_domain = $domain;

        my $username = $contacts_href->{$modified_by};

        $mod_date = "&nbsp;" if ( $mod_date eq "" );
        $username = "&nbsp;" if ( $username eq "" );

        print qq{
            <tr class='img'>
            <td class='img'>
        };

        if ( $taxon_oid >= $er_start_taxon_oid ) {
            print qq{  $taxon_oid  };
        } else {
            print qq{ 
                <a href='main-edit.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid'> $taxon_oid </a> 
            };
        }
        print qq{
        <input type='hidden' name='taxon_oid$count' value='$taxon_oid' />
        <input type='hidden' name='taxon_filter_oid' value='$taxon_oid' />
            </td>
            
            <td class='img'>
            <input type='text' name='name$count' size='25' 
            value='$taxon_display_name'/> </td>
        };

        # TODO - select box
        # <input type='text' name='genus$count' size='10' value='$genus'/>
        my $str = join( $delimiter_selectbox, @$genus_aref );
        print qq{
            <td class='img'>
            <input type="text" name="genus$count" value="$genus" selectBoxOptions="$str">
            </td>
        };

        # <input type='text' name='species$count' size='10' value='$species'/>
        my $str = join( $delimiter_selectbox, @$species_aref );
        print qq{
            <td class='img'>
            <input type="text" name="species$count" value="$species" selectBoxOptions="$str"> 
            </td>
        };

        print qq{            
            <td class='img'>
            <input type='text' name='strain$count' size='10' value='$strain'/> 
            </td>            

            <td class='img'>
            <input type='text' name='ncbi_taxon_id$count' size='10'
            onKeyPress="return numbersonly(event)"  
            value='$ncbi_taxon_id'/> 
            </td>   

            <td class='img'>
            <input type='text' name='refseq_project_id$count' size='10'
            onKeyPress="return numbersonly(event)"  
            value='$refseq_project_id'/> 
            </td>  

            <td class='img'>
            <input type='text' name='gbk_project_id$count' size='10'
            onKeyPress="return numbersonly(event)"  
            value='$gbk_project_id'/> 
            </td>  
        };

        # domain
        # <input type='hidden' name='domain$count' value='$domain'/>
        print qq{
            <td class='img'> $domain 
            
        };
        printDomainSelectBox( $domain_aref, $domain, $count );

        print "</td>\n";

        # <input type='text' name='phylum$count' size='10' value='$phylum'/>
        my $str = join( $delimiter_selectbox, @$phylum_aref );
        print qq{
            <td class='img'>
            <input type="text" name="phylum$count" value="$phylum" selectBoxOptions="$str">
            </td>
        };

        # <input type='text' name='ir_class$count' size='10' value='$ir_class'/>
        my $str = join( $delimiter_selectbox, @$ir_class_aref );
        print qq{
            <td class='img'>
            <input type="text" name="ir_class$count" value="$ir_class" selectBoxOptions="$str">
            </td>  
        };

        # <input type='text' name='ir_order$count' size='10' value='$ir_order'/>
        my $str = join( $delimiter_selectbox, @$ir_order_aref );
        print qq{
            <td class='img'>
            <input type="text" name="ir_order$count" value="$ir_order" selectBoxOptions="$str">
            </td>             
        };

        # <input type='text' name='family$count' size='10' value='$family'/>
        my $str = join( $delimiter_selectbox, @$family_aref );
        print qq{
            <td class='img'> 
            <input type="text" name="family$count" value="$family" selectBoxOptions="$str">
            </td>  
        };

        print qq{
            <td class='img'>
            <input type='text' name='comments$count' size='10' 
            value='$comments'/> 
            </td>  
        };

        # seq status
        print qq{
            <td class='img'>
        };
        if ( $seq_status eq "Finished" ) {
            print qq{
            <select name='seq_status$count'>
            <option value="Draft">Draft</option>
            <option value="Permanent Draft">Permanent Draft</option>
            <option selected="selected" value="Finished">Finished</option>
            </select>
            };
        } elsif ( $seq_status eq "Permanent Draft" ) {

            # "Permanent Draft"
            print qq{
            <select name='seq_status$count'>
            <option value="Draft">Draft</option>
            <option selected="selected" value="Permanent Draft">Permanent Draft</option>
            <option value="Finished">Finished</option>
            </select>
            };
        } else {

            # "Draft"
            print qq{
            <select name='seq_status$count'>
            <option selected="selected" value="Draft">Draft</option>
            <option value="Permanent Draft">Permanent Draft</option>
            <option value="Finished">Finished</option>
            </select>
            };
        }
        print "</td>";

        # Obsolete
        print qq{
            <td class='img'>
        };
        if ( $obsolete_flag eq "Yes" ) {
            print qq{
            <select name='obsolete_flag$count'>
            <option value="No">No</option>
            <option selected="selected" value="Yes">Yes</option>
            </select>
        };
        } else {
            print qq{
            <select name='obsolete_flag$count'>
            <option selected="selected" value="No">No</option>
            <option value="Yes">Yes</option>
            </select>
        };
        }
        print "</td>";

        # is low quality $is_low_quality
        print qq{
            <td class='img'>
        };
        if ( $is_low_quality eq "Yes" ) {
            print qq{
            <select name='is_low_quality$count'>
            <option value="No">No</option>
            <option selected="selected" value="Yes">Yes</option>
            </select>
        };
        } else {
            print qq{
            <select name='is_low_quality$count'>
            <option selected="selected" value="No">No</option>
            <option value="Yes">Yes</option>
            </select>
        };
        }
        print "</td>";

        # combined sample
        print qq{
            <td class='img'>
        };
        if ( $combined_sample_flag eq "Yes" ) {
            print qq{
            <select name='combined_sample_flag$count'>
            <option value="No">No</option>
            <option selected="selected" value="Yes">Yes</option>
            </select>
        };
        } else {
            print qq{
            <select name='combined_sample_flag$count'>
            <option selected="selected" value="No">No</option>
            <option value="Yes">Yes</option>
            </select>
        };
        }
        print "</td>";
        print qq{
            <td class='img'> $img_version </td>
            <td class='img'> $add_date </td>
            <td class='img'> $mod_date </td>
            <td class='img'> $username </td>
            
            </tr>
        };
        $count++;
    }

    print "</table>\n";

    $taxon_dbh->disconnect();

    WebUtil::printStatusLine_old( "$count Loaded.", 2 );

    print qq{
    <input type='hidden' name='page' value='update' />
    <input type='hidden' name='section' value='TaxonEdit' />
    <input type='hidden' name='count' value='$count' />

    <input type=reset value="Reset Form" class='medbutton'>
    <input type="submit" name="update" value="Update" class="smdefbutton" 
    title='ONLY updates changes to staging db'/>
    &nbsp; 
    };

    my $url = "$section_cgi&page=taxonListPhylo";
    $url .= TaxonList::taxonListPhyloRestrictions();

    print qq{
    <input type='button' class='medbutton' value='View Phylogenetically'
    title='view tree created from staging database' 
    onClick='javascript:window.open("$url", "_self");' />       
    };

    print end_form();

    print qq{
        <script type="text/javascript">
    };
    for ( my $i = 0 ; $i < $count ; $i++ ) {
        print qq{
        createEditableSelect(document.mainForm.genus$i);
        createEditableSelect(document.mainForm.species$i);
        createEditableSelect(document.mainForm.phylum$i);
        createEditableSelect(document.mainForm.ir_class$i);
        createEditableSelect(document.mainForm.ir_order$i);
        createEditableSelect(document.mainForm.family$i);
        };
    }
    print qq{
        </script>        
    };

}

sub taxonOneEditForm {
    my $taxon_oid = param("taxon_oid");

    print "<h1>Genome Editor</h1>\n";

    WebUtil::printStatusLine_old( "Loading ...", 1 );

    printJavaScript();

    #printMainForm();
    print qq{
       <form method="post" 
       action="main-edit.cgi" 
       enctype="multipart/form-data" 
       onReset="return confirm('Do you really want to reset the form?')"
       name="mainForm">
    };

    my $taxon_dbh = taxonDbLogin();

    # line of tab delimited
    my $line = getOneTaxon( $taxon_dbh, $taxon_oid );
    my (
        $taxon_display_name,   $genus,             $species,        $strain,        $ncbi_taxon_id,
        $domain,               $phylum,            $ir_class,       $ir_order,      $family,
        $comments,             $mod_date,          $modified_by,    $seq_status,    $add_date,
        $img_version,          $refseq_project_id, $gbk_project_id, $obsolete_flag, $is_low_quality,
        $combined_sample_flag, $high_quality_flag, $taxonomy_lock, $locked_by, $lock_date
      )
      = split( /\t/, $line );

    # Current DB values
    # if any of the follow values are update lock the taxon from being updated via Amy's sync from gold
    # fields to trigger lock:
    # Domain, Phylum, IR Class, IR Order, Family, Genus, Species, Strain
    # lock colums:
    print hiddenVar( 'taxonomy_lock', "$domain\t$phylum\t$ir_class\t$ir_order\t$family\t$genus\t$species\t$strain" );

    # domain
    my $domain_aref = getCVDomain($taxon_dbh);

    # get CV for phylum, ir_class, ir_order, family, genus, species
    my $phylum_aref   = getCVPhylum( $taxon_dbh, $domain, "phylum" );
    my $ir_class_aref = getCVPhylum( $taxon_dbh, $domain, "ir_class" );
    my $ir_order_aref = getCVPhylum( $taxon_dbh, $domain, "ir_order" );
    my $family_aref   = getCVPhylum( $taxon_dbh, $domain, "family" );
    my $genus_aref    = getCVPhylum( $taxon_dbh, $domain, "genus" );
    my $species_aref  = getCVPhylum( $taxon_dbh, $domain, "species" );

    $taxon_dbh->disconnect();

    # db to standard img
    my $dbh           = dbLogin();
    my $contacts_href = getContacts($dbh);

    #$dbh->disconnect();

    my $username = $contacts_href->{$modified_by};

    $mod_date = "&nbsp;" if ( $mod_date eq "" );
    $username = "&nbsp;" if ( $username eq "" );

    my $textsize = 50;

    print qq{
        <table class='img' border='1'>
        
        <tr class='img'>
        <th class='img'>Genome ID</th>
            <td class='img'> 
	    };

    #<a href='main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid'> $taxon_oid </a>
    if ( $taxon_oid >= $er_start_taxon_oid ) {
        print qq{  $taxon_oid  };
    } else {
        print qq{ <a href='main-edit.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid'> $taxon_oid </a> };
    }
    print qq{        <input type='hidden' name='taxon_oid' value='$taxon_oid' /> 
            </td>
        </tr>
        
        <tr class='img'>
        <th class='img'>Name</th>
            <td class='img'>
            <input type='text' name='name' size='$textsize' 
            value='$taxon_display_name'/> </td>
        </tr>
      };

    # <input type='text' name='genus' size='$textsize' value='$genus'/>
    my $str = join( $delimiter_selectbox, @$genus_aref );
    print qq{
        <tr class='img'>
        <th class='img'>Genus</th>
            <td class='img'>
            <input type="text" name="genus" value="$genus" selectBoxOptions="$str">
            </td>
        </tr>
      };

    # <input type='text' name='species' size='$textsize' value='$species'/>
    my $str = join( $delimiter_selectbox, @$species_aref );
    print qq{
        <tr class='img'>
        <th class='img'>Species</th>
            <td class='img'>
             <input type="text" name="species" value="$species" selectBoxOptions="$str">
            </td>
        </tr>
      };

    print qq{
        <tr class='img'>
        <th class='img'>Strain</th>
            <td class='img'>
            <input type='text' name='strain' size='$textsize' 
            value='$strain'/> </td> 
        </tr>

        <tr class='img'>
        <th class='img'>NCBI Taxon ID</th>
            <td class='img'>
            <input type='text' name='ncbi_taxon_id' size='$textsize'
            onKeyPress="return numbersonly(event)" 
            value='$ncbi_taxon_id'/> </td>   
        </tr>

        <tr class='img'>
        <th class='img'>Refseq Project ID</th>
            <td class='img'>
            <input type='text' name='refseq_project_id' size='$textsize'
            onKeyPress="return numbersonly(event)" 
            value='$refseq_project_id'/> </td>   
        </tr>

        <tr class='img'>
        <th class='img'>GenBank Project ID</th>
            <td class='img'>
            <input type='text' name='gbk_project_id' size='$textsize'
            onKeyPress="return numbersonly(event)" 
            value='$gbk_project_id'/> </td>   
        </tr>

        <tr class='img'>
        <th class='img'>Domain</th>
            <td class='img'> $domain
      };

    printDomainSelectBox( $domain_aref, $domain );

    print "</td></tr>\n";

    # <input type='text' name='phylum' size='$textsize' value='$phylum'/>
    my $str = join( $delimiter_selectbox, @$phylum_aref );
    print qq{
        <tr class='img'>
        <th class='img'>Phylum</th>
            <td class='img'>
            <input type="text" name="phylum" value="$phylum" selectBoxOptions="$str"> 
            </td>
        </tr>
      };

    # <input type='text' name='ir_class' size='$textsize' value='$ir_class'/>
    my $str = join( $delimiter_selectbox, @$ir_class_aref );
    print qq{
        <tr class='img'>
        <th class='img'>IR Class</th>
            <td class='img'>
            <input type="text" name="ir_class" value="$ir_class" selectBoxOptions="$str">
            </td>
        </tr>
      };

    # <input type='text' name='ir_order' size='$textsize' value='$ir_order'/>
    my $str = join( $delimiter_selectbox, @$ir_order_aref );
    print qq{
        <tr class='img'>
        <th class='img'>IR Order</th>
            <td class='img'>
            <input type="text" name="ir_order" value="$ir_order" selectBoxOptions="$str">
            </td>
        </tr>
      };

    # <input type='text' name='family' size='$textsize' value='$family'/>
    my $str = join( $delimiter_selectbox, @$family_aref );
    print qq{
        <tr class='img'>
        <th class='img'>Family</th>
            <td class='img'>
            <input type="text" name="family" value="$family" selectBoxOptions="$str">
            </td>
        </tr>
      };

    print qq{
        <tr class='img'>
        <th class='img'>Comments</th>
            <td class='img'>
            <input type='text' name='comments' size='$textsize' 
            value='$comments'/> </td>
        </tr>
     };

    # seq status
    print qq{
        <tr class='img'>
        <th class='img'>Seq Status</th>
        <td class='img'>
    };
    if ( $seq_status eq "Finished" ) {
        print qq{
            <select name='seq_status'>
            <option value="Draft">Draft</option>
            <option value="Permanent Draft">Permanent Draft</option>
            <option selected="selected" value="Finished">Finished</option>
            </select>
        };
    } elsif ( $seq_status eq "Permanent Draft" ) {

        # "Permanent Draft"
        print qq{
            <select name='seq_status'>
            <option value="Draft">Draft</option>
            <option selected="selected" value="Permanent Draft">Permanent Draft</option>
            <option value="Finished">Finished</option>
            </select>
        };
    } else {

        # "Draft"
        print qq{
            <select name='seq_status'>
            <option selected="selected" value="Draft">Draft</option>
            <option value="Permanent Draft">Permanent Draft</option>
            <option value="Finished">Finished</option>
            </select>
        };
    }
    print "</td></tr>\n";

    # is_low_quality
    print qq{
        <tr class='img'>
        <th class='img'>Low Quality</th>
        <td class='img'>
    };
    if ( $is_low_quality eq "Yes" ) {
        print qq{
            <select name='is_low_quality'>
            <option value="No"> No </option>
            <option selected="selected" value="Yes"> Yes </option>
            </select>
        };
    } else {
        print qq{
            <select name='is_low_quality'>
            <option selected="selected"  value="No"> No </option>
            <option value="Yes"> Yes </option>
            </select>
        };
    }
    print "</td></tr>\n";

    # obsolete
    print qq{
        <tr class='img'>
        <th class='img'>Obsolete</th>
        <td class='img'>
    };
    if ( $obsolete_flag eq "Yes" ) {
        print qq{
            <select name='obsolete_flag'>
            <option value="No"> No </option>
            <option selected="selected" value="Yes"> Yes </option>
            </select>
        };
    } else {
        print qq{
            <select name='obsolete_flag'>
            <option selected="selected"  value="No"> No </option>
            <option value="Yes"> Yes </option>
            </select>
        };
    }
    print "</td></tr>\n";

    # combined sample
    print qq{
        <tr class='img'>
        <th class='img'>Combined Sample</th>
        <td class='img'>
    };
    if ( $combined_sample_flag eq "Yes" ) {
        print qq{
            <select name='combined_sample_flag'>
            <option value="No"> No </option>
            <option selected="selected" value="Yes"> Yes </option>
            </select>
        };
    } else {
        print qq{
            <select name='combined_sample_flag'>
            <option selected="selected"  value="No"> No </option>
            <option value="Yes"> Yes </option>
            </select>
        };
    }
    print "</td></tr>\n";

    # high_quality_flag
    print qq{
        <tr class='img'>
        <th class='img'>High Quality</th>
        <td class='img'>
    };
    if ( $high_quality_flag eq "Yes" ) {
        print qq{
            <select name='high_quality_flag'>
            <option value="No"> No </option>
            <option selected="selected" value="Yes"> Yes </option>
            </select>
        };
    } else {
        print qq{
            <select name='high_quality_flag'>
            <option selected="selected"  value="No"> No </option>
            <option value="Yes"> Yes </option>
            </select>
        };
    }
    print "</td></tr>\n";


    my $username_lock = $contacts_href->{$locked_by};
    
    print qq{       
        <tr class='img'>
        <th class='img'>IMG Version</th>
            <td class='img'> $img_version </td>
        </tr>
        
        <tr class='img'>
        <th class='img'>Add Date</th>
            <td class='img'> $add_date </td>
        </tr>

        <tr class='img'>
        <th class='img'>Mod Date</th>
            <td class='img'> $mod_date </td>
        </tr>

        
        <tr class='img'>
        <th class='img'>Modified By</th>
            <td class='img'> $username </td>
        </tr>


        <tr class='img'>
        <th class='img'>Taxonomy Lock</th>
            <td class='img'> $taxonomy_lock </td>
        </tr>
        <tr class='img'>
        <th class='img'>Locked By</th>
            <td class='img'> $username_lock </td>
        </tr>
        <tr class='img'>
        <th class='img'>Lock Date</th>
            <td class='img'> $lock_date </td>
        </tr>

        
        </table>        
    };
    
    # $high_quality_flag, $taxonomy_lock, $locked_by, $lock_date

    WebUtil::printStatusLine_old( "Loaded.", 2 );

    print qq{
    <input type='hidden' name='page' value='updateOne' />
    <input type='hidden' name='section' value='TaxonEdit' />

    <input type=reset value="Reset Form" class='medbutton'>
    <input type="submit" name="update" value="Update" class="smdefbutton" 
    title='ONLY updates changes to staging db'/>
    &nbsp; 
    };

    my $url = "$section_cgi&page=taxonListPhylo&domain=$domain";

    $url .= TaxonList::taxonListPhyloRestrictions();

    print qq{
    <input type='button' class='medbutton' value='View Phylogenetically'
    title='view tree created from staging database' 
    onClick='javascript:window.open("$url", "_self");' />       
    };

    print end_form();

    print qq{
    <script type="text/javascript">
    createEditableSelect(document.mainForm.genus);
    createEditableSelect(document.mainForm.species);
    createEditableSelect(document.mainForm.phylum);
    createEditableSelect(document.mainForm.ir_class);
    createEditableSelect(document.mainForm.ir_order);
    createEditableSelect(document.mainForm.family);
    </script>        
    };
}

sub printDomainSelectBox {
    my ( $domain_aref, $domainSelected, $count ) = @_;
    if ( $count ne "" ) {
        my $tmp = "domain" . $count;
        print "<select name='$tmp'>\n";
    } else {
        print "<select name='domain'>\n";
    }
    foreach my $x (@$domain_aref) {
        my $ck = "";
        if ( $domainSelected eq $x ) {
            $ck = "selected='selected'";
        }

        print qq{
            <option  value='$x' $ck > $x </option>
            };

    }
    print "</select>\n";

}

#
# get list of super users
#
sub getContacts {
    my ($dbh) = @_;

    # contact oid => username
    my %data;

    my $sql = qq{
        select contact_oid, username
        from contact
        where super_user = 'Yes'        
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $oid, $name ) = $cur->fetchrow();
        last if !$oid;
        $data{$oid} = $name;
    }
    $cur->finish();

    return \%data;
}

#
# get taxons to edit
#
sub getTaxons {
    my ( $dbh, $taxon_dbh ) = @_;

    my $taxonClause = txsClause( "tx", $dbh );

    #    my $sql1 = qq{
    #        select tx.taxon_oid
    #        from taxon tx
    #        where 1 = 1
    #        $taxonClause
    #        order by tx.taxon_oid
    #    };

    my $sql2 = qq{
        select tx.taxon_oid, tx.taxon_display_name, tx.genus, tx.species, 
        tx.strain, tx.ncbi_taxon_id, 
        tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family, tx.comments, 
        to_char(tx.mod_date, 'yyyy-mm-dd hh24:mi'), 
        modified_by, seq_status,
        to_char(tx.add_date, 'yyyy-mm-dd hh24:mi'),
        tx.img_version, tx.refseq_project_id, tx.gbk_project_id, nvl(tx.obsolete_flag, 'No'),
        nvl(tx.is_low_quality, 'No'), nvl(tx.combined_sample_flag, 'No') 
        from taxon tx
        where tx.taxon_oid in (_XXX_)
    };

    #my $cur = execSql( $dbh, $sql1, $verbose );
    my @taxon_oids;

    #for ( ; ; ) {
    #    my ($taxon_oid) = $cur->fetchrow();
    #    last if !$taxon_oid;
    #    push( @taxon_oids, $taxon_oid );
    #}
    #$cur->finish();
    my @taxon_filter_oid = param("taxon_filter_oid");
    my %h                = WebUtil::array2Hash(@taxon_filter_oid);    # get unique taxon_oid's
    @taxon_oids = sort( keys(%h) );

    $sql2 = WebUtil::bigInQuery( $sql2, "_XXX_", \@taxon_oids );
    my $cur2 = execSql( $taxon_dbh, $sql2, $verbose );

    my %data;
    for ( ; ; ) {
        my (
            $taxon_oid,      $taxon_display_name, $genus,             $species,        $strain,
            $ncbi_taxon_id,  $domain,             $phylum,            $ir_class,       $ir_order,
            $family,         $comments,           $mod_date,          $modified_by,    $seq_status,
            $add_date,       $img_version,        $refseq_project_id, $gbk_project_id, $obsolete_flag,
            $is_low_quality, $combined_sample_flag
          )
          = $cur2->fetchrow();
        last if !$taxon_oid;

        $data{$taxon_oid} =
            "$taxon_display_name\t$genus\t$species\t"
          . "$strain\t$ncbi_taxon_id\t$domain\t$phylum\t"
          . "$ir_class\t$ir_order\t$family\t$comments\t"
          . "$mod_date\t$modified_by\t$seq_status\t"
          . "$add_date\t$img_version\t$refseq_project_id\t$gbk_project_id\t$obsolete_flag\t$is_low_quality"
          . "\t$combined_sample_flag";

    }
    $cur2->finish();

    return \%data;
}

sub getOneTaxon {
    my ( $taxon_dbh, $taxon_oid ) = @_;

    my $sql2 = qq{
        select tx.taxon_oid, tx.taxon_display_name, tx.genus, tx.species, 
        tx.strain, tx.ncbi_taxon_id, 
        tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family, tx.comments, 
        to_char(tx.mod_date, 'yyyy-mm-dd hh24:mi'), 
        tx.modified_by, tx.seq_status,
        to_char(tx.add_date, 'yyyy-mm-dd hh24:mi'),
        tx.img_version, tx.refseq_project_id, tx.gbk_project_id, nvl(tx.obsolete_flag, 'No'),
        nvl(tx.is_low_quality, 'No'), nvl(tx.combined_sample_flag, 'No'), nvl(tx.high_quality_flag, 'No'),
        taxonomy_lock,  locked_by,  to_char(lock_date, 'yyyy-mm-dd hh24:mi')
        from taxon tx
        where tx.taxon_oid = ?
    };

    my $cur2 = execSql( $taxon_dbh, $sql2, $verbose, $taxon_oid );

    my (
        $taxon_oid,      $taxon_display_name, $genus,             $species,        $strain,
        $ncbi_taxon_id,  $domain,             $phylum,            $ir_class,       $ir_order,
        $family,         $comments,           $mod_date,          $modified_by,    $seq_status,
        $add_date,       $img_version,        $refseq_project_id, $gbk_project_id, $obsolete_flag,
        $is_low_quality, $combined_sample_flag, $is_high_quality,
        $taxonomy_lock,  $locked_by,  $lock_date
      )
      = $cur2->fetchrow();

    $cur2->finish();

    return "$taxon_display_name\t$genus\t$species\t"
      . "$strain\t$ncbi_taxon_id\t$domain\t$phylum\t"
      . "$ir_class\t$ir_order\t$family\t$comments\t"
      . "$mod_date\t$modified_by\t$seq_status\t"
      . "$add_date\t$img_version\t$refseq_project_id\t$gbk_project_id\t$obsolete_flag\t$is_low_quality\t$combined_sample_flag\t"
      . "$is_high_quality\t$taxonomy_lock\t$locked_by\t$lock_date";
}

#
# copy from TaxonList.pm
#
sub printTaxonTree {
    my $taxon_filter_oid_str = WebUtil::getTaxonFilterOidStr();
    my @taxon_oids = split( /,/, $taxon_filter_oid_str );
    my %taxon_filter;
    for my $t (@taxon_oids) {
        $taxon_filter{$t} = $t;
    }

    print "<h1>Genome Browser</h1>\n";

    #    print qq{
    #        <p>
    #        <a href='main.cgi?section=TaxonEdit'>Edit Selected Genomes.</a>
    #        </p>
    #    };

    my $dbh = taxonDbLogin();

    printMainForm();

    print submit(
        -name  => 'edit',
        -value => 'Edit Selections',
        -class => 'smdefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All'  "
      . "onClick='selectAllTaxons(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All'  " . "onClick='selectAllTaxons(0)' class='smbutton' />\n";
    print nbsp(1);

    TaxonSearchUtil::printNotes();

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree( "pageRestrictedMicrobes", $dbh );
    my @keys             = keys(%taxon_filter);
    my $taxon_filter_cnt = @keys;

    # $editor - 1 flag to print edit button
    $mgr->printSelectableTree( \%taxon_filter, $taxon_filter_cnt, 1 );
    print "<br/>\n";
    print "</p>\n";

    print hiddenVar( "page",    "taxonEditForm" );
    print hiddenVar( "section", "TaxonEdit" );
    print submit(
        -name  => 'Edit',
        -value => 'Edit Selections',
        -class => 'smdefbutton'
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All'  "
      . "onClick='selectAllTaxons(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All'  " . "onClick='selectAllTaxons(0)', class='smbutton' />\n";

    #$dbh->disconnect();
    print end_form();
}

#
# get new taxon ranks
#
sub getTaxonRank {
    my ($taxon_dbh) = @_;

    my $sql = qq{
        select taxon_oid, domain, phylum, ir_class, ir_order, family, 
        genus, species, strain, taxon_name
        from taxon
        order by domain, phylum, ir_class, ir_order, family, genus, species, 
        strain, taxon_name        
    };

    my @recs;

    my $cur = execSql( $taxon_dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $strain, $taxon_name ) =
          $cur->fetchrow();
        last if !$taxon_oid;
        push( @recs,
            "$taxon_oid\t$domain\t$phylum\t$ir_class\t$ir_order\t" . "$family\t$genus\t$species\t$strain\t$taxon_name" );
    }
    $cur->finish();

    return \@recs;
}

# read data file to create tree
sub processFile {
    my ( $data_aref, $taxonTree_ref ) = @_;

    foreach my $s (@$data_aref) {

        my ( $taxon_oid, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $strain, $taxon_name ) =
          split( /\t/, $s );

        my $domain_ref    = $taxonTree_ref;
        my $phylum_ref    = getHash( $domain_ref, $domain );
        my $ir_class_ref  = getHash( $phylum_ref, $phylum );
        my $ir_order_ref  = getHash( $ir_class_ref, $ir_class );
        my $family_ref    = getHash( $ir_order_ref, $ir_order );
        my $genus_ref     = getHash( $family_ref, $family );
        my $species_ref   = getHash( $genus_ref, $genus );
        my $strain_ref    = getHash( $species_ref, $species );
        my $taxon_oid_ref = getHash( $strain_ref, "$strain\t$taxon_oid" );
    }
}

#
# printTree to a tab delimited file - for sql loader
#
sub printTree {
    my ( $fh, $taxonTree_ref, $data_aref, $level, $nodeCount_ref, $parentNode ) = @_;
    my @keys = sort( keys(%$taxonTree_ref) );
    $$nodeCount_ref++;
    for my $k (@keys) {
        my ( $key, $taxon_oid ) = split( /\t/, $k );

        #        print " " x ( $level * 2 );
        #        print sprintf( "%02d", $level );
        #        print " '$key' parent=$parentNode nodeId=$$nodeCount_ref ";
        #        print "taxon_oid='$taxon_oid'<br/>\n";

        my $rank_name = "Domain";
        $rank_name = "Phylum"   if $level == 1;
        $rank_name = "IR_Class" if $level == 2;
        $rank_name = "IR_Order" if $level == 3;
        $rank_name = "Family"   if $level == 4;
        $rank_name = "Genus"    if $level == 5;
        $rank_name = "Species"  if $level == 6;
        $rank_name = "Strain"   if $level == 7;
        print $fh "$$nodeCount_ref\t";
        print $fh "$key\t";
        print $fh "$rank_name\t";
        print $fh "$taxon_oid\t";
        print $fh "$parentNode\n";

        push( @$data_aref, "$$nodeCount_ref\t$key\t$rank_name\t$taxon_oid\t$parentNode" );

        my $t2 = $taxonTree_ref->{$k};
        printTree( $fh, $t2, $data_aref, $level + 1, $nodeCount_ref, $$nodeCount_ref );
    }
}

#
# getHash - If not found, create it.
#
sub getHash {
    my ( $h_ref, $name ) = @_;
    my $h2 = $h_ref->{$name};
    return $h2 if defined($h2);
    my $h = {};
    $h_ref->{$name} = $h;
    return $h;
}

#
# delete table dt_taxon_node_lite
#
sub deleteTable {
    my ($dbh) = @_;

    my $sql = "truncate table dt_taxon_node_lite";

    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();

    print "<p>Number of rows deleted : " . $cur->rows;
    print "</p>\n";
}

#
# start sql loader
#
sub sqlLoader {
    my ($dbh) = @_;

    my $inTabFile = "$cgi_tmp_dir/dt_taxon_node_lite.tab.txt";

    my $outCtlFile = "$cgi_tmp_dir/dt_taxon_node_lite.ctl";

    open( Fin, "< $inTabFile" )
      || webDie(" cannot read '$inTabFile'\n");
    my $header = <Fin>;
    close Fin;
    chop $header;
    my (@fields) = split( /\t/, $header );
    open( Fout, "> $outCtlFile" )
      || webDie("cannot write '$outCtlFile'\n");

    my $fileName = lastPathTok($inTabFile);
    my ( $fileRoot, @exts ) = split( /\./, $fileName );
    print Fout "load data\n";
    print Fout "infile '$inTabFile'\n";
    print Fout "append\n";
    print Fout "into table $fileRoot\n";
    print Fout "fields terminated by X'09'\n";

    #print Fout "fields terminated by \"\@\@\@\"\n";
    print Fout "trailing nullcols\n";
    my %types = getTypes( $dsn, $user, $pw, $fileRoot );
    my $fstr = "(\n";
    for my $f (@fields) {
        $f =~ tr/A-Z/a-z/;
        my $t = $types{$f};
        $fstr .= "  $f $t,\n";
    }
    chop $fstr;
    chop $fstr;
    $fstr .= "\n)";
    print Fout "$fstr\n";
    close Fout;

    my $pw2 = pwDecode($pw);

    my $sql = "alter table dt_taxon_node_lite  nologging";
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();

    my $cmd =
        "$sqlldr $user/_XXX_\@$service control=$outCtlFile "
      . "log=$cgi_tmp_dir/dt_taxon_node_lite.log "
      . "skip=1 direct=TRUE ";

    print "$cmd <br/>\n";
    $cmd =
        "$sqlldr $user/$pw2\@$service control=$outCtlFile "
      . "log=$cgi_tmp_dir/dt_taxon_node_lite.log "
      . "skip=1 direct=TRUE ";
    runCmd($cmd);

    my $sql = "alter table dt_taxon_node_lite logging";
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();

    print "<br/><br/><b>SQL Loader Log</b><br/>\n";
    my $res = newReadFileHandle("$cgi_tmp_dir/dt_taxon_node_lite.log");
    while ( my $line = $res->getline() ) {
        chomp $line;
        print "$line <br/>\n";

    }
    close $res;

}

#
# getTypes - Get datatypes for table.
#
sub getTypes {
    my ( $dsn, $user, $pw, $tableName ) = @_;

    my $maxClob = 50000;

    my $dbh = DBI->connect( $dsn, $user, pwDecode($pw) );
    if ( !defined($dbh) ) {
        webDie("getTypes: cannot login '$user' \@ '$dsn'\n");
    }
    $tableName =~ tr/a-z/A-Z/;
    my $sql = qq{
      select column_name, data_type, data_length
      from user_tab_columns
      where table_name = '$tableName'
   };
    my $cur = $dbh->prepare($sql)
      || webDie("getTypes: cannot preparse statement: $DBI::errstr\n");
    $cur->execute()
      || webDie("getTypes: cannot execute: $DBI::errstr\n");
    my %types;
    for ( ; ; ) {
        my ( $column_name, $data_type, $data_length ) = $cur->fetchrow();
        last if $column_name eq "";
        my $type = $data_type;
        $column_name =~ tr/A-Z/a-z/;
        $type        =~ tr/A-Z/a-z/;
        if ( $type =~ /char/ ) {
            $type = "char($data_length)";
        } elsif ( $type =~ /clob/ ) {
            $type = "char($maxClob)";
        } else {

            # sqlldr doesn't like this.
            $type = "";
        }
        $types{$column_name} = $type;
    }
    $cur->finish();

    #$dbh->disconnect();
    return %types;
}

sub printJavaScript {
    print <<EOF;
    
    <script language='JavaScript' type='text/javascript'>


/*
 * as the user types only allow [0-9] values use it on event onKeyPress="return
 * numbersonly(event)"
 */
function numbersonly(e) {
    var key;
    var keychar;

    if (window.event) {
        key = window.event.keyCode;
    } else if (e) {
        key = e.which;
    } else {
        return true;
    }
    keychar = String.fromCharCode(key);

    // control keys
    if ((key == null) || (key == 0) || (key == 8) || (key == 9) || (key == 13)
            || (key == 27)) {
        return true;
        // } else if ((("-.0123456789").indexOf(keychar) > -1)) {
    } else if ((("0123456789").indexOf(keychar) > -1)) {
        // numbers
        return true;
    } else {
        return false;
    }
}


function mySubmit(page) {
    document.mainForm.page.value = page;
    document.mainForm.submit();
}
    
    </script>
    
EOF

}

# get CV for phylum, ir_class, ir_order, family, genus, species
# return array list
sub getCVPhylum {
    my ( $dbh, $domain, $columnname ) = @_;

    my $clause = "where domain = ? ";
    if ( $domain eq "Plasmids" ) {
        $clause = "where domain like 'Pla%' ";
    } elsif ( $domain eq "GFragment" ) {
        $clause = "where domain like 'GFragment%' ";
    } elsif ( $domain eq "Viruses" ) {
        $clause = "where domain like 'Vir%' ";
    } elsif ( $domain eq "" ) {
        $clause = "where 1 = 1 ";
    }

    my $andClause;
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    $andClause .= "and domain not like 'Vir%'\n"
      if $hideViruses eq "Yes";
    $andClause .= "and domain not like 'Plasmid%'\n"
      if $hidePlasmids eq "Yes";
    $andClause .= "and domain not like 'GFragment%'\n"
      if $hideGFragment eq "Yes";

    my $sql = qq{
        select distinct $columnname
        from taxon
        $clause
        and $columnname is not null
        $andClause
        order by 1
    };

    my $cur;
    if ( $domain eq "Plasmids" || $domain eq "Viruses" || $domain eq "GFragment" ) {
        $cur = execSql( $dbh, $sql, $verbose );
    } elsif ( $domain eq "" ) {
        $cur = execSql( $dbh, $sql, $verbose );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $domain );
    }
    my @array;
    for ( ; ; ) {
        my ($name) = $cur->fetchrow();
        last if ( !$name );

        $name = escHtml($name);
        push( @array, $name );
    }
    $cur->finish();
    return \@array;
}

#
# get list of unique names
# null values are listed as $unclassified
#
sub getCVPhylum2 {
    my ( $dbh, $columnname, $domain_filter_aref ) = @_;

    # pref for vir pla and obsolete
    my $andClause;
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    $andClause .= "and domain not like 'Vir%'\n"       if $hideViruses   eq "Yes";
    $andClause .= "and domain not like 'Plasmid%'\n"   if $hidePlasmids  eq "Yes";
    $andClause .= "and domain not like 'GFragment%'\n" if $hideGFragment eq "Yes";
    my $hideObsoleteTaxon = getSessionParam("hideObsoleteTaxon");
    $hideObsoleteTaxon = "Yes" if $hideObsoleteTaxon eq "";
    $andClause .= "and obsolete_flag ='No'\n" if $hideObsoleteTaxon eq "Yes";

    # domain filter
    # list of domains to show
    my $domainClause;
    my $virExists       = 0;
    my $plasmidExists   = 0;
    my $GFragmentExists = 0;
    if ( $domain_filter_aref ne "" && $#$domain_filter_aref > -1 ) {
        my @a;
        foreach my $x (@$domain_filter_aref) {
            push( @a, '?' );
            $virExists       = 1 if ( $x eq "Vir" );
            $plasmidExists   = 1 if ( $x eq "Plasmid" );
            $GFragmentExists = 1 if ( $x eq "GFragment" );
        }
        my $str = join( ",", @a );
        if ( $virExists || $plasmidExists || $GFragmentExists ) {
            $domainClause = " and ( domain in ($str) ";
        } else {
            $domainClause = " and domain in ($str) ";
        }
    }

    if ($virExists) {
        $domainClause .= " or domain like 'Vir%' ";
    }

    if ($plasmidExists) {
        $domainClause .= " or domain like 'Plasmid%' ";
    }

    if ($GFragmentExists) {
        $domainClause .= " or domain like 'GFragment%' ";
    }

    if ( $virExists || $plasmidExists || $GFragmentExists ) {
        $domainClause .= " ) ";
    }

    my $sql = qq{
        select nvl($columnname, '$unclassified'), count(*)
        from taxon
        where 1 = 1
        $andClause
        $domainClause
        group by nvl($columnname, '$unclassified')
        order by 1
    };

    my $cur = execSql( $dbh, $sql, $verbose, @$domain_filter_aref );

    my @array;
    my @counts;
    for ( ; ; ) {
        my ( $name, $count ) = $cur->fetchrow();
        last if ( !$name );

        $name = escHtml($name);
        push( @array,  $name );
        push( @counts, $count );
    }
    $cur->finish();
    return ( \@array, \@counts );
}

# get distinct list of all domain names
sub getCVDomain {
    my ($dbh) = @_;
    my $sql = qq{
        select distinct domain
        from taxon
        order by 1
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @data;
    for ( ; ; ) {
        my ($name) = $cur->fetchrow();
        last if ( !$name );

        push( @data, $name );
    }
    $cur->finish();
    return \@data;
}

#
# ncbi compare
#
# allncbi.txt
# file format - tab delimited
# 1st line - header - taxon_oid taxon_display_name  ncbi_taxon_id   phylum  ir_class    ir_order    family  genus   domain
# 2nd line - img data - 637000001   Koribacter versatilis Ellin345  204669  Acidobacteria   Acidobacteriae  Acidobacteriales    Koribacteraceae Koribacter  Bacteria
# 3rd line - ncbi data - undef  Candidatus Koribacter versatilis Ellin345   204669  unclassified    unclassified    unclassified    unclassified    unclassified    Bacteria
# etc...
#
# perl object
#struct Phylum => {
#                   taxon_oid          => '$',
#                   taxon_display_name => '$',
#                   ncbi_taxon_id      => '$',
#                   phylum             => '$',
#                   ir_class           => '$',
#                   ir_order           => '$',
#                   family             => '$',
#                   genus              => '$',
#                   species            => '$',
#                   domain             => '$'
#};
sub ncbiCompare {
    my $query_domain = param("domain");

    print qq{
        <h1> IMG vs NCBI  - todo </h1>
    };
    WebUtil::printStatusLine_old( "Loading ...", 1 );

    my $rfh = newReadFileHandle( $allncbi_file, "ncbi" );

    my $count = 0;
    my @headers;
    my @img_data;
    my @ncbi_data;
    while ( my $line = $rfh->getline() ) {
        chomp $line;
        if ( $line =~ /^taxon_oid/ ) {

            # header
            @headers = split( /\t/, $line );
            next;
        }

        my ( $taxon_oid, $taxon_display_name, $ncbi_taxon_id, $phylum, $ir_class, $ir_order, $family, $genus, $domain ) =
          split( /\t/, $line );

        if ( $query_domain ne "" && lc($query_domain) ne lc($domain) ) {
            next;
        }

        $count++;

        my $object = Phylum->new();
        $object->taxon_oid($taxon_oid);
        $object->taxon_display_name($taxon_display_name);
        $object->ncbi_taxon_id($ncbi_taxon_id);
        $object->phylum($phylum);
        $object->ir_class($ir_class);
        $object->ir_order($ir_order);
        $object->family($family);
        $object->genus($genus);
        $object->domain($domain);

        if ( $taxon_oid eq "undef" ) {

            # ncbi data line
            push( @ncbi_data, $object );
        } else {

            # img data line
            push( @img_data, $object );
        }
    }

    close $rfh;

    printCompareTable( \@headers, \@img_data, \@ncbi_data );

    $count = $count / 2;
    WebUtil::printStatusLine_old( "$count Loaded", 2 );
}

sub printCompareTable {
    my ( $headers_aref, $img_data_aref, $ncbi_data_aref ) = @_;

    print "<table class='img'>";

    foreach my $h (@$headers_aref) {
        print "<th class='img'> $h </th>\n";
    }

    for ( my $i = 0 ; $i <= $#$img_data_aref ; $i++ ) {
        my $img_object  = $img_data_aref->[$i];
        my $ncbi_object = $ncbi_data_aref->[$i];

        # img row
        print "<tr class='img'>\n";
        my $url = "main-edit.cgi?section=TaxonEdit&page=taxonOneEdit&taxon_oid=";
        $url = alink( $url . $img_object->taxon_oid, $img_object->taxon_oid );
        print "<td class='img'> " . $url . " </td>\n";
        if ( $img_object->taxon_display_name ne $ncbi_object->taxon_display_name ) {
            print "<td class='img'> <font color='red'>" . $img_object->taxon_display_name . "</font> </td>\n";
        } else {
            print "<td class='img'> " . $img_object->taxon_display_name . " </td>\n";
        }

        if ( $img_object->ncbi_taxon_id ne $ncbi_object->ncbi_taxon_id ) {
            print "<td class='img'> <font color='red'>" . $img_object->ncbi_taxon_id . "</font> </td>\n";
        } else {
            print "<td class='img'> " . $img_object->ncbi_taxon_id . " </td>\n";
        }

        if (   $ncbi_object->phylum ne "unclassified"
            && $img_object->phylum ne $ncbi_object->phylum )
        {
            print "<td class='img'> <font color='red'>" . $img_object->phylum . "</font> </td>\n";
        } else {
            print "<td class='img'> " . $img_object->phylum . " </td>\n";
        }

        if (   $ncbi_object->ir_class ne "unclassified"
            && $img_object->ir_class ne $ncbi_object->ir_class )
        {
            print "<td class='img'> <font color='red'>" . $img_object->ir_class . "</font> </td>\n";
        } else {
            print "<td class='img'> " . $img_object->ir_class . " </td>\n";
        }

        if (   $ncbi_object->ir_order ne "unclassified"
            && $img_object->ir_order ne $ncbi_object->ir_order )
        {
            print "<td class='img'> <font color='red'>" . $img_object->ir_order . "</font> </td>\n";
        } else {
            print "<td class='img'> " . $img_object->ir_order . " </td>\n";
        }

        if (   $ncbi_object->family ne "unclassified"
            && $img_object->family ne $ncbi_object->family )
        {
            print "<td class='img'> <font color='red'>" . $img_object->family . "</font> </td>\n";
        } else {
            print "<td class='img'> " . $img_object->family . " </td>\n";
        }

        if (   $ncbi_object->genus ne "unclassified"
            && $img_object->genus ne $ncbi_object->genus )
        {
            print "<td class='img'> <font color='red'>" . $img_object->genus . "</font> </td>\n";
        } else {
            print "<td class='img'> " . $img_object->genus . " </td>\n";
        }

        print "<td class='img'> " . $img_object->domain . " </td>\n";
        print "</tr>\n";

        # ncbi row
        print "<tr class='img'>\n";
        print "<td class='img'> NCBI - " . $ncbi_object->taxon_oid . " </td>\n";
        print "<td class='img'> " . $ncbi_object->taxon_display_name . " </td>\n";
        print "<td class='img'> " . $ncbi_object->ncbi_taxon_id . " </td>\n";
        print "<td class='img'> " . $ncbi_object->phylum . " </td>\n";
        print "<td class='img'> " . $ncbi_object->ir_class . " </td>\n";
        print "<td class='img'> " . $ncbi_object->ir_order . " </td>\n";
        print "<td class='img'> " . $ncbi_object->family . " </td>\n";
        print "<td class='img'> " . $ncbi_object->genus . " </td>\n";
        print "<td class='img'> " . $ncbi_object->domain . " </td>\n";
        print "</tr>\n";

        # blank row
        print "<tr class='highlight'>\n";
        print "<td class='img' colspan=9 > &nbsp; </td>\n";
        print "</tr>\n";
    }

    print "</table>\n";
}

1;
