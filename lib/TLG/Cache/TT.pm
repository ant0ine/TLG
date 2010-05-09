package TLG::Cache::TT;

use strict;
use warnings;

use Storable qw( nfreeze thaw );
use TokyoTyrantx::Instance;

use constant RDB_TRY => 3;

=head2 new

=cut

sub new {
    my $class = shift;
    my ($name, $args) = @_;
    my $self = bless {
        name => $name,
        args => $args,
    }, $class;
    return $self;
}

sub client {
    my $self = shift;
    return $self->{client} ||= TokyoTyrantx::Instance->new( $self->name => $self->args )->get_rdb;
}

sub name { $_[0]->{name} }

sub args { $_[0]->{args} }

=head2 $self->set($key, $record)

=cut

sub set {
    my $self = shift;
    my ($key, $record) = @_;
    die 'key required' unless $key;
    die 'record required' unless $record;
    my $frozen = nfreeze($record);
    my $rdb = $self->client;
    for my $try (1..RDB_TRY()) { 
        if ($rdb->put( $key, $frozen )) {
            TLG->log->debug(sub { $self->_log_string('CACHED', $key) });
            last;
        }
        else {
            if ($rdb->ecode == $rdb->ERECV && $try < RDB_TRY()) {
                TLG->log->warn(sub { $self->_log_string('WARNING CACHED', $key, $rdb->errmsg($rdb->ecode), "RETRYING ($try)") });
            }
            else {
                die $self->_log_string('"ERROR CACHED', $key, $rdb->errmsg($rdb->ecode));
            }
        }
    }
}

=head2 $record = $self->get($key) 

=cut

sub get {
    my $self = shift;
    my ($key) = @_;
    die 'key required' unless $key;
    my $record = $self->client->get($key);
    return unless defined $record;
    TLG->log->debug(sub { $self->_log_string('HIT', $key) });
    return thaw($record);
}

=head2 $self->del($key)

=cut

sub del {
    my $self = shift;
    my ($key) = @_;
    die 'key required' unless $key;
    my $rdb = $self->client;
    for my $try (1..RDB_TRY()) { 
        if ($rdb->out( $key )) {
            TLG->log->debug(sub { $self->_log_string('REMOVED', $key) });
            last;
        }
        else {
            if ($rdb->ecode == $rdb->ENOREC) {
                TLG->log->warn(sub { $self->_log_string('WARNING REMOVED', $key, $rdb->errmsg($rdb->ecode)) });
                last;
            }
            elsif ($rdb->ecode == $rdb->ERECV && $try < RDB_TRY()) {
                TLG->log->warn( sub { $self->_log_string('WARNING REMOVED', $key, $rdb->errmsg($rdb->ecode), "RETRYING ($try)") } );
            }
            else {
                die $self->_log_string('ERROR REMOVED', $key, $rdb->errmsg($rdb->ecode));
            }
        }
    }
}

sub _log_string {
    my $self = shift;
    my $action = shift;
    my $key = shift;
    return join(' ', $action, 'in the', $self->name, "tyrant (key=$key)", @_);
}

sub start {
    my $self = shift;
    my $ti = TokyoTyrantx::Instance->new( $self->name => $self->args );
    $ti->start;
}

sub stop {
    my $self = shift;
    TokyoTyrantx::Instance->new( $self->name => $self->args )->stop;
}

sub status {
    my $self = shift;
    TokyoTyrantx::Instance->new( $self->name => $self->args )->status;
}

sub reload {
    my $self = shift;
    TokyoTyrantx::Instance->new( $self->name => $self->args )->reload;
}

1;
