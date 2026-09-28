#!/usr/bin/env bash
# Issue 03: ImagePullBackOff (non-existent image)
# Reference a Docker image that doesn't exist.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 03: ImagePullBackOff (non-existent image) ==="
echo "Patching backend to use a non-existent image..."

kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "this-image-definitely-does-not-exist:latest"}
]'

echo ""
echo "Waiting for ImagePullBackOff..."
sleep 5

echo ""
echo "=== Current backend pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=backend

echo ""
echo "=== How to diagnose ==="
echo "  kubectl describe pod -n ${NAMESPACE} -l app=backend"
echo "  kubectl get events -n ${NAMESPACE} | grep -i 'pull\|image'"
echo ""
echo "Run the fix: ./fixes/fix-03-image-pull-error.sh"