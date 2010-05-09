package TLG::Entity;

use strict;
use warnings;

use TLG::LockSet;
use TLG::Unmutable;

=head1 DESCRIPTION

Abstract base class for Triplet, Resource, Predicat, Literal

=cut

=head2 new

Generates the key from the args, and return the object.

=cut

sub new {
    my $class = shift;
    my ($args, $ls) = @_;
    $args->{key} = $class->generate_key($args);
    my $self = bless $args, $class;
    $ls->get_lock($self->lock_key)
        if $ls && !TLG::Unmutable->is_unmutable(entity => $self);
    return $self;
}

=head2 $class->generate_key($args);

Same args as new($args)

=cut

sub generate_key  { die 'must be redefined'; }

sub key { $_[0]->{key} }

sub lock_key {
    my $class = shift;
    my ($key) = @_;
    $key = $class->key if ref $class;
    die 'no key' unless $key;
    return join('-', $key, $class->role),
}

=head2 to_record

Extracts the field to store from the object.

=cut

sub to_record {
    my $class = shift;
    my ($args) = @_;
    $args = $class if ref $class;
    my $record = {};
    my @cols = grep { $_ !~ /^__/ && $_ ne 'key' } keys %$args;
    $record->{$_} = $args->{$_} for @cols;
    return $record;
}

=head2 from_record

Build the object from the record

=cut

sub from_record {
    my $class = shift;
    my ($key, $record) = @_;
    $class = ref $class if ref $class;
    return bless {
        %$record,
        key => $key,
        __stored => 1,
    }, $class;
}

=head2 role

=cut

# TODO remove and use directly $class

sub role {
    my $class = shift;
    $class = ref $class if ref $class;
    $class =~ s/.*:://;
    return lc $class;
}

sub cache_driver {
    my $class = shift;
    $class = ref $class if ref $class;
    my $u = TLG->current_universe;
    my $role = $class->role;
    return $u->cache_driver($role);
}

sub backend_driver {
    my $class = shift;
    $class = ref $class if ref $class;
    my $u = TLG->current_universe;
    my $role = $class->role;
    return $u->backend_driver($role);
}

=head2 $self->cache_enabled

Or $class->cache_enabled

=cut

# TODO should be in the conf, just check if there is no defined cache driver

sub cache_enabled {
    my $class = shift;
    $class = ref $class if ref $class;
    return eval '$'.$class.'::CACHE';
}

=head2 is_stored

TODO Explain the difference with "exists"

=cut

sub is_stored { $_[0]->{__stored} }

=head2 exists

Returns true if the entity already exists in the triplestore.

=cut

sub exists {
    my $self = shift;
    return $self if $self->is_stored;

    if ($self->cache_enabled) {
        if (my $record = $self->cache_driver->get($self->key)) {
            return $self->from_record($self->key, $record);
        }
    }

    if (my $record = $self->backend_driver->get($self->key)) {
        # cache miss, fill it
        $self->cache_driver->set($self->key, $record) if $self->cache_enabled;
        return $self->from_record($self->key, $record);
    }
    
    return;
}

=head2 load

Creates the object using new, but then checks if it exists in the store, returns undef if not.

=cut

sub load {
    my $class = shift;
    my $obj = $class->new(@_);
    return $obj->exists;
}

=head2 load_by_key

Queries the cache, then the backend.

=cut

sub load_by_key {
    my $class = shift;
    my ($key, $ls) = @_;
    die 'key required' unless $key;
    $ls->get_lock($class->lock_key($key))
        if $ls && !TLG::Unmutable->is_unmutable(lock_key => $class->lock_key($key));

    if ($class->cache_enabled) {
        if (my $record = $class->cache_driver->get($key)) {
            return $class->from_record($key, $record);
        }
    }
    
    if (my $record = $class->backend_driver->get($key)) {
        # cache miss, fill it
        $class->cache_driver->set($key, $record)
            if $class->cache_enabled && $ls;
        return $class->from_record($key, $record);
    }
    
    return;
}


=head2 store

Returns 1 if already stored. Otherwise, stores in Tokyo and then caches it.

=cut

sub store {
    my $self = shift;
    return 1 if $self->is_stored;
    $self->{__stored}++;
    eval {
        $self->backend_driver->set($self->key, $self->to_record);
    };
    if ($@) {
        $self->cache_driver->del($self->key) if $self->cache_enabled;
        die $@;
    }
    else {
        $self->cache_driver->set($self->key, $self->to_record) if $self->cache_enabled;
    }
    return 1;
}

=head2 remove

=cut

sub remove {
    my $self = shift;
    return 1 if TLG::Unmutable->is_unmutable(entity => $self);
    $self->cache_driver->del($self->key) if $self->cache_enabled;
    $self->backend_driver->del($self->key);
    delete $self->{__stored};
    return 1;
}

=head2 trash

=cut

sub trash {
    my $self = shift;
    return TLG->current_universe->get_counter_client->inc(
        join('-', $self->key, $self->role)
    );
}

=head2 query

=cut

# cannot use this because we need to lock early
#sub query {
#    my $class = shift;
#    my ($args, $ls) = @_;
#    my $res = $class->backend_driver->query($args);
#    return [ map {
#        my $key = delete $_->{''};
#        my $self = $class->from_record($key, $_);
#        $ls->get_lock($class->lock_key($key)) if $ls; # TODO eval ?
#        return $self;
#    } @$res ];
#}


sub query {
    my $class = shift;
    my ($args, $ls) = @_;
    my $res = $class->backend_driver->query_key($args);
    return [ map {
        $class->load_by_key($_, $ls)
    } @$res ];
}

=head2 query_count

=cut

sub query_count {
    my $class = shift;
    my ($args) = @_;
    return $class->backend_driver->query_count($args);
}

=head2 query_field

=cut

sub query_field {
    my $class = shift;
    my ($args, $field) = @_;
    return $class->backend_driver->query_field($args, $field);
}

=head2 query_key

=cut

sub query_key {
    my $class = shift;
    my ($args) = @_;
    return $class->backend_driver->query_key($args);
}

1;
