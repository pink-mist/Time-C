use strict;
use warnings;
package Time::P;

# ABSTRACT: Parse times from strings.

use Carp qw/ croak /;
use Exporter qw/ import /;
use Function::Parameters;
use File::Share qw/ dist_file /;
use Data::Munge qw/ list2re slurp /;
use JSON::MaybeXS qw/ decode_json /;

use constant DEBUG => 0;

our @EXPORT = qw/ strptime /;

=head1 SYNOPSIS

  use Time::P; # strptime() automatically exported.

  # "2016-10-30T16:07:34Z"
  my $t = strptime "sön okt 30 16:07:34 UTC 2016", "%a %b %d %T %Z %Y", locale => "sv_SE";

=head1 DESCRIPTION

Parses a string to get a time out of it using L<Format Specifiers> reminiscent of C's C<scanf> and indeed C<strptime> functions.

=head1 FUNCTIONS

=cut

our $loc_db;

my %parser; %parser = (
    '%A' => fun (:$locale) {
        my @weekdays = @{ _get_locale(weekdays => $locale) };
        my $re = list2re(@weekdays);
        return qr"(?<A>$re)";
    },
    '%a' => fun (:$locale) {
        my @weekdays_abbr = @{ _get_locale(weekdays_abbr => $locale) };
        my $re = list2re(@weekdays_abbr);
        return qr"(?<a>$re)";
    },
    '%B' => fun (:$locale) {
        my @months = @{ _get_locale(months => $locale) };
        my $re = list2re(@months);
        return qr"(?<B>$re)";
    },
    '%b' => fun (:$locale) {
        my @months_abbr = @{ _get_locale(months_abbr => $locale) };
        my $re = list2re(@months_abbr);
        return qr"(?<b>$re)";
    },
    '%C' => fun () { qr"(?<C>[0-9][0-9])"; },
    '%c' => fun (:$locale) { _get_locale(datetime => $locale); },
    '%D' => fun () {
        return $parser{'%m'}->(), qr!/!, $parser{'%d'}->(), qr!/!, $parser{'%y'}->();
    },
    '%d' => fun () { qr"(?<d>[0-9][0-9])"; },
    '%e' => fun () { qr"\s?(?<e>[0-9][0-9]?)"; },
    '%F' => fun () {
        return $parser{'%Y'}->(), qr/-/, $parser{'%m'}->(), qr/-/, $parser{'%d'}->();
    },
    '%H' => fun () { qr"(?<H>[0-9][0-9])"; },
    '%h' => fun (:$locale) { $parser{'%b'}->(locale => $locale) },
    '%I' => fun () { qr"(?<I>[0-9][0-9])"; },
    '%j' => fun () { qr"(?<j>[0-9][0-9][0-9])"; },
    '%k' => fun () { qr"\s?(?<k>[0-9][0-9]?)"; },
    '%l' => fun () { qr"\s?(?<l>[0-9][0-9]?)"; },
    '%M' => fun () { qr"(?<M>[0-9][0-9])"; },
    '%m' => fun () { qr"(?<m>[0-9][0-9])"; },
    '%n' => fun () { qr"\s+"; },
    '%p' => fun (:$locale) {
        my @am_pm = @{ _get_locale(am_pm => $locale) };
        return () unless @am_pm;
        my $re = list2re(@am_pm);
        return qr"(?<p>$re)";
    },
    '%X' => fun (:$locale) { _get_locale(time => $locale) },
    '%x' => fun (:$locale) { _get_locale(date => $locale) },
    '%R' => fun () {
        return $parser{'%H'}->(), qr/:/, $parser{'%M'}->();
    },
    '%r' => fun (:$locale) { _get_locale(time_ampm => $locale); },
    '%S' => fun () { qr"(?<S>[0-9][0-9])"; },
    '%s' => fun () { qr"\s*(?<s>[0-9]+)"; },
    '%T' => fun () {
        return $parser{'%H'}->(), qr/:/, $parser{'%M'}->(), qr/:/, $parser{'%S'}->();
    },
    '%t' => fun () { qr"\s+"; },
    '%U' => fun () { qr"(?<U>[0-9][0-9])"; },
    '%u' => fun () { qr"(?<u>[0-9])"; },
    '%V' => fun () { qr"(?<V>[0-9][0-9])"; },
    '%v' => fun (:$locale) {
        return $parser{'%e'}->(), qr/-/, $parser{'%b'}->(locale => $locale), qr/-/, $parser{'%Y'}->()
    },
    '%W' => fun () { qr"(?<W>[0-9][0-9])"; },
    '%w' => fun () { qr"(?<w>[0-9])"; },
    '%Y' => fun () { qr"(?<Y>[0-9]{1,4})"; },
    '%y' => fun () { qr"(?<y>[0-9][0-9])"; },
    '%Z' => fun () { qr"(?<Z>\S+)"; },
    '%z' => fun () { qr"(?<z>[-+][0-9][0-9](?::?[0-9][0-9])?)"; },
    '%%' => fun () { qr"%"; },
);

