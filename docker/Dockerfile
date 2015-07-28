# ==================================================
# Dockerfile for jmx4perl Tools
# ==================================================

FROM alpine:3.2

RUN apk add --update \
    build-base \
    wget \
    perl \
    perl-dev \
    readline \
    readline-dev \
    ncurses \
    ncurses-dev \
    libxml2-dev \
    expat-dev \
    gnupg1

RUN cpan App::cpanminus < /dev/null

RUN cpanm install -n Term::ReadKey

RUN cpanm install \
    JSON::XS \
    Term::ReadLine::Gnu

RUN cpanm install JMX::Jmx4Perl

RUN rm -rf /var/cache/apk/*

RUN apk del \
    build-base \
    perl-dev \
    readline-dev \
    ncurses-dev \
    libxml2-dev \
    expat-dev

