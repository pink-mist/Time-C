package Time::P;

use Carp qw/ croak /;
use Exporter qw/ import /;
use Function::Parameters qw/ :strict /;

our @EXPORT = qw/ strptime /;

our @weekdays = qw/ Monday Tuesday Wednesday Thursday Friday Saturday Sunday /;
our @weekdays_abbr = qw/ Mon Tue Wed Thu Fri Sat Sun /;
our @months = qw/ January February March April May June July August September October November December /;
our @months_abbr = qw/ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec /;
our @am_pm = qw/ a.m. p.m. /;

my %parser; %parser = (

#  Support these formats:
#
#    %A - national representation of the full weekday name (eg Monday)

    '%A' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        my $re = _list2re(@weekdays);
        if ($str =~ /\G($re)/) { return $struct->{'%A'} = $1; }
        return undef;
    },

#    %a - national representation of the abbreviated weekday name (eg Mon)

    '%a' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        my $re = _list2re(@weekdays_abbr);
        if ($str =~ /\G($re)/) { return $struct->{'%a'} = $1; }
        return undef;
    },

#    %B - national representation of the full month name (eg January)

    '%B' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        my $re = _list2re(@months);
        if ($str =~ /\G($re)/) { return $struct->{'%B'} = $1; }
        return undef;
    },

#    %b - national representation of the abbreviated month name (eg Jan)

    '%b' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        my $re = _list2re(@months_abbr);
        if ($str =~ /\G($re)/) { return $struct->{'%b'} = $1; }
        return undef;
    },

#    %C - 2 digit century (eg 20)

    '%C' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%C'} = $1; }
        return undef;
    },

#    %D - equivalent to %m/%d/%y (eg 01/31/16)

    '%D' => fun ($str, $pos, $struct) {
        my $m = $parser{'%m'}->($str, $pos, $struct) // return undef;
        $pos += length($m);
        substr($str, $pos, 1) eq '/' or return undef;
        my $d = $parser{'%d'}->($str, ++$pos, $struct) // return undef;
        $pos += length($d);
        substr($str, $pos, 1) eq '/' or return undef;
        my $y = $parser{'%y'}->($str, ++$pos, $struct) // return undef;
        return $struct->{'%D'} = "$m/$d/$y";
    },

#    %d - 2 digit day of month (eg 30)

    '%d' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%d'} = $1; }
        return undef;
    },

#    %e - 1/2 digit day of month (eg 9)

    '%e' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9]?)/) { return $struct->{'%e'} = $1; }
        return undef;
    },

#    %F - equivalent to %Y-%m-%d (eg 2016-01-31)

    '%F' => fun ($str, $pos, $struct) {
        my $Y = $parser{'%Y'}->($str, $pos, $struct) // return undef;
        $pos += length($Y);
        substr($str, $pos, 1) eq '-' or return undef;
        my $m = $parser{'%m'}->($str, ++$pos, $struct) // return undef;
        $pos += length($m);
        substr($str, $pos, 1) eq '-' or return undef;
        my $d = $parser{'%d'}->($str, ++$pos, $struct) // return undef;
        return $struct->{'%F'} = "$Y-$m-$d";
    },

#    %H - 2 digit hour in 24-hour time (eg 23)

    '%H' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%H'} = $1; }
        return undef;
    },

#    %h - equivalent to %b (eg Jan)

    '%h' => fun ($str, $pos, $struct) {
        return $struct->{'%h'} = $parser{'%b'}->($str, $pos, $struct);
    },

#    %I - 2 digit hour in 12-hour time (eg 11)

    '%I' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%I'} = $1; }
        return undef;
    },

#    %j - 3 digit day of the year (eg 001)

    '%j' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9][0-9])/) { return $struct->{'%j'} = $1; }
        return undef;
    },

#    %k - 1/2 digit hour in 24-hour time (eg 9)

    '%k' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9]?)/) { return $struct->{'%k'} = $1; }
        return undef;
    },

#    %l - 1/2 digit hour in 12-hour time (eg 9)

    '%l' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9]?)/) { return $struct->{'%l'} = $1; }
        return undef;
    },

#    %M - 2 digit minute (eg 45)

    '%M' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%M'} = $1; }
        return undef;
    },

#    %m - 2 digit month (eg 12)

    '%m' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%m'} = $1; }
        return undef;
    },

#    %n - newline

    '%n' => fun ($str, $pos, $struct) {
        if (substr($str, $pos, 1) eq "\n") { return "\n"; }
        return undef;
    },

