#!/bin/bash
SCRIPT_PATH="$(grealpath .)"
DEMO_CLUSTER=wf
echo $SCRIPT_PATH
$SCRIPT_PATH/../switch-cluster.sh ${DEMO_CLUSTER}

function get_ks_token () {
  export OS_CLOUD=$1
  watch gtimeout --kill-after=10 5 'openstack endpoint list --interface public; openstack token issue'
}


get_ks_token ${DEMO_CLUSTER}
