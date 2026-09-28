#!/usr/bin/env bash
# Fix 07: PVC Failed Binding
# Remove the non-existent storage class so PVC uses default.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 07: PVC Failed Binding ==="
echo "Removing the problematic storageClassName from mysql PVC..."

kubectl patch pvc mysql-pvc -n "${NAMESPACE}" --type='json' -p='[
  {"op": "remove", "path": "/spec/storageClassName"}
]'

echo ""
echo "Waiting for PVC to bind..."
sleep 5

echo ""
echo "=== Current PVC status ==="
kubectl get pvc -n "${NAMESPACE}"

echo ""
echo "=== Current MySQL pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=mysql

echo ""
echo "=== Verification ==="
echo "PVC should be Bound and MySQL pod Running."
echo ""
echo "Fixed! PVC now using default storage class."