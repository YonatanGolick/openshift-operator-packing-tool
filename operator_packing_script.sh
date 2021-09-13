#create the necessary directories
export REG_CREDS=/run/containers/0/auth.json
export REGISTRY_BASE="/opt/registry"
mkdir  ${REGISTRY_BASE}/acm-index
mkdir ${REGISTRY_BASE}/olm
cd ${REGISTRY_BASE}/acm-index
echo "Created necessary directories."

echo 'Enter your RedHat account username: '
read RED_HAT_ACCOUNT_USER

echo 'Enter your RedHat account password: '
read RED_HAT_ACCOUNT_PASSWORD
## Choose the operator version you want to copy
echo 'Enter the ACM version you want (Example: v2.2.5): '
read VERSION

echo 'Enter openshift version you want to install ACM on (Example: v4.6): '
read OPENSHIFT_VERSION

echo 'Enter the registry FQDN: '
read REGISTRY_FQDN


## Login the both your newly created registry and the redhat.io registry

podman login ${REGISTRY_FQDN}:5000 -u admin -p redhat
podman login registry.redhat.io -u ${RED_HAT_ACCOUNT_USER} -p ${RED_HAT_ACCOUNT_PASSWORD}
echo "Logged into the source registry and the destination registry."
## prune the source index

opm index prune -f registry.redhat.io/redhat/redhat-operator-index:$OPENSHIFT_VERSION     -p advanced-cluster-management -t ${REGISTRY_FQDN}:5000/olm/acm-operator-index:$OPENSHIFT_VERSION --generate

echo "Pruned the source image from everything except for the advanced-cluster-management."

## Create a Dockerfile and push the image to your registry
podman build --format docker -f index.Dockerfile -t ${REGISTRY_FQDN}:5000/olm/acm-operator-index:$OPENSHIFT_VERSION
podman push ${REGISTRY_FQDN}:5000/olm/acm-operator-index:$OPENSHIFT_VERSION
echo "Created a Dockerfile and pushed the image to the internal registry."

## Mirror the images from the index
cd ${REGISTRY_BASE}/olm/
oc adm catalog mirror ${REGISTRY_FQDN}:5000/olm/acm-operator-index:$OPENSHIFT_VERSION     ${REGISTRY_FQDN}:5000 -a ${REG_CREDS} --filter-by-os='.*' --manifests-only --insecure

echo "Mirrored the images from the source index."
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
## tar the whole directory to untar it in the disconnected enviroment.
podman save  docker.io/library/registry:2 -o ${REGISTRY_BASE}/downloads/images/registry.tar
cd ${REGISTRY_BASE}
tar -cf acm-registry.tar *
echo "Created a tar file from the directory."
