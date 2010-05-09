package TLG::Cache::Memcache;

use strict;
use warnings;

#use Cache::Memcached;
use Cache::Memcached::Fast;
use IO::File;

=head2 new

=cut

sub new {
    my $class = shift;
    my @resources;
    while (my $name = shift @_) {
        my $args = shift @_;
        push @resources, [$name, $args];
    }
    my $self = bless {
        resources => \@resources,
    }, $class;
    return $self;
}

sub client {
    my $self = shift;
    my @servers = 
        map { join(':', $_->[1]->{ip}, $_->[1]->{port}) } 
        @{ $self->{resources} };
    return $self->{client} ||= Cache::Memcached::Fast->new( {
        servers => \@servers,
        compress_threshold => 1_000,
        #debug => 0,
    });
}

sub name {
    my $self = shift;
    return 
        join( '-', map { $_->[0] } @{$self->{resources}} );
}

# TODO support N resources
# the solution is to write a Cache::Memcache::instance
sub f_name { $_[0]->{resources}->[0]->[0] };

sub f_args { $_[0]->{resources}->[0]->[1] };

=head2 $self->set($obj)

Caches the object in the cache. 

=cut

sub set { 
    my $self = shift;
    my ($key, $record) = @_;
    die 'key required' unless $key;
    die 'record required' unless $record;
    if ($self->client->set( $key, $record )) {
        TLG->log->debug( sub { $self->_log_string('CACHED', $key) } );
    }
    else {
        TLG->log->warn( sub { $self->_log_string('WARNING CACHED', $key) } );
    }
}

=head2 $self->get($key)

Tries to get the object from the cache. 

=cut

sub get {
    my $self = shift;
    my ($key) = @_;
    die 'key required' unless $key;
    if (my $record = $self->client->get($key)) {
        TLG->log->debug( sub { $self->_log_string('HIT', $key) } );
        return $record;
    }
    return;
}

=head2 $self->del($obj)

=cut

sub del {
    my $self = shift;
    my ($key) = @_;
    die 'key required' unless $key;
    if ($self->client->remove($key)) {
        TLG->log->debug( sub { $self->_log_string('REMOVED', $key) } );
    }
    else {
        TLG->log->warn( sub { $self->_log_string('WARNING REMOVED', $key) } );
    }
}

sub _log_string {
    my $self = shift;
    my $action = shift;
    my $key = shift;
    return join(' ', $action, 'in the', $self->name, "cache (key=$key)", @_);
}

sub pid_filename {
    my $self = shift;
    return $self->f_args->{db_dir}.'/memcache-'.$self->f_args->{port}.'.pid';
}

sub get_pid {
    my $self = shift;
    my $file = $self->pid_filename;
    my $fh = IO::File->new;
    $fh->open("<$file") or die "can't open file $file : $!";
    my $pid = <$fh>;
    $fh->close;
    chomp $pid;
    return $pid;
}

sub start_cmd {
    my $self = shift;
    my @cmd;
    push @cmd, '/usr/local/bin/memcached';
    push @cmd, '-l '.$self->f_args->{ip};
    push @cmd, '-p '.$self->f_args->{port};
    push @cmd, '-P '.$self->f_args->{db_dir}.'/memcache-'.$self->f_args->{port}.'.pid';
    push @cmd, $self->f_args->{extra_options};
    push @cmd, '-d';
    return join(' ', @cmd);
}

sub start {
    my $self = shift;
    my $cmd = $self->start_cmd;
    print "Starting Memcache: $cmd\n";
    system($cmd);
}

sub stop {
    my $self = shift;
    my $pid = $self->get_pid or die "can't find pid";
    print "Stopping memcache pid=$pid\n";
    kill 2, $pid;
}

sub status {
    my $self = shift;
    my $cmd = 'echo -e "stats\nquit" | nc -w1 '.$self->f_args->{ip}.' '.$self->f_args->{port};
    print "Status $cmd\n";
    system($cmd);
}

1;
