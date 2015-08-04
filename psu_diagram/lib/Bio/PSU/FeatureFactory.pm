
package Bio::PSU::FeatureFactory;

use strict;
use Carp;
use Bio::PSU::Base;
use Bio::PSU::Utils::FeatureSplicer;

use vars qw(@ISA);

@ISA = qw(Bio::PSU::Base Bio::PSU::Utils::FeatureSplicer);

{
    my $_class_defaults = { };
    my $_class_args     = { };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}

sub annotate_translation
{
    my ($self, $feature, $position, $length) = @_;

    if ($feature->strand == 1 or $feature->strand == -1)
    {
	return $self->make_spliced_annotation($feature, $position, $length)
    }
    else
    {
	$self->btrace("Unable to add annotation to feature as its strand is not set")
    }
}

1;
