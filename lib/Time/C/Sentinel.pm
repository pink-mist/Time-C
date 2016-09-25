use strict;
use warnings;
package Time::C::Sentinel;

use Exporter qw/ import /;

our @EXPORT = qw/ sentinel /;

sub sentinel :lvalue {
    my %args = @_;

    my $value = $args{value};
    my $set   = $args{set};

    tie my $ret, __PACKAGE__, $value, $set;

    return $ret;
}

sub TIESCALAR {
    my ($c, $val, $set) = @_;

    bless { value => $val, set => $set }, $c;
}

sub STORE {
    my ($o, $new) = @_;

    $o->{value} = $o->{set}->($new);
}

sub FETCH { shift->{value}; }

1;
