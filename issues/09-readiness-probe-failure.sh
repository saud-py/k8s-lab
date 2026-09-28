#!/usr/bin/env bash
# Issue 09: Readiness Probe Failure
# Make the readiness probe always fail (return non-zero), so pod is not Ready.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 09: Readiness Probe Failure ==="
echo "Patching backend readiness probe to always fail..."

kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe", "value": {
    "exec": {"command": ["sh", "-c", "exit 1"]},
    "initialDelaySeconds": 2,
    "periodSeconds": 5
  }}
]'

echo ""
echo "Waiting for pods to become NotReady..."
sleep 5

echo ""
echo "=== Current backend pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=backend

echo ""
echo "=== How to diagnose ==="
echo "  kubectl describe pod -n ${NAMESPACE} -l app=backend"
echo "  kubectl get pods -n ${NAMESPACE} -l app=backend  # look for 1/2 or 0/2 READY"
echo "  kubectl get events -n ${NAMESPACE} | grep -i readiness"
echo ""
echo "Run the fix: ./fixes/fix-09-readiness-probe-failure.sh"