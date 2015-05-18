#!/usr/bin/env bash

if [[ ! -d test/dot.gnupg ]] ; then 
    mkdir test/dot.gnupg
    chmod u=rwx test/dot.gnupg
fi

./gneasy-genkey.sh "Testy McTesterson <testy@mctesterson.test>,Test Testerson <test@testerson.tst>,<@testy>" --gnupg-home test/dot.gnupg 
#--policy-url "https://policy.txt"
#--show-tty
