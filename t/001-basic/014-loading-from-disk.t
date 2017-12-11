#!perl

use strict;
use warnings;

use File::Basename ();
use File::Spec     ();
use lib File::Spec->catdir( File::Spec->rel2abs( File::Basename::dirname(__FILE__) ), '../lib' );

use Test::More;

use Foo::Bar;

my $foo = Foo::Bar->new;
ok( $foo->isa( 'Foo::Bar' ), '... the object is from class Foo' );
ok( $foo->isa( 'Moxie::Object' ), '... the object is derived from class Object' );
ok( $foo->isa( 'UNIVERSAL::Object' ), '... the object is derived from base Object' );

done_testing;