#    %p - national representation of a.m./p.m.

    '%p' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        my $re = _list2re(@am_pm);
        if ($str =~ /\G($re)/) { return $struct->{'%p'} = $1; }
        return undef;
    },

#    %R - equivalent to %H:%M (eg 22:05)

    '%R' => fun ($str, $pos, $struct) {
        my $H = $parser{'%H'}->($str, $pos, $struct) // return undef;
        $pos += length($H);
        substr($str, $pos, 1) eq ':' or return undef;
        my $M = $parser{'%M'}->($str, ++$pos, $struct) // return undef;
        return $struct->{'%R'} = "$H:$M";
    },

#    %r - equivalent to %I:%M:%S %p (eg 10:05:00 p.m.)

    '%r' => fun ($str, $pos, $struct) {
        my $I = $parser{'%I'}->($str, $pos, $struct) // return undef;
        $pos += length($I);
        substr($str, $pos, 1) eq ':' or return undef;
        my $M = $parser{'%M'}->($str, ++$pos, $struct) // return undef;
        $pos += length($M);
        substr($str, $pos, 1) eq ':' or return undef;
        my $S = $parser{'%S'}->($str, ++$pos, $struct) // return undef;
        $pos += length($S);
        substr($str, $pos, 1) eq ' ' or return undef;
        my $p = $parser{'%p'}->($str, ++$pos, $struct) // return undef;
        return $struct->{'%r'} = "$I:$M:$S $p";
    },

#    %S - 2 digit second

    '%S' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%S'} = $1; }
        return undef;
    },

#    %s - 1/2/3/4/5/... digit seconds since epoch (eg 1477629064)

    '%s' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9]+)/) { return $struct->{'%s'} = $1; }
        return undef;
    },

#    %T - equivalent to %H:%M:%S

    '%T' => fun ($str, $pos, $struct) {
        my $H = $parser{'%H'}->($str, $pos, $struct) // return undef;
        $pos += length($H);
        substr($str, $pos, 1) eq ':' or return undef;
        my $M = $parser{'%M'}->($str, ++$pos, $struct) // return undef;
        $pos += length($M);
        substr($str, $pos, 1) eq ':' or return undef;
        my $S = $parser{'%S'}->($str, ++$pos, $struct) // return undef;
        return $struct->{'%T'} = "$H:$M:$S";
    },

#    %t - tab

    '%t' => fun ($str, $pos, $struct) {
        if (substr($str, $pos, 1) eq "\t") { return "\t"; }
        return undef;
    },

#    %U - 2 digit week number of the year Sunday-based week (eg 00)

    '%U' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%U'} = $1; }
        return undef;
    },

#    %u - 1 digit weekday Monday-based week (eg 1)

    '%u' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9])/) { return $struct->{'%u'} = $1; }
        return undef;
    },

#    %V - 2 digit week number of the year Monday-based week (eg 01)

    '%V' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%V'} = $1; }
        return undef;
    },

#    %v - equivalent to %e-%b-%Y (eg 9-Jan-2016)

    '%v' => fun ($str, $pos, $struct) {
        my $e = $parser{'%e'}->($str, $pos, $struct) // return undef;
        $pos += length($e);
        substr($str, $pos, 1) eq '-' or return undef;
        my $b = $parser{'%b'}->($str, ++$pos, $struct) // return undef;
        $pos += length($b);
        substr($str, $pos, 1) eq '-' or return undef;
        my $Y = $parser{'%Y'}->($str, ++$pos, $struct) // return undef;
        return $struct->{'%v'} = "$e-$b-$Y";
    },

#    %W - 2 digit week number of the year Monday-based week (eg 00)

    '%W' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%W'} = $1; }
        return undef;
    },

#    %w - 1 digit weekday Sunday-based week (eg 0)

    '%w' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9])/) { return $struct->{'%w'} = $1; }
        return undef;
    },

#    %Y - 1/2/3/4 digit year including century (eg 2016)

    '%Y' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9]{1,4})/) { return $struct->{'%Y'} = $1; }
        return undef;
    },

#    %y - 2 digit year without century (eg 99)

    '%y' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([0-9][0-9])/) { return $struct->{'%y'} = $1; }
        return undef;
    },

#    %Z - time zone name (eg CET)

    '%Z' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G(\S+)/) { return $struct->{'%Z'} = $1; }
        return undef;
    },

#    %z - time zone offset from UTC (eg +0100)

    '%z' => fun ($str, $pos, $struct) {
        pos($str) = $pos;
        if ($str =~ /\G([-+][0-9][0-9](?::?[0-9][0-9])?)/) { return $struct->{'%z'} = $1; }
        return undef;
    },

