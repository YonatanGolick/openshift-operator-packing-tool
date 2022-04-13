# rhacm-operator-export

**1.1 Registry Creation**
**prerequisites - **

1. Use RHEL 8 Registered & subscribed system.
2. Check that you don't have a registry running on your machine.
3. Check that you don’t have a directory /opt/registry, if so delete it.
4. Delete any existing .crt in /etc/pki/ca-trust/source/anchors/
5. Work as root user !
6. Podman version 1.9.3+
7. opm version 1.12.3+
8. Skopeo version 0.1.40


**1.2 Create operator catalog & tar the directory**
We will create an index image. An index image based on the Operator Bundle Format, it is a containerized snapshot of an Operator catalog. We can prune an index of all but a specified list of packages, creating a copy of the source index containing only the Operators we need.


