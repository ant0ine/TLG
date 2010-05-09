package TLG::Class;

use strict;
use warnings;

use Carp;

use TLG;
use TLG::Resource;
use TLG::Predicat;
use TLG::Literal;
use TLG::Triplet;
use TLG::Namespace;
use TLG::TXN;
use TLG::Unmutable;

our $CACHE = 1;

=head2 new( $subject )

$subject can be a URI or a TLG::Resource object.

explain that this is in fact load_or_new

=cut

sub new {
    my $class = shift;
    my ($subject) = @_;

    unless ($subject) {
        # TODO lockset and anonymous node
        $subject = TLG::Resource->new; # new blank node
    }
    else {
        my $ls = TLG::TXN->get_lockset;
        $subject = TLG::Triplet->canonical_subject($subject, $ls);
        my $obj = $class->load($subject, $ls);
        return $obj if $obj;
    }

    my $self = bless( {}, $class );
    $self->init($subject);
    return $self;
}

=head2 init( $subject )

explain how to overload

=cut

sub init {
    my $self = shift;
    my ($subject) = @_;
    
    $self->{__subject} = $subject;
    $self->{__properties} = {};
    $self->{__new_properties} = {};

    # set the rdf_type property
    $self->set( rdf => type => $self->rdf_type )
        if $self->rdf_type;
}

=head2 rdf_type

=cut

sub rdf_type { return undef; }

=head2 subject

Returns the subject as a TLG::Resource object.

=cut

sub subject {
    my $self = shift;
    return $self->{__subject};
}

=head2 uri

Returns the subject URI. Short for $self->subject->uri

=cut

sub uri {
    my $self = shift;
    $self->subject->uri;
}

=head2 load( $subject )

$subject can be a URI or a TLG::Resource object.

If you plan to modify the node, it should be locked, see lock_and_load.

=cut

sub load {
    my $class = shift;
    my ($subject) = @_;
    my $ls = TLG::TXN->get_lockset;

    # checks
    die 'subject required to load a node' unless $subject;
    $subject = TLG::Triplet->canonical_subject($subject, $ls);
    return unless $subject->exists;

    my $self = $class->_get_cache($subject, $ls);
    return $self if $self;

    $self = $class->_get_backend($subject, $ls);
    
    # cache missed, fill it, we have a lock it's safe. 
    $self->_set_cache if $self && $ls;

    return $self;
}

### property accessors ###

=head2 properties

=cut

sub properties {
    my $self = shift;
    my %h = %{ $self->_merged_properties };
    for my $puri (keys %h) {
        $h{$puri} = [ map { $_->object_value } @{ $h{$puri} } ];
    }
    return \%h;
}

=head2 get_as_triplet( $ns, $local );

=cut

sub get_as_triplet {
    my $self = shift;
    my $puri;
    if (@_ == 1) {
        $puri = TLG::Namespace->resolve($_[0]);
    }
    elsif (@_ == 2) {
        $puri = TLG::Namespace->norm($_[0]) . $_[1];
    }
    else { die 'wrong number of args'; }

    my $p = $self->_merged_properties;
    return $p->{$puri} || [];
}

=head2 get( $ns, $local );

 get('http://purl.org/dc/elements/1.1/title')
 get('dc_title')
 get('http://purl.org/dc/elements/1.1/', 'title')
 get(dc => 'title')

=cut

sub get {
    my $self = shift;
    my @r = map { $_->object_value } @{ $self->get_as_triplet(@_) };
    return unless scalar @r;
    return wantarray ? @r : $r[0]; 
}

=head2 set( $ns => $local => $value )

    set( $ns => $local => [ $value1, $value2, ... ] )
    set( $ns => $local => undef )
    set( $uri => $value )
    set( $uri => [ $value1, $value2, ... ] )
    set( $uri => undef )

=cut 

sub _scrub_set_args {
    my $self = shift;
    my ($puri, $values);
    if (@_ == 2) {
        $puri = $_[0];
        $values = ref $_[1] eq 'ARRAY' ? $_[1] : [ $_[1] ];
    }
    elsif (@_ == 3) {
        $puri = TLG::Namespace->norm($_[0]) . $_[1];
        $values = ref $_[1] eq 'ARRAY' ? $_[2] : [ $_[2] ];
    }
    else { confess 'wrong number of args'; }
    die 'no value' unless @$values;
    return ($puri, $values);
}

sub set {
    my $self = shift;
    my ($puri, $values) = $self->_scrub_set_args(@_);
    my $ls = TLG::TXN->get_lockset;

    my $p = TLG::Predicat->new($puri, $ls);

    if (@$values == 1 && ! defined $values->[0]) {
        $self->{__new_properties}->{$p->uri} = undef;
    }
    else {
        my @triplets;
        for (@$values) {
            next unless defined $_;
            push @triplets, TLG::Triplet->new($self->subject, $p, $_, $ls);
        }
        $self->{__new_properties}->{$p->uri} = \@triplets;
    }
    return 1;
}

