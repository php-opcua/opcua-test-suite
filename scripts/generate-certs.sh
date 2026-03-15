#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${CERTS_DIR:-${SCRIPT_DIR}/../certs}"

echo "============================================"
echo "OPC UA Certificate Generator"
echo "============================================"
echo "Output directory: ${CERTS_DIR}"

# Skip generation if certificates already exist (use FORCE_REGEN=1 to regenerate)
if [ "${FORCE_REGEN}" != "1" ] && \
   [ -f "${CERTS_DIR}/ca/ca-cert.pem" ] && \
   [ -f "${CERTS_DIR}/server/cert.pem" ] && \
   [ -f "${CERTS_DIR}/client/cert.pem" ]; then
  echo ""
  echo "Certificates already exist, skipping generation."
  echo "Set FORCE_REGEN=1 or delete ${CERTS_DIR} to regenerate."
  echo "============================================"
  exit 0
fi

# Clean and create directories
rm -rf "${CERTS_DIR}/ca" "${CERTS_DIR}/server" "${CERTS_DIR}/client" "${CERTS_DIR}/self-signed" "${CERTS_DIR}/expired"
mkdir -p "${CERTS_DIR}"/{ca,server,client,self-signed,expired,trusted,rejected,pki/{own/certs,own/private,trusted/certs,rejected/certs,issuers/certs,issuers/crl}}

# ========================
# 1. CA Root Certificate
# ========================
echo ""
echo "[1/5] Generating CA Root Certificate..."

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "${CERTS_DIR}/ca/ca-key.pem" 2>/dev/null

openssl req -new -x509 -key "${CERTS_DIR}/ca/ca-key.pem" \
  -out "${CERTS_DIR}/ca/ca-cert.pem" \
  -days 3650 \
  -subj "/C=IT/ST=Test/L=Test/O=OPC UA Test CA/OU=Testing/CN=OPC UA Test CA" \
  2>/dev/null

echo "  CA certificate created"

# Generate CRL (Certificate Revocation List) for the CA
# node-opcua requires a CRL to verify certificate revocation status
touch "${CERTS_DIR}/ca/index.txt"
echo "01" > "${CERTS_DIR}/ca/crlnumber"

cat > "${CERTS_DIR}/ca/openssl-ca.cnf" << CAEOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = ${CERTS_DIR}/ca
database          = ${CERTS_DIR}/ca/index.txt
crlnumber         = ${CERTS_DIR}/ca/crlnumber
default_md        = sha256
default_crl_days  = 3650
certificate       = ${CERTS_DIR}/ca/ca-cert.pem
private_key       = ${CERTS_DIR}/ca/ca-key.pem
CAEOF

openssl ca -gencrl \
  -config "${CERTS_DIR}/ca/openssl-ca.cnf" \
  -out "${CERTS_DIR}/ca/ca-crl.pem" \
  2>/dev/null

openssl crl -in "${CERTS_DIR}/ca/ca-crl.pem" -outform der -out "${CERTS_DIR}/ca/ca-crl.der" 2>/dev/null

echo "  CA CRL created"

# ========================
# 2. Server Certificate (signed by CA)
# ========================
echo ""
echo "[2/5] Generating Server Certificate..."

# Server key
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "${CERTS_DIR}/server/key.pem" 2>/dev/null

# Server CSR
openssl req -new -key "${CERTS_DIR}/server/key.pem" \
  -out "${CERTS_DIR}/server/server.csr" \
  -subj "/C=IT/ST=Test/L=Test/O=OPC UA Test Server/OU=Testing/CN=OPC UA Test Server" \
  2>/dev/null

