#!/usr/bin/env bash
# Fix 11: Liveness Probe Failure
# Restore the backend liveness probe to its working HTTP check.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 11: Liveness Probe Failure ==="
echo "Restoring backend liveness probe to HTTP check..."

kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe", "value": {
    "httpGet": {"path": "/api/health", "port": 80},
    "initialDelaySeconds": 5,
    "periodSeconds": 10
  }}
]'

echo ""
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s

echo ""
echo "=== Current backend pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=backend

echo ""
echo "=== Verification ==="
POD=$(kubectl get pods -n "${NAMESPACE}" -l app=backend -o jsonpath='{.items[0].metadata.name}')
echo "Testing backend health endpoint..."
kubectl exec -n "${NAMESPACE}" "${POD}" -- curl -s http://localhost/api/health
echo ""
echo "Fixed! Backend liveness probe restored."