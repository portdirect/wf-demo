#!/bin/bash

SCRIPT_PATH="$(grealpath .)"

function provision_keystone_support () {
  set -x
  TMP_DIR=$(mktemp -d)
  cd "${TMP_DIR}"
  git init
  git remote add origin https://github.com/openstack/openstack-helm-infra.git
  git fetch --depth 1 origin 010faee9d541a11f545126b5c15843dc5d12e9a7
  git checkout FETCH_HEAD
  make helm-toolkit
  make ingress
  make mariadb
  make rabbitmq
  make memcached
  tee ${TMP_DIR}/ingress-kube-system.yaml << 'EOF'
deployment:
  mode: cluster
  type: DaemonSet
network:
  host_namespace: true
EOF
  helm upgrade --install ingress-kube-system ${TMP_DIR}/ingress-0.1.0.tgz \
    --namespace=kube-system \
    --values=${TMP_DIR}/ingress-kube-system.yaml
  helm upgrade --install ingress-openstack ${TMP_DIR}/ingress-0.1.0.tgz \
    --namespace=openstack
  kubectl -n kube-system wait --timeout=900s --for=condition=Ready pod -l application=ingress,component=server
  kubectl -n kube-system patch svc ingress --patch '{"spec":{"type":"LoadBalancer"}}'
  kubectl -n kube-system get svc ingress
  while [ -z "$(kubectl -n kube-system get svc ingress -o go-template='{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}')" ]; do
    sleep 5s
    kubectl -n kube-system get svc ingress --no-headers
  done
  helm upgrade --install mariadb ${TMP_DIR}/mariadb-0.1.0.tgz \
      --namespace=openstack \
      --set pod.replicas.server=1
  helm upgrade --install rabbitmq ${TMP_DIR}/rabbitmq-0.1.0.tgz \
      --namespace=openstack \
      --set pod.replicas.server=1
  helm upgrade --install memcached ${TMP_DIR}/memcached-0.1.0.tgz \
      --namespace=openstack
  kubectl -n openstack wait --timeout=900s --for=condition=Ready pod -l application=mariadb
  kubectl -n openstack wait --timeout=900s --for=condition=Ready pod -l application=rabbitmq,component=server
  kubectl -n openstack wait --timeout=900s --for=condition=Ready pod -l application=memcached
  set +x
}

function provision_support () {
  set -x
  for DEMO_CLUSTER in meta jobs wf; do
    ${SCRIPT_PATH}/switch-cluster.sh ${DEMO_CLUSTER}
    if ! [ "$DEMO_CLUSTER" == "jobs" ]; then
      INFRA_TMP_DIR=$(mktemp -d)
      cd "${INFRA_TMP_DIR}"
      git init
      git remote add origin https://review.opendev.org/openstack/openstack-helm-infra.git
      git fetch --depth 1 origin refs/changes/87/632487/6
      git checkout FETCH_HEAD
      make helm-toolkit
      make argo
      helm upgrade --install argo ${INFRA_TMP_DIR}/argo-0.1.0.tgz \
          --namespace=argo
      kubectl -n argo wait --timeout=900s --for=condition=Ready pod -l app=workflow-controller
      kubectl -n argo wait --timeout=900s --for=condition=Ready pod -l app=argo-ui
      kubectl patch -n argo svc argo-ui --patch '{"spec":{"type":"LoadBalancer"}}'
      kubectl -n argo get svc argo-ui
      while [ -z "$(kubectl -n argo get svc argo-ui -o go-template='{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}')" ]; do
        sleep 5s
        kubectl -n argo get svc argo-ui --no-headers
      done
    fi
    if [ "$DEMO_CLUSTER" == "meta" ]; then
      kubectl create ns metacontroller
      kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/metacontroller/master/manifests/metacontroller-rbac.yaml
      kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/metacontroller/master/manifests/metacontroller.yaml
      kubectl -n metacontroller wait --timeout=900s --for=condition=Ready pod metacontroller-0
    fi
    provision_keystone_support
  done
  set +x
}

provision_support
