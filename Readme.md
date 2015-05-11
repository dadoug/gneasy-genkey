<!-- ####################################################################### -->
<!-- @file       Readme.md -->
<!-- @brief      Information about gneasy-genkey -->
<!-- @author     0x21F2372027AAC738 -->
<!-- @date       2015-04-15 -->
<!-- -->
<!-- Copyright (C) 2015 0x21F2372027AAC738 -->
<!-- This document is free text: you can redistribute it and/or modify -->
<!-- it under the terms of the GNU General Public License as published by -->
<!-- the Free Software Foundation, either version 3 of the License, or -->
<!-- (at your option) any later version. -->
<!-- This document is distributed in the hope that it will be useful, -->
<!-- but WITHOUT ANY WARRANTY; without even the implied warranty of -->
<!-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the -->
<!-- GNU General Public License for more details. -->
<!-- You should have received a copy of the GNU General Public License -->
<!-- along with this document.  If not, see <http://www.gnu.org/licenses/>. -->

# gneasy-genkey
Easy GnuPG key generation tool (v1.1.1).

The process of generating a new GnuPG key -- and all the sub-keys -- 
can be tedious and a bit confusing.

So, here's a script that performs the following tasks 
(most of which can be toggled):

1. Generate a 4096-bit RSA master key capable of certification 
   and set to expire two years from now.
2. Generate three 4096-bit RSA sub-keys capable of signing, encryption and 
   authentication respectively and set to expire one year from now.
3. Export and symmetrically encrypt a gzipped tar-ball containing 
   both an ascii armored and qr-encoded revocation certificate 
   for the master key. 
4. Export the protected secret key, protected secret sub-keys and public key 
   to individual files.
