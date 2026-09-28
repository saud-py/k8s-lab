# Kubernetes Commands Cheatsheet for k8s-lab

This cheatsheet documents the `kubectl` commands used throughout this project for learning Kubernetes in a hands‑on environment.

## Core Resource Commands

### View Resources

```bash
# Get all pods in the current namespace (k8s-lab)
kubectl get pods

# Get all pods with wide output (includes node name, IP, etc.)
kubectl get pods -o wide

# Get pods filtered by label
kubectl get pods -l app=backend

# Get all resources (pods, services, deployments) at once
kubectl get all

# Get services
kubectl get svc

# Get deployments
kubectl get deployment

# Get PVCs
kubectl get pvc

# Get nodes
kubectl get nodes

# Get storage classes
kubectl get storageclass
```

### Describe Resources

```bash
# Detailed diagnostics for a pod
kubectl describe pod <pod-name>

# Detailed diagnostics for a deployment
kubectl describe deployment <name>

# Detailed diagnostics for a service
kubectl describe svc <name>

# Detailed diagnostics for a node
kubectl describe node <name>

# Detailed diagnostics for a PVC
kubectl describe pvc <name>
```

### Logs

```bash
# Current pod logs
kubectl logs <pod-name>

# Previous pod logs (CrashLoopBackOff, evicted pods)
kubectl logs <pod-name> --previous

# All previous logs
kubectl logs <pod-name> --all

# Follow logs (like tail -f)
kubectl logs -f <pod-name>

# Logs for all pods in namespace
kubectl logs $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name} {end}')

# Logs with timestamps
kubectl logs <pod-name> --timestamps
```

### Execute into Container

```bash
# Interactive shell into a pod
kubectl exec -it <pod-name> -- sh

# Non-interactive command
kubectl exec <pod-name> -- <command>

# Execute multiple commands
kubectl exec <pod-name> -- sh -c "<command1>; <command2>"

# Execute on all pods
kubectl exec -it $(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name} ') -- sh
```

### Resource Usage

```bash
# View CPU and memory usage for pods
kubectl top pods

# View CPU and memory usage for all pods in namespace
kubectl top pods --namespace=k8s-lab

# View usage for specific pod
kubectl top pod <pod-name>

# View node usage
kubectl top nodes
```

## Diagnostic Commands

### Events

```bash
# Get all events in the current namespace
kubectl get events

# Get events sorted chronologically (most recent first)
kubectl get events --sort-by=.metadata.creationTimestamp

# Get events for a specific resource
kubectl get events --field-selector involvedName=<resource-name>

# Get events with specific reasons (warnings/errors)
kubectl get events | grep -i "error\|warn\|failed\|oom"

# Watch for new events
kubectl get events --watch
```

### Rollouts

```bash
# Monitor a rollout (block until complete)
kubectl rollout status deployment/<name> --timeout=60s

# Pause a rollout
kubectl rollout pause deployment/<name>

# Resume a rollout
kubectl rollout resume deployment/<name>

# Undo a rollout (revert to previous revision)
kubectl rollout undo deployment/<name>

# See rollout history
kubectl rollout history deployment/<name>

# Get rollout status without blocking
kubectl get deployment <name> -o wide
```

### Node Management

```bash
# Mark a node as unschedulable (cordon)
kubectl cordon <node-name>

# Mark a node as schedulable (uncordon)
kubectl uncordon <node-name>

# Add a taint to a node (simulate pressure)
kubectl taint nodes <node-name> key=value:NoSchedule

# Remove a taint from a node
kubectl taint nodes <node-name> key=value:NoSchedule-

# Get node info
kubectl get node <name> -o wide

# Get node conditions
kubectl get node <name> -o jsonpath='{.status.conditions}'
```

### Patching Resources

```bash
# Patch a deployment (JSON merge patch)
kubectl patch deployment <name> --type='json' -p='[{"op":"replace","path":"/spec/replicas","value":3}]'

# Add a label
kubectl patch deployment <name> --type='json' -p='[{"op":"add","path":"/metadata/labels/foo","value":"bar"}]'

# Remove a field
kubectl patch deployment <name> --type='json' -p='[{"op":"remove","path":"/spec/template/spec/containers/0/resources"}]'

# Patch using YAML merge (safer for nested structures)
kubectl patch deployment <name> --type='merge' -p='replicas: 3'

# Patch a ConfigMap
kubectl patch configmap <name> --type='json' -p='[{"op":"replace","path":"/data/KEY","value":"new-value"}]'

# Patch a PVC
kubectl patch pvc <name> --type='json' -p='[{"op":"add","path":"/spec/storageClassName","value":"new-storage-class"}]'
```

## Application‑Specific Commands

### Testing Backend API

```bash
# Get backend pod name
BACKEND_POD=$(kubectl get pods -n k8s-lab -l app=backend -o jsonpath='{.items[0].metadata.name}')

# Test backend health endpoint
kubectl exec -n k8s-lab $BACKEND_POD -- wget -qO- http://localhost/api/health

# Test frontend health endpoint
FRONTEND_POD=$(kubectl get pods -n k8s-lab -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n k8s-lab $FRONTEND_POD -- wget -qO- http://localhost/health

# Port forward to access services locally (example: frontend on localhost:8080)
kubectl port-forward svc/frontend 8080:80 -n k8s-lab
```

### Scripts

This project includes several shell scripts to streamline common operations:

```bash
# Deploy the healthy baseline
./scripts/setup.sh

# Check current status
./scripts/check-status.sh

# Clean up everything
./scripts/teardown.sh

# Inject each issue (run in order)
./issues/01-crashloop-backoff.sh
./issues/02-oomkilled.sh
# ... etc

# Fix each issue (run after the corresponding issue)
./fixes/fix-01-crashloop.sh
./fixes/fix-02-oomkilled.sh
# ... etc
```

## Tips for Using This Cheatsheet

1. **Practice with dry‑runs**: Before applying changes that could break things, use `kubectl apply --dry-run=client -f <file>`.

2. **Save useful commands**: The scripts often show example commands; copy those into your workflow.

3. **Understand output**: Pay attention to the `-o wide` flag for debugging networking and IP issues.

4. **Check events**: When something isn't working, `kubectl get events --sort-by=.metadata.creationTimestamp` often reveals the root cause.

5. **Follow the script flow**: The `issues/` and `fixes/` scripts are designed to teach a pattern; running them in order builds a systematic approach.

6. **Use `kubectl describe`**: This command is the best first step when something goes wrong.

7. **Remember the namespace**: All commands here assume the `k8s-lab` namespace. Use `-n k8s-lab` explicitly when needed.

8. **Version control**: Initialize a git repo and track your changes to remember what you learned and what fixes you applied.

## Quick Reference

```bash
# Get a pod by label
POD=$(kubectl get pods -l app=backend -o jsonpath='{.items[0].metadata.name}')

# Describe, logs, exec combination for debugging
kubectl describe pod $POD
kubectl logs $POD
kubectl exec -it $POD -- sh

# Check rollout status
kubectl rollout status deployment/backend

# Check node condition
kubectl get node $(kubectl get nodes -o jsonpath='{..metadata.name}') -o wide

# Get events for a resource
kubectl get events --field-selector involvedName=$POD

# Port forward for local testing
kubectl port-forward svc/frontend 8080:80
```

This cheatsheet will grow as you work through more Kubernetes concepts. Feel free to add your own commonly‑used commands and patterns!

---

**Generated by**: Kubernetes Learning Lab Project
**Purpose**: Hands‑on Kubernetes practice with mock production issues