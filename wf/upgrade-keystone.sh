#!/bin/bash
SCRIPT_PATH="$(grealpath .)"
DEMO_CLUSTER=wf
OSH_INFRA_COMMIT="2e688e8feb4bb1e58ff484209811da5c60705d94"
OSH_COMMIT="5e8793c4ed60802d0eee1bfeb8167dbb2a806f17"
echo $SCRIPT_PATH
$SCRIPT_PATH/../switch-cluster.sh ${DEMO_CLUSTER}

mkdir -p $SCRIPT_PATH/resources/openstack-helm-infra
cd $SCRIPT_PATH/resources/openstack-helm-infra
(git show $OSH_INFRA_COMMIT -q > /dev/null && git checkout $OSH_INFRA_COMMIT > /dev/null ) || (
  git init
  git remote add origin https://github.com/openstack/openstack-helm-infra.git
  git fetch --depth 1 origin refs/changes/87/632487/6
  git checkout FETCH_HEAD
  )
make helm-toolkit

mkdir -p $SCRIPT_PATH/resources/openstack-helm
cd $SCRIPT_PATH/resources/openstack-helm
(git show $OSH_COMMIT -q > /dev/null && git checkout $OSH_COMMIT > /dev/null ) || (
  git init
  git remote add origin https://github.com/openstack/openstack-helm.git
  git fetch --depth 1 origin refs/changes/46/636346/28
  git checkout FETCH_HEAD
  )
make keystone

read -t 60 -n 1 -s -r -p "Charts built, press any key to continue"
clear
TMP_DIR=$(mktemp -d)

set -x
helm ls --namespace openstack
read -t 60 -n 1 -s -r -p "Press any key to upgrade keystone"
clear
tee ${TMP_DIR}/keystone.yaml << EOF
images:
  tags:
    keystone_db_sync: docker.io/openstackhelm/keystone:pike
    keystone_fernet_setup: docker.io/openstackhelm/keystone:pike
    keystone_fernet_rotate: docker.io/openstackhelm/keystone:pike
    keystone_credential_setup: docker.io/openstackhelm/keystone:pike
    keystone_credential_rotate: docker.io/openstackhelm/keystone:pike
    keystone_credential_cleanup: docker.io/openstackhelm/heat:pike
    keystone_api: docker.io/openstackhelm/keystone:pike
    keystone_domain_manage: docker.io/openstackhelm/keystone:pike
pod:
  replicas:
    api: 3
endpoints:
  identity:
    host_fqdn_override:
      public: keystone.via-${DEMO_CLUSTER}.denver
EOF
read -t 60 -n 1 -s -r -p "Press any key to remove argo workflows, and start upgrade"
echo ""
kubectl -n openstack delete wf --all

helm upgrade --install keystone ${SCRIPT_PATH}/resources/openstack-helm/keystone-0.1.0.tgz \
  --namespace=openstack \
  --values=${TMP_DIR}/keystone.yaml
