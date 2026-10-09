#!/usr/bin/env bash
# Cleanup script for AWS resources created by failed Terraform runs
# Run this AFTER setting up the remote backend (S3 bucket + DynamoDB table)
# or before the first run to remove orphaned resources.

set -euo pipefail

# ============================================================================
# CONFIGURATION — UPDATE THESE
# ============================================================================
TF_STATE_BUCKET=""           # e.g. "my-tfstate-bucket" — must exist already
TF_STATE_REGION="ap-southeast-2"  # your AWS region
TF_LOCK_TABLE=""             # e.g. "tf-lock-table" — must exist already
TF_CLUSTER_NAME="low-cost-dev-cluster"  # your EKS cluster name

# ============================================================================
# CLEANUP: IAM Roles & Policies (simplest first step)
# ============================================================================
echo "=== Cleaning up IAM roles ==="
for ROLE in "${TF_CLUSTER_NAME}-cluster-role" "${TF_CLUSTER_NAME}-node-role"; do
  echo "Processing role: $ROLE"

  # Detach managed policies
  for ARN in $(aws iam list-attached-role-policies --role-name "$ROLE" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
    if [ -n "$ARN" ]; then
      echo "  Detaching: $ARN"
      aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$ARN" 2>/dev/null || echo "  Warning: Could not detach $ARN"
    fi
  done

  # Delete inline policies
  for P in $(aws iam list-role-policies --role-name "$ROLE" --query 'PolicyNames[]' --output text 2>/dev/null); do
    if [ -n "$P" ]; then
      echo "  Deleting inline policy: $P"
      aws iam delete-role-policy --role-name "$ROLE" --policy-name "$P" 2>/dev/null || echo "  Warning: Could not delete $P"
    fi
  done

  # Delete the role itself
  echo "  Deleting role: $ROLE"
  aws iam delete-role --role-name "$ROLE" 2>/dev/null && echo "  ✓ Deleted" || echo "  ✗ Failed to delete (may have dependencies)"
done

echo "=== IAM cleanup complete ==="

# ============================================================================
# CLEANUP: VPC, Subnets, NAT Gateway (resources from failed apply)
# ============================================================================
echo ""
echo "=== Checking for orphaned VPC resources ==="

# Find VPC by name tag (our cluster name tag)
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${TF_CLUSTER_NAME}-vpc" "Name=is-default,Values=false" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  echo "Found VPC: $VPC_ID"

  # Find subnets in this VPC
  SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[*].SubnetId" --output text 2>/dev/null || echo "")

  echo "Subnets in VPC: $SUBNETS"

  # Delete subnets (they must be empty first, but our resources should be gone)
  for SUBNET in $SUBNETS; do
    echo "  Deleting subnet: $SUBNET"
    aws ec2 delete-subnet --subnet-id "$SUBNET" 2>/dev/null && echo "  ✓ Deleted" || echo "  ⚠ Subnet may have dependencies"
  done

  # Delete route tables (except the default one)
  ROUTE_TABLES=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${TF_CLUSTER_NAME}-*" \
    --query "RouteTables[*].RouteTableId" --output text 2>/dev/null || echo "")

  for RT in $ROUTE_TABLES; do
    echo "  Deleting route table: $RT"
    aws ec2 delete-route-table --route-table-id "$RT" 2>/dev/null && echo "  ✓ Deleted" || echo "  ⚠ Route table may have dependencies"
  done

  # Delete NAT Gateway (if exists)
  NAT_GW=$(aws ec2 describe-nat-gateways \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${TF_CLUSTER_NAME}-nat" \
    --query "NatGateways[0].NatGatewayId" --output text 2>/dev/null || echo "")

  if [ -n "$NAT_GW" ] && [ "$NAT_GW" != "None" ]; then
    echo "Deleting NAT Gateway: $NAT_GW"
    aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GW" 2>/dev/null && echo "  ✓ Deleted" || echo "  ⚠ NAT Gateway may have dependencies"
  fi

  # Delete Internet Gateway
  IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${TF_CLUSTER_NAME}-igw" \
    --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || echo "")

  if [ -n "$IGW" ] && [ "$IGW" != "None" ]; then
    echo "Deleting Internet Gateway: $IGW"
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC_ID" 2>/dev/null
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW" 2>/dev/null && echo "  ✓ Deleted" || echo "  ⚠ IGW may have dependencies"
  fi

  # Delete the VPC itself
  echo "Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null && echo "  ✓ VPC Deleted" || echo "  ✗ VPC delete failed (check for dependencies)"

else
  echo "No VPC found with name tag ${TF_CLUSTER_NAME}-vpc (may already be cleaned or never created)"
fi

echo ""
echo "=== Cleanup complete ==="
echo "Run 'terraform init' with your remote backend, then 'terraform plan' to generate a fresh plan."