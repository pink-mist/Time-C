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
    croak "Not a Time::C object: $start" unless ref $start and $start->isa('Time::C');
    croak "Not a Time::C object: end => $end" if defined $end and not (ref $end and $end->isa('Time::C'));

    bless {
        start   => $start,
        current => $start->clone(),
        end     => $end,
        years   => $years,
        months  => $months,
        weeks   => $weeks,
        days    => $days,
        hours   => $hours,
        minutes => $minutes,
        seconds => $seconds,
    }, $c;
}

=head1 ACCESSORS

=cut

=head2 start

  my $start = $r->start;
  $r->start = $start;

Returns or sets the L<Time::C> object representing the starting time of the recurrence. Setting this also calls C<< $r->reset() >>.

=cut

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

1;

__END__

=head1 SEE ALSO

=over

=item L<Time::C>

=item L<Time::D>

=back

