#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
CLUSTER_NAME="ychibani"


##                              K3D

printf "${GREEN}[K3D]${NC} - Install and create cluster...\n"
if sudo k3d cluster list | grep -q "$CLUSTER_NAME"; then
	printf "${RED}[K3D]${NC} - A cluster named $CLUSTER_NAME already exists.\n"
	exit 1
else
	if ! sudo k3d cluster create $CLUSTER_NAME --port 80:80 --servers 1 --agents 3; then
        echo "${RED}[K3D]${NC} - Cluster creation failed! Do you have k3d installed and is the Docker service running?${NC}"
        exit 1
    fi
fi

export KUBECONFIG="$(sudo k3d kubeconfig write "$CLUSTER_NAME")"