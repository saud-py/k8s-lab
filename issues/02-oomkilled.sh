#!/usr/bin/env bash
# Issue 02: OOMKilled
# Set the backend memory limit extremely low (1Mi) so it gets OOMKilled on startup.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 02: OOMKilled ==="
echo "Setting backend memory limit to 1Mi (too low for nginx)..."

kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {
    "limits": {"memory": "1Mi"},
    "requests": {"memory": "1Mi"}
  }}
]'

echo ""
echo "Waiting for pod to be OOMKilled..."
sleep 5

echo ""
echo "=== Current backend pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=backend

echo ""
echo "=== How to diagnose ==="
echo "  kubectl describe pod -n ${NAMESPACE} -l app=backend"
echo "  kubectl get events -n ${NAMESPACE} | grep -i oom"
echo "  kubectl top pods -n ${NAMESPACE}"
echo ""
echo "Run the fix: ./fixes/fix-02-oomkilled.sh"