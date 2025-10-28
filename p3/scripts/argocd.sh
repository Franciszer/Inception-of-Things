#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

dots="..."
spaces="   "

printf "${GREEN}[ARGOCD]${NC} - Creating namespaces...\n"


sudo kubectl create namespace argocd && sudo kubectl create namespace dev
sudo kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


#
##                                  wait argocd pods running
#


printf "${GREEN}[ARGOCD]${NC} - Waiting for all pods to be running...\n"
while true; do
	running_pods=$(sudo kubectl get pods -n argocd --field-selector=status.phase=Running 2>/dev/null | grep -c "argocd")
	if [[ "$running_pods" -eq "7" ]]; then
		printf "\r${YELLOW}[ARGOCD]${NC} - Waiting...	(7/7)\n"
		printf "${GREEN}[ARGOCD]${NC} - All pods are running.\n"
		break
	else
		for ((i = 1; i <= ${#dots}; i++)); do
			printf "\r${YELLOW}[ARGOCD]${NC} - Waiting${dots:0:$i}${spaces:($i-1):3}	($running_pods/7)"
			sleep 1
		done
	fi
done

#
##                                  retrieving password
#

printf "${GREEN}[ARGOCD]${NC} - Retrieving credentials...\n"
echo "Password : $(sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)"
echo "argocd available at: http://localhost:80850/"
printf "${GREEN}[ARGOCD]${NC} - Installation and configuration completed.\n"

#
##                                  port-forwarding on 8085
#

sudo kubectl port-forward svc/argocd-server -n argocd 8085:443 > /dev/null 2>&1 &
echo "[INFO]  Access argocd at https://localhost:8085" 


#
##
#                                  configure argocd ingress

sudo kubectl apply -n argocd -f ./confs/argocd/ingress.yaml


#
##								   Forwarding wil application
#
MAX_WAIT=300  # seconds
SLEEP_INTERVAL=2
elapsed=0

printf "${GREEN}[PLAYGROUND]${NC} - Waiting for playground-service to be ready in namespace 'dev'...\n"
while true; do
	if ! sudo kubectl get svc playground-service -n dev >/dev/null 2>&1; then
		printf "\r${YELLOW}[PLAYGROUND]${NC} - playground-service not found yet... (elapsed: %ds)" "$elapsed"
	else
		addr_count=$(sudo kubectl get endpoints playground-service -n dev -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | wc -l)
		if [[ "$addr_count" -gt 0 ]]; then
			printf "\r${GREEN}[PLAYGROUND]${NC} - playground-service is ready (backends: %d).\n" "$addr_count"
			break
		else
			printf "\r${YELLOW}[PLAYGROUND]${NC} - playground-service has no ready backends yet... (elapsed: %ds)" "$elapsed"
		fi
	fi

	if (( elapsed >= MAX_WAIT )); then
		printf "\n${RED}[PLAYGROUND]${NC} - Timeout waiting for playground-service to be ready after %d seconds.\n" "$MAX_WAIT"
		exit 1
	fi

	sleep "$SLEEP_INTERVAL"
	((elapsed+=SLEEP_INTERVAL))
done

sudo kubectl port-forward svc/playground-service 8888:8888 -n dev