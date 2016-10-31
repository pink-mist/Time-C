use strict;
use warnings;
package Time::F;

# ABSTRACT: Formatting times.

use Carp qw/ croak /;
use Exporter qw/ import /;
use Function::Parameters qw/ :strict /;

use Time::C::Util qw/ get_fmt_tok get_locale /;

our @EXPORT = qw/ strftime /;

=head1 SYNOPSIS

  use Time::F; # strftime automatically imported
  use Time::C;
  use feature 'say';

  # "mån 31 okt 2016 14:21:57"
  say strftime(Time::C->now_utf(), "%c", locale => "sv_SE");

=head1 DESCRIPTION

Formats a time using L<Time::P/Format Specifiers>, according to specified locale.

=head1 FUNCTIONS

=cut

my %formatter; %formatter = (
    '%A' => fun ($t, $l) { get_locale(weekdays => $l)->[$t->day_of_week() % 7]; },
    '%a' => fun ($t, $l) { get_locale(weekdays_abbr => $l)->[$t->day_of_week() % 7]; },
    '%B' => fun ($t, $l) { get_locale(months => $l)->[$t->month() - 1]; },
    '%b' => fun ($t, $l) { get_locale(months_abbr => $l)->[$t->month() - 1]; },
    '%C' => fun ($t, $l) { sprintf '%02d', substr($t->year, -4, 2) + 0; },
    '%c' => fun ($t, $l) { strftime($t, get_locale(datetime => $l), locale => $l); },
    '%D' => fun ($t, $l) { strftime($t, '%m/%d/%y', locale => $l); },
    '%d' => fun ($t, $l) { sprintf '%02d', $t->day; },
    '%e' => fun ($t, $l) { sprintf '%2d', $t->day; },
    '%F' => fun ($t, $l) { strftime($t, '%Y-%m-%d', locale => $l); },
    '%G' => fun ($t, $l) { ((($t->day_of_year < 7) and ($t->week > 1)) ? $t->year - 1 : $t->year); },
    '%g' => fun ($t, $l) { sprintf ('%02d', ((($t->day_of_year < 7) and ($t->week > 1)) ? substr($t->year - 1, -2) : substr($t->year, -2))); },
    '%H' => fun ($t, $l) { sprintf '%02d', $t->hour; },
    '%h' => fun ($t, $l) { $formatter{'%b'}->($t, $l); },
    '%I' => fun ($t, $l) { my $I = $t->hour % 12; sprintf '%02d', $I ? $I : 12; },
    '%j' => fun ($t, $l) { sprintf '%03d', $t->day_of_year; },
    '%k' => fun ($t, $l) { sprintf '%2d', $t->hour; },
    '%l' => fun ($t, $l) { my $I = $t->hour % 12; sprintf '%2d', $I ? $I : 12; },
    '%M' => fun ($t, $l) { sprintf '%02d', $t->minute; },
    '%m' => fun ($t, $l) { sprintf '%02d', $t->month; },
    '%n' => fun ($t, $l) { "\n"; },
    '%p' => fun ($t, $l) { get_locale(am_pm => $l)->[$t->hour < 12 ? $t->hour < 1 : $t->hour > 12]; },
    '%X' => fun ($t, $l) { strftime($t, get_locale(time => $l), locale => $l); },
    '%x' => fun ($t, $l) { strftime($t, get_locale(date => $l), locale => $l); },
    '%R' => fun ($t, $l) { strftime($t, '%H:%M', locale => $l); },
    '%r' => fun ($t, $l) { strftime($t, get_locale(time_ampm => $l), locale => $l); },
    '%S' => fun ($t, $l) { sprintf '%02d', $t->second; },
    '%s' => fun ($t, $l) { $t->epoch; },
    '%T' => fun ($t, $l) { strftime($t, '%H:%M:%S', locale => $l); },
    '%t' => fun ($t, $l) { "\t"; },
    '%U' => fun ($t, $l) { sprintf '%02d', ($t->day_of_week == 7 ? $t->week + 1 : $t->week); },
    '%u' => fun ($t, $l) { $t->day_of_week; },
    '%V' => fun ($t, $l) { sprintf '%02d', $t->week; },
    '%v' => fun ($t, $l) { strftime($t, '%e-%b-%Y', locale => $l); },
    '%W' => fun ($t, $l) { sprintf '%02d', $t->week; },
    '%w' => fun ($t, $l) { $t->day_of_week == 7 ? 0 : $t->day_of_week; },
    '%Y' => fun ($t, $l) { $t->year; },
    '%y' => fun ($t, $l) { sprintf '%02d', substr $t->year, -2; },
    '%Z' => fun ($t, $l) { $t->tz; },
    '%z' => fun ($t, $l) { my $z = $t->offset; sprintf '%s%02s%02s', ($z > 0 ? '-' : '+'), (($z - ($z % 60)) / 60), ($z % 60); },
    '%%' => fun ($t, $l) { '%'; },
);

=head2 strftime

  my $str = strftime($t, $fmt);
  my $str = strftime($t, $fmt, locale => $locale);

Formats a time using the formats specifiers in C<$fmt>, under the locale rulses of C<$locale>.

=over

=item C<$t>

C<$t> should be a L<Time::C> time object.

=item C<$fmt>

C<$fmt> should be a format specifier string, see L<Time::P/Format Specifiers> for more details.

=item C<< locale => $locale >>

C<$locale> should be a locale. If not specified it defaults to C<C>.

=back

=cut

fun strftime ($t, $fmt, :$locale = 'C') {
    my $str = '';
    my $pos = 0;
    while (defined(my $tok = get_fmt_tok($fmt, $pos))) {
        if (exists $formatter{$tok}) {
            $str .= $formatter{$tok}->($t, $locale);
        } elsif ($tok =~ m/^%/) {
            croak "Unsupported format specifier: $tok"
        } else {
            $str .= $tok;
        }
    }

    return $str;
}

1;

__END__

=head1 SEE ALSO

=over

=item L<Time::P>

=item L<Time::C>

=item L<Time::Moment>

=item L<Time::Piece>

=back

