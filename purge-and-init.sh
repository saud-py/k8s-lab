#!/usr/bin/env bash
# ============================================================================
# Complete State Purge & Re-init Script for Terraform EKS Lab
# ============================================================================
# Purges corrupted Terraform state from S3 + DynamoDB, removes orphaned
# AWS resources (IAM roles, VPC, subnets, NAT, etc.), and re-initializes
# cleanly for a fresh start.
#
# Usage:
#   chmod +x purge-and-init.sh
#   ./purge-and-init.sh
#
# Prerequisites:
#   - AWS CLI configured with S3, DynamoDB, IAM, EC2 permissions
#   - Terraform installed
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION — EDIT THESE VALUES
# ============================================================================
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-saud-tf-state}"
TF_LOCK_TABLE="${TF_LOCK_TABLE:-terraform-lock}"
STATE_KEY_PREFIX="${STATE_KEY_PREFIX:-eks/saud-eks-lab}"
TF_CLUSTER_NAME="${TF_CLUSTER_NAME:-saud-eks-lab}"
STATE_KEY="${STATE_KEY_PREFIX}/terraform.tfstate"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ============================================================================
# STEP 1: Verify AWS connectivity
# ============================================================================
verify_aws() {
    log_info "=== Verifying AWS connectivity ==="
    aws sts get-caller-identity --region "$AWS_REGION" --query Account --output text >/dev/null 2>&1 || {
        log_error "AWS CLI not configured or no credentials"
        exit 1
    }
    log_info "AWS credentials verified"
}

# ============================================================================
# STEP 2: Delete S3 state file (purge corrupted state)
# ============================================================================
purge_s3_state() {
    log_info "=== Purging S3 state ==="
    if aws s3 ls "s3://${TF_STATE_BUCKET}/${STATE_KEY}" >/dev/null 2>&1; then
        log_warn "Deleting corrupted state: s3://${TF_STATE_BUCKET}/${STATE_KEY}"
        aws s3 rm "s3://${TF_STATE_BUCKET}/${STATE_KEY}"
        log_info "S3 state deleted"
    else
        log_info "No state file found in S3"
    fi
}

# ============================================================================
# STEP 3: Clear DynamoDB lock table entries
# ============================================================================
purge_dynamodb_locks() {
    log_info "=== Clearing DynamoDB lock entries ==="
    if aws dynamodb describe-table --table-name "$TF_LOCK_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
        aws dynamodb scan --table-name "$TF_LOCK_TABLE" --region "$AWS_REGION" \
            --query "Items[].LockID.S" --output text 2>/dev/null | while read LOCK_ID; do
            if [ -n "$LOCK_ID" ]; then
                log_warn "Deleting lock entry: $LOCK_ID"
                aws dynamodb delete-item \
                    --table-name "$TF_LOCK_TABLE" \
                    --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" \
                    --region "$AWS_REGION" >/dev/null 2>&1 || true
            fi
        done
        log_info "DynamoDB locks cleared"
    else
        log_info "DynamoDB table does not exist (will be created by setup-backend.sh)"
    fi
}

