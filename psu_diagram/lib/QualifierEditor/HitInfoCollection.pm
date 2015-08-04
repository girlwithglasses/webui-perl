=head1 NAME

QualifierEditor::HitInfoCollection - The object contains a group of HitInfo 
objects 

$Header: /scratch/svn-conversion/img_dev/v2/webUI/webui.cgi/psu_diagram/lib/QualifierEditor/HitInfoCollection.pm,v 1.1 2013-03-27 20:41:23 jinghuahuang Exp $

=cut

package QualifierEditor::HitInfoCollection;

use strict;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %args = @_;

  my $self = {};

  $self->{values} = [];

  bless $self, $class;

  return $self;
}

sub add
{
  my ($self, $new_value) = @_;

  if (!$new_value->isa ("QualifierEditor::HitInfo")) {
    die '!$new_value->isa ("QualifierEditor::HitInfo")' . "\n";
  }

  push @{$self->{values}}, $new_value;

  my %new_value = %{$new_value};

  for my $key (keys %new_value) {
    if (exists $self->{max_length}{$key}) {
      if (defined $new_value{$key} &&
          $self->{max_length}{$key} < length $new_value{$key}) {
        $self->{max_length}{$key} = length $new_value{$key};
      }
    } else {
      if (defined $new_value{$key}) {
        $self->{max_length}{$key} = length $new_value{$key};
      } else {
        $self->{max_length}{$key} = 0;
      }
    }
  }
}

sub max_length
{
  my ($self, $id) = @_;

  if (exists $self->{max_length}{$id}) {
    return $self->{max_length}{$id};
  } else {
    return -1;
  }
}

sub all_values
{
  my ($self) = @_;

  return @{$self->{values}};
}

1;
