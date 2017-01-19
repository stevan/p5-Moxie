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
use PadWalker              (); # for generating lexical accessors

use MOP;
use MOP::Internal::Util;

# ...

our %ATTRIBUTE_MAPPING;

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

sub import ($class, @args) {

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


        # This next step, we want to do
        # immediately after this import
        # method (and the BEGIN block it
        # is contained within) finishes

        # since these are BEGIN blocks,
        # they need to be enqueued in
        # the reverse order they will
        # run in order to have the method
        # not trip up role composiiton
        B::CompilerPhase::Hook::enqueue_BEGIN {
            $meta->delete_method_alias('MODIFY_CODE_ATTRIBUTES')
        };
        B::CompilerPhase::Hook::enqueue_BEGIN {
            $meta->alias_method(
                FETCH_CODE_ATTRIBUTES => sub {
                    my (undef, $code) = @_;
                    @{ $ATTRIBUTE_MAPPING{ $code } || [] };
                }
            );
            $meta->alias_method(
                MODIFY_CODE_ATTRIBUTES => sub {
                    my (undef, $code, @attrs) = @_;
                    my $method = MOP::Method->new( $code );
                    foreach my $attr ( @attrs ) {
                        my ($trait, $arg);
                        if ( $attr =~ m/^([a-z_]*)$/ ) {
                            $trait = $1;
                        }
                        elsif ( $attr =~ m/^([a-z_]*)\((.*)\)$/ ) {
                            $trait = $1;
                            $arg   = $2;
                        }
                        GENERATE_METHOD( $meta, $method, $trait, $arg );
                    }
                    # yuk!
                    if ( my $generated = $meta->get_method( $method->name ) ) {
                        $ATTRIBUTE_MAPPING{
                            $generated->body
                            # we need to do this ^^ because the
                            # GENERATE_METHOD function will repace the
                            # original $code with something new and
                            # so we need to re-fetch this from the
                            # class, however this will not help the
                            # lexical subroutines, but that might be
                            # fine as they are not easily accessible
                        } = [ @attrs ];
                    }
                    return;
                }
            );
        };

        # install our class finalizers in the
        # reverse order so that the first one
        # encountered goes first, this is the
        # reverse of the usual UNITCHECK way
        # but is what we need here.
        B::CompilerPhase::Hook::append_UNITCHECK {

            # pre-populate the cache for all the slots
            GATHER_ALL_SLOTS( $meta )
                if $meta->isa('MOP::Class');

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

## Private Util Subs

sub GATHER_ALL_SLOTS ($meta) {
    foreach my $super ( map { MOP::Role->new( name => $_ ) } $meta->mro->@* ) {
        foreach my $attr ( $super->slots ) {
            $meta->alias_slot( $attr->name, $attr->initializer )
                unless $meta->has_slot( $attr->name )
                    || $meta->has_slot_alias( $attr->name );
        }
    }
    return;
}

sub GENERATE_METHOD ($meta, $method, $trait, $arg) {

    my $method_name = $method->name;

    # a method will know it's origin stash, but ...
    my $c = MOP::Class->new( $method->origin_stash );

    # we will not be able to find it in the symbol table ...
    unless ( $c->has_method( $method_name ) || $c->has_method_alias( $method_name ) || $c->requires_method( $method_name ) ) {

        #warn $c->has_method( $method_name ) ? 'has method' : 'no method';
        #warn $c->has_method_alias( $method_name ) ? 'has method alias' : 'no method alias';
        #warn $c->requires_method( $method_name ) ? 'requires method' : 'no required method';
        #warn $c->name."::$method_name trying to generate $trait ($arg)";

        # for the time being lets only support
        # ro and rw here, this will likely change ...
        return unless $trait eq 'ro' || $trait eq 'rw';

        # at this point we can assume that we have a lexical
        # method which we need to transform, and in order to
        # do that we need to look at all the methods in this
        # class and find all the ones who 'close over' the
        # lexical method and then re-write their lexical pad
        # to use the accessor method that I will generate.

        # NOTE:
        # we need to delay this until the UNITCHECK phase
        # because we need all the methods of this class to
        # have been compiled, at this moment, they are not.
        B::CompilerPhase::Hook::enqueue_UNITCHECK {
            my $slot_name = $arg || $method_name;
            # now check the class local methods ....
            foreach my $m ( $c->methods ) {
                # get a HASH of the things the method closes over
                my $closed_over = PadWalker::closed_over( $m->body );

                #warn Data::Dumper::Dumper({
                #    class       => $c->name,
                #    method      => $m->name,
                #    closed_over => $closed_over,
                #    trait       => $trait,
                #    looking_for => $method_name,
                #});

                # if the private method is used, then it will be
                # here with a prepended `&` sigil ...
                if ( exists $closed_over->{ '&' . $method_name } ) {
                    # now we know that we have someone using the
                    # lexical method inside the method body, so
                    # we need to generate our accessor accordingly
                    # then this is as simple as assigning the HASH key
                    $closed_over->{ '&' . $method_name } =
                        $trait eq 'ro'
                            ? sub {
                                package DB; @DB::args = (); my () = caller(1);
                                my ($self) = @DB::args;
                                $self->{ $slot_name };
                            }
                            : sub {
                                package DB; @DB::args = (); my () = caller(1);
                                my ($self)  = @DB::args;
                                $self->{ $slot_name } = $_[0] if scalar @_;
                                $self->{ $slot_name };
                            };

                    # okay, now restore the closed over vars
                    # with our new addition...
                    PadWalker::set_closed_over( $m->body, $closed_over );
                }
            }
        };
    }
    # TODO:
    # in this `else` block we are assuming it is not a
    # lexical method, so going about doing the usual
    # stash operations, etc. However, our lexical
    # determination is weak and can be confused easily
    # so we will want to actually do the method lookup
    # that failed in order to get us to this `else` and
    # then take the method we find and compare that
    # to the $code here. This will detect the case of
    # a lexical method and non-lexical method conflicting.
    # - SL
    else {
        # transform here ...
        if ( $trait eq 'ro' ) {
            $trait = 'reader';
            $arg   = $method_name;
        }
        elsif ( $trait eq 'rw' ) {
            $trait = 'writer';
            $arg   = $method_name;
        }

        if ( $trait eq 'predicate' ) {
            my $slot_name = $arg || ($method_name =~ s/^has\_//r); #/

            die 'Unable to find slot `' . $slot_name.'` in `'.$meta->name.'`'
                unless $meta->has_slot( $slot_name )
                    || $meta->has_slot_alias( $slot_name );

            $meta->add_method( $method_name => sub { defined $_[0]->{ $slot_name } } );
        }
        elsif ( $trait eq 'writer' ) {
            my $slot_name = $arg || ($method_name =~ s/^set\_//r); #/

            die 'Unable to find slot `' . $slot_name.'` in `'.$meta->name.'`'
                unless $meta->has_slot( $slot_name )
                    || $meta->has_slot_alias( $slot_name );

            $meta->add_method( $method_name => sub {
                $_[0]->{ $slot_name } = $_[1] if $_[1];
                $_[0]->{ $slot_name };
            });
        }
        elsif ( $trait eq 'reader' ) {
            my $slot_name = $arg || ($method_name =~ s/^get\_//r); #/

            die 'Unable to find slot `' . $slot_name.'` in `'.$meta->name.'`'
                unless $meta->has_slot( $slot_name )
                    || $meta->has_slot_alias( $slot_name );

            $meta->add_method( $method_name => sub {
                die "Cannot assign to `$slot_name`, it is a readonly slot" if scalar @_ != 1;
                $_[0]->{ $slot_name };
            });
        }
        elsif ( $trait eq 'clearer' ) {
            my $slot_name = $arg || ($method_name =~ s/^clear\_//r); #/

            die 'Unable to find slot `' . $slot_name.'` in `'.$meta->name.'`'
                unless $meta->has_slot( $slot_name )
                    || $meta->has_slot_alias( $slot_name );

            $meta->add_method( $method_name => sub { undef $_[0]->{ $slot_name } } );
        }
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





