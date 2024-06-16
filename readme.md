

# OSP 18 LAB

This lab is designed to test OSP18 in a virtualized environment using KVM, closely resembling real-world scenarios.

![ASCII Image](/Pix/ascii.png)
### Prerequisites
- OCP 4.12+ and ODF installed
- The following operators installed and instantiated:
    - Nmstate, MetalLB, MCE
- Cert-manager operator installed
- Quay or equivalent private registry installed

### Installing a Private Registry with Mirror-Registry

1. **Download the mirror-registry binary and install packages**:

    First, set variables for easy customization:

    ```bash
    BASTIONFQDN=$(hostname -f) # Your bastion fully qualified domain name
    MIRROR_REGISTRY_VERSION="latest" # Change as required
    INSTALL_DIR="/opt/mirror-registry"
    QUAYROOT="/opt/OSP18"
    ```

    Download and install the mirror-registry:

    ```bash
    wget "https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/mirror-registry/${MIRROR_REGISTRY_VERSION}/mirror-registry.tar.gz" -O "${INSTALL_DIR}/mirror-registry.tar.gz"
    cd "${INSTALL_DIR}"
    tar zxvf mirror-registry.tar.gz
    ./mirror-registry install --initPassword=12345678 --targetHostname $BASTIONFQDN --quayRoot $QUAYROOT
    ```

2. **Add Quay rootCA certificate to the trust store**:

    For RPM-based systems:

    ```bash
    cp $QUAYROOT/quay-rootCA/rootCA.pem /etc/pki/ca-trust/source/anchors/
    update-ca-trust extract
    ```

    For DEB-based systems:

    ```bash
    cp ~/quay-install/quay-rootCA/rootCA.pem /usr/local/share/ca-certificates/rootCA.crt
    sudo update-ca-certificates
    ```

3. **Add Quay CA to the OCP cluster**:

    ```bash
    oc create configmap quay-ca --from-file=${BASTIONFQDN}..8443=./quay-enterprise.pem -n openshift-config
    oc patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"quay-ca"}}}' --type=merge
    ```

4. **Test authentication against the private Quay repository**:

    ```bash
    podman login -u init -p 12345678 ${BASTIONFQDN}:8443
    # Expected output: "Login Succeeded!"
    ```

### Installing the OpenStack Operator

1. **Create the `openstack-operators` project for the RHOSP operators and the `openstack` project for the deployed RHOSP environment**:

    ```bash
    oc new-project openstack-operators && oc new-project openstack
    ```

2. **Ensure `registry.redhat.io/rhosp-dev-preview` is trusted**:

    ```bash
    curl https://www.redhat.com/security/data/f21541eb.txt -o /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta
    podman image trust set -f /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta registry.redhat.io/rhosp-dev-preview
    cat /etc/containers/policy.json
    ```

3. **Install `opm`**:

    ```bash
    wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/opm-linux.tar.gz
    tar zxvf opm-linux.tar.gz && mv opm /usr/local/bin && rm -f opm-linux.tar.gz
    ```

4. **Use the `opm` tool to create an index image**:

    **Warning**: The command below needs to be run multiple times to complete.

    ```bash
    podman login -u <your-username> -p <your-password> registry.redhat.io
    opm index add -u podman --pull-tool podman --tag ${BASTIONFQDN}:8443/admin/rhoso-podified-beta/openstack-operator-index:1.0.0 -b "registry.redhat.io/rhoso-podified-beta/barbican-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/cinder-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/designate-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/glance-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/heat-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/horizon-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/infra-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/ironic-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/keystone-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/manila-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/mariadb-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/neutron-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/nova-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/octavia-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/openstack-baremetal-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/openstack-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/ovn-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/placement-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/rabbitmq-cluster-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/swift-operator-bundle:1.0.0,registry.redhat.io/rhoso-podified-beta/telemetry-operator-bundle:1.0.0,registry.redhat.io/rhoso-edpm-beta/dataplane-operator-bundle:1.0.0,registry.redhat.io/rhoso-edpm-beta/openstack-ansibleee-operator-bundle:1.0.0" --mode semver
    ```

