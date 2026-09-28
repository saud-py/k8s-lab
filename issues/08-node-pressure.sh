#!/usr/bin/env bash
# Issue 08: Node Pressure / Taints
# Taint a node to simulate node pressure or maintenance, causing pods to be evicted.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 08: Node Pressure ==="
echo "Adding a taint to simulate node maintenance/pressure..."

# Get the first node (assuming minikube single node)
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Tainting node: $NODE"

kubectl taint nodes "$NODE" key1=value1:NoSchedule --overwrite=true

echo ""
echo "Waiting for scheduler to react..."
sleep 5

echo ""
echo "=== Current node status ==="
kubectl get nodes -o wide

echo ""
echo "=== Current pod status (some may be evicted) ==="
kubectl get pods -n "${NAMESPACE}" -o wide

echo ""
echo "=== How to diagnose ==="
echo "  kubectl describe nodes $NODE  # look for Taints section"
echo "  kubectl get pods -n ${NAMESPACE} -o wide  # look for Evicted pods"
echo "  kubectl get events -n ${NAMESPACE} | grep -i taint\|evict"
echo ""
echo "Run the fix: ./fixes/fix-08-node-pressure.sh"