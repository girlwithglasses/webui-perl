############################################################################
# $Id: MetagJavaScript.pm 31256 2014-06-25 06:27:22Z jinghuahuang $
#
# this module replaces taxonDetails.js
#
package MetagJavaScript;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
	printMetagJS
);

use strict;
use WebUtil;
use WebConfig;


sub printMetagJS {
	print <<EOF;
	
<script language='JavaScript' type='text/javascript'>
	
function selectTaxon ( end, bname) {
   var f = document.mainForm;


   var idx1 = myFind(bname) + 2;
   var idx2 = end + idx1;
   for( var i = idx1;  i < idx2; i++ ) {
      var e = f.elements[ i ];
      e.checked = true;
   }
}

function unSelectTaxon ( end, bname) {
   var f = document.mainForm;

   var idx1 = myFind(bname) + 1;
   var idx2 = end + idx1;
   for( var i = idx1;  i < idx2; i++ ) {
      var e = f.elements[ i ];
      e.checked = false;
   }
}

function maxCheckboxSelected (max, object) {
   var f = document.mainForm;
   var count = 0;

   for( var i = 0;  i < f.length; i++ ) {
      var e = f.elements[i];
      if(e.type == "checkbox") {
         if(e.checked) {
            count++;
            if(count > 2) {
                alert("Please select only 2!");
                var y = myFind(object);
                f.elements[y].checked = false;
                return;
            }
         }
      }
   }
}

function myFind (bname) {
   var f = document.mainForm;

   for( var i = 0;  i < f.length; i++ ) {
      var e = f.elements[i];
      if(e.name == bname) {
         //alert(bname + " at : " + i);
        return i;
      }
   }
   
   alert("cannot find object name: " + bname);
   return -1;
}

function myView(main_cgi, view, file1, file2, file4, taxon_oid, percent_identity, domain, phylum) {
    var f = document.mainForm;
    var e = f.elements[6];
    
    if(e.checked == true) {
    window.open(main_cgi + "?section=MetagenomeHits&page=metagenomeHits&view=" + view +"&coghide=true&cf1=" + file1 + 
    "&cf2=" + file2 + "&cf4=" + file4 
    + "&taxon_oid=" + taxon_oid + "&percent_identity=" + percent_identity 
    + "&domain=" + domain +"&phylum=" + phylum, "_self");

    } else {

    window.open(main_cgi + "?section=MetagenomeHits&page=metagenomeHits&view=" + view + "&coghide=false&cf1=" + file1 + 
    "&cf2=" + file2 + "&cf4=" + file4 
    + "&taxon_oid=" + taxon_oid + "&percent_identity=" + percent_identity 
    + "&domain=" + domain +"&phylum=" + phylum, "_self");
    }
}

function myView2(main_cgi, view, file1, file2, file4, taxon_oid,  percent_identity, plus, domain, phylum, ir_class, ir_order, family, genus, species) {
    var f = document.mainForm;
    var e = f.elements[6];
    
    if(e.checked == true) {
    window.open(main_cgi + "?section=MetagenomeHits&page=taxonomyMetagHits&view=" + view +"&coghide=true&cf1=" + file1 + 
    "&cf2=" + file2 + "&cf4=" + file4 
    + "&taxon_oid=" + taxon_oid + "&percent_identity=" + percent_identity + "&plus=" + plus
    + "&domain=" + domain + "&phylum=" +phylum + "&ir_class=" + ir_class + "&ir_order=" + ir_order + "&family=" + family + "&genus=" + genus + "&species=" + species, "_self");

    } else {

    window.open(main_cgi + "?section=MetagenomeHits&page=taxonomyMetagHits&view=" + view + "&coghide=false&cf1=" + file1 + 
    "&cf2=" + file2 + "&cf4=" + file4 
    + "&taxon_oid=" + taxon_oid + "&percent_identity=" + percent_identity + "&plus=" + plus
    + "&domain=" + domain + "&phylum=" +phylum + "&ir_class=" + ir_class + "&ir_order=" + ir_order + "&family=" + family + "&genus=" + genus + "&species=" + species, "_self");
    }
}


function mySort(main_cgi, sort, file1, file2, file4, taxon_oid, percent_identity, domain, phylum, ir_class) {
    var f = document.mainForm;
    var e = f.elements[6];
    
    if(e.checked == true) {
    window.open(main_cgi + "?section=MetagenomeHits&page=metagenomeHits&sort=" + sort +"&coghide=true&cf1=" + file1 + 
    "&cf2=" + file2 + "&cf4=" + file4 
    + "&taxon_oid=" + taxon_oid + "&percent_identity=" +percent_identity 
    + "&domain=" + domain + "&phylum=" + phylum + "&ir_class=" + ir_class, "_self");

    } else {

    window.open(main_cgi + "?section=MetagenomeHits&page=metagenomeHits&sort=" + sort + "&coghide=false&cf1=" + file1 + 
    "&cf2=" + file2 + "&cf4=" + file4 
    + "&taxon_oid=" + taxon_oid + "&percent_identity=" +percent_identity 
    + "&domain=" + domain + "&phylum=" + phylum + "&ir_class=" + ir_class, "_self");
    }
}

function mySort2(main_cgi, sort, file1, file2, file4, taxon_oid, percent_identity, domain, phylum, ir_class, ir_order, family, genus, species) {
    var f = document.mainForm;
    var e = f.elements[6];
    
    if(e.checked == true) {
    window.open(main_cgi + "?section=MetagenomeHits&page=taxonomyMetagHits&sort=" + sort +"&coghide=true&cf1=" + file1 + 
    "&cf2=" + file2 + "&cf4=" + file4 
    + "&taxon_oid=" + taxon_oid + "&percent_identity=" +percent_identity 
    + "&domain=" + domain + "&phylum=" +phylum + "&ir_class=" + ir_class + "&ir_order=" + ir_order + "&family=" + family + "&genus=" + genus + "&species=" + species, "_self");

    } else {

    window.open(main_cgi + "?section=MetagenomeHits&page=taxonomyMetagHits&sort=" + sort + "&coghide=false&cf1=" + file1 + 
    "&cf2=" + file2 + "&cf4=" + file4 
    + "&taxon_oid=" + taxon_oid + "&percent_identity=" +percent_identity 
    + "&domain=" + domain + "&phylum=" +phylum + "&ir_class=" + ir_class + "&ir_order=" + ir_order + "&family=" + family + "&genus=" + genus + "&species=" + species, "_self");
    }
}


function selectAllCheckBoxes2( x, skip ) {
   var f = document.mainForm;
   var y = 0 + skip;
   
   for( var i = y; i < f.length; i++ ) {
        var e = f.elements[ i ];
    if( e.type == "checkbox" ) {
           e.checked = ( x == 0 ? false : true );
    }
   }
}

function myCompareCogFunc(main_cgi, taxon_oid) {
   var f = document.mainForm;
   var count = 0;
   var phylum1;
   var phylum2;
   
   var diff = 2;
   var perc = 30;
      
   for( var i = 0;  i < f.length; i++ ) {
      var e = f.elements[i];
      if(e.type == "checkbox") {
         if(e.checked) {
             count++;
             if(count == 1) {
                phylum1 = unescape(e.value);
                //alert(phylum1);
             } else if (count == 2) {
                phylum2 = unescape(e.value);
                //alert(phylum2);             
             } 
             
             if(count > 1) {
                break;
             }
         }
      }
   }
   
   if(count < 2) {
      alert("Please select 2 Phyla/Classes to compare!");
      return;
   }
   
   var domainArray1 = phylum1.split("\t");
   //alert("1 array size = " + domainArray1.length + ":" + domainArray1[2] +":");


   var domainArray2 = phylum2.split("\t");
   //alert("2 array size = " + domainArray2.length );
   
   if(domainArray1[2]  == "") {
    domainArray1[2] = "mynull";
   }

   if(domainArray2[2]  == "") {
    domainArray2[2] = "mynull";
   }

/*
   for( var i = 0;  i < f.length; i++ ) {
      var e = f.elements[i];
      if(e.name == "percentage") {
      	alert("percent is " + e.value);
      } else if(e.name == "difference") {
      	alert("diff is " + e.value);
      }
   }
   */
    window.open(main_cgi + "?section=MetagenomeHits&page=compareCogFunc&taxon_oid=" + taxon_oid
    + "&perc=" +    document.mainForm.percentage.value
    + "&difference=" + document.mainForm.difference.value
    + "&domain1=" +domainArray1[0]+ "&phylum1=" +domainArray1[1] + "&ir_class1=" + domainArray1[2]
    + "&domain2=" +domainArray2[0]+ "&phylum2=" +domainArray2[1] + "&ir_class2=" + domainArray2[2]
    , "_self");
   
   
}

function myCompareCogPath(main_cgi, taxon_oid) {
   var f = document.mainForm;
   var count = 0;
   var phylum1;
   var phylum2;
      
   for( var i = 0;  i < f.length; i++ ) {
      var e = f.elements[i];
      if(e.type == "checkbox") {
         if(e.checked) {
             count++;
             if(count == 1) {
                phylum1 = unescape(e.value);
                //alert(phylum1);
             } else if (count == 2) {
                phylum2 = unescape(e.value);
                //alert(phylum2);             
             } 
             
             if(count > 1) {
                break;
             }
         }
      }
   }
   
   if(count < 2) {
      alert("Please select at least 2 Plylums/Classes to compare!");
      return;
   }
   
   var domainArray1 = phylum1.split("\t");
   //alert("1 array size = " + domainArray1.length + ":" + domainArray1[2] +":");


   var domainArray2 = phylum2.split("\t");
   //alert("2 array size = " + domainArray2.length );
   
   if(domainArray1[2]  == "") {
    domainArray1[2] = "mynull";
   }

   if(domainArray2[2]  == "") {
    domainArray2[2] = "mynull";
   }
   
    window.open(main_cgi + "?section=MetagenomeHits&page=comparePathFunc&taxon_oid=" + taxon_oid
    + "&perc=" +    document.mainForm.percentage.value
    + "&difference=" + document.mainForm.difference.value
    + "&domain1=" +domainArray1[0]+ "&phylum1=" +domainArray1[1] + "&ir_class1=" + domainArray1[2]
    + "&domain2=" +domainArray2[0]+ "&phylum2=" +domainArray2[1] + "&ir_class2=" + domainArray2[2]
    , "_self");
   

}

</script>
	
EOF
		
}

