package Moxie::Object;
# ABSTRACT: Yet Another Base Class

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

our @ISA; BEGIN { @ISA = ('UNIVERSAL::Object') }

sub DOES ($self, $role) {
    my $class = ref $self || $self;
    # if we inherit from this, we are good ...
    return 1 if $class->isa( $role );
    # next check the roles ...
    my $meta = MOP::Class->new( name => $class );
    # test just the local (and composed) roles first ...
    return 1 if $meta->does_role( $role );
    # then check the inheritance hierarchy next ...
    return 1 if scalar grep { MOP::Class->new( name => $_ )->does_role( $role ) } $meta->mro->@*;
    return 0;
}

1;

__END__

=pod

=head1 DESCRIPTION

Extending L<UNIVERSAL::Object> for fun and profit?

=cut
