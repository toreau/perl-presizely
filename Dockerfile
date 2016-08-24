FROM perl:latest

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
    openssl && apt-get clean

RUN cpanm \
    CHI \
    Config::JFDI \
    Digest::SHA \
    File::Share \
    FindBin \
    Imager \
    IO::Compress::Gzip \
    IO::Socket::SSL \
    Mojolicious \
    Moose \
    namespace::autoclean \
    YAML::XS

COPY . /app/Presizely

WORKDIR /app/Presizely

EXPOSE 3000

ENV MOJO_MAX_MESSAGE_SIZE=33554432

CMD ./script/presizely prefork -m production -w 32 -c 2