=head2 add( $ns => $local => $value )

    add( $ns => $local => [ $value1, $value2, ... ] )
    add( $uri => $value )
    add( $uri => [ $value1, $value2, ... ] )

=cut

sub add {
    my $self = shift;
    my ($puri, $values) = $self->_scrub_set_args(@_);
    my $ls = TLG::TXN->get_lockset;

    my $p = TLG::Predicat->new($puri, $ls);

    my @triplets;
    for (@$values) {
        next unless defined $_;
        push @triplets, TLG::Triplet->new($self->subject, $p, $_, $ls);
    }

    if ($self->{__new_properties}->{$p->uri}) {
        push @{ $self->{__new_properties}->{$p->uri} }, @triplets;
    }
    else {
        $self->{__new_properties}->{$p->uri} = [ @{ $self->{__properties}->{$p->uri} || [] }, @triplets ];
    }

    return 1;
}

=head2 del( $ns => $local => $value )

    add( $ns => $local => [ $value1, $value2, ... ] )
    add( $uri => $value )
    add( $uri => [ $value1, $value2, ... ] )

=cut

sub del {
    my $self = shift;
    my ($puri, $values) = $self->_scrub_set_args(@_);
    my $ls = TLG::TXN->get_lockset;

    my $p = TLG::Predicat->new($puri, $ls);

    my @obj =   map { ref $_ ? $_->key : $_ }  # XXX key can equal value ?
                map { TLG::Triplet->canonical_object($_) } 
                grep { defined $_ } @$values;
    my %object;
    $object{$_}++ for @obj;

    $self->{__new_properties}->{$p->uri} ||= $self->{__properties}->{$p->uri} || [];
    $self->{__new_properties}->{$p->uri} = [ 
        grep { my $key = ref $_->object ? $_->object->key : $_->object; !$object{$key} } 
        @{ $self->{__new_properties}->{$p->uri}} 
    ];

    return 1;
}

### Inbound accessors ###

=head2 get_referers_as_triplet

=cut

# TODO cache this too, require to invalidate the cache of other objects, Potantial big win here 

sub get_referers_as_triplet {
    my $self = shift;
    my ($ns, $local) = @_;
    $ns = TLG::Namespace->norm($ns);
    $self->subject->exists or return [];
    my $p = TLG::Predicat->load_by_uri($ns, $local) or return [];
    return TLG::Triplet->query(undef, $p, $self->subject);
}

=head2 get_referers

=cut

sub get_referers { # TODO rename as get_inbound get_outbound (not sure un fact)
    my $self = shift;
    my @r = map { $_->subject->uri } @{ $self->get_referers_as_triplet(@_) };
    return wantarray ? @r : shift @r;
}

=head2 count_referers

=cut

sub count_referers {
    my $self = shift;
    return scalar @{ $self->get_referers_as_triplet(@_) };
}

=head2 store

In a concurrent environment, the node is supposed to be locked.

=cut

sub store {
    my $self = shift;

    eval { $self->_set_backend };

    if ($@) {
        TLG->log->error("ERROR STORED in the backend : $@");
        $self->_del_cache;
        die "ERROR STORED in the backend: $@";
    }
    else {
        $self->_set_cache;
    }

    return 1;
}

=head2 remove

    $n->remove;

    $n->remove( keep_predicat => 1 );

=cut

sub remove {
    my $self = shift;
    my %opts = @_;

    $self->subject->exists or return;

    $self->_del_cache;

    $self->_del_backend(%opts);

    return 1;
}

=head2 as_string

=cut

sub as_string {
    my $self = shift;

    my @s = ($self->subject->as_string);
    for my $p (values %{ $self->_merged_properties }) {
        push @s, map { $_->as_string } @$p;
    }
    return join("\n\t", @s)."\n";
}

=head2 as_ntriples

=cut

sub as_ntriples {
    my $self = shift;
    my @s;
    for my $p (values %{ $self->_merged_properties }) {
        push @s, map { $_->as_ntriples } @$p;
    }
    return join("\n", @s)."\n";
}


sub as_xml {
    my $self = shift;
    my $type = $self->rdf_type || 'rdf:Description';
}

### Cache private methods ###

sub _cache_driver {
    return TLG->current_universe->cache_driver('node');
}

sub _cache_key {
    my $class = shift;
    my ($key) = @_;
    if (ref $class) {
        $key = $class->subject->key;
    }
    return unless $key;
    # use package here to allow the polymorphic classes to share the cache
    return join '-', __PACKAGE__, TLG->current_universe->{id}, $key;
}

