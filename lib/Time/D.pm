use strict;
use warnings;
package Time::D;

# ABSTRACT: Differentiate between two times

use overload (
    '""' => sub { shift->to_string(2); },
    bool => sub { 1 },
    fallback => 1,
);

use Carp qw/ croak /;
use Function::Parameters qw/ :strict /;
use Time::C;
use Time::C::Sentinel;

=head1 SYNOPSIS

  use Time::D;
  use feature 'say';

  # "1 hour ago"
  say Time::D->new(time, time - 3600)->to_string();

  # "now"
  say Time::D->new(time)->to_string();

  my $d = Time::D->new(time);
  $d->comp(Time::C->from_string("2000-01-01T00:00:00Z"));

  # "16 years, 8 months, 4 weeks, 20 hours, 6 minutes, and 3 seconds ago" (at the time of writing)
  say $d->to_string();

  # "8 months, and 4 weeks ago"
  $d->years = 0;

  # "7 months, and 4 weeks ago"
  $d->months++;

  # "2016-02-01T00:00:00Z"
  say Time::C->gmtime($d->comp)->string;


=head1 DESCRIPTION

Allows you to differentiate between two times, manipulate the difference in various ways, and check what the computed comparison time is.

=cut

=head1 CONSTRUCTORS

=head2 new

  my $d = Time::D->new($base);
  my $d = Time::D->new($base, $comp);

Creates a Time::D object comparing the C<$base> epoch to the C<$comp> epoch.

=over

=item C<$base>

This is the epoch for the base of the comparison.

=item C<$comp>

This is the epoch for the time you want to compare to the base. If omitted, this defaults to the same as C<$base>.

=back

=cut

method new ($c: $base, $comp = $base) {
    bless { base => $base, comp => $comp }, $c;
}

method _setter ($d: $key, $new) {
    return sub {
        $d->{$key} = $_[0];
        return $d if defined $new;
        return $_[0];
    };
}

method _computed_setter ($d: $key, $new) {
    my %diff;
    @diff{qw/ sign year month week day hour minute second /} = $d->to_array();

    my $val = $diff{$key};

    my $ct = Time::C->gmtime($d->comp);
    return $val, sub {
        $ct->$key -= $val - $_[0];
        $d->comp = $ct->epoch;

        return $d if defined $new;
        return $_[0];
    };
}

=head1 ACCESSORS

These accessors will work as C<LVALUE>s, meaning you can assign to them to change the compared times.

=cut

=head2 base

  my $epoch = $d->base;
  $d->base = $epoch;
  $d->base += 3600;
  $d->base++;
  $d->base--;

  $d = $d->base($new_base);

Returns or sets the base epoch. This is the base time that C<< $d->comp >> gets compared against, and is the number of seconds since the system epoch, usually C<1970-01-01T00:00:00Z>.

If the form C<< $d->base($new_base) >> is used, it likewise changes the base epoch but returns the entire object.

=cut

method base ($d: $new_base = undef) :lvalue {
    my $setter = $d->_setter('base', $new_base);

    return $setter->($new_base) if defined $new_base;

    sentinel value => $d->{base}, set => $setter;
}

=head2 comp

  my $epoch = $d->comp;
  $d->comp = $epoch;
  $d->comp -= 3600;
  $d->comp++;
  $d->comp--;

  $d = $d->comp($new_comp);

Returns or sets the comp epoch. This is the time that gets compared to the C<< $d->base >>, and is the number of seconds since the system epoch, usually C<1970-01-01T00:00:00Z>.

If the form C<< $d->comp($new_comp) >> is used, it likewise changes the comp epoch but returns the entire object.

=cut

method comp ($d: $new_comp = undef) :lvalue {
    my $setter = $d->_setter('comp', $new_comp);

    return $setter->($new_comp) if defined $new_comp;

    sentinel value => $d->{comp}, set => $setter;
}

=head2 sign

  my $sign = $d->sign;
  $d->sign = $sign;

  $d = $d->sign($new_sign);

