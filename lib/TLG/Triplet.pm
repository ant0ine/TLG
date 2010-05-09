package TLG::Triplet;

use strict;
use warnings;

use base qw( TLG::Entity );

use Encode;
use Digest::MD5 qw( md5_base64 );

use TLG::Resource;
use TLG::Predicat;
use TLG::Literal;

our $CACHE = 1;

=head1 DESCRIPTION

=cut

# TODO the remaining issue is the extra columns for multiple indexes, should be optional for some backends

=head2 new($subject, $predicat, $object)

stored in Tokyo Cabinet Table like this:

key => {

    s => <md5 base64 subject resource key>,
    p => <md5 base64 predicat resource key>,

    # one of the three
    ol => <md5 base64 literal key>,
    or => <md5 base64 resource key>,
    on => <numeric value>,
    
    # the additional columns for additional indexes
    sp => 
    pol => 
    por =>
    pon => 

}

=cut

sub new {
    my $class = shift;
    my ($subject, $predicat, $object, $ls) = @_;

    die 'subject required' unless defined $subject;
    $subject = $class->canonical_subject($subject, $ls);
    
    die 'predicat required' unless defined $predicat;
    $predicat = $class->canonical_predicat($predicat, $ls);

    die 'object required' unless defined $object;
    $object = $class->canonical_object($object, $ls);

    my %args = (
        __subject => $subject,
        __predicat => $predicat,
        __object => $object,
    );

    $args{s} = $subject->{key} or die 'subject key missing';
    $args{p} = $predicat->{key} or die 'predicat key missing';
    $args{sp} = join('|', $args{s}, $args{p});

    if (ref $object eq 'TLG::Resource') {
        $args{or} = $object->{key} or die 'object key is missing';
        $args{por} = join('|', $args{p}, $args{or});
    }
    elsif (ref $object eq 'TLG::Literal') {
        $args{ol} = $object->{key} or die 'object key is missing';
        $args{pol} = join('|', $args{p}, $args{ol});
    }
    elsif ($object =~ /^-?\d+$/) { 
        $args{on} = $object;
        $args{pon} = join('|', $args{p}, $args{on});
    }

    return $class->SUPER::new(\%args, $ls);
}

=head2 new_from_ntriples

Create a triple from a ntriples line:
 http://www.w3.org/2001/sw/RDFCore/ntriples/

Not sure the string escapes are complete

And also, note that the file is encoded in utf8.

=cut

# TODO lockset support

sub new_from_ntriples {
    my $class = shift;
    my ($string) = @_;
    # cleaning
    chomp $string;
    $string = Encode::decode_utf8($string);
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    # skip
    return if $string =~ /^#/;
    return if $string eq '';
    
    if ($string =~ /^<([^>]+)>\s+<([^>]+)>\s+(?:<|"")(.+)(?:>|"")\s*\.$/) {
        my ($s, $p, $o) = ($1, $2, $3);
        $o =~ s/\\n/\n/g;
        $o =~ s/\\r/\r/g;
        $o =~ s/\\t/\t/g;
        $o =~ s/\\\"/"/g;
        $o =~ s/\\\\/\\/g;
        return $class->new( $s, $p, $o );
    }
    return;
}

=head2 $class->generate_key(%args);

Can be improved a lot.
IDEA: s|md5(po)

=cut

sub generate_key  {
    my $class = shift;
    my ($args) = @_ or return;
    my $s = join('|', grep { defined $_ } map { $args->{$_} } qw( s p or ol on ) );
    return md5_base64($s);
}

=head2 canonical_subject

Always returns a TLG::Resource

=cut

sub canonical_subject {
    my $class = shift;
    my ($subject, $ls) = @_;
    if (ref $subject eq 'TLG::Resource') {
        if ($ls && !$ls->locked($subject->lock_key)) {
            $subject = $subject->uri;
        }
        else {
            return $subject;
        }
    }
    return TLG::Resource->new($subject, $ls);
}

=head2 canonical_predicat

Always returns a TLG::Predicat

=cut

sub canonical_predicat {
    my $class = shift;
    my ($predicat, $ls) = @_;
    if (ref $predicat eq 'TLG::Predicat') {
        if ($ls && !$ls->locked($predicat->lock_key)) {
            $predicat = $predicat->uri;
        }
        else {
            return $predicat;
        }
    }
    return  ref $predicat eq 'ARRAY' ?
            TLG::Predicat->new(@$predicat, $ls) :
            TLG::Predicat->new($predicat, $ls);
}

