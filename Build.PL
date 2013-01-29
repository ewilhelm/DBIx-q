
use strict;
use warnings;
use Module::Build;
my $build_class = 'Module::Build';

my $builder = $build_class->new(
  module_name         => 'DBIx::q',
  license             => 'perl',
  requires => {
  },
  build_requires => {
    'Module::Build' => 0.34,
    'Test::More'    => 0,
  },
  add_to_cleanup      => [ qw(DBIx-q-* META.yml)],
  # create_makefile_pl => 'passthrough',
  meta_merge => {
    resources => {
      homepage =>
        'http://scratchcomputing.com/',
      bugtracker =>
        'http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-q',
      #MailingList => 'mailto:...',
      repository =>
        'http://svn.scratchcomputing.com/DBIx-q/trunk',
    }
  },
);

$builder->create_build_script();

# vi:syntax=perl:ts=2:sw=2:et:sta
