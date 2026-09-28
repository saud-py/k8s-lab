#!/usr/bin/env bash
# Fix 08: Node Pressure
# Remove the taint to restore normal scheduling.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 08: Node Pressure ==="
echo "Removing the taint to restore normal node scheduling..."

# Get the first node (assuming minikube single node)
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Removing taint from node: $NODE"

kubectl taint nodes "$NODE" key1=value1:NoSchedule- --overwrite=true

echo ""
echo "Waiting for scheduler to reschedule pods..."
sleep 5

echo ""
echo "=== Current node status ==="
kubectl get nodes -o wide

echo ""
echo "=== Current pod status ==="
kubectl get pods -n "${NAMESPACE}" -o wide

echo ""
echo "=== Verification ==="
echo "No taints should remain and pods should be Running."
echo ""
echo "Fixed! Node taint removed."