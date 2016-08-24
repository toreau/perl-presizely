package Presizely::Controller::Root;
use Mojo::Base 'Mojolicious::Controller';
use Moose;
use namespace::autoclean;

sub index {
    my $self = shift;

    my @images = (
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/2/20/Hamilton_-_2016_Monaco_GP_02.jpg',
            orig_size => '4,740 × 3,160',
        },
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/d/db/17_Years_of_Sekar_Jepun_2014-11-01_32.jpg',
            orig_size => '2,329 × 1,553',
        },
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/e/e9/Egyptian_food_Koshary.jpg',
            orig_size => '3,031 × 2,101',
        },
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/1/16/The_Shuttle_Enterprise_-_GPN-2000-001363.jpg',
            orig_size => '3,000 × 2,239',
        },
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/7/7a/India_-_Varanasi_green_peas_-_2714.jpg',
            orig_size => '3,504 × 2,336',
        },
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/e/ed/Funifor_Arabba_Porta_Vescovo.jpg',
            orig_size => '7,360 × 4,912',
        },
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/f/fb/Indian_pigments.jpg',
            orig_size => '2,592 × 1,944',
        },
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/0/02/Fire_breathing_2_Luc_Viatour.jpg',
            orig_size => '3,288 × 2,416',
        },
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/a/a8/NASA-Apollo8-Dec24-Earthrise.jpg',
            orig_size => '2,400 × 2,400',
        },
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/2/24/Wwii_woman_worker-edit.jpg',
            orig_size => '7,373 × 5,679',
        },
        {
            url       => 'https://upload.wikimedia.org/wikipedia/commons/7/7e/Hope_Bay-2016-Trinity_Peninsula%E2%80%93Esperanza_Station_02.jpg',
            orig_size => '4,988 × 2,835',
        },
    );

    my $image = $images[ rand @images ];

    $self->render(
        image_url       => $image->{url},
        image_orig_size => $image->{orig_size},
    );
}

# The End

1;