sub _set_cache {
    my $self = shift;
    return unless $CACHE;
    die 'not stored yet, cannot cache' unless $self->subject->exists;
    my $key = $self->_cache_key or die 'no cache key';
    $self->_cache_driver->set( $key, $self )
}

sub _get_cache {
    my $class = shift;
    my ($subject) = @_;
    
    return unless $CACHE;
    
    my $key = $class->_cache_key($subject->key);

    my $cached = $class->_cache_driver->get($key)
        or return;

    # locking
    if (my $ls = TLG::TXN->get_lockset) {
        my %merged = %{ $cached->_merged_properties };
        for my $p (keys %merged) {
            for my $t (@{$merged{$p}}) {
                $ls->get_lock($t->lock_key)
                    unless TLG::Unmutable->is_unmutable(entity => $t);
                $ls->get_lock($t->predicat->lock_key)
                    unless TLG::Unmutable->is_unmutable(entity => $t->predicat);
                $ls->get_lock($t->object->lock_key)
                    if ref $t->object && !TLG::Unmutable->is_unmutable(entity => $t->object);
            }
        }
    }

    TLG->log->debug("HIT the node cache $key");
    
    # make sure the object has the right class: POLYMORPHISM
    my %obj = %$cached;
    my $self = bless \%obj, $class;

    # check that the cache is correct (no key collision)
    die "wrong cached key" unless $self->uri eq $subject->uri;
    
    # check the rdf_type if defined
    if ($self->rdf_type) {
        my @types = $self->get( rdf => 'type');
        return unless grep { $_ eq $self->rdf_type } @types;
    }
    
    return $self;
}

sub _del_cache {
    my $self = shift;
    return unless $CACHE;
    die 'not stored yet, cannot cache' unless $self->subject->exists;
    my $key = $self->_cache_key or die 'no cache key';
    $self->_cache_driver->del( $key );
}

### Backend private methods ###

sub _store_property {
    my $self = shift;
    my ($predicat) = @_;
    $predicat = TLG::Triplet->canonical_predicat($predicat);

    my %objects;
   
    # new version
    my $new_p = $self->{__properties}->{$predicat->uri};
    if (exists $self->{__new_properties}->{$predicat->uri}) {
        $new_p = delete $self->{__new_properties}->{$predicat->uri};
    }

    for ( @{ $new_p || [] } ) {
        my $o = $_->object;
        $o->store if ref $o;
        my $key = ref $o ? ref($o).$o->{key} : $o;
        $objects{$key} = { obj => $o, count => 10, triplet => $_ };
    }
    
    # current version
    for ( @{ $self->{__properties}->{$predicat->uri} || [] } ) {
        my $o = $_->object;
        my $key = ref $o ? ref($o).$o->{key} : $o;
        if ($objects{$key}) {
            $objects{$key}->{count}++;
            $objects{$key}->{triplet} = $_;
        }
        else {
            $objects{$key} = { obj => $o, count => 1, triplet => $_ };
        }
    }

    # first add to not remove a predicat or a resource for nothing
    for (keys %objects) {
        if ($objects{$_}->{count} == 10) { # add
            $objects{$_}->{triplet}->store;
        }
    }

    # then remove
    for (keys %objects) {
        if ($objects{$_}->{count} == 1) { # remove
            $objects{$_}->{triplet}->remove(
                keep_subject => 1,
                keep_predicat => 1, # TODO not sure, we may want to remove it completely
            );
        }
    }

    # sync localy
    if (defined $new_p) {
        $self->{__properties}->{$predicat->uri} = $new_p;
    }
    else {
        delete $self->{__properties}->{$predicat->uri};
    }

    return 1;
}


sub _merged_properties {
    my $self = shift;
    # TODO storable dclone ?
    my %h = ( %{ $self->{__properties} }, %{ $self->{__new_properties} } );
    return \%h;
}

sub _set_backend {
    my $self = shift;
    $self->subject->store;
    $self->_store_property($_)
        for keys %{ $self->_merged_properties };
    return 1;
}

sub _get_backend {
    my $class = shift;
    my ($subject) = @_;
    my $ls = TLG::TXN->get_lockset;

    # prepare the object
    my $self = bless( {
        __subject => $subject,
        __properties => {},
        __new_properties => {},
    }, $class );

    # load from the DB
    for (@{ TLG::Triplet->query($subject, undef, undef, $ls)}) {
        # load  the properties
        my $puri = $_->predicat->uri; 
        $self->{__properties}->{$puri} ||= [];
        push @{ $self->{__properties}->{$puri} }, $_;
    }

    # check the rdf_type if defined
    if ($self->rdf_type) {
        my @types = $self->get( rdf => 'type');
        return unless grep { $_ eq $self->rdf_type } @types;
    }
        
    TLG->log->debug("HIT the node tokyo ".$self->subject->key);

    return $self;
}

