use strict;
use warnings;

use Test::More tests => 14;

use Time::C;

my $t = Time::C->from_string('2016-09-23T04:28:30Z');
isa_ok($t, "Time::C");

is ($t->string, "2016-09-23T04:28:30Z", 'initial time correct');

# 2016-01-01T04:28:30Z
$t->month = $t->day = 1;
is ($t->string, "2016-01-01T04:28:30Z", 'setting month and day to 1 correct');
 
# 2016-01-01T00:00:00Z
$t->hour = $t->minute = $t->second = 0;
is ($t->string, "2016-01-01T00:00:00Z", 'setting hour, minute, second to 0 correct');
 
# 2016-02-04T00:00:00Z
$t->month += 1; $t->day += 3;
is ($t->string, "2016-02-04T00:00:00Z", 'increasing month by 1 and day by 3 correct');
 
# 2016-03-03T00:00:00Z
$t->day += 28;
is ($t->string, "2016-03-03T00:00:00Z", 'increasing day by 28 correct');

# print all days of the week (2016-02-29T00:00:00Z to 2016-03-06T00:00:00Z)
my @days;
$t->day_of_week = 1;
BLOCK: {
    do { push @days, "$t"; last BLOCK if @days > 10; } while $t->day_of_week++ < 7;
}
is (@days, 7, '@days has an entire week');
is ($days[0], "2016-02-29T00:00:00Z", 'first day of week correct');
is ($days[1], "2016-03-01T00:00:00Z", 'second day of week correct');
is ($days[2], "2016-03-02T00:00:00Z", 'third day of week correct');
is ($days[3], "2016-03-03T00:00:00Z", 'fourth day of week correct');
is ($days[4], "2016-03-04T00:00:00Z", 'fifth day of week correct');
is ($days[5], "2016-03-05T00:00:00Z", 'sixth day of week correct');
is ($days[6], "2016-03-06T00:00:00Z", 'seventh day of week correct');
