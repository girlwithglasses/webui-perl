############################################################################ 
# HashUtil.pm
# 
# $Id: HashUtil.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################ 
package HashUtil;
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
     hash_mod0
     hash_mod
     hash_substr
     get_hash_func
     get_hash_code
);


use strict; 
use POSIX; 
use FileHandle;

sub hash_mod0 {
    my ($id, $no_bin) = @_;

    my $id2 = $id;
    $id2 =~ s/\:/\_/g;
    $id2 =~ s/\//\_/g;
    my $len = length($id2);
    my $code = 0;
    for (my $j = 0; $j < $len; $j++) {
    	$code += (substr($id2, $j, 1) - '0');
    }

    return ($code % $no_bin) + 1;
}

sub hash_mod {
    my ($id, $no_bin) = @_;

    my $id2 = $id;
    $id2 =~ s/\:/\_/g;
    $id2 =~ s/\//\_/g;
    my $len = length($id2);
    my $code = 0;
    for (my $j = 0; $j < $len; $j++) {
    	$code = ($code * 3 + (ord(substr($id2, $j, 1)) - 32)) % $no_bin;
    }

    #print "HashUtil::hash_mod id: $id, max_cnt: $no_bin, code: $code<br/>\n";

    return ($code % $no_bin) + 1;
}


sub hash_substr {
    my ($id, $sep, $a_ref) = @_;

    my $code = "";

    my @ids = split($sep, $id);

    for my $j (@$a_ref) {
    	if ( $j < scalar(@ids) ) {
    	    my $k = $ids[$j];
    	    if ( $code ) {
        		$code .= '_' . $k;
    	    }
    	    else {
        		$code = $k;
    	    }
    	}
    }

    return $code;
}

sub get_hash_func {
    my ($hash_file, $tag) = @_;

    my @res = ();
    if ( $hash_file ) {
	if ( -e $hash_file ) { 
	    open(HFILE, $hash_file);
	    while (my $line1 = <HFILE>) {
    		chomp($line1);
    		my ($a0, $a1, $a2, @a3) = split(/\,/, $line1);
        		if ( $a0 eq $tag ) {
        		    if ( $a1 =~ /hash_mod/ ) {
            			@res = ( $a1, $a2 );
        		    } 
        		    elsif ( $a1 eq 'hash_substr' ) {
            			@res = ( $a1, $a2, @a3 );
        		    }
        		} 
    	    } 
    	    close HFILE;
    	}
    }

    return @res;
}

sub get_hash_code {
    my ($hash_file, $tag, $id) = @_;

    my $code = "";

    if ( $hash_file ) {
    	if ( -e $hash_file ) { 
    	    open(HFILE, $hash_file);
    	    while (my $line1 = <HFILE>) {
        		chomp($line1);
        		my ($a0, $a1, $a2, @a3) = split(/\,/, $line1);
        
        		if ( $a0 eq $tag ) {
        		    if ( $a1 eq 'hash_mod0' ) {
            			$code = hash_mod0($id, $a2);
        		    } 
        		    elsif ( $a1 eq 'hash_mod' ) {
            			$code = hash_mod($id, $a2);
                        #print "HashUtil::get_hash_code max_cnt: $a2, code: $code<br/>\n";
        		    } 
        		    elsif ( $a1 eq 'hash_substr' ) {
            			$code = hash_substr($id, $a2, \@a3);
        		    }
        		} 
    	    } 
    	    close HFILE;
    	}
    }

    return $code;
}



1;
