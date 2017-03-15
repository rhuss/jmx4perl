# ==================================================
# Dockerfile for jmx4perl Tools
# ==================================================
FROM alpine:3.2

# The less command from alpine does not interpret color escapes (no -R switch)
ENV JMX4PERL_VERSION=1.12 PAGER=cat

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
    openssl-dev \
 && cpan App::cpanminus < /dev/null \
 && cpanm install -n Term::ReadKey \
    # pin Term-Clui version, the 1.71 has a broken META.yml
    # cf. https://rt.cpan.org/Public/Bug/Display.html?id=120160
 && cpanm PJB/Term-Clui-1.70.tar.gz \
 && cpanm install \
    JSON::XS \
    Term::ReadLine::Gnu \
    LWP::Protocol::https \
    XML::LibXML \
 && cpanm install ROLAND/jmx4perl-${JMX4PERL_VERSION}.tar.gz \
 && rm -rf /var/cache/apk/* \
 && apk del \
    build-base \
    perl-dev \
    readline-dev \
    ncurses-dev \
    expat-dev \
 && mkdir /jolokia

WORKDIR /jolokia
VOLUME /jolokia

CMD [ "jmx4perl", "--version" ]