sub _del_backend {
    my $self = shift;
    my %opts = @_;
    my @atts = map { @$_ } values %{ $self->{__properties} };
    my $last = pop @atts;
    $_->remove(
        %opts,
        keep_subject => 1,
    ) for (@atts);
    $last->remove(%opts);
}

### Query methods ###

# TODO change api to use the Set Theory terminology
my $process_terms;
# http://cpansearch.perl.org/src/STBEY/Bit-Vector-7.1/examples/SetObject.pl
$process_terms = sub {
    my ($op, $terms) = @_;
    my @results;

    # DIFF is not ? we need to support the ARRAY API
    my @predicats;
    if (ref $terms eq 'ARRAY') {
        my $first_p = $terms->[0];
        my %h = @$terms;
        $terms = \%h;
        @predicats = grep { $first_p ne $_ } keys %$terms;
        unshift @predicats, $first_p;
    }
    else {
        @predicats = keys %$terms;
    }

    for my $predicat (@predicats) {
        if (grep { $_ eq $predicat } qw( AND OR DIFF )) {
            push @results, &$process_terms($predicat, $terms->{$predicat});
        }
        else {
            push @results, TLG::Triplet->query_subject_keys( undef, $predicat, $terms->{$predicat} );
        }
    }

    my %hash;
    my $set_count = 1;
    for my $r (@results) {
        for my $key (@$r) {
            if ($hash{$key}) {
                $hash{$key} += $set_count;
            }
            else {
                $hash{$key} = $set_count;
            }
        }
        $set_count *= 10;
    }

    if ($op eq 'AND') {
        my $score = '1' x scalar @results;
        return [ 
            grep { $hash{$_} == $score } keys %hash
        ];
    }
    elsif ($op eq 'OR') {
        return [ keys %hash ];
    }
    elsif ($op eq 'DIFF') {
        my $score = '1';
        return [ 
            grep { $hash{$_} == $score } keys %hash
        ];
    }
    else {
        die 'unknown operator';
    }
};

=head2 query

 query(
    AND  => {
        $ns.$local => $value,
        $ns.$local => { op => '>', value => $value },
        $ns.$local => undef,
        OR => { 
            $ns.$local => $value,
            $ns.$local => $value,
        },
    }, 
    OR => { 
        $ns.$local => $value,
        $ns.$local => $value,
    },
    DIFF => {
        $ns.$local => $value,
        $ns.$local => $value,
    }
)

=cut

sub query {
    my $class = shift;
    my ($terms, $opts) = @_;

    my $r = $class->query_subject_keys($terms, $opts);

    # load the node from the keys, some may have been removed in the meantime
    my @nodes;
    for (@$r) {
        # TODO, should be possible to skip this ? and load directly from the key ?
        my $s = TLG::Resource->load_by_key($_, TLG::TXN->get_lockset); 
        unless ($s) {
            TLG->log->warn("no resource for key: $_");
            next;
        }
        my $n = $class->load($s);
        unless ($n) {
            TLG->log->warn("no node for resource key: $_");
            next;
        }
        push @nodes, $n;
    }

    return \@nodes;
}

=head2 query_subject_keys

=cut

sub query_subject_keys {
    my $class = shift;
    my ($terms, $opts) = @_;
    
    # my $t0 = [gettimeofday]; # TODO profiling

    $terms->{'rdf:type'} = $class->rdf_type if $class->rdf_type;

    my $r =  &$process_terms( AND => $terms );

    if (my $sort = $opts->{sort}) {
        my %h;
        $h{$_}++ for @$r;
        my $s = TLG::Triplet->query_subject_keys( undef, $sort->{predicat}, { order => $sort->{order} } ); 
        my @result;
        for (@$s) {
            push @result, $_ if delete $h{$_};
        }
        push @result, keys %h;
        $r = \@result;
    }

    if ($opts->{limit}) {
        $opts->{offset} ||= 0;
        $r = [ splice( 
            @$r, 
            $opts->{offset}, 
            $opts->{limit}
        ) ];
    }

    return $r;
}

=head2 count

=cut

#TODO rename query count
sub count {
    my $class = shift;
    my ($terms) = @_;
    $terms->{'rdf:type'} = $class->rdf_type if $class->rdf_type;
    return scalar @{ &$process_terms( AND => $terms ) };
}

sub DESTROY { }

our $AUTOLOAD;

sub AUTOLOAD {
    my $mth = $AUTOLOAD;
    $mth =~ s/.*:://;
    my $self = shift;
    my $uri = TLG::Namespace->resolve($mth);
    confess "unknown properties $AUTOLOAD" if $mth eq $uri;
    if (@_) {
        return $self->set($uri => @_);
    }
    else {
        return $self->get($uri);
    }
}

1;

