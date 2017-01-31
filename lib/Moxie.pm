package Moxie;
# ABSTRACT: Yet Another Moose Clone

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

# TODO:
# Everything that this &import method does should be
# in util subroutines so that someone else can just
# come in and use it sensibly to implement their own
# object system if they want. The idea is that the
# simple, bare bones sugar I provide here is just barely
# one step above the raw version which uses the package
# variables and MOP::Internal::Util::* methods directly
# inside BEGIN blocks, etc.
#
# In short, there is no need to make people jump through
# stupid meta-layer subclass stuff in order to maintain
# a level or purity that perl just doesn't give a fuck
# about anyway. In the 'age of objects' we have forgotten
# that subroutines are also an excellent form of encapsulation
# and re-use.
# - SL

sub import ($class, %opts) {

    # get the caller ...
    my $caller = caller;

    # make the assumption that if we are
    # loaded outside of main then we are
    # likely being loaded in a class, so
    # turn on all the features
    if ( $caller ne 'main' ) {

        # FIXME:
        # There are a lot of assumptions here that
        # we are not loading MOP.pm in a package
        # where it might have already been loaded
        # so we might want to keep that in mind
        # and guard against some of that below,
        # in particular I think the FINALIZE handlers
        # might need to be checked, and perhaps the
        # 'has' keyword importation as well.
        # - SL

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
        Method::Traits::import_into( $meta, @traits );

        # install our class finalizers in the
        # reverse order so that the first one
        # encountered goes first, this is the
        # reverse of the usual UNITCHECK way
        # but is what we need here.
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
on top of the MOP. It is purposefully meant to be similar to
the Moose/Mouse/Moo style of classes, but with a number of
improvements as well.

=cut





