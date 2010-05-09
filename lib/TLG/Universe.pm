package TLG::Universe;

use strict;
use warnings;

use TokyoTyrantx::Counter;
use TokyoTyrantx::Lock::Client;

use TLG;
use TLG::Namespace;

$TokyoTyrantx::Lock::Client::DEBUG = 1;

=head2 new

=cut

sub new {
    my $class = shift;
    my %args = @_;
    for (qw( id name resources triplestore )) {
        die "$_ required" unless $args{$_};
    }
    return bless( \%args, $class );
}

=head2 set_current

=cut

sub set_current {
    my $self = shift;
    TLG->instance->current_universe($self);
}

=head2 get_role_conf

=cut

sub get_role_conf {
    my $self = shift;
    my ($role) = @_;
    return $self->{triplestore}{$role};
}

=head2 get_resource_conf

=cut

sub get_resource_conf {
    my $self = shift;
    my ($res) = @_;
    return $self->{resources}{$res};
}

=head2 get_host_resources

=cut

sub get_host_resources {
    my $self = shift;
    my ($host) = @_;
    return grep {
        $self->{resources}{$_}{runhost} &&
        $self->{resources}{$_}{runhost} eq $host
    } keys %{ $self->{resources} };
}

=head2 instanciate_driver

=cut

sub instanciate_driver {
    my $self = shift;
    my ($res) = @_;
    my $class;
    my %resources;
    if (ref $res eq 'ARRAY') {
        for (@$res) {
            my $conf = $self->get_resource_conf($_);
            $class = $conf->{driver};
            $resources{$_} = $conf->{args};
        }
    }
    else {
        my $conf = $self->get_resource_conf($res);
        $class = $conf->{driver};
        $resources{$res} = $conf->{args};
    }
    eval "require $class";
    my $driver = $class->new( %resources );
    return $driver;
}

=head2 backend_driver

=cut

sub backend_driver {
    my $self = shift;
    my ($role) = @_;
    my $resname = $self->get_role_conf($role)->{backend};
    return $self->{__backend_driver}->{$role} ||= $self->instanciate_driver($resname);
}

=head2 cache_driver

=cut

sub cache_driver {
    my $self = shift;
    my ($role) = @_;
    my $resname = $self->get_role_conf($role)->{cache};
    return $self->{__cache_driver}->{$role} ||= $self->instanciate_driver($resname);
}

=head2 get_lock_client

=cut

sub get_lock_client {
    my $self = shift;
    return $self->{__lock_client} ||= TokyoTyrantx::Lock::Client->instance(
        hash => $self->instanciate_driver('lock')->client # XXX this is a hack
    );
}

=head2 get_counter_client

=cut

sub get_counter_client {
    my $self = shift;
    return $self->{__counter_client} ||= TokyoTyrantx::Counter->instance(
        hash => $self->instanciate_driver('counter')->client # XXX this is a hack
    );
}

sub cache_info {
    my $self = shift;
    my %info;
    for (qw( Resource Predicat Literal Triplet Class )) {
        my $var = '$TLG::'.$_.'::CACHE';
        $info{$var} = eval "$var";
    }
    return \%info;
}

sub end {
# TODO disconnect all memcache and tokyo tyrant

}

1;
