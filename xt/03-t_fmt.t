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

foreach my $l (sort keys %{ $loc_db->{t_fmt} }) {
SKIP: {
    skip "$l => Charset issues.", 1 if in ($l => qw/ nan_TW@latin /);
    skip "$l => Not a proper locale.", 1 if in ($l => qw/ i18n /);
    skip "$l => No AM/PM specifier even though it needs it.", 1 if in ($l => qw/ zh_HK wal_ET ur_IN tig_ER ti_ET ti_ER the_NP tcy_IN ta_IN sq_AL so_SO so_KE so_ET so_DJ sid_ET sd_IN@devanagari sd_IN sat_IN sa_IN raj_IN pa_IN om_KE om_ET ne_NP mt_MT ms_MY mr_IN mni_IN ml_IN mag_IN ks_IN@devanagari ks_IN kok_IN kn_IN hy_AM hne_IN hi_IN gu_IN gez_ET gez_ER en_PH en_IN en_HK doi_IN byn_ER brx_IN bn_IN bn_BD bho_IN bhb_IN ar_YE ar_TN ar_SY ar_SS ar_SD ar_QA ar_OM ar_MA ar_LY ar_LB ar_KW ar_JO ar_IQ ar_IN ar_EG ar_DZ ar_BH ar_AE anp_IN am_ET aa_ET aa_ER@saaho aa_ER aa_DJ /);
        
        
    my $t = Time::C->now_utc();

    my $stdout = do {
        local $ENV{LC_ALL} = "$l.UTF-8";
        local $ENV{TZ} = "UTC";
        local $/;
        open my $fh, '-|', 'date', '+%X';
        readline $fh;
    };

    chomp $stdout;

    my $data = decode('UTF-8', $stdout);

    note "$l => $stdout";
    my $p = eval { strptime($data, "%X", locale => $l) };

    if (defined $p) {
        cmp_ok ($p->epoch - $t->epoch, '>=', '-60', "$l => Correct time calculated!") or
          diag sprintf("Error: %s\nStr: %s\nFormat: %s\nR-Format: %s\n\n", "$p is not close enough to $t", $data, $loc_db->{t_fmt}{$l}, $loc_db->{r_fmt}{$l});
    } else {
        my $err = $@;
        if ($err =~ /^Unsupported format specifier: (%\S+)/) {
            skip "$l => Unsupported format specifier: $1", 1;
        } else {
            fail "$l => Correct time calculated!";
            diag sprintf("Error: %s\nStr: %s\nFormat: %s\nR-Format: %s\n\n", encode('UTF-8', $err), $data, $loc_db->{t_fmt}{$l}, $loc_db->{r_fmt}{$l});
        }
    }
}
}

done_testing;
