FROM perl:latest

ENV DEBIAN_FRONTEND=noninteractive LANG=en_US.UTF-8 LC_ALL=C.UTF-8 LANGUAGE=en_US.UTF-8

RUN apt-get update && apt-get install -y \
    build-essential \
    cpanminus \
    libgif-dev \
    libgif4 \
    libjpeg-dev \
    libjpeg62-turbo \
    libjpeg62-turbo-dev \
    libpng-dev \
    libpng12-0 \
    libssl-dev \
    libtiff5 \
    libtiff5-dev \
    openssl \
    && apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN cpanm \
    CHI \
    Digest::SHA \
    Imager \
    IO::Compress::Gzip \
    IO::Socket::SSL \
    Mojolicious \
    Mojolicious::Plugin::YamlConfig \
    Moose \
    namespace::autoclean \
    Text::Glob \
    YAML::XS \
    && rm -rf ~/.cpanm/

COPY . /app/Presizely

WORKDIR /app/Presizely

EXPOSE 3000

ENV MOJO_MAX_MESSAGE_SIZE=33554432

CMD ./script/presizely prefork -m production -w 32 -c 2
