#!/usr/bin/env bash
# Issue 14: Website CrashLoopBackOff
# This script breaks the website pod by overwriting its entrypoint with a failing command.
# The pod will start, immediately fail, and Kubernetes will restart it (CrashLoopBackOff).
# This is a standalone website failure — NOT a cascade from the backend.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 14: Website CrashLoopBackOff ==="
echo "Patching website deployment to run a failing command..."

kubectl patch deployment website -n "${NAMESPACE}" --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/command", "value": ["/bin/sh", "-c", "echo \"starting...\"; sleep 1; exit 1"]}
]'

echo ""
echo "Waiting for pod to enter CrashLoopBackOff..."
sleep 3

echo ""
echo "=== Current website pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=website

echo ""
echo "=== How to diagnose ==="
echo "  kubectl describe pod -n ${NAMESPACE} -l app=website"
echo "  kubectl logs -n ${NAMESPACE} -l app=website"
echo "  kubectl logs -n ${NAMESPACE} -l app=website --previous"
echo "  kubectl get endpoints website -n ${NAMESPACE}     # no ready endpoints"
echo ""
echo "Note: this is a standalone website failure. The backend is healthy."
echo "Run the fix: ./fixes/fix-14-website-crashloop.sh"