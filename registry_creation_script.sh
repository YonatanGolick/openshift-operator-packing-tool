## This is an automated procedure for creating an empty registry to be used for an operator whitening.
##create all the necessary directories.
mkdir /opt/registry
echo 'Enter the registry FQDN you want to create: '
read REGISTRY_FQDN
export REGISTRY_BASE="/opt/registry"
mkdir -p ${REGISTRY_BASE}/{auth,certs,data,downloads}
mkdir -p ${REGISTRY_BASE}/downloads/{images,tools,secrets}
echo "Created a bunch of directories"
## Add the registry FQDN to /etc/hosts
echo "127.0.0.1      ${REGISTRY_FQDN}" >> /etc/hosts
echo "Added the registry FQDN to /etc/hosts"
## Install necessary dependencies.
yum install -y jq openssl podman  curl wget skopeo
yum install -y  nmap telnet openldap-clients tcpdump
yum install -y net-tools httpd-tools podman sqlite
echo "Installed necessary packages"
## Create a self-signed certificate for the registry
cd ${REGISTRY_BASE}/certs/
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
CN=${REGISTRY_FQDN}

[ req_ext ]
subjectAltName = @alt_names
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ alt_names ]
DNS.1 = ${REGISTRY_FQDN}" > ${REGISTRY_BASE}/certs/answerFile.txt
openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt -config <( cat ${REGISTRY_BASE}/certs/answerFile.txt )
echo "Created a domain.crt for the registry to have a certificate."
cp ${REGISTRY_BASE}/certs/domain.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract
## Create username and password to authenticate with the registry
htpasswd -bBc ${REGISTRY_BASE}/auth/htpasswd admin redhat
echo "Created username and password to authenticate with the registry"
## Open the used port to allow pulling from the registry
systemctl start firewalld
firewall-cmd --add-port=5000/tcp --zone=public --permanent
firewall-cmd --reload
echo "Enabled traffic on port 5000 to be used by the registry."
## Create the registry
echo 'podman run --name registry --rm -d -p 5000:5000 \
        -v ${REGISTRY_BASE}/data:/var/lib/registry:z \
        -v ${REGISTRY_BASE}/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" \
        -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" \
        -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" \
        -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
        -v ${REGISTRY_BASE}/certs:/certs:z \
        -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
        -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
docker.io/library/registry:2' > ${REGISTRY_BASE}/downloads/tools/start_registry.sh
chmod a+x ${REGISTRY_BASE}/downloads/tools/start_registry.sh
${REGISTRY_BASE}/downloads/tools/start_registry.sh
sleep 5
echo ''
curl -u admin:redhat -k https://$REGISTRY_FQDN:5000/v2/_catalog
echo ''
echo ''
echo 'The script needs to return {"repositories":[]}, if everything worked.'
