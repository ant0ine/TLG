package TLG::Cache::Local;

use strict;

use Storable qw( nfreeze thaw );
use Cache::Memory;

=head2 new

=cut

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub client {
    my $self = shift;
    return $self->{client} ||= Cache::Memory->new(
        namespace => 'TLG',
#        default_expires => '600 sec',
    );
}

sub name { 'local' }

=head2 $self->set($obj)

Caches the object in the cache. 

=cut

sub set { 
    my $self = shift;
    my ($key, $record) = @_;
    die 'key required' unless $key;
    die 'record required' unless $record;
    my $frozen = nfreeze($record);
    unless ( defined $self->client->set( $key, $frozen )) {
        TLG->log->debug( sub { $self->_log_string('CACHED ', $key) } );
    }
    else {
        TLG->log->warn( sub { $self->_log_string('ERROR CACHED', $key) } );
    }
}

=head2 $self->get($key)

Tries to get the object from the cache. 

=cut

sub get {
    my $self = shift;
    my ($key) = @_;
    die 'key required' unless $key;
    my $record = $self->client->get($key);
    return unless defined $record;
    TLG->log->debug( sub { $self->_log_string('HIT', $key) } );
    return thaw($record);
}

=head2 $self->del($obj)

=cut

sub del {
    my $self = shift;
    my ($key) = @_;
    die 'key required' unless $key;
    $self->client->remove($key); # TODO error handling
    TLG->log->debug( sub { $self->_log_string('REMOVED', $key) } );
}

sub _log_string {
    my $self = shift;
    my $action = shift;
    my $key = shift;
    return join(' ', $action, 'in the', $self->name, "cache (key=$key)", @_);
}

1;
