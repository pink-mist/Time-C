use strict;
use warnings;
package Time::C;

# ABSTRACT: Convenient time manipulation.

use overload (
    '""' => sub { shift->string },
    bool => sub { 1 },
    fallback => 1,
);

use Carp qw/ croak /;
use Function::Parameters qw/ :strict /;
use Time::C::Sentinel;
use Time::D;
use Time::Moment;
use Time::Piece ();
use Time::Zone::Olson;

=head1 SYNOPSIS

  use Time::C;

  my $t = Time::C->from_string('2016-09-23T04:28:30Z');

  # 2016-01-01T04:28:30Z
  $t->month = $t->day = 1;

  # 2016-01-01T00:00:00Z
  $t->hour = $t->minute = $t->second = 0;

  # 2016-02-04T00:00:00Z
  $t->month += 1; $t->day += 3;

  # 2016-03-03T00:00:00Z
  $t->day += 28;

  # print all days of the week (2016-02-29T00:00:00Z to 2016-03-06T00:00:00Z)
  $t->day_of_week = 1;
  do { say $t } while ($t->day_of_week++ < 7);

=head1 DESCRIPTION

Makes manipulating time structures more convenient. Internally uses L<Time::Moment>, L<Time::Piece> and L<Time::Zone::Olson>.

=head1 CONSTRUCTORS

=cut

=head2 new

  my $t = Time::C->new();
  my $t = Time::C->new($year);
  my $t = Time::C->new($year, $month);
  my $t = Time::C->new($year, $month, $day);
  my $t = Time::C->new($year, $month, $day, $hour);
  my $t = Time::C->new($year, $month, $day, $hour, $minute);
  my $t = Time::C->new($year, $month, $day, $hour, $minute, $second);
  my $t = Time::C->new($year, $month, $day, $hour, $minute, $second, $tz);

Creates a Time::C object for the specified time, or the current time if no C<$year> is specified.

=over

=item C<$year>

This is the year. If not specified, C<new()> will call C<now_utc()>. The year is 1-based and starts with year 1 corresponding to 1 AD. Legal values are in the range 1-9999.

=item C<$month>

This is the month. If not specified it defaults to C<1>. The month is 1-based and starts with month 1 corresponding to January. Legal values are in the range 1-12.

=item C<$day>

This is the day of the month. If not specified it defaults to C<1>. The day is 1-based and starts with day 1 being the first day of the month. Legal values are in the range 1-31.

=item C<$hour>

This is the hour. If not specified it defaults to C<0>. The hour is 0-based and starts with hour 0 corresponding to midnight. Legal values are in the range 0-23.

=item C<$minute>

This is the minute. If not specified it defaults to C<0>. The minute is 0-based and starts with minute 0 being the first minute of the hour. Legal values are in the range 0-59.

=item C<$second>

This is the second. If not specified it defaults to C<0>. The second is 0-based and starts with second 0 being the first second of the minute. Legal values are in the range 0-59.

=item C<$tz>

This is the timezone specification such as C<Europe/Stockholm> or C<UTC>. If not specified it defaults to C<UTC>.

=back

=cut

method new ($c: $year = undef, $month = 1, $day = 1, $hour = 0, $minute = 0, $second = 0, $tz = 'UTC') {
    return $c->now_utc() if not defined $year;

    my $tm = Time::Moment->new(year => $year, month => $month, day => $day, hour => $hour, minute => $minute, second => $second, offset => 0);

    if ($tz ne 'UTC' and $tz ne 'GMT') {
        my $offset = _get_offset($tm->epoch, $tz);
        $tm = $tm->with_offset_same_local($offset);
        $offset = _get_offset($tm->epoch, $tz);
        $tm = $tm->with_offset_same_local($offset);
    }

    $c->localtime($tm->epoch, $tz);
}

=head2 localtime

  my $t = Time::C->localtime($epoch);
  my $t = Time::C->localtime($epoch, $tz);

Creates a Time::C object for the specified C<$epoch> and optional C<$tz>.

=over

=item C<$epoch>

This is the time in seconds since the system epoch, usually C<1970-01-01T00:00:00Z>.

