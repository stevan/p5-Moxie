#!perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN {
    use_ok('MOP');
}

package Point {
    use Moxie;

    extends 'Moxie::Object';

    has '$!x' => sub { 0 };
    has '$!y' => sub { 0 };

    sub x : ro($!x);
    sub y : ro($!y);

    sub set_x : wo($!x);
    sub set_y : wo($!y);

    sub clear ($self) {
        @{ $self }{'$!x', '$!y'} = (0, 0);
    }

    sub pack ($self) {
        +{ x => $self->x, y => $self->y }
    }
}

# ... subclass it ...

package Point3D {
    use Moxie;

    extends 'Point';

    has '$!z' => sub { 0 };

    sub z     : ro($!z);
    sub set_z : wo($!z);

    sub pack ($self) {
        my $data = $self->next::method;
        $data->{z} = $self->{'$!z'};
        $data;
    }
}

## Test an instance
subtest '... test an instance of Point' => sub {
    my $p = Point->new;
    isa_ok($p, 'Point');

    is_deeply(
        mro::get_linear_isa('Point'),
        [ 'Point', 'Moxie::Object', 'UNIVERSAL::Object' ],
        '... got the expected linear isa'
    );

    is $p->x, 0, '... got the default value for x';
    is $p->y, 0, '... got the default value for y';

    $p->set_x(10);
    is $p->x, 10, '... got the right value for x';

    $p->set_y(320);
    is $p->y, 320, '... got the right value for y';

    is_deeply $p->pack, { x => 10, y => 320 }, '... got the right value from pack';
};

## Test the instance
subtest '... test an instance of Point3D' => sub {
    my $p3d = Point3D->new();
    isa_ok($p3d, 'Point3D');
    isa_ok($p3d, 'Point');

    is_deeply(
        mro::get_linear_isa('Point3D'),
        [ 'Point3D', 'Point', 'Moxie::Object', 'UNIVERSAL::Object' ],
        '... got the expected linear isa'
    );

    is $p3d->z, 0, '... got the default value for z';

    $p3d->set_x(10);
    is $p3d->x, 10, '... got the right value for x';

    $p3d->set_y(320);
    is $p3d->y, 320, '... got the right value for y';

    $p3d->set_z(30);
    is $p3d->z, 30, '... got the right value for z';

    is_deeply $p3d->pack, { x => 10, y => 320, z => 30 }, '... got the right value from pack';
};

subtest '... meta test' => sub {

    my @MOP_object_methods = qw[
        new BUILDARGS CREATE DESTROY
    ];

    my @Point_methods = qw[
        x set_x
        y set_y
        pack
        clear
    ];

    my @Point3D_methods = qw[
        z set_z
        clear
    ];

    subtest '... test Point' => sub {

        my $Point = MOP::Class->new( name => 'Point' );
        isa_ok($Point, 'MOP::Class');
        isa_ok($Point, 'UNIVERSAL::Object');

        is_deeply($Point->mro, [ 'Point', 'Moxie::Object', 'UNIVERSAL::Object' ], '... got the expected mro');
        is_deeply([ $Point->superclasses ], [ 'Moxie::Object' ], '... got the expected superclasses');

        foreach ( @Point_methods ) {
            ok($Point->has_method( $_ ), '... Point has method ' . $_);

            my $m = $Point->get_method( $_ );
            isa_ok($m, 'MOP::Method');
            is($m->name, $_, '... got the right method name (' . $_ . ')');
            ok(!$m->is_required, '... the ' . $_ . ' method is not a required method');
            is($m->origin_stash, 'Point', '... the ' . $_ . ' method was defined in Point class')
        }

        ok(Point->can( $_ ), '... Point can call method ' . $_)
            foreach @MOP_object_methods, @Point_methods;

        {
            my $m = $Point->get_method( 'set_y' );
            is_deeply([ $m->get_code_attributes ], [['wo', ['$!y'], 'wo($!y)']], '... we show one CODE attribute');
        }

        {
            my $m = $Point->get_method( 'y' );
            is_deeply([ $m->get_code_attributes ], [['ro', ['$!y'], 'ro($!y)']], '... we show one CODE attribute');
        }

    };

};

done_testing;


