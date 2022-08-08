# openshift-operator-packing-tool

**Prerequisites:**

1. Use RHEL 8 Registered & subscribed system.
2. Validate that you don't have a running registry continer on your machine.
5. Work as root user !
6. Podman version 1.9.3+
7. opm version 1.12.3+
8. Skopeo version 0.1.40+


**Usage Examples:**


If you dont know the name of the operator you can start by using the hack script

Usage:
```
get_pack_name.sh -v [Openshift Version] -u [RedHat Account User] -p [Password] -i [Operator Index Name]
```
Example - To view all availible operators under a specific index:
```
./get_pack_name.sh -v v4.6 -u Username -p Password -i redhat-operator-index
```


Usage:
```
operator_pack.sh -v [Openshift Version] -o [Operator Version] -r [Registry FQDN] -u [RedHat Account User] -p [Password] -n [Package Name] -i [Operator Index Name] -b [Base Directory]
```
Example:
```
./operator_pack.sh -v v4.6 -o v7.4 -r registry -u Username -p Password -n rhsso-operator -i redhat-operator-index
```

