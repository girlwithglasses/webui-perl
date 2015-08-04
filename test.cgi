#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.16';
use Data::Dumper::Concise;
use lib '/global/u1/a/aireland/webUI/webui.cgi/';
use WebConfig;

my $env = getEnv();

open (my $fh, '>', '/global/u1/a/aireland/log/webenv.pl') or die "Could not open file: $!";
print { $fh } Dumper $env;

exit;