#    %% - percent sign

    '%%' => fun ($str, $pos, $struct) {
        if (substr($str, $pos, 1) eq '%') { return '%'; }
        return undef;
    },

);

sub strptime {
    my ($str, $fmt) = @_;

    my $s_pos = my $f_pos = 0;
    my $struct = {};

    while ($s_pos < length $str and $f_pos < length $fmt) {
        my $tok = _get_tok($fmt, $f_pos);

        my $ret;
        if (exists $parser{$tok}) {
            $ret = $parser{$tok}->($str, $s_pos, $struct);
            croak sprintf "Could not match %s using %s. Match failed at position %d.", $str, $fmt, $s_pos
              if not defined $ret;
        } else {
            $ret = substr($str, $s_pos, length($tok));
            croak sprintf "Could not match %s using %s. Match failed at position %d.", $str, $fmt, $s_pos
              if $ret ne $tok;
        }
        $s_pos += length($ret)

    }

    croak sprintf "Could not match %s using %s. Trailing characters at position %d.", $str, $fmt, $s_pos
      if $s_pos < length $str;
    croak sprintf "Could not match %s using %s. Unexpected end of string at position %d.", $str, $fmt, $s_pos
      if $f_pos < length $fmt;

    my ($time, $err) = _mktime($struct);
    croak sprintf "Could not match %s using %s. Invalid time specification: %s.", $str, $fmt, $err
      if defined $err;

    return $time;
}

sub _get_tok {
    my ($fmt, $pos) = @_;

    my $tok_len = substr($fmt, $pos, 1) eq '%' ? 2 : 1;

    my $tok = substr $fmt, $pos, $tok_len;
    $_[1] = $pos + $tok_len;
    return $tok;
}

sub _list2re {
    join '|', map quotemeta, @_;
}

fun _mktime ($struct) {
    require Time::C;

    # First, if we know the epoch, great
    my $epoch = $struct->{'%s'};

    # Then set up as many date bits we know about
    #  year + day of year
    #  year + month + day of month
    #  year + week + day of week

    my $year = $struct->{'%Y'};
    if (not defined $year) {
        if (defined $struct->{'%C'}) {
            $year = $struct->{'%C'} * 100;
            $year += $struct->{'%y'} if defined $struct->{'%y'};
        } elsif (defined $struct->{'%y'}) {
            $year = $struct->{'%y'} + 1900;
            if ($year < (Time::C->now_utc()->year - 50)) { $year += 100; }
        }
    }

    my $yday = $struct->{'%j'};

    my $month = $struct->{'%m'};
    if (not defined $month) {
        if (defined $struct->{'%B'}) {
            $month = _get_index($struct->{'%B'}, @months) + 1;
        } elsif (defined $struct->{'%b'}) {
            $month = _get_index($struct->{'%b'}, @months_abbr) + 1;
        } 
    }

    my $mday = $struct->{'%d'};
    if (not defined $mday) { $mday = $struct->{'%e'}; }

    my $s_week = $struct->{'%U'};
    my $m_week = $struct->{'%W'};

    my $wday = $struct->{'%u'};
    if (not defined $wday) {
        $wday = $struct->{'%w'};
        $wday = 7 if defined $wday and $wday = 0;
    }
    if (not defined $wday) {
        if (defined $struct->{'%A'}) {
            $wday = _get_index($struct->{'%A'}, @weekdays) + 1;
        } elsif (defined $struct->{'%a'}) {
            $wday = _get_index($struct->{'%a'}, @weekdays_abbr) + 1;
        }
    }

    if (not defined $m_week and defined $s_week and defined $wday) {
        $m_week = $s_week; $m_week-- if $wday == 7;
    }

    # Next try to set up time bits -- these are pretty easy in comparison

    my $hour = $struct->{'%H'};
    if (not defined $hour) { $hour = $struct->{'%k'}; }
    if (not defined $hour) {
        $hour = $struct->{'%I'} // $struct->{'%l'};
        if (defined $hour and defined $struct->{'%p'}) {
            $hour = _get_index($struct->{'%p'}, @am_pm) ? $hour + 12 : $hour;
        }
    }

    my $min = $struct->{'%M'};

    my $sec = $struct->{'%S'};

    # And last see if we have some timezone or at least offset info

    my $tz = $struct->{'%Z'};

    my $offset = $struct->{'%z'};

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

1;

__END__
