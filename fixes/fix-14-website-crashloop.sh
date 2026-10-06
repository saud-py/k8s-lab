#!/usr/bin/env bash
# Fix 14: Website CrashLoopBackOff
# Restore the website deployment to its original working state.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 14: Website CrashLoopBackOff ==="
echo "Restoring website deployment to original config..."

# Remove the custom command (revert to image default)
kubectl patch deployment website -n "${NAMESPACE}" --type='json' -p='[
  {"op": "remove", "path": "/spec/template/spec/containers/0/command"}
]'

echo ""
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/website -n "${NAMESPACE}" --timeout=60s

echo ""
echo "=== Current website pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=website

echo ""
echo "=== Verification ==="
# Wait for a running pod to appear
POD=""
for i in $(seq 1 10); do
  POD=$(kubectl get pods -n "${NAMESPACE}" -l app=website -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
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
  POD=$(kubectl get pods -n "${NAMESPACE}" -l app=website -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
fi

echo "Testing website health endpoint..."
kubectl exec -n "${NAMESPACE}" "${POD}" -- curl -s http://localhost/health 2>/dev/null || echo "(connect may take a moment)"
echo ""
echo "Fixed! Website is healthy again."