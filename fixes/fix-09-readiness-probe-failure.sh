#!/usr/bin/env bash
# Fix 09: Readiness Probe Failure
# Restore the backend readiness probe to its working HTTP check.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 09: Readiness Probe Failure ==="
echo "Restoring backend readiness probe to HTTP check..."

kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe", "value": {
    "httpGet": {"path": "/api/health", "port": 80},
    "initialDelaySeconds": 2,
    "periodSeconds": 5
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
echo "Fixed! Backend readiness probe restored."