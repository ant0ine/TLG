package TLG::TXN;
use strict;
use warnings;

use TLG::LockSet;

my $LS;
my $Running;

sub get_lockset {
    my $class = shift;
    return unless $Running;
    return $LS;
}

sub start {
    my $class = shift;    
    $LS = TLG::LockSet->new;
    $Running = 1;
}

sub pause {
    my $class = shift;
    $Running = 0;
}

sub resume {
    my $class = shift;
    $Running = 1;
}

sub end {
    my $class = shift;
    TLG->log->info('TXN end, releasing '.$LS->lock_count.' locks');
    $LS = undef;
    $Running = 0;
}

# TODO this is a write ahead log, with do and undo action
# TLG::TXN->add_step( do => ..., undo => ... )
sub add_step {}

1;

