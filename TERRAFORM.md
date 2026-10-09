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
- S3 bucket and DynamoDB table for Terraform state (see Remote Backend Setup below)

## Remote Backend Setup (REQUIRED for CI/CD)

**This must be done once before any Terraform operations.** The configuration uses an S3 backend with DynamoDB locking to persist state across CodeBuild runs.

### 1. Create S3 bucket and DynamoDB table

```bash
# Set your values
export TF_STATE_BUCKET="k8s-lab-tfstate-<your-account-id>"  # globally unique
export TF_LOCK_TABLE="terraform-lock"
export TF_REGION="ap-southeast-2"

# Create S3 bucket with versioning and encryption
aws s3api create-bucket \
  --bucket "$TF_STATE_BUCKET" \
  --region "$TF_REGION" \
  --create-bucket-configuration LocationConstraint="$TF_REGION"

aws s3api put-bucket-versioning \
  --bucket "$TF_STATE_BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$TF_STATE_BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB lock table (PAY_PER_REQUEST billing)
aws dynamodb create-table \
  --table-name "$TF_LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 2. Update `backend.tf` with your values

Edit `backend.tf` and replace the placeholders:
```hcl
bucket         = "k8s-lab-tfstate-<your-account-id>"
dynamodb_table = "terraform-lock"
region         = "ap-southeast-2"
```

### 3. Grant CodeBuild IAM permissions

Attach this policy to your CodeBuild service role:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::k8s-lab-tfstate-<your-account-id>",
        "arn:aws:s3:::k8s-lab-tfstate-<your-account-id>/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:DescribeTable"],
      "Resource": "arn:aws:dynamodb:ap-southeast-2:<your-account-id>:table/terraform-lock"
    }
  ]
}
```

---

## Quick Start

```bash
# Initialize Terraform (will prompt to migrate state if any local exists)
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