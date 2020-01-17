#!/bin/bash
if [[ $# -lt 2 ]]; then
	echo "Usage: $0 <name> <id> [p12-password]"
	exit 1
fi

[ -f "/etc/CA/pki/reqs/$1.req" ] && rm -f "/etc/CA/pki/reqs/$1.req"
[ -f "/etc/CA/pki/private/$1.key" ] && rm -f "/etc/CA/pki/private/$1.key"
[ -f "/etc/CA/pki/issued/$1.crt" ] && rm -f "/etc/CA/pki/issued/$1.crt"

export EASYRSA_DN="org"
export EMAIL=$(eco "$1@ur.gd" | tr ' ' '.')
export SSO=$2
export DEVID=$(echo $RANDOM$RANDOM$RANDOM | sha1sum | cut -d " " -f  1)
export SAN="email:$2@${DEVID}.ur"

./easyrsa --req-st="" --req-c="" --req-city="" --req-cn="$2@${DEVID}.ge" --req-email="$EMAIL" --req-ou="" --req-org="UR.GD" build-client-full "$2@${DEVID}.ur" nopass 
cp "pki/issued/$2@${DEVID}.ur.crt" "pki/issued/$2.crt"
cp "pki/private/$2@${DEVID}.ur.key" "pki/private/$2.key"

export OPENSSL_EXTRA=
if [ "x$3" != "x" ]; then
	export OPENSSL_EXTRA="-password pass:$3 "
fi

openssl pkcs12 -export -out $2.p12 -in "pki/issued/$2.crt" -inkey "pki/private/$2.key" $OPENSSL_EXTRA -certfile pki/ca.crt 
./genmobileconfig.sh $2 $3

