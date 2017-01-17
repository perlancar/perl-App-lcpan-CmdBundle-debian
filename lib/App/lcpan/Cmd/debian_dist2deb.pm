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
    summary => 'Show Debian package name/version for a dist',
    description => <<'_',

This routine uses the simple rule of: converting the dist name to lowercase then
add "lib" prefix and "-perl" suffix. A small percentage of Perl distributions do
not follow this rule.

_
    args => {
        %App::lcpan::common_args,
        %App::lcpan::dists_args,
        check_exists_on_debian => {
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
        exists_on_debian => {
            summary => 'Only output debs which exist on Debian repository',
            'summary.alt.bool.neg' => 'Only output debs which do not exist on Debian repository',
            schema => 'bool*',
            tags => ['category:filtering'],
        },
        exists_on_cpan => {
            summary => 'Only output debs which exist in database',
            'summary.alt.bool.neg' => 'Only output debs which do not exist in database',
            schema => 'bool*',
            tags => ['category:filtering'],
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

    {
        push @fields, "dist_version";
        my $sth = $dbh->prepare(
            "SELECT name,version FROM dist WHERE is_latest AND name IN (".
                join(",", map { $dbh->quote($_) } @{ $args{dists} }).")");
        $sth->execute;
        my %versions;
        while (my $row = $sth->fetchrow_hashref) {
            $versions{$row->{name}} = $row->{version};
        }
        for (0..$#rows) {
            $rows[$_]{dist_version} = $versions{$rows[$_]{dist}};
        }
        if (defined $args{exists_on_cpan}) {
            @rows = grep { !(defined $_->{dist_version} xor $args{exists_on_cpan}) } @rows;
        }
    }

    if ($args{check_exists_on_debian} || defined $args{exists_on_debian}) {
        push @fields, "deb_version";
        my $opts = {};
        $opts->{use_allpackages} = 1 if $args{use_allpackages} // $args{exists};

        my @res = Dist::Util::Debian::deb_ver($opts, map {$_->{deb}} @rows);
        for (0..$#rows) { $rows[$_]{deb_version} = $res[$_] }
        if (defined $args{exists_on_debian}) {
            @rows = grep { !(defined $_->{deb_version} xor $args{exists_on_debian}) } @rows;
        }
    }

    [200, "OK", \@rows, {'table.fields' => \@fields}];
}

1;
# ABSTRACT:
