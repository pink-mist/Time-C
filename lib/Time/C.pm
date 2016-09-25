use strict;
use warnings;
package Time::C;

# ABSTRACT: Convenient time manipulation.

use overload (
    '""' => sub { shift->string },
    fallback => 1,
);

use Carp qw/ croak /;
use Function::Parameters qw/ :strict /;
use Time::C::Sentinel;
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

This is the year. If not specified, C<new()> will call C<now_utc()>.

=item C<$month>

This is the month. If not specified it defaults to C<1>.

=item C<$day>

This is the day of the month. If not specified it defaults to C<1>.

=item C<$hour>

This is the hour. If not specified it defaults to C<0>.

=item C<$minute>

This is the minute. If not specified it defaults to C<0>.

=item C<$second>

This is the second. If not specified it defaults to C<0>.

=item C<$tz>

This is the timezone specification such as C<Europe/Stockholm> or C<UTC>. If not specified it defaults to C<UTC>.

=back

=cut

method new ($c: $year = undef, $month = 1, $day = 1, $hour = 0, $minute = 0, $second = 0, $tz = 'UTC') {
    return $c->now_utc() if not defined $year;

    my $tm = Time::Moment->new(year => $year, month => $month, day => $day, hour => $hour, minute => $minute, second => $second, offset => 0);

    $c->gmtime($tm->epoch)->tz($tz);
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
    $epoch = _to_utc($epoch, $tz);
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

Creates a Time::C object for the current epoch in the timezone specified in C<$ENV{TZ}> or C<UTC> if that is unspecified.

=cut

method now ($c:) { $c->localtime( time ); }

=head2 now_utc

  my $t = Time::C->now_utc();

Creates a Time::C object for the current epoch in C<UTC>.

=cut

method now_utc ($c:) { $c->localtime( time, 'UTC' ); }

=head2 from_epoch

  my $t = Time::C->from_epoch($epoch);

Creates a Time::C object for the specified C<$epoch>. The timezone will be C<UTC>.

=over

=item C<$epoch>

This is the time in seconds since the system epoch, usually C<1970-01-01T00:00:00Z>.

=back

=cut

method from_epoch ($c: $epoch) { $c->localtime( $epoch, 'UTC' ); }

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

fun _to_utc ($epoch, $from) {
    return $epoch if (not defined $from or $from eq 'UTC' or $from eq 'GMT');

    my $offset = eval {
      Time::Zone::Olson->new({timezone => $from})->local_offset($epoch); };

    croak sprintf "Unknown timezone %s.", $from if not defined $offset;

    return $epoch + $offset * 60;
}

fun _from_utc ($epoch, $to) {
    return $epoch if (not defined $to or $to eq 'UTC' or $to eq 'GMT');

    my $offset = Time::Zone::Olson->new({timezone => $to})->local_offset($epoch);
    return $epoch - $offset * 60;
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

=cut

=head2 epoch

  my $epoch = $t->epoch;
  $t->epoch = $epoch;
  $t->epoch += 3600;
  $t->epoch++;
  $t->epoch--;

Returns or sets the epoch according to the specified timezone.

=cut

method epoch ($t:) :lvalue {
    my $epoch = _from_utc($t->{epoch}, $t->{tz});

    sentinel value => $epoch, set =>
      sub { $t->{epoch} = _to_utc($_[0], $t->{tz}); $_[0]; };
}

=head2 tz

  my $tz = $t->tz;
  $t->tz = $tz;

  $t = $t->tz($new_tz);

Returns or sets the timezone. If the timezone can't be recognised it dies.

If the form C<< $t->tz($new_tz) >> is used, it instead changes the internal tz and returns the entire object.

=cut

method tz ($t: $new_tz = undef) :lvalue {
    my $setter = sub {
        unless (
          $_[0] =~ /^([+-])(\d+):(\d+)$/ and 
          (($1 eq '+' and $2 < 14 and $3 < 60) or
          ($1 eq '-' and $2 < 12 and $3 < 60))) {
            croak sprintf "Unknown timezone: %s", $_[0]
              unless eval { Time::Zone::Olson->new({timezone => $_[0]}); 1; };
        }

        $t->{tz} = $_[0];
        return $t if defined $new_tz;
        return $t->{tz};
    };

    return $setter->($new_tz) if defined $new_tz;

    sentinel value => $t->{tz}, set => $setter;
}

=head2 offset

  my $offset = $t->offset;
  $t->offset = $offset;
  $t->offset += 60;

Returns or sets the current offset in minutes. If the offset is set, it tries to find a generic C<Etc/GMT+X> or C<+XX:XX> timezone that matches the offset and updates the C<tz> to this. If it fails, it dies with an error.

=cut

method offset ($t:) :lvalue {
    my $offset = eval { Time::Zone::Olson->new({timezone => $t->{tz}})
      ->local_offset($t->{epoch}); };

    if (not defined $offset) {
        if ($t->{tz} =~ /^([+-])(\d+):(\d+)$/) {
            my ($sign, $hour, $min) = ($1, $2, $3);
            $offset = 60 * $hour + $min;
            $offset = -$offset if $sign eq '-';
        }
    }

    croak sprintf "Invalid timezone %s set. Can't find offset.", $t->{tz}
      if not defined $offset;

    sentinel value => $offset, set =>
      sub { $t->{tz} = _get_tz($_[0]); $_[0]; };
}

=head2 tm

  my $tm = $t->tm;
  $t->tm = $tm;

Returns a Time::Moment object for the current epoch and offset. On setting, it changes the current epoch.

=cut

method tm ($t:) :lvalue {
    $t->{tz} = 'UTC' if not defined $t->{tz};

    my $tm = Time::Moment->from_epoch($t->{epoch});

    if ($t->{tz} ne 'GMT' and $t->{tz} ne 'UTC') {
        $tm = $tm->with_offset_same_instant($t->offset);
    }

    sentinel value => $tm, set =>
      sub { $t->{epoch} = $_[0]->with_offset_same_instant(0)->epoch; $_[0]; };
}

=head2 string

  my $str = $t->string;
  my $str = $t->string($format);
  $t->string = $str;
  $t->string($format) = $str;

Renders the current time to a string using the optional strftime C<$format>. If the C<$format> is not given it defaults to C<undef>. When setting this value, it tries to parse the string using L<Time::Piece/strptime> with the C<$format> or L<Time::Moment/from_string> if no C<$format> was given or strptime fails. If the detected C<offset> matches the current C<tz>, that is kept, otherwise it will get changed to a generic C<tz> in the form of C<Etc/GMT+X> or C<+XX:XX>.

=cut

method string ($t: $format = undef) :lvalue {
    $t->{tz} = 'UTC' if not defined $t->{tz};

    my $str;
    if (defined $format) {
        local $ENV{TZ} = $t->{tz};
        my $tp = Time::Piece->localtime($t->{epoch});
        $str = $tp->strftime($format);
    } else {
        $str = Time::Moment->from_epoch($t->{epoch})->with_offset_same_instant($t->offset)->to_string;
    }

    sentinel value => $str, set =>
      sub { @{$t}{epoch,tz} = _parse($_[0], $format, $t->{tz}); $_[0]; }
}

=head2 year

  my $year = $t->year;
  $t->year = $year;
  $t->year += 10;
  $t->year++;
  $t->year--;

Returns or sets the current year, updating the epoch accordingly.

=cut

method year ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->year, set =>
      sub {
          my $ret = ($t->tm = $tm->with_year($_[0]))->year;
      };
}

=head2 quarter

  my $quarter = $t->quarter;
  $t->quarter = $quarter;
  $t->quarter += 4;
  $t->quarter++;
  $t->quarter--;

Returns or sets the current quarter of the year, updating the epoch accordingly.

=cut

method quarter ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->quarter, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_months(3*$_[0] - $tm->month))->quarter;
      };
}

=head2 month

  my $month = $t->month;
  $t->month = $month;
  $t->month += 12;
  $t->month++;
  $t->month--;

Returns or sets the current month of the year, updating the epoch accordingly.

=cut 

method month ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->month, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_months($_[0] - $tm->month))->month;
      };
}

=head2 week

  my $week = $t->week;
  $t->week = $week;
  $t->week += 4;
  $t->week++;
  $t->week--;

Returns or sets the current week or the year, updating the epoch accordingly.

=cut

method week ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->week, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_weeks($_[0] - $tm->week))->week;
      };
}

=head2 day

  my $day = $t->day;
  $t->day = $day;
  $t->day += 31;
  $t->day++;
  $t->day--;

Returns or sets the current day of the month, updating the epoch accordingly.

=cut

method day ($t:) :lvalue { $t->day_of_month }

=head2 day_of_month

Functions exactly like C<day>.

=cut

method day_of_month ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->day_of_month, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_days($_[0] - $tm->day_of_month))->day_of_month;
      };
}

=head2 day_of_year

  my $yday = $t->day_of_year;
  $t->day_of_year = $yday;
  $t->day_of_year += 365;
  $t->day_of_year++;
  $t->day_of_year--;

Returns or sets the current day of the month, updating the epoch accordingly.

