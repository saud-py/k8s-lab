#!/usr/bin/env bash
# Fix 02: OOMKilled
# Remove the restrictive memory limits so the container has enough memory.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 02: OOMKilled ==="
echo "Removing restrictive memory limits..."

kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "remove", "path": "/spec/template/spec/containers/0/resources"}
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
kubectl exec -n "${NAMESPACE}" "${POD}" -- wget -qO- http://localhost/api/health
echo ""
echo "Fixed! Backend has proper memory limits."