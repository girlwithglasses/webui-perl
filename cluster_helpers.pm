#!/usr/bin/perl -w

use strict;

#===============================================
#    cluster_helpers.pm
#
#    Peter L. Williams
#      March 2009
#
#===============================================

sub openf {
    my ($fn) = @_;
    local *FH;
    print "opening $fn\n";
    open FH, "$fn" or die "Unable to open $fn\n";
    return *FH;
}
sub openfw {
    my ($fn) = @_;
    open my $fho, ">$fn" or die "Unable to open $fn\n";
    return *$fho;
}

sub bin_search1 {
  my ($query, $table_ref) = @_;
  my $max = @$table_ref - 1;
  my $min = 0;
  my $mid;
  while ($min <= $max) {
     $mid = int (($max + $min) / 2); # rounds down
     if ($query lt ${$table_ref}[$mid]) {
       $max = $mid - 1; 
     } elsif ($query gt ${$table_ref}[$mid]) { 
       $min = $mid + 1; 
     } else {
       return $mid;
     }
  }
  return -1;         # not found
}
sub bin_search {
  my ($query, $table_ref, $col) = @_;
  my $max = @$table_ref - 1;
  my $min = 0;
  my $mid;
  while ($min <= $max) {
     $mid = int (($max + $min) / 2); # rounds down
     if ($query lt ${@{$table_ref}[$mid]}[$col]) {
       $max = $mid - 1; 
     } elsif ($query gt ${@{$table_ref}[$mid]}[$col]) { 
       $min = $mid + 1; 
     } else {
       return $mid;
     }
  }
  return -1;         # not found
}

sub lookup {
  my ($pid, $table_ref) = @_;
  my $idx = &bin_search ($pid, $table_ref, 0);
  if ($idx < 0) { return [-1,-1]; }
#die "Unable to find $pid in lookup(): $!"; }
  else { return @$table_ref[$idx]; }
}

my $end = -1;


# NB: add_pid_to_cluster in cluster_helpers.pm may be broken:
#   end = -1 and cluster_num = -1

sub add_pid_to_cluster {
  my ($pid, $clusters, $cluster_num) = @_;
  if ($cluster_num == -1) {
    if ($end == -1) { $end = @{$clusters}; }
      push @{${$clusters}[$end]}, $pid;     
      $end++;
      return $end - 1;
  } else {
    push @{${$clusters}[$cluster_num]}, $pid;
    return $cluster_num;
  }
}

sub add_entry_to_table {
  my ($pid, $cluster_num, $table_ref) = @_;
  push @{${$table_ref}[$cluster_num]}, $pid;
}

my @start_time;

sub start_timing {
  my ($N) = @_;
  if (not defined $N) { $N = 0; }
  $start_time[$N] = time;
#  print_date();
}

sub end_timing {
  my ($msg, $N) = @_;
  if (not defined $N) { $N = 0; }
  my $etime = ((time - $start_time[$N]) / 60.0);
#  print_date();
  my $dat = `date`;
  chomp $dat;
  printf "$msg: %8.3f mins   (%8.3f hrs)  $dat\n", $etime, $etime/60.0;
  return $etime;
}

sub print_date {
  open (DATE ,"date +%c |") or 
	    die "Unable to execute \"date command |\": $!";
  my $date = <DATE>;
  chomp $date;
  close (DATE) || die "unable to close DATE $!";
  print "date: $date\n";
}

1;