5. **Push catalog to private registry**:

    ```bash
    podman push ${BASTIONFQDN}:8443/rhosp-dev-preview/openstack-operator-index:0.1.3
    ```

    ```bash
    podman push ${BASTIONFQDN}:8443/admin/rhoso-podified-beta/openstack-operator-index:1.0.0
    ```

6. **Create a secret in the `openshift-marketplace` namespace containing the authentication credentials for the private registry**:

    ```bash
    oc create secret generic private-registry \
    -n openstack-operators \
    --from-file=.dockerconfigjson=privaterepo.json \
    --type=kubernetes.io/dockerconfigjson
    ```

7. **Provide private registry access to all namespaces in the cluster**:

    ```bash
    oc extract secret/pull-secret -n openshift-config --confirm
    cat .dockerconfigjson | \
    jq --compact-output '.auths["osp-hetzner.lab.local:8443/admin/rhoso-podified-beta/"] |= . + {"auth":"aW5pdDoxMjM0NTY3OA=="}' > new_dockerconfigjson
    oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=new_dockerconfigjson
    ```

### Install OpenStack Operator

The OSP 18 control plane is now installed using an operator. All services that previously ran on OSP control nodes are now running as services directly on OCP. The IP networks used, storage types, and services to be activated during installation are specified in the openstack-operator.yaml file.

```bash
oc apply -f openstack-operator.yaml
```

Check if the installation went well:

```bash
oc get operators openstack-operator.openstack-operators
oc get pods -n openstack-operators
```

You should see the following once the operator has finished installing:

