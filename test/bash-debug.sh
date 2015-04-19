#!/usr/bin/env bash

if [[ ! -d test/dot.gnupg ]] ; then 
    mkdir test/dot.gnupg
    chmod u=rwx test/dot.gnupg
fi

./gneasy-genkey.sh "Testy McTesterson <testy@mctesterson.test>" --bash-debug 2>&1
