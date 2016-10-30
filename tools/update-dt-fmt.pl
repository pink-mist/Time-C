#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;
use JSON::MaybeXS qw/ encode_json /;
use Data::Dumper;

my %d_t_fmt = ();
my %d_fmt = ();
my %t_fmt = ();
my %r_fmt = ();
my %months = ();
my %months_abbr = ();
my %days = ();
my %days_abbr = ();
my %am_pm = ();

my $dir = shift; $dir //= "/usr/share/i18n/locales";

opendir my $dh, $dir or die "Could not open $dir: $!";

foreach my $file (grep -f "$dir/$_", readdir $dh) {
    open my $fh, '<', "$dir/$file" or die "Could not open $dir/$file: $!";

    $_ = do { local $/; readline $fh; };
    close $fh;

    my ($comment) = /^comment_char\s+(\S+)$/m;
    my ($escape) = /^escape_char\s+(\S+)$/m;

    # remove comments
    s/^$comment.*$//gm if defined $comment;
    s/\s*$comment\s?\S+[\t ]*//g if defined $comment;
    s/$comment\s*$//gm if defined $comment;

    # remove escapes
    s/$escape\n[\t ]*//g if defined $escape;

    my ($d_t_fmt) = /^d_t_fmt\s+"(.*)"$/m;
    my ($d_fmt)   = /^d_fmt\s+"(.*)"$/m;
    my ($t_fmt)   = /^t_fmt\s+"(.*)"$/m;
    my ($r_fmt)   = /^t_fmt_ampm\s+"(.*)"$/m;
    my ($abday)   = /^abday\s+(".*")$/m;
    my ($day)     = /^day\s+(".*")$/m;
    my ($abmon)   = /^abmon\s+(".*")$/m;
    my ($mon)     = /^mon\s+(".*")$/m;
    my ($am_pm)   = /^am_pm\s+(".*")$/m;

    if (defined $abday) {
        my @abdays = map { decode_fmt($_) } map { /"([^"]+)"/ } split /;/, $abday;
        $days_abbr{$file} = \@abdays;
    }
    if (defined $day) {
        my @days = map { decode_fmt($_) } map { /"([^"]+)"/ } split /;/, $day;
        $days{$file} = \@days;
    }
    if (defined $abmon) {
        my @abmons = map { decode_fmt($_) } map { /"([^"]+)"/ } split /;/, $abmon;
        $months_abbr{$file} = \@abmons;
    }
    if (defined $mon) {
        my @mons = map { decode_fmt($_) } map { /"([^"]+)"/ } split /;/, $mon;
        $months{$file} = \@mons;
    }
    if (defined $am_pm) {
        my @am_pms = map { decode_fmt($_) } map { /"([^"]+)"/ } split /;/, $am_pm;
        $am_pm{$file} = \@am_pms;
    } else {
        #$am_pm{$file} = [qw/ AM PM /];
    }

    $d_t_fmt{$file} = decode_fmt($d_t_fmt) if length $d_t_fmt;
    $d_fmt{$file} = decode_fmt($d_fmt) if length $d_fmt;
    $t_fmt{$file} = decode_fmt($t_fmt) if length $t_fmt;
    if (length $r_fmt) {
        $r_fmt{$file} = decode_fmt($r_fmt);
    } else {
        $r_fmt{$file} = "%I:%M:%S %p" if defined $d_t_fmt{$file} and $d_t_fmt{$file} =~ /%r/;
        $r_fmt{$file} = "%I:%M:%S %p" if defined $t_fmt{$file} and $t_fmt{$file} =~ /%r/;
    }

}

sub decode_fmt {
    my $fmt = shift;
    $fmt =~ s/<U([0-9A-Fa-f]+)>/chr hex $1/ge;

    return $fmt;
}

my $comment = sprintf "# format db generated on %s from %s.\n", "".localtime, $dir;
print encode_json { comment => $comment, d_t_fmt => \%d_t_fmt, d_fmt => \%d_fmt, t_fmt => \%t_fmt, days => \%days, days_abbr => \%days_abbr, months => \%months, months_abbr => \%months_abbr, am_pm => \%am_pm, r_fmt => \%r_fmt };
