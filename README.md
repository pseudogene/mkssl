#Creating a Certificate Authority and Certificates with OpenSSL
Michaël Bekaert

##Summary
This was written using OpenSSL 0.9.5 as a reference.

To start with, you'll need OpenSSL. Compilation and installation follow the usual methods. It's worthwhile to note that the default installs everything in `/usr/local/ssl`. No need to change this (unless you want to).

After you have this installed, you may want to edit the OpenSSL configuration file with the information for your site so you have pleasant defaults when creating and signing certificates. You'll find this in `/usr/local/ssl/openssl.cnf` in the section `req_distinguished_name` Here you can set the defaults (denoted by the `_default` appended to the variable name). Any settings that do not have a default, such as `localityName` can have one set by appending `_default`. In this case you'd set `localityName_default`.

Now, we move on to creating a private Certificate Authority (CA). The CA is used in SSL to verify the authenticity of a given certificate. The CA acts as a trusted third party who has authenticated the user of the signed certificate as being who they say. The certificate is signed by the CA, and if the client trusts the CA, it will trust your certificate. For use within your organisation, a private CA will probably serve your needs. However, if you intend use your certificates for a public service, you should probably obtain a certificate from a known CA. In addition to identification, your certificate is also used for encryption.


##Creating a private CA

 *   Download the script call `mkca.sh`
 *   `su` to root
     *   To make sure you data are safe from evil eyes.
 *   `./mkca.sh`
     *   It will create a 4096-bit self-sign CA certificate and key
     *   When prompted for CA password, choose a long and safe password. This is your CA after all.
     *   Answer the rest of the questions intelligently. The common name would be how this certificate might be referred to. For example, the Equifax Secure CA uses the common name of Equifax Secure Certificate Authority.
 *   A `.mkca.serial` will also be created, that is the memory of the future server and client serial numbers.


##Creating server certificates

 *   Download the script call `mkserver.sh`
 *   `su` to root
     *   To make sure you data are safe from evil eyes.
 *   `./mkserver.sh`
     *   It will create a 4096-bit CA sign certificate and key
     *   Answer the rest of the questions intelligently. The common name would be how this certificate might be referred to. For example, the server DNS e.g. www.example.com.
     *   It will ask for a P12 pass phrase, that's the passphrase you set your key importation.
     *   This signs the certificate that you just created with the CA you created just moments before. You can generate multiple certificates.
 *   The signed certificate is now in the current directory as .crt + .key, .p12 and .pem. If you are going to create more, you should rename this.


##Creating client-side certificates

 *   Download the script call `mkclient.sh`
 *   `su` to root
     *   To make sure you data are safe from evil eyes.
 *   `./mkclient.sh`
     *   It will create a 4096-bit CA sign certificate and key
     *   When prompted for CA password, choose a long and safe password. This is your CA after all.
     *   Answer the rest of the questions intelligently. The common name would be how this certificate might be referred to. For example, your username or email address.
 *   The signed certificate is now in the current directory as .crt + .key, .p12 and .pem. If you are going to create more, you should rename this.
