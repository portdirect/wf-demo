#!/bin/bash

SCRIPT_PATH="$(grealpath .)"
function get_demo_hosts () {
  HOSTS_SNIPPET=$(mktemp)
  echo "# WF-DEMO START" > $HOSTS_SNIPPET
  for DEMO_CLUSTER in jobs wf; do
    ${SCRIPT_PATH}/switch-cluster.sh ${DEMO_CLUSTER}
    INGRESS_IP=$(kubectl -n kube-system get svc ingress -o go-template='{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}' | head -1)
    echo "${INGRESS_IP} keystone.via-${DEMO_CLUSTER}.denver" >> $HOSTS_SNIPPET
  done
  for DEMO_CLUSTER in wf meta; do
    ${SCRIPT_PATH}/switch-cluster.sh ${DEMO_CLUSTER}
    INGRESS_IP=$(kubectl -n argo get svc argo-ui -o go-template='{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}' | head -1)
    echo "${INGRESS_IP} argo.via-${DEMO_CLUSTER}.denver" >> $HOSTS_SNIPPET
  done
  echo "# WF-DEMO END" >> $HOSTS_SNIPPET
  sudo sed -i.bak "/^# WF-DEMO START$/,/^# WF-DEMO END$/d" /etc/hosts
  cat ${HOSTS_SNIPPET} | sudo tee -a /etc/hosts

  tee /etc/openstack/clouds.yaml <<EOF
clouds:
  jobs:
    region_name: RegionOne
    identity_api_version: 3
    auth:
      username: 'admin'
      password: 'password'
      project_name: 'admin'
      project_domain_name: 'default'
      user_domain_name: 'default'
      auth_url: 'http://keystone.via-jobs.denver/v3'
  wf:
    region_name: RegionOne
    identity_api_version: 3
    auth:
      username: 'admin'
      password: 'password'
      project_name: 'admin'
      project_domain_name: 'default'
      user_domain_name: 'default'
      auth_url: 'http://keystone.via-wf.denver/v3'
EOF
}

get_demo_hosts
