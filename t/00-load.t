
use warnings;
use strict;

use Test::More tests => 1;

my $package = 'DBIx::q';
use_ok('DBIx::q') or BAIL_OUT('cannot load DBIx::q');

eval {require version};
diag("Testing $package ", $package->VERSION );

# vim:syntax=perl:ts=2:sw=2:et:sta
