#!/bin/bash

SCRIPT_PATH="$(grealpath .)"

function create_clusters () {
  set -x
  RESOURCE_GROUP="$(whoami)"
  for DEMO_CLUSTER in jobs wf meta; do
    az aks create \
        --resource-group ${RESOURCE_GROUP} \
        --name ${RESOURCE_GROUP}-cluster-${DEMO_CLUSTER} \
        --node-count 1 \
        --node-vm-size Standard_D16s_v3 \
        --node-osdisk-size 128 \
        --max-pods 110 \
        --kubernetes-version 1.12.6 \
        --location centralus \
        --generate-ssh-key \
        --no-wait
  done
  for DEMO_CLUSTER in jobs wf meta; do
    while ! [ "$(az aks show --name ${RESOURCE_GROUP}-cluster-${DEMO_CLUSTER} -g ${RESOURCE_GROUP} --output json | jq -r '.provisioningState')" == "Succeeded" ]; do
      az aks show --name ${RESOURCE_GROUP}-cluster-${DEMO_CLUSTER} -g ${RESOURCE_GROUP} --output table
      sleep 5s
    done
    kubectl config delete-context ${RESOURCE_GROUP}-cluster-${DEMO_CLUSTER} || true
    kubectl config delete-cluster ${RESOURCE_GROUP}-cluster-${DEMO_CLUSTER} || true
    cp ~/.kube/config ~/.kube/config.bak
    yq --yaml-output 'del( .users[] | select(.name == "clusterUser_${RESOURCE_GROUP}_${RESOURCE_GROUP}-cluster-${DEMO_CLUSTER}") )' ~/.kube/config.bak > ~/.kube/config
    rm -f ~/.kube/config.bak
    az aks get-credentials --overwrite-existing --resource-group ${RESOURCE_GROUP} --name ${RESOURCE_GROUP}-cluster-${DEMO_CLUSTER}
    ${SCRIPT_PATH}/switch-cluster.sh ${DEMO_CLUSTER}
    cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: azure-fixer
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: azure-fixer
  template:
    metadata:
      labels:
        name: azure-fixer
    spec:
      hostPID: true
      containers:
        - name: azure-fixer
          image: docker.io/busybox:latest
          securityContext:
            privileged: true
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - |
                  [ -f /tmp/aks-patched ] && exit 0 || exit 1
          command:
            - sh
            - -c
            - |
              nsenter -t1 -m -u -n -i -- apt-get update
              #NOTE(portdirect): we need to remove this to allow neutron & nova to work, as it gets upset when we try to chown files via names that do not map to uid's on the host
              nsenter -t1 -m -u -n -i -- apt-get purge -y unscd
              nsenter -t1 -m -u -n -i -- docker pull docker.io/openstackhelm/heat:ocata
              nsenter -t1 -m -u -n -i -- docker pull docker.io/openstackhelm/heat:pike
              nsenter -t1 -m -u -n -i -- docker pull docker.io/xrally/xrally-openstack:1.3.0
              nsenter -t1 -m -u -n -i -- docker pull docker.io/rabbitmq:3.7-management
              nsenter -t1 -m -u -n -i -- docker pull quay.io/stackanetes/kubernetes-entrypoint:v0.3.1
              nsenter -t1 -m -u -n -i -- docker pull ianhowell/kubernetes-entrypoint:latest
              nsenter -t1 -m -u -n -i -- docker pull docker.io/openstackhelm/keystone:ocata
              nsenter -t1 -m -u -n -i -- docker pull docker.io/openstackhelm/keystone:pike
              nsenter -t1 -m -u -n -i -- docker pull docker.io/library/mysql:5.5
              nsenter -t1 -m -u -n -i -- docker pull hemanth43/python_pyyaml_jinja2:3.5
              echo "done"
              touch /tmp/aks-patched
              tail -f /dev/null
EOF
    kubectl -n kube-system wait --timeout=900s --for=condition=Ready pod -l name=azure-fixer
    kubectl get storageclass "$(kubectl get storageclass | awk '/ \(default\)/ { print $1; exit }')" -o json | jq 'del(.metadata) | . + {metadata: {name: "general"}}' | kubectl apply -f -
    kubectl label "$(kubectl get nodes -o name | sort -V | head -1)" openstack-helm-node-class=primary
    kubectl label nodes --all openstack-control-plane=enabled
    kubectl label nodes --all openstack-compute-node=enabled
    kubectl label nodes --all openvswitch=enabled
    kubectl label nodes --all linuxbridge=enabled
    kubectl label nodes --all ceph-mon=enabled
    kubectl label nodes --all ceph-osd=enabled
    kubectl label nodes --all ceph-mds=enabled
    kubectl label nodes --all ceph-rgw=enabled
    kubectl label nodes --all ceph-mgr=enabled

  done
  set +x
}

create_clusters
