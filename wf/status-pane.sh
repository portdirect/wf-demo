#!/bin/bash
SCRIPT_PATH="$(grealpath .)"
DEMO_CLUSTER=wf
echo $SCRIPT_PATH
$SCRIPT_PATH/../switch-cluster.sh ${DEMO_CLUSTER}

until $(argo -n openstack list | grep -q "wf-keystone-api"); do
  clear
  kubectl get --all-namespaces pods
  sleep 2s
done

argo -n openstack watch wf-keystone-api
sleep 10s
argo -n openstack watch wf-keystone-bootstrap
sleep 10s
set -x
argo -n openstack get wf-keystone-api
argo -n openstack get wf-keystone-bootstrap
set +x
