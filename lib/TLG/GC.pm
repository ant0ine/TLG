package TLG::GC;

use strict;
use warnings;

use TLG::Resource;
use TLG::Predicat;
use TLG::Literal;
use TLG::Triplet;

=head1 DESCRIPTION

Naive and experimental Garbage collector, not enable yet.

=cut

my $Instance;

sub new {
    my $class = shift;
    my %param = @_;
    return bless \%param, $class;
}

sub instance {
    my $class = shift;
    return $Instance ||= $class->new(@_);
}

sub clean_resource {
    my $self = shift;
    my ($key) = @_;
    my $r = TLG::Resource->load_by_key($key);
    if ($r &&
        TLG::Triplet->query_count( $r, undef, undef ) == 0 &&
        TLG::Triplet->query_count( undef, undef, $r ) == 0) {
        $r->remove;
        return 1;
    }
    return 0;
}

sub clean_predicat {
    my $self = shift;
    my ($key) = @_;
    my $p = TLG::Predicat->load_by_key($key);
    if ($p && 
        TLG::Triplet->query_count( undef, $p, undef ) == 0) {
        $p->remove;
        return 1;
    }
    return 0;
}

sub clean_literal {
    my $self = shift;
    my ($key) = @_;
    my $l = TLG::Literal->load_by_key($key);
    if ($l &&
        TLG::Triplet->query_count( undef, undef, $l ) == 0) {
        $l->remove;
        return 1;
    }
    return 0;
}

sub clean {
    my $self = shift;
    my ($key) = @_;
    my ($md5, $type) = split(/-/, $key);
    my $mth = 'clean_'.$type;
    if ($self->can($mth)) {
        return $self->$mth($md5);
    }
    return 0;
}


sub run {
    my $self = shift;
    print "Running the Garbage Collector\n";
#    return unless $self->size < 1000;
# time too
    my $c = TLG->current_universe->get_counter_client;
    print "found ".$c->counter_count." objects that maybe be removed\n";
    my $removed = 0;
    $c->iterinit;
    while (my $key = $c->iternext) {
        my $count = $c->value($key);
        TLG->log->info("cleaning $key, in trash $count times");
#        next if $count > 10; # percent of the size ?
        $removed += $self->clean($key);
        $c->reset($key);
    }
    print "removed: $removed\n";
}

1;
