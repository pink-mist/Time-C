#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;
use Data::Dumper;

binmode STDOUT, ":encoding(UTF-8)";

my %d_t_fmt = ();
my %d_fmt = ();
my %t_fmt = ();

my $dir = shift; $dir //= "/usr/share/i18n/locales";

opendir my $dh, $dir or die "Could not open $dir: $!";

foreach my $file (grep -f "$dir/$_", readdir $dh) {
    open my $fh, '<', "$dir/$file" or die "Could not open $dir/$file: $!";

    while (readline($fh)) {
        if (/^d_t_fmt\s+"(.*)"$/) {
            $d_t_fmt{$file} = decode_fmt($1);
        } elsif (/^d_fmt\s+"(.*)"$/) {
            $d_fmt{$file} = decode_fmt($1);
        } elsif (/^t_fmt\s+"(.*)"$/) {
            $t_fmt{$file} = decode_fmt($1);
        }
    }
}

sub decode_fmt {
    my $fmt = shift;
    $fmt =~ s/<U([0-9A-Fa-f]+)>/chr hex $1/ge;

    return $fmt;
}

$Data::Dumper::Terse = 1;
$Data::Dumper::Useqq = 1;
$Data::Dumper::Sortkeys = 1;

printf "# format db generated on %s from %s.\n", "".localtime, $dir;
print Dumper { d_t_fmt => \%d_t_fmt, d_fmt => \%d_fmt, t_fmt => \%t_fmt };
