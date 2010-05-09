package TLG::Unmutable;
use strict;
use warnings;

my %Unmutables;

sub _check_entity_class {
    my $test = shift;
    return scalar grep { $test eq $_ } 
        qw( TLG::Predicat TLG::Resource TLG::Literal TLG::Triplet );
}

sub _norm_args {
    my %args = @_;
    my ($role, $key);
    if ($args{lock_key}) {
        (undef, $role) = split /-/, $args{lock_key};
        $key = $args{lock_key};
    }
    elsif ($args{class} && _check_entity_class($args{class})) {
        $role = $args{class}->role;
    }
    elsif ($args{role}) {
        $role = $args{role};
    }
    elsif ($args{entity}) {
        (undef, $role) = split /-/, $args{entity}->lock_key;
        $key = $args{entity}->lock_key;
    }
    return ($role, $key);
}

=head2 set_unmutable($entity)

or set_unmutable(ref $entity)

In parallel env, the entities must be locked before been declared as unmutables.

TODO, move this into the config or init phase.

=cut

sub set_unmutable {
    my $class = shift;
    my ($role, $key) = _norm_args(@_);
    if ($key) {
        $Unmutables{$key} = 1;
    }
    else {
        $Unmutables{$role} = 1 if $role;
    }
}

=head2 is_unmutable( entity => $entity )

=cut

sub is_unmutable {
    my $class = shift;
    my ($role, $key) = _norm_args(@_);
    return 1 if $role && $Unmutables{$role};
    return 1 if $key && $Unmutables{$key};
    return 0;
}

=head2 clear_unmutables

For testing purpose only

=cut

sub clear_unmutables {
    my $class = shift;
    %Unmutables = ();
}

1;
