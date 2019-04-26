#!/bin/bash

function switch_cluster () {
  set -x
  RESOURCE_GROUP="$(whoami)"
  DEMO_CLUSTER="$1"
  kubectl config use-context ${RESOURCE_GROUP}-cluster-${DEMO_CLUSTER}
  launchctl unload /Users/pb269f/Library/LaunchAgents/local.portdirect.tiller.plist
  launchctl load /Users/pb269f/Library/LaunchAgents/local.portdirect.tiller.plist
  set +x
}


switch_cluster $1
export PS1="$(kubectl config current-context)$ "