#
# javascripts for the species form, where you select
# which ref gene's scaffold to plot against
#
sub printMetagSpeciesPlotJS {
	print <<EOF;
<script language='JavaScript' type='text/javascript'>

var maxScaffolds = 20;

/*
we must have at least one scaffold selected and less than eq 10 selected
*/
function checkSelect() {
    var f = document.mainForm;
    var count = 0;
    // max number of scaffolds a user can pick
    
    
    for( var i = 0;  i < f.length; i++ ) {
        var e = f.elements[i];
        if(e.type == "checkbox" && e.checked && e.name != 'hitgene') {
            count++;
        }
        
        if (count > maxScaffolds) {
            alert("Please select only " + maxScaffolds +" scaffolds");
            e.checked = false;
            return false;
        }
    } 

    if(count == 0 ) {
        alert("Please select a scaffold");
        return false;           
    }
    
    return true;
}


function plotRange(main_cgi, scaffold) {
    
    var f = document.mainForm;
    
    var taxon = f.elements['taxon_oid'].value;
    var family = f.elements['family'].value;
    var domain = f.elements['domain'].value;
    var phylum = f.elements['phylum'].value;
    var ir_class = f.elements['ir_class'].value;
    var genus = f.elements['genus'].value;
    var species = f.elements['species'].value;
    var hitgene = f.elements['hitgene'].checked;
    var min = 1;
    var max = 1;

    var select_name = 'range_select' + scaffold
    for( var i = 0; i < f.length; i++ ) {
        var e = f.elements[ i ];
        //alert(e.type + " " + e.name);
        
        if(  e.name == select_name) {
            var str = e.value;
            var array = str.split(",");
            
            min = array[0];
            
            if(min == '-') {
                return;
            }
            
            max = array[1];
            
            break;
        }
    }
    
    
    var url = main_cgi;
    url = url + "?section=MetagenomeGraph&page=fragRecView1";
    url = url + "&taxon_oid=" + taxon;
    
    url = url + "&min=" + min;
    url = url + "&max=" + max;
    
    url = url + "&family=" + family;
    url = url + "&domain=" + domain;
    url = url + "&phylum=" + phylum;
    url = url + "&genus=" + genus;
    url = url + "&hitgene=" + hitgene;
    
    if(species != '') {
        url = url + "&species=" + species;
    }

    if(ir_class != '') {
        url = url + "&ir_class=" + ir_class;
    }

    url = url + "&scaffolds=" + scaffold;
    
    var newWind = window.open(url, "_self");
    
}

function plotRange2(main_cgi, scaffold) {
    
    var f = document.mainForm;
    
    var min = 1;
    var max = 1;

    var select_name = 'range_select' + scaffold
    for( var i = 0; i < f.length; i++ ) {
        var e = f.elements[ i ];
        //alert(e.type + " " + e.name);
        
        if(  e.name == select_name) {
            var str = e.value;
            var array = str.split(",");
            
            min = array[0];
            
            if(min == '-') {
                return;
            }
            
            max = array[1];
            
            break;
        }
    }
    document.mainForm.min.value = min;
    document.mainForm.max.value = max; 
    document.mainForm.scaffolds.value = scaffold;    
    document.mainForm.submit();
}




function plotZoom(main_cgi) {
  
    var f = document.mainForm;
    var taxon = f.elements['taxon_oid'].value;
    var family = f.elements['family'].value;
    var domain = f.elements['domain'].value;
    var phylum = f.elements['phylum'].value;
    var ir_class = f.elements['ir_class'].value;
    var genus = f.elements['genus'].value;
    var species = f.elements['species'].value;

    var strand = f.elements['strand'].value;
    
    var range = f.elements['zoom_select'].value;
    var merfs = f.elements['merfs'].value;
    
    if(range == '-') {
        return;
    }
    
    var url = main_cgi;
    url = url + "?section=MetagenomeGraph&page=fragRecView3";
    url = url + "&taxon_oid=" + taxon;
    
    url = url + "&family=" + family;
    url = url + "&domain=" + domain;
    url = url + "&phylum=" + phylum;

    if(genus != '') {
        url = url + "&genus=" + genus;
    }
    
    if(species != '') {
        url = url + "&species=" + species;
    }

    if(ir_class != '') {
        url = url + "&ir_class=" + ir_class;
    }

    if(merfs != '') {
        url = url + "&merfs=" + merfs;
    }

    url = url + "&strand=" + strand;
    url = url + "&range=" + range;

    var newWind = window.open(url, "_self");
    
}

function plot(main_cgi) {
    if(!checkSelect()) {
        return;
    }
    
    var f = document.mainForm;
    
    //alert(f.elements['family'].value);
    
    
    var taxon = f.elements['taxon_oid'].value;
    var family = f.elements['family'].value;
    var domain = f.elements['domain'].value;
    var phylum = f.elements['phylum'].value;
    var ir_class = f.elements['ir_class'].value;
    var genus = f.elements['genus'].value;
    var species = f.elements['species'].value;
    //var ref_taxon_id = f.elements['ref_taxon_id'].value;
	var hitgene = f.elements['hitgene'].checked;
    var scaffolds = '';

    for( var i = 0; i < f.length; i++ ) {
        var e = f.elements[ i ];
        if( e.type == "checkbox" &&  e.checked && e.name != 'hitgene') {
            var scaffold = e.value;
            if(scaffolds == '') {
            	scaffolds = scaffold;
            } else {
            	scaffolds = scaffolds + '_' + scaffold;
            }
        }
    }
    
    //alert(scaffolds);
    
    var url = main_cgi;
    url = url + "?section=MetagenomeGraph&page=fragRecView1";
    url = url + "&taxon_oid=" + taxon;
    
    url = url + "&family=" + family;
    url = url + "&domain=" + domain;
    url = url + "&phylum=" + phylum;
    
    //url = url + "&ref_taxon_id=" + ref_taxon_id;
    url = url + "&genus=" + genus;

    if(species != '') {
        url = url + "&species=" + species;
    }

    if(ir_class != '') {
        url = url + "&ir_class=" + ir_class;
    }

	url = url + "&hitgene=" + hitgene;
	
    url = url + "&scaffolds=" + scaffolds;
    var newWind = window.open(url, "_self");
    //newWind.elements['domain'].value = domain;
    
}

function plotProtein(main_cgi) {
    if(!checkSelect()) {
        return;
    }
    
    var f = document.mainForm;
    
    //alert(f.elements['family'].value);
    
    
    var taxon = f.elements['taxon_oid'].value;
    var family = f.elements['family'].value;
    var domain = f.elements['domain'].value;
    var phylum = f.elements['phylum'].value;
    var ir_class = f.elements['ir_class'].value;
    var genus = f.elements['genus'].value;
    var species = f.elements['species'].value;
    //var ref_taxon_id = f.elements['ref_taxon_id'].value;
	var hitgene = 'false';
    var scaffolds = '';

    for( var i = 0; i < f.length; i++ ) {
        var e = f.elements[ i ];
        if( e.type == "checkbox" &&  e.checked && e.name != 'hitgene') {
            var scaffold = e.value;
            if(scaffolds == '') {
            	scaffolds = scaffold;
            } else {
            	scaffolds = scaffolds + '_' + scaffold;
            }
        }
    }
    
    //alert(scaffolds);
    
    var url = main_cgi;
    url = url + "?section=MetagenomeGraph&page=fragRecView2";
    url = url + "&taxon_oid=" + taxon;
    
    url = url + "&family=" + family;
    url = url + "&domain=" + domain;
    url = url + "&phylum=" + phylum;
    
    //url = url + "&ref_taxon_id=" + ref_taxon_id;
    url = url + "&genus=" + genus;

    if(species != '') {
        url = url + "&species=" + species;
    }

    if(ir_class != '') {
        url = url + "&ir_class=" + ir_class;
    }

	url = url + "&hitgene=" + hitgene;
	
    url = url + "&scaffolds=" + scaffolds;
    window.open(url, "_self");
}



function plotBin(main_cgi) {
    if(!checkSelect()) {
        return;
    }
    
    var f = document.mainForm;
    
    //alert(f.elements['family'].value);
    
    
    var taxon = f.elements['taxon_oid'].value;
    var family = f.elements['family'].value;
    var method_oid = f.elements['method_oid'].value;
    var bin_oid = f.elements['bin_oid'].value;
    var genus = f.elements['genus'].value;
    var species = f.elements['species'].value;
    //var ref_taxon_id = f.elements['ref_taxon_id'].value;
    var scaffolds = '';

    for( var i = 0; i < f.length; i++ ) {
        var e = f.elements[ i ];
        if( e.type == "checkbox" &&  e.checked) {
            var scaffold = e.value;
            if(scaffolds == '') {
            	scaffolds = scaffold;
            } else {
            	scaffolds = scaffolds + '_' + scaffold;
            }
        }
    }
    
    //alert(scaffolds);
    
    var url = main_cgi;
    url = url + "?section=MetagenomeGraph&page=binfragRecView1";
    url = url + "&taxon_oid=" + taxon;
    
    url = url + "&family=" + family;
    url = url + "&method_oid=" + method_oid;
    url = url + "&bin_oid=" + bin_oid;
    
    //url = url + "&ref_taxon_id=" + ref_taxon_id;
    url = url + "&genus=" + genus;

    if(species != '') {
        url = url + "&species=" + species;
    }
	
    url = url + "&scaffolds=" + scaffolds;
    window.open(url, "_self");
}

function plotBinProtein(main_cgi) {
    if(!checkSelect()) {
        return;
    }
    
    var f = document.mainForm;
    
    //alert(f.elements['family'].value);
    
    
    var taxon = f.elements['taxon_oid'].value;
    var family = f.elements['family'].value;
    var method_oid = f.elements['method_oid'].value;
    var bin_oid = f.elements['bin_oid'].value;
    var genus = f.elements['genus'].value;
    var species = f.elements['species'].value;
    //var ref_taxon_id = f.elements['ref_taxon_id'].value;

    var scaffolds = '';

    for( var i = 0; i < f.length; i++ ) {
        var e = f.elements[ i ];
        if( e.type == "checkbox" &&  e.checked && e.name != 'hitgene') {
            var scaffold = e.value;
            if(scaffolds == '') {
            	scaffolds = scaffold;
            } else {
            	scaffolds = scaffolds + '_' + scaffold;
            }
        }
    }
    
    //alert(scaffolds);
    
    var url = main_cgi;
    url = url + "?section=MetagenomeGraph&page=binfragRecView2";
    url = url + "&taxon_oid=" + taxon;
    
    url = url + "&family=" + family;
    url = url + "&method_oid=" + method_oid;
    url = url + "&bin_oid=" + bin_oid;
    
    //url = url + "&ref_taxon_id=" + ref_taxon_id;
    url = url + "&genus=" + genus;

    if(species != '') {
        url = url + "&species=" + species;
    }

	
    url = url + "&scaffolds=" + scaffolds;
    window.open(url, "_self");
}



/*
  runtime verison as user clicks a box
*/
function checkSelect2(elementId) {
    var f = document.mainForm;
    var count = 0;
      
    for( var i = 0;  i < f.length; i++ ) {
        var e = f.elements[i];
        if(e.type == "checkbox" && e.checked && e.name != 'hitgene') {
            count++;
        }
        
        if (count > maxScaffolds) {
            alert("Please select only " + maxScaffolds + " scaffolds");
            var lastelement = f.elements[elementId];
            lastelement.checked = false;
            return;
        }
    } 
}

function enableHits(type) {
    var chkBoxSpan = document.getElementById('hitChk');
    if (type == 'cum')
	chkBoxSpan.disabled = true;
    else
	chkBoxSpan.disabled = false;
}      
	
</script>
EOF
}

sub printFormJS {
    print <<EOF;
<script language='JavaScript' type='text/javascript'>

function enableHits(type) {
    var chkBox = document.mainForm.show_hits;
    if (type == 'cum')
	chkBox.disabled = false;
    else
	chkBox.disabled = true;
}      

</script>
EOF
}

1;

