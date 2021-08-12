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



**1.2 Create operator catalog & tar the directory**
We will create an index image. An index image based on the Operator Bundle Format, it is a containerized snapshot of an Operator catalog. We can prune an index of all but a specified list of packages, creating a copy of the source index containing only the Operators we need.

**prerequisites -**
1. Podman version 1.9.3+
2. opm version 1.12.3+
3. Skopeo version 0.1.40


oc version (the same as your openshift cluster)
-	Install opm according to the official tutorial (if not exists):
https://docs.openshift.com/container-platform/4.6/cli_reference/opm-cli.html#opm-cli


**Explanation for the script - **

```
mkdir /opt/registry/acm-index
cd /opt/registry/acm-index
```

1. Create directories.
```
#create the necessary directories
export REG_CREDS=/run/containers/0/auth.json
export REGISTRY_BASE="/opt/registry"
mkdir  ${REGISTRY_BASE}/acm-index
mkdir ${REGISTRY_BASE}/olm
cd ${REGISTRY_BASE}/acm-index
echo "Created necessary directories."
```
2. Input the ACM, OCP versions & the registry FQDN.
```
## Choose the operator version you want to copy
echo 'Enter the ACM version you want (Example: v2.2.5): '
read VERSION
echo 'Enter openshift version you want to install ACM on (Example: v4.6): '
read OPENSHIFT_VERSION
echo 'Enter the registry FQDN: '
read REGISTRY_FQDN
echo 'Enter your RedHat account username: '
read RED_HAT_ACCOUNT_USER
echo 'Enter your RedHat account password: '
read RED_HAT_ACCOUNT_PASSWORD
```
3. Login into both source and destination registries.
```
## Login the both your newly created registry and the redhat.io registry
podman login ${REGISTRY_FQDN}:5000 -u admin -p redhat
podman login registry.redhat.io -u ${RED_HAT_ACCOUNT_USER} -p ${RED_HAT_ACCOUNT_PASSWORD}
echo "Logged into the source registry and the destination registry."
```
4. Use prune to discard the source image from everything except for the advanced-cluster-management.
```
## prune the source index
opm index prune -f registry.redhat.io/redhat/redhat-operator-index:$OPENSHIFT_VERSION     -p advanced-cluster-management -t ${REGISTRY_FQDN}:5000/olm/acm-operator-index:$OPENSHIFT_VERSION --generate
```
5. Create a Dockerfile and push the image to your registry.
```
## Create a Dockerfile and push the image to your registry
podman build --format docker -f index.Dockerfile -t ${REGISTRY_FQDN}:5000/olm/acm-operator-index:$OPENSHIFT_VERSION
podman push ${REGISTRY_FQDN}:5000/olm/acm-operator-index:$OPENSHIFT_VERSION
echo "Created a Dockerfile and pushed the image to the internal registry."
```
6. Mirror the images from the source index.
```
## Mirror the images from the index
cd ${REGISTRY_BASE}/olm/
oc adm catalog mirror ${REGISTRY_FQDN}:5000/olm/acm-operator-index:$OPENSHIFT_VERSION     ${REGISTRY_FQDN}:5000 -a ${REG_CREDS} --filter-by-os='.*' --manifests-only --insecure
echo "Mirrored the images from the source index."
```
7. use skopeo copy to copy the images needed for the operator
```
## use skopeo copy to copy the images needed for the operator
export SOURCE=`echo "select * from related_image where operatorbundle_name like '%advanced-cluster-management.${VERSION}%';" | sqlite3 -line ${REGISTRY_BASE}/acm-index/database/index.db | grep image | awk '{print $3}'`
echo "Choose only the images relevant to the version you chose at the beginning of the process."
for image in $SOURCE;do
    # Save the destination location, including registry and right digest
    # Push the image to your disconnected registry
    IMAGE_NAME=$(echo $image | awk -F \/ '{print $3}')
    IMAGE_NAMESPACE=$(echo $image | awk -F \/ '{print $2}')
    skopeo copy -a --dest-tls-verify=false docker://${image} docker://${REGISTRY_FQDN}:5000/${IMAGE_NAMESPACE}/${IMAGE_NAME}
    echo docker://${REGISTRY_FQDN}:5000/${IMAGE_NAMESPACE}/${IMAGE_NAME} >> images.txt
done
echo "Skopeo copy the images from the chosen version into the internal registry."
```
8. Create a tar file from the whole directory to use it in the disconnected environment.
```
## tar the whole directory to untar it in the disconnected enviroment.
podman save  docker.io/library/registry:2 -o ${REGISTRY_BASE}/downloads/images/registry.tar
cd ${REGISTRY_BASE}
tar -cf acm-registry.tar *
echo "Created a tar file from the directory."
```
