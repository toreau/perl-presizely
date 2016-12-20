requires 'CHI';
requires 'Config::JFDI';
requires 'Digest::SHA';
requires 'File::Share';
requires 'FindBin';
requires 'IO::Compress::Gzip';
requires 'IO::Socket::SSL';
requires 'Imager';
requires 'MIME::Base64';
requires 'Mojolicious';
requires 'Mojolicious::Plugin::YamlConfig';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Text::Glob';
requires 'Time::HiRes';
requires 'YAML::XS';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.59';
    requires 'Image::Size';
    requires 'Module::Install';
    requires 'Test::Mojo';
    requires 'Test::More';
};
