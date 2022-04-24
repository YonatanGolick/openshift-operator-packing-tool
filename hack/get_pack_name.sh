#!/bin/bash
print_help_message(){
    echo "Usage:
 get_pack_name.sh -v [Openshift Version] -u [RedHat Account User] -p [Password] -i [Operator Index Name]

    Valid index names are:
      - certified-operator-index
      - community-operator-index
      - redhat-marketplace-index
      - redhat-operator-index"
}
check_missing_params() {
  [ -z $version ] && echo "Missing Openshift version" && print_help_message && exit 1
  [ -z $user ] && echo "Missing RedHat username" && print_help_message && exit 1
  [ -z $password ] && echo "Missing RedHat user password" && print_help_message && exit 1
  [ -z $index ] && echo  "Missing index name" && print_help_message && exit 1
}
is_index_valid() {
  index_list=("certified-operator-index" "community-operator-index" "redhat-marketplace-index" "redhat-operator-index")
  for i in "${index_list[@]}"
  do
    if [ "$index" = "$i" ]; then
      return 
    fi
  done
  echo "Invalid index name!
  " && print_help_message && exit 1
}
grpcurl_exists() {
    if [[ -f /usr/bin/grpcurl ]]; then 
      echo -e "grpcurl Exists - skipping download...\n"
    else
      echo -e "grpcurl not found, downloading grpcurl to fetch package names from the index...\n"
      wget https://github.com/fullstorydev/grpcurl/releases/download/v1.8.5/grpcurl_1.8.5_linux_x86_64.tar.gz 

      echo -e "Trasfer grpcurl to /usr/bin for usage\n"
      tar -xvzf grpcurl_1.8.5_linux_x86_64.tar.gz -C /usr/bin/.
    fi
}
list_packages() {
        grpcurl -plaintext localhost:50051 api.Registry/ListPackages
}
while getopts ":v:u:p:i:" flag; do
  case $flag in
    v)version=$OPTARG >&2;;
    u)user=$OPTARG >&2;;
    p)password=$OPTARG >&2;;
    i)index=$OPTARG >&2;;
    ?)print_help_message >&2;;
    *)echo "No argument was given!" >&2 ;;
  esac
done

check_missing_params

is_index_valid 

grpcurl_exists

container_id=$(podman run -p50051:50051 -dit registry.redhat.io/redhat/$index:$version >&1)

echo -e "Printing package names for $index-$version\n\n---------------------------------------------"
while ! list_packages >/dev/null 2>&1
do
        echo "Index container Not ready yet..."
        sleep 3
done
list_packages
echo -e "---------------------------------------------\n\n"

echo -e "Cleaning up the created container...\n\n"

podman stop $container_id
podman rm $container_id
