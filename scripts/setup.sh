#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="k8s-lab"
BASE_DIR="$(dirname "$0")/../base"

echo "=== k8s-lab Setup ==="
echo "Creating namespace '${NAMESPACE}'..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "Applying base manifests..."
kubectl apply -f "${BASE_DIR}/namespace.yaml"
kubectl apply -f "${BASE_DIR}/frontend/"
kubectl apply -f "${BASE_DIR}/website/"
kubectl apply -f "${BASE_DIR}/backend/"
kubectl apply -f "${BASE_DIR}/redis/"
kubectl apply -f "${BASE_DIR}/mysql/"

echo ""
echo "Waiting for pods to be ready (up to 120s)..."
kubectl wait --for=condition=Ready pods --all -n "${NAMESPACE}" --timeout=120s 2>/dev/null || true

echo ""
echo "=== Current Status ==="
bash "$(dirname "$0")/check-status.sh"