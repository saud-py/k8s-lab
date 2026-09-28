#!/usr/bin/env bash
# Issue 05: Configuration Error
# Inject wrong MySQL password into a ConfigMap that the backend doesn't actually use,
# but we'll simulate by creating a ConfigMap that the app *thinks* it uses.
# Actually, since our backend doesn't use MySQL directly, let's instead corrupt the nginx config.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 05: Configuration Error ==="
echo "Patching backend nginx config to be invalid..."

kubectl patch configmap backend-config -n "${NAMESPACE}" --type merge -p '{"data":{"nginx.conf":"invalid nginx configuration that will cause nginx to fail to start\n"}}'

echo ""
echo "Waiting for pods to restart with bad config..."
sleep 5

echo ""
echo "=== Current backend pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=backend

echo ""
echo "=== How to diagnose ==="
echo "  kubectl describe pod -n ${NAMESPACE} -l app=backend"
echo "  kubectl logs -n ${NAMESPACE} -l app=backend"
echo "  kubectl get configmap backend-config -n ${NAMESPACE} -o yaml"
echo ""
echo "Run the fix: ./fixes/fix-05-config-error.sh"