Returns or sets the sign - whether the difference between C<< $d->base >> and C<< $d->comp >> is positive or negative, changing C<< $d->comp >> to either be before the base or after the base. The sign can be either C<+> or C<->.

If the form C<< $d->sign($new_sign) >> is used, it likewise changes the sign but returns the entire object.

=cut

method sign ($d: $new_sign = undef) :lvalue {
    my %diff;
    @diff{qw/ sign year month week day hour minute second /} = $d->to_array();

    my $sign = $diff{sign};

    my $ct = Time::C->gmtime($d->comp);

    my $setter = sub {
        if ($_[0] ne '+' and $_[0] ne '-') { croak "Can't set a sign other than '+' or '-'."; }

        if ($_[0] ne $sign) {
            $ct->year -= (2*$diff{year});
            $ct->month -= (2*$diff{month});
            $ct->week -= (2*$diff{week});
            $ct->day -= (2*$diff{day});
            $ct->hour -= (2*$diff{hour});
            $ct->minute -= (2*$diff{minute});
            $ct->second -= (2*$diff{second});
            $d->comp = $ct->epoch;
        }

        return $d if defined $new_sign;
        return $_[0];
    };

    return $setter->($new_sign) if defined $new_sign;

    sentinel value => $sign, set => $setter;
}

=head2 years

  my $y = $d->years;
  $d->years = $y;
  $d->years += 10;
  $d->years++;
  $d->years--;

  $d = $d->years($new_years);

Returns or sets the difference in years between the C<< $d->base >> and the C<< $d->comp >>. If changed, it changes C<< $d->comp >>.

If the form C<< $d->years($new_years) >> is used, it likewise changes the difference in years but returns the entire object.

=cut

method years ($d: $new_years = undef) :lvalue {
    my ($years, $setter) = $d->_computed_setter('year', $new_years);

    return $setter->($new_years) if defined $new_years;

    sentinel value => $years, set => $setter;
}

=head2 months

  my $m = $d->months;
  $d->months = $m;
  $d->months += 12;
  $d->months++;
  $d->months--;

  $d = $d->months($new_months);

Returns or sets the difference in months between the C<< $d->base >> and the C<< $d->comp >>. If changed, it changes C<< $d->comp >>.

If the form C<< $d->months($new_months) >> is used, it likewise changes the difference in months but returns the entire object.

=cut

method months ($d: $new_months = undef) :lvalue {
    my ($months, $setter) = $d->_computed_setter('month', $new_months);

    return $setter->($new_months) if defined $new_months;

    sentinel value => $months, set => $setter;
}

=head2 weeks

  my $w = $d->weeks;
  $d->weeks = $w;
  $d->weeks += 4;
  $d->weeks++;
  $d->weeks--;

  $d = $d->weeks($new_weeks);

Returns or sets the difference in weeks between the C<< $d->base >> and the C<< $d->comp >>. If changed, it changes C<< $d->comp >>.

If the form C<< $d->weeks($new_weeks) >> is used, it likewise changes the difference in weeks but returns the entire object.

=cut

method weeks ($d: $new_weeks = undef) :lvalue {
    my ($weeks, $setter) = $d->_computed_setter('week', $new_weeks);

    return $setter->($new_weeks) if defined $new_weeks;

    sentinel value => $weeks, set => $setter;
}

=head2 days

  my $days = $d->days;
  $d->days = $days;
  $d->days += 7;
  $d->days++;
  $d->days--;

  $d = $d->days($new_days);

Returns or sets the difference in days between the C<< $d->base >> and the C<< $d->comp >>. If changed, it changes C<< $d->comp >>.

If the form C<< $d->days($new_days) >> is used, it likewise changes the difference in days but returns the entire object.

=cut

method days ($d: $new_days = undef) :lvalue {
    my ($days, $setter) = $d->_computed_setter('day', $new_days);

    return $setter->($new_days) if defined $new_days;

    sentinel value => $days, set => $setter;
}

=head2 hours

  my $h = $d->hours;
  $d->hours = $h;
  $d->hours += 24;
  $d->hours++;
  $d->hours--;

  $d = $d->hours($new_hours);

