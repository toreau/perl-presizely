package Presizely::Log;
use Moose;
use namespace::autoclean;

use Mojo::Log;

has '_log' => (
    isa => 'Mojo::Log',
    is => 'ro',
    lazy => 1,
    default => sub { Mojo::Log->new },
);

sub debug { shift->_log->debug(@_) }
sub info  { shift->_log->info (@_) }
sub warn  { shift->_log->warn (@_) }
sub error { shift->_log->error(@_) }
sub fatal { shift->_log->fatal(@_) }

__PACKAGE__->meta->make_immutable;

1;
