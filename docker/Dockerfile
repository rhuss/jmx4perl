# ==================================================
# Dockerfile for jmx4perl Tools
# ==================================================
FROM alpine:3.11

# The less command from alpine does not interpret color escapes (no -R switch)
ENV JMX4PERL_VERSION=1.13 PAGER=cat

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
    openssl \
    openssl-dev \
 && cpan App::cpanminus < /dev/null \
 && cpanm install -n Term::ReadLine::Gnu \
 && cpanm install Term::ReadKey \
    JSON::XS \
    LWP::Protocol::https \
    XML::LibXML \
    Term::Clui \
 && cpanm install ROLAND/jmx4perl-${JMX4PERL_VERSION}.tar.gz \
 && rm -rf /var/cache/apk/* \
 && apk del \
    build-base \
    perl-dev \
    readline-dev \
    ncurses-dev \
    expat-dev \
    openssl-dev \
 && mkdir /jolokia

WORKDIR /jolokia
VOLUME /jolokia

CMD [ "jmx4perl", "--version" ]