```bash
NAME                                                              READY   STATUS      RESTARTS   AGE
09e2a9770492f5560e930698e53344b969fd76f4d8609802cc9c0c559c5mk4z   0/1     Completed   0          5m51s
3b8dfb5bf50fefcc388181799c2fd028251ba79cd90c97c1583bab37c7h4h49   0/1     Completed   0          5m55s
3c4ab7aa62e61325641ee6d60937ea2c99048d6deb6938499462da6fe1p4b7b   0/1     Completed   0          5m56s
3cbdb8ca3939f943d34da1b263f7ef5208

bb85a937863d5c6ac1e45e03scplf   0/1     Completed   0          5m59s
41f18f2e6bc415e3a3a7568685297f44472d10d766cff64a980493b9c7wws97   0/1     Completed   0          5m53s
45011157978581688a65e175bdba6bbc05540f3cb5e9d992726ebbae29snbmj   0/1     Completed   0          5m57s
45423e4e35c8ea1da850f4ad33f8d2af35cbc0d37907ef0b6b2d49ec2fq5b8t   0/1     Completed   0          5m54s
461e5add93155be7ff6df19679aedd44d1385f45d925ad6b71462ddf1477nr5   0/1     Completed   0          5m53s
4ada867547b643ed0171378947c4bb0dec6c250bedb86988c33d5403bcg8swm   0/1     Completed   0          5m52s
66b774e6f6460f10faf4d3e77a008e1f70f5851a591ca802545f9ffaeap7ztj   0/1     Completed   0          6m
7b12533d260140c3593e6968a5e815af00f6bee8b42889bcdf5c8be9acgmdfj   0/1     Completed   0          5m52s
801d3d6a9a03e95f733edaf9ec35f1b64646127c9839bcc8d21cd10050dd5bj   0/1     Completed   0          5m53s
9b90dc450363f9762be7cd08f24f39a4541737d722d652f748a33e5e5225ds4   0/1     Completed   0          5m57s
a20be8859108fb5abc28fc841b4728cf7dd4813d27acab8eb5508086c12xbzl   0/1     Completed   0          5m51s
a481ba6a5cf9018862d26fc26cf503bca6ad737f1b4d876a1aef8dc4dcbf664   0/1     Completed   0          5m59s
b0183caec24c710e3ce2fd351feb5576a8186bed9019781b404a56063avzvr5   0/1     Completed   0          6m1s
b60823faa1649a8e352d2b1e9385a79660c4d62c71994d69a27ecaaa21lssb6   0/1     Completed   0          5m56s
b6b1184c6afff069c64ec2e11fc6c6a9e0506892f2c1198f36a7009cd2nbjwm   0/1     Completed   0          5m58s
barbican-operator-controller-manager-648d4bf58d-b2bps             2/2     Running     0          4m23s
c07dee05752d076d4f11a16f2169cfcde3ad20de6018aa493ac1b4c0c1z8phd   0/1     Completed   0          5m54s
c1db46e7f96ab1ef8aa6b571f2635d0cfd4ed32163af9ea124d7f1fd955n4mn   0/1     Completed   0          5m54s
c9665a037b66d6e7d49d4307cbb71df691d28395482c13502323c3153984n5c   0/1     Completed   0          6m
cinder-operator-controller-manager-f6d6c869b-qt7qd                2/2     Running     0          5m25s
dataplane-operator-controller-manager-59547dd7c9-bsgsg            2/2     Running     0          4m57s
designate-operator-controller-manager-7cdcbb89df-phc7m            2/2     Running     0          4m13s
f750c18b4b930ff10eee3d5db9c104f2054c0e6a1c3977b38fe3430a6aw7lmh   0/1     Completed   0          5m51s
glance-operator-controller-manager-69445bb7db-xrm6z               2/2     Running     0          4m7s
heat-operator-controller-manager-755968c858-lvw9x                 2/2     Running     0          4m31s
horizon-operator-controller-manager-5c4c9d5c85-rrsjz              2/2     Running     0          3m33s
infra-operator-controller-manager-57bfc7b94-574l4                 2/2     Running     0          4m25s
ironic-operator-controller-manager-bdd96c4f9-c97lh                2/2     Running     0          3m57s
keystone-operator-controller-manager-544ccb8899-tmskg             2/2     Running     0          5m9s
manila-operator-controller-manager-7d7f5bb74c-5lx58               2/2     Running     0          3m43s
mariadb-operator-controller-manager-6cd57dc95d-659t5              2/2     Running     0          4m44s
neutron-operator-controller-manager-564d4b64d6-6srxg              2/2     Running     0          3m12s
nova-operator-controller-manager-5b4dddf4c4-9v6k9                 2/2     Running     0          3m14s
octavia-operator-controller-manager-7d7f8b95d6-pbbgb              2/2     Running     0          3m47s
openstack-ansibleee-operator-controller-manager-864bc644cbbxhql   2/2     Running     0          5m19s
openstack-baremetal-operator-controller-manager-7cb7dd55-4n7tf    2/2     Running     0          3m46s
openstack-operator-controller-manager-7898b97679-4r4x5            2/2     Running     0          4m57s
openstack-operator-index-87z84                                    1/1     Running     0          6m19s
ovn-operator-controller-manager-5f6b5fb789-6lblx                  2/2     Running     0          3m30s
placement-operator-controller-manager-c6b6b6778-lnnjd             2/2     Running     0          3m31s
rabbitmq-cluster-operator-549d8b79d6-7flbf                        1/1     Running     0          4m32s
swift-operator-controller-manager-7948544565-7nttr                2/2     Running     0          3m17s
telemetry-operator-controller-manager-6c449fd68c-lr9ss            2/2     Running     0          5m15s
```

### Prepare Network

Apply the provided manifests to prepare OSP18 deployment network configuration.

1. Apply the manifests:

    ```bash
    oc apply -f openstack-service-secret.yaml
    oc apply -f openstack-nad.yaml
    oc apply -f openstack-ipaddresspools.yaml
    oc apply -f openstack-l2advertisement.yaml
    oc patch network.operator cluster -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"gatewayConfig":{"ipForwarding": "Global"}}}}}' --type=merge
    oc create -f openstacknetconfig.yaml
    ```

