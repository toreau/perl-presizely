package Presizely;
use Mojo::Base 'Mojolicious';

use IO::Compress::Gzip 'gzip';
use Presizely::Log;

# ABSTRACT: Easy-to-use online service for transforming images.

our $VERSION = '0.05';

# TODO: hmac signatures.
# TODO: Better "allowed hosts" functionality.
# TODO: Consider Etag.
# TODO: Allow _local configuration files.
# TODO: Refactor the Transform controller.
# SOLVED: Cache transformed images after they have been delivered to the client.
# SOLVED: Send correct Content-Type.
# SOLVED: Max. cache size setting; see CHI's discard policy. (This can be set
#         in the configuration file with the 'max_size' parameter.)

sub startup {
    my $self = shift;

    # Setup helpers, routes and hooks.
    $self->_setup_config;
    $self->_setup_helpers;
    $self->_setup_routes;
    $self->_setup_hooks;

    # Check if config was loaded.
    # TODO: Better configuration checking.
    unless ( keys %{$self->config} ) {
        $self->log->fatal( 'Invalid configuration!' );
        die;
    }

    # Set ENV variables.
    $ENV{MOJO_MAX_MESSAGE_SIZE} = $self->config->{ua}->{MOJO_MAX_MESSAGE_SIZE};

    # Assign this application's secrets.
    $self->secrets( $self->config->{app}->{secrets} );

    # Done!
    $self->log->debug( 'Application started!' );
}

sub _setup_config {
    my $self = shift;

    my $config = $self->plugin(yaml_config => {
        file      => 'share/presizely.yml',
        stash_key => 'conf',
        class     => 'YAML::XS'
    });

    $self->{config} = $config;
}

sub _setup_helpers {
    my $self = shift;

    $self->helper( log => sub { Presizely::Log->new } );
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
