package Moxie;
# ABSTRACT: Not Another Moose Clone

use v5.22;
use warnings;
use experimental qw[
    signatures
    postderef
];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use experimental           (); # need this later when we load features
use Module::Runtime        (); # load things so they DWIM
use BEGIN::Lift            (); # fake some keywords
use B::CompilerPhase::Hook (); # multi-phase programming
use Method::Traits         (); # for accessor generators

use MOP;
use MOP::Internal::Util;

use Moxie::Object;
use Moxie::Traits::Provider;

sub import ($class, %opts) {

    # get the caller ...
    my $caller = caller;

    # make the assumption that if we are
    # loaded outside of main then we are
    # likely being loaded in a class, so
    # turn on all the features
    if ( $caller ne 'main' ) {

        # NOTE:
        # create the meta-object, we start
        # with this as a role, but it will
        # get "cast" to a class if there
        # is a need for it.
        my $meta = MOP::Role->new( name => $caller );

        # turn on strict/warnings
        strict->import;
        warnings->import;

        # so we can have fun with attributes ...
        warnings->unimport('reserved');

        # turn on signatures and more
        experimental->import($_) foreach qw[
            signatures

            postderef
            postderef_qq

            current_sub
            lexical_subs

            say
            state
        ];

        # turn on refaliasing if we have it ...
        experimental->import('refaliasing') if $] >= 5.022;

        # import has, extend and with keyword
        BEGIN::Lift::install(
            ($caller, 'has') => sub ($name, $initializer = undef) {
                $initializer ||= eval 'package '.$caller.'; sub { undef }'; # we need this to be a unique CV ... sigh
                $meta->add_slot( $name, $initializer );
                return;
            }
        );

        BEGIN::Lift::install(
            ($caller, 'extends') => sub (@isa) {
                Module::Runtime::use_package_optimistically( $_ ) foreach @isa;
                ($meta->isa('MOP::Class')
                    ? $meta
                    : (bless $meta => 'MOP::Class') # cast into class
                )->set_superclasses( @isa );
                return;
            }
        );

        BEGIN::Lift::install(
            ($caller, 'with') => sub (@does) {
                Module::Runtime::use_package_optimistically( $_ ) foreach @does;
                $meta->set_roles( @does );
                return;
            }
        );

        # setup the base traits, and
        my @traits = ('Moxie::Traits::Provider');
        # and anything we were asked to load ...
        push @traits => $opts{'traits'}->@* if exists $opts{'traits'};

        # then schedule the trait collection ...
        Method::Traits->import_into( $meta, @traits );

        # install our class finalizer
        B::CompilerPhase::Hook::append_UNITCHECK {

            # pre-populate the cache for all the slots
            if ( $meta->isa('MOP::Class') ) {
                foreach my $super ( map { MOP::Role->new( name => $_ ) } $meta->mro->@* ) {
                    foreach my $attr ( $super->slots ) {
                        $meta->alias_slot( $attr->name, $attr->initializer )
                            unless $meta->has_slot( $attr->name )
                                || $meta->has_slot_alias( $attr->name );
                    }
                }
            }

            # apply roles ...
            if ( my @does = $meta->roles ) {
                #warn sprintf "Applying roles(%s) to class/role(%s)" => (join ', ' => @does), $meta->name;
                MOP::Internal::Util::APPLY_ROLES(
                    $meta,
                    \@does,
                    to => ($meta->isa('MOP::Class') ? 'class' : 'role')
                );
            }

        };
    }
}

1;

__END__

=pod

=head1 SYNOPSIS

    package Point {
        use Moxie;

        extends 'Moxie::Object';

        has 'x' => sub { 0 };
        has 'y' => sub { 0 };

        sub x : ro;
        sub y : ro;

        sub clear ($self) {
            @{$self}{'x', 'y'} = (0, 0);
        }
    }

    package Point3D {
        use Moxie;

        extends 'Point';

        has 'z' => sub { 0 };

        sub z : ro;

        sub clear ($self) {
            $self->next::method;
            $self->{'z'} = 0;
        }
    }

=head1 DESCRIPTION

Moxie is a reference implemenation for an object system built
on top of a set of modules.

=over 4

=item L<UNIVERSAL::Object>

This is the suggested base class (through L<Moxie::Object>) for
all Moxie classes.

=item L<MOP>

This provides an API to Classes, Roles, Methods and Slots, which
is use by many elements within this module.

=item L<BEGIN::Lift>

This module is used to create three new keywords; C<extends>,
C<with> and C<has>. These keywords are executed during compile
time and just make calls to the L<MOP> to affect the class
being built.

=item L<Method::Traits>

This module is used to handle the method traits which are used
mostly for method generation (accessors, predicates, etc.).

=item L<B::CompilerPhase::Hook>

This allows us to better manipulate the various compiler phases
that Perl has.

=cut





