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
    },
};
sub handle_cmd {
    require Dist::Util::Debian;

    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my @rows;
    my @fields = qw(dist deb);

    push @fields, "exists" if $args{check_exists};

    for my $dist (@{ $args{dists} }) {
        my $deb = Dist::Util::Debian::dist2deb($dist);
        my $row = {dist => $dist, deb => $deb};
        if ($args{check_exists}) {
            $row->{exists} = Dist::Util::Debian::deb_exists($deb);
        }
        push @rows, $row;
    }
    [200, "OK", \@rows, {'table.fields' => \@fields}];
}

1;
# ABSTRACT:
