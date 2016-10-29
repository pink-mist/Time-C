package Time::P;

use strict;
use warnings;

use Carp qw/ croak /;
use Exporter qw/ import /;
use Function::Parameters;
use DateTime::Locale;
use File::ShareDir qw/ dist_file /;

use constant DEBUG => 0;

our @EXPORT = qw/ strptime /;

our %weekdays = ( C => [ qw/ Monday Tuesday Wednesday Thursday Friday Saturday Sunday / ] );
our %weekdays_abbr = ( C => [ qw/ Mon Tue Wed Thu Fri Sat Sun / ] );
our %months = ( C => [ qw/ January February March April May June July August September October November December / ] );
our %months_abbr = ( C => [ qw/ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec / ] );
our %am_pm = ( C => [ qw/ a.m. p.m. / ] );
our %datetime;
our %date;
our %time;
our %locales;
our $loc_db = {};

my %parser; %parser = (

#  Support these formats:
#
#    %A - national representation of the full weekday name (eg Monday)

    '%A' => fun (:$locale) {
        my @weekdays = @{ $weekdays{$locale} //= _build_locale(weekdays => $locale) };
        my $re = _list2re(@weekdays);
        return qr"(?<A>$re)";
    },

#    %a - national representation of the abbreviated weekday name (eg Mon)

    '%a' => fun (:$locale) {
        my @weekdays_abbr = @{ $weekdays_abbr{$locale} //= _build_locale(weekdays_abbr => $locale) };
        my $re = _list2re(@weekdays_abbr);
        return qr"(?<a>$re)";
    },

#    %B - national representation of the full month name (eg January)

    '%B' => fun (:$locale) {
        my @months = @{ $months{$locale} //= _build_locale(months => $locale) };
        my $re = _list2re(@months);
        return qr"(?<B>$re)";
    },

#    %b - national representation of the abbreviated month name (eg Jan)

    '%b' => fun (:$locale) {
        my @months_abbr = @{ $months_abbr{$locale} //= _build_locale(months_abbr => $locale) };
        my $re = _list2re(@months_abbr);
        return qr"(?<b>$re)";
    },

#    %C - 2 digit century (eg 20)

    '%C' => fun () { qr"(?<C>[0-9][0-9])"; },

#    #c - The date and time representation for the current locale.

    '%c' => fun (:$locale) {
        return $datetime{$locale} //= _build_locale(datetime => $locale);
    },

#    %D - equivalent to %m/%d/%y (eg 01/31/16)

    '%D' => fun () {
        my $re = sprintf "(?<D>%s/%s/%s)", $parser{'%m'}->(), $parser{'%d'}->(), $parser{'%y'}->();
        return qr"$re";
    },

#    %d - 2 digit day of month (eg 30)

    '%d' => fun () { qr"(?<d>[0-9][0-9])"; },

#    %e - 1/2 digit day of month (eg 9)

    '%e' => fun () { qr"(?<e>[0-9][0-9]?)"; },

#    %F - equivalent to %Y-%m-%d (eg 2016-01-31)

    '%F' => fun () {
        my $re = sprintf "(?<F>%s-%s-%s)", $parser{'%Y'}->(), $parser{'%m'}->(), $parser{'%d'}->();
        return qr"$re";
    },

#    %H - 2 digit hour in 24-hour time (eg 23)

    '%H' => fun () { qr"(?<H>[0-9][0-9])"; },

#    %h - equivalent to %b (eg Jan)

    '%h' => fun (:$locale) { $parser{'%b'}->(locale => $locale) },

#    %I - 2 digit hour in 12-hour time (eg 11)

    '%I' => fun () { qr"(?<I>[0-9][0-9])"; },

#    %j - 3 digit day of the year (eg 001)

    '%j' => fun () { qr"(?<j>[0-9][0-9][0-9])"; },

#    %k - 1/2 digit hour in 24-hour time (eg 9)

    '%k' => fun () { qr"(?<k>[0-9][0-9]?)"; },

#    %l - 1/2 digit hour in 12-hour time (eg 9)

    '%l' => fun () { qr"(?<l>[0-9][0-9]?)"; },

#    %M - 2 digit minute (eg 45)

    '%M' => fun () { qr"(?<M>[0-9][0-9])"; },

#    %m - 2 digit month (eg 12)

    '%m' => fun () { qr"(?<m>[0-9][0-9])"; },

#    %n - newline - arbitrary whitespace

    '%n' => fun () { qr"\s+"; },

#    %p - national representation of a.m./p.m.

    '%p' => fun (:$locale) {
        my @am_pm = @{ $am_pm{$locale} //= _build_locale(am_pm => $locale) };
        my $re = _list2re(@am_pm);
        return qr"(?<p>$re)";
    },

#    %X - The time, using the locale's time format

    '%X' => fun (:$locale) { $time{$locale} //= _build_locale(time => $locale) },

#    %x - The date, using the locale's date format

    '%x' => fun (:$locale) { $date{$locale} //= _build_locale(date => $locale) },

#    %R - equivalent to %H:%M (eg 22:05)

    '%R' => fun () {
        my $re = sprintf "(?<R>%s:%s)", $parser{'%H'}->(), $parser{'%M'}->();
        return qr"$re";
    },

#    %r - equivalent to %I:%M:%S %p (eg 10:05:00 p.m.)

    '%r' => fun (:$locale) {
        my $re = sprintf "(?<r>%s:%s:%s%s%s)", $parser{'%I'}->(), $parser{'%M'}->(), $parser{'%S'}->(), "\\s+", $parser{'%p'}->(locale => $locale);
        return qr"$re";
    },

#    %S - 2 digit second

    '%S' => fun () { qr"(?<S>[0-9][0-9])"; },

#    %s - 1/2/3/4/5/... digit seconds since epoch (eg 1477629064)

    '%s' => fun () { qr"(?<s>[0-9]+)"; },

#    %T - equivalent to %H:%M:%S

    '%T' => fun () {
        my $re = sprintf "(?<T>%s:%s:%s)", $parser{'%H'}->(), $parser{'%M'}->(), $parser{'%S'}->();
        return qr"$re";
    },

#    %t - tab - arbitrary whitespace

    '%t' => fun () { qr"\s+"; },

#    %U - 2 digit week number of the year Sunday-based week (eg 00)

    '%U' => fun () { qr"(?<U>[0-9][0-9])"; },

#    %u - 1 digit weekday Monday-based week (eg 1)

    '%u' => fun () { qr"(?<u>[0-9])"; },

#    %V - 2 digit week number of the year Monday-based week (eg 01)

    '%V' => fun () { qr"(?<V>[0-9][0-9])"; },

#    %v - equivalent to %e-%b-%Y (eg 9-Jan-2016)

    '%v' => fun (:$locale) {
        my $re = sprintf "(?<v>%s-%s-%s)", $parser{'%e'}->(), $parser{'%b'}->(locale => $locale), $parser{'%Y'}->();
        return qr"$re";
    },

#    %W - 2 digit week number of the year Monday-based week (eg 00)

    '%W' => fun () { qr"(?<W>[0-9][0-9])"; },

#    %w - 1 digit weekday Sunday-based week (eg 0)

    '%w' => fun () { qr"(?<w>[0-9])"; },

#    %Y - 1/2/3/4 digit year including century (eg 2016)

    '%Y' => fun () { qr"(?<Y>[0-9]{1,4})"; },

#    %y - 2 digit year without century (eg 99)

    '%y' => fun () { qr"(?<y>[0-9][0-9])"; },

#    %Z - time zone name (eg CET)

    '%Z' => fun () { qr"(?<Z>\S+)"; },

#    %z - time zone offset from UTC (eg +0100)

    '%z' => fun () { qr"(?<z>[-+][0-9][0-9](?::?[0-9][0-9])?)"; },

#    %% - percent sign

    '%%' => fun () { qr"%"; },

);

fun strptime ($str, $fmt, :$locale = 'C') {
    my $struct = {};

    my $re = _compile_fmt($fmt, locale => $locale);

    warn "fmt re: $re\n" if DEBUG;

    if ($str =~ $re) {
        %$struct = %+;
    } else {
        croak sprintf "Could not match '%s' using '%s'.", $str, $fmt;
    }

    my ($time, $err) = _mktime($struct, locale => $locale);
    croak sprintf "Could not match %s using %s. Invalid time specification: %s.", $str, $fmt, $err
      if defined $err;

    return $time;
}

fun _compile_fmt ($fmt, :$locale) {
    my $re = qr//;

    my $pos = 0;

    # _get_tok will increment $pos for us
    while (defined(my $tok = _get_tok($fmt, $pos))) {
        if (exists $parser{$tok}) {
            my $qr = $parser{$tok}->(locale => $locale);
            $re = qr/$re$qr/;
        } else {
            $re = qr/$re\Q$tok\E/;
        }
    }

    return qr/^$re$/;
}

sub _get_tok {
    my ($fmt, $pos) = @_;

    return undef if $pos >= length $fmt;

    my $tok_len = substr($fmt, $pos, 1) eq '%' ? 2 : 1;

    my $tok = substr $fmt, $pos, $tok_len;
    $_[1] = $pos + $tok_len;
    return $tok;
}

sub _list2re {
    my $re = join '|', map quotemeta, @_;
    qr"$re";
}

fun _mktime ($struct, :$locale) {
    require Time::C;

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
            $month = _get_index($struct->{'B'}, @{ $months{$locale} }) + 1;
        } elsif (defined $struct->{'b'}) {
            $month = _get_index($struct->{'b'}, @{ $months_abbr{$locale} }) + 1;
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
            $wday = _get_index($struct->{'A'}, @{ $weekdays{$locale} }) + 1;
        } elsif (defined $struct->{'a'}) {
            $wday = _get_index($struct->{'a'}, @{ $weekdays_abbr{$locale} }) + 1;
        }
    }

    if (not defined $m_week and defined $s_week and defined $wday) {
        $m_week = $s_week; $m_week-- if $wday == 7;
    }

    # Next try to set up time bits -- these are pretty easy in comparison

    my $hour = $struct->{'H'};
    if (not defined $hour) { $hour = $struct->{'k'}; }
    if (not defined $hour) {
        $hour = $struct->{'I'} // $struct->{'l'};
        if (defined $hour and defined $struct->{'p'}) {
            $hour = _get_index($struct->{'p'}, @{ $am_pm{$locale} }) ? $hour + 12 : $hour;
        }
    }

    my $min = $struct->{'M'};

    my $sec = $struct->{'S'};

    # And last see if we have some timezone or at least offset info

    my $tz = $struct->{'Z'};

    my $offset = $struct->{'z'};

    my $offset_n = defined $offset ? _offset_to_minutes($offset) : undef;

    # Alright, time to try and construct a Time::C object with what we have
    # We'll start with the easiest one: epoch
    # Then go on to creating it from the date bits, and the time bits

    my $t;

    if (defined $epoch) {
        $t = Time::C->gmtime($epoch);

        if (defined $tz) {
            $t->tz = $tz;
        } elsif (defined $offset_n) {
            $t->offset = $offset_n;
        }

        return $t;
    } elsif (defined $year) { # We have a year at least...
        if (defined $month) {
            if (defined $mday) {
                $t = Time::C->new($year, $month, $mday);
            } else {
                $t = Time::C->new($year, $month);
            }
        } elsif (defined $m_week) {
            $t = Time::C->new($year)->week($m_week);
            if (defined $wday) { $t->day_of_week = $wday; }
        } elsif (defined $yday) {
            $t = Time::C->new($year)->day($yday);
        } else { # we have neither month, week, or day of year!
            $t = Time::C->new($year);
        }

        # Now add the time bits on top...
        if (defined $hour) { $t->hour = $hour; }
        if (defined $min) { $t->minute = $min; }
        if (defined $sec) { $t->second = $sec; }
    } else {
        croak 'Could not mktime: no year or epoch specified.';
    }

    # And last, adjust for timezone bits

    if (defined $tz) {
        $t = $t->tz($tz, 1);
    } elsif (defined $offset_n) {
        $t->tm = $t->tm->with_offset_same_local($offset_n);
        $t->offset = $offset_n;
    }

    return $t;
}

fun _offset_to_minutes ($offset) {
    my ($sign, $hours, $minutes) = $offset =~ m/^([+-])([0-9][0-9]):?([0-9][0-9])?$/;
    return $sign eq '+' ? ($hours * 60 + $minutes) : -($hours * 60 + $minutes);
}

fun _get_index ($needle, @haystack) {
    foreach my $i (0 .. $#haystack) {
        return $i if $haystack[$i] eq $needle;
    }
    croak "Could not find $needle in the list.";
}

fun _build_locale ($type, $locale) {
    if ($type eq 'weekdays') {
        $locales{$locale} //= DateTime::Locale->load($locale);
        return $locales{$locale}->day_format_wide;
    } elsif ($type eq 'weekdays_abbr') {
        $locales{$locale} //= DateTime::Locale->load($locale);
        return $locales{$locale}->day_format_abbreviated;
    } elsif ($type eq 'months') {
        $locales{$locale} //= DateTime::Locale->load($locale);
        return $locales{$locale}->month_format_wide;
    } elsif ($type eq 'months_abbr') {
        $locales{$locale} //= DateTime::Locale->load($locale);
        return $locales{$locale}->month_format_abbreviated;
    } elsif ($type eq 'am_pm') {
        return $locales{$locale}->am_pm_abbreviated;
    } elsif ($type eq 'datetime') {
        $loc_db //= do dist_file 'Time-C', 'locale.db';
        return _compile_fmt($loc_db->{d_t_fmt}->{$locale}, $locale);
    } elsif ($type eq 'date') {
        $loc_db //= do dist_file 'Time-C', 'locale.db';
        return _compile_fmt($loc_db->{d_fmt}->{$locale}, $locale);
    } elsif ($type eq 'time') {
        $loc_db //= do dist_file 'Time-C', 'locale.db';
        return _compile_fmt($loc_db->{t_fmt}->{$locale}, $locale);
    } else { croak "Unknown locale type: $type."; }
}

1;

__END__