=item C<$tz>

This is the timezone specification, such as C<Europe/Stockholm> or C<UTC>. If not specified defaults to the timezone specified in C<$ENV{TZ}>, or C<UTC> if that is unspecified.

=back

=cut

method localtime ($c: $epoch, $tz = $ENV{TZ}) {
    $tz = 'UTC' unless defined $tz;
    _verify_tz($tz);
    bless {epoch => $epoch, tz => $tz}, $c;
}

=head2 gmtime

  my $t = Time::C->gmtime($epoch);

Creates a Time::C object for the specified C<$epoch>. The timezone will be C<UTC>.

=over

=item C<$epoch>

This is the time in seconds since the system epoch, usually C<1970-01-01T00:00:00Z>.

=back

=cut

method gmtime ($c: $epoch) { $c->localtime( $epoch, 'UTC' ); }

=head2 now

  my $t = Time::C->now();
  my $t = Time::C->now($tz);

Creates a Time::C object for the current epoch in the timezone specified in C<$tz> or C<$ENV{TZ}> or C<UTC> if the first two are unspecified.

=over

=item C<$tz>

This is the timezone specification, such as C<Europe/Stockholm> or C<UTC>. If not specified defaults to the timezone specified in C<$ENV{TZ}>, or C<UTC> if that is unspecified.

=back

=cut

method now ($c: $tz = $ENV{TZ}) { $c->localtime( time, $tz ); }

=head2 now_utc

  my $t = Time::C->now_utc();

Creates a Time::C object for the current epoch in C<UTC>.

=cut

method now_utc ($c:) { $c->localtime( time, 'UTC' ); }

=head2 from_string

  my $t = Time::C->from_string($str);
  my $t = Time::C->from_string($str, $format);
  my $t = Time::C->from_string($str, $format, $expected_tz);

Creates a Time::C object for the specified C<$str>, using the optional C<$format> to parse it, and the optional C<$expected_tz> to set an unambigous timezone, if it matches the offset the parsing operation gave.

=over

=item C<$str>

This is the string that will be parsed by either L<Time::Piece/strptime> or L<Time::Moment/from_string>.

=item C<$format>

This is the format that L<Time::Piece/strptime> will be given, by default it is C<undef>. If it is not defined, L<Time::Moment/from_string> will be used instead.

=item C<$expected_tz>

If the parsed time contains a zone or offset that parses, and the offset matches the C<$expected_tz> offset, C<$expected_tz> will be set as the timezone. If it doesn't match, a generic timezone matching the offset will be set, such as C<UTC> for an offset of C<0>. This variable will also default to C<UTC>.

=back

=cut

method from_string ($c: $str, $format = undef, $expected_tz = 'UTC') {
    my @p = _parse($str, $format, $expected_tz);

    bless {epoch => $p[0], tz => $p[1]}, $c;
}

fun _verify_tz ($tz) {
    _get_offset(time, $tz);
}

my %tz_offset = (
    -720 => 'Etc/GMT+12',
    -660 => 'Etc/GMT+11',
    -600 => 'Etc/GMT+10',
    -540 => 'Etc/GMT+9',
    -480 => 'Etc/GMT+8',
    -420 => 'Etc/GMT+7',
    -360 => 'Etc/GMT+6',
    -300 => 'Etc/GMT+5',
    -240 => 'Etc/GMT+4',
    -180 => 'Etc/GMT+3',
    -120 => 'Etc/GMT+2',
    -60  => 'Etc/GMT+1',
    0    => 'UTC',
    60   => 'Etc/GMT-1',
    120  => 'Etc/GMT-2',
    180  => 'Etc/GMT-3',
    240  => 'Etc/GMT-4',
    300  => 'Etc/GMT-5',
    360  => 'Etc/GMT-6',
    420  => 'Etc/GMT-7',
    480  => 'Etc/GMT-8',
    540  => 'Etc/GMT-9',
    600  => 'Etc/GMT-10',
    660  => 'Etc/GMT-11',
    720  => 'Etc/GMT-12',
    780  => 'Etc/GMT-13',
    840  => 'Etc/GMT-14',
);

