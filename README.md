# Kubernetes Learning Lab — Mock Production Issues Playground

This project provides a self-contained environment for learning Kubernetes commands in depth. It simulates common production issues in a small multi-service application, letting you practice diagnosis and remediation.

## What You'll Learn

- **Core kubectl commands**: get, describe, logs, exec, top, events, rollout, etc.
- **Diagnostic techniques**: interpreting pod states, events, resource usage.
- **Remediation patterns**: fixing pods, services, deployments, PVCs.
- **Real-world scenarios**: crash loops, OOMKilled, image pull errors, probe failures, node pressure, etc.

## Directory Structure

```
k8s-lab/
├── base/              # Base Kubernetes manifests (namespace, services, deployments, etc.)
├── issues/            # Scripts that inject mock production issues
├── fixes/             # Corresponding fix scripts
├── scripts/           # Utility scripts (setup, teardown, status check)
└── docs/              # Documentation (commands cheatsheet)
```

## Usage

### Setup (Initial Deployment)

1. **Deploy the healthy baseline**:
   ```bash
   cd k8s-lab
   ./scripts/setup.sh
   ```
   This creates a fresh `k8s-lab` namespace with all services running.

2. **Check status**:
   ```bash
   ./scripts/check-status.sh
   ```

### Practice Issues

Each issue script (`issues/XX-*.sh`) deliberately breaks one aspect of the application. Run them in order:

```bash
./issues/01-crashloop-backoff.sh
./issues/02-oomkilled.sh
./issues/03-image-pull-error.sh
# ... etc
```

Each script:
- Explains what it's doing
- Shows how to diagnose the problem
- Points to the corresponding fix script

### Fix Issues

After injecting an issue, run the corresponding fix script:

```bash
./fixes/fix-01-crashloop.sh
./fixes/fix-02-oomkilled.sh
./fixes/fix-03-image-pull-error.sh
# ... etc
```

### Tearing Down

Remove the entire environment:

```bash
./scripts/teardown.sh
```

## Available Issues (13 total)

| # | Issue | Level | What it teaches |
|---|-------|-------|----------------|
| 01 | CrashLoopBackOff | Beginner | Pod restart loops, checking previous logs |
| 02 | OOMKilled | Beginner | Resource limits, memory pressure |
| 03 | ImagePullBackOff (non-existent) | Beginner | Image errors, Docker Hub connectivity |
| 04 | ImagePullBackOff (auth) | Beginner | Private registry auth, credentials |
| 05 | ConfigError | Beginner | Bad configuration, invalid manifests |
| 06 | Service Mesh Down | Intermediate | Service deletion, DNS resolution, endpoints |
| 07 | PVC Failed Binding | Intermediate | Storage issues, storage classes |
| 08 | Node Pressure | Intermediate | Taints, evictions, scheduling |
| 09 | Readiness Probe Failure | Intermediate | Pod readiness, health checks |
| 10 | Rollout Stuck | Intermediate | Paused rollouts, version management |
| 11 | Liveness Probe Failure | Intermediate | Restart policies, container health |
| 12 | HPA Failure | Intermediate | Autoscaling, metrics-server, custom metrics |
| 13 | DNS Failure | Beginner | Service DNS resolution, nslookup |

## Key Kubernetes Commands You'll Use

See `docs/commands.md` for a detailed cheatsheet.

Basic commands:
- `kubectl get pods -o wide` (see pods, IPs, node names)
- `kubectl describe pod <name>` (detailed diagnostics)
- `kubectl logs <pod>` (container logs)
- `kubectl logs <pod> --previous` (previous pod, e.g., CrashLoopBackOff)
- `kubectl exec -it <pod> -- sh` (debug inside container)
- `kubectl top pods` (resource usage)
- `kubectl get events --sort-by=.metadata.creationTimestamp` (chronological events)
- `kubectl rollout status <resource> --timeout=<s>` (monitor rollouts)
- `kubectl rollout pause/resume <resource>` (control rollouts)
- `kubectl cordon/uncordon node <name>` (mark nodes for maintenance)
- `kubectl taint node <name> key=value:NoSchedule` (simulate node pressure)
- `kubectl patch <resource>` (quick edits)
- `kubectl edit <resource>` (manual editing)
- `kubectl apply -f` (apply manifests)
- `kubectl delete <resource>` (clean up)

## How to Use This Project

1. **Start with setup**: Run `./scripts/setup.sh` to deploy the healthy app.
2. **Observe healthy state**: Use `./scripts/check-status.sh` to confirm all pods are Ready.
3. **Inject issues**: Run each issue script to learn how to detect the problem.
4. **Fix issues**: Run the corresponding fix script to remediate.
5. **Repeat** for all 11 issues.
6. **Teardown**: Clean up with `./scripts/teardown.sh` when done.

## Assumptions

- Minikube is running with `kubectl` pointing to it.
- Standard Docker images (`nginx`, `redis`, `mysql`) are available (pulled from Docker Hub).
- Basic familiarity with YAML, Kubernetes concepts (pods, services, deployments).
- No Kubernetes admin permissions needed (all actions are within a dedicated namespace).

## Tips for Learning
n
- **Take notes**: Document the `kubectl` commands that reveal the problem.
- **Practice dry-runs**: Use `kubectl apply --dry-run=client -f <file>` before applying changes.
- **Check events**: Events often tell you *why* something failed.
- **Use `kubectl describe`**: This command is the best diagnostic tool for any resource.
- **Follow the scripts**: The scripts include explicit commands for diagnosis and remediation.