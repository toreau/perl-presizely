package Presizely;
use Mojo::Base 'Mojolicious';

use IO::Compress::Gzip 'gzip';
use Presizely::Config;
use Presizely::Log;

our $VERSION = '0.01';

sub startup {
    my $self = shift;

    # Set ENV variables.
    $ENV{MOJO_MAX_MESSAGE_SIZE} = 64 * ( 1024 * 1024 ); # 64MB

    # Setup helpers, routes and hooks.
    $self->_setup_helpers;
    $self->_setup_routes;
    $self->_setup_hooks;

    # Assign this application's secrets.
    $self->secrets( $self->config->{secrets} );

    # Done.
    $self->log->debug( 'APPLICATION STARTED UP!' );
}

sub _setup_helpers {
    my $self = shift;

    $self->helper( config => sub { Presizely::Config->new->config } );
    $self->helper( log    => sub { Presizely::Log->new            } );
}

sub _setup_routes {
    my $self = shift;

    my $r = $self->routes;

    $r->get( '/' )     ->to( 'root#index'      );
    $r->get( '/*path' )->to( 'transform#index' );
}

sub _setup_hooks {
    my $self = shift;

    $self->hook(
        after_render => sub {
            my $c      = shift;
            my $output = shift;
            my $format = shift;

            # If the format is HTML, we want to strip away newlines followed
            # by spaces to make the HTML more compact.
            if ( $format eq 'html' && $c->config->{output}->{trim_html} ) {
                $$output =~ s/\n+\s+/\n/sg;
            }

            # GZIP-compress the output?
            if ( ($c->req->headers->accept_encoding // '') =~ /gzip/i && $c->config->{output}->{gzip_compress} ) {
                $c->res->headers->content_encoding( 'gzip' );
                gzip $output, \my $compressed;

                $$output = $compressed;
            }
        },
    );
}

1;
