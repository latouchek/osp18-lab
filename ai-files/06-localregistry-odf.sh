##Storage ODF##

cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    imageregistry.openshift.io: "true"
    manager: cluster-image-registry-operator
  name: image-registry-storage
  namespace: openshift-image-registry
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 60Gi
  volumeMode: Filesystem
  storageClassName: ocs-storagecluster-cephfs
EOF






oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"storage": {"pvc": {"claim": "image-registry-storage"}}}}' --type=merge
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

oc patch storageclass ocs-storagecluster-ceph-rbd -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'


##Storage LVM##

cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    imageregistry.openshift.io: "true"
    manager: cluster-image-registry-operator
  name: image-registry-storage
  namespace: openshift-image-registry
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 40Gi
  volumeMode: Filesystem
  storageClassName: lvms-vg1
EOF
oc patch storageclass lvms-vg1 -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"storage": {"pvc": {"claim": "image-registry-storage"}}}}' --type=merge
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge -p '{"spec":{"rolloutStrategy":"Recreate"}}'