=head2 canonical_object

=cut

sub canonical_object {
    my $class = shift;
    my ($object, $ls) = @_;
    if (ref $object eq 'TLG::Resource') {
        if ($ls && !$ls->locked($object->lock_key)) {
            $object = $object->uri;
        }
        else {
            return $object;
        }
    }
    if (ref $object eq 'TLG::Literal') {
        if ($ls && !$ls->locked($object->lock_key)) {
            $object = $object->value;
        }
        else {
            return $object;
        }
    }
    return $object if $object =~ /^-?\d+$/; # TODO decimal
    return $object =~ /^\w+:\S+$/ ?
        TLG::Resource->new($object, $ls) :
        TLG::Literal->new($object, $ls);
}

=head2 get_object_type

Assumes that $object is in the canonical form.

=cut

sub get_object_type {
    my $class = shift;
    my ($object) = @_;
    die 'no object' unless defined $object;
    return 'n' if ! ref $object && $object =~ /^-?\d+$/;
    return 'l' if ref $object eq 'TLG::Literal';
    return 'r' if ref $object eq 'TLG::Resource';
}

=head2 store

=cut

sub store {
    my $self = shift;
    return 1 if $self->is_stored;
    for (qw( subject predicat object )) {
        my $obj = $self->$_();
        die "$_ is missing" unless defined $obj;
        $obj->store if ref $obj;
    }
    return $self->SUPER::store;
}

=head2 load_by_key

=cut

sub load_by_key {
    my $class = shift;
    my ($key, $ls) = @_;
    my $self = $class->SUPER::load_by_key($key, $ls);
    $self->subject($ls);
    $self->predicat($ls);
    $self->object($ls);
    return $self;
}

=head2 load

=cut

sub load {
    my $class = shift;
    my ($subject, $predicat, $object, $ls) = @_;
    my $self = $class->SUPER::load($subject, $predicat, $object, $ls);
    $self->subject($ls);
    $self->predicat($ls);
    $self->object($ls);
    return $self;
}

=head2 subject

=cut

sub subject {
    my $self = shift;
    my ($ls) = @_;
    return $self->{__subject} ||= TLG::Resource->load_by_key( $self->{s}, $ls )
        or die 'subject not found (key='.$self->{s}.', triplet key='.$self->key.')';
}

=head2 predicat

=cut

sub predicat {
    my $self = shift;
    my ($ls) = @_;
    return $self->{__predicat} ||= TLG::Predicat->load_by_key( $self->{p}, $ls )
        or die 'predicat not found (key='.$self->{p}.', triplet key='.$self->key.')';
}

=head2 object

=cut

sub object {
    my $self = shift;
    my ($ls) = @_;
    unless ($self->{__object}) { 
        if (defined $self->{on}) {
            $self->{__object} = $self->{on};
        }
        elsif (defined $self->{ol}) {
            $self->{__object} = TLG::Literal->load_by_key($self->{ol}, $ls)
                or die 'object literal not found (key='.$self->{ol}.', triplet key='.$self->key.')';
        }
        elsif (defined $self->{or}) {
            $self->{__object} = TLG::Resource->load_by_key($self->{or}, $ls)
                or die 'object resource not found (key='.$self->{or}.', triplet key='.$self->key.')';
        }
    }
    return $self->{__object};
}

=head2 object_type

=cut

sub object_type {
    my $self = shift;
    return TLG::Triplet->get_object_type($self->object);
}

=head2 object_value

=cut

sub object_value {
    my $self = shift;
    return $self->object if $self->object_type eq 'n';
    return $self->object->value if $self->object_type eq 'l';
    return $self->object->uri if $self->object_type eq 'r';
}

=head2 remove

Removes the triplet and remove the subject, predicat and literal if they are not used.

Options:

 remove( keep_subject => 1, keep_predicat => 1, keep_object => 1)

=cut

