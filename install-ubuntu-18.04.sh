#!/bin/bash
set -e

if [[ $# -lt 1 ]]; then
	echo "Usage: $0 <main.domain>"
	exit 1
fi

export cdir=$(pwd)
echo "Welcome! This will install docker, systemd scripts and a CA. Sit back."

apt-get -y update
apt-get install -y unzip curl git bridge-utils syslog-ng software-properties-common pwgen
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get -y update
apt-get install -y docker-ce

cat >/etc/syslog-ng/conf.d/dockers.conf <<EOF
# syslog-ng dockers log config

options {
    use_dns(no);
    keep_hostname(yes);
    create_dirs(yes);
    ts_format(iso);
};

source s_net_dck { udp(ip(169.254.254.254) port(5514)); };
source s_net_log { udp(ip(169.254.254.254) port(514)); };

rewrite r_net_dck {
    subst ("^/usr/(sbin|bin)/", "", value (PROGRAM));
    subst ("^/(sbin|bin)/", "", value (PROGRAM));
    subst ("/", "-", value (PROGRAM));
    subst ("^-", "", value (PROGRAM));
    subst ("^169.254.254.254$", "", value (HOST));
};

filter f_net_dck { facility(local7); };

destination d_dockers { file("/var/log/dockers/\${YEAR}-\${MONTH}-\${DAY}/\${PROGRAM}.log"); };
destination d_net_log { file("/var/log/dockers/\${YEAR}-\${MONTH}-\${DAY}/\${HOST}.log"); };

log { source(s_net_dck); filter(f_net_dck); rewrite(r_net_dck); destination(d_dockers); flags(final); };
log { source(s_net_log); destination(d_net_log); flags(final); };

EOF

mkdir -p /var/log/dockers 2>/dev/null >/dev/null
chmod 0700 /var/log/dockers

cat >/etc/docker/daemon.json <<EOF
{
        "dns": [
                "8.8.8.8",
                "8.8.4.4"
        ],
        "log-opts": {
                "tag": "{{.Name}}",
		"syslog-facility": "local7",
		"syslog-address": "udp://169.254.254.254:5514",
		"syslog-format": "rfc3164"
        },
        "storage-driver": "overlay2",
        "log-driver": "syslog",
        "userland-proxy": false,
        "tls": true,
        "tlscacert": "/etc/docker/ca.crt",
        "tlscert": "/etc/docker/docker.crt",
        "tlskey": "/etc/docker/docker.key"
}
EOF

cd /etc
curl -fsSL https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.6/EasyRSA-unix-v3.0.6.tgz -o - | tar xz
mv EasyRSA-* CA
cd -
cd /etc/CA

./easyrsa init-pki
echo "$1 CA" | ./easyrsa build-ca nopass
./easyrsa build-server-full docker nopass

cat <<EOF >x509-types/server
subjectAltName=\${ENV::SAN}
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage = serverAuth,1.3.6.1.5.5.8.2.2
keyUsage = digitalSignature,keyEncipherment,dataEncipherment
EOF

cat <<EOF >x509-types/client
subjectAltName=\${ENV::SAN}
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage = clientAuth
keyUsage = digitalSignature
EOF

export SAN="DNS:$1"
./easyrsa build-server-full $1 nopass

cp ${cdir}/utils/build-client.sh .
chmod 0700 build-client.sh

cp ${cdir}/utils/genmobileconfig.sh .
chmod 0700 genmobileconfig.sh

cp pki/issued/docker.crt /etc/docker/
cp pki/private/docker.key /etc/docker/
cp pki/ca.crt /etc/docker/
systemctl enable docker
systemctl restart docker
cd -

cat >/etc/systemd/system/docker@.service <<EOF
[Unit]
Description=Docker container for %i
After=docker.service

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/usr/bin/docker start -a %i
ExecStop=/usr/bin/docker stop -t 120 %i
Restart=always
RestartSec=30s
EOF

cat > /etc/rc.local <<EOF
#!/bin/bash
/sbin/brctl addbr link
echo 1 >/proc/sys/net/ipv4/ip_forward
/sbin/ip a replace 169.254.254.254/32 dev link
/sbin/ip link set dev link up
exit 0
EOF
chmod 0700 /etc/rc.local
/etc/rc.local

systemctl daemon-reload

systemctl restart syslog-ng
systemctl restart docker

echo 'export CONSUL_HTTP_ADDR="169.254.254.254:8500"' >> /etc/bash.bashrc
echo 'export NOMAD_ADDR="http://169.254.254.254:4646/"' >> /etc/bash.bashrc
echo '. /etc/docker_macros' >> /etc/bash.bashrc

curl -L https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod 0700 /usr/local/bin/docker-compose
cp utils/logrotate.sh /usr/local/bin/
chmod 755 /usr/local/bin/logrotate.sh
cat >/etc/cron.d/logrotate <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
00 2 * * *   root	/usr/local/bin/logrotate.sh
EOF

cp systemd-scripts/* /etc/systemd/system/
cp utils/docker_macros /etc/
cp utils/dc /usr/local/bin/

echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf

dnsserver=$(systemd-resolve --status | grep "DNS Servers" | head -n 1 | cut -d ':' -f 2)

systemctl disable systemd-resolved
systemctl stop systemd-resolved

rm /etc/resolv.conf

cat <<EOF > /etc/resolv.conf
nameserver$dnsserver
EOF

echo "Done. Enjoy life."

