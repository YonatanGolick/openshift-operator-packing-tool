#!/bin/bash
print_help_message(){
    echo "Usage:
 operator_pack.sh -v [Openshift Version] -o [Operator Version] -r [Registry FQDN] -u [RedHat Account User] -p [Password] -n [Package Name]"
}
check_missing_params(){
  [ -z $version ] && echo "Missing Openshift version" && print_help_message && exit 1
  [ -z $operator ] && echo "Missing operator version" && print_help_message && exit 1
  [ -z $registry ] && echo "Missing registry fqdn" && print_help_message && exit 1
  [ -z $user ] && echo "Missing RedHat username" && print_help_message && exit 1
  [ -z $password ] && echo "Missing RedHat user password" && print_help_message && exit 1
  [ -z $name ] && echo  "Missing package name" && print_help_message && exit 1
}

while getopts ":v:o:r:u:p:n:" flag; do
  case $flag in
    v)version=$OPTARG >&2;;
    o)operator=$OPTARG >&2;;
    r)registry=$OPTARG >&2;;
    u)user=$OPTARG >&2;;
    p)password=$OPTARG >&2;;
    n)name=$OPTARG >&2;;
    ?)print_help_message >&2;;
    *)echo "No argument was given!" >&2 ;;
  esac
done
check_missing_params
work_dir=$(pwd)
echo "Choose your base directory: "
read registry_base
registry_base_default="/opt/$name-$version"
if [ -z "$registry_base" ]; then
    registry_base=$registry_base_default
else
    registry_base=$registry_base/$name-$version
fi
echo $registry_base
. $work_dir/registry_creation_script.sh

. $work_dir/operator_packing_script.sh
