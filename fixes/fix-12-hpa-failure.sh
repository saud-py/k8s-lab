#!/usr/bin/env bash
# Fix 12: HPA Failure
# Replace the broken HPA with one using a real metric (cpu utilization).

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 12: HPA Failure ==="
echo "Recreating the HPA with a working CPU-based metric..."

# Delete the broken HPA first
kubectl delete hpa website -n "${NAMESPACE}" --ignore-not-found || true

# Create a correct HPA that uses CPU utilization (supported by metrics-server)
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: website
  namespace: ${NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: website
  minReplicas: 2
  maxReplicas: 8
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
EOF

echo ""
echo "Waiting for HPA to report metrics..."
sleep 5

echo ""
echo "=== Current HPA status ==="
kubectl get hpa website -n "${NAMESPACE}" -o wide

echo ""
echo "=== HPA description ==="
kubectl describe hpa website -n "${NAMESPACE}"

echo ""
echo "Verification: HPA should show a TARGET and CURRENT value."
echo "Fixed! HPA now uses CPU utilization metric."
