#!/bin/bash
SCRIPT_PATH="$(grealpath .)"
DEMO_CLUSTER=meta
echo $SCRIPT_PATH
$SCRIPT_PATH/../switch-cluster.sh ${DEMO_CLUSTER}
META_OPERATOR_COMMIT=728d92a939f292ce77b5ed58ef4eb11222404a15

mkdir -p $SCRIPT_PATH/resources/tenant-operator
cd $SCRIPT_PATH/resources/tenant-operator
(git show $META_OPERATOR_COMMIT -q > /dev/null && git checkout $META_OPERATOR_COMMIT > /dev/null ) || (
  git init
  git remote add origin https://github.com/hemanthnakkina/tenant-operator.git
  git fetch --depth 1 origin $META_OPERATOR_COMMIT
  git checkout FETCH_HEAD
  )
clear

set -x
kubectl -n argo get serviceaccount tenant-admin || \
  kubectl -n argo create serviceaccount tenant-admin

kubectl get clusterrolebinding tenant-admin || \
  kubectl create clusterrolebinding tenant-admin --clusterrole=cluster-admin --serviceaccount=argo:tenant-admin

read -t 60 -n 1 -s -r -p "Created required service account and bound that to argo"
clear

cd $SCRIPT_PATH/resources/tenant-operator/metacontroller_poc/tenant

cat sync.py
kubectl get configmap tenant-controller -n metacontroller || \
  kubectl create configmap tenant-controller -n metacontroller --from-file=sync.py
read -t 60 -n 1 -s -r -p "Created metacontroller faas configmap"
clear

cat template.j2
kubectl get configmap tenant-argo-template -n metacontroller || \
  kubectl create configmap tenant-argo-template -n metacontroller --from-file=template.j2
read -t 60 -n 1 -s -r -p "Created metaoperator argo template"
clear

cat crd.yaml
kubectl apply -f crd.yaml
set +x
kubectl api-resources | head -1
kubectl api-resources | grep tenants
set -x
kubectl get tenants
read -t 60 -n 1 -s -r -p "Created tenant CRD"
clear

cat controller.yaml
kubectl apply -f controller.yaml
read -t 60 -n 1 -s -r -p "Created metacontroller metaoperator composite controller spec"
clear

cat webhook.yaml
kubectl apply -f webhook.yaml
read -t 60 -n 1 -s -r -p "Created metacontroller metaoperator faas executor deployment"
clear