5. Create some informative files for the new key, including:
   - a [paperkey](http://www.jabberwocky.com/software/paperkey/)
	 of the protected secret key, 
   - a [YAML](https://en.wikipedia.org/wiki/YAML) formatted file 
	 containing human-readable information about the generated keys, 
   - a qr-encoded UID and fingerprint, 
   - a contact [vCard](https://en.wikipedia.org/wiki/VCard), 
   - an [iCal](https://en.wikipedia.org/wiki/ICalendar) 
     as a reminder of key expiration dates.
6. Remove the master (certification) key from the GnuPG keyring, 
   but keep the sub-keys (capable of signing, encryption and authentication).

## Install
### Dependencies
#### GnuPG
The primary dependency is 
[GnuPG stable, v2.0.XX](https://www.gnupg.org/download/index.html). 
On Debian flavored GNU/Linux (Ubuntu), the following should suffice 
to install the required dependencies:
```bash
sudo apt-get install gpgv2
``` 
The software was developed using GnuPG-v2.0.22 but _might_ work with 
GnuPG-v2.1.xx modern. It will not work with GnuPG-v1.4.xx classic, though 
adding support for this version of GnuPG is certainly possible.

#### Enhancements
Both 
[qrencode](https://fukuchi.org/works/qrencode/) and 
[paperkey](http://www.jabberwocky.com/software/paperkey/)
will enhance the output: 
```bash
sudo apt-get install qrencode paperkey
```
All users should consider installing the optional 
[haveged](http://freecode.com/projects/haveged) for better/faster entropy 
collection: 
```bash
sudo apt-get install haveged
```

#### Note on Unix
This software was developed on Debian flavored GNU/Linux and uses 
[the Unix philosophy](https://en.wikipedia.org/wiki/Unix_philosophy) 
by combining the standard tools like 
`getopt`, `which`, `mktemp`, `grep`, `awk`, `mkdir`, `head`, and `shred`. 
Mileage may vary for users of Unix derived systems 
(like *BSD and Mac OS). 
It is likely that Unix users will need to install 
[getopt(1)](http://linux.die.net/man/1/getopt) 
in order to use this software.

### Installation
This software is a self contained bash script. 
It should, therefore, suffice to copy the script to a global path:
```bash
sudo cp gneasy-genkey.sh /usr/local/bin/gneasy-genkey
sudo chmod o=rwx,g=rx,o=rx /usr/local/bin/gneasy-genkey
```

## Usage
This software is designed to automatically implement the procedure 
outlined in 
[Generating More Secure GPG Keys: A Step-by-Step Guide](http://spin.atomicobject.com/2013/11/24/secure-gpg-keys-guide/) 
by Mike English, using the hardening options for GnuPG outlined by 
[OpenPGP Best Practices](https://help.riseup.net/en/security/message-security/openpgp/best-practices) from the RiseUp Collective and 
[duraconf](https://github.com/ioerror/duraconf/tree/master/configs/gnupg/gpg.conf
) 
by ioerror.

### Example
Calling 
```bash
gneasy-genkey "Testy McTesterson <testy@mctesterson.test>"
```
will perform the tasks outlined above for a user id
`Testy McTesterson <testy@mctesterson.test>`.

By default the exported files are saved in a directory named after the 
key-id of the generated key, i.e. `0x1234567890ABDCED/`

Note that extra UIDs can be added with comma separation:
```bash
gneasy-genkey "Testy McTesterson <testy@mctesterson.test>,Test Testerson <test@testerson.tst>,<@testy>"
```
                                  
### Help
```
Usage: gneasy-genkey <uid> [options]
Easy GnuPG key generation tool.

Arguments:
 <uid>  User-id(s) for the generated key. Format is "Name <email>".

Options:
 -S, --size           Size (length) in bits of master key.
                        Range is [1024, 4096]. Default is 4096.
 -L, --lifetime       Lifetime (expiration time) of master key. 
                        Format is that of GnuPG: 0 = no expiration, 
                        <n> = n days, <n>w = n weeks, <n>m = n months, 
                        <n>y = n years. Default is 2y.
 -s, --sub-size       Size of sub-keys in bits.
                        Range and default same as --size.
 -l, --sub-lifetime   Lifetime of sub-keys. 
                        Format is same as --lifetime. Default is 1y.

     --no-sign        Do not generate a sub-key for signing.
     --no-encr        Do not generate a sub-key for encryption.
     --no-auth        Do not generate a sub-key for authentication.
     --otr            Generate a 1024-bit DSA sub-key for authentication.

     --out-dir        Directory for export output; created if not present.
                        Default is key-id of the master key.
     --no-export      Do not export keys, revocation or summary.
     --no-revoke      Do not export revocation certificate.
     --no-export-pub  Do not export public key.
     --no-export-sec  Do not export secret keys.
     --no-export-sub  Do not export secret sub-keys.
     --no-paperkey    Do not export secret keys as paperkey.
     --no-info        Do not export key summary information.
     --no-calendar    Do not export iCalendar for key expiration dates.
     --no-qr          Do not export QR-code with uid and fingerprint.
     --no-vcard       Do not export vcard with contact information.
     --keep-master    Keep the master key in the GnuPG keyring.

     --gnupg-home     Home directory for GnuPG. Default is '~/.gnupg'.

     --quiet          Disable regular terminal output but show errors.
     --silent         Disable all terminal output.

 -h, --help           Print this help and exit.
 -v, --version        Print version information and exit.
     --version-num    Print version number <major.minor.patch> and exit.
     --copyright      Print copyright & license information and exit.
```
#### Debug
Developers might find the following flags useful:
```
     --debug       Print some debugging messages
     --bash-debug  Also echo all bash commands
```

## FYI
### GnuPG Flags
The following flags (and options) are automatically passed to 
`gpg2` and cannot be controlled by `gneasy-genkey` from the command-line 
(e.g. without editing the script).

In order to properly control GnuPG all calls to `gpg2` contain the flags:
```
--display-charset utf-8 
--expert 
--no-greeting 
--quiet 
--no-verbose 
--no-tty 
```

In keeping with 
[OpenPGP Best Practices](https://help.riseup.net/en/security/message-security/openpgp/best-practices), 
all calls to `gpg2` contain the flags:
```
--keyid-format 0xlong 
--with-fingerprint 
--no-emit-version 
--personal-cipher-preferences "AES256 AES192 AES CAST5" 
--personal-digest-preferences "SHA512 SHA384 SHA256 SHA224" 
--default-preference-list "SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed" 
```

The extra flags used for the GnuPG `genkey` command are:
```
--s2k-cipher-algo AES256
--s2k-digest-algo SHA512
```

The extra flags used for symmetrically encrypting
sensitive files (like the revocation certificate) are:
```
--cipher-algo AES256
--digest-algo SHA512
```
Sensitive temporary files are written to the output directory 
and `shred`-ed on exit (when `shred`/`srm` are available).

GnuPG "state-machine" command-/status-/output-/attribute-/logger- files 
are written to `/tmp/egk-XXXXXXXXXX/`. 
These files do not contain particularly sensitive information 
and are deleted (e.g. `rm`-ed) on exit.



## License
![GPLv3](https://gnu.org/graphics/gplv3-88x31.png)

`gneasy-genkey` is software libre; 
you are free to modify and share this software under the terms of the 
[GNU General Public License, version 3.0](https://www.gnu.org/licenses/gpl-3.0.html)

## Acknowledgments
The general outline of the tasks performed by this software 
was inspired by 
[Generating More Secure GPG Keys: A Step-by-Step Guide](http://spin.atomicobject.com/2013/11/24/secure-gpg-keys-guide/) 
by Mike English.
The flags/options passed to GnuPG are those suggested by 
[OpenPGP Best Practices](https://help.riseup.net/en/security/message-security/openpgp/best-practices) from the Riseup Collective and 
[duraconf](https://github.com/ioerror/duraconf/tree/master/configs/gnupg/gpg.conf
) 
from ioerror.

The crucial part of this script is the "state-machine" that automates 
interaction with GnuPG. That such interaction was even possible and 
the initial example of which was found at the 
[GnuPG users mailing list archive #67792](http://www.gossamer-threads.com/lists/gnupg/users/67792#67792).

Small snippets and other inspiration were lifted from the 
[monkeysphere](http://web.monkeysphere.info/community/) code.


## Contribute!
Please contribute to this project.

You can [submit a new issue](https://github.com/dadoug/gneasy-genkey/issues/new) 
or [help with a current issue](https://github.com/dadoug/gneasy-genkey/issues?q=is%3Aopen+is%3Aissue+label%3A%22help+wanted%22).

You can also donate bitcoin: `1ZCTTQPrfeYjUosgD4GUkVA1bdKwiTpwm`

<!-- end Readme.md -->
<!-- ####################################################################### -->