fun _get_tz ($offset) {
    return 'UTC' unless $offset;

    return $tz_offset{$offset} if defined $tz_offset{$offset};

    my $min = $offset % 60;
    my $hour = int $offset / 60;
    my $sign = '+';
    if ($hour < 0) { $sign = '-'; $hour = -$hour; }

    return sprintf "%s%02s:%02s", $sign, $hour, $min;
}

fun _parse ($str, $format = undef, $tz = 'UTC') {
    my $tp;
    $tp = eval { Time::Piece->strptime($str, $format); } if defined $format;
    my $tm = eval { defined $tp ?
        Time::Moment->from_object($tp) :
        Time::Moment->from_string($str);
    };

    croak sprintf "Could not parse %s.", $str if not defined $tm;

    my $epoch = $tm->epoch;
    my $offset = $tm->offset;

    $tz = _get_tz($offset) unless $offset ==
      Time::Zone::Olson->new({timezone => $tz})->local_offset($epoch);

    return $epoch, $tz;
}

=head1 ACCESSORS

These accessors will work as C<LVALUE>s, meaning you can assign to them to change the time being represented.

Note that an assignment expression will return the I<computed> value rather than the assigned value. This means that in the expression C<< my $wday = $t->day_of_week = 8; >> the value assigned to C<$wday> will be C<1> because the value returned from the day_of_week assignment wraps around after 7, and in fact starts the subsequent week. Similarly in the expression C<< my $mday = $t->month(2)->day_of_month = 30; >> the value assigned to C<$mday> will be either C<1> or C<2> depending on if it's a leap year or not, and the month will have changed to C<3>.

=cut

=head2 epoch

  my $epoch = $t->epoch;
  $t->epoch = $epoch;
  $t->epoch += 3600;
  $t->epoch++;
  $t->epoch--;

  $t = $t->epoch($new_epoch);

Returns or sets the epoch, i.e. the number of seconds since C<1970-01-01T00:00:00Z>.

If the form C<< $t->epoch($new_epoch) >> is used, it likewise changes the epoch but returns the entire object.

=cut

method epoch ($t: $new_epoch = undef) :lvalue {
    my $epoch = $t->{epoch};

    my $setter = sub {
        $t->{epoch} = $_[0];
        return $t if defined $new_epoch;
        return $_[0];
    };

    return $setter->($new_epoch) if defined $new_epoch;

    sentinel value => $epoch, set => $setter;
}

=head2 tz

  my $tz = $t->tz;
  $t->tz = $tz;

  $t = $t->tz($new_tz);

Returns or sets the timezone. If the timezone can't be recognised it dies.

If the form C<< $t->tz($new_tz) >> is used, it likewise changes the timezone but returns the entire object.

=cut

method tz ($t: $new_tz = undef) :lvalue {
    my $setter = sub {
        _verify_tz($_[0]);

        $t->{tz} = $_[0];
        return $t if defined $new_tz;
        return $t->{tz};
    };

    return $setter->($new_tz) if defined $new_tz;

    sentinel value => $t->{tz}, set => $setter;
}

fun _get_offset ($epoch, $tz) {
    my $offset = eval { Time::Zone::Olson->new({timezone => $tz})
      ->local_offset($epoch); };

    if (not defined $offset) {
        if ($tz =~ /^([+-])(\d+):(\d+)$/) {
            my ($sign, $hour, $min) = ($1, $2, $3);
            $offset = 60 * $hour + $min;
            $offset = -$offset if $sign eq '-';
        }
    }

    croak sprintf "Unknown timezone %s.", $tz
      if not defined $offset;

    return $offset;
}

=head2 offset

  my $offset = $t->offset;
  $t->offset = $offset;
  $t->offset += 60;

  $t = $t->offset($new_offset);

Returns or sets the current offset in minutes. If the offset is set, it tries to find a generic C<Etc/GMT+X> or C<+XX:XX> timezone that matches the offset and updates the C<tz> to this. If it fails, it dies with an error.

If the form C<< $t->offset($new_offset) >> is used, it likewise sets the timezone from C<$new_offset> but returns the entire object.

=cut

method offset ($t: $new_offset = undef) :lvalue {
    my $setter = sub {
        $t->{tz} = _get_tz($_[0]);

        return $t if defined $new_offset;
        return $_[0];
    };

    return $setter->($new_offset) if defined $new_offset;

    my $offset = _get_offset($t->{epoch}, $t->{tz});

    sentinel value => $offset, set => $setter;
}

=head2 tm

  my $tm = $t->tm;
  $t->tm = $tm;

  $t = $t->tm($new_tm);

Returns a Time::Moment object for the current epoch and offset. On setting, it changes the current epoch.

If the form C<< $t->tm($new_tm) >> is used, it likewise changes the current epoch but returns the entire object.

=cut

method tm ($t: $new_tm = undef) :lvalue {
    $t->{tz} = 'UTC' if not defined $t->{tz};

    my $setter = sub {
        $t->{epoch} = $_[0]->with_offset_same_instant(0)->epoch;

        return $t if defined $new_tm;
        return $_[0];
    };

    return $setter->($new_tm) if defined $new_tm;

    my $tm = Time::Moment->from_epoch($t->{epoch});

    if ($t->{tz} ne 'GMT' and $t->{tz} ne 'UTC') {
        $tm = $tm->with_offset_same_instant($t->offset);
    }

    sentinel value => $tm, set => $setter;
}

=head2 string

  my $str = $t->string;
  my $str = $t->string($format);
  $t->string = $str;
  $t->string($format) = $str;

  $t = $t->string($format, $new_str);

Renders the current time to a string using the optional strftime C<$format>. If the C<$format> is not given it defaults to C<undef>. When setting this value, it tries to parse the string using L<Time::Piece/strptime> with the C<$format> or L<Time::Moment/from_string> if no C<$format> was given or strptime fails. If the detected C<offset> matches the current C<tz>, that is kept, otherwise it will get changed to a generic C<tz> in the form of C<Etc/GMT+X> or C<+XX:XX>.

If the form C<< $t->string($format, $new_str) >> is used, it likewise updates the epoch and timezone but returns the entire object.

=cut

method string ($t: $format = undef, $new_str = undef) :lvalue {
    $t->{tz} = 'UTC' if not defined $t->{tz};

    my $setter = sub {
        @{$t}{epoch,tz} = _parse($_[0], $format, $t->{tz});

        return $t if defined $new_str;
        return $_[0];
    };

    return $setter->($new_str) if defined $new_str;

    my $str;
    if (defined $format) {
        local $ENV{TZ} = $t->{tz};
        my $tp = Time::Piece->localtime($t->{epoch});
        $str = $tp->strftime($format);
    } else {
        $str = Time::Moment->from_epoch($t->{epoch})->with_offset_same_instant($t->offset)->to_string;
    }

    sentinel value => $str, set => $setter;
}

=head2 year

  my $year = $t->year;
  $t->year = $year;
  $t->year += 10;
  $t->year++;
  $t->year--;

  $t = $t->year($new_year);

Returns or sets the current year, updating the epoch accordingly.

If the form C<< $t->year($new_year) >> is used, it likewise sets the current year but returns the entire object.

The year is 1-based where the year 1 corresponds to 1 AD. Legal values are in the range 1-9999.

=cut

method year ($t: $new_year = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->with_year($_[0]))->year;

        return $t if defined $new_year;
        return $ret;
    };

    return $setter->($new_year) if defined $new_year;

    sentinel value => $tm->year, set => $setter;
}

=head2 quarter

  my $quarter = $t->quarter;
  $t->quarter = $quarter;
  $t->quarter += 4;
  $t->quarter++;
  $t->quarter--;

  $t = $t->quarter($new_quarter);

Returns or sets the current quarter of the year, updating the epoch accordingly.

If the form C<< $t->quarter($new_quarter) >> is used, it likewise sets the current quarter but returns the entire object.

The quarter is 1-based where quarter 1 is the first three months of the year. Legal values are in the range 1-4.

=cut