# ============================================================================
# STEP 4: Delete orphaned IAM roles
# ============================================================================
purge_iam_roles() {
    log_info "=== Purging orphaned IAM roles ==="

    for ROLE in "${TF_CLUSTER_NAME}-cluster-role" "${TF_CLUSTER_NAME}-node-role" \
                "${TF_CLUSTER_NAME}-alb-controller-role"; do
        if aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
            log_warn "Processing role: $ROLE"

            # Detach managed policies
            for ARN in $(aws iam list-attached-role-policies --role-name "$ROLE" \
                         --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
                if [ -n "$ARN" ]; then
                    log_warn "  Detaching: $ARN"
                    aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$ARN" 2>/dev/null || true
                fi
            done

            # Delete inline policies
            for P in $(aws iam list-role-policies --role-name "$ROLE" \
                       --query 'PolicyNames[]' --output text 2>/dev/null); do
                if [ -n "$P" ]; then
                    log_warn "  Deleting inline policy: $P"
                    aws iam delete-role-policy --role-name "$ROLE" --policy-name "$P" 2>/dev/null || true
                fi
            done

            # Delete the role
            aws iam delete-role --role-name "$ROLE" 2>/dev/null && log_info "  ✓ Role deleted: $ROLE" || \
                log_warn "  ⚠ Could not delete: $ROLE (may have dependencies)"
        else
            log_info "Role $ROLE does not exist — skipping"
        fi
    done
}

# ============================================================================
# STEP 5: Delete orphaned VPC resources
# ============================================================================
purge_vpc_resources() {
    log_info "=== Purging orphaned VPC resources ==="

    VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${TF_CLUSTER_NAME}-vpc" \
        --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")

    if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
        log_info "No VPC found with tag ${TF_CLUSTER_NAME}-vpc"
        return 0
    fi

    log_warn "Found VPC: $VPC_ID — deleting associated resources..."

    # NAT Gateway
    NAT_GW=$(aws ec2 describe-nat-gateways --region "$AWS_REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query "NatGateways[0].NatGatewayId" --output text 2>/dev/null || echo "")
    if [ -n "$NAT_GW" ] && [ "$NAT_GW" != "None" ]; then
        log_warn "Deleting NAT Gateway: $NAT_GW"
        aws ec2 delete-nat-gateway --region "$AWS_REGION" --nat-gateway-id "$NAT_GW" 2>/dev/null || true
    fi

    # Subnets
    SUBNETS=$(aws ec2 describe-subnets --region "$AWS_REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query "Subnets[*].SubnetId" --output text 2>/dev/null || echo "")
    for SUBNET in $SUBNETS; do
        log_warn "Deleting subnet: $SUBNET"
        aws ec2 delete-subnet --region "$AWS_REGION" --subnet-id "$SUBNET" 2>/dev/null || true
    done

    # Route tables (non-main)
    RTABLES=$(aws ec2 describe-route-tables --region "$AWS_REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query "RouteTables[?Associations[0].Main!\`true\`].RouteTableId" --output text 2>/dev/null || echo "")
    for RT in $RTABLES; do
        log_warn "Deleting route table: $RT"
        aws ec2 delete-route-table --region "$AWS_REGION" --route-table-id "$RT" 2>/dev/null || true
    done

    # Security groups
    SGS=$(aws ec2 describe-security-groups --region "$AWS_REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=${TF_CLUSTER_NAME}-*" \
        --query "SecurityGroups[*].GroupId" --output text 2>/dev/null || echo "")
    for SG in $SGS; do
        log_warn "Deleting security group: $SG"
        aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$SG" 2>/dev/null || true
    done

    # Internet Gateway
    IGW=$(aws ec2 describe-internet-gateways --region "$AWS_REGION" \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${TF_CLUSTER_NAME}-igw" \
        --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || echo "")
    if [ -n "$IGW" ] && [ "$IGW" != "None" ]; then
        aws ec2 detach-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$IGW" --vpc-id "$VPC_ID" 2>/dev/null
        aws ec2 delete-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$IGW" 2>/dev/null || true
    fi

    # VPC itself
    log_warn "Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --region "$AWS_REGION" --vpc-id "$VPC_ID" 2>/dev/null && log_info "✓ VPC deleted" || \
        log_warn "⚠ VPC delete failed — check for remaining dependencies"
}

# ============================================================================
# STEP 6: Clean local .terraform directory
# ============================================================================
purge_local_terraform() {
    log_info "=== Purging local .terraform directory ==="
    if [ -d .terraform ]; then
        rm -rf .terraform
        log_info "Local .terraform removed"
    fi
    if [ -f .terraform.lock.hcl ]; then
        rm -f .terraform.lock.hcl
        log_info "Local .terraform.lock.hcl removed"
    fi
}

# ============================================================================
# STEP 7: Re-initialize Terraform
# ============================================================================
reinit_terraform() {
    log_info "=== Re-initializing Terraform ==="
    terraform init || {
        log_error "terraform init failed — check backend.tf values"
        exit 1
    }
    log_info "Terraform initialized successfully"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    log_info "Starting purge-and-init for cluster: $TF_CLUSTER_NAME"
    log_info "Region: $AWS_REGION | Bucket: $TF_STATE_BUCKET | Table: $TF_LOCK_TABLE"
    log_info ""

    verify_aws
    purge_s3_state
    purge_dynamodb_locks
    purge_iam_roles
    purge_vpc_resources
    purge_local_terraform
    reinit_terraform

    log_info ""
    log_info "=== Purge-and-init Complete ==="
    log_info "Next steps:"
    log_info "  1. terraform plan -out=tfplan"
    log_info "  2. terraform apply -auto-approve tfplan"
    log_info "  3. kubectl get pods -n lab"
    log_info "  4. kubectl get hpa -n lab"
}

main "$@"