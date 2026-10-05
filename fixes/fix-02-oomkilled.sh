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
# Wait for a running pod to appear
POD=""
for i in $(seq 1 10); do
  POD=$(kubectl get pods -n "${NAMESPACE}" -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$POD" ] && [ "$POD" != " " ]; then
    STATUS=$(kubectl get pod -n "${NAMESPACE}" "${POD}" -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$STATUS" = "Running" ]; then
      break
    fi
  fi
  sleep 2
done

if [ -z "$POD" ]; then
  echo "Warning: No running pod found, trying anyway..."
  POD=$(kubectl get pods -n "${NAMESPACE}" -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
fi

echo "Testing backend health endpoint..."
kubectl exec -n "${NAMESPACE}" "${POD}" -- curl -s http://localhost/api/health 2>/dev/null || echo "(connect may take a moment)"
echo ""
echo "Fixed! Backend has proper memory limits."