Returns or sets the difference in hours between the C<< $d->base >> and the C<< $d->comp >>. If changed, it changes C<< $d->comp >>.

If the form C<< $d->hours($new_hours) >> is used, it likewise changes the difference in hours but returns the entire object.

=cut

method hours ($d: $new_hours = undef) :lvalue {
    my ($hours, $setter) = $d->_computed_setter('hour', $new_hours);

    return $setter->($new_hours) if defined $new_hours;

    sentinel value => $hours, set => $setter;
}

=head2 minutes

  my $m = $d->minutes;
  $d->minutes = $m;
  $d->minutes += 60;
  $d->minutes++;
  $d->minutes--;

  $d = $d->minutes($new_minutes);

Returns or sets the difference in minutes between the C<< $d->base >> and the C<< $d->comp >>. If changed, it changes C<< $d->comp >>.

If the form C<< $d->minutes($new_minutes) >> is used, it likewise changes the difference in minutes but returns the entire object.

=cut

method minutes ($d: $new_minutes = undef) :lvalue {
    my ($minutes, $setter) = $d->_computed_setter('minute', $new_minutes);

    return $setter->($new_minutes) if defined $new_minutes;

    sentinel value => $minutes, set => $setter;
}

=head2 seconds

  my $s = $d->seconds;
  $d->seconds = $s;
  $d->seconds += 60;
  $d->seconds++;
  $d->seconds--;

  $d = $d->seconds($new_seconds);

Returns or sets the difference in seconds between the C<< $d->base >> and the C<< $d->comp >>. If changed, it changes C<< $d->comp >>.

If the form C<< $d->seconds($new_seconds) >> is used, it likewise changes the difference in seconds but returns the entire object.

=cut

method seconds ($d: $new_seconds = undef) :lvalue {
    my ($seconds, $setter) = $d->_computed_setter('second', $new_seconds);

    return $setter->($new_seconds) if defined $new_seconds;

    sentinel value => $seconds, set => $setter;
}

=head1 METHODS

=cut

=head2 to_array

  my ($sign, $years, $months, $weeks, $days, $hours, $minutes, $seconds) = $d->to_array();

Returns the difference between C<< $d->base >> and C<< $d->comp >> in the different units. This is different from accessing them via the accessors, because the accessors return the total difference in the specific unit you're asking for, while C<to_array> returns the units with previous units accounted for.

=over

=item C<$sign>

This will be either C<+> or C<->, depending on if C<< $d->comp >> is ahead of or behind C<< $d->base >>.

=item C<$years>

This will be the difference in years.

=item C<$months>

This will be the difference in months after the years have been accounted for.

=item C<$weeks>

This will be the difference in weeks after the years and months have been accounted for.

=item C<$days>

This will be the difference in days after the weeks etc. have been accounted for.

=item C<$hours>

This will be the difference in hours after the days etc. have been accounted for.

=item C<$minutes>

This will be the difference in minutes after the hours etc. have been accounted for.

=item C<$seconds>

This will be the difference in seconds after the minutes etc. have been accounted for.

=back

=cut

