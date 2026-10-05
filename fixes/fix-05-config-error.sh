#!/usr/bin/env bash
# Fix 05: Configuration Error
# Restore the backend nginx config to its working state.

set -euo pipefail

NAMESPACE="k8s-lab"

echo "=== Fixing Issue 05: Configuration Error ==="
echo "Restoring backend-config ConfigMap to original nginx.conf..."

kubectl create configmap backend-config -n "${NAMESPACE}" \
  --from-file=nginx.conf=<(
    cat <<'EOF'
worker_processes  1;
events { worker_connections  1024; }
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    server {
        listen       80;
        server_name  localhost;
        location = /api/health {
            access_log off;
            return 200 '{"status":"ok","service":"backend"}\n';
            add_header Content-Type application/json;
        }
        location / {
            access_log off;
            return 200 '{"status":"ok","service":"backend"}\n';
            add_header Content-Type application/json;
        }
    }
}
EOF
  ) --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s

echo ""
echo "=== Current backend pod status ==="
kubectl get pods -n "${NAMESPACE}" -l app=backend

echo ""
echo "=== Verification ==="
POD=$(kubectl get pods -n "${NAMESPACE}" -l app=backend -o jsonpath='{.items[0].metadata.name}')
echo "Testing backend health endpoint..."
kubectl exec -n "${NAMESPACE}" "${POD}" -- curl -s http://localhost/api/health
echo ""
echo "Fixed! Backend configuration restored."