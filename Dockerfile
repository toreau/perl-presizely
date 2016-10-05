FROM perl:latest

ENV DEBIAN_FRONTEND=noninteractive LANG=en_US.UTF-8 LC_ALL=C.UTF-8 LANGUAGE=en_US.UTF-8

WORKDIR /root

COPY cpanfile .

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

# Default options for cpanm
ENV PERL_CPANM_OPT --quiet --no-man-pages --skip-satisfied

# Install third party deps
RUN cpanm --notest --installdeps .

# Install internal deps
RUN cpanm --notest --with-feature=own --installdeps .

# Bust the cache and reinstall internal deps
ADD https://www.random.org/strings/?num=16&len=16&digits=on&upperalpha=on&loweralpha=on&unique=on&format=plain&rnd=new /tmp/CACHEBUST
RUN cpanm --with-feature=own --reinstall --installdeps .

COPY . .

EXPOSE 3000

CMD ./script/presizely prefork -m production -w 16 -c 2
