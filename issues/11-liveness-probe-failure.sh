#!/usr/bin/env bash
# Issue 11: Liveness Probe Failure
# Break the liveness probe so Kubernetes constantly restarts the pod.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 11: Liveness Probe Failure ==="
echo "Patching backend liveness probe to always fail..."

kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe", "value": {
    "exec": {"command": ["sh", "-c", "exit 1"]},
    "initialDelaySeconds": 5,
    "periodSeconds": 10
  }}
]'

echo ""
echo "Waiting for pods to restart continuously..."
sleep 5

echo ""
echo "=== Current backend pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=backend

echo ""
echo "=== How to diagnose ==="
echo "  kubectl describe pod -n ${NAMESPACE} -l app=backend"
echo "  kubectl get pods -n ${NAMESPACE} -l app=backend  # look for high RESTART count"
echo "  kubectl logs -n ${NAMESPACE} -l app=backend --previous"
echo ""
echo "Run the fix: ./fixes/fix-11-liveness-probe-failure.sh"