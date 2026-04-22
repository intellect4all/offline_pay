#!/usr/bin/env bash
#
# Generate a self-signed dev PKI for the offlinepay gRPC server:
#   ca.pem / ca.key        — root CA
#   server.pem / server.key — server cert (SANs cover local dev hosts)
#   client.pem / client.key — one client cert for mTLS testing
#
# DO NOT ship these into any environment that handles real money. The CA key
# is generated here unencrypted for convenience. For staging/prod, swap in
# certs minted by the real PKI (Vault PKI / cert-manager / ACM Private CA).
set -euo pipefail

OUT_DIR="${1:-$(dirname "$0")}"
cd "$OUT_DIR"

DAYS=365
SUBJ_CA="/CN=offlinepay-dev-ca"
SUBJ_SERVER="/CN=offlinepay-server"
SUBJ_CLIENT="/CN=offlinepay-dev-client"

# SANs cover loopback, docker-for-mac gateway, and the Android emulator's
# host-loopback alias. Add more if you test from physical devices on LAN.
SERVER_SAN="DNS:localhost,DNS:host.docker.internal,DNS:offlinepay-server,DNS:server,IP:127.0.0.1,IP:10.0.2.2"

echo "[pki] generating CA"
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days "$DAYS" -out ca.pem -subj "$SUBJ_CA"

echo "[pki] generating server cert ($SERVER_SAN)"
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr -subj "$SUBJ_SERVER"
cat >server.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = $SERVER_SAN
EOF
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -out server.pem -days "$DAYS" -sha256 -extfile server.ext
rm -f server.csr server.ext

echo "[pki] generating client cert"
openssl genrsa -out client.key 4096
openssl req -new -key client.key -out client.csr -subj "$SUBJ_CLIENT"
cat >client.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
  -out client.pem -days "$DAYS" -sha256 -extfile client.ext
rm -f client.csr client.ext

echo "[pki] done. Files in $OUT_DIR:"
ls -1 ca.pem ca.key server.pem server.key client.pem client.key
