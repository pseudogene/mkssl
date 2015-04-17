#!/bin/bash
##
##  mkclient.sh -- Create Certificate Authority
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

echo "${T_MD}mkclient.sh -- Create Client Certificate${T_ME}"

if [ -f $sslcrtdir/ca.crt ] &&  [ ! -f $sslcrtdir/client.crt ]; then
    echo ""
    echo "${T_MD}Generating custom Client Certificate${T_ME}"
    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}STEP 1: Generating RSA private key for Client Certificate (${sslbit} bit)${T_ME}"
    if [ ! -f "$HOME/.rnd" ]; then
        touch "$HOME/.rnd"
    fi
    if [ ".$randfiles" != . ]; then
        $openssl genrsa -aes256 -rand $randfiles \
                        -out $sslkeydir/client.key \
                        $sslbit
    else
        $openssl genrsa -aes256 -out $sslkeydir/client.key \
                        $sslbit
    fi
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate RSA private key" 1>&2
        exit 1
    fi
    
   
    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}STEP 2: Generating X.509 certificate signing request for Client Certificate${T_ME}"
    cat >.mkcert.cfg <<EOT
[ req ]
default_bits                    = ${sslbit}
distinguished_name              = req_DN
[ req_DN ]
countryName                     = "1. Country Name             (2 letter code)"
countryName_default             = IE
countryName_min                 = 2
countryName_max                 = 2
0.organizationName              = "2. Organization Name        (eg, company)  "
0.organizationName_default      = Certificate Authority World Dominators
organizationalUnitName          = "3. Organizational Unit Name (eg, section)  "
organizationalUnitName_default  = Remote users
commonName                      = "4. Username/Login           (eg, nickname) "
commonName_max                  = 64
commonName_default              = 
emailAddress                    = "5. Email Address            (eg, name@fqdn)"
emailAddress_max                = 40
emailAddress_default            = 
EOT
    $openssl req -nodes -sha512 -newkey rsa:$sslbit \
             -config .mkcert.cfg \
             -new \
             -key $sslkeydir/client.key \
             -out $sslcsrdir/client.csr
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
nsComment         = "Client certificate"
nsCertType        = client, email, objsign
keyUsage          = nonRepudiation, digitalSignature, keyEncipherment
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
                  -in $sslcsrdir/client.csr -req \
                  -out $sslcrtdir/client.crt
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate X.509 certificate" 1>&2
        exit 1
    fi
    
    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}STEP 4: Export PEM and P12 files${T_ME}"

    caname=$($openssl x509 -noout -text -in $sslcrtdir/ca.crt | grep Subject: | sed -e 's;.*CN=;;' -e 's;/Em.*;;')
    username=$($openssl x509 -noout -text -in $sslcrtdir/client.crt | grep Subject: | sed -e 's;.*CN=;;' -e 's;/Em.*;;')
    $openssl pkcs12 \
        -export \
        -in $sslcrtdir/client.crt \
        -inkey $sslkeydir/client.key \
        -certfile $sslcrtdir/ca.crt \
        -name "$username" \
        -caname "$caname" \
        -out $sslcrtdir/client.p12

    $openssl x509 -outform PEM -in $sslcrtdir/client.crt -out $sslcrtdir/client.crt.pem
    $openssl rsa -outform PEM -in $sslkeydir/client.key -out $sslkeydir/client.key.pem
    cat $sslcrtdir/client.crt.pem $sslkeydir/client.key.pem > $sslcrtdir/client.pem


    echo "______________________________________________________________________"
    echo ""
    echo "${T_MD}RESULT:${T_ME}"
    $openssl verify -CAfile $sslcrtdir/ca.crt $sslcrtdir/client.crt
    if [ $? -ne 0 ]; then
        echo "Error: Failed to verify resulting X.509 certificate" 1>&2
        exit 1
    fi

    rm -f .mkcert.cfg .$randfiles

    chmod 400 $sslkeydir/client.key $sslcsrdir/client.csr $sslcrtdir/client.crt $sslcrtdir/client.p12 $sslcrtdir/client.crt.pem $sslkeydir/client.key.pem $sslcrtdir/client.pem
    echo -e "${T_MD}$sslkeydir/client.key${T_ME}\t\tPrivate Key (private)"
    echo -e "${T_MD}$sslcsrdir/client.csr${T_ME}\t\tCertificate Signing Request (public)"
    echo -e "${T_MD}$sslcrtdir/client.crt${T_ME}\t\tCertificate (public)"
    echo -e "${T_MD}$sslcrtdir/client.p12${T_ME}\t\tCertificate and Private Key (private)"
    echo -e "${T_MD}$sslcrtdir/client.crt.pem${T_ME}\t\tCertificate (public)"
    echo -e "${T_MD}$sslkeydir/client.key.pem${T_ME}\t\tPrivate Key (private)"
    echo -e "${T_MD}$sslcrtdir/client.pem${T_ME}\t\tCertificate and Private Key (private)"
fi
