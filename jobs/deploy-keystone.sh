#!/bin/bash
SCRIPT_PATH="$(grealpath .)"
DEMO_CLUSTER=jobs
OSH_INFRA_COMMIT="010faee9d541a11f545126b5c15843dc5d12e9a7"
OSH_COMMIT="0f459ecfeee07daf056209430314406ee11f816f"
echo $SCRIPT_PATH
$SCRIPT_PATH/../switch-cluster.sh ${DEMO_CLUSTER}

mkdir -p $SCRIPT_PATH/resources/openstack-helm-infra
cd $SCRIPT_PATH/resources/openstack-helm-infra
(git show $OSH_INFRA_COMMIT -q > /dev/null && git checkout $OSH_INFRA_COMMIT > /dev/null ) || (
  git init
  git remote add origin https://github.com/openstack/openstack-helm-infra.git
  git fetch --depth 1 origin $OSH_INFRA_COMMIT
  git checkout FETCH_HEAD
  )
make helm-toolkit

mkdir -p $SCRIPT_PATH/resources/openstack-helm
cd $SCRIPT_PATH/resources/openstack-helm
(git show $OSH_COMMIT -q > /dev/null && git checkout $OSH_COMMIT > /dev/null ) || (
  git init
  git remote add origin https://github.com/openstack/openstack-helm.git
  git fetch --depth 1 origin $OSH_COMMIT
  git checkout FETCH_HEAD
  )
make keystone

read -t 60 -n 1 -s -r -p "Charts built, press any key to continue"
clear
TMP_DIR=$(mktemp -d)

set -x
helm ls --namespace openstack
read -t 60 -n 1 -s -r -p "Press any key to deploy keystone"
clear
tee ${TMP_DIR}/keystone.yaml << EOF
pod:
  replicas:
    api: 3
endpoints:
  identity:
    host_fqdn_override:
      public: keystone.via-${DEMO_CLUSTER}.denver
EOF
sleep 2s

helm upgrade --install keystone ${SCRIPT_PATH}/resources/openstack-helm/keystone-0.1.0.tgz \
  --namespace=openstack \
  --values=${TMP_DIR}/keystone.yaml

sleep 5s

helm ls --namespace openstack
