# ==================================================
# Dockerfile for jmx4perl Tools
# ==================================================
FROM alpine:3.2

ENV JMX4PERL_VERSION 1.12

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
    gnupg1 \
 && cpan App::cpanminus < /dev/null \
 && cpanm install -n Term::ReadKey \
 && cpanm install \
    JSON::XS \
    Term::ReadLine::Gnu \
 && cpanm install ROLAND/jmx4perl-${JMX4PERL_VERSION}.tar.gz \
 && rm -rf /var/cache/apk/* \
 && apk del \
    build-base \
    perl-dev \
    readline-dev \
    ncurses-dev \
    libxml2-dev \
    expat-dev \
 && mkdir /jolokia

WORKDIR /jolokia
VOLUME /jolokia

CMD [ "jmx4perl", "--version" ]



