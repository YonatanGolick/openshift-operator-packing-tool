#!/bin/bash
print_help_message(){
    echo "Usage:
 operator_pack.sh -v [Openshift Version] -o [Operator Version] -r [Registry FQDN] -u [RedHat Account User] -p [Password] -n [Package Name] -i [Operator Index Name] -b [Base Directory] 
 
    Default value for Base Directory if not given is /opt/{package-name+version}
    
    Valid index names are:
      - certified-operator-index
      - community-operator-index
      - redhat-marketplace-index
      - redhat-operator-index"
}
check_missing_params() {
  [ -z $version ] && echo "Missing Openshift version" && print_help_message && exit 1
  [ -z $operator ] && echo "Missing operator version" && print_help_message && exit 1
  [ -z $registry ] && echo "Missing registry fqdn" && print_help_message && exit 1
  [ -z $user ] && echo "Missing RedHat username" && print_help_message && exit 1
  [ -z $password ] && echo "Missing RedHat user password" && print_help_message && exit 1
  [ -z $name ] && echo  "Missing package name" && print_help_message && exit 1
  [ -z $index ] && echo  "Missing index name" && print_help_message && exit 1
}
is_registry_base_null() {
  registry_base_default="/opt/$name-$operator-$version"
  if [ -z "$registry_base" ]; then
      registry_base=$registry_base_default
  else
      registry_base=$registry_base/$name-$operator-$version
  fi
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

while getopts ":v:o:r:u:p:n:i:b" flag; do
  case $flag in
    v)version=$OPTARG >&2;;
    o)operator=$OPTARG >&2;;
    r)registry=$OPTARG >&2;;
    u)user=$OPTARG >&2;;
    p)password=$OPTARG >&2;;
    n)name=$OPTARG >&2;;
    i)index=$OPTARG >&2;;
    b)registry_base=$OPTARG >&2;;
    ?)print_help_message >&2;;
    *)echo "No argument was given!" >&2 ;;
  esac
done

is_registry_base_null

check_missing_params

is_index_valid 

work_dir=$(pwd)

. $work_dir/registry_creation.sh

. $work_dir/operator_packing_script.sh
