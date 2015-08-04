########################################################################
# Save selection until save button is selected
#
# Issue what if the user goes away from the page
#
# Added export routine +BSJ 02/22/10
#
# $Id: Selection.pm 31462 2014-07-23 08:03:32Z jinghuahuang $
########################################################################

package Selection;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw();
#@EXPORT = qw(array_multisort array_filter);
use strict;
use CGI qw( :standard unescape );
use CGI::Cookie;
use JSON;
use Fcntl qw( :flock );

use WebUtil;
use WebConfig;
use Data::Dumper;

my $env                 = getEnv();
my $main_cgi            = $env->{main_cgi};
my $base_url            = $env->{base_url};
my $base_dir            = $env->{base_dir};
my $tmp_dir             = $env->{tmp_dir};
my $tmp_url             = $env->{tmp_url};
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};

my $dir2 = WebUtil::getSessionDir();
$dir2 .= "/yui";
if ( !(-e "$dir2") ) { 
    mkdir "$dir2" or webError("Can not make $dir2!"); 
}
$cgi_tmp_dir = $dir2;

$| = 1;

#######################################################################
# dispatch - Dispatch loop.
#######################################################################
sub dispatch {
    my $page = param("page");
    if ($page eq "getCheckboxes") {
    	print header( -type => "application/json" );
    	# print header( -type => "text/plain" );    # uncomment for debugging
        getCheckboxes();
    } elsif($page eq "toggleCheckboxes") {
    	print header( -type => "application/json" );
    	# print header( -type => "text/plain" );    # uncomment for debugging
        toggleCheckboxes();
    } elsif($page eq "export") {
    	printExcelHeader(param('table') . "$$" . "_" . lc(getSysDate())  . ".xls");
    	# print header( -type => "text/plain" );    # uncomment for debugging
        export();
    }
}

########################################################################
# getCheckboxes - Read checkbox elements from previously created tmpfile
########################################################################
sub getCheckboxes {
    my $tmpfile = param("tmpfile");
    my $chkState = param("chk"); # 1=checked; 0=unchecked
    my $init = param("init");    # 1=called by oIMGTable instantiation
    my $chkList = param("cl");   # list of dirty checkboxes
    my $filter = unescape(param('f')); # get URL unescaped param
    my $column = param('c');
    my $type = param('t');       # search type: "text|regex"
    my $arrayStr = file2Str("$cgi_tmp_dir/$tmpfile");
    my $highLight = 0;

    # Prevent file from being purged by cgi purge timeout +BSJ 01/25/12
    WebUtil::fileTouch ("$cgi_tmp_dir/$tmpfile"); 

    $arrayStr = each %{{$arrayStr,0}};   # untaint the string
    my @fullArray = eval($arrayStr);
    my @checkBoxArray = @fullArray;
    @checkBoxArray = array_filter($column, $filter, $type, $highLight, @fullArray) if $filter;

    ########## return if filter text error (most likely regex error)
    if ($checkBoxArray[0] =~ /^###/) {
    	print @checkBoxArray;
    	return;
    }

    my @arSelect = ( );

    if ($chkList) {
    	my $json = new JSON;
    	my $dirtyChks = $json->decode($chkList);
    	return if (!$dirtyChks);
    	my $col;
    
    	for my $c ( keys %{$checkBoxArray[0]} ) {
    	    $col = $c;
    	    last if ($c =~ /(^Select$|^Selection$)/i);
    	}
    
    	for my $rowIndex ( keys %$dirtyChks ) {
    	    my $isChecked = $dirtyChks->{$rowIndex};
    	    my $chk = $checkBoxArray[$rowIndex - 1]->{$col};
    	    updateCheckBox ($isChecked, $chk); # $chk gets updated
    	    $checkBoxArray[$rowIndex - 1]->{$col} = $chk;
    	    $fullArray[$rowIndex - 1]->{$col} = $chk;
    	    # print $chk . "\n"; # for debugging
    	}
    } else {
    	# Read all hashes from the array in the tmpfile
    	my $i = 1; # starting index 1 to coincide with _img_yuirow_id indexes
    	for my $prt_array (@checkBoxArray) {
    	    for my $col ( keys %$prt_array ) {
        		if ($col =~ /(^Select$|^Selection$)/i) {
        		    my $chk = $prt_array->{$col};
        
        		    # do not update checkboxes when called by initial load
        		    updateCheckBox ($chkState, $chk) if !$init;
        		    if ($filter) {
            			$arSelect[$i] = $chk;        
        		    } else {
            			$arSelect[$prt_array->{'_img_yuirow_id'}] = $chk;
        		    }
        		    $fullArray[$prt_array->{'_img_yuirow_id'} - 1]->{$col} = $chk;
        		    $i++;
        		}
    	    }
    	}
    	
        #my $json0 = new JSON;
        #$json0->pretty;
        #my $json0_text = $json0->encode(\@arSelect);
        #webLog("Selection::getCheckboxes() arSelect=\n@arSelect\n");
        #webLog("Selection::getCheckboxes() arSelect size=$i\n");

    	# Send a JSON array back to the browser
    	my $json = new JSON;
    	#$json->pretty;            # display JSON array aesthetically - uncomment for debugging JSON
    	print ($json->encode(\@arSelect));
    }

    if (!$init) {  # don't update temp file if called by IMGTable (in selection.js) instantiation
    	$Data::Dumper::Terse  = 1;         # don't output variable names where feasible
    	$Data::Dumper::Indent = 1;         # indent minimal
    	my $sOutStr = Dumper( \@fullArray );
    	$sOutStr =~ s/\[\n|\]\n//g;        # remove the lines with [ and ] to mimic original file
    	str2File ($sOutStr, "$cgi_tmp_dir/$tmpfile"); # Overwrite the same tempfile with new checkbox values
    }
}

