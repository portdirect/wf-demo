#!/bin/bash
SCRIPT_PATH="$(grealpath .)"
DEMO_CLUSTER=meta
echo $SCRIPT_PATH
$SCRIPT_PATH/../switch-cluster.sh ${DEMO_CLUSTER}


TMP_DIR=$(mktemp -d)
set -x
clear
tee ${TMP_DIR}/tenants.yaml << EOF
---
apiVersion: tenants.k8s.att.io/v1
kind: Tenant
metadata:
  name: tenant-1
  labels:
    tenant: tenant-1
spec:
  namespaces:
    - name: tenant-1-ns-1
      resourcequota:
        name: tenant-1-rq-1
        cpu: 15
        memory: 20Gi
        pods: 10
    - name: tenant-1-ns-2
      resourcequota:
        name: tenant-1-rq-2
        cpu: 10
        memory: 10Gi
        pods: 5
...
EOF

sleep 1s

kubectl apply -f ${TMP_DIR}/tenants.yaml
