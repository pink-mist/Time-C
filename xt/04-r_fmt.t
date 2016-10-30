#!/usr/bin/env perl

use strict;
use warnings;

use Encode qw/ decode encode /;
use File::Share qw/ dist_file /;
use Test::More;
use Carp::Always;
use JSON::MaybeXS qw/ decode_json /;
use Data::Munge qw/ slurp /;

use Time::C;
use Time::P;

binmode STDERR, ":encoding(UTF-8)";

sub in {
    my ($n, @h) = @_;
    foreach my $s (@h) { return 1 if $n eq $s; }
    return 0;
}

my $fn = dist_file 'Time-C', 'locale.db';
open my $fh, '<', $fn or die "Could not open $fn: $!";
my $loc_db = decode_json slurp $fh;

foreach my $l (sort keys %{ $loc_db->{r_fmt} }) {
SKIP: {
    skip "$l => Charset issues.", 1 if in ($l => qw/ nan_TW@latin tt_RU@iqtelif sd_IN@devanagari ks_IN@devanagari /);
    skip "$l => Not a proper locale.", 1 if in ($l => qw/ i18n /);

    my $t = Time::C->now_utc()->second_of_day(0);

    my $stdout = do {
        local $ENV{LC_ALL} = "$l.UTF-8";
        local $ENV{TZ} = "UTC";
        local $/;
        open my $fh, '-|', 'date', '+%r';
        readline $fh;
    };

    chomp $stdout;

    my $data = decode('UTF-8', $stdout);

    note "$l => $stdout";
    my $p = eval { strptime($data, "%r", locale => $l) };

    if (defined $p) {
        cmp_ok ($p->epoch - $t->epoch, '>=', '-60', "$l => Correct time calculated!") or
          diag sprintf("Error: %s\nStr: %s\nR-Format: %s\nAM: %s\nPM: %s\n\n", "$p is not close enough to $t", $data, $loc_db->{r_fmt}{$l}, @{ $loc_db->{am_pm}{$l} }[0,1]);
    } else {
        my $err = $@;
        if ($err =~ /^Unsupported format specifier: (%\S+)/) {
            skip "$l => Unsupported format specifier: $1", 1;
        } else {
            fail "$l => Correct time calculated!";
            diag sprintf("Error: %s\nStr: %s\nR-Format: %s\nAM: %s\nPM: %s\n\n", encode('UTF-8', $err), $data, $loc_db->{r_fmt}{$l}, @{ $loc_db->{am_pm}{$l} }[0,1]);
        }
    }
}
}

done_testing;