### Create the Control Plane

> ⚠️ **Warning:**

Create an `OpenStackVersion` object to specify where to pull images from. If not, it will be created automatically and images will be pulled from `registry.redhat.io`.

```bash
oc create -f openstackversion-controlplane.yaml -n openstack
```

Deploy the control plane with the previously chosen network parameters:

```bash
oc create -f openstack-controlplane.yaml -n openstack
```

It is possible to enable services after deploying the control

 plane:

**Enable extra services**

```bash
oc patch openstackcontrolplanes/openstack-galera-network-isolation -p='[{"op": "replace", "path": "/spec/horizon/enabled", "value": true}]' --type json
oc patch openstackcontrolplanes/openstack-galera-network-isolation -p='[{"op": "replace", "path": "/spec/octavia/enabled", "value": true}]' --type json
```

**Check Endpoints URL**

The OSP operator deploys an `openstack-client` pod allowing OpenStack commands to be run.

```bash
sh-5.1$ openstack endpoint list -c 'Service Name' -c Interface -c URL
+--------------+-----------+--------------------------------------------------------------------------+
| Service Name | Interface | URL                                                                      |
+--------------+-----------+--------------------------------------------------------------------------+
| nova         | internal  | http://nova-internal.openstack.svc:8774/v2.1                             |
| swift        | public    | https://swift-public-openstack.apps.ocpd.lab.local/v1/AUTH_%(tenant_id)s |
| neutron      | internal  | http://neutron-internal.openstack.svc:9696                               |
| barbican     | internal  | http://barbican-internal.openstack.svc:9311                              |
| keystone     | internal  | http://keystone-internal.openstack.svc:5000                              |
| placement    | public    | https://placement-public-openstack.apps.ocpd.lab.local                   |
| neutron      | public    | https://neutron-public-openstack.apps.ocpd.lab.local                     |
| glance       | internal  | http://glance-default-internal.openstack.svc:9292                        |
| keystone     | public    | https://keystone-public-openstack.apps.ocpd.lab.local                    |
| barbican     | public    | https://barbican-public-openstack.apps.ocpd.lab.local                    |
| cinderv3     | internal  | http://cinder-internal.openstack.svc:8776/v3                             |
| glance       | public    | https://glance-default-public-openstack.apps.ocpd.lab.local              |
| nova         | public    | https://nova-public-openstack.apps.ocpd.lab.local/v2.1                   |
| swift        | internal  | http://swift-internal.openstack.svc:8080/v1/AUTH_%(tenant_id)s           |
| cinderv3     | public    | https://cinder-public-openstack.apps.ocpd.lab.local/v3                   |
| placement    | internal  | http://placement-internal.openstack.svc:8778                             |
+--------------+-----------+--------------------------------------------------------------------------+
```

The deployment might take some time. To ensure it is completed, you can run the following command:

```bash
sh-5.1$ oc get openstackcontrolplanes.core.openstack.org
NAME                                 STATUS   MESSAGE
openstack-galera-network-isolation   True     Setup complete
```

You can now prepare for the deployment of the data plane.

### DataPlane Deployment Preparation

The OSP18 operator allows provisioning and configuration of compute nodes. The workflow is as follows:

Create a pool of baremetal nodes -> Install RHEL9 on the nodes -> Apply an Ansible playbook to configure the nodes.

The playbook is launched from an Ansible runner pod, so it is necessary to create an SSH key pair for this operation.

```bash
KEY_FILE_NAME=osp18
ssh-keygen -f $KEY_FILE_NAME -N "" -t rsa -b 4096
SECRET_NAME=osp-installation-secret
oc create secret generic $SECRET_NAME \
  --save-config \
  --dry-run=client \
  --from-file=authorized_keys=$KEY_FILE_NAME.pub \
  --from-file=ssh-privatekey=$KEY_FILE_NAME \
  --from-file=ssh-publickey=$KEY_FILE_NAME.pub \
  -n openstack \
  -o yaml | oc apply -f-
```



