use strict;
use warnings;
package Time::R;

# ABSTRACT: Handle recurrences.

use overload (
    '""' => sub { shift->to_string; },
    bool => sub { 1 },
    fallback => 1,
);

use Carp qw/ croak /;
use Time::C;
use Time::C::Sentinel;
use Function::Parameters qw/ :strict /;

=head1 SYNOPSIS

  use Time::C;
  use Time::R;

  my $start = Time::C->new(2016,1,31);
  my $r = Time::R->new($start, months => 1);

  # "2016-02-29T00:00:00Z"
  my $first = $r->next();

  # "2016-03-31T00:00:00Z
  my $second = $r->next();

  # resets $r->next()
  $r->reset();

  # 2016-10-31T00:00:00Z" (depending on current time)
  my $upcoming = $r->upcoming();

  # "2016-09-30T00:00:00Z" (depending on current time)
  my $latest = $r->latest();

  # ("2016-09-30T00:00:00Z", "2016-10-31T00:00:00Z", "2016-11-30T00:00:00Z",
  #  "2016-12-31T00:00:00Z")
  my @dates = $r->until(Time::C->new(2017,1,1));

  # "2017-01-31T00:00:00Z"
  my $next = $r->next();

=head1 DESCRIPTION

Convenient ways of handling recurrences.

=head1 CONSTRUCTORS

=cut

=head2 new

  my $r = Time::R->new($start);
  my $r = Time::R->new($start, end => $end, years => $year, months => $months,
    weeks => $weeks, days => $days, hours => $hours, minutes => $minutes,
    seconds => $seconds);

Creates a Time::R object starting at C<$start>, and optionally ending at C<$end>. Every argument except C<$start> is optional and can be in any order.

=over

=item C<$start>

This should be a L<Time::C> object representing the starting time.

=item C<$end>

This should be a L<Time::C> object optionally specifying the ending time. Defaults to C<undef>.

=item C<$years>

This should be the number of years between each recurrence. Defaults to C<0>.

=item C<$months>

This should be the number of months between each recurrence. Defaults to C<0>.

=item C<$weeks>

This should be the number of weeks between each recurrence. Defaults to C<0>.

=item C<$days>

This should be the number of days between each recurrence. Defaults to C<0>.

=item C<$hours>

This should be the number of hours between each recurrence. Defaults to C<0>.

=item C<$minutes>

This should be the number of minutes between each recurrence. Defaults to C<0>.

=item C<$seconds>

This should be the number of seconds between each recurrence. Defaults to C<0>.

=back

=cut

method new ($c: $start, :$end = undef, :$years = 0, :$months = 0, :$weeks = 0, :$days = 0, :$hours = 0, :$minutes = 0, :$seconds = 0) {
    bless({
        start   => $start,
        end     => $end,
        years   => $years,
        months  => $months,
        weeks   => $weeks,
        days    => $days,
        hours   => $hours,
        minutes => $minutes,
        seconds => $seconds,
    }, $c)->_validate_start($start)->_validate_end($end);
}

method _validate_end ($r: $new_end) {
    if (defined $new_end) {
        croak "->end(): Not a Time::C object: $new_end" unless ref $new_end and $new_end->isa('Time::C');
        croak "->end() time is before ->start() time." if $r->start->epoch > $new_end->epoch;
    }

    return $r;
}

method _validate_start ($r: $new_start) {
    croak "->start(): Not a Time::C object: $new_start" unless ref $new_start and $new_start->isa('Time::C');

    if (defined $r->end and ref $r->end and $r->end->isa('Time::C')) {
        croak "->end() time is before ->start() time." if $new_start->epoch > $r->end->epoch;
    }

    return $r;
}

=head1 ACCESSORS

=cut

=head2 start

  my $start = $r->start;
  $r->start = $start;

  $r = $r->start($new_start);

Returns or sets the L<Time::C> object representing the starting time of the recurrence. Setting this also calls C<< $r->reset() >>.

If the form C<< $r->start($new_start) >> is used, it likewise updates the start but returns the entire object.

