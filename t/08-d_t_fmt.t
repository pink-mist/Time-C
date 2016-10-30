#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

if (not $ENV{RELEASE_TESTING}) { plan skip_all => 'Release test should only be run on release.'; }

use Encode qw/ decode encode /;
use File::Share qw/ dist_file /;
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

foreach my $l (sort keys %{ $loc_db->{d_t_fmt} }) {
SKIP: {
    skip "$l => Charset issue.", 1 if in($l, qw/ uz_UZ@cyrillic nan_TW@latin tt_RU@iqtelif sr_RS@latin sd_IN@devanagari ks_IN@devanagari km_KH be_BY@latin /);
    skip "$l => Not a proper locale.", 1 if in ($l, qw/ i18n /);
    skip "$l => Error in date spec.", 1 if in ($l, qw/ ms_MY mt_MT id_ID hy_AM /);
    skip "$l => Doesn't actually display a time.", 1 if in ($l, qw/ br_FR /);
    skip "$l => Treated like aa_ER", 1 if in ($l, qw/ aa_ER@saaho /);

    my $t = Time::C->now_utc();

    my $stdout = do {
        local $ENV{LC_ALL} = "$l.UTF-8";
        local $ENV{TZ} = "UTC";
        local $/;
        open my $fh, '-|', 'date', '+%c';
        readline $fh;
    };

    chomp $stdout;

    my $data = decode('UTF-8', $stdout);

    note "$l => $stdout";
    my $p = eval { strptime($data, "%c", locale => $l) };

    if (defined $p) {
        cmp_ok ($p->epoch - $t->epoch, '>=', '-60', "$l => Correct time calculated!") or
          diag sprintf("Error: %s\nStr: %s\nFormat: %s\nR-Format: %s\n\n", "$p is not close enough to $t", $data, encode('UTF-8', $loc_db->{d_t_fmt}{$l}), encode('UTF-8', $loc_db->{r_fmt}{$l}));
    } else {
        my $err = $@;
        if ($err =~ /^Unsupported format specifier: (%\S+)/) {
            skip "$l => Unsupported format specifier: $1", 1;
        } else {
            fail "$l => Correct time calculated!";
            diag sprintf("Error: %s\nStr: %s\nFormat: %s\nR-Format: %s\nAM: %s\nPM: %s\n\n",
              encode('UTF-8', $err),
              $data,
              encode('UTF-8', $loc_db->{d_t_fmt}{$l}),
              encode('UTF-8', $loc_db->{r_fmt}{$l} // ''),
              ${ $loc_db->{am_pm}{$l} // [] }[0] // '',
              ${ $loc_db->{am_pm}{$l} // [] }[1] // '');
        }
    }
}
}

done_testing;
