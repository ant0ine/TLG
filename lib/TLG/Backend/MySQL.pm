package TLG::Backend::MySQL;

use strict;
use DBI;

=head1 DESCRIPTION

OLD IMPLEMENTATION, NEED TO BE REWRITTEN FOR THE BACKEND INTERFACE



Very very very light ORM for TLG. Hopefuly very fast.

Assumes table_name is based on the class name
Assumes (universe_id, id) primary key
Assumes id, universe_id always exist

The object is just the blessed hash representing a row of the table.

YUID not available on 32bits, lets use auto_increment.

TODO: 
- accessors
- way to store non persistant data (currently done with __attributs)

=cut

=head2 get_dbh

Asks the dbh to TLG

=cut

sub get_dbh {
    my $class = shift;
    return TLG->instance->get_dbh($class);
}

=head2 table_name

=cut

sub table_name {
    my $obj_or_class = shift;
    my $class = ref $obj_or_class || $obj_or_class;
    $class =~ s/^.+:://g;
    $class = lc $class;
    return $class;
}

=head2 new

 my $obj = TLG::Resource->new(
     universe => $universe_obj,
     col => value,
     ...,
 );

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $universe = delete $args{'universe'};
    $args{universe_id} ||= $universe->{id} if $universe;
    die 'universe_id required' unless $args{universe_id};
    return bless( \%args, $class);
}

=head2 store

 $obj->store;

=cut

sub store {
    my $self = shift;
    return 1 if $self->{id};
    die 'universe_id missing in the obj' unless $self->{universe_id};

    my @keys;
    my @values;
    for (keys %$self) {
        next if $_ =~ /^__/;
        push @keys, join('=', $_, '?');
        push @values, $self->{$_};
    }
    my $dbh = __PACKAGE__->get_dbh;
    my $query = 'INSERT INTO '.$self->table_name.' SET '.join(', ', @keys);
    TLG->log->debug($query." // ".join(', ', @values));
    my $sth = $dbh->prepare_cached($query);
    my $r = $sth->execute( @values );
    if (!$r) {
        # XXX Hack, FIXME
        die $sth->errstr unless $sth->errstr =~ /Duplicate entry/;
    }
    $self->{id} = $sth->{mysql_insertid} || $sth->{insertid};
    return 1;
}

=head2 load

 my ($obj) = TLG::Resource->load(
     universe => $universe_obj,
     ...,
 );

=cut

sub load {
    my $class = shift;
    my %args = @_;

    my $universe_id = delete $args{universe_id};
    my $universe = delete $args{'universe'};
    $universe_id ||= $universe->{id} if $universe;
    die 'universe_id required' unless $universe_id;

    my @keys = ('universe_id = ?');
    my @values = ($universe_id);
    for (keys %args) {
        next if $_ =~ /^__/;
        my ($op, $value);
        if (ref $args{$_} eq 'HASH') {
            $op = $args{$_}->{op};
            $value = $args{$_}->{value};
        }
        else {
            $op = '=';
            $value = $args{$_};
        }
        push @keys, join($op,$_,'?');
        push @values, $value;
    }
    my $dbh = __PACKAGE__->get_dbh;
    my $query = 'SELECT * FROM '.$class->table_name.' WHERE '.join(' AND ', @keys);
    TLG->log->debug($query." // ".join(', ', @values));
    my $sth = $dbh->prepare_cached($query);
    $sth->execute( @values ) or die $sth->errstr;
    my @result;
    while (my $h = $sth->fetchrow_hashref) {
        push @result, bless($h, $class);
    }

    return @result;
}

=head2 update

 $obj->update(
    col => value,
    ...,
 );

Example: Updating the Literal with an UPDATE SQL request allow us to keep the same ID and thus to not update the Triplet.

=cut

sub update {
    my $self = shift;
    my %args = @_;

    die 'id missing in the obj' unless $self->{id};
    die 'universe_id missing in the obj' unless $self->{universe_id};

    for (keys %args) {

    }

    # SQL query: return the blessed HASH result;
    return 1;
}

=head2 remove

 $obj->remove;

=cut

sub remove {
    my $self = shift;
    #die 'not stored yet' unless $self->{id};
    return 1 unless $self->{id};
    die 'universe_id missing in the obj' unless $self->{universe_id};
    my $dbh = __PACKAGE__->get_dbh;
    my $query = 'DELETE FROM '.$self->table_name.' WHERE id = ? AND universe_id = ? ';
    TLG->log->debug($query." // ".join(', ', $self->{id}, $self->{universe_id}));
    my $sth = $dbh->prepare_cached($query);
    $sth->execute( $self->{id}, $self->{universe_id} ) or die $sth->errstr;
    return 1;
}

=head2 universe

return the universe obj

=cut

sub universe {
    my $self = shift;
}

1;
