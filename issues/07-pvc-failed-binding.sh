#!/usr/bin/env bash
# Issue 07: PVC Failed Binding
# Request a storage class that doesn't exist, causing PVC to remain in Pending state.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 07: PVC Failed Binding ==="
echo "Patching mysql PVC to use a non-existent storage class..."

kubectl patch pvc mysql-pvc -n "${NAMESPACE}" --type='json' -p='[
  {"op": "add", "path": "/spec/storageClassName", "value": "non-existent-storage-class"}
]'

echo ""
echo "Waiting for PVC to show Pending state..."
sleep 3

echo ""
echo "=== Current PVC status ==="
kubectl get pvc -n "${NAMESPACE}"

echo ""
echo "=== Current MySQL pod status (should be Pending) ==="
kubectl get pods -n "${NAMESPACE}" -l app=mysql

echo ""
echo "=== How to diagnose ==="
echo "  kubectl describe pvc mysql-pvc -n ${NAMESPACE}"
echo "  kubectl get events -n ${NAMESPACE} | grep -i pvc"
echo "  kubectl get sc  # list available storage classes"
echo ""
echo "Run the fix: ./fixes/fix-07-pvc-failed-binding.sh"