package TLG::Backend::TT;

use strict;
use warnings;

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
    my $rdb = $self->client;
    for my $try (1..RDB_TRY()) { 
        if ($rdb->put( $key, $record )) {
            TLG->log->debug( sub { $self->_log_string('STORED', $key) } );
            last;
        }
        else {
            if ($rdb->ecode == $rdb->ERECV && $try < RDB_TRY()) {
                TLG->log->warn( sub { $self->_log_string('ERROR STORED', $key, $rdb->errmsg($rdb->ecode), "RETRYING ($try)") } ); 
            }
            else {
                die $self->_log_string('ERROR STORED', $key, $rdb->errmsg($rdb->ecode));
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
    TLG->log->debug( sub { $self->_log_string('HIT', $key) } );
    return $record;
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
            TLG->log->debug( sub { $self->_log_string('REMOVED', $key) } );
            last;
        }
        else {
            if ($rdb->ecode == $rdb->ERECV && $try < RDB_TRY()) {
                TLG->log->warn( sub { $self->_log_string('ERROR REMOVED', $key, $rdb->errmsg($rdb->ecode), "RETRYING ($try)") } );
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

my %OpMap = (
    '<' => 'QCNUMLT',
    '<=' => 'QCNUMLE',
    '>' => 'QCNUMGT',
    '>=' => 'QCNUMGE',
);

my %OrderMap = (
    asc => 'QONUMASC',
    desc => 'QONUMDESC',
);

sub _build_query {
    my $self = shift;
    my ($args) = @_;
    my $qry = TokyoTyrant::RDBQRY->new($self->client);
    
    my @cols = keys %{ $args };
    for (@cols) {
        if (ref $args->{$_} eq 'HASH') {

            if ($args->{$_}->{op}) {
                my $op = $OpMap{$args->{$_}->{op}};
                my $value = $args->{$_}->{value};
                $qry->addcond($_, $qry->$op(), $value);
            }

            if ($args->{$_}->{order}) {
                my $order = $OrderMap{$args->{$_}->{order}};
                $qry->setorder( $_, $qry->$order() );
            }
            
            if ($args->{$_}->{limit}) {
                $qry->setlimit( $args->{$_}->{limit} );
            }

        }
        elsif ($args->{$_} =~ /^-?\d+$/) {
            $qry->addcond($_, $qry->QCNUMEQ, $args->{$_});
        }
        else {
            $qry->addcond($_, $qry->QCSTREQ, $args->{$_});
        }
    }
    return $qry;
}

=head2 query

=cut

sub query {
    my $self = shift;
    my ($args) = @_;
    my $qry = $self->_build_query($args);
    return $qry->searchget();
}

=head2 query_count

=cut

sub query_count {
    my $self = shift;
    my ($args) = @_;
    my $qry = $self->_build_query($args);
    return $qry->searchcount();
}

=head2 $self->query_field( { ... }, $field_to_extract ) 

=cut

sub query_field {
    my $self = shift;
    my ($args, $field) = @_;
    my $qry = $self->_build_query($args);
    my $res = $qry->searchget();
    return [ map { $_->{$field} } @$res ];
}

=head2 $self->query_key( { ... } )

=cut

sub query_key {
    my $self = shift;
    my ($args) = @_;
    my $qry = $self->_build_query($args);
    return $qry->search();
}


sub start {
    my $self = shift;
    my $ti = TokyoTyrantx::Instance->new( $self->name => $self->args );
    $ti->start;
    # set the index
    return 1 unless $self->args->{indices};
    sleep(2);
    print "Set the indexes unless already set\n";
    $ti->set_indices;
    sleep(2);
    print "Optimize index\n";
    $ti->opti_indices;
    sleep(2);
    # reload
    $ti->reload;
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
