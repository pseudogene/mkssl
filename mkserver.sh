#!/bin/bash
##
##  mkserver.sh -- Create Certificate Authority
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

echo "${T_MD}mkserver.sh -- Create Server Certificate${T_ME}"

if [ -f $sslcrtdir/ca.crt ] &&  [ ! -f $sslcrtdir/server.crt ]; then
    echo ""
    echo "${T_MD}Generating custom Server Certificate${T_ME}"
    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}STEP 1: Generating RSA private key for Server Certificate (${sslbit} bit)${T_ME}"
    if [ ! -f "$HOME/.rnd" ]; then
        touch "$HOME/.rnd"
    fi
    if [ ".$randfiles" != . ]; then
        $openssl genrsa -aes256 -rand $randfiles \
                        -out $sslkeydir/server.key \
                        $sslbit
    else
        $openssl genrsa -aes256 -out $sslkeydir/server.key \
                        $sslbit
    fi
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate RSA private key" 1>&2
        exit 1
    fi
    
   
    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}STEP 2: Generating X.509 certificate signing request for Server Certificate${T_ME}"
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
organizationalUnitName_default  = Server Team
commonName                      = "6. server DNS name          (eg, url)      "
commonName_max                  = 64
commonName_default              = www.cawd.wf
emailAddress                    = "7. Email Address            (eg, name@fqdn)"
emailAddress_max                = 40
emailAddress_default            = ca@cawd.wf
EOT
    $openssl req -nodes -sha512 -newkey rsa:$sslbit \
             -config .mkcert.cfg \
             -new \
             -key $sslkeydir/server.key \
             -out $sslcsrdir/server.csr
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate certificate signing request" 1>&2
        exit 1
    fi 

    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}STEP 3: Generating X.509 certificate signed by CA${T_ME}"
cat >.mkcert.cfg <<EOT
extensions = x509v3
[ x509v3 ]
subjectAltName    = email:copy
basicConstraints  = pathlen:0
nsComment         = "Server certificate"
nsCertType        = server
#extendedKeyUsage = RID:2.16.840.1.113730.4.1,RID:1.3.6.1.4.1.311.10.3.3
extendedKeyUsage  = msSGC,nsSGC
EOT
    if [ ! -f .mkca.serial ]; then
        echo '01' >.mkca.serial
    fi
    $openssl x509 -extfile .mkcert.cfg \
                  -days 3650 \
                  -sha512 \
                  -CAserial .mkca.serial \
                  -CA $sslcrtdir/ca.crt \
                  -CAkey $sslkeydir/ca.key \
                  -in $sslcsrdir/server.csr -req \
                  -out $sslcrtdir/server.crt
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate X.509 certificate" 1>&2
        exit 1
    fi
    
    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}STEP 4: Export PEM and P12 files${T_ME}"

    caname=$($openssl x509 -noout -text -in $sslcrtdir/ca.crt | grep Subject: | sed -e 's;.*CN=;;' -e 's;/Em.*;;')
    username=$($openssl x509 -noout -text -in $sslcrtdir/server.crt | grep Subject: | sed -e 's;.*CN=;;' -e 's;/Em.*;;')
    $openssl pkcs12 \
        -export \
        -in $sslcrtdir/server.crt \
        -inkey $sslkeydir/server.key \
        -certfile $sslcrtdir/ca.crt \
        -name "$username" \
        -caname "$caname" \
        -out $sslcrtdir/server.p12

    $openssl x509 -outform PEM -in $sslcrtdir/server.crt -out $sslcrtdir/server.crt.pem
     $openssl rsa -outform PEM -in $sslkeydir/server.key -out $sslkeydir/server.key.pem
    cat $sslcrtdir/server.crt.pem $sslkeydir/server.key.pem > $sslcrtdir/server.pem


    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}RESULT:${T_ME}"
    $openssl verify -CAfile $sslcrtdir/ca.crt $sslcrtdir/server.crt
    if [ $? -ne 0 ]; then
        echo "Error: Failed to verify resulting X.509 certificate" 1>&2
        exit 1
    fi

    rm -f .mkcert.cfg .$randfiles

    #OLD HTTP SERVERS: Encrypt RSA private key with a pass phrase for security 
    #$openssl rsa -des3 -in $sslkeydir/server.key -out $sslkeydir/server.key.crypt
    #cp $sslkeydir/serVer.key.crypt $sslkeydir/server.key
    #rm -f $sslkeydir/server.key.crypt

    chmod 400 $sslkeydir/server.key $sslcsrdir/server.csr $sslcrtdir/server.crt $sslcrtdir/server.p12 $sslcrtdir/server.crt.pem $sslkeydir/server.key.pem $sslcrtdir/server.pem
    echo -e "${T_MD}$sslkeydir/server.key${T_ME}\t\tPrivate Key (private)"
    echo -e "${T_MD}$sslcsrdir/server.csr${T_ME}\t\tCertificate Signing Request (public)"
    echo -e "${T_MD}$sslcrtdir/server.crt${T_ME}\t\tCertificate (public)"
    echo -e "${T_MD}$sslcrtdir/server.p12${T_ME}\t\tCertificate and Private Key (private)"
    echo -e "${T_MD}$sslcrtdir/server.crt.pem${T_ME}\t\tCertificate (public)"
    echo -e "${T_MD}$sslkeydir/server.key.pem${T_ME}\t\tPrivate Key (private)"
    echo -e "${T_MD}$sslcrtdir/server.pem${T_ME}\t\tCertificate and Private Key (private)"
fi
