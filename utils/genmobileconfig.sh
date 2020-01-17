#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <id> <p12pass>"
    exit 1
fi

export MC_SSO=$1
export MC_PWD=$2
export MC_P12_UUID=$(cat /proc/sys/kernel/random/uuid | tr 'a-z' 'A-Z')
export MC_CN=$(openssl x509 -in ./pki/issued/${MC_SSO}.crt -noout -text | grep "email:" | cut -d ":" -f 2)
export MC_CA_CN=$(openssl x509 -in ./pki/ca.crt -noout -text | grep "Subject: CN" | cut -d "=" -f 2 | sed 's/^  *//g')
export MC_REMOTE_FQDN=$(echo $MC_CA_CN | cut -d " " -f 1)
export MC_VPN_UUID=$(cat /proc/sys/kernel/random/uuid | tr 'a-z' 'A-Z')
export MC_PAYLOAD_UUID=$(cat /proc/sys/kernel/random/uuid | tr 'a-z' 'A-Z')

export MC_P12_B64=$(cat ${MC_SSO}.p12 | base64)

cat >${MC_SSO}.mobileconfig <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PayloadContent</key>
	<array>
		<dict>
			<key>Password</key>
			<string>${MC_PWD}</string>
			<key>PayloadCertificateFileName</key>
			<string>${MC_SSO}.p12</string>
			<key>PayloadContent</key>
			<data>
${MC_P12_B64}
			</data>
			<key>PayloadDescription</key>
			<string>Adds a PKCS#12-formatted certificate</string>
			<key>PayloadDisplayName</key>
			<string>${MC_SSO}.p12</string>
			<key>PayloadIdentifier</key>
			<string>com.apple.security.pkcs12.${MC_P12_UUID}</string>
			<key>PayloadType</key>
			<string>com.apple.security.pkcs12</string>
			<key>PayloadUUID</key>
			<string>${MC_P12_UUID}</string>
			<key>PayloadVersion</key>
			<integer>1</integer>
		</dict>
		<dict>
			<key>IKEv2</key>
			<dict>
				<key>AuthenticationMethod</key>
				<string>Certificate</string>
				<key>ChildSecurityAssociationParameters</key>
				<dict>
					<key>DiffieHellmanGroup</key>
					<integer>14</integer>
					<key>EncryptionAlgorithm</key>
					<string>AES-256</string>
					<key>IntegrityAlgorithm</key>
					<string>SHA2-256</string>
					<key>LifeTimeInMinutes</key>
					<integer>1440</integer>
				</dict>
				<key>DeadPeerDetectionRate</key>
				<string>Medium</string>
				<key>DisableMOBIKE</key>
				<integer>0</integer>
				<key>DisableRedirect</key>
				<integer>0</integer>
				<key>EnableCertificateRevocationCheck</key>
				<integer>0</integer>
				<key>EnablePFS</key>
				<integer>0</integer>
				<key>ExtendedAuthEnabled</key>
				<true/>
				<key>IKESecurityAssociationParameters</key>
				<dict>
					<key>DiffieHellmanGroup</key>
					<integer>14</integer>
					<key>EncryptionAlgorithm</key>
					<string>AES-256</string>
					<key>IntegrityAlgorithm</key>
					<string>SHA2-256</string>
					<key>LifeTimeInMinutes</key>
					<integer>1440</integer>
				</dict>
				<key>LocalIdentifier</key>
				<string>${MC_CN}</string>
				<key>PayloadCertificateUUID</key>
				<string>${MC_P12_UUID}</string>
				<key>RemoteAddress</key>
				<string>${MC_REMOTE_FQDN}</string>
				<key>RemoteIdentifier</key>
				<string>${MC_REMOTE_FQDN}</string>
				<key>ServerCertificateCommonName</key>
				<string>${MC_REMOTE_FQDN}</string>
				<key>ServerCertificateIssuerCommonName</key>
				<string>${MC_CA_CN}</string>
				<key>UseConfigurationAttributeInternalIPSubnet</key>
				<integer>0</integer>
			</dict>
			<key>IPv4</key>
			<dict>
				<key>OverridePrimary</key>
				<integer>0</integer>
			</dict>
			<key>PayloadDescription</key>
			<string>Configures VPN settings</string>
			<key>PayloadDisplayName</key>
			<string>VPN</string>
			<key>PayloadIdentifier</key>
			<string>com.apple.vpn.managed.${MC_VPN_UUID}</string>
			<key>PayloadType</key>
			<string>com.apple.vpn.managed</string>
			<key>PayloadUUID</key>
			<string>${MC_VPN_UUID}</string>
			<key>PayloadVersion</key>
			<integer>1</integer>
			<key>Proxies</key>
			<dict>
				<key>HTTPEnable</key>
				<integer>0</integer>
				<key>HTTPSEnable</key>
				<integer>0</integer>
			</dict>
			<key>UserDefinedName</key>
			<string>${MC_REMOTE_FQDN} EAP VPN</string>
			<key>VPNType</key>
			<string>IKEv2</string>
		</dict>
	</array>
	<key>PayloadDescription</key>
	<string>This adds the ${MC_REMOTE_FQDN} VPN configuration</string>
	<key>PayloadDisplayName</key>
	<string>${MC_REMOTE_FQDN} VPN</string>
	<key>PayloadIdentifier</key>
	<string>ur.vpn.${MC_PAYLOAD_UUID}</string>
	<key>PayloadOrganization</key>
	<string>UR.GD</string>
	<key>PayloadRemovalDisallowed</key>
	<false/>
	<key>PayloadType</key>
	<string>Configuration</string>
	<key>PayloadUUID</key>
	<string>${MC_PAYLOAD_UUID}</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
</dict>
</plist>
EOF

