requires 'CHI';
requires 'Digest::SHA';
requires 'IO::Compress::Gzip';
requires 'IO::Socket::SSL';
requires 'Imager';
requires 'Mojolicious';
requires 'Mojolicious::Plugin::YamlConfig';
requires 'Moose';
requires 'Text::Glob';
requires 'YAML::XS';
requires 'namespace::autoclean';
requires 'perl', '5.010001';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.59';
    requires 'Image::Size';
    requires 'Module::Install';
    requires 'Test::Mojo';
    requires 'Test::More';
};