=head2 strptime

  my $t = strptime($str, $fmt);
  my $t = strptime($str, $fmt, locale => $locale, strict => $strict);

C<strptime> takes a string and a format, and tries to parse the string using the format to create a L<Time::C> object representing the time.

=over

=item C<$str>

C<$str> is the string to parse.

=item C<$fmt>

C<$fmt> is the format specifier used to parse the C<$str>. If it can't match C<$str> to get a useful date/time it will throw an exception. See L<Format Specifiers> for details on the supported format specifiers.

=item C<< locale => $locale >>

C<$locale> is an optional boolean flag which defaults to C<C>. It is used to determine how the format specifiers C<%a>, C<%A>, C<%b>, C<%B>, C<%c>, C<%p>, and C<%r> match. See L<Format Specifiers> for more details.

=item C<< strict => $strict >>

C<$strict> is an optional boolean flag which defaults to true. If it is a true value, the C<$fmt> must describe the string entirely. If it is false, the C<$fmt> may describe only part of the string, and any extra bits, either before or after, are discarded.

=back

If the format reads in a timezone that isn't well-defined, it will be silently ignored, and any offset that is parsed will be used instead. It uses L<Time::C/mktime> to create the C<Time::C> object from the parsed data.

=cut

fun strptime ($str, $fmt, :$locale = 'C', :$strict = 1) {
    require Time::C;

    my %struct = ();

    my @res = _compile_fmt($fmt, locale => $locale);
    @res = (qr/^/, @res, qr/$/) if $strict;

    while (@res and $str =~ m/\G$res[0]/gc) {
        %struct = (%struct, %+);
        shift @res;
    }

    if (@res) {
        croak sprintf "Could not match '%s' using '%s'. Match failed at position %d.", $str, $fmt, pos($str);
    }

    %struct = _parse_struct(\%struct, locale => $locale);
    my $time = Time::C->mktime(%struct);

    return $time;
}

fun _compile_fmt ($fmt, :$locale) {
    my @res = ();

    my $pos = 0;

    # _get_tok will increment $pos for us
    while (defined(my $tok = _get_tok($fmt, $pos))) {
        if (exists $parser{$tok}) {
            push @res, $parser{$tok}->(locale => $locale);
        } elsif ($tok =~ /^%/) {
            croak "Unsupported format specifier: $tok";
        } else {
            push @res, qr/\Q$tok\E/;
        }
    }

    return @res;
}

sub _get_tok {
    my ($fmt, $pos) = @_;

    return undef if $pos >= length $fmt;

    my $tok_len = substr($fmt, $pos, 1) eq '%' ? 2 : 1;

    my $tok = substr $fmt, $pos, $tok_len;

    while ($tok eq '%-') {
        $tok = '%' . substr($fmt, $pos + $tok_len, 1); $tok_len++;
    }
    if (($tok eq '%O') or ($tok eq '%E')) {
        $tok .= substr($fmt, $pos + $tok_len, 1); $tok_len++;
    }

    $_[1] = $pos + $tok_len;
    return $tok;
}

