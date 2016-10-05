use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use Image::Size qw( imgsize );

my $t = Test::Mojo->new( 'Presizely' );

my @tests = (
    {
        path         => '/',
        status_is    => 200,
        content_like => qr/Presizely is an easy-to-use online service for transforming images/,
    },
    {
        path         => '/1024x',
        status_is    => 404,
        content_like => qr/Page not found/,
    },
    {
        path         => '/1024x/http://aursand.no/sneakers.png',
        status_is    => 200,
    },
);

foreach ( @tests ) {
    if ( my $content_like = $_->{content_like} ) {
        $t->get_ok( $_->{path} )->status_is( $_->{status_is} )->content_like( $_->{content_like} );
    }
    else {
        $t->get_ok( $_->{path} )->status_is( $_->{status_is} );
    }
}

my @test_imgs = (
    {
        path   => '/1024x/https://upload.wikimedia.org/wikipedia/commons/7/7a/India_-_Varanasi_green_peas_-_2714.jpg',
        width  => 1024,
        height => 683,
    },
);

foreach ( @test_imgs ) {
    my $body = $t->get_ok( $_->{path} )->tx->res->body;
    my ( $width, $height ) = imgsize( \$body );

    is( $width,  $_->{width},  'width is OK'  );
    is( $height, $_->{height}, 'height is OK' );
}

done_testing;
