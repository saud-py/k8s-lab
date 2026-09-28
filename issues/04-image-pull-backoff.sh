#!/usr/bin/env bash
# Issue 04: ImagePullBackOff (auth required)
# Use a private registry that requires auth (simulated by using a registry that doesn't exist or requires creds).
# We'll use a fake registry URL that will fail to pull.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 04: ImagePullBackOff (auth/registry issue) ==="
echo "Patching backend to use a registry that requires auth (simulated)..."

kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "index.docker.io/doesnotexist/private-registry-image:latest"}
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
echo "  kubectl get events -n ${NAMESPACE} | grep -i 'pull\|image\|registry'"
echo ""
echo "Run the fix: ./fixes/fix-04-image-pull-backoff.sh"