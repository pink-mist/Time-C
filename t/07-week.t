#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Time::C;
use Time::F;
use Time::P;

my $fmt = "%G: %W-%w";
foreach my $t (Time::C->new(2016), Time::C->new(2016,1,22)) {
    my $str = strftime $t, $fmt;
    my $t2 = strptime $str, $fmt;

    is ($t2, $t, "Week for $t parsed correctly.");
}

done_testing;
