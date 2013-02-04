package DBIx::q;
$VERSION = v0.0.1;

use warnings;
use strict;
use Carp;

=head1 NAME

DBIx::q - DBI interface to quit quoting queries

=head1 SYNOPSIS

=cut

use DBI;
our @ISA = 'DBI';

=head2 connect

Connect to a DBI database with reasonable defaults and a hash of options.

  my $dbh = DBIx::q->connect($driver => $dbname, %opts);

The first to arguments may be the 'driver' and 'dbname' attributes, or
these may be passed anywhere in the options hash as follows:

Defaults: 
 RaiseError enabled

The following options are supported:

=over

=item driver

=item dbname

=item host

=item username

=item password

=item dbi_options

=back

=cut

sub _connect_opts {
  my $package = shift;
  (@_ % 2) and croak("odd number of elements in argument hash");
  my (%opts) = @_;

  # but rewind for $driver => $dbname, %opts usage
  unless($opts{driver} and $opts{dbname}) {
    my ($driver, $name) = (shift(@_), shift(@_));
    %opts = (driver => $driver, dbname => $name, @_);
  }

  my %config = (
    dbi_options => {},
    %opts,
  );
  if($config{host} and not $config{password}) {
    my $f = $ENV{HOME} . '/.auth/' . $config{host} . '.db.yml';
    open(my $fh, '<', $f) or die "cannot read $f - $!";
    my %x = map({chomp; split(/: /, $_)} <$fh>);
    @config{qw(username password)} = @x{qw(username password)};
  }

  $config{server} = delete($config{host})
    if($config{driver} eq 'Sybase');

  my $dbi_opts = delete($config{dbi_options});
  my $dbuser   = delete($config{username});
  my $dbpass   = delete($config{password});

  croak("no such file '$config{dbname}'")
    if $config{driver} eq 'SQLite' and
      not(-e $config{dbname} or $config{init});

  my $dsn = 'DBI:' . delete($config{driver}) . ':' .
    join(';',
      map({defined($config{$_}) ? "$_=$config{$_}" : ''} keys %config)
    );

  return(
    \%config,
    $dsn, $dbuser, $dbpass,
    {PrintError => 0, RaiseError => 1,
      HandleError => sub {local $Carp::CarpLevel = 1; croak(shift)},
      pg_enable_utf8 => 1, %$dbi_opts}
  );
} # _connect_opts ######################################################

sub connect {
  my $package = shift;
  my ($c, @dbi_args) = $package->_connect_opts(@_);
  my $dbh = $package->SUPER::connect(@dbi_args);
  $c->{init}->($dbh) if $c->{init};
  return $dbh;
} # connect ############################################################

{
package DBIx::q::db;
use warnings; use strict; use Carp;
our @ISA = 'DBI::db';

=head1 Database Handle

=head2 SELECT

  my $sth = $dbh->SELECT(\@fields, FROM => $table, $sql, \@bind);
  $sth->all;

=cut

sub SELECT {
  my $self = shift;
  my (@q) = @_;

  my $bind = pop(@q) if ref($q[-1]);
  my @fields = ref($q[0]) ? do {
    my $f = shift(@q);
    ref($f) eq 'HASH' ? map({"$_ AS $f->{$_}"} keys %$f) : @$f
  } : ('*');

  my $sth = $self->prepare(join(' ', SELECT => join(',', @fields), @q));
  $sth->execute(@$bind);
} # SELECT #############################################################

=head2 INSERT

Insert the given %ROW into $table.  Returns the 'last_insert_id' (except
in void context.)

  $dbh->INSERT($table, %ROW);

=cut

sub INSERT {
  my $self = shift;
  my ($table, %what) = @_;

  my ($k, $v) = ([keys %what], [values %what]);

  $self->do(
    "INSERT INTO $table \(" . join(',', @$k) . "\) " .
      "VALUES \(" . join(',', ('?')x scalar(@$k)) . "\)",
    {},
    @$v
  );
  return unless defined(wantarray);

  return $self->last_insert_id('','',$table,'');
} # INSERT #############################################################

=head2 txn

Execute a given subref within a transaction.  The sub will be invoked
with the database handle object ($dbh) as the first argument.

  $dbh->txn(sub { my $also_dbh = shift; ...});

=cut

sub txn {
  my $self = shift;
  my ($sub) = @_;

  $self->begin_work;
  $sub->($self);
  $self->commit;
} # txn ################################################################

} # package
########################################################################
{
package DBIx::q::st;
use warnings; use strict; use Carp;
our @ISA = 'DBI::st';

=head1 Statement Handle

=head2 execute

  $sth->execute->...

=cut

sub execute {
  my $self = shift;
  # TODO local $Carp::CarpLevel = 1; # XXX maybe
  my $rv = $self->SUPER::execute(@_);
  return $self if(($self->{NUM_OF_FIELDS}||0) > 0); # select
  return $rv;
} # execute ############################################################

=head2 all

Fetch all of the results as hashrefs in a list.

  my @refs = $sth->all;

In scalar context, returns a List::oo arrayref object.  (List::oo must
be loaded elsewhere.)

  use List::oo;
  ...
  $sth->all->map(sub{...})->...

=cut

sub all {
  my $self = shift;

  my $hash_key_name = $self->{FetchHashKeyName} || 'NAME';
  my $names_hash = $self->FETCH("${hash_key_name}_hash");
  my $num_of_fields = $self->FETCH('NUM_OF_FIELDS');

  my $NAME = $self->FETCH($hash_key_name);
  my @row = (undef) x $num_of_fields;
  $self->bind_columns(\(@row));
  my @rows;
  while ($self->fetch) {
    push(@rows, my $ref = {});
    @$ref{@$NAME} = @row;
  }

  return wantarray ? @rows : bless(\@rows, 'List::oo');
} # all ################################################################

} # package
########################################################################

=head1 AUTHOR

Eric Wilhelm @ <ewilhelm at cpan dot org>

http://scratchcomputing.com/

=head1 BUGS

If you found this module on CPAN, please report any bugs or feature
requests through the web interface at L<http://rt.cpan.org>.  I will be
notified, and then you'll automatically be notified of progress on your
bug as I make changes.

If you forked a dev version from git, please contact me directly.

=head1 COPYRIGHT

Copyright (C) 2009-2013 Eric L. Wilhelm, All Rights Reserved.

=head1 NO WARRANTY

Absolutely, positively NO WARRANTY, neither express or implied, is
offered with this software.  You use this software at your own risk.  In
case of loss, no person or entity owes you anything whatsoever.  You
have been warned.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# vi:ts=2:sw=2:et:sta
1;
