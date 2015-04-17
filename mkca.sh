#!/bin/bash
##
##  mkca.sh -- Create Certificate Authority
##  Copyright (c) 2011-2015 Michael Bekaert, All Rights Reserved. 
##
##  This script is derived from mkcert.sh from the mod_ssl distribution.
##  gid-mkcert.sh -- Create Certificates for Global Server ID facility
##  Copyright (c) 1998-2001 Ralf S. Engelschall, All Rights Reserved. 
##
##  It requires OpenSSL 0.9.4.
##

#   parameters
openssl="openssl"
sslcrtdir="."
sslcsrdir="."
sslkeydir="."
sslbit="4096"

#   some optional terminal sequences
case $TERM in
    xterm|xterm*|vt220|vt220*)
        T_MD=$(echo dummy | awk '{ printf("%c%c%c%c", 27, 91, 49, 109); }')
        T_ME=$(echo dummy | awk '{ printf("%c%c%c", 27, 91, 109); }')
        ;;
    vt100|vt100*)
        T_MD=$(echo dummy | awk '{ printf("%c%c%c%c%c%c", 27, 91, 49, 109, 0, 0); }')
        T_ME=$(echo dummy | awk '{ printf("%c%c%c%c%c", 27, 91, 109, 0, 0); }')
        ;;
    default)
        T_MD=''
        T_ME=''
        ;;
esac

#   find some random files
#   (do not use /dev/random here, because this device 
#   doesn't work as expected on all platforms)
randfiles=''
for file in /var/log/messages /var/adm/messages \
            /kernel /vmunix /vmlinuz \
            /etc/hosts /etc/resolv.conf; do
    if [ -f $file ]; then
        if [ ".$randfiles" = . ]; then
            randfiles="$file"
        else
            randfiles="${randfiles}:$file"
        fi
    fi
done

echo "${T_MD}mkca.sh -- Create Certificate Authority${T_ME}"

if [ ! -f $sslcrtdir/ca.crt ]; then
    echo ""
    echo "${T_MD}Generating custom Certificate Authority (CA)${T_ME}"
    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}STEP 1: Generating RSA private key for CA (${sslbit} bit)${T_ME}"
    if [ ! -f "$HOME/.rnd" ]; then
        touch "$HOME/.rnd"
    fi
    if [ ".$randfiles" != . ]; then
        $openssl genrsa -aes256 -rand $randfiles \
                        -out $sslkeydir/ca.key \
                        $sslbit
    else
        $openssl genrsa -aes256 -out $sslkeydir/ca.key \
                        $sslbit
    fi
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate RSA private key" 1>&2
        exit 1
    fi
    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}STEP 2: Generating X.509 certificate signing request for CA${T_ME}"
    cat >.mkcert.cfg <<EOT
[ req ]
default_bits                    = ${sslbit}
distinguished_name              = req_DN
[ req_DN ]
countryName                     = "1. Country Name             (2 letter code)"
countryName_default             = WF
countryName_min                 = 2
countryName_max                 = 2
0.organizationName              = "4. Organization Name        (eg, company)  "
0.organizationName_default      = Certificate Authority World Dominators
organizationalUnitName          = "5. Organizational Unit Name (eg, section)  "
organizationalUnitName_default  = Certificate Authority
commonName                      = "6. Common Name              (eg, CA name)  "
commonName_max                  = 64
commonName_default              = Certificate Authority World Dominators CA
emailAddress                    = "7. Email Address            (eg, name@FQDN)"
emailAddress_max                = 40
emailAddress_default            = ca@cawd.wf
EOT
    $openssl req -nodes -sha512 -newkey rsa:$sslbit \
                 -config .mkcert.cfg \
                 -new \
                 -key $sslkeydir/ca.key \
                 -out $sslcsrdir/ca.csr
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate certificate signing request" 1>&2
        exit 1
    fi
    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}STEP 3: Generating X.509 certificate for CA signed by itself${T_ME}"
    cat >.mkcert.cfg <<EOT
extensions = x509v3
[ x509v3 ]
subjectAltName   = email:copy
basicConstraints = CA:true,pathlen:0
nsComment        = "Certificate Authority World Dominators"
nsCertType       = sslCA
EOT
    $openssl x509 -extfile .mkcert.cfg \
                  -sha512 \
                  -days 3650 \
                  -signkey $sslkeydir/ca.key \
                  -in  $sslcsrdir/ca.csr -req \
                  -out $sslcrtdir/ca.crt
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate self-signed CA certificate" 1>&2
        exit 1
    fi
    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}RESULT:${T_ME}"
    echo '01' >.mkca.serial
    $openssl verify $sslcrtdir/ca.crt
    if [ $? -ne 0 ]; then
        echo "Error: Failed to verify resulting X.509 certificate" 1>&2
        exit 1
    fi
    rm -f .mkcert.cfg .$randfiles
    chmod 400 $sslkeydir/ca.key $sslcsrdir/ca.csr $sslcrtdir/ca.crt
    echo -e "${T_MD}.mkca.serial${T_ME}\t\tCA serial number(local shared)"
    echo -e "${T_MD}$sslkeydir/ca.key${T_ME}\t\tPrivate Key (private)"
    echo -e "${T_MD}$sslcsrdir/ca.csr${T_ME}\t\tCertificate Signing Request (public)"
    echo -e "${T_MD}$sslcrtdir/ca.crt${T_ME}\t\tCertificate (public)"
fi
