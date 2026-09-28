#!/usr/bin/env bash
# Issue 10: Rollout Stuck
# Pause a rollout with a bad configuration (e.g., invalid image) so it stays in progress.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 10: Rollout Stuck ==="
echo "Setting backend to use a non-existent image and then pausing rollout..."

# First set bad image
kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "this-image-definitely-does-not-exist:latest"}
]'

# Then pause the rollout
kubectl rollout pause deployment/backend -n "${NAMESPACE}"

echo ""
echo "Waiting for rollout to show as paused..."
sleep 3

echo ""
echo "=== Current rollout status ==="
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=5s 2>/dev/null || echo "Rollout is paused (as expected)"
echo ""
echo "=== Current backend pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=backend

echo ""
echo "=== How to diagnose ==="
echo "  kubectl rollout status deployment/backend -n ${NAMESPACE}"
echo "  kubectl describe deployment backend -n ${NAMESPACE}"
echo "  kubectl get rs -n ${NAMESPACE}  # look for new ReplicaSet"
echo "  kubectl get events -n ${NAMESPACE} | grep -i rollout"
echo ""
echo "Run the fix: ./fixes/fix-10-rollout-stuck.sh"