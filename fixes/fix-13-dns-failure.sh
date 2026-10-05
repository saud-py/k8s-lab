#!/usr/bin/env bash
# Fix 13: DNS Failure
# Recreate the backend Service from the base manifest to restore DNS resolution.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 13: DNS Failure ==="
echo "Recreating the backend Service from base manifest..."

# Recreate the service from the base manifest
kubectl apply -f "$(dirname "$0")/../base/backend/service.yaml"

echo ""
echo "Waiting for the Service to get a ClusterIP..."
sleep 3

echo ""
echo "=== Current services ==="
kubectl get svc -n "${NAMESPACE}"

echo ""
echo "=== Current endpoints ==="
kubectl get endpoints -n "${NAMESPACE}"

echo ""
echo "=== Verification ==="
echo "DNS resolution should now work:"
FRONTEND_POD=$(kubectl get pods -n "${NAMESPACE}" -l app=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "${FRONTEND_POD}" ]; then
    echo "Testing DNS from frontend pod..."
    kubectl exec -n "${NAMESPACE}" "${FRONTEND_POD}" -- nslookup backend || true
fi

echo ""
echo "Fixed! DNS resolution restored."