=cut

method day_of_year ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->day_of_year, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_days($_[0] - $tm->day_of_year))->day_of_year;
      };
}

=head2 day_of_quarter

  my $qday = $t->day_of_quarter;
  $t->day_of_quarter = $qday;
  $t->day_of_quarter += 90;
  $t->day_of_quarter++;
  $t->day_of_quarter--;

Returns or sets the current day of the quarter, updating the epoch accordingly.

=cut

method day_of_quarter ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->day_of_quarter, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_days($_[0] - $tm->day_of_quarter))->day_of_quarter;
      };
}

=head2 day_of_week

  my $wday = $t->day_of_week;
  $t->day_of_week = $wday;
  $t->day_of_week += 7;
  $t->day_of_week++;
  $t->day_of_week--;

Returns or sets the current day of the week, updating the epoch accordingly. This module uses L<Time::Moment> which counts days in the week starting from 1 with Monday, and ending on 7 with Sunday.

=cut

method day_of_week ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->day_of_week, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_days($_[0] - $tm->day_of_week))->day_of_week;
      };
}

=head2 hour

  my $hour = $t->hour;
  $t->hour = $hour;
  $t->hour += 24;
  $t->hour++;
  $t->hour--;

Returns or sets the current hour of the day, updating the epoch accordingly.

=cut

method hour ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->hour, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_hours($_[0] - $tm->hour))->hour;
      };
}

=head2 minute

  my $minute = $t->minute;
  $t->minute = $minute;
  $t->minute += 60;
  $t->minute++;
  $t->minute--;

Returns or sets the current minute of the hour, updating the epoch accordingly.

=cut

method minute ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->minute, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_minutes($_[0] - $tm->minute))->minute;
      };
}

=head2 second

  my $second = $t->second;
  $t->second = $second;
  $t->second += 60;
  $t->second++;
  $t->second--;

Returns or sets the current second of the minute, updating the epoch accordingly.

=cut

method second ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->second, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_seconds($_[0] - $tm->second))->second;
      };
}

=head2 millisecond

  my $msec = $t->millisecond;
  $t->millisecond = $msec;
  $t->millisecond += 1000;
  $t->millisecond++;
  $t->millisecond--;

Returns or sets the current millisecond of the second, updating the epoch accordingly.

=cut

method millisecond ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->millisecond, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_milliseconds($_[0] - $tm->millisecond))->millisecond;
      };
}

=head2 microsecond

  use utf8;
  my $µsec = $t->microsecond;
  $t->microsecond = $µsec;
  $t->microsecond += 1_000_000;
  $t->microsecond++;
  $t->microsecond--;

Returns or sets the current microsecond of the second, updating the epoch accordingly.

=cut

method microsecond ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->microsecond, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_microseconds($_[0] - $tm->microsecond))->microsecond;
      };
}

=head2 nanosecond

  my $nsec = $t->nanosecond;
  $t->nanosecond = $nsec;
  $t->nanosecond += 1_000_000_000;
  $t->nanosecond++;
  $t->nanosecond--;

Returns or sets the current nanosecond of the second, updating the epoch accordingly.

=cut

method nanosecond ($t:) :lvalue {
    my $tm = $t->tm();

    sentinel value => $tm->nanosecond, set =>
      sub {
          my $ret = ($t->tm = $tm->plus_nanoseconds($_[0] - $tm->nanosecond))->nanosecond;
      };
}

1;

__END__

=head1 SEE ALSO

=over

=item L<Time::Moment>

=item L<Time::Piece>

=item L<Time::Zone::Olson>

=back

