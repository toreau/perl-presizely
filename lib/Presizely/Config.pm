package Presizely::Config;
use Moose;
use namespace::autoclean;

use Config::JFDI;
use File::Share qw( dist_dir );
use FindBin;

has '_name' => (
    isa => 'Str',
    is => 'ro',
    lazy => 1,
    default => 'presizely',
);

has '_sharedir' => (
    isa => 'Str',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;

        return ( eval { dist_dir($self->_name) } || 'share' );
    },
);

has 'config' => (
    isa => 'HashRef',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;

        my $config = $self->_get_config_from_path( $self->_sharedir );

        unless ( $config->found ) {
            $config = $self->_get_config_from_path( $FindBin::Bin . '/../' . $self->_sharedir );
        }

        unless ( $config->found ) {
            die "FATAL: COULDN'T FIND THE APPLICATION'S CONFIG!\n";
        }

        return $config->get;
    },
);

sub _get_config_from_path {
    my $self = shift;
    my $path = shift;

    my $config = Config::JFDI->new(
        name                => $self->_name,
        path                => $path,
        config_local_suffix => ( ($ENV{HARNESS_ACTIVE} || ($ENV{MOJO_MODE} && $ENV{MOJO_MODE} eq 'testing')) ? 'test' : 'local' ),
    );

    return $config;
}

__PACKAGE__->meta->make_immutable;

1;
