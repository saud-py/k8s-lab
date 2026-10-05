#!/usr/bin/env bash
# Issue 13: DNS Failure for Pod/Service (DNS resolution failure)
# Remove the backend service, so any pod that tries to reach
# `backend` by hostname cannot resolve it. This is a common DNS failure
# scenario in Kubernetes: CoreDNS is running, but no Service exists for
# the requested hostname.
#
# Level: Beginner - teaches DNS basics and Service/End points.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 13: DNS Failure ==="
echo "Deleting the backend Service so DNS no longer resolves it..."

kubectl delete service backend -n "${NAMESPACE}"

echo ""
echo "Waiting a moment for the DNS entry to expire..."
sleep 3

echo ""
echo "=== Current services ==="
kubectl get svc -n "${NAMESPACE}"

echo ""
echo "=== Current endpoints ==="
kubectl get endpoints -n "${NAMESPACE}"

echo ""
echo "=== How to diagnose ==="
echo "  kubectl get svc -n ${NAMESPACE}          # backend is missing"
echo "  kubectl describe svc backend -n ${NAMESPACE}   # Error: services \"backend\" not found"
echo "  kubectl get endpoints backend -n ${NAMESPACE}  # Error: no endpoints"
echo "  kubectl exec -it <frontend-pod> -n ${NAMESPACE} -- nslookup backend"
echo "    # will fail with \"server failed: non-existent domain\""
echo "  kubectl logs -n ${NAMESPACE} -l app=frontend  # look for lookup failures"
echo ""
echo "Run the fix: ./fixes/fix-13-dns-failure.sh"