sub extractCheckBoxes {
    my ($filter, @allRecords) = @_;

    my @arSelect = ( );

    # Read all hashes from the array in the tmpfile
    my $i = 1; # starting index 1 to coincide with _img_yuirow_id indexes
    for my $prt_array (@allRecords) {
        for my $col ( keys %$prt_array ) {
            if ($col =~ /(^Select$|^Selection$)/i) {
                my $chk = $prt_array->{$col};
                if ($filter) {
                    $arSelect[$i] = $chk;        
                } else {
                    $arSelect[$prt_array->{'_img_yuirow_id'}] = $chk;
                }
                $i++;
            }
        }
    }

    #webLog("Selection::extractCheckboxes() arSelect=\n@arSelect\n");
    #webLog("Selection::extractCheckboxes() arSelect size=$i\n");

    return @arSelect;
}

################################################################
# updateCheckBox - Update markup for a checkbox 
#                  based on whether it is checked or not
################################################################
sub updateCheckBox {
    my ($chkState, $chk) = @_;

    # Insert the 'checked' attribute to the INPUT tag if called by Select All
    if ($chkState) {
    	$chk =~ (s/input/input checked=\'checked\'/i) if $chk !~ /checked/;
    } else { # remove the phrase checked='checked' and variations
    	$chk =~ s/\s*checked\s*=\s*'\s*checked\s*'//g;
    	$chk =~ s/\s*checked//g; # just in case no match was found above
    }
    $_[1] = $chk;
}

################################################################
# export - Export current table to a tab delimited file,
# and print a URL of this file to the browser
# 
# If exported from a taxonlist, includes taxon_oid column
# +BSJ 01/04/11
# 
# Added kludge to remove "zzz"
# +BSJ 11/14/11
################################################################
sub export {
    require HtmlUtil;
    
    my $tmpfile = param("tmpfile");
    my $chkRows = param('rows');
    my $colHeads = param('columns');
    my ($sortCol, $sortDir) = split(/\|/, param('sort'));
    my $filter = unescape(param('f')); # get URL unescaped param
    my $column = param('c');
    my $type = param('t');
    my $section = param('table');    # to check whether this is a taxonlist
    my $isTaxonList = ($section =~ /(taxontable|genomecart)/i) ? 1 : 0;
    my $arrayStr = file2Str("$cgi_tmp_dir/$tmpfile");  # read in the file
    my $highLight = 0;

    # Prevent file from being purged by cgi purge timeout +BSJ 01/25/12
    WebUtil::fileTouch ("$cgi_tmp_dir/$tmpfile"); 

    $arrayStr = each %{{$arrayStr,0}};  # untaint the string
    my @checkBoxArray = eval($arrayStr);
    # filter array if necessary with current filter terms
    @checkBoxArray = array_filter($column, $filter, $type, $highLight, @checkBoxArray) if $filter;

    my $json = new JSON;
    my @arColHeads = @{$json->decode($colHeads)};
    my @tabRecs;

    my $tabStr = "";

    # Add column headers into output array
    for my $sColTitle (@arColHeads) {
    	my $curCol = $sColTitle->{'label'};
    	if ($curCol !~ /(^Select$|^Selection$)/i) {
    	    $curCol =~ s/(<br>|<br\/>)/ /ig;;
    	    $curCol =~ s/<[^>]*>//gs;
    	    # prevent Excel from complaining about SYLK file format
    	    # See http://support.microsoft.com/kb/323626
    	    $curCol = "Id" if ($curCol eq "ID");
    	    $tabStr .= $curCol . "\t";
    	} elsif ($isTaxonList) {
    	    $tabStr .= "taxon_oid\t";
    	}
    }
    push(@tabRecs, $tabStr) ;

    # Special condition to print all records from tmpfile
    if ($chkRows eq "all") {
    	# Sort rows according to current sort field and direction
    	@checkBoxArray = array_multisort($sortCol, $sortDir, @checkBoxArray);
    
    	for (my $i=0; $i < @checkBoxArray; $i++) {
    	    $tabStr = "";
    	    for my $sColTitle (@arColHeads) {
        		my $cellValue = $checkBoxArray[$i]->{$sColTitle->{'key'}};
        		if ($sColTitle->{'label'} !~ /(^Select$|^Selection$)/i) {
        		    $cellValue = (strTrim($cellValue) eq "&nbsp;") ? "" : $cellValue;
        		    $cellValue =~ s/^zzz//ig; # kludge to replace values that begin with 'zzz'
        		    $tabStr .= $cellValue . "\t";
        		} elsif ($isTaxonList) {
        		    $tabStr .= HtmlUtil::getHTMLAttrValue ("value", $cellValue) . "\t";
        		}
    	    }
    	    push(@tabRecs, $tabStr);
    	}
    } 
    else {  # otherwise get the rows specified by the rows parameter

        my @arChkRows = @{$json->decode($chkRows)};
        #webLog("Selection::export() arChkRowsSize=" . scalar(@arChkRows) . "\n");

        # Populate an array of hashes with the selected rows
        my @selArray;
        #for (my $i=0, my $j=0; $i < @arChkRows; $i++) {
        #    webLog("Selection::export() arChkRows[$i]=$arChkRows[$i]\n");               
        #    if ( defined ($arChkRows[$i]) && ($arChkRows[$i] =~ /checked/) ) {
        #        webLog("Selection::export() checked arChkRows[$i]=$arChkRows[$i]\n");
        #        my $checkBoxArrayItemStr = Dumper($checkBoxArray[($i-1)]);
        #        webLog("Selection::export() checkBoxArray[($i-1)]=$checkBoxArrayItemStr\n");
        #        for my $sColTitle (@arColHeads) {
        #            my $cellValue = $checkBoxArray[($i-1)]->{$sColTitle->{'key'}};
        #            $cellValue =~ s/^zzz//ig; # kludge to replace values that begins with 'zzz'
        #            webLog("Selection::export() i=$i sColTitle=" . $sColTitle->{'key'} . " cellValue=$cellValue\n");
        #            if (($sColTitle->{'label'} !~ /(^Select$|^Selection$)/i) 
        #                || ($isTaxonList)) {
        #                $selArray[$j]{$sColTitle->{'key'}} = $cellValue;
        #                webLog("Selection::export() added i=$i sColTitle=" . $sColTitle->{'key'} . " cellValue=$cellValue\n");
        #            }
        #        }
        #        $j++;
        #    }
        #}

        my %chkRows_h;
        for (my $i=0; $i < @arChkRows; $i++) {
            #webLog("Selection::export() arChkRows[$i]=$arChkRows[$i]\n");
            if ( defined ($arChkRows[$i]) && ($arChkRows[$i] =~ /checked/) ) {
                my $valStr .= HtmlUtil::getHTMLAttrValue("value", $arChkRows[$i]);
                if ( $valStr ) {
                    $chkRows_h{$valStr} = 1;                   
                    #webLog("Selection::export() valStr=$valStr\n");
                }
            }
        }

        my $chkRowValidSize = scalar( keys %chkRows_h );
        #webLog("Selection::export() chkRowValidSize=$chkRowValidSize\n");
        if ( $chkRowValidSize > 0 ) {
            #webLog("Selection::export() checkBoxArraySize=" . scalar(@checkBoxArray) . "\n");
            for (my $i=0, my $j=0; $i < @checkBoxArray; $i++) {               
                #my $checkBoxArrayItemStr = Dumper($checkBoxArray[$i]);
                #webLog("Selection::export() checkBoxArray[$i]=$checkBoxArrayItemStr\n");

                my $included = 0;
                for my $sColTitle (@arColHeads) {
                    my $cellValue = $checkBoxArray[$i]->{$sColTitle->{'key'}};
                    #webLog("Selection::export() i=$i sColTitle=" . $sColTitle->{'key'} . " cellValue=$cellValue\n");
                    if ( $sColTitle->{'label'} =~ /(^Select$|^Selection$)/i ) {
                        my $valStr .= HtmlUtil::getHTMLAttrValue("value", $cellValue);
                        #webLog("Selection::export() checkBoxArray[$i] valStr=$valStr\n");
                        if ( $chkRows_h{$valStr} ) {
                            $included = 1;
                        }
                        else {
                            last;
                        }
                    }
                    if ( $included ) {
                        if ( ($sColTitle->{'label'} !~ /(^Select$|^Selection$)/i) || ($isTaxonList) ) {
                            $cellValue = (strTrim($cellValue) eq "&nbsp;") ? "" : $cellValue;
                            $cellValue =~ s/^zzz//ig; # kludge to replace values that begin with 'zzz'
                            $selArray[$j]{$sColTitle->{'key'}} = $cellValue;
                            #webLog("Selection::export() added i=$i sColTitle=" . $sColTitle->{'key'} . " cellValue=$cellValue\n");
                        }                         
                    }
                }
                if ( $included ) {
                    $j++;
                    if ( $j >= $chkRowValidSize ) {
                        last;                        
                    }
                }
            }
        }
        
    	# Sort rows according to current sort field and direction
    	@selArray = array_multisort($sortCol, $sortDir, @selArray);
    
    	# Append rows to array for printing
    	for my $sCols (@selArray) {
    	    $tabStr = "";
    	    for my $sColTitle (@arColHeads) {
        		my $cellValue = $sCols->{$sColTitle->{'key'}};
        		$cellValue = (strTrim($cellValue) eq "&nbsp;") ? "" : $cellValue;
        		if ($sColTitle->{'label'} !~ /(^Select$|^Selection$)/i) {
        		    $tabStr .= $cellValue . "\t";
        		} elsif ($isTaxonList) {
        		    $tabStr .= HtmlUtil::getHTMLAttrValue ("value", $cellValue) . "\t";
        		}
    	    }
    	    push(@tabRecs, $tabStr);
        }
     }

     # Print each line from array back to browser
     foreach my $line (@tabRecs) {
        print $line . "\n";
    }
}

###############################################################
# array_multisort
# Return array after sorting; automatically distinguishes
# numbers and strings in incoming data and sorts accordingly
#
# **** Also used by json_proxy.pl *****
#
# -BSJ 11/13/09
###############################################################

sub array_multisort ($$@)
{
  my ($sortByCol, $sort_dir, @array) = @_;
  my @sorted = ( );
  my $numericCol = 1;    # assume column is numeric unless proven otherwise

  for (@array) {
      if (!isNumber($_->{$sortByCol})) {
	  if (strTrim($_->{$sortByCol}) eq "&nbsp;" ||
	     (strTrim($_->{$sortByCol}) eq "" )) {
	      $_->{$sortByCol} = 0; # set blanks to be zero
	      next;
	  }
	  $numericCol = 0;      # no longer a numeric column
	  last;
      }
  }

  # if there is even one non-numeric value in this column, do a case-insensitive text sort
  if ($sort_dir eq "desc") {
     @sorted = $numericCol ? sort {    $$b{$sortByCol }  <=>    $$a{$sortByCol}  } @array :
	                     sort { "\L$$b{$sortByCol }" cmp "\L$$a{$sortByCol}" } @array ;
  } else {
     @sorted = $numericCol ? sort {    $$a{$sortByCol }  <=>    $$b{$sortByCol}  } @array :
	                     sort { "\L$$a{$sortByCol }" cmp "\L$$b{$sortByCol}" } @array ;
  }
  return @sorted;
}

###############################################################
# array_filter
# Return array after filtering; filterByCol is the current sort
# column
# Highlight the matched text in bold green
#
# **** Also used by json_proxy.pl *****
#
# -BSJ 06/11/10
###############################################################
sub array_filter {
    my ($filterByCol, $filterTerm, $filterType, $highLight, @array) = @_;
    my @filtered;
    my @colNames;

    # Decode URL text and trim filter
    $filterTerm = unescape($filterTerm);
    $filterTerm = strTrim($filterTerm);

    if ($filterByCol eq 'all') {
	    @colNames = keys %{$array[0]};
    } else {
    	# If search column not found, return entire array
    	if (!(grep { $_ eq $filterByCol } keys %{$array[0]})) {
    	    return @array;
    	}
    	push @colNames, $filterByCol;
    }

    for (@array) {
    	my $rowFiltered = 0;
    	for my $col (@colNames) {
    	    # Do not process column; next line of code checks for display header
    	    next if ($col =~ /Disp/);
    	    # Check whether the filter column has a display value
    	    my $filteredDisp = ($array[0]->{$col . "Disp"}) ? $col . "Disp" : $col;
    	    next if ($filteredDisp eq "_img_yuirow_id"); # do not process column
    	    next if ($filteredDisp =~ /(^Select$|^Selection$)/i); # do not process column
    
    	    my $nonHTMLStr = $_->{$filteredDisp};
    	    # Remove HTML, extract text, and trim
    	    $nonHTMLStr =~ s/(<[^>]*>)//gi;
    	    $nonHTMLStr = strTrim($nonHTMLStr);
    
    	    my @matches;
    	    # Check for comparison or range operators for numeric data
    	    if (($filterTerm =~ /(^<=|^>=|^<|^>|\d+\s*\.\.\s*\d+)/) &&
    		(isNumber($nonHTMLStr))) {
        		my $op = $1;
        		my $actualTerm = $filterTerm;
        		my $condition;
        		$actualTerm =~ s/\s*//g; # remove spaces
        		$nonHTMLStr = $nonHTMLStr + 0;
        		# If filterTerm is a range, eg. 1..100
        		if ($actualTerm =~ /\.\./) {
        		    my @range = split(/\.\./, $actualTerm);
        		    $condition = ($range[0] <= $nonHTMLStr && $range[1] >= $nonHTMLStr) ? 1:0;
        		} else { # filterTerm has a comparison operator
        		    $actualTerm =~ s/$op//g;
        		    $condition = eval('($nonHTMLStr ' . $op . ' $actualTerm) ? 1:0');
        		    $condition = 0 if (!$actualTerm);
        		}
        		push (@matches, $nonHTMLStr) if ($condition);
    	    } else {
        		if ($filterType eq "regex") {
        		    eval '($nonHTMLStr =~ /$filterTerm/)'; 
        		    if ($@) {
            			push @filtered, "###" . $@;
            			######### returning on regex error: non-JSON structure
            			return @filtered;
        		    } else {
            			$filterTerm =~ s/(^\/|\/$)//gi; # remove regex delimiters if any
            			@matches = $nonHTMLStr =~ /$filterTerm/gi;
        		    }
        		} else {
        		    @matches = $nonHTMLStr =~ /(\Q$filterTerm\E)/gi;
        		}
    	    }
    	    if (@matches > 0) {
        		if ($highLight) {
        		    for my $match (@matches) {
            			# search and replace only text not within HTML tags
            			$_->{$filteredDisp} =~
            			    s/(\Q$match\E(?![^<>]*>))/<span style='color:green;font-weight:bold'>$match<\/span>/g;
        		    }
        		}
        		$rowFiltered = 1;
    	    }
    	}
    	push @filtered, $_ if $rowFiltered;
    }
    return @filtered;
}

################################################################
# toggleCheckboxes - Toggle the selection of checkboxes
#                    Used in analysis carts
################################################################
sub toggleCheckboxes {
    my $tmpfile = param("tmpfile");
    my $arrayStr = file2Str("$cgi_tmp_dir/$tmpfile");
    my $chkState;

    $arrayStr = each %{{$arrayStr,0}};   # untaint the string
    my @fullArray = eval($arrayStr);

    my @arSelect = ( );

	# Read all hashes from the array in the tmpfile
	my $i = 1; # starting index 1 to coincide with _img_yuirow_id indexes
	for my $prt_array (@fullArray) {
	    for my $col ( keys %$prt_array ) {
		if ($col =~ /(^Select$|^Selection$)/i) {
		    my $chk = $prt_array->{$col};
		    # if ($chk =~ /(\s*checked\s*=\s*'\s*checked\s*')|(\s*checked)/i) {
		    if ($chk =~ /\s+checked/gi) {
			$chkState = 0;
		    } else {
			$chkState = 1;
		    }
		    # do not update checkboxes when called by initial load
		    updateCheckBox ($chkState, $chk);
		    $arSelect[$prt_array->{'_img_yuirow_id'}] = $chk;
		    $fullArray[$prt_array->{'_img_yuirow_id'} - 1]->{$col} =
			$chk;
		    $i++;
		}
	    }
	}
	# Send a JSON array back to the browser
	my $json = new JSON;
	# $json->pretty;            # display JSON array aesthetically - uncomment for debugging JSON
	print ($json->encode(\@arSelect));

	$Data::Dumper::Terse  = 1;         # don't output variable names where feasible
	$Data::Dumper::Indent = 1;         # indent minimal
	my $sOutStr = Dumper( \@fullArray );
	$sOutStr =~ s/\[\n|\]\n//g;        # remove the lines with [ and ] to mimic original file
	str2File ($sOutStr, "$cgi_tmp_dir/$tmpfile"); # Overwrite the same tempfile with new checkbox values
}

1;
