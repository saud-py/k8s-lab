#!/usr/bin/env bash
# Fix 03: ImagePullBackOff
# Restore the backend to use the correct nginx image.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 03: ImagePullBackOff ==="
echo "Restoring backend to use nginx:1.27-alpine..."

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
kubectl exec -n "${NAMESPACE}" "${POD}" -- wget -qO- http://localhost/api/health
echo ""
echo "Fixed! Backend is running the correct image."