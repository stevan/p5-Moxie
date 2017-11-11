package Moxie::Traits::Provider::Delegation;
# ABSTRACT: built in traits

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

use Method::Traits ':for_providers';

use Carp      ();
use MOP::Util ();

our $VERSION   = '0.06';
our $AUTHORITY = 'cpan:STEVAN';

sub handles ( $meta, $method, @args ) : OverwritesMethod {

    my $method_name = $method->name;

    my ($slot_name, $delegate) = ($args[0] =~ /^(.*)\-\>(.*)$/);

    Carp::confess('Delegation spec must be in the pattern `slot->method`, not '.$args[0])
        unless $slot_name && $delegate;

    Carp::confess('Unable to build delegation method for slot `' . $slot_name.'` in `'.$meta->name.'` because the slot cannot be found.')
        unless $meta->has_slot( $slot_name )
            || $meta->has_slot_alias( $slot_name );

    $meta->add_method( $method_name => sub {
        $_[0]->{ $slot_name }->$delegate( @_[ 1 .. $#_ ] );
    });
}

1;

__END__

=pod

=head1 DESCRIPTION

This is a L<Method::Traits> provider module which L<Moxie> enables by
default. These are documented in the L<METHOD TRAITS> section of the
L<Moxie> documentation.

=cut
