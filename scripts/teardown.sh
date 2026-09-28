#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== k8s-lab Teardown ==="
echo "Deleting namespace '${NAMESPACE}' and all resources..."
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true

echo ""
echo "=== Done ==="
echo "All k8s-lab resources have been removed."