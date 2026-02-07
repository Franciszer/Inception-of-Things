#!/usr/bin/env bash
# p1/test.sh — Automated eval checks for Part 1: K3s and Vagrant
# Run from p1/ after "vagrant up" has completed.
set -uo pipefail

LOGIN='frthierr'
SERVER="${LOGIN}S"
WORKER="${LOGIN}SW"
SERVER_IP='192.168.56.110'
WORKER_IP='192.168.56.111'

PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "  [OK]  $1"; }
fail() { FAIL=$((FAIL+1)); echo "  [KO]  $1"; }

section() { echo; echo "=== $1 ==="; }

# ---------- Part 1 – Configuration ----------
section "Configuration checks"

# 1. Vagrantfile exists
[ -f Vagrantfile ] && ok "Vagrantfile exists" || fail "Vagrantfile not found"

# 2. Two VMs defined
VM_COUNT=$(grep -cE '\.vm\.define' Vagrantfile)
[ "$VM_COUNT" -eq 2 ] && ok "2 VMs defined in Vagrantfile" || fail "Expected 2 VMs, found $VM_COUNT"

# 3. Names contain login + S / SW
grep -qE "define.*${LOGIN}S" Vagrantfile && ok "Server name contains ${LOGIN}S" || fail "Server name missing"
grep -qE "define.*${LOGIN}SW" Vagrantfile && ok "Worker name contains ${LOGIN}SW" || fail "Worker name missing"

# 4. IPs present
grep -q "$SERVER_IP" Vagrantfile && ok "Server IP $SERVER_IP in Vagrantfile" || fail "Server IP missing"
grep -q "$WORKER_IP" Vagrantfile && ok "Worker IP $WORKER_IP in Vagrantfile" || fail "Worker IP missing"

# ---------- Part 1 – Usage ----------
section "Vagrant status"

STATUS=$(vagrant status --machine-readable 2>/dev/null)
echo "$STATUS" | grep -q "${SERVER},state,running" && ok "$SERVER is running" || fail "$SERVER is not running"
echo "$STATUS" | grep -q "${WORKER},state,running" && ok "$WORKER is running" || fail "$WORKER is not running"

section "SSH & hostname"

S_HOST=$(vagrant ssh "$SERVER" -c 'hostname' 2>/dev/null | tr -d '\r')
[ "$S_HOST" = "$SERVER" ] && ok "Server hostname = $SERVER" || fail "Server hostname is '$S_HOST', expected '$SERVER'"

W_HOST=$(vagrant ssh "$WORKER" -c 'hostname' 2>/dev/null | tr -d '\r')
[ "$W_HOST" = "$WORKER" ] && ok "Worker hostname = $WORKER" || fail "Worker hostname is '$W_HOST', expected '$WORKER'"

section "Network interfaces"

S_IP=$(vagrant ssh "$SERVER" -c "ip -4 -o addr show | grep '$SERVER_IP'" 2>/dev/null | tr -d '\r')
[ -n "$S_IP" ] && ok "Server has IP $SERVER_IP" || fail "Server missing IP $SERVER_IP"

W_IP=$(vagrant ssh "$WORKER" -c "ip -4 -o addr show | grep '$WORKER_IP'" 2>/dev/null | tr -d '\r')
[ -n "$W_IP" ] && ok "Worker has IP $WORKER_IP" || fail "Worker missing IP $WORKER_IP"

section "K3s services"

vagrant ssh "$SERVER" -c 'systemctl is-active k3s' 2>/dev/null | grep -q 'active' \
  && ok "k3s (server) service active" || fail "k3s (server) service not active"

vagrant ssh "$WORKER" -c 'systemctl is-active k3s-agent' 2>/dev/null | grep -q 'active' \
  && ok "k3s-agent service active" || fail "k3s-agent service not active"

section "Cluster nodes (kubectl get nodes -o wide)"

NODES_OUTPUT=$(vagrant ssh "$SERVER" -c 'sudo kubectl get nodes -o wide' 2>/dev/null)
echo "$NODES_OUTPUT"
echo

NODE_COUNT=$(echo "$NODES_OUTPUT" | grep -c ' Ready ')
[ "$NODE_COUNT" -ge 2 ] && ok "$NODE_COUNT nodes Ready in cluster" || fail "Expected 2 Ready nodes, got $NODE_COUNT"

echo "$NODES_OUTPUT" | grep -qi "$SERVER" \
  && ok "Server node listed" || fail "Server node not found in output"

echo "$NODES_OUTPUT" | grep -qi "$WORKER" \
  && ok "Worker node listed" || fail "Worker node not found in output"

echo "$NODES_OUTPUT" | grep -q "$SERVER_IP" \
  && ok "Server INTERNAL-IP is $SERVER_IP" || fail "Server INTERNAL-IP mismatch"

echo "$NODES_OUTPUT" | grep -q "$WORKER_IP" \
  && ok "Worker INTERNAL-IP is $WORKER_IP" || fail "Worker INTERNAL-IP mismatch"

# Verify roles: server should be control-plane, worker should not
echo "$NODES_OUTPUT" | grep -i "$SERVER" | grep -q 'control-plane\|master' \
  && ok "Server has control-plane role" || fail "Server missing control-plane role"

# ---------- Summary ----------
section "Summary"
TOTAL=$((PASS+FAIL))
echo "  $PASS/$TOTAL checks passed"
[ "$FAIL" -eq 0 ] && echo "  All good!" || echo "  $FAIL check(s) failed"
exit "$FAIL"