method quarter ($t: $new_quarter = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->plus_months(3*$_[0] - $tm->month))->quarter;

        return $t if defined $new_quarter;
        return $ret;
    };

    return $setter->($new_quarter) if defined $new_quarter;

    sentinel value => $tm->quarter, set => $setter;
}

=head2 month

  my $month = $t->month;
  $t->month = $month;
  $t->month += 12;
  $t->month++;
  $t->month--;

  $t = $t->month($new_month);

Returns or sets the current month of the year, updating the epoch accordingly.

If the form C<< $t->month($new_month) >> is used, it likewise sets the month but returns the entire object.

The month is 1-based where month 1 is January. Legal values are in the range 1-12.

=cut 

method month ($t: $new_month = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->plus_months($_[0] - $tm->month))->month;

        return $t if defined $new_month;
        return $ret;
    };

    return $setter->($new_month) if defined $new_month;

    sentinel value => $tm->month, set => $setter;
}

=head2 week

  my $week = $t->week;
  $t->week = $week;
  $t->week += 4;
  $t->week++;
  $t->week--;

  $t = $t->week($new_week);

Returns or sets the current week or the year, updating the epoch accordingly.

If the form C<< $t->week($new_week) >> is used, it likewise sets the current week but returns the entire object.

The week is 1-based where week 1 is the first week of the year according to ISO 8601. The first week may actually have some days in the previous year, and the last week may have some days in the subsequent year. Legal values are in the range 1-53.

=cut

method week ($t: $new_week = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->plus_weeks($_[0] - $tm->week))->week;

        return $t if defined $new_week;
        return $ret;
    };

    return $setter->($new_week) if defined $new_week;

    sentinel value => $tm->week, set => $setter;
}

=head2 day

  my $day = $t->day;
  $t->day = $day;
  $t->day += 31;
  $t->day++;
  $t->day--;

  $t = $t->day($new_day);

Returns or sets the current day of the month, updating the epoch accordingly.

If the form C<< $t->day($new_day) >> is used, it likewise sets the current day of the month but returns the entire object.

The day is 1-based where day 1 is the first day of the month. Legal values are in the range 1-31.

=cut

method day ($t: $new_day = undef) :lvalue { $t->day_of_month(@_) }

=head2 day_of_month

Functions exactly like C<day>.

=cut

method day_of_month ($t: $new_day = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->plus_days($_[0] - $tm->day_of_month))->day_of_month;

        return $t if defined $new_day;
        return $ret;
    };

    return $setter->($new_day) if defined $new_day;

    sentinel value => $tm->day_of_month, set => $setter;
}

=head2 day_of_year

  my $yday = $t->day_of_year;
  $t->day_of_year = $yday;
  $t->day_of_year += 365;
  $t->day_of_year++;
  $t->day_of_year--;

  $t = $t->day_of_year($new_day);

Returns or sets the current day of the year, updating the epoch accordingly.

If the form C<< $t->day_of_year($new_day) >> is used, it likewise sets the current day of the year but returns the entire object.

The day is 1-based where day 1 is the first day of the year. Legal values are in the range 1-366.

=cut

method day_of_year ($t: $new_day = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->plus_days($_[0] - $tm->day_of_year))->day_of_year;

        return $t if defined $new_day;
        return $ret;
    };

    return $setter->($new_day) if defined $new_day;

    sentinel value => $tm->day_of_year, set => $setter;
}

=head2 day_of_quarter

  my $qday = $t->day_of_quarter;
  $t->day_of_quarter = $qday;
  $t->day_of_quarter += 90;
  $t->day_of_quarter++;
  $t->day_of_quarter--;

  $t = $t->day_of_quarter($new_day);

Returns or sets the current day of the quarter, updating the epoch accordingly.

If the form C<< $t->day_of_quarter($new_day) >> is used, it likewise sets the current day of the quarter but returns the entire object.

The day is 1-based where day 1 is the first day in the first month of the quarter. Legal values are in the range 1-92.

=cut

method day_of_quarter ($t: $new_day = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->plus_days($_[0] - $tm->day_of_quarter))->day_of_quarter;

        return $t if defined $new_day;
        return $ret;
    };

    return $setter->($new_day) if defined $new_day;

    sentinel value => $tm->day_of_quarter, set => $setter;
}

=head2 day_of_week

  my $wday = $t->day_of_week;
  $t->day_of_week = $wday;
  $t->day_of_week += 7;
  $t->day_of_week++;
  $t->day_of_week--;

  $t = $t->day_of_week($new_day);

Returns or sets the current day of the week, updating the epoch accordingly. This module uses L<Time::Moment> which counts days in the week starting from 1 with Monday, and ending on 7 with Sunday.

If the form C<< $t->day_of_week($new_day) >> is used, it likewise sets the current day of the week but returns the entire object.

The day is 1-based where day 1 is Monday. Legal values are in the range 1-7.

=cut

method day_of_week ($t: $new_day = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->plus_days($_[0] - $tm->day_of_week))->day_of_week;

        return $t if defined $new_day;
        return $ret;
    };

    return $setter->($new_day) if defined $new_day;

    sentinel value => $tm->day_of_week, set => $setter;
}

=head2 hour

  my $hour = $t->hour;
  $t->hour = $hour;
  $t->hour += 24;
  $t->hour++;
  $t->hour--;

  $t = $t->hour($new_hour);

Returns or sets the current hour of the day, updating the epoch accordingly.

If the form C<< $t->hour($new_hour) >> is used, it likewise sets the current hour but returns the entire object.

The hour is 0-based where hour 0 is midnight. Legal values are in the range 0-23.

=cut

method hour ($t: $new_hour = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->plus_hours($_[0] - $tm->hour))->hour;

        return $t if defined $new_hour;
        return $ret;
    };

    return $setter->($new_hour) if defined $new_hour;

    sentinel value => $tm->hour, set => $setter;
}

=head2 minute

  my $minute = $t->minute;
  $t->minute = $minute;
  $t->minute += 60;
  $t->minute++;
  $t->minute--;

  $t = $t->minute($new_minute);

Returns or sets the current minute of the hour, updating the epoch accordingly.

If the form C<< $t->minute($new_minute) >> is used, it likewise sets the current minute but returns the entire object.

The minute is 0-based where minute 0 is the first minute of the hour. Legal values are in the range 0-59.

=cut

method minute ($t: $new_minute = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->plus_minutes($_[0] - $tm->minute))->minute;

        return $t if defined $new_minute;
        return $ret;
    };

    return $setter->($new_minute) if defined $new_minute;

    sentinel value => $tm->minute, set => $setter;
}

=head2 second

  my $second = $t->second;
  $t->second = $second;
  $t->second += 60;
  $t->second++;
  $t->second--;

  $t = $t->second($new_second);

Returns or sets the current second of the minute, updating the epoch accordingly.

If the form C<< $t->second($new_second) >> is used, it likewise sets the current second but returns the entire object.

The second is 0-based where second 0 is the first second of the minute. Legal values are in the range 0-59.

=cut

method second ($t: $new_second = undef) :lvalue {
    my $tm = $t->tm();

    my $setter = sub {
        my $ret = ($t->tm = $tm->plus_seconds($_[0] - $tm->second))->second;

        return $t if defined $new_second;
        return $ret;
    };

    return $setter->($new_second) if defined $new_second;

    sentinel value => $tm->second, set => $setter;
}

=head1 METHODS

=cut

=head2 diff

  my $d = $t1->diff($t2);
  my $d = $t1->diff($epoch);

Creates a L<Time::D> object from C<$t1> and C<$t2> or C<$epoch>. It accepts either an arbitrary object that has an C<< ->epoch >> accessor returning an epoch, or a straight epoch.

=cut

method diff ($t: $t2) {
    my $epoch =
      ref $t2 ?
        $t2->can('epoch') ?
          $t2->epoch :
          croak "Object with no ->epoch method passed (". ref $t2 .")." :
        $t2;
    return Time::D->new($t->epoch, $epoch);
}

1;

__END__

=head1 SEE ALSO

=over

=item L<Time::D>

=item L<Time::Moment>

=item L<Time::Piece>

=item L<Time::Zone::Olson>

=back

