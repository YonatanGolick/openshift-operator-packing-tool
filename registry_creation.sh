#!/bin/bash

mkdir -p ${registry_base}/{auth,certs,data,downloads}
mkdir -p ${registry_base}/downloads/{images,tools,secrets}

## Add the registry FQDN to /etc/hosts
echo "127.0.0.1      ${registry}" >> /etc/hosts

## Install necessary dependencies.
yum install -y jq openssl podman  curl wget skopeo
yum install -y  nmap telnet openldap-clients tcpdump
yum install -y net-tools httpd-tools podman sqlite

## Create a self-singed certificate for the registry
cd ${registry_base}/certs/

echo " [req]
default_bits = 4096
prompt = no
default_md = sha256
x509_extensions = req_ext
req_extensions = req_ext
distinguished_name = dn
[ dn ]
C=US
ST=New York
L=New York
O=MyOrg
OU=MyOU
emailAddress=me@working.me
CN=${registry}
[ req_ext ]
subjectAltName = @alt_names
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
[ alt_names ]
DNS.1 = ${registry}" > ${registry_base}/certs/answerFile.txt 

openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt -config <( cat ${registry_base}/certs/answerFile.txt )
cp ${registry_base}/certs/domain.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract

## Create username and password to authenticate with the registry
htpasswd -bBc ${registry_base}/auth/htpasswd admin redhat

## Open the used port to allow pulling from the registry
systemctl start firewalld
firewall-cmd --add-port=5000/tcp --zone=public --permanent
firewall-cmd --reload

## Create the registry
echo 'podman run --name registry --rm -d -p 5000:5000 \
	-v ${registry_base}/data:/var/lib/registry:z \
	-v ${registry_base}/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" \
	-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" \
	-e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" \
	-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
	-v ${registry_base}/certs:/certs:z \
	-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
	-e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
docker.io/library/registry:2' > ${registry_base}/downloads/tools/start_registry.sh
chmod a+x ${registry_base}/downloads/tools/start_registry.sh
. ${registry_base}/downloads/tools/start_registry.sh

sleep 5
echo ''
curl -u admin:redhat -k https://$registry:5000/v2/_catalog
echo ''
echo ''
echo 'The script needs to return {"repositories":[]}, if it did everything worked.'