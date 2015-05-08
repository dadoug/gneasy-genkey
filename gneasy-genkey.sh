#!/usr/bin/env bash
### ############################################################################
##! @file    gneasy-genkey.sh
##! @brief   Easily create a GnuPG key.
##! @author  0x21F2372027AAC738
##! @date    2015-03-27
##
## gneasy-genkey Easy GnuPG key generation tool.
## Copyright (C) 2015 0x21F2372027AAC738
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -o errexit           ## exit on simple command fail
umask 077                ## o=rw
EGK_PROG=$(basename $0)  ## Program name
EGK_VERSION="1.0.0"      ## Program version
EGK_DATE="2015"          ## Creatation date

## *****************************************************************************
## Functions
## *****************************************************************************

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Usage
function usage() {
    cat <<EOF >&2
Usage: $EGK_PROG <uid> [options]
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
     --no-info        Do not export key summary information.
     --no-calendar    Do not export iCalendar for key expiration dates.
     --no-qr          Do not export QR-codes.
     --no-vcard       Do not export vcard with contact information.
     --keep-master    Keep the master key in the GnuPG keyring.

     --gnupg-home     Home directory for GnuPG. Default is '~/.gnupg'.

     --quiet          Disable regular terminal output but show errors.
     --silent         Disable all terminal output.

 -h, --help           Print this help and exit.
 -v, --version        Print version information and exit.
     --version-num    Print version number <major.minor.patch> and exit.
     --copyright      Print copyright & license information and exit.

Examples:
 $ $EGK_PROG "Testy McTesterson <testy@mctesterson.test>"
   Generate a 4096-bit RSA master certification key with a two year lifetime.
   Generate three 4096-bit RSA master sub keys with one year lifetimes.
   Generate a 1024-bit DSA sub key with one year lifetimes.
   Export key information files and encrypted revocation certificate.   

 $ $EGK_PROG "Testy McTesterson <testy@mctesterson.test>,Test Son <test.tst>,<@mctesterson>"
   Same as above, but add extra uids 
EOF
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Version
function version() {
    cat <<EOF >&2
$EGK_PROG $EGK_VERSION
EOF
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Copyright
function copyright() {
    cat <<EOF >&2
Copyright (C) $EGK_DATE 0x21F2372027AAC738.
EOF
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## License
function license() {
    cat <<EOF >&2
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Handles for logging
function log() { 
    if [ "$EGK_QUIET" != true ] && [ "$EGK_SILENT" != true ] ; then 
	echo "egk: $@"; 
    fi
}
function debug() { 
    if [ "$EGK_DEBUG" == true ] ; then log "DEBUG: $@"; fi
}
function warning() { 
    if [ "$EGK_SILENT" != true ] ; then log "WARNING: $@"; fi
}
function error() { 
    if [ "$EGK_SILENT" != true ] ; then log "ERROR: $@" >&2; fi
}
function opt_error() { 
    error "$@"
    usage
    exit 3
}
function fatal() { 
    if [ "$EGK_SILENT" != true ] ; then log "FATAL: $@" >&2; fi
    exit 4
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Check for the programs on which we depend or request 
## and attempt to get extract the bare, e.g. not user-aliased, commands.
function check_dependencies() {
    ## -------------------------------------
    ## Requirements

    ## which
    if ! type which &>/dev/null ; then
	fatal "Failed to find executable locator: 'which'"
    fi

    ## Secure (-ish, at least 'careful') file removal
    ## This is of limited utility on many modern file systems
    ## but some of our files are sensitive, so we do what we can
    if type shred &>/dev/null ; then
    	sdelCmd=$(which shred)
	EGK_SRMFLAGS=( --iterations=7 --force --zero --remove )
    elif type srm &>/dev/null ; then
    	sdelCmd=$(which srm)
	EGK_SRMFLAGS=( --medium --force --zero )
    elif type rm &>/dev/null ; then
    	sdelCmd=$(which rm)
	EGK_SRMFLAGS=( --force )
    	warning "Failed to find secure file remover:"\
                "'shred' or 'srm', using 'rm'"
    else
    	fatal "Failed to find file remover: 'shred', 'srm' or 'rm'"
    fi

    ## mktemp
    if type mktemp &>/dev/null ; then
	mktempCmd=$(which mktemp)
    else
	fatal "Failed to find temporary file creater: 'mktemp'"
    fi

    ## mkdir
    if type mkdir &>/dev/null ; then
	mkdirCmd=$(which mkdir)
    else
 	fatal "Failed to find directory creater: 'mkdir'"
    fi

    ## chmod
    if type chmod &>/dev/null ; then
	chmodCmd=$(which chmod)
    else
 	fatal "Failed to find mode changer: 'chmod'"
    fi

    ## grep
    if type grep &>/dev/null ; then
	grepCmd=$(which grep)
	## Unset grep environment variables
	unset GREP_OPTIONS
    else
	fatal "Failed to find pattern searcher: 'grep'"
    fi

    ## awk
    if type awk &>/dev/null ; then
	awkCmd=$(which awk)
    else
	fatal "Failed to find pattern scanner: 'awk'"
    fi

    ## NOTE: This requires "GNU" getopt.  
    ## On Mac OS X and FreeBSD, you have to install this separately ... 
    if type getopt &>/dev/null ; then
	getoptCmd=$(which getopt)
	## Do not force retro-compatable mode
	unset GETOPT_COMPATIBLE
	## Test for "enhanced" version
	set +e  ## unset exit on simple command fail
	goptTest=$($getoptCmd --test)
	if [ "$?" != "4" ]; then 
	    fatal "Failed to find enhanced option parser: 'getopt(1)'"; 
	fi
	set -e  ## reset exit on simple command fail
    else
	fatal "Failed to find option parser: 'getopt(1)'"
    fi

    ## GnuPG
    if type gpg2 &>/dev/null ; then
	gpgCmd=$(which gpg2)
    # elif type gpg &>/dev/null ; then
    # 	gpgCmd=$(which gpg)
    else 
	fatal "Failed to find GnuPG-v2: 'gpg2'"
    fi
    ## gpg version
    gpgVstr=$("$gpgCmd" --version)
    gpgVersion=$(echo -n "$gpgVstr" | head -n1 | "$awkCmd" '{ print $3 }')
    gpgMajorVersion=$(echo -n "$gpgVersion" | "$awkCmd" -F'.' '{ print $1 }')
    if [ $gpgMajorVersion -lt 2 ] ; then
	fatal "Please install 'gnupg' version >= 2.X"	
    fi
    gpgMinorVersion=$(echo -n "$gpgVersion" | "$awkCmd" -F'.' '{ print $2 }')
    if [ $gpgMinorVersion -gt 0 ] ; then
	warning "GnuPG version > 2.0; you may experience bugs ..."	
    fi


    ## -------------------------------------
    ## Optionals

    ## QR encoder
    if type qrencode &>/dev/null ; then
	qrCmd=$(which qrencode)
    else 
    	log "QR-code creater not found: `qrencode`"
    fi

    ## Tails
    if ! type tails-version &>/dev/null ; then
    	log "Consider using Tails <https://tails.boum.org/>."
    fi

    # ## haveged
    # set +e  ## unset exit on simple command fail
    # havegedStatus=$(ps -e | "$grepCmd" haveged)
    # set -e  ## reset exit on simple command fail
    # if [[ -z "${havegedStatus:-}" ]] ; then 
    # 	log "Consider installing 'haveged' for better entropy gathering."
    # fi
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Secure remove a file
function srm_file() {
    $sdelCmd ${EGK_SRMFLAGS[@]} "$@"
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Create temporary directory
function mktmp_dir() {
    EGK_TMPDIR=$("$mktempCmd" -d ${EGK_TMPPATH:-/tmp}/egk-XXXXXXXXXX)
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Clean-up and exit
##  $1: exit code
##  $2: exit message (optional)
function cleanup() {
    # unset masterKeyId
    if [ "$EGK_DEBUG" != true ] ; then 
	## Remove temporary directory
	if [[ -n "${EGK_TMPDIR:-}" ]] ; then 
	    rm -rf "$EGK_TMPDIR/"
	fi
    fi
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Make a temporary file
##  $1: suffix
function mktmp_file() {
    ## make the temp file
    if [[ -z "${1:-}" ]] ; then 
    	"$mktempCmd" "$EGK_TMPDIR/egk-XXXXXXXXXX"
    else
    	"$mktempCmd" -p "$EGK_TMPDIR" -t "$1.XXX"
    	# touch "$EGK_TMPDIR/$1"
    fi
}


## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Create output directory
##  $1: fallback, if EGK_OUTDIR is empty
function mkout_dir() {
    if [[ -n "$EGK_OUTDIR" ]] && [[ -d "$EGK_OUTDIR" ]] ; then 
	## Global variable is not an empty string and 
	## represents a directory path
	echo "$EGK_OUTDIR"
    else
	## Use $1 if EGK_OUTDIR is empty
	local outDir="${EGK_OUTDIR:-$1}"
	## Check
	if [[ -n "${outDir:-}" ]] ; then 
	    ## outDir is not an empty string; do things
	    ## set global vaiable
	    EGK_OUTDIR="$outDir"
	    if [[ -d "$outDir" ]] ; then 
		## Directory exists; echo it
		echo "$outDir"
	    else 
		## Directory does not exists; create it
		"$mkdirCmd" "$outDir"
		if [[ ! -d "$outDir" ]] ; then 
		    ## Directory not created
    		    fatal "Failed to create output directory: $outDir"
		else 
		    ## Directory created
		    echo "$outDir"
		fi
	    fi
	else
	    ## outDir is an empty string; exit
    	    fatal "No output directory given"
	fi
    fi ## end check global
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## User gpg command with common options
function egk_gpg() {
    LC_ALL= LANGUAGE=en \
    "$gpgCmd" \
     --homedir "$EGK_GPGHOME" \
     --display-charset utf-8 \
     --expert \
     --no-greeting --quiet --no-verbose \
     --no-tty \
     --keyid-format 0xlong --with-fingerprint \
     --no-emit-version \
     --personal-cipher-preferences "AES256 AES192 AES CAST5" \
     --personal-digest-preferences "SHA512 SHA384 SHA256 SHA224" \
     --default-preference-list "SHA512 SHA384 SHA256 SHA224 \
AES256 AES192 AES CAST5 \
ZLIB BZIP2 ZIP Uncompressed" \
     "$@"
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Execute a state machine for manipulating keys
##  $1: machine-name = short string to inform
##  $2: command = state-machine command to interact with gpg
##  $[@]:2: flags = gpg command, like --gen-key or --edit-key
function egk_gpg_state_machine(){
    ## Locals
    local machName="$1"
    local command="$2"
    shift ; shift
    local flags="$@"

    ## state-machine command file
    local commanF=$(mktmp_file "$machName.comman")
    echo -e "$command" > "$commanF"
    ## Store gpg output
    local statusF=$(mktmp_file "$machName.status")
    local outputF=$(mktmp_file "$machName.inform")
    local attribF=$(mktmp_file "$machName.attrib")
    local loggerF=$(mktmp_file "$machName.logger")

    ## It's a trap!
    trap 'fatal "Key generation interupted"' HUP INT TERM QUIT
    ## Generate a key. Direct both std-out/err to $outputF
    egk_gpg \
      --command-file    "$commanF" \
      --status-file     "$statusF" \
      --attribute-file  "$attribF" \
      --logger-file     "$loggerF" \
      ${flags} \
      >> "$outputF" 2>&1

    ## Whew, we made it: unset the trap
    trap - HUP INT TERM QUIT

    ## the status file contains the information 
    ## about what the state machine accomplished
    echo "$statusF"
}

##+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## List public key information with machine parsable output
##  $1: keyId
function egk_gpg_listkey() {
    egk_gpg  --with-fingerprint --with-colons --list-key "$1"
}

##+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## List public key information with machine parsable output
##  $1: keyId
function egk_gpg_listsecretkey() {
    egk_gpg  --with-fingerprint --with-colons --list-secret-key "$1"
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Generate the master certification RSA key
##  $1: name
##  $2: email
##  $3: key-size
##  $4: key-life
function egk_gpg_gen_master(){
    ## Generate the master key
    log "Generating key: master (certification) ..."
    local flags=( --s2k-cipher-algo "$EGK_GPGCIPHERALGO" \
	          --s2k-digest-algo "$EGK_GPGDIGESTALGO" \
	          --passphrase-repeat $EGK_GPGPASSRPT \
	          --gen-key )
    local statusF=$(egk_gpg_state_machine \
                    "certification" \
                    "8\nS\nE\nQ\n$3\n$4\nY\n$1\n$2\n\nO\n"\
                    ${flags[@]})

    ## Check for status
    if [[ -z "${statusF:-}" ]] ; then 
    	fatal "Failed to find status file for certification key: $statusF"
    else 
	## Extract the generated key fingerprint from the status file
	local keyFpr=$("$grepCmd" "KEY_CREATED P" "$statusF" \
	    | "$awkCmd" '{ print $4 }')
	if [[ -z "${keyFpr:-}" ]] ; then 
    	    fatal "Failed to generate a master key"
	else
	    ## Extract master key-id
	    #unset masterKeyId
	    masterKeyId="0x"
	    masterKeyId+=$(egk_gpg_listkey "$keyFpr" \
    		| "$grepCmd" pub | "$awkCmd" -F: '{ print $5 }')
	    debug "Master key-id: $masterKeyId"
	fi
    fi
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Parse name from UID string
function parse_uid_name(){
    if [ "${1:0:1}" == "<" ] ; then 
	echo ""
    else
	local name=$(echo "$1" | awk -F " <" '{ print $1 }')
	echo "$name"
    fi
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Parse mail from UID string
function parse_uid_mail(){
    local mail=$(echo "$1" | cut -d\< -f2 | cut -d\> -f1)
    echo "$mail"
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Add a another UID
##  $1: master keyId
##  $2: name
##  $3: email
function egk_gpg_add_uid(){
    local flags=( --allow-freeform-uid --edit-key "$1" )
    local statusF=$(egk_gpg_state_machine \
                    "adduid" \
                    "adduid\n$2\n$3\n\nO\nuid 1\nprimary\nsave\n" \
                    ${flags[@]})

    log "Added uid: $2 <$3> ..."
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Add a all UIDs
##  $1: master keyId
function egk_gpg_add_uids(){
    for idx in $(seq 0 $((${#EGK_NAMES[@]} - 1)))
    do 
	egk_gpg_add_uid "$1" "${EGK_NAMES[${idx}]}" "${EGK_MAILS[${idx}]}"
    done
    unset idx
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Generate a sub-key; this method has easier input parameters
##   $1: sub-key type
##   $2: master key-id
##   $3: sub-key size
##   $4: sub-key lifetime
function egk_gpg_gen_subkey(){
    ## Parse type and set state machine commands
    local sm=""
    if   [ "$1" == "signing" ] ;        then sm="8\nE\nQ";    
    elif [ "$1" == "encryption" ] ;     then sm="8\nS\nQ";
    elif [ "$1" == "authentication" ] ; then sm="8\nA\nS\nE\nQ";
    elif [ "$1" == "otr" ] ;            then sm="7\nA\nS\nQ";
    else fatal "Unkown subkey type: $1" 
    fi

    ## Generate the key
    log "Generating key: $1 ..."
    local flags=( --s2k-cipher-algo "$EGK_GPGCIPHERALGO" \
	          --s2k-digest-algo "$EGK_GPGDIGESTALGO" \
	          --passphrase-repeat $EGK_GPGPASSRPT \
	          --edit-key "$2" )
    local statusF=$(egk_gpg_state_machine \
                    "$1" \
                    "addkey\n$sm\n$3\n$4\nsave\n" \
                    ${flags[@]})
    ## Check for status
    if [[ -z "${statusF:-}" ]] ; then 
    	error "Failed to find status file for $1 key: $statusF"
    else 
	## Check for success
	local keyCreated=$("$grepCmd" "KEY_CREATED S" "$statusF")
	if [[ -z "${keyCreated:-}" ]] ; then 
    	    error "Failed to generate a $1 key"
	fi
    fi
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Export key with ascii armored output
##  $1: master key-id
##  $2: output directory
##  $3: export type; public, secret or secret-subs
function egk_gpg_export_key() {
    ## locals
    local keyId="$1"
    local outDir="$2"
    local expType="$3"
    local filePre=""
    local fileExt=""

    ## Parse type and set flags
    local expFlag="--export"
    if   [ "$expType" == "public" ] || [[ -z "${expType:-}" ]] ; then 
	expType="public"
	filePre="public-key"
	fileExt="asc"
    elif [ "$expType" == "secret" ] ;      then 
	expFlag+="-secret-keys";
	filePre="master-secret-key"
	fileExt="gpg"
    elif [ "$expType" == "secret-subs" ] ; then 
	expFlag+="-secret-subkeys";
	filePre="sub-secret-keys"
	fileExt="gpg"
    else fatal "Unkown export type: $expType" 
    fi
    ## Set-up output file
    if [[ -n "${outDir:-}" ]] ; then 
	local expFile="$outDir/${filePre}.${fileExt}"
    else
	local expFile="$keyId-${filePre}.${fileExt}"
    fi

    ## Do it
    if   [[ "$fileExt" == "asc" ]] ; then 
	egk_gpg --armor --output "$expFile" ${expFlag} "$keyId"
    elif [[ "$fileExt" == "gpg" ]] ; then 
	egk_gpg         --output "$expFile" ${expFlag} "$keyId"
    else fatal "Unkown file extension: $fileExt" 
    fi

    ## Check for success
    if [[ -e "$expFile" ]] ; then echo "$expFile"
    else echo "failed"; fi
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Encrypt a file
##  $1: file-name
function egk_gpg_enrc_file() {
    local fn="$1"
    local efn="${fn}.gpg"
    egk_gpg --cipher-algo "$EGK_GPGCIPHERALGO" \
            --digest-algo "$EGK_GPGDIGESTALGO" \
            --passphrase-repeat $EGK_GPGPASSRPT \
            --symmetric \
            --output "$efn" \
            "$fn"
    echo "$efn"
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Generate a revocation certificate
##  $1: master key-id
##  $2: output directory
function egk_gpg_export_revoke() {
    ## locals
    local keyId="$1"
    local outDir="$2"
    ## Set-up output file
    if [[ -d "$outDir" ]] ; then 
	local revFile="$outDir/revocation-cert.asc"
    else
	local revFile="$keyId-revocation-cert.asc"
    fi

    ## Generate the key
    local flags=( --armor --output $revFile --gen-revoke $keyId )
    local statusF=$(egk_gpg_state_machine \
                    "revoke" \
                    "Y\n0\n\nY\n" \
                     ${flags[@]})

    ## Check for success
    if [[ -e "$revFile" ]] ; then 
	## Successfully generated the file
	if [ "$EGK_EXPORTQR"  == true ] && [[ -n "${qrCmd:-}" ]] ; then 
	    ## QR requested:

	    ## Build qr file name
	    if [[ -d "$outDir" ]] ; then
		local qrrf="$outDir/revocation-cert.png"
	    else
		local qrrf="$keyId-revocation-cert.png"
	    fi
	    ## generate the qr code
	    cat "$revFile" | qrencode -o "$qrrf"

	    ## Build bundle file name
	    if [[ -d "$outDir" ]] ; then
		local rfb="$outDir/revocation-cert.tgz"
	    else
		local rfb="$keyId-revocation-cert.tgz"
	    fi
	    ## bundle the formated files
	    tar -czf "$rfb" "$revFile" "$qrrf"

	    ## encrypt bundle
	    local erc=$(egk_gpg_enrc_file "$rfb")
	    if [[ -e "$erc" ]] ; then 
		## the files are sensitive, let's obliterate them
		srm_file "$revFile"
		srm_file "$qrrf"
		srm_file "$rfb"
		echo "$erc"
	    else
		echo "failed"
	    fi
	else
	    ## no QR requested:
	    local erc=$(egk_gpg_enrc_file "$revFile")
	    if [[ -e "$erc" ]] ; then 
		## the file is sensitive, let's obliterate it
		srm_file "$revFile"
		echo "$erc"
	    else
		echo "failed"
	    fi
	fi
    else
	echo "failed"
    fi
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Remove master key
##  $1: key-id
##  $2: sub-keys file-name
function egk_gpg_remove_master() {
    local keyId="$1"
    local skfn="$2"
    if [[ -e "$skfn" ]] ; then
	## Remove secret keys from key-ring
	local flags=( --delete-secret-keys $keyId )
 	local statusF=$(egk_gpg_state_machine \
	                "delete-secret" "Y\nY\n" ${flags[@]})

	## Import key from file into key-ring
	egk_gpg --import "$skfn"
	
    else
	warning "Sub-keys file $skfn not found,"\
                "master key of $keyId not removed from key-ring."
    fi
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Convert from seconds since epoch to a nearly ISO-8601 date stamp
##  $1: seconds since epoch
function sec2date() {
    local seconds="$1"
    ## First try GNU
    if ! date --utc '+%F %T%z' -d @"${seconds}" 2>/dev/null ; then
        # Then try BSD
        date -ru "${seconds}" '+%F %T%z'
    fi
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Convert from algorithm code to string
##  $1: algorithm code
function algo2str() {
    case "$1" in
	1)  echo "RSA" ;;
	17) echo "DSA" ;;
	*)  echo "Unknown" ;;
    esac
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Convert from capability code to string
##  $1: capability code
function capa2str() {
    if   [[ "$1" == *"c"* ]]; then echo "certify" ;
    elif [[ "$1" == *"s"* ]]; then echo "sign" ;
    elif [[ "$1" == *"e"* ]]; then echo "encrypt" ;
    elif [[ "$1" == *"a"* ]]; then echo "authenticate" ;
    else                           echo "unknown" ;
    fi
}


## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Format fingerprint
##  $1: fingerprint
function frmt_fpr_gpg() {
    local fpr="$1"
    local len=${#fpr}
    if [[ $len -ne 40 ]] ; then 
	echo "unknown"
    fi
    local fmt="${fpr:0:4} ${fpr:3:4} ${fpr:7:4} ${fpr:11:4} ${fpr:15:4}  "
    fmt+="${fpr:19:4} ${fpr:23:4} ${fpr:27:4} ${fpr:31:4} ${fpr:35:4}"
    echo "$fmt"
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Parse wierdo gnupg key information
##  $1: keyID
function parse_key_info() {
    ## Local variables for holding the info
    local keyId="$1"
    masterIdx=   # index of master key
    lengths=()   # key lengths
    algos=()     # algorithm codes
    keyids=()    # keyids
    credates=()  # creation dates
    expdates=()  # expiration dates
    capes=()     # capabilities
    fprs=()      # fingerprints
    uids=()      # user-ids
    uidnames=()  # user-id: names
    uidemails=() # user-id: emails
    uiddates=()  # user-id: dates

    ## Parse the obtuse GnuPG output
    oldIFS="$IFS"
    IFS=$'\n'
    for line in $(egk_gpg_listsecretkey "$keyId")
    do
	#echo "$line"
	type=$(echo "$line" | cut -d: -f1)
	## Master public key
	if [ "$type" == "sec" ] || [ "$type" == "ssb" ] ; then
	    lengths=(${lengths[@]} \
		     $(echo "$line" | cut -d: -f3))
	    algos=(${algos[@]} \
		   $(algo2str $(echo "$line" | cut -d: -f4)))
	    keyids=(${keyids[@]} \
		   $(echo "$line" | cut -d: -f5))
	    credates=(${credates[@]} \
		      $(sec2date $(echo "$line" | cut -d: -f6)))
	    expdates=(${expdates[@]} \
		      $(sec2date $(echo "$line" | cut -d: -f7)))
	    capes=(${capes[@]} \
		   $(capa2str $(echo "$line" | cut -d: -f12)))
	    if [ "$type" == "sec" ] ; then
		masterIdx=$((${#lengths[@]}-1))
	    fi
	fi

	## Fingerprints
	if [ "$type" == "fpr" ] ; then
	    fprs=(${fprs[@]} "$(frmt_fpr_gpg $(echo "$line" | cut -d: -f10))")
	fi

	## User-ids
	if [ "$type" == "uid" ] ; then
	    uid=$(echo "$line" | cut -d: -f10)
	    uids=(${uids[@]} $uid)
	    uidnames=(${uidnames[@]} $(echo $uid | \
		      "$awkCmd" -F" <" '{ print $1 }'))
	    uidemails=(${uidemails[@]} $(echo $uid | \
		       cut -d\< -f2 | cut -d\> -f1))
	    uiddates=(${uiddates[@]} $(sec2date \
		      $(echo "$line" | cut -d: -f6)))

	fi
    done  ## end loop over lines
    IFS="$oldIFS"
    unset line type
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Export gnupg key information to YAML format
##  $1: keyID
##  $2: out directory
function write_key_info_yaml() {
    ## Local variables
    local keyId="$1"
    local outDir="$2"

    ## Print the summary information to a file
    if [ -d "$outDir" ] ; then
	local infoF="$outDir/info-public-key.yaml"
    else
	local infoF="$keyId-info-public-key.yaml"
    fi

    ## Write YAML file
    echo "---"                                        > $infoF
    echo "gnupg-key: "                               >> $infoF

    echo "  uids: "                                  >> $infoF
    for idx in $(seq 0 $((${#uids[@]} - 1)))
    do 
    echo "    - ${uidnames[${idx}]} <${uidemails[${idx}]}>" >> $infoF
    done
    unset idx
 
    echo "  master: "                                >> $infoF
    echo "    id: "${keyids[$masterIdx]}             >> $infoF
    echo "    fingerprint: "${fprs[$masterIdx]}      >> $infoF
    echo "    capability: "${capes[$masterIdx]}      >> $infoF
    echo "    algorithm: "${algos[$masterIdx]}       >> $infoF
    echo "    size: "${lengths[$masterIdx]}          >> $infoF
    echo "    date: "                                >> $infoF
    echo "      created: "${credates[$masterIdx]}    >> $infoF
    echo "      expires: "${expdates[$masterIdx]}    >> $infoF

    echo "  sub-keys: "                              >> $infoF
    for idx in $(seq 0 $((${#keyids[@]} - 1)))
    do 
    if [ $idx != $masterIdx ] ; then
    echo "    - id: "${keyids[$idx]}                 >> $infoF
    echo "      fingerprint: "${fprs[$idx]}          >> $infoF
    echo "      capability: "${capes[$idx]}          >> $infoF
    echo "      algorithm: "${algos[$idx]}           >> $infoF
    echo "      size: "${lengths[$idx]}              >> $infoF
    echo "      date: "                              >> $infoF
    echo "        created: "${credates[$idx]}        >> $infoF
    echo "        expires: "${expdates[$idx]}        >> $infoF
    fi
    done
    unset idx

    echo "..."                                       >> $infoF

    echo "$infoF"
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Reformat iso date from "YYYY-MM-DD HH:MM:SS+hhmm" to "YYYYMMDD"
##  $1: iso date
function refrmt_date() {
    local iso="$1"
    local fmt="${iso:0:4}${iso:5:2}${iso:8:2}"
    echo "$fmt"
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Export gnupg key expiration dates to iCal format
##  $1: keyID
##  $2: out directory
function write_ics() {
    ## Local variables
    local keyId="$1"
    local outDir="$2"

    ## Print the summary information to a file
    if [ -d "$outDir" ] ; then
	local icalF="$outDir/expiration-reminder.ics"
    else
	local icalF="$keyId-expiration-reminder.ics"
    fi

    ## Write iCal file
    echo "BEGIN:VCALENDAR"                                  > $icalF
    echo "VERSION:2.0"                                     >> $icalF

    echo "BEGIN:VEVENT"                                    >> $icalF
    echo "DTSTART:$(refrmt_date ${expdates[$masterIdx]})"  >> $icalF
    echo "SUMMARY:$keyId master key expires"               >> $icalF
    echo "BEGIN:VALARM"                                    >> $icalF
    echo "TRIGGER:-PT10080M"                               >> $icalF
    echo "ACTION:DISPLAY"                                  >> $icalF
    echo "DESCRIPTION:$keyId master key expires in 1 week" >> $icalF
    echo "END:VALARM"                                      >> $icalF
    echo "END:VEVENT"                                      >> $icalF

    for idx in $(seq 0 $((${#keyids[@]} - 1)))
    do 
    if [ $idx != $masterIdx ] ; then
    echo "BEGIN:VEVENT"                                    >> $icalF
    echo "DTSTART:$(refrmt_date ${expdates[$idx]})"        >> $icalF
    echo "SUMMARY:$keyId sub-keys expire"                  >> $icalF
    echo "BEGIN:VALARM"                                    >> $icalF
    echo "TRIGGER:-PT10080M"                               >> $icalF
    echo "ACTION:DISPLAY"                                  >> $icalF
    echo "DESCRIPTION:$keyId sub-keys expire in 1 week"    >> $icalF
    echo "END:VALARM"                                      >> $icalF
    echo "END:VEVENT"                                      >> $icalF
    break
    fi
    done
    unset idx

    echo "END:VCALENDAR"                             >> $icalF

    echo "$icalF"
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Export gnupg key contact information to vcard format
##  $1: keyID
##  $2: out directory
function write_vcard() {
    ## Local variables
    local keyId="$1"
    local outDir="$2"

    ## Print the summary information to a file
    if [ -d "$outDir" ] ; then
	local cardF="$outDir/contact.vcf"
    else
	local cardF="$keyId-contact.vcf"
    fi

    ## Write iCal file
    echo "BEGIN:VCARD"               > $cardF
    echo "VERSION:4.0"              >> $cardF
    echo "FN:${uidnames[0]}"        >> $cardF
    echo "EMAIL:${uidemails[0]}"    >> $cardF
    echo "NOTE:${fprs[$masterIdx]}" >> $cardF
    echo "END:VCARD"                >> $cardF

    echo "$cardF"
}


## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Export primary uid and fingerprint as a qr-code
##  $1: keyID
##  $2: out directory
function write_uidfpr_qr() {
    local keyId="$1"
    local outDir="$2"
    if [[ -n "${qrCmd:-}" ]] ; then 
	if [ -d "$outDir" ] ; then
	    local qrF="$outDir/qr-uid-fpr.png"
	else
	    local qrF="$keyId-qr-uid-fpr.png"
	fi
	local info="${uidnames[0]} <${uidemails[0]}>"
	info+="\n${fprs[$masterIdx]}"
	echo -e "$info" | qrencode -o "$qrF"
    fi
    echo "$qrF"
}

## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Parse options
function parse_options() {
    ## -------------------------------------
    ## Check for args
    if [[ "$#" -lt 1 ]] ; then 
	opt_error "Must give a uid argument."; 
    fi

    ## -------------------------------------
    ## Options variables
    EGK_SILENT=false
    EGK_QUIET=false

    EGK_NAME=""
    EGK_MAIL=""
    EGK_NAMES=()
    EGK_MAILS=()
    EGK_KEYSIZE=4096
    EGK_KEYLIFE="2y"
    EGK_SUBKEYSIZE=4096
    EGK_SUBKEYLIFE="1y"
    EGK_GENSIGN=true
    EGK_GENENCR=true
    EGK_GENAUTH=true
    EGK_GENOTR=false

    EGK_OUTDIR=""
    EGK_EXPORT=true
    EGK_EXPORTPUB=true
    EGK_EXPORTSEC=true
    EGK_EXPORTSUB=true
    EGK_EXPORTREV=true
    EGK_EXPORTSUM=true
    EGK_EXPORTCAL=true
    EGK_EXPORTQR=true
    EGK_EXPORTVC=true
    EGK_KEEPMASTER=false

    EGK_GPGHOME="$HOME/.gnupg"
    EGK_GPGCIPHERALGO="AES256"
    EGK_GPGDIGESTALGO="SHA512"
    EGK_GPGPASSRPT=2

    EGK_TMPPATH="/tmp"
    EGK_TMPDIR=""
    EGK_DEBUG=false
    EGK_BASHDEBUG=false

    ## -------------------------------------
    ## Set-up "GNU" getopt
    cliSOpts="hvn:e:S:L:s:l:" # O:
    cliLOpts="bash-debug,debug,"\
"quiet,silent,help,version,version-num,copyright,"\
"size:,lifetime:,sub-size:,sub-lifetime:,"\
"gnupg-home:,"\
"no-sign,no-encr,no-auth,otr,"\
"out-dir:,no-export,no-export-pub,no-export-sec"\
"no-revoke,no-info,no-calendar,no-qr,no-vcard,keep-master" 
# gnupg-opts:,
# "name:,email:,"\

    cliOpts=$($getoptCmd --name        "$EGK_PROG" \
                         --options     "$cliSOpts" \
                         --longoptions "$cliLOpts" \
                         --quiet \
                         -- "$@")
    ## Check that we got *all* of the command-line inputs?
    if [ $? != 0 ] ; then fatal "Failed to parse command-line arguments" ; fi
    ## Set `em
    eval set -- "$cliOpts"

    ## Parse `em
    while true; do
	case "$1" in
	    ## About
	    -h | --help        ) 
		version; copyright; license; echo ""; usage;  exit 0 ;;
	    -v | --version     ) version; copyright; license; exit 0 ;;
                 --version-num ) echo "$EGK_VERSION";         exit 0 ;;
                 --copyright   ) copyright; license;          exit 0 ;;
                 --quiet       ) EGK_QUIET=true;              shift ;;
                 --silent      ) EGK_SILENT=true;             shift ;;
                 --debug       ) EGK_DEBUG=true;              shift ;;
                 --bash-debug  ) 
		EGK_DEBUG=true; 
		EGK_BASHDEBUG=true;          
		shift ;;

	    ## EGK Options
	    -S | --size          ) EGK_KEYSIZE="$2";     shift 2 ;;
	    -L | --lifetime      ) EGK_KEYLIFE="$2";     shift 2 ;;
	    -s | --sub-size      ) EGK_SUBKEYSIZE="$2";  shift 2 ;;
	    -l | --sub-lifetime  ) EGK_SUBKEYLIFE="$2";  shift 2 ;;
                 --no-sign       ) EGK_GENSIGN=false;    shift ;;
                 --no-encr       ) EGK_GENENCR=false;    shift ;;
                 --no-auth       ) EGK_GENAUTH=false;    shift ;;
                 --otr           ) EGK_GENOTR=true;     shift ;;
	         --out-dir       ) EGK_OUTDIR="$2";      shift 2 ;;
                 --no-export     ) EGK_EXPORT=false;     shift ;;
                 --no-export-pub ) EGK_EXPORTPUB=false;  shift ;;
                 --no-export-sec ) EGK_EXPORTSEC=false;  shift ;;
                 --no-export-sub ) EGK_EXPORTSUB=false;  shift ;;
                 --no-revoke     ) EGK_EXPORTREV=false;  shift ;;
                 --no-info       ) EGK_EXPORTSUM=false;  shift ;;
                 --no-calendar   ) EGK_EXPORTCAL=false;  shift ;;
                 --no-qr         ) EGK_EXPORTQR=false;   shift ;;
                 --no-vcard      ) EGK_EXPORTVC=false;   shift ;;
                 --keep-master   ) EGK_KEEPMASTER=true;  shift ;;

	    ## GnuPG options
	         --gnupg-home   ) EGK_GPGHOME="$2"; shift 2 ;;
	    
	    ## Misc
	    -- ) shift; break ;;
	    *  ) fatal "getopt error" ;;
	esac
    done

    ## Attempt to interpret remaining arg as master name & email
    for arg 
    do 
	oldIFS="$IFS"
	IFS=$','
	for uid in $arg
	do
	    if [[ -z "${EGK_NAME:-}" ]]; then 
		EGK_NAME=$(parse_uid_name "$uid")
		EGK_MAIL=$(parse_uid_mail "$uid")
	    else
		if [ "${uid:0:1}" == "<" ] ; then 
		    EGK_NAMES=("${EGK_NAMES[@]}" "$EGK_NAME")
		    EGK_MAILS=("${EGK_MAILS[@]}" $(parse_uid_mail "$uid"))
		else 
		    EGK_NAMES=("${EGK_NAMES[@]}" $(parse_uid_name "$uid"))
		    EGK_MAILS=("${EGK_MAILS[@]}" $(parse_uid_mail "$uid"))
		fi
	    fi
	done
	unset uid
	IFS="$oldIFS"
    done

    ## -------------------------------------
    ## Check variables

    ## Set variables for debugging 
    if [ "$EGK_DEBUG" == true ] ; then
    	## Use this for testing & development
    	EGK_GPGHOME="test/dot.gnupg"
    	EGK_TMPPATH="test"
    	## Echo all bash commands
	if [ "$EGK_BASHDEBUG" == true ] ; then set -x; fi
    fi

    ## UID
    if [[ -z "${EGK_NAME:-}" ]]; then 
	opt_error "Must give a name for key UID."; 
    fi
    if [[ -z "${EGK_MAIL:-}" ]]; then 
	opt_error "Must give an email for key UID."; 
    fi

    ## Check for sane key-lengths
    if [ $EGK_KEYSIZE -gt 4096 ] || [ $EGK_KEYSIZE -lt 1024 ] ; then
	opt_error "Master key length $EGK_KEYSIZE out of range [1024, 4096]"
    fi
    if [ $EGK_SUBKEYSIZE -gt 4096 ] || [ $EGK_SUBKEYSIZE -lt 1024 ] ; then
	opt_error "Sub-key length $EGK_KEYSIZE out of range [1024, 4096]"
    fi

    ## GnuPG
    ## Check if gnupg homedir variable is set
    if [[ -z "${EGK_GPGHOME:-}" ]] ; then 
	opt_error "GnuPG home directory not set"; 
    fi
    ## Check if gnupg homedir exists
    if [[ ! -d "$EGK_GPGHOME" ]] ; then 
	log "Creating GnuPG home directory: $EGK_GPGHOME"; 
	"$mkdirCmd" "$EGK_GPGHOME"
	"$chmodCmd" u=rwx,g=,o= "$EGK_GPGHOME"
    fi
    ## Check if gnupg homedir is accesible; GnuPG will check other permissions
    if [[ ! -r "$EGK_GPGHOME" ]] || [[ ! -w "$EGK_GPGHOME" ]] ; then 
	opt_error "GnuPG home directory not accessible: $EGK_GPGHOME"; 
    fi

    ## Check for cipher-algo
    if [[ "$gpgVstr" != *"$EGK_GPGCIPHERALGO"* ]]; then 
	warning "cipher-algo $EGK_GPGCIPHERALGO not found, using CAST5" 
	EGK_GPGCIPHERALGO="CAST5"
    fi
    ## Check for digest-algo
    if [[ "$gpgVstr" != *"$EGK_GPGDIGESTALGO"* ]]; then 
	warning "digest-algo $EGK_GPGDIGESTALGO not found, using SHA1" 
	EGK_GPGDIGESTALGO="SHA1"
    fi

    ## Dump some options 
    debug "EGK:"
    debug "  UID:     $EGK_NAME <$EGK_MAIL>"
    debug "  Names:   ${EGK_NAMES[@]}"
    debug "  Mails:   ${EGK_MAILS[@]}"
    debug "  Master:  $EGK_KEYSIZE-bits $EGK_KEYLIFE"
    debug "  Sub-Key: $EGK_SUBKEYSIZE-bits $EGK_SUBKEYLIFE"
    debug "GnuPG:"
    debug "  Version: $gpgVersion"
    debug "  Cmd:     $gpgCmd"
    debug "  Home:    $EGK_GPGHOME"
}


## *****************************************************************************
## Main
function gneasy_genkey(){
    ## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    ## preliminaries
    trap cleanup EXIT   ## It's a trap!
    check_dependencies  ## Check for dependencies
    parse_options "$@"  ## Parse & set the options
    mktmp_dir           ## Create directory for tmp-files
    
    ## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    ## Generate keys
    log "Creating new GnuPG keys for User-ID: $EGK_NAME <$EGK_MAIL>"
    log "Use a strong and memorable pass-phrase to protect your secret key."

    ## -----------------
    ## Master Key; sets global variable $masterKeyId
    egk_gpg_gen_master "$EGK_NAME" "$EGK_MAIL" "$EGK_KEYSIZE" "$EGK_KEYLIFE"

    ## -----------------
    ## Sub-keys
    if [ "$EGK_GENSIGN" == true ] ; then 
    	egk_gpg_gen_subkey "signing" "$masterKeyId"\
                           "$EGK_SUBKEYSIZE" "$EGK_SUBKEYLIFE"
    fi
    if [ "$EGK_GENENCR" == true ] ; then 
    	egk_gpg_gen_subkey "encryption" "$masterKeyId"\
                           "$EGK_SUBKEYSIZE" "$EGK_SUBKEYLIFE"
    fi
    if [ "$EGK_GENAUTH" == true ] ; then 
    	egk_gpg_gen_subkey "authentication" "$masterKeyId"\
                           "$EGK_SUBKEYSIZE" "$EGK_SUBKEYLIFE"
    fi
    if [ "$EGK_GENOTR"  == true ] ; then 
    	egk_gpg_gen_subkey "otr" "$masterKeyId"\
                           "1024" "$EGK_SUBKEYLIFE"
    fi

    ## -----------------
    ## UIDs
    if [[ ${#EGK_NAMES[@]} -gt 0 ]] ; then 
	egk_gpg_add_uids "$masterKeyId"
    fi

    ## Debug 
    if [ "$EGK_DEBUG" == true ] ; then 
    	debug "Key info: "
    	egk_gpg_listsecretkey "$masterKeyId"
    fi

    ## +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    ## Exports & backups
    if [ "$EGK_EXPORT" == true ] ; then 
        ## Make output directory
        local outDir=$(mkout_dir "$masterKeyId")

	## -----------------
    	## Revocation
    	if [ "$EGK_EXPORTREV" == true ] ; then 
    	    log "Use a strong and memorable pass-phrase to protect your"\
                "revocation certificate."
    	    local ercF=$(egk_gpg_export_revoke "$masterKeyId" "$outDir")
    	    if [[ -e "$ercF" ]] ; then log "Exported revocation: $ercF"
    	    else warning "Failed to export revocation certificate" ; fi
    	fi

	## -----------------
        ## Public key
    	if [ "$EGK_EXPORTPUB" == true ] ; then 
    	    local pubF=$(egk_gpg_export_key "$masterKeyId" \
    		         "$outDir" "public")
    	    if [[ -e "$pubF" ]] ; then log "Exported public key: $pubF"
    	    else warning "Failed to export public key" ; fi
    	fi

 	## -----------------
   	## Secret key
    	if [ "$EGK_EXPORTSEC" == true ] ; then 
    	    local secF=$(egk_gpg_export_key "$masterKeyId" \
    		         "$outDir" "secret")
    	    if [[ -e "$secF" ]] ; then log "Exported secret key: $secF"
    	    else warning "Failed to export secret key" ; fi
    	fi

 	## -----------------
   	## Secret sub-keys
    	if [ "$EGK_EXPORTSUB" == true ] ; then 
    	    local ssecF=$(egk_gpg_export_key "$masterKeyId" \
    		          "$outDir" "secret-subs")
    	    if [[ -e "$ssecF" ]] ; then log "Exported sub-keys:   $ssecF"
    	    else warning "Failed to export secret sub-keys" ; fi
    	fi

 	## -----------------
   	## Summary
    	if [ "$EGK_EXPORTSUM" == true ] || \
	   [ "$EGK_EXPORTCAL" == true ] || \
	   [ "$EGK_EXPORTQR"  == true ] || \
	   [ "$EGK_EXPORTVC"  == true ] ; then 
	    ## Parse the --list-key output
	    parse_key_info "$masterKeyId"

	    ## -----------------
	    ## Export yaml file
    	    if [ "$EGK_EXPORTSUM" == true ] ; then 
    		local sumF=$(write_key_info_yaml "$masterKeyId" "$outDir")
    		if [[ -e "$sumF" ]] ; then log "Exported summary:    $sumF"
    		else warning "Failed to export key summary" ; fi
    		if [ "$EGK_DEBUG" == true ] ; then 
		    debug "YAML: "; cat "$sumF" ; 
		fi
	    fi

	    ## -----------------
	    ## Export ics file
    	    if [ "$EGK_EXPORTCAL" == true ] ; then 
		local icsF=$(write_ics  "$masterKeyId" "$outDir")
    		if [[ -e "$icsF" ]] ; then log "Exported calendar:   $icsF"
    		else warning "Failed to export key summary" ; fi
    		if [ "$EGK_DEBUG" == true ] ; then 
		    debug "iCal: "; cat "$icsF" ; 
		fi
	    fi

	    ## -----------------
	    ## Export vcard file
    	    if [ "$EGK_EXPORTVC" == true ] ; then 
		local qrF=$(write_vcard  "$masterKeyId" "$outDir")
    		if [[ -e "$qrF" ]] ; then log "Exported vcard:      $qrF"
    		else warning "Failed to export vcard" ; fi
	    fi

	    ## -----------------
	    ## Export QR file
    	    if [ "$EGK_EXPORTQR" == true ] && 
	       [[ -n "${qrCmd:-}" ]]; then 
		local qrF=$(write_uidfpr_qr  "$masterKeyId" "$outDir")
    		if [[ -e "$qrF" ]] ; then log "Exported qr-code:    $qrF"
    		else warning "Failed to export key summary" ; fi
	    fi
    	fi

 	## -----------------
   	## Remove master key from key-ring
    	if [ "$EGK_KEEPMASTER" == false ] && \
    	   [ "$EGK_EXPORTSEC"  == true  ] && [[ -e "$secF"  ]] && \
    	   [ "$EGK_EXPORTSUB"  == true  ] && [[ -e "$ssecF" ]] ; then 
    	    egk_gpg_remove_master "$masterKeyId" "$ssecF"
    	    if [ "$EGK_DEBUG" == true ] ; then 
    		egk_gpg_listsecretkey "$masterKeyId"
    	    fi
    	fi

    	## Debug 
    	if [ "$EGK_DEBUG" == true ] ; then 
    	    debug "Exported files: ${outDir}/"
    	    ls -lh "$outDir" | "$awkCmd" '{ printf "%-30s\t%s\n", $9, $5 }'
    	fi
    fi ## end exports

    ## exit
    exit 0
}


## *****************************************************************************
## Run main method
## *****************************************************************************
gneasy_genkey "$@"


### end gneasy-genkey.sh
### ############################################################################
