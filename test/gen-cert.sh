#!/usr/bin/env bash

if [[ ! -d test/dot.gnupg ]] ; then 
    mkdir test/dot.gnupg
    chmod u=rwx test/dot.gnupg
fi

/usr/bin/gpg2 --display-charset utf-8 --no-greeting --quiet --no-verbose --no-emit-version --expert --keyid-format 0xlong --with-fingerprint --personal-cipher-preferences 'AES256 AES192 AES CAST5' --personal-digest-preferences 'SHA512 SHA384 SHA256 SHA224' --default-preference-list 'SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed' --homedir test/dot.gnupg --s2k-cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65011712 --passphrase-repeat 2 --gen-key
