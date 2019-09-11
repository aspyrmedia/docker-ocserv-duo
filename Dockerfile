FROM alpine:latest
LABEL MAINTAINER="Daniel Hagen <daniel.b.hagen@gmail.com>"

ENV OCSERV_VERSION=0.11.8 \
    PAM_DUO_VERSION=1.11.0-r1 \
    NSS_PAM_LDAPD_VERSION=0.9.8-r0
ENV OCSERV_URL=ftp://ftp.infradead.org/pub/ocserv/ocserv-$OCSERV_VERSION.tar.xz
ENV DUO_IKEY=DISHPO44ZBBXB8RZ9NDO                       \
    DUO_SKEY=YSpUorVwOW3WFzQFz7GEn5xO1tYxNs96z90VdzP6   \
    DUO_API=api-2cb27c3b.duosecurity.com                \
    LDAP_URI=ldap://123.123.123.123:389                 \
    LDAP_DN="dc=example,dc=com"                         \
    VPN_DOMAIN=vpn.example.com                            \
    VPN_NETWORK=10.20.30.0/24                           \
    LAN_NETWORK=192.168.0.0/16                          \
    TERM=xterm

WORKDIR /etc/ocserv

EXPOSE 443/tcp 443/udp
VOLUME ["/etc/ocserv/"]

ENTRYPOINT ["/entrypoint.sh"]

RUN buildDeps=" \
        curl \
        duo_unix=${PAM_DUO_VERSION} \
        g++ \
        gnutls-dev \
        gpgme \
        libev-dev \
        libnl3-dev \
        libseccomp-dev \
        linux-headers \
        linux-pam-dev \
        lz4-dev \
        make \
        nss-dev \
        openldap-dev \
        openssl-dev \
        readline-dev \
        tar \
        wget \
        xz \
    "; \
    set -x \
    && apk add --update --virtual .build-deps $buildDeps \
    && curl -SL ${OCSERV_URL} -o ocserv.tar.xz \
#    && curl -SL $OCSERV_URL.sig -o ocserv.tar.xz.sig \
#    && wget https://ftp.gnu.org/gnu/gnu-keyring.gpg \
#    && gpg --import ./gnu-keyring.gpg \
#    && gpg --keyserver keys.gnupg.net --keyring ./gnu-keyring.gpg -recv-key BE07D9FD54809AB2C4B0FF5F63762CDA67E2F359 \
#    && gpg --keyring ./gnu-keyring.gpg --verify ocserv.tar.xz.sig \
    && mkdir -p /usr/src/ocserv \
    && tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
    && rm ocserv.tar.xz* \
    && cd /usr/src/ocserv \
    && ./configure \
    && make \
    && make install \
    && mkdir -p /etc/ocserv \
    && cp /usr/src/ocserv/doc/sample.config /etc/ocserv/ocserv.conf \
    && cp /usr/src/ocserv/doc/sample.config /etc/ocserv.sample \
    && cd / \
    && rm -rf /usr/src/ocserv \
    && runDeps="$( \
        scanelf --needed --nobanner /usr/local/sbin/ocserv \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | xargs -r apk info --installed \
            | sort -u \
        ) \
        duo_unix=${PAM_DUO_VERSION} \
    " \
    && apk add --virtual .run-deps $runDeps gnutls-utils iptables \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

RUN set -xe \
    && mkdir -p /etc/ocserv/certs \
    && mkdir -p /etc/ocserv/config-per-user \
    && mkdir -p /etc/ocserv/config-per-group \
    && mkdir -p /etc/ocserv/defaults

COPY init.sh /init.sh
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /init.sh /entrypoint.sh