method to_array ($d:) {
    my $bt = Time::C->gmtime($d->base);
    my $ct = Time::C->gmtime($d->comp);

    my $years = $bt->tm->delta_years($ct->tm);
    $ct->year -= $years;

    my $months = $bt->tm->delta_months($ct->tm);
    $ct->month -= $months;

    my $weeks = $bt->tm->delta_weeks($ct->tm);
    $ct->week -= $weeks;

    my $days = $bt->tm->delta_days($ct->tm);
    $ct->day -= $days;

    my $hours = $bt->tm->delta_hours($ct->tm);
    $ct->hour -= $hours;

    my $minutes = $bt->tm->delta_minutes($ct->tm);
    $ct->minute -= $minutes;

    my $seconds = $bt->tm->delta_seconds($ct->tm);

    my $sign;

    if    ($years   < 0) { $sign = '-'; } elsif ($years   > 0) { $sign = '+'; }
    elsif ($months  < 0) { $sign = '-'; } elsif ($months  > 0) { $sign = '+'; }
    elsif ($weeks   < 0) { $sign = '-'; } elsif ($weeks   > 0) { $sign = '+'; }
    elsif ($days    < 0) { $sign = '-'; } elsif ($days    > 0) { $sign = '+'; }
    elsif ($hours   < 0) { $sign = '-'; } elsif ($hours   > 0) { $sign = '+'; }
    elsif ($minutes < 0) { $sign = '-'; } elsif ($minutes > 0) { $sign = '+'; }
    elsif ($seconds < 0) { $sign = '-'; } else                 { $sign = '+'; }

    if ($sign eq '-') {
        ($years, $months, $weeks, $days, $hours, $minutes, $seconds) =
          (-$years, -$months, -$weeks, -$days, -$hours, -$minutes, -$seconds);
    }

    return $sign, $years, $months, $weeks, $days, $hours, $minutes, $seconds;
}

fun _plural ($num, $sing, $plur) { sprintf "%s %s", $num, $num == 1 ? $sing : $plur; }

=head2 to_string

  $d->to_string();
  $d->to_string($precision);
  "$d";

Returns the difference as a human readable string. The C<$precision> determines how precise the output will be, and it can range from C<0> to C<7> (though C<0> is pretty useless).

=over

=item C<$precision>

Determines how precise the output should be. The default is 7, which is the maximum precision and will tell you all the differences to the second. For precisions less than the maximum, the results are truncated. No rounding is done.

If you set it to C<0>, there actually won't be enough precision to see a difference at all, so you will get the string C<now> returned.

If you stringified the object, like C<"$d";> for example, the precision will be 2, and only the 2 most significant units of difference will be returned.

This is treated as a maximum, meaning that if the actual difference in the data is less than the given precision, it won't pad with arbitrary 0 units.

=back

The return value will be a string in one of the following forms:

=over

=item

C<now>

=item

C<in %s, [%s, ...], and %s>

=item

C<in %s>

=item

C<%s, [%s, ...], and %s ago>

=item

C<%s ago>

=back

Where the C<%s> will be strings such as:

=over

=item

C<1 year>

=item

C<%d years>

=item

C<1 month>

=item

C<%d months>

=back

... and so on.

=cut

method to_string ($d: $precision = 7) {
    my ($sign, $years, $months, $weeks, $days, $hours, $minutes, $seconds) = 
      $d->to_array();

    my @out;

    if ($precision > 0 and $years)   { $precision--; push @out, _plural($years, 'year', 'years'); }
    if ($precision > 0 and $months)  { $precision--; push @out, _plural($months, 'month', 'months'); }
    if ($precision > 0 and $weeks)   { $precision--; push @out, _plural($weeks, 'week', 'weeks'); }
    if ($precision > 0 and $days)    { $precision--; push @out, _plural($days, 'day', 'days'); }
    if ($precision > 0 and $hours)   { $precision--; push @out, _plural($hours, 'hour', 'hours'); }
    if ($precision > 0 and $minutes) { $precision--; push @out, _plural($minutes, 'minute', 'minutes'); }
    if ($precision > 0 and $seconds) { $precision--; push @out, _plural($seconds, 'second', 'seconds'); }

    return "now" unless @out;

    if (@out > 1) { $out[-1] = "and $out[-1]"; }

    my $pretty = join ", ", @out;

    return sprintf $sign eq '+' ? "in %s" : "%s ago", $pretty;
}

1;

__END__

=head1 SEE ALSO

=over

=item L<Time::C>

The companion to this module, which handles individual times.

=item L<Time::Seconds>

Which doesn't base itself on a specific epoch, so it's ostensibly simpler, but also less able to correctly get differences in months and days.

=item L<Time::Moment>

This is what this module uses internally to calculate the different units.

=item L<Number::Denominal>

Breaks up numbers into arbitrary denominations; deals excellently with durations as well, though it works in the same way as C<Time::Seconds>.

=back

