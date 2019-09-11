FROM alpine:latest
LABEL MAINTAINER="Daniel Hagen <daniel.b.hagen@gmail.com>"

ENV RADCLI_VERSION=1.2.11 \
    OCSERV_VERSION=0.11.8
ENV RADCLI_URL=https://github.com/radcli/radcli/releases/download/${RADCLI_VERSION}/radcli-${RADCLI_VERSION}.tar.gz \
    OCSERV_URL=ftp://ftp.infradead.org/pub/ocserv/ocserv-${OCSERV_VERSION}.tar.xz
ENV VPN_DOMAIN=vpn.example.com               \
    VPN_NETWORK=10.20.30.0/24                \
    LAN_NETWORK=192.168.0.0/16               \
    RADIUS_CLIENT_NAME=vpn.example.com       \
    RADIUS_SERVER_ADDRESS=radius.example.com \
    RADIUS_SERVER_PORT=1812                  \
    RADIUS_SERVER_SECRET=makethissecret      \
    TERM=xterm

WORKDIR /etc/ocserv

EXPOSE 443/tcp 443/udp
VOLUME ["/etc/ocserv/"]

ENTRYPOINT ["/entrypoint.sh"]

RUN buildDeps=" \
        curl \
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
        openssl-dev \
        readline-dev \
        tar \
        wget \
        xz \
    "; \
    set -x \
    && apk add --update --virtual .build-deps $buildDeps \
    && curl -SL ${RADCLI_URL} -o radcli.tar.xz \
    && curl -SL ${OCSERV_URL} -o ocserv.tar.xz \
#    && curl -SL $OCSERV_URL.sig -o ocserv.tar.xz.sig \
#    && wget https://ftp.gnu.org/gnu/gnu-keyring.gpg \
#    && gpg --import ./gnu-keyring.gpg \
#    && gpg --keyserver keys.gnupg.net --keyring ./gnu-keyring.gpg -recv-key BE07D9FD54809AB2C4B0FF5F63762CDA67E2F359 \
#    && gpg --keyring ./gnu-keyring.gpg --verify ocserv.tar.xz.sig \
    && mkdir -p /usr/src/radcli \
    && tar -xf radcli.tar.xz -C /usr/src/radcli --strip-components=1 \
    && rm radcli.tar.xz* \
    && mkdir -p /usr/src/ocserv \
    && tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
    && rm ocserv.tar.xz* \
    \
    && cd /usr/src/radcli \
    && ./configure \
    && make \
    && make install \
    && cd /usr/src/ocserv \
    && ./configure \
    && make \
    && make install \
    \
    && mkdir -p /etc/ocserv \
    && cp /usr/src/ocserv/doc/sample.config /etc/ocserv/ocserv.conf \
    && cp /usr/src/ocserv/doc/sample.config /etc/ocserv.sample \
    && cd / \
    && rm -rf /usr/src/radcli \
    && rm -rf /usr/src/ocserv \
    && runDeps="$( \
        scanelf --needed --nobanner /usr/local/sbin/ocserv \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | xargs -r apk info --installed \
            | sort -u \
        ) \
    " \
    && apk add --virtual .run-deps $runDeps gnutls-utils iptables \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

RUN set -xe \
    && mkdir -p /etc/ocserv/certs \
    && mkdir -p /etc/ocserv/config-per-user \
    && mkdir -p /etc/ocserv/config-per-group \
    && mkdir -p /etc/ocserv/defaults \
    && mkdir -p /etc/radcli/

COPY dictionary /etc/radcli/dictionary
COPY init.sh /init.sh
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /init.sh /entrypoint.sh