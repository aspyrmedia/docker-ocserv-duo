#!/bin/sh

set -e

mkdir -p /etc/ocserv/certs
mkdir -p /etc/ocserv/config-per-user
mkdir -p /etc/ocserv/config-per-group
mkdir -p /etc/ocserv/defaults
touch /etc/ocserv/defaults/user.conf
touch /etc/ocserv/defaults/group.conf

#sed -i -e 's@ikey = INTEGRATION_KEY@ikey = '"${DUO_IKEY}"'@' \
#              -e 's@skey = SECRET_KEY@skey = '"${DUO_SKEY}"'@' \
#              -e 's@host = API_HOSTNAME@host = '"${DUO_API}"'@' \
#              /etc/duo/pam_duo.conf
#echo "DUO MFA Intigration Key: ${DUO_IKEY}"

if [ ! -f /etc/ocserv/ocpasswd ]; then
    touch /etc/ocserv/ocpasswd
    echo "${VPN_PASSWORD}" | ocpasswd -c /etc/ocserv/ocpasswd "${VPN_USERNAME}"
fi

printf "uri ${LDAP_URI}\n\
base ${LDAP_DN}\n\
uid nslcd\n\
gid nslcd\n" > /etc/nslcd.conf

printf "passwd:   files ldap\n\
group:  files ldap\n\
shadow: files ldap\n" > /etc/nsswitch.conf

if [ ! -f /etc/ocserv/ocserv.conf ]; then
    cp /etc/ocserv.sample /etc/ocserv/ocserv.conf

    sed -i -e 's@\./sample.passwd@/etc/ocserv/ocpasswd@' \
              -e 's@\.\./tests/@/etc/ocserv/@' \
              -e 's@^#cert-group-oid =@cert-group-oid =@' \
              -e 's@^#compression =.*@compression = true@' \
              -e 's@^#config-per-@config-per-@' \
              -e 's@^auth = "plain@#auth = "plain@' \
              -e 's@^#default-@default-@' \
              -e 's@^default-domain@#&@' \
              -e 's@^dns =.*@dns = 8.8.8.8@' \
              -e 's@^max-clients =.*@max-clients = 0@' \
              -e 's@^max-same-clients =.*@max-same-clients = 0@' \
              -e 's@^route@#&@' \
              -e 's@^try-mtu-discovery =.*@try-mtu-discovery = true@' \
              /etc/ocserv/ocserv.conf
fi

if [ -f /etc/ocserv/certs/server-cert.pem ]
then
    echo "Initialized!"
    exit 0
else
    echo "Initializing ..."
fi

mkdir -p /etc/ocserv/certs
cd /etc/ocserv/certs

cat > ca.tmpl <<_EOF_
cn = "ocserv Root CA"
organization = "ocserv"
serial = 1
expiration_days = 3650
ca
signing_key
cert_signing_key
crl_signing_key
_EOF_

cat > server.tmpl <<_EOF_
cn = "${VPN_DOMAIN}"
dns_name = "${VPN_DOMAIN}"
organization = "ocserv"
serial = 2
expiration_days = 365
encryption_key
signing_key
tls_www_server
_EOF_

cat > client.tmpl <<_EOF_
cn = "client@${VPN_DOMAIN}"
uid = "client"
unit = "ocserv"
expiration_days = 365
signing_key
tls_www_client
_EOF_

# gen ca keys
certtool --generate-privkey \
         --outfile ca-key.pem

certtool --generate-self-signed \
         --load-privkey /etc/ocserv/certs/ca-key.pem \
         --template ca.tmpl \
         --outfile ca.pem

# gen server keys
certtool --generate-privkey \
         --outfile server-key.pem

certtool --generate-certificate \
         --load-privkey server-key.pem \
         --load-ca-certificate ca.pem \
         --load-ca-privkey ca-key.pem \
         --template server.tmpl \
         --outfile server-cert.pem

# gen client keys
certtool --generate-privkey \
         --outfile client-key.pem

certtool --generate-certificate \
         --load-privkey client-key.pem \
         --load-ca-certificate ca.pem \
         --load-ca-privkey ca-key.pem \
         --template client.tmpl \
         --outfile client-cert.pem

certtool --to-p12 \
         --pkcs-cipher 3des-pkcs12 \
         --load-ca-certificate ca.pem \
         --load-certificate client-cert.pem \
         --load-privkey client-key.pem \
         --outfile client.p12 \
         --outder \
         --p12-name "${VPN_DOMAIN}" \
         --password "${VPN_PASSWORD}"

sed -i -e "s@^ipv4-network =.*@ipv4-network = ${VPN_NETWORK}@" \
       -e "s@^ipv4-netmask =.*@ipv4-netmask = ${VPN_NETMASK}@" \
       -e "s@^no-route =.*@no-route = ${LAN_NETWORK}/${LAN_NETMASK}@" /etc/ocserv/ocserv.conf

echo "${VPN_PASSWORD}" | ocpasswd -c /etc/ocserv/ocpasswd "${VPN_USERNAME}"