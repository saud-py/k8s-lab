#!/usr/bin/env bash
# Fix 10: Rollout Stuck
# Resume the rollout with a good image (or undo the bad change).

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 10: Rollout Stuck ==="
echo "Resuming rollout with correct image..."

# First unpause
kubectl rollout resume deployment/backend -n "${NAMESPACE}"

# Then fix the image (in case it was changed)
kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "nginx:1.27-alpine"}
]'

echo ""
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=120s

echo ""
echo "=== Current backend pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=backend

echo ""
echo "=== Verification ==="
POD=$(kubectl get pods -n "${NAMESPACE}" -l app=backend -o jsonpath='{.items[0].metadata.name}')
echo "Testing backend health endpoint..."
kubectl exec -n "${NAMESPACE}" "${POD}" -- curl -s http://localhost/api/health
echo ""
echo "Fixed! Rollout completed successfully."