package TLG;

use strict;
use warnings;

use Cwd;
use YAML;
use Log::Log4perl;
use TokyoTyrantx::Lock::Client;

use TLG::Universe;

=head1 NAME

TLG - Tiny Local Graph

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 DESCRIPTION

An experimental store for the semantic web data, based and Tokyo Cabinet, Tokyo Tyrant and Memcache.
The name is a reference to the Giant Global Graph L<http://dig.csail.mit.edu/breadcrumbs/node/215>.

=head1 FUNCTIONS

=head2 new

=cut

my $Singleton;

sub new {
    my $class = shift;
    my %param = @_;
    return bless \%param, $class;
}

=head2 instance

TLG is a singleton

=cut

sub instance {
    my $class = shift;
    return $Singleton ||= $class->new(@_);
}

=head2 current_universe

=cut

sub current_universe {
    my $self = shift;
    $self = TLG->instance unless ref $self;
    my ($sys) = @_;
    $self->{current_universe} = $sys if $sys;
    return $self->{current_universe};
}

=head2 base_dir

Returns the base directory.

=cut

sub base_dir {
    my $class = shift;
    return Cwd::realpath($INC[0].'/../');
}

=head2 conf_dirs

=cut

sub conf_dirs {
    my $class = shift;
    my $base = $class->base_dir;
    my @try = (
        $base,
        $base.'/conf/',
        $base.'/t/',
    );
}

=head2 boot

=cut

sub boot {
    my $class = shift;
    my %args = @_;
    my $conf;
    if (my $name = $args{name}) {
        my ($file) = grep { -f $_ } map { $_.$name.'.yaml' } $class->conf_dirs;
        die 'no conf file found' unless $file;
        $conf = YAML::LoadFile($file);
    }
    elsif( my $file = $args{file} ) {
        $conf = YAML::LoadFile($file);
    }
    elsif( $args{conf} ) {
        $conf = $args{conf};
    }
    # check the conf
    die 'universe required' unless $conf->{universe};
    $class->instance;
    TLG::Universe->new(%{ $conf->{universe} })->set_current;
    
    Log::Log4perl->init( \ $conf->{Log4perl} );

    return 1;
}

=head2 end

=cut

sub end {
    my $class = shift;
    $class->current_universe->end;
}

=head2 get_lock

=cut

sub get_lock {
    my $self = shift;
    my $c = TLG->current_universe->get_lock_client
        or die 'cannot get the lock client';
    return $c->lock(@_);
}

=head2 log

=cut

sub log {
    my $class = shift;
    my $self = TLG->instance;
    return $self->{logger} ||= Log::Log4perl::get_logger($class);
}

=head1 AUTHOR

Antoine Imbert, C<< <antoine.imbert at gmail.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Antoine Imbert, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