=cut

method start ($r: $new_start = undef) {
    my $setter = sub {
        $r->_validate_start($_[0])->{start} = $_[0];

        return $r if defined $new_start;
        return $_[0];
    };

    return $setter->($new_start) if defined $new_start;

    sentinel value => $r->{start}, set => $setter;
}

=head2 current

  my $current = $r->current;
  $r->current = $current;

Returns or sets the L<Time::C> object representing the current time of the current recurrence.

This may get changed by C<< $r->next >>, C<< $r->upcoming >>, C<< $r->latest >>, C<< $r->until >>, and C<< $r->reset >>.

=cut

=head2 end

  my $end = $r->end;
  $r->end = $end;

Returns or sets the L<Time::C> object representing the end time of the recurrence.

=cut

=head2 years

  my $years = $r->years;
  $r->years = $years;
  $r->years += 10;
  $r->years++;
  $r->years--;

Returns or sets the number of years between each recurrence. Setting this also calls C<< $r->reset() >>.

=cut

=head2 months

  my $months = $r->months;
  $r->months = $months;
  $r->months += 12;
  $r->months++;
  $r->months--;

Returns or sets the number of months between each recurrence. Setting this also calls C<< $r->reset() >>.

=cut

=head2 weeks

  my $weeks = $r->weeks;
  $r->weeks = $weeks;
  $r->weeks += 52;
  $r->weeks++;
  $r->weeks--;

Returns or sets the number of weeks between each recurrence. Setting this also calls C<< $r->reset() >>.

=cut

=head2 days

  my $days = $r->days;
  $r->days = $days;
  $r->days += 7;
  $r->days++;
  $r->days--;

Returns or sets the number of days between each recurrence. Setting this also calls C<< $r->reset() >>.

=cut

=head2 hours

  my $hours = $r->hours;
  $r->hours = $hours;
  $r->hours += 24;
  $r->hours++;
  $r->hours--;

Returns or sets the number of hours between each recurrence. Setting this also calls C<< $r->reset() >>.

=cut

=head2 minutes

  my $minutes = $r->minutes;
  $r->minutes = $minutes;
  $r->minutes += 60;
  $r->minutes++;
  $r->minutes--;

Returns or sets the number of minutes between each recurrence. Setting this also calls C<< $r->reset() >>.

=cut

=head2 seconds

  my $seconds = $r->seconds;
  $r->seconds = $seconds;
  $r->seconds += 60;
  $r->seconds++;
  $r->seconds--;

Returns or sets the number of seconds between each recurrence. Setting this also calls C<< $r->reset() >>.

=cut

=head1 METHODS

=cut

=head2 next

  my $next = $r->next();

Sets C<< $r->current >> to and returns the next recurrence as a L<Time::C> object. If the next time would happen after the C<< $r->end >>, it instead returns C<undef> and leaves C<< $r->current >> alone.

=cut

=head2 upcoming

  my $upcoming = $r->upcoming();

Sets C<< $r->current >> to and returns the next time the recurrence occurs as a L<Time::C> object based on the current time. If the next time would happen after the C<< $r->end >>, it instead returns C<undef> and leaves C<< $r->current >> alone.

=cut

=head2 latest

  my $latest = $r->latest();

Sets C<< $r->current >> to and returns the latest time the recurrence occurs as a L<Time::C> object based on the current time.

=cut

=head2 until

  my @until = $r->until($end);

Returns all the recurrences that will happen from C<< $r->current >> until C<$end> (which should be a L<Time::C> object), and updates C<< $r->current >> to the last one returned if any. If C<$end> is after C<< $r->end >> if defined, it will instead use C<< $r->end >> as the limit.

=cut

=head2 reset

  $r->reset();

Resets C<< $r->current >> to C<< $r->start >>.

=cut

method reset ($r:) {
    $r->current = $r->start->clone();
}

1;

__END__

=head1 SEE ALSO

=over

=item L<Time::C>

=item L<Time::D>

=back

