package Moxie::Traits::Provider;
# ABSTRACT: built in traits

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

our $VERSION   = '0.07';
our $AUTHORITY = 'cpan:STEVAN';

use Module::Runtime ();

use Moxie::Traits::Provider::Accessor    ();
use Moxie::Traits::Provider::Constructor ();

our @PROVIDERS = qw(
    Moxie::Traits::Provider::Accessor
    Moxie::Traits::Provider::Constructor
);

our @EXPERIMENTAL_PROVIDERS = qw(
    Moxie::Traits::Provider::Experimental
);

## ...

sub list_providers              () { @PROVIDERS }
sub list_experimental_providers () { @EXPERIMENTAL_PROVIDERS }

## ...

sub load_experimental_providers {
    map Module::Runtime::use_package_optimistically( $_ ), list_experimental_providers()
}

1;

__END__

=pod

=head1 DESCRIPTION

This is a L<Method::Traits> provider module which L<Moxie> enables by
default. These are documented in the L<METHOD TRAITS> section of the
L<Moxie> documentation.

=cut
