#!/usr/bin/env bash
# Issue 12: HPA Failure (Horizontal Pod Autoscaler misconfiguration)
# Delete the HorizontalPodAutoscaler and leave a bad autoscaling metric reference.
#
# Level: Intermediate - introduces autoscaling, metrics-server, and scaling behavior.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Injecting Issue 12: HPA Failure ==="
echo "Removing the HPA and replacing with a misconfigured one that references"
echo "a non-existent metric so the HPA can never scale the frontend."
echo ""

# Delete any existing HPA first
kubectl delete hpa frontend -n "${NAMESPACE}" --ignore-not-found || true

# Create a broken HPA that references a custom metric that doesn't exist.
# The HPA controller will keep failing with "failed to get cpu utilization:
# unable to get external metric ... unable to match any metric names".
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend
  namespace: ${NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 2
  maxReplicas: 8
  metrics:
    - type: Pods
      pods:
        metric:
          name: requests-per-second   # <--- this metric is not collected by metrics-server
          selector:
            matchLabels:
              app: frontend
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
EOF

echo "Broken HPA applied. Waiting for the HPA to show an error condition..."
sleep 4

echo ""
echo "=== Current HPA status ==="
kubectl describe hpa/frontend -n "${NAMESPACE}"

echo ""
echo "=== How to diagnose ==="
echo "  kubectl get hpa -n ${NAMESPACE}           # look for 'SLO' or low scale value"
echo "  kubectl describe hpa/frontend -n ${NAMESPACE}  # check for failed-get-metrics"
echo "  kubectl get events -n ${NAMESPACE} | grep -i hpa"
echo "  kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods  # verify metrics-server is exposing metrics"
echo ""
echo "Run the fix: ./fixes/fix-12-hpa-failure.sh"