### Adding BareMetal Nodes
To create a node pool, declare them in the `05-baremetalhost.yaml` manifest following the metal3.io/v1alpha1 schema. 


> ⚠️ **Warning:** Patch provisionning ressource so baremetal nodes can be provisonned accross all namespaces
```bash
oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true }}'
```

```bash
oc apply -f 05-baremetalhost.yaml
```
This command will start the inspection/introspection process of the nodes, which can be observed using the following command:

```bash
oc get bmh -A
NAMESPACE               NAME                          STATE        CONSUMER              ONLINE   ERROR   AGE
openshift-machine-api   osp-compute-0                 inspecting                         false            12s
openshift-machine-api   osp-compute-1                 inspecting                         false            12s
openshift-machine-api   osp-compute-2                 inspecting                         false            12s
```

Once introspection has taken place, you should see:

```bash
oc get bmh -A
NAMESPACE               NAME                          STATE       CONSUMER              ONLINE   ERROR   AGE
openshift-machine-api   ocp4-worker0.ocpd.lab.local   unmanaged   ocpd-9srlg-master-0   true             17h
openshift-machine-api   ocp4-worker1.ocpd.lab.local   unmanaged   ocpd-9srlg-master-1   true             17h
openshift-machine-api   ocp4-worker2.ocpd.lab.local   unmanaged   ocpd-9srlg-master-2   true             17h
openshift-machine-api   osp-compute-0                 available                         false            3h3m
openshift-machine-api   osp-compute-1                 available                         false            3h3m
openshift-machine-api   osp-compute-2                 available                         false            3h3m
```
The nodes are annotated as 'available', meaning they can be used to deploy the data plane.
### Dataplane

Ensure to replace `registry.redhat.io/rhoso-edpm-beta/openstack-ansible-ee-rhel9:1.0.0` with `registry.redhat.io/rhoso-edpm-beta/ee-openstack-ansible-ee-rhel9:1.0.0`.

The first step of deploying the data plane is to create a dataplanenodeset object that describes the target nodes, their network configuration, and the Ansible variables to be used.

```bash
oc create -f openstack-dataplanenodeset-beta.yaml
openstackdataplanenodeset.dataplane.openstack.org/osp-mcn-lab created
```
Tip: After creating dataplanenodeset, you should see a pod named osp-mcn-lab-provisionserver-openstackprovisionserver-xxx. It can be useful to observe the logs of this pod to ensure everything is proceeding as expected.

```bash
oc get pod
NAME                                                              READY   STATUS      RESTARTS   AGE
osp-mcn-lab-provisionserver-openstackprovisionserver-58f4fpxbzv   1/1     Running     0          10s
```
After creating this pod, the nodes should start and be provisioned.



```bash
oc get openstackdataplanenodesets.dataplane.openstack.org
NAME          STATUS   MESSAGE
osp-mcn-lab   False    NodeSetBaremetalProvisionReady not yet ready
```
💡 **Tip:** Closely monitor metal3 pod for debugging 

```bash
oc logs -f metal3-xyxyxyxyx-xxxx -n openshift-machine-api -c metal3-ironic-inspector
```

```bash
oc get openstackdataplanenodesets.dataplane.openstack.org
NAME          STATUS   MESSAGE
osp-mcn-lab   False    Deployment not started
```
You can see below that their status has changed and they are ready to be configured according to the parameters set in the `openstack-dataplanenodeset-beta.yaml` file.```bash
oc get bmh -n openshift-machine-api
NAMESPACE               NAME                          STATE         CONSUMER              ONLINE   ERROR   AGE
openshift-machine-api   osp-compute-0                 provisioned   osp-mcn-lab           true             3h37m
openshift-machine-api   osp-compute-1                 provisioned   osp-mcn-lab           true             3h37m
openshift-machine-api   osp-compute-2                 available                           false            3h37m
```

Now, you need to initiate the deployment by running the following command:

```bash
oc create -f openstack-deploy.yaml
```
To be continued...

