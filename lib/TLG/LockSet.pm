package TLG::LockSet;

use strict;
use warnings;

use TLG;
use TokyoTyrantx::Lock::Client;

$TokyoTyrantx::Lock::Client::DEBUG=0;

=head1 DESCRIPTION

Manage a set of entity locks

=cut

sub new {
    my $class = shift;
    return bless { set => {} }, $class;
}

=head2 get_lock($key)

=cut

sub get_lock {
    my $self = shift;
    my ($key) = @_;
    die 'no key' unless $key;
    return if $self->{set}->{$key};
    if (my $lock = TLG->get_lock(
        $key,
        or_wait => 1,
        n_times => 20,
    )) {
        $self->{set}->{$key} = $lock;
    }
    else {
        my $msg = "cannot get the lock, resource taken $key";
        TLG->log->warn($msg);
        die $msg;
    }
}

=head2 locked($key)

=cut

sub locked { 
    my $self = shift;
    my ($key) = @_;
    return $self->{set}->{$key} ? 1 : 0;  
}

=head2 lock_count

=cut

sub lock_count {
    my $self = shift;
    return scalar keys %{ $self->{set} };
}

1;
