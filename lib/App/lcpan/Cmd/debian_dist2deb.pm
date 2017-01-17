package App::lcpan::Cmd::debian_dist2deb;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

require App::lcpan;

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'Convert dist name to Debian package name',
    description => <<'_',

This routine uses the simple rule of: converting the dist name to lowercase then
add "lib" prefix and "-perl" suffix. A small percentage of Perl distributions do
not follow this rule.

_
    args => {
        %App::lcpan::common_args,
        %App::lcpan::dists_args,
        check_exists => {
            summary => 'Check each distribution if its Debian package exists, using Dist::Util::Debian::dist_has_deb',
            schema => 'bool*',
        },
        use_allpackages => {
            summary => 'Will be passed to Dist::Util::Debian::dist_has_deb',
            description => <<'_',

Using this option is faster if you need to check existence for many Debian
packages. See <pm:Dist::Util::Debian> documentation for more details.

_
            schema => 'bool*',
        },
    },
};
sub handle_cmd {
    require Dist::Util::Debian;

    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my @rows;
    my @fields = qw(dist deb);

    for my $dist (@{ $args{dists} }) {
        my $deb = Dist::Util::Debian::dist2deb($dist);
        my $row = {dist => $dist, deb => $deb};
        push @rows, $row;
    }

    if ($args{check_exists}) {
        push @fields, "exists" if $args{check_exists};
        my $opts = {};
        $opts->{use_allpackages} = 1 if $args{use_allpackages};

        my @res = Dist::Util::Debian::deb_exists($opts, map {$_->{deb}} @rows);
        for (0..$#rows) { $rows[$_]{exists} = $res[$_] }
    }

    [200, "OK", \@rows, {'table.fields' => \@fields}];
}

1;
# ABSTRACT:
