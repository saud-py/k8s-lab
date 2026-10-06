#!/usr/bin/env bash
# Issue 01: CrashLoopBackOff
# This script breaks the backend pod by overwriting its entrypoint with a failing command.
# The pod will start, immediately fail, and Kubernetes will restart it (CrashLoopBackOff).

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 01: CrashLoopBackOff ==="
echo "Patching backend deployment to run a failing command..."

kubectl patch deployment backend -n "${NAMESPACE}" --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/command", "value": ["/bin/sh", "-c", "echo \"starting...\"; sleep 1; exit 1"]}
]'

echo ""
echo "Waiting for pod to enter CrashLoopBackOff..."
sleep 3

echo ""
echo "=== Current backend pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=backend

echo ""
echo "=== How to diagnose ==="
echo "  kubectl describe pod -n ${NAMESPACE} -l app=backend"
echo "  kubectl logs -n ${NAMESPACE} -l app=backend"
echo "  kubectl logs -n ${NAMESPACE} -l app=backend --previous"
echo "  kubectl get pods -n ${NAMESPACE} -l app=website     # website goes down too (it depends on backend)"
echo ""
echo "Note: the website Service depends on the backend, so its"
echo "readiness probe (which checks /api/health) will also fail"
echo "and the website will break as a consequence."
echo ""
echo "Run the fix: ./fixes/fix-01-crashloop.sh"