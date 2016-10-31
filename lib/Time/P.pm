use strict;
use warnings;
package Time::P;

# ABSTRACT: Parse times from strings.

use Carp qw/ croak /;
use Exporter qw/ import /;
use Function::Parameters;
use Data::Munge qw/ list2re /;

use Time::C::Util qw/ get_fmt_tok get_locale /;

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

my %parser; %parser = (
    '%A' => fun (:$locale) {
        my @weekdays = @{ get_locale(weekdays => $locale) };
        my $re = list2re(@weekdays);
        return qr"(?<A>$re)";
    },
    '%a' => fun (:$locale) {
        my @weekdays_abbr = @{ get_locale(weekdays_abbr => $locale) };
        my $re = list2re(@weekdays_abbr);
        return qr"(?<a>$re)";
    },
    '%B' => fun (:$locale) {
        my @months = @{ get_locale(months => $locale) };
        my $re = list2re(@months);
        return qr"(?<B>$re)";
    },
    '%b' => fun (:$locale) {
        my @months_abbr = @{ get_locale(months_abbr => $locale) };
        my $re = list2re(@months_abbr);
        return qr"(?<b>$re)";
    },
    '%C' => fun () { qr"(?<C>[0-9][0-9])"; },
    '%c' => fun (:$locale) { _compile_fmt(get_locale(datetime => $locale), locale => $locale); },
    '%D' => fun () {
        return $parser{'%m'}->(), qr!/!, $parser{'%d'}->(), qr!/!, $parser{'%y'}->();
    },
    '%d' => fun () { qr"(?<d>[0-9][0-9])"; },
    '%e' => fun () { qr"\s?(?<e>[0-9][0-9]?)"; },
    '%F' => fun () {
        return $parser{'%Y'}->(), qr/-/, $parser{'%m'}->(), qr/-/, $parser{'%d'}->();
    },
    '%G' => fun () { qr"(?<G>[0-9]{1,4})"; },
    '%g' => fun () { qr"(?<g>[0-9][0-9])"; },
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
        my @am_pm = @{ get_locale(am_pm => $locale) };
        return () unless @am_pm;
        my $re = list2re(@am_pm);
        return qr"(?<p>$re)";
    },
    '%X' => fun (:$locale) { _compile_fmt(get_locale(time => $locale), locale => $locale); },
    '%x' => fun (:$locale) { _compile_fmt(get_locale(date => $locale), locale => $locale); },
    '%R' => fun () {
        return $parser{'%H'}->(), qr/:/, $parser{'%M'}->();
    },
    '%r' => fun (:$locale) { _compile_fmt(get_locale(time_ampm => $locale), locale => $locale); },
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

C<$locale> is an optional parameter which defaults to C<C>. It is used to determine how the format specifiers C<%a>, C<%A>, C<%b>, C<%B>, C<%c>, C<%p>, and C<%r> match. See L<Format Specifiers> for more details.

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
    while (defined(my $tok = get_fmt_tok($fmt, $pos))) {
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

fun _parse_struct ($struct, :$locale) {
    # First, if we know the epoch, great
    my $epoch = $struct->{'s'};

    # Then set up as many date bits we know about
    #  year + day of year
    #  year + month + day of month
    #  year + week + day of week

    my $wyear = 0;
    my $year = $struct->{'Y'};
    if (not defined $year) {
        if (defined $struct->{'G'}) {
            $year = $struct->{'G'};
            $wyear = 1;
        } elsif (defined $struct->{'C'}) {
            $year = $struct->{'C'} * 100;
            $year += $struct->{'y'} if defined $struct->{'y'};
            if (defined $struct->{'g'} and not defined $struct->{'y'}) {
                $year += $struct->{'g'};
                $wyear = 1;
            }
        } elsif (defined $struct->{'y'}) {
            $year = $struct->{'y'} + 1900;
            if ($year < (Time::C->now_utc()->year - 50)) { $year += 100; }
        } elsif (defined $struct->{'g'}) {
            $year = $struct->{'g'} + 1900;
            if ($year < (Time::C->now_utc()->year - 50)) { $year += 100; }
            $wyear = 1;
        }
    }

    my $yday = $struct->{'j'};

    my $month = $struct->{'m'};
    if (not defined $month) {
        if (defined $struct->{'B'}) {
            $month = _get_index($struct->{'B'}, @{ get_locale(months => $locale) }) + 1;
        } elsif (defined $struct->{'b'}) {
            $month = _get_index($struct->{'b'}, @{ get_locale(months_abbr => $locale) }) + 1;
        } 
    }

    my $mday = $struct->{'d'};
    if (not defined $mday) { $mday = $struct->{'e'}; }

    my $u_week = $struct->{'U'};
    my $w_week = $struct->{'W'};
    my $v_week = $struct->{'V'};

    my $wday = $struct->{'u'} // $struct->{'w'};

    if (not defined $wday) {
        if (defined $struct->{'A'}) {
            $wday = _get_index($struct->{'A'}, @{ get_locale(weekdays => $locale) });
        } elsif (defined $struct->{'a'}) {
            $wday = _get_index($struct->{'a'}, @{ get_locale(weekdays_abbr => $locale) });
        }
    }
    $wday = 7 if defined $wday and $wday == 0;

    if (not defined $w_week and defined $u_week and defined $wday) {
        $w_week = $u_week; $w_week-- if $wday == 7;
    }

    if (not defined $v_week and defined $w_week) {
        my $t = Time::C->new($year // Time::C->now_utc->year);

        $v_week = $t->day_of_week >= 5 ? $w_week : $w_week + 1;
        if ($wyear and $w_week == 0) { $wyear = 0; $year++; $v_week--; }
    }

    if ($wyear and defined $v_week) {
        $year = Time::C->mktime(year => $year, week => $v_week)->year;
    } elsif (defined $v_week and $v_week > 1) {
        if (Time::C->mktime(year => $year, week => $v_week)->year == $year + 1) {
            $year-- if not defined $month;
        }
    }

    # Next try to set up time bits -- these are pretty easy in comparison

    # fix I and l if they're == 12 and it's ... pm? am? gah
    my $hour = $struct->{'H'};
    if (not defined $hour) { $hour = $struct->{'k'}; }
    if (not defined $hour) {
        $hour = $struct->{'I'} // $struct->{'l'};
        if (defined $hour and defined $struct->{'p'}) {
            if (_get_index($struct->{'p'}, @{ get_locale(am_pm => $locale) })) {
                # PM
                if ($hour < 12) { $hour += 12; }
                elsif ($hour == 12) { $hour = 0; }
            } else {
                # AM
                if ($hour == 0) { $hour = 12; }
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
    $struct{week} = $v_week if defined $v_week;
    $struct{wday} = $wday if defined $wday;
    $struct{yday} = $yday if defined $yday;
    $struct{year} = $year if defined $year;
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

=item C<%G>

Year, 1-4 digits, representing the week-based year since year 0, e.g. C<2016>.

=item C<%g>

2 digit week-based year without century, which will be interpreted as being within 50 years of the current year, whether that means adding 1900 or 2000 to it, e.g. C<16>.

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

=item L<Time::C>

The companion to this module, which represents the actual time we parsed.

=item L<Time::Piece>

Also provides a C<strptime()>, but it doesn't deal well with timezones or offsets.

=item L<POSIX::strptime>

Also provides a C<strptime()>, but it also doesn't deal well with timezones or offsets.

=item L<Time::Strptime>

Also provides a C<strptime()>, but it doesn't handle C<%c>, C<%x>, or C<%X> format specifiers at all, only supports a C<POSIX> version of C<%r>, and is arguably buggy with C<%a>, C<%A>, C<%b>, C<%B>, and C<%p>.

=item L<DateTime::Format::Strptime>

Provides an OO-interface for strptime, but it has the same issues as C<Time::Strptime>.

=back