fun _parse_struct ($struct, :$locale) {
    # First, if we know the epoch, great
    my $epoch = $struct->{'s'};

    # Then set up as many date bits we know about
    #  year + day of year
    #  year + month + day of month
    #  year + week + day of week

    my $year = $struct->{'Y'};
    if (not defined $year) {
        if (defined $struct->{'C'}) {
            $year = $struct->{'C'} * 100;
            $year += $struct->{'y'} if defined $struct->{'y'};
        } elsif (defined $struct->{'y'}) {
            $year = $struct->{'y'} + 1900;
            if ($year < (Time::C->now_utc()->year - 50)) { $year += 100; }
        }
    }

    my $yday = $struct->{'j'};

    my $month = $struct->{'m'};
    if (not defined $month) {
        if (defined $struct->{'B'}) {
            $month = _get_index($struct->{'B'}, @{ $loc_db->{months}{$locale} }) + 1;
        } elsif (defined $struct->{'b'}) {
            $month = _get_index($struct->{'b'}, @{ $loc_db->{months_abbr}{$locale} }) + 1;
        } 
    }

    my $mday = $struct->{'d'};
    if (not defined $mday) { $mday = $struct->{'e'}; }

    my $s_week = $struct->{'U'};
    my $m_week = $struct->{'W'};

    my $wday = $struct->{'u'};
    if (not defined $wday) {
        $wday = $struct->{'w'};
        $wday = 7 if defined $wday and $wday = 0;
    }
    if (not defined $wday) {
        if (defined $struct->{'A'}) {
            $wday = _get_index($struct->{'A'}, @{ $loc_db->{days}{$locale} }) + 1;
        } elsif (defined $struct->{'a'}) {
            $wday = _get_index($struct->{'a'}, @{ $loc_db->{days_abbr}{$locale} }) + 1;
        }
    }

    if (not defined $m_week and defined $s_week and defined $wday) {
        $m_week = $s_week; $m_week-- if $wday == 7;
    }

    # Next try to set up time bits -- these are pretty easy in comparison

    # fix I and l if they're == 12 and it's ... pm? am? gah
    my $hour = $struct->{'H'};
    if (not defined $hour) { $hour = $struct->{'k'}; }
    if (not defined $hour) {
        $hour = $struct->{'I'} // $struct->{'l'};
        if (defined $hour and defined $struct->{'p'}) {
            if (_get_index($struct->{'p'}, @{ $loc_db->{am_pm}{$locale} })) {
                $hour = $hour + 12 unless $hour == 12;
            } else {
                $hour = $hour - 12 if $hour == 12;
            }
        }
    }

    my $min = $struct->{'M'};

    my $sec = $struct->{'S'};

    # And last see if we have some timezone or at least offset info

    my $tz = $struct->{'Z'}; # should verify that it's a useful tz
    if (defined $tz) {
        undef $tz if not defined eval { Time::C->now($tz); };
    }

    my $offset = $struct->{'z'};

    my $offset_n = defined $offset ? _offset_to_minutes($offset) : undef;

    my %struct = ();
    $struct{second} = $sec if defined $sec;
    $struct{minute} = $min if defined $min;
    $struct{hour} = $hour if defined $hour;
    $struct{mday} = $mday if defined $mday;
    $struct{month} = $month if defined $month;
    $struct{week} = $m_week if defined $m_week;
    $struct{wday} = $wday if defined $wday;
    $struct{yday} = $yday if defined $yday;
    $struct{epoch} = $epoch if defined $epoch;
    $struct{tz} = $tz if defined $tz;
    $struct{offset} = $offset_n if defined $offset_n;

    return %struct;
}

fun _offset_to_minutes ($offset) {
    my ($sign, $hours, $minutes) = $offset =~ m/^([+-])([0-9][0-9]):?([0-9][0-9])?$/;
    return $sign eq '+' ? ($hours * 60 + $minutes) : -($hours * 60 + $minutes);
}

fun _get_index ($needle, @haystack) {
    if (not @haystack and $needle eq '') { return 0; }

    foreach my $i (0 .. $#haystack) {
        return $i if $haystack[$i] eq $needle;
    }
    croak "Could not find $needle in the list.";
}

fun _get_locale($type, $locale) {
    if (not defined $loc_db) {
        my $fn = dist_file('Time-C', 'locale.db');
        open my $fh, '<', $fn
          or croak "Could not open $fn: $!";
        $loc_db = decode_json slurp $fh;
    }

    my @ret;
    if ($type eq 'weekdays') {
        @ret = $loc_db->{days}->{$locale};
    } elsif ($type eq 'weekdays_abbr') {
        @ret = $loc_db->{days_abbr}->{$locale};
    } elsif ($type eq 'months') {
        @ret = $loc_db->{months}->{$locale};
    } elsif ($type eq 'months_abbr') {
        @ret = $loc_db->{months_abbr}->{$locale};
    } elsif ($type eq 'am_pm') {
        @ret = $loc_db->{am_pm}->{$locale};
    } elsif ($type eq 'datetime') {
        @ret = _compile_fmt($loc_db->{d_t_fmt}->{$locale}, locale => $locale);
    } elsif ($type eq 'date') {
        @ret = _compile_fmt($loc_db->{d_fmt}->{$locale}, locale => $locale);
    } elsif ($type eq 'time') {
        @ret = _compile_fmt($loc_db->{t_fmt}->{$locale}, locale => $locale);
    } elsif ($type eq 'time_ampm') {
        @ret = _compile_fmt($loc_db->{r_fmt}->{$locale}, locale => $locale);
    } else { croak "Unknown locale type: $type."; }

    if (not defined $ret[0]) { croak "Value for locale type $type in locale $locale is undefined."; }

    return wantarray ? @ret : $ret[0];
}

1;

__END__

=head1 Format Specifiers

The format specifiers work in a format to parse distinct portions of a string. Any part of the format that isn't a format specifier will be matched verbatim. All format specifiers start with a C<%> character. Some implementations of C<strptime> will support some of them, and other implementations will support others. This implementation will support the ones described below:

=over

=item C<%A>

Full weekday, depending on the locale, e.g. C<söndag>.

=item C<%a>

Abbreviated weekday, depending on the locale, e.g. C<sön>.

=item C<%B>

Full month name, depending on the locale, e.g. C<oktober>.

=item C<%b>

Abbreviated month name, depending on the locale, e.g. C<okt>.

=item C<%C>

2 digit century, e.g. C<20>.

=item C<%c>

The date and time representation for the current locale, e.g. C<sön okt 30 16:07:34 UTC 2016>.

=item C<%D>

Equivalent to C<%m/%d/%y>, e.g. C<10/30/16>.

=item C<%d>

2 digit day of month, e.g. C<30>.

=item C<%e>

1/2 digit day of month, possibly space padded, e.g. C<30>.

=item C<%F>

Equivalent to C<%Y-%m-%d>, e.g. C<2016-10-30>.

=item C<%H>

2 digit hour in 24-hour time, e.g. C<16>.

=item C<%h>

Equivalent to C<%b>, e.g. C<okt>.

=item C<%I>

2 digit hour in 12-hour time, e.g. C<04>.

=item C<%j>

3 digit day of the year, e.g. C<304>.

=item C<%k>

1/2 digit hour in 24-hour time, e.g. C<16>.

=item C<%l>

1/2 digit hour in 12-hour time, possibly space padded, e.g. C< 4>.

=item C<%M>

2 digit minute, e.g. C<07>.

=item C<%m>

2 digit month, e.g. C<10>.

=item C<%n>

Arbitrary whitespace, like C<m/\s+/>.

=item C<%p>

Matches the locale version of C<a.m.> or C<p.m.>, if the locale has that. Otherwise matches the empty string.

=item C<%X>

The time representation for the current locale, e.g. C<16:07:34>.

=item C<%x>

The date representation for the current locale, e.g. C<2016-10-30>.

=item C<%R>

Equivalent to C<%H:%M>, e.g. C<16:07>.

=item C<%r>

The time representation with am/pm for the current locale. For example in the C<POSIX> locale, it is equivalent to C<%I:%M:%S %p>.

=item C<%S>

2 digit second, e.g. C<34>.

=item C<%s>

The epoch, i.e. the number of seconds since C<1970-01-01T00:00:00Z>.

=item C<%T>

Equivalent to C<%H:%M:%S>, e.g. C<16:07:34>.

=item C<%t>

Arbitrary whitespace, like C<m/\s+/>.

=item C<%U>

2 digit week number of the year, Sunday-based week, e.g. C<44>.

=item C<%u>

1 digit weekday, Monday-based week, e.g. C<7>.

=item C<%V>

2 digit week number of the year, Monday-based week, e.g. C<43>.

=item C<%v>

Equivalent to C<%e-%b-%Y>, which depends on the locale, e.g. C<30-okt-2016>.

=item C<%W>

2 digit week number of the year, Monday-based week, e.g. C<43>.

=item C<%w>

1 digit weekday, Sunday-based week, e.g. C<0>.

=item C<%Y>

Year, 1-4 digits, representing the full year since year 0, e.g. C<2016>.

=item C<%y>

2 digit year without century, which will be interpreted as being within 50 years of the current year, whether that means adding 1900 or 2000 to it, e.g. C<16>.

=item C<%Z>

Time zone name, e.g. C<CET>, or C<Europe/Stockholm>.

=item C<%z>

Offset from UTC in hours and minutes, or just hours, e.g. C<+0100>.

=item C<%%>

A literal C<%> sign.

=back

=head1 SEE ALSO

=over

=item L<Time::Piece>

Also provides a C<strptime()>, but it doesn't deal well with timezones or offsets.

=item L<POSIX::strptime>

Also provides a C<strptime()>, but it also doesn't deal well with timezones or offsets.

=item L<Time::Strptime>

Also provides a C<strptime()>, but it doesn't handle C<%c>, C<%x>, or C<%X> format specifiers at all, only supports a C<POSIX> version of C<%r>, and is arguably buggy with C<%a>, C<%A>, C<%b>, C<%B>, and C<%p>.

=item L<DateTime::Format::Strptime>

Provides an OO-interface for strptime, but it has the same issues as C<Time::Strptime>.

=back

