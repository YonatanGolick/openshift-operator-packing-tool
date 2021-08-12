# preparing-rhacm-operator-for-disconnected-openshift-cluster

**1.1 Registry Creation**
**prerequisites - **

1. Use RHEL 8 Registered & subscribed system.
2. Check that you don't have a registry running on your machine.
3. Check that you don’t have a directory /opt/registry, if so delete it.
4. Delete any existing .crt in /etc/pki/ca-trust/source/anchors/
5. Work as root user !

**Explanation for the script -**

1. Create directories
```
## This is an automated procedure for creating an empty registry to be used for an operator whitening.
##create all the necessary directories.
mkdir /opt/registry
echo 'Enter the registry FQDN you want to create: '
read REGISTRY_FQDN
export REGISTRY_BASE="/opt/registry"
mkdir -p ${REGISTRY_BASE}/{auth,certs,data,downloads}
mkdir -p ${REGISTRY_BASE}/downloads/{images,tools,secrets}
echo "Created a bunch of directories"
```
2. Update /etc/hosts with the name of the registry server
```
## Add the registry FQDN to /etc/hosts
echo "127.0.0.1      ${REGISTRY_FQDN}" >> /etc/hosts
echo "Added the registry FQDN to /etc/hosts"
```
3. Install necessary packages
```
## Install necessary dependencies.
yum install -y jq openssl podman  curl wget skopeo
yum install -y  nmap telnet openldap-clients tcpdump
yum install -y net-tools httpd-tools podman sqlite
echo "Installed necessary packages"
```
4. Now we will create an answer file for self-signed certificate for our temporary registry
```
## Create a self-signed certificate for the registry
cd ${REGISTRY_BASE}/certs/
echo " [req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
[ dn ]
C=IL
ST=TLV
L=TLV
O=Org
OU=OU
emailAddress=local@local.com
CN = ${REGISTRY_FQDN}" > ${REGISTRY_BASE}/certs/answerFile.txt
```
5. Generate self-signed certificate, it will generate files that we will use in next steps
```
openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt -config <( cat ${REGISTRY_BASE}/certs/answerFile.txt )
echo "Created a domain.crt for the registry to have a certificate."
```
6. Add the new self-signed certificate to the OS trustore.
```
cp ${REGISTRY_BASE}/certs/domain.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract
```
7. Generate a user for our registry
```
## Create username and password to authenticate with the registry
htpasswd -bBc ${REGISTRY_BASE}/auth/htpasswd admin redhat
echo "Created username and password to authenticate with the registry"
```
8. Make sure to expose port 5000 on your registry host
```
## Open the used port to allow pulling from the registry
systemctl start firewalld
firewall-cmd --add-port=5000/tcp --zone=public --permanent
firewall-cmd --reload
echo "Enabled traffic on port 5000 to be used by the registry."
```
9. Now we are ready to run our registry container, create a start script.
```
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
```
10. Change file permissions and execute it
```
chmod a+x ${REGISTRY_BASE}/downloads/tools/start_registry.sh
${REGISTRY_BASE}/downloads/tools/start_registry.sh
```
11. Verify connectivity
```
curl -u admin:redhat -k https://$REGISTRY_FQDN:5000/v2/_catalog
```
