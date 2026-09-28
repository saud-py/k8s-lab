#!/usr/bin/env bash
# Issue 06: Service Mesh Down (DNS resolution failure)
# Delete the backend service so frontend can't resolve backend hostname.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 06: Service Mesh Down ==="
echo "Deleting the backend service (simulating service mesh failure)..."

kubectl delete service backend -n "${NAMESPACE}"

echo ""
echo "Waiting a moment for DNS cache to clear..."
sleep 3

echo ""
echo "=== Current services ==="
kubectl get svc -n "${NAMESPACE}"

echo ""
echo "=== How to diagnose ==="
echo "  kubectl get svc -n ${NAMESPACE}"
echo "  kubectl describe svc backend -n ${NAMESPACE}  # will show NotFound"
echo "  kubectl get endpoints backend -n ${NAMESPACE}  # will show no endpoints"
echo ""
echo "Note: To test from frontend pod, you would exec in and try to curl backend:80"
echo ""
echo "Run the fix: ./fixes/fix-06-service-mesh-down.sh"