#!/bin/bash

#create the necessary directories
reg_creds=/run/containers/0/auth.json
mkdir $registry_base/$name-$operator-$version-index
mkdir $registry_base/olm
cd $registry_base/$name-$operator-$version-index
echo "Created necessary directories."

## Login the both your newly created registry and the redhat.io registry
podman login $registry:5000 -u admin -p redhat
podman login registry.redhat.io -u $user -p $password
echo "Logged into the source registry and the destination registry."

## prune the source index
opm index prune -f registry.redhat.io/redhat/$index:$version -p $name -t $registry:5000/olm/$name-index:$version --generate

echo "Pruned the source image from everything except for the $name."

## Create a Dockerfile and push the image to your registry
podman build --format docker -f index.Dockerfile -t $registry:5000/olm/$name-index:$version
podman push $registry:5000/olm/$name-index:$version
echo "Created a Dockerfile and pushed the image to the internal registry."

## Mirror the images from the index
cd $registry_base/olm/
oc adm catalog mirror $registry:5000/olm/$name-index:$version     $registry:5000 -a $reg_creds --index-filter-by-os='.*' --manifests-only --insecure

echo "Mirrored the images from the source index."

## use skopeo copy to copy the images needed for the operator

# Might deprecate - not needed as of now it seems
#source=`echo "select * from related_image where operatorbundle_name like '%$name.$operator%';" | sqlite3 -line $registry_base/$name-$operator-$version-index/database/index.db | grep image | awk '{print $3}'`
echo "Choose only the images relevant to the version you chose at the beginning of the process."
image_mapping=$(find . -iname "mapping.txt")
all_images=$(cat $image_mapping | grep -v $registry:5000 | awk -F \= '{print $1}')
source_registries=$(printf '%s' "$all_images" | awk -F \/ '{print $1}' | sort | uniq)

for src in $source_registries;do
    if [[ $src != *"redhat"* ]]; then
        continue
    fi
    skopeo login $src -u $user -p $password
done

for image in $all_images;do
    # Save the destination location, including registry and right digest
    # Push the image to your disconnected registry
    remote_registry=$(echo $image | awk -F \/ '{print $1}')
    local_source=$(printf '%s' "$image" | sed "s/$remote_registry/$registry:5000/g")
    skopeo copy -a --dest-tls-verify=false docker://$image docker://$local_source
    echo docker://$local_source >> images.txt
done

echo "Skopeo copy the images from the chosen version into the internal registry."

## tar the whole directory to untar it in the disconnected enviroment.
podman save docker.io/library/registry:2 -o $registry_base/downloads/images/registry.tar
cd $registry_base
tar -cf $name-registry.tar *
echo "Created a tar file from the directory."

