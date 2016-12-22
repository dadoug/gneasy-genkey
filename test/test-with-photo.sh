#!/usr/bin/env bash

if [[ ! -d test/dot.gnupg ]] ; then 
    mkdir test/dot.gnupg
    chmod u=rwx test/dot.gnupg
fi

./gneasy-genkey.sh "Testy McTesterson <testy@mctesterson.test>" --gnupg-home test/dot.gnupg --photo test/testy.jpg
#--policy-url "https://policy.txt"
#--show-tty

echo "list-options show-photos" >test/dot.gnupg/gpg.conf
gpg2 --homedir test/dot.gnupg --list-keys
