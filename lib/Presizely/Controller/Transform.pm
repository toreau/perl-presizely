package Presizely::Controller::Transform;
use Mojo::Base 'Mojolicious::Controller';
use Moose;
use namespace::autoclean;

use CHI;
use Digest::SHA qw( sha384_hex );
use Imager;
use MIME::Base64;
use Mojo::IOLoop::Subprocess;
use Mojo::URL;
use Mojo::UserAgent;
use Text::Glob qw( match_glob );
use Time::HiRes qw( gettimeofday tv_interval );

has 'ua' => (
    isa => 'Mojo::UserAgent',
    is => 'ro',
    lazy => 1,
    default => sub { Mojo::UserAgent->new( %{shift->config->{ua}} ) },
);

has 'primary_cache' => (
    isa => 'Object',
    is => 'ro',
    lazy => 1,
    default => sub { CHI->new( %{shift->config->{cache}->{primary}} ) },
);

has 'secondary_cache' => (
    isa => 'Object',
    is => 'ro',
    lazy => 1,
    default => sub { CHI->new( %{shift->config->{cache}->{secondary}} ) },
);

sub index {
    my $self = shift;

    # Fetch and parse arguments.
    my $path   = $self->req->url;
    my $params = '';
    my $url    = '';

    if ( $path =~ m,^/(.*?)/((https?|ftp).+)$,i ) {
        $params = $1;
        $url    = $2;

        $params =~ s/\s+//sg;
    }
    elsif ( $path =~ m,^/((https?|ftp).+),i ) {
        $url = $1;
    }
    else {
        return $self->render(
            status => 404,
            text   => 'Page not found!',
        );
    }

    # Is the image host allowed?
    my $host = Mojo::URL->new( $url )->host;

    unless ( $self->_host_is_allowed($host) ) {
        return $self->render(
            status => 500,
            text   => "Image host '" . $host . "' is not allowed!",
        );
    }

    # Sort the params for a better cache key.
    $params   = join( ',', sort split(/\s*,\s*/, $params) );
    $params //= 'none';

    # If the image is in the cache, with the parameters mentioned, return it
    # immediately.
    my $primary_cache_key = Digest::SHA::sha384_hex( $params . '_' . $url );
    my $img_data          = $self->primary_cache->get( $primary_cache_key );

    if ( $img_data ) {
        $self->log->debug( "Retrieved '" . $url . "' (params: " . $params . ") from the primary cache; returning it ASAP!" );

        return $self->_render_image( $img_data, $url );
    }
    else {
        # Try to retrieve the image from the cache, but only based on the URL
        # of it, not the parameters (we've already checked for that).
        my $secondary_cache_key = Digest::SHA::sha384_hex( '_' . $url );

        if ( $img_data = $self->secondary_cache->get($secondary_cache_key) ) {
            $self->log->debug( "Retrieved '" . $url . "' (params: " . $params . ") from the secondary cache!" );
        }
        else {
            $img_data->{image} = $self->_get_img_data_from_url( $url );

            unless ( $img_data ) {
                return $self->render(
                    status => 500,
                    text   => "Failed to retrieve data from the image host for '" . $url . "'!",
                );
            }

            # Cache the image. This is a done in a subprocess in case the cache
            # backend (like a file system) is slow.
            Mojo::IOLoop->subprocess(
                sub {
                    $self->log->debug( "Storing '" . $url . "' (params: " . ($params // 'none') . ") in the secondary cache!" );
                    $self->secondary_cache->set( $secondary_cache_key, $img_data );
                },

                sub {
                    # No need to do anything
                },
            );
        }

        # Process the image, if necessary.
        if ( my $jobs = $self->_get_jobs_from_param_str($params) ) {
            my $imager = eval {
                Imager->new( data => $img_data->{image} );
            };

            if ( $@ || !$imager ) {
                if ( $@ ) {
                    $self->log->error( $@ );
                }

                # Delete from caches.
                $self->primary_cache->remove( $primary_cache_key );
                $self->secondary_cache->remove( $secondary_cache_key );

                # TODO: Find a way to check if image format is supported
                #       earlier on.
                return $self->render(
                    status => 500,
                    text   => "Failed to read image; probably unsupported image format...",
                );
            }

            my $t0 = [ gettimeofday ];

            # Detect the image format.
            unless ( $img_data->{format} = $imager->tags(name => 'i_format') ) {
                return $self->render(
                    status => 500,
                    text   => "Failed to detect the image's format!",
                );
            }

            # Crop?
            if ( my $crop = $jobs->{crop} ) {
                $imager = $imager->crop(
                    width  => $crop->{width},
                    height => $crop->{height},
                    left   => $crop->{x},
                    top    => $crop->{y},
                );
            }

            # Resize?
            if ( my $resize = $jobs->{resize} ) {
                $imager = $self->_resize( $imager, $resize );
            }

            # Rotate?
            # TODO: Default should be transparent background, if possible.
            if ( my $rotation = $jobs->{rotate} ) {
                $self->log->debug( "About to rotate image " . $rotation . " degrees!" );
                $imager = $imager->rotate( degrees => $rotation, back => $self->config->{imager}->{rotation_bg_color} );
            }

            # Change quality?
            # TODO: Warn if previous quality setting and the new setting
            #       somehow conflicts.
            my $quality = undef;

            if ( my $q = $jobs->{quality} ) {
                if ( $q >= 10 && $q <= 100 ) {
                    if ( $img_data->{format} eq 'jpeg' ) {
                        $self->log->debug( "Setting image quality to " . $q );
                        $quality = $q;
                    }
                    else {
                        $self->log->warn( "Can't change quality for '" . $img_data->{format} . "' images; skipping this action!" );
                    }
                }
            }

            # Flip image?
            if ( my $flip = $jobs->{flip} ) {
                $imager = $imager->flip( dir => $flip );
            }

            # Black and white?
            if ( $jobs->{black_and_white} ) {
                $imager = $imager->convert( preset => 'grey' );
            }

            # JPEG only: Optimize?
            my $optimize = 0;

            if ( $jobs->{optimize} ) {
                if ( $img_data->{format} eq 'jpeg' ) {
                    $self->log->debug( 'Optimizing image!' );
                    $optimize = 1;
                }
                else {
                    $self->log->warn( "Can't optimize '" . $img_data->{format} . "' images; skipping this action!" );
                }
            }

            # JPEG only: Make progressive?
            my $progressive = 0;

            if ( $jobs->{progressive} ) {
                if ( $img_data->{format} eq 'jpeg' ) {
                    $self->log->debug( 'Making image progressive!' );
                    $progressive = 1;
                }
                else {
                    $self->log->warn( "Can't make images of type '" . $img_data->{format} . "' progressive; skipping this action!" );
                }
            }

            # Sharpen?
            if ( $jobs->{sh} ) {
                $self->log->debug( 'Sharpening the image!' );

                $imager->filter(
                    type => 'conv',
                    coef =>  [ -2, 10, -2 ],
                );
            }

            # Write the finalized image (and do JPEG stuff, if necessary).
            # TODO: Refactor this, because writing is done multiple places.
            my @options = (
                data => \$img_data->{image},
                type => $img_data->{format},
            );

            push( @options, jpegquality      => $quality ) if ( $quality     );
            push( @options, jpeg_optimize    => 1        ) if ( $optimize    );
            push( @options, jpeg_progressive => 1        ) if ( $progressive );

            eval {
                $imager->write( @options );
            };

            if ( $@ ) {
                # TODO: Return the original image instead of barking? Maybe
                #       make it a config option?
                return $self->render(
                    status => 500,
                    text   => "Failed to apply transformations to image; " . $@,
                );
            }

            # Face detection?
            if ( $jobs->{face_detection} ) {
                if ( my $json = $self->_get_google_vision_data($img_data->{image}) ) {
                    foreach my $annotation ( @{$json->{responses}->[0]->{faceAnnotations}} ) {
                        foreach ( qw(boundingPoly fdBoundingPoly) ) {
                            my $vertices = $annotation->{$_}->{vertices};

                            my $min_x = -1;
                            my $max_x = -1;
                            my $min_y = -1;
                            my $max_y = -1;

                            foreach ( @{$vertices} ) {
                                $min_x = $_->{x} if ( $min_x == -1 || $_->{x} < $min_x );
                                $max_x = $_->{x} if ( $max_x == -1 || $_->{x} > $max_x );
                                $min_y = $_->{y} if ( $min_y == -1 || $_->{y} < $min_y );
                                $max_y = $_->{y} if ( $max_y == -1 || $_->{y} > $max_y );
                            }

                            $imager->box( xmin => $min_x, xmax => $max_x, ymin => $min_y, ymax => $max_y, color => 'white' );
                        }
                    }

                    # TODO: Refactor this, because writing is done multiple places.
                    @options = (
                        data => \$img_data->{image},
                        type => $img_data->{format},
                    );

                    eval {
                        $imager->write( @options );
                    };
                }
            }

            # Done!
            $self->log->debug( "Transformed the image in " . tv_interval( $t0, [gettimeofday] ) . " seconds!" );
        }

        # Cache the image. This is a done in a subprocess in case the cache
        # backend (like a file system) is slow.
        if ( $img_data ) {
            Mojo::IOLoop->subprocess(
                sub {
                    $self->log->debug( "Storing the transformed '" . $url . "' in the primary cache!" );
                    $self->primary_cache->set( $primary_cache_key, $img_data );
                },

                sub {
                    # No need to do anything
                },
            );
        }
    }

    # Output.
    $self->_render_image( $img_data, $url );
}

sub _get_jobs_from_param_str {
    my $self   = shift;
    my $params = shift // '';

    my %jobs = ();

    foreach my $param ( split(/\s*,\s*/, $params) ) {
        if ( $param =~ m/^(\d+\.?\d*)x$/ ) {
            $jobs{resize}->{width} = $1;
        }
        elsif ( $param =~ m/^x(\d+\.?\d*)$/ ) {
            $jobs{resize}->{height} = $1;
        }
        elsif ( $param =~ m/^(\d+\.?\d*)x(\d+\.?\d*)$/ ) {
            $jobs{resize} = {
                width  => $1,
                height => $2,
            };
        }
        elsif ( $param =~ m/^q(\d+)$/ ) {
            $jobs{quality} = $1;
        }
        elsif ( $param =~ m/^r(\-?\d+)$/ ) {
            $jobs{rotate} = $1;
        }
        elsif ( $param =~ m/^f(h|v)$/ ) {
            $jobs{flip} = $1;
        }
        elsif ( $param eq 'bw' ) {
            $jobs{black_and_white} = 1;
        }
        elsif ( $param eq 'o' ) {
            $jobs{optimize} = 1;
        }
        elsif ( $param =~ m/^c(\d+)x(\d+)-(\d+)x(\d+)$/ ) {
            $jobs{crop} = {
                width  => $1,
                height => $2,
                x      => $3,
                y      => $4,
            };
        }
        elsif ( $param eq 'fd' ) {
            $jobs{face_detection} = 1;
        }
        elsif ( $param eq 'prog' ) {
            $jobs{progressive} = 1;
        }
        elsif ( $param eq 'sh' ) {
            $jobs{sh} = 1;
        }
        else {
            $self->log->warn( "Skipping unknown job parameter: " . $param );
        }
    }

    return ( keys %jobs ) ? \%jobs : undef;
}

sub _resize {
    my $self   = shift;
    my $imager = shift;
    my $job    = shift;

    my $width  = $job->{width}  // '';
    my $height = $job->{height} // '';

    $self->log->debug( "About to resize image; width = " . $width . " (was: " . $imager->getwidth . "), height = " . $height . " (was: " . $imager->getheight . ")" );

    if ( $width && $height ) {
        my $type = ( $width =~ m/^\d+\.\d+$/ && $height =~ m/^\d+\.\d+$/ ) ? 'scalefactor' : 'pixels';

        $imager = $imager->scaleX( $type => $width,  qtype => $self->config->{imager}->{scaling_qtype} );
        $imager = $imager->scaleY( $type => $height, qtype => $self->config->{imager}->{scaling_qtype} );
    }
    else {
        if ( $width =~ m/^\d+\.\d+$/ || $height =~ m/^\d+\.\d+$/ ) {
            $imager = $imager->scale( xscalefactor => $width,  qtype => $self->config->{imager}->{scaling_qtype} ) if ( $width  );
            $imager = $imager->scale( yscalefactor => $height, qtype => $self->config->{imager}->{scaling_qtype} ) if ( $height );
        }
        else {
            $imager = $imager->scale( xpixels => $width,  qtype => $self->config->{imager}->{scaling_qtype} ) if ( $width  );
            $imager = $imager->scale( ypixels => $height, qtype => $self->config->{imager}->{scaling_qtype} ) if ( $height );
        }
    }

    $self->log->debug( "The image's new dimension: " . $imager->getwidth . " x " . $imager->getheight );

    return $imager;
}

sub _get_response_from_url {
    my $self = shift;
    my $url  = shift;

    my $t0 = [ gettimeofday ];

    my $response = $self->ua->get( $url )->res;
    $self->log->debug( "Result of GETting '" . $url . "': " . $response->code . ' ' . $response->message . ' (' . tv_interval( $t0, [gettimeofday] ) . ' seconds)' );

    return $response;
}

sub _get_img_data_from_url {
    my $self = shift;
    my $url  = shift;

    my $response = $self->_get_response_from_url( $url );

    if ( $response->is_success ) {
        # If we got HTML back, try to parse it for og/twitter image URL.
        if ( ($response->headers->content_type // '') =~ m,text/html,i ) {
            $self->log->debug( "Got HTML, so going to look for an image in the DOM tree..." );

            my $dom = $response->dom;

            $response = undef;

            my $meta = $dom->at( 'meta[property="og:image"]' ) || $dom->at( 'meta[property="twitter:image"]' );

            if ( $meta ) {
                if ( my $content = $meta->attr('content') ) {
                    if ( $content =~ m,^//.+, ) {
                        $content = 'http:' . $content;
                    }

                    $self->log->debug( 'Found this image URL in the HTML: ' . $content );

                    $response = $self->_get_response_from_url( $content );
                }
            }
        }
    }

    return ( defined $response && $response->is_success ) ? $response->body : undef;
}

sub _host_is_allowed {
    my $self = shift;
    my $host = shift;

    my $allowed_hosts = $self->config->{allowed_hosts} || [];

    if ( scalar(@{$allowed_hosts}) ) {
        my $allowed = 0;

        foreach ( @{$allowed_hosts} ) {
            if ( match_glob($_, $host) ) {
                $allowed = 1;
                last;
            }
        }

        return $allowed;
    }
    else {
        return 1;
    }
}

sub _render_image {
    my $self       = shift;
    my $img_data   = shift;
    my $url        = shift;

    # Cache control? Default is NO caching.
    $self->res->headers->cache_control( 'private, max-age=0, no-cache' );

    if ( my $cache_control = $self->config->{output}->{cache_control} ) {
        if ( my $max_age = $cache_control->{max_age} ) {
            $self->res->headers->cache_control( 'public, max-age=' . $max_age );
        }
    }

    # If we're missing the image's format, we need to retrieve it again.
    # TODO: This happens only (?) when no transformations are done, i.e.
    #       forwarding the original picture. See if it can be done elsewhere.
    unless ( $img_data->{format} ) {
        my $imager = Imager->new( data => $img_data->{image} );
        $img_data->{format} = $imager->tags( name => 'i_format' );
    }

    # Output image.
    return $self->render(
        status => 200,
        format => $img_data->{format},
        data   => $img_data->{image},
    );
}

sub _get_google_vision_data {
    my $self  = shift;
    my $image = shift;

    my $service_url = 'https://vision.googleapis.com/v1/images:annotate';
    my $api_key     = $self->config->{google_vision}->{api_key} // '';

    unless ( length $api_key ) {
        $self->log->warn( "Presizely was asked to do face detection, but the Google Vision API key is missing!" );
        return {};
    }

    my $base64    = encode_base64( $image );
    my $cache_key = Digest::SHA::sha384_hex( $base64 );
    my $json      = $self->secondary_cache->get( $cache_key );

    unless ( $json ) {
        my %post = (
            requests => [
                {
                    image => {
                        content => $base64,
                    },

                    features => [
                        {
                            type => 'FACE_DETECTION',
                            maxResults => $self->config->{google_vision}->{face_detection}->{max_results},
                        },
                    ],
                },
            ],
        );

        $json = $self->ua->post( $service_url . '?key=' . $api_key, json => \%post )->res->json;

        if ( $json ) {
            Mojo::IOLoop->subprocess(
                sub {
                    $self->secondary_cache->set( $cache_key, $json );
                },

                sub {
                    # No need to do anything
                },
            );
        }
    }

    return $json;
}

# The End

1;