# Server extensions for SAN
cat > "${CERTS_DIR}/server/server-ext.cnf" << 'EXTEOF'
[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment, nonRepudiation, dataEncipherment, keyCertSign
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[alt_names]
URI.1 = urn:opcua:test-server:OPCUATestServer
DNS.1 = localhost
DNS.2 = opcua-no-security
DNS.3 = opcua-userpass
DNS.4 = opcua-certificate
DNS.5 = opcua-all-security
DNS.6 = opcua-discovery
DNS.7 = opcua-auto-accept
DNS.8 = opcua-sign-only
DNS.9 = opcua-legacy-security
IP.1 = 127.0.0.1
IP.2 = 0.0.0.0
EXTEOF

# Sign server cert with CA
openssl x509 -req -in "${CERTS_DIR}/server/server.csr" \
  -CA "${CERTS_DIR}/ca/ca-cert.pem" \
  -CAkey "${CERTS_DIR}/ca/ca-key.pem" \
  -CAcreateserial \
  -out "${CERTS_DIR}/server/cert.pem" \
  -days 3650 \
  -extensions v3_req \
  -extfile "${CERTS_DIR}/server/server-ext.cnf" \
  2>/dev/null

# Also create DER format for OPC UA
openssl x509 -in "${CERTS_DIR}/server/cert.pem" -outform der -out "${CERTS_DIR}/server/cert.der" 2>/dev/null
openssl rsa -in "${CERTS_DIR}/server/key.pem" -outform der -out "${CERTS_DIR}/server/key.der" 2>/dev/null

echo "  Server certificate created (PEM + DER)"

# ========================
# 3. Client Certificate (signed by CA)
# ========================
echo ""
echo "[3/5] Generating Client Certificate..."

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "${CERTS_DIR}/client/key.pem" 2>/dev/null

openssl req -new -key "${CERTS_DIR}/client/key.pem" \
  -out "${CERTS_DIR}/client/client.csr" \
  -subj "/C=IT/ST=Test/L=Test/O=OPC UA Test Client/OU=Testing/CN=OPC UA Test Client" \
  2>/dev/null

cat > "${CERTS_DIR}/client/client-ext.cnf" << 'EXTEOF'
[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment, nonRepudiation, dataEncipherment
extendedKeyUsage = clientAuth
subjectAltName = @alt_names
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[alt_names]
URI.1 = urn:opcua:test-client
DNS.1 = localhost
IP.1 = 127.0.0.1
EXTEOF

openssl x509 -req -in "${CERTS_DIR}/client/client.csr" \
  -CA "${CERTS_DIR}/ca/ca-cert.pem" \
  -CAkey "${CERTS_DIR}/ca/ca-key.pem" \
  -CAcreateserial \
  -out "${CERTS_DIR}/client/cert.pem" \
  -days 3650 \
  -extensions v3_req \
  -extfile "${CERTS_DIR}/client/client-ext.cnf" \
  2>/dev/null

openssl x509 -in "${CERTS_DIR}/client/cert.pem" -outform der -out "${CERTS_DIR}/client/cert.der" 2>/dev/null
openssl rsa -in "${CERTS_DIR}/client/key.pem" -outform der -out "${CERTS_DIR}/client/key.der" 2>/dev/null

echo "  Client certificate created (PEM + DER)"

# ========================
# 4. Self-Signed Certificate (for rejection testing)
# ========================
echo ""
echo "[4/5] Generating Self-Signed Certificate (untrusted)..."

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "${CERTS_DIR}/self-signed/key.pem" 2>/dev/null

openssl req -new -x509 -key "${CERTS_DIR}/self-signed/key.pem" \
  -out "${CERTS_DIR}/self-signed/cert.pem" \
  -days 3650 \
  -subj "/C=IT/ST=Test/L=Test/O=Untrusted Client/OU=Testing/CN=Untrusted Client" \
  -addext "subjectAltName=URI:urn:opcua:untrusted-client,DNS:localhost" \
  -addext "keyUsage=digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=clientAuth" \
  2>/dev/null

openssl x509 -in "${CERTS_DIR}/self-signed/cert.pem" -outform der -out "${CERTS_DIR}/self-signed/cert.der" 2>/dev/null

echo "  Self-signed certificate created"

# ========================
# 5. Expired Certificate
# ========================
echo ""
echo "[5/5] Generating Expired Certificate..."

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "${CERTS_DIR}/expired/key.pem" 2>/dev/null

# Create a cert that expired yesterday
openssl req -new -key "${CERTS_DIR}/expired/key.pem" \
  -out "${CERTS_DIR}/expired/expired.csr" \
  -subj "/C=IT/ST=Test/L=Test/O=Expired Client/OU=Testing/CN=Expired Client" \
  2>/dev/null

# Use faketime-like approach: sign with -days 1 and set start date in the past
openssl x509 -req -in "${CERTS_DIR}/expired/expired.csr" \
  -CA "${CERTS_DIR}/ca/ca-cert.pem" \
  -CAkey "${CERTS_DIR}/ca/ca-key.pem" \
  -CAcreateserial \
  -out "${CERTS_DIR}/expired/cert.pem" \
  -days 1 \
  -set_serial 9999 \
  2>/dev/null

# Overwrite with actually expired cert by backdating
openssl ca -batch -config /dev/null 2>/dev/null || true
# Simple approach: create cert valid from 2020-01-01 to 2020-01-02
openssl req -new -x509 -key "${CERTS_DIR}/expired/key.pem" \
  -out "${CERTS_DIR}/expired/cert.pem" \
  -days 1 \
  -subj "/C=IT/ST=Test/L=Test/O=Expired Client/OU=Testing/CN=Expired Client" \
  -addext "subjectAltName=URI:urn:opcua:expired-client,DNS:localhost" \
  2>/dev/null || true

openssl x509 -in "${CERTS_DIR}/expired/cert.pem" -outform der -out "${CERTS_DIR}/expired/cert.der" 2>/dev/null

echo "  Expired certificate created"

# ========================
# Setup trust directories
# ========================
echo ""
echo "Setting up trust directories..."

# Trust the client cert on server side
cp "${CERTS_DIR}/client/cert.pem" "${CERTS_DIR}/trusted/"
cp "${CERTS_DIR}/client/cert.der" "${CERTS_DIR}/trusted/" 2>/dev/null || true

# Setup PKI structure (node-opcua format)
cp "${CERTS_DIR}/server/cert.pem" "${CERTS_DIR}/pki/own/certs/"
cp "${CERTS_DIR}/server/key.pem" "${CERTS_DIR}/pki/own/private/"
cp "${CERTS_DIR}/client/cert.pem" "${CERTS_DIR}/pki/trusted/certs/"
cp "${CERTS_DIR}/ca/ca-cert.pem" "${CERTS_DIR}/pki/issuers/certs/"
cp "${CERTS_DIR}/ca/ca-crl.pem" "${CERTS_DIR}/pki/issuers/crl/"
cp "${CERTS_DIR}/ca/ca-crl.der" "${CERTS_DIR}/pki/issuers/crl/" 2>/dev/null || true

# Self-signed goes to rejected by default
cp "${CERTS_DIR}/self-signed/cert.pem" "${CERTS_DIR}/rejected/"

# Clean up temp files
rm -f "${CERTS_DIR}/server/server.csr" "${CERTS_DIR}/server/server-ext.cnf"
rm -f "${CERTS_DIR}/client/client.csr" "${CERTS_DIR}/client/client-ext.cnf"
rm -f "${CERTS_DIR}/expired/expired.csr"
rm -f "${CERTS_DIR}/ca/ca-cert.srl"
rm -f "${CERTS_DIR}/ca/openssl-ca.cnf" "${CERTS_DIR}/ca/index.txt" "${CERTS_DIR}/ca/index.txt.old" "${CERTS_DIR}/ca/index.txt.attr"
rm -f "${CERTS_DIR}/ca/crlnumber" "${CERTS_DIR}/ca/crlnumber.old"

echo ""
echo "============================================"
echo "Certificate generation complete!"
echo "============================================"
echo ""
echo "Files created:"
echo "  CA:          ${CERTS_DIR}/ca/ca-cert.pem, ca-key.pem"
echo "  Server:      ${CERTS_DIR}/server/cert.pem, key.pem (+ DER)"
echo "  Client:      ${CERTS_DIR}/client/cert.pem, key.pem (+ DER)"
echo "  Self-Signed: ${CERTS_DIR}/self-signed/cert.pem, key.pem"
echo "  Expired:     ${CERTS_DIR}/expired/cert.pem, key.pem"
echo "  Trusted:     ${CERTS_DIR}/trusted/"
echo "  Rejected:    ${CERTS_DIR}/rejected/"
echo "  PKI:         ${CERTS_DIR}/pki/"
