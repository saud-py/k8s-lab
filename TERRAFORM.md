# Terraform: Low-Cost EKS Cluster with Microservices

This Terraform configuration deploys:
- A VPC with public and private subnets across 2 AZs
- A NAT Gateway for outbound internet access from private subnets
- An EKS cluster (version 1.31) with IAM roles
- A managed node group using low-cost `t3.micro` instances (on-demand, can switch to SPOT)
- Two sample microservices deployed via the Kubernetes provider:
  - **frontend**: Nginx (exposed via LoadBalancer)
  - **backend**: HashiCorp http-echo (internal ClusterIP)

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- kubectl (for interacting with the cluster after creation)

## Quick Start

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `ap-southeast-2` |
| `cluster_name` | EKS cluster name | `low-cost-dev-cluster` |
| `cluster_version` | Kubernetes version | `1.31` |
| `node_instance_type` | Worker node instance type | `t3.micro` |
| `desired_capacity` | Desired node count | `2` |
| `max_capacity` | Maximum node count | `3` |
| `min_capacity` | Minimum node count | `1` |

To override variables, create a `terraform.tfvars` file or pass `-var` flags.

## Cost Optimization

- **Instance Type**: Uses `t3.micro` (~$0.0104/hr each). For even lower cost, change `capacity_type = "SPOT"` in `aws_eks_node_group`.
- **Node Count**: Default is 2 nodes. Adjust `desired_capacity`, `min_capacity`, `max_capacity`.
- **NAT Gateway**: A single NAT Gateway is created (~$0.045/hr + data processing). For dev, consider removing it and using public subnets for nodes (less secure).
- **LoadBalancer**: The frontend service creates an AWS Network LoadBalancer (~$0.0225/hr). Remove `type = "LoadBalancer"` and use `NodePort` if not needed.

## Outputs

After apply, useful outputs:

```bash
# Get the kubeconfig
terraform output -raw kubeconfig > kubeconfig.yaml
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Verify cluster
kubectl get nodes
kubectl get pods -n lab
kubectl get svc -n lab
```

## Accessing the Frontend

The frontend is exposed via an AWS LoadBalancer. Get the hostname:

```bash
terraform output frontend_service_hostname
# or
kubectl get svc frontend -n lab
```

## Cleanup

```bash
terraform destroy
```

## Architecture

```
Internet
    │
    ▼
Internet Gateway ──▶ Public Subnets (AZ1, AZ2)
    │                     │
    │                     ├── NAT Gateway (AZ1) ◀──▶ Private Subnets (AZ1, AZ2) ──▶ EKS Worker Nodes
    │                     │
    │                     └── (LoadBalancer for frontend)
    │
    ▼
EKS Control Plane (managed by AWS)
```

## Notes

- The cluster uses private subnets for worker nodes (recommended for production). The NAT Gateway allows nodes to pull container images.
- The frontend service uses `type: LoadBalancer` which creates an AWS Network Load Balancer.
- The backend service uses `type: ClusterIP` for internal communication only.
- IAM roles follow least-privilege for EKS cluster and worker nodes.