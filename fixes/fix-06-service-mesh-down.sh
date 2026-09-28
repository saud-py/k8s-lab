#!/usr/bin/env bash
# Fix 06: Service Mesh Down
# Recreate the backend service.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 06: Service Mesh Down ==="
echo "Recreating the backend service..."

# Recreate the service from the base manifest
kubectl apply -f "$(dirname "$0")/../base/backend/service.yaml"

echo ""
echo "Waiting for service to be ready..."
sleep 2

echo ""
echo "=== Current services ==="
kubectl get svc -n "${NAMESPACE}"

echo ""
echo "=== Verification ==="
echo "Service 'backend' should now be present with a ClusterIP."
echo ""
echo "Fixed! Backend service recreated."