#!/usr/bin/env bash
# p2/test.sh — Automated eval checks for Part 2: K3s and three simple applications
# Run from p2/ after "vagrant up" has completed.
set -uo pipefail

LOGIN='frthierr'
VM_NAME="${LOGIN}S"
VM_IP='192.168.56.110'

PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "  [OK]  $1"; }
fail() { FAIL=$((FAIL+1)); echo "  [KO]  $1"; }

section() { echo; echo "=== $1 ==="; }

# Helper: run a command inside the guest via vagrant ssh
guest() { vagrant ssh "$VM_NAME" -c "$1" 2>/dev/null | tr -d '\r'; }

# ===================== Part 2 – Configuration =====================
section "Configuration checks"

# 1. Vagrantfile exists
[ -f Vagrantfile ] \
  && ok "Vagrantfile exists" \
  || fail "Vagrantfile not found"

# 2. Only 1 VM defined
VM_COUNT=$(grep -cE '\.vm\.define' Vagrantfile)
[ "$VM_COUNT" -eq 1 ] \
  && ok "1 VM defined in Vagrantfile" \
  || fail "Expected 1 VM, found $VM_COUNT"

# 3. Name contains login + S (literal or Ruby interpolation)
(grep -qF "${LOGIN}S" Vagrantfile || grep -qF '#{LOGIN}S' Vagrantfile) \
  && ok "VM name contains ${LOGIN}S" \
  || fail "VM name missing"

# 4. IP present
grep -q "$VM_IP" Vagrantfile \
  && ok "IP $VM_IP in Vagrantfile" \
  || fail "IP $VM_IP missing"

# 5. Latest stable distro
grep -qE "ubuntu/jammy64|ubuntu/noble64|debian/bookworm64" Vagrantfile \
  && ok "Latest stable distro used" \
  || fail "Distro not recognized as latest stable"

# ===================== Part 2 – Usage =====================
section "Vagrant status"

STATUS=$(vagrant status --machine-readable 2>/dev/null)
echo "$STATUS" | grep -q "${VM_NAME},state,running" \
  && ok "$VM_NAME is running" \
  || fail "$VM_NAME is not running"

section "SSH & hostname"

HOSTNAME=$(guest 'hostname')
[ "$HOSTNAME" = "$VM_NAME" ] \
  && ok "Hostname = $VM_NAME" \
  || fail "Hostname is '$HOSTNAME', expected '$VM_NAME'"

section "Network interface"

IP_CHECK=$(guest "ip -4 -o addr show | grep '$VM_IP'")
[ -n "$IP_CHECK" ] \
  && ok "VM has IP $VM_IP on an interface" \
  || fail "VM missing IP $VM_IP"

section "K3s service"

guest 'systemctl is-active k3s' | grep -q 'active' \
  && ok "k3s service active" \
  || fail "k3s service not active"

section "Cluster nodes (kubectl get nodes -o wide)"

NODES=$(guest 'sudo kubectl get nodes -o wide')
echo "$NODES"
echo

echo "$NODES" | grep -q ' Ready ' \
  && ok "Node is Ready" \
  || fail "Node not Ready"

echo "$NODES" | grep -q "$VM_IP" \
  && ok "Node INTERNAL-IP is $VM_IP" \
  || fail "Node INTERNAL-IP mismatch"

section "Applications (kubectl get all)"

ALL=$(guest 'sudo kubectl get all')
echo "$ALL"
echo

# Deployments exist
echo "$ALL" | grep -q 'deployment.apps/app1' \
  && ok "app1 deployment exists" \
  || fail "app1 deployment missing"
echo "$ALL" | grep -q 'deployment.apps/app2' \
  && ok "app2 deployment exists" \
  || fail "app2 deployment missing"
echo "$ALL" | grep -q 'deployment.apps/app3' \
  && ok "app3 deployment exists" \
  || fail "app3 deployment missing"

# Replica counts
echo "$ALL" | grep 'deployment.apps/app1' | grep -q '1/1' \
  && ok "app1 has 1/1 replicas" \
  || fail "app1 replica count wrong"
echo "$ALL" | grep 'deployment.apps/app2' | grep -q '3/3' \
  && ok "app2 has 3/3 replicas" \
  || fail "app2 replica count wrong"
echo "$ALL" | grep 'deployment.apps/app3' | grep -q '1/1' \
  && ok "app3 has 1/1 replicas" \
  || fail "app3 replica count wrong"

# Services
echo "$ALL" | grep -q 'service/app1' \
  && ok "app1 service exists" \
  || fail "app1 service missing"
echo "$ALL" | grep -q 'service/app2' \
  && ok "app2 service exists" \
  || fail "app2 service missing"
echo "$ALL" | grep -q 'service/app3' \
  && ok "app3 service exists" \
  || fail "app3 service missing"

section "Ingress"

INGRESS=$(guest 'sudo kubectl get ingress')
echo "$INGRESS"
echo

echo "$INGRESS" | grep -q 'iot-ingress' \
  && ok "iot-ingress exists" \
  || fail "iot-ingress missing"

echo "$INGRESS" | grep -q 'app1.com' \
  && ok "Ingress has app1.com rule" \
  || fail "Ingress missing app1.com rule"

echo "$INGRESS" | grep -q 'app2.com' \
  && ok "Ingress has app2.com rule" \
  || fail "Ingress missing app2.com rule"

section "HOST-based routing (curl tests)"

# app1.com -> app1
RESP1=$(guest "curl -s -H 'Host: app1.com' http://localhost/")
echo "$RESP1" | grep -q '"HOSTNAME":"app1-' \
  && ok "Host: app1.com -> app1 pod" \
  || fail "Host: app1.com did not route to app1"

# app2.com -> app2
RESP2=$(guest "curl -s -H 'Host: app2.com' http://localhost/")
echo "$RESP2" | grep -q '"HOSTNAME":"app2-' \
  && ok "Host: app2.com -> app2 pod" \
  || fail "Host: app2.com did not route to app2"

# default -> app3
RESP3=$(guest "curl -s http://localhost/")
echo "$RESP3" | grep -q '"HOSTNAME":"app3-' \
  && ok "Default host -> app3 pod" \
  || fail "Default host did not route to app3"

# ===================== Summary =====================
section "Summary"
TOTAL=$((PASS+FAIL))
echo "  $PASS/$TOTAL checks passed"
[ "$FAIL" -eq 0 ] && echo "  All good!" || echo "  $FAIL check(s) failed"
exit "$FAIL"
