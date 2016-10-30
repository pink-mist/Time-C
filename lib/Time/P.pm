package Time::P;

use strict;
use warnings;

use Carp qw/ croak /;
use Exporter qw/ import /;
use Function::Parameters;
use File::Share qw/ dist_file /;
use Data::Munge qw/ list2re slurp /;
use JSON::MaybeXS qw/ decode_json /;

use constant DEBUG => 0;

our @EXPORT = qw/ strptime /;

our $loc_db;

my %parser; %parser = (

#  Support these formats:
#
#    %A - national representation of the full weekday name (eg Monday)

    '%A' => fun (:$locale) {
        my @weekdays = @{ _get_locale(weekdays => $locale) };
        my $re = list2re(@weekdays);
        return qr"(?<A>$re)";
    },

#    %a - national representation of the abbreviated weekday name (eg Mon)

    '%a' => fun (:$locale) {
        my @weekdays_abbr = @{ _get_locale(weekdays_abbr => $locale) };
        my $re = list2re(@weekdays_abbr);
        return qr"(?<a>$re)";
    },

#    %B - national representation of the full month name (eg January)

    '%B' => fun (:$locale) {
        my @months = @{ _get_locale(months => $locale) };
        my $re = list2re(@months);
        return qr"(?<B>$re)";
    },

#    %b - national representation of the abbreviated month name (eg Jan)

    '%b' => fun (:$locale) {
        my @months_abbr = @{ _get_locale(months_abbr => $locale) };
        my $re = list2re(@months_abbr);
        return qr"(?<b>$re)";
    },

#    %C - 2 digit century (eg 20)

    '%C' => fun () { qr"(?<C>[0-9][0-9])"; },

#    #c - The date and time representation for the current locale.

    '%c' => fun (:$locale) { _get_locale(datetime => $locale); },

#    %D - equivalent to %m/%d/%y (eg 01/31/16)

    '%D' => fun () {
        return $parser{'%m'}->(), qr!/!, $parser{'%d'}->(), qr!/!, $parser{'%y'}->();
    },

#    %d - 2 digit day of month (eg 30)

    '%d' => fun () { qr"(?<d>[0-9][0-9])"; },

#    %e - 1/2 digit day of month (eg 9)

    '%e' => fun () { qr"\s?(?<e>[0-9][0-9]?)"; },

#    %F - equivalent to %Y-%m-%d (eg 2016-01-31)

    '%F' => fun () {
        return $parser{'%Y'}->(), qr/-/, $parser{'%m'}->(), qr/-/, $parser{'%d'}->();
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

    '%k' => fun () { qr"\s?(?<k>[0-9][0-9]?)"; },

#    %l - 1/2 digit hour in 12-hour time (eg 9)

    '%l' => fun () { qr"\s?(?<l>[0-9][0-9]?)"; },

#    %M - 2 digit minute (eg 45)

    '%M' => fun () { qr"(?<M>[0-9][0-9])"; },

#    %m - 2 digit month (eg 12)

    '%m' => fun () { qr"(?<m>[0-9][0-9])"; },

#    %n - newline - arbitrary whitespace

    '%n' => fun () { qr"\s+"; },

#    %p - national representation of a.m./p.m.

    '%p' => fun (:$locale) {
        my @am_pm = @{ _get_locale(am_pm => $locale) };
        return () unless @am_pm;
        my $re = list2re(@am_pm);
        return qr"(?<p>$re)";
    },

#    %X - The time, using the locale's time format

    '%X' => fun (:$locale) { _get_locale(time => $locale) },

#    %x - The date, using the locale's date format

    '%x' => fun (:$locale) { _get_locale(date => $locale) },

#    %R - equivalent to %H:%M (eg 22:05)

    '%R' => fun () {
        return $parser{'%H'}->(), qr/:/, $parser{'%M'}->();
    },

#    %r - equivalent to %I:%M:%S %p in POSIX - not in other locales (eg 10:05:00 p.m.)

    '%r' => fun (:$locale) { _get_locale(time_ampm => $locale); },

#    %S - 2 digit second

    '%S' => fun () { qr"(?<S>[0-9][0-9])"; },

#    %s - 1/2/3/4/5/... digit seconds since epoch (eg 1477629064)

    '%s' => fun () { qr"\s*(?<s>[0-9]+)"; },

#    %T - equivalent to %H:%M:%S

    '%T' => fun () {
        return $parser{'%H'}->(), qr/:/, $parser{'%M'}->(), qr/:/, $parser{'%S'}->();
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
        return $parser{'%e'}->(), qr/-/, $parser{'%b'}->(locale => $locale), qr/-/, $parser{'%Y'}->()
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

    my ($sec, $min, $hour, $mday, $month, $year, $wday, $week, $yday, $epoch, $tz, $offset)
      = _parse_struct(\%struct, locale => $locale);
    my $time = mktime($sec, $min, $hour, $mday, $month, $year, $wday, $week, $yday, $epoch, $tz, $offset);

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

    my $offset = $struct->{'z'};

    my $offset_n = defined $offset ? _offset_to_minutes($offset) : undef;

    return ($sec, $min, $hour, $mday, $month, $year, $wday, $m_week, $yday, $epoch, $tz, $offset_n);
}

fun mktime ($sec, $min, $hour, $mday, $month, $year, $wday, $m_week, $yday, $epoch, $tz, $offset) {

    # Alright, time to try and construct a Time::C object with what we have
    # We'll start with the easiest one: epoch
    # Then go on to creating it from the date bits, and the time bits

    my $t;

    if (defined $epoch) {
        $t = Time::C->gmtime($epoch);

        if (defined $tz) {
            $t->tz = $tz;
        } elsif (defined $offset) {
            $t->offset = $offset;
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
            $t = Time::C->new($year)->week($m_week)->day_of_week(1);
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
        # If we don't have a year, let's use the current year
        $year = Time::C->now($tz)->tz('UTC', 1)->year;
        if (defined $month) {
            if (defined $mday) {
                $t = Time::C->new($year, $month, $mday);
            } else {
                $t = Time::C->new($year, $month);
            }

            # Now add the time bits on top...
            if (defined $hour) { $t->hour = $hour; }
            if (defined $min) { $t->minute = $min; }
            if (defined $sec) { $t->second = $sec; }
        } elsif (defined $m_week) {
            $t = Time::C->new($year)->week($m_week)->day_of_week(1);
            if (defined $wday) { $t->day_of_week = $wday; }

            # Now add the time bits on top...
            if (defined $hour) { $t->hour = $hour; }
            if (defined $min) { $t->minute = $min; }
            if (defined $sec) { $t->second = $sec; }
        } elsif (defined $yday) {
            $t = Time::C->new($year)->day($yday);

            # Now add the time bits on top...
            if (defined $hour) { $t->hour = $hour; }
            if (defined $min) { $t->minute = $min; }
            if (defined $sec) { $t->second = $sec; }
        } else {
            # We have neither year, month, week, or day of year ...
            # So let's just make a time for today's date
            $t = Time::C->now($tz)->second_of_day(0)->tz('UTC', 1);

            croak "Could not mktime: No date specified and no time given."
              if not defined $hour and not defined $min and not defined $sec;

            # And add the time bits on top...
            # - if hour not defined, use current hour
            # - if hour and minute not defined, use current minute
            if (defined $hour) { $t->hour = $hour; } else { $t->hour = Time::C->now($tz)->tz('UTC', 1)->hour; }
            if (defined $min) { $t->minute = $min; } elsif (not defined $hour) { $t->second_of_day = Time::C->now($tz)->tz('UTC', 1)->second(0)->second_of_day; }
            if (defined $sec) { $t->second = $sec; }
        }
    }

    # And last, adjust for timezone bits

    if (defined $tz) {
        $t = $t->tz($tz, 1);
    } elsif (defined $offset) {
        $t->tm = $t->tm->with_offset_same_local($offset);
        $t->offset = $offset;
    }

    return $t;
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
