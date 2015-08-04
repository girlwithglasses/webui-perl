package OperonFunc;
#################################################
# package with functions used in Operons.pm
#
# $Id: OperonFunc.pm 29739 2014-01-07 19:11:08Z klchu $
#################################################


use strict;
use warnings;
use CGI::Carp 'fatalsToBrowser';
use CGI::Carp 'warningsToBrowser';

###################################################
# input is the method
# returns a string that describes the method
###################################################
sub clusterString{
	my ($cluster_method)=@_;
	my $strCluster="";
	$strCluster="COG" if $cluster_method eq 'cog';
	$strCluster="PFAM" if $cluster_method eq 'pfam';
	#$strCluster="BBH(MCL)" if $cluster_method eq 'bbh';
	$strCluster= "IMG Ortholog Cluster" if $cluster_method eq 'bbh';
	return $strCluster;
}


###############################################
# depending on the number of protein families
# return a string that describes the size
###############################################
sub expansionName{
	my ($expansion)=@_;
	if(!$expansion){return "Query";}
	if($expansion ==2) {return "Pairs";}
	if($expansion ==3) {return "Triplets";}
	if($expansion ==4) {return "Quadruplet";}
	if($expansion ==5) {return "Quintuplet";}
	if($expansion ==6) {return "Sextuplet";}
	if($expansion ==7) {return "Septuplet";}
	if($expansion ==8) {return "Octuplet";}
	if($expansion ==6) {return "Nonuplet";}
	if($expansion ==6) {return "Dectuplet";}
	
	$expansion="$expansion-let";
	
}

##################################################
# find the unique elements of an array
###################################################
sub unique
{
        my ($array,$size)=@_;
        my @a1=@$array;
        my $un_sep="UN~:~SEP";
        my %check=();
        my @uniq=();
                if ($size >1)
                {
                        for(my $i=0;$i<scalar(@a1);$i++)
                        {
                                my $string;
                                for(my $j=0;$j<$size;$j++) {$string.=$a1[$i][$j].$un_sep;}
                                unless($check{$string})
                                {
                                        my @temp_array=split($un_sep,$string);
                                        push @uniq,[@temp_array];
                                        $check{$string}=1;
                                }
                        }
                }
                elsif ($size==1)
                {
                        foreach my $e(@a1)
                        {
                                if (defined($e))
                                {
                                        unless(defined($check{$e}))
                                        {
                                                        push @uniq,$e;
                                                        $check{$e}=1;
                                        }
                                }
                        }
                }
        return @uniq;
}

######################################################
# check if an element is in an array
######################################################


sub in
{
        my ($v1,$element)=@_;
        my @array=@$v1;#my $element=$$v2;
        if (!defined($v1)){die "in: pointer to array not defined\n";}
        if (!defined($element)){die "in: element not defined\n";}
        my $return_value=-1;
        for (my $i=0;$i<scalar(@array);$i++)
        {
                if ($array[$i] eq $element)
                {
                        $return_value=$i;
                        last;
                }
        }
        return $return_value;
}

########################################################
# find the intersection between two arrays
########################################################

sub intersect
{
        my ($v1,$v2,$flag)=@_;
	
        my @a1=unique($v1,1);
        my @b1=unique($v2,1);
        my @union = my @isect = ();
        my %union = my %isect = ();
	
        foreach my $e (@a1)
        {
                $union{$e} = 1
        }

        foreach my $e (@b1)
        {
                if ( $union{$e} ) { $isect{$e} = 1 }
        }
        @isect = keys %isect;
        return @isect;
}



1;
