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

1;
