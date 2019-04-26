#!/bin/bash
SCRIPT_PATH="$(grealpath .)"
DEMO_CLUSTER=meta
echo $SCRIPT_PATH
$SCRIPT_PATH/../switch-cluster.sh ${DEMO_CLUSTER}

set -x
kubectl delete tenant tenant-1