sub remove {
    my $self = shift;
    my %opts = @_;

    # remove the triplet row
    $self->SUPER::remove;
    
    # can the predicat be removed ?
    unless( $opts{keep_predicat} ) {
        $self->predicat->remove
            if TLG::Triplet->query_count( undef, $self->predicat, undef ) == 0;
    }

    # can the subject resource be removed ?
    unless( $opts{keep_subject} ) {
        $self->subject->remove 
            if TLG::Triplet->query_count( $self->subject, undef, undef ) == 0 &&
               TLG::Triplet->query_count( undef, undef, $self->subject ) == 0;
    }

    unless( $opts{keep_object} ) {
        # can the object resource be removed ?
        if ($self->{or}) {
            $self->object->remove
                if TLG::Triplet->query_count( $self->object, undef, undef ) == 0 &&
                   TLG::Triplet->query_count( undef, undef, $self->object ) == 0;
        }
        # can the object literal be removed ?
        if ($self->{ol}) {
            $self->object->remove 
                if TLG::Triplet->query_count( undef, undef, $self->object ) == 0;
        }
    }

    return 1;
}

=head2 remove_gc

Removes the triplet and then uses the garbage collector for the composant.

=cut

sub remove_gc {
    my $self = shift;
    my %opts = @_;

    # remove the triplet row
    $self->SUPER::remove;
    
    eval {
        $self->predicat->trash unless $opts{keep_predicat};

        $self->subject->trash unless $opts{keep_subject};

        unless( $opts{keep_object} ) {
            $self->object->trash if $self->{or} || $self->{ol};
        }
    };

    warn $@ if $@;

    return 1;
}

sub _build_query_args {
    my $class = shift;
    my ($subject, $predicat, $object) = @_;
    
    #use Data::Dumper;
    #print STDERR Dumper(\@_);
    my ($skey, $pkey, $okey, $otype);
    $skey = $class->canonical_subject($subject)->key if defined $subject;
    $pkey = $class->canonical_predicat($predicat)->key if defined $predicat;
    if (defined $object && ref $object ne 'HASH') {
        my $o = $class->canonical_object($object);
        $otype = $class->get_object_type($o);
        $okey = $otype eq 'n' ? $o : $o->key;
    }
    #print STDERR Dumper([$skey, $pkey, $okey, $otype]);
    
    my %args;
    if (!defined $skey && !defined $pkey && !defined $okey) {   # 000
    
    }
    elsif (!defined $skey && !defined $pkey && defined $okey) { # 001
        $args{'o'.$otype} = $okey;
    }
    elsif (!defined $skey && defined $pkey && !defined $okey) { # 010
        $args{p} = $pkey;
    }
    elsif (!defined $skey && defined $pkey && defined $okey) {  # 011
        $args{'po'.$otype} = join('|', $pkey, $okey);
    }
    elsif (defined $skey && !defined $pkey && !defined $okey) { # 100
        $args{s} = $skey;
    }
    elsif (defined $skey && !defined $pkey && defined $okey) {  # 101
        $args{s} = $skey;
        $args{'o'.$otype} = $okey;
    }
    elsif (defined $skey && defined $pkey && !defined $okey) {  # 110 
        $args{sp} = join('|', $skey, $pkey);
    }
    elsif (defined $skey && defined $pkey && defined $okey) {   # 111
        #print STDERR "QUERY can be done with keys\n"; # TODO
        $args{s} = $skey;
        $args{p} = $pkey;
        $args{'o'.$otype} = $okey;
    }

    if (defined $object && ref $object eq 'HASH') {
        $args{on} = $object;
    }
    #print STDERR Dumper(\%args);
    return \%args;
}

=head2 query

Basically a term of a graph pattern

=cut

sub query {
    my $class = shift;
    my ($subject, $predicat, $object, $ls) = @_;
    my $args = $class->_build_query_args($subject, $predicat, $object);    
    return $class->SUPER::query( $args, $ls );
}


=head2 query_count

Same args as query, but just returns the count.

=cut

sub query_count {
    my $class = shift;
    my $args = $class->_build_query_args(@_);    
    return $class->SUPER::query_count( $args );
}

=head2 query_subject_keys

=cut

sub query_subject_keys {
    my $class = shift;
    my $args = $class->_build_query_args(@_);    
    return $class->query_field( $args, 's' );
}

sub as_string { $_[0]->as_ntriples }

sub as_ntriples {
    my $self = shift;
    die 'undef subject' 
        unless defined $self->subject;
    die 'undef predicat' 
        unless defined $self->predicat;
    die 'undef object, subject predicat were: '.$self->subject->as_ntriples.' '.$self->predicat->as_ntriples
        unless defined $self->object;
    return join(' ', 
        $self->subject->as_ntriples,
        $self->predicat->as_ntriples,
        (ref $self->object ? $self->object->as_ntriples : '""'.$self->object.'""'),
        '.'
    );
}

1;
