#!/usr/bin/env bash
# Comprehensive AWS Cleanup Script for Terraform EKS Lab
# Run this to clean up orphaned resources from failed Terraform runs
#
# Prerequisites: AWS CLI configured with appropriate permissions
# Usage: chmod +x cleanup.sh && ./cleanup.sh

set -euo pipefail

# ============================================================================
# CONFIGURATION — UPDATE THESE TO MATCH YOUR SETUP
# ============================================================================
TF_STATE_BUCKET="saud-tf-state"          # Your S3 bucket name
TF_STATE_REGION="ap-southeast-2"         # Your AWS region
TF_LOCK_TABLE="terraform-lock"           # Your DynamoDB table name
TF_CLUSTER_NAME="low-cost-dev-cluster"   # Your EKS cluster name
TF_STATE_KEY="eks/low-cost-dev-cluster/terraform.tfstate"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ============================================================================
# STEP 1: Check Current VPC Count
# ============================================================================
check_vpcs() {
    log_info "=== Checking VPC count ==="
    VPC_COUNT=$(aws ec2 describe-vpcs --region "$TF_STATE_REGION" --query 'Vpcs | length(@)' --output text)
    log_info "Current VPCs in $TF_STATE_REGION: $VPC_COUNT"

    if [ "$VPC_COUNT" -ge 5 ]; then
        log_warn "VPC limit (5) reached or exceeded. Cleanup needed."
        log_info "Listing all VPCs:"
        aws ec2 describe-vpcs --region "$TF_STATE_REGION" \
            --query 'Vpcs[].{Name:Tags[?Key==`Name`].Value|[0], VpcId:VpcId, IsDefault:IsDefault}' \
            --output table
        return 1
    else
        log_info "VPC count OK ($VPC_COUNT/5)"
        return 0
    fi
}

# ============================================================================
# STEP 2: Delete Orphaned IAM Roles
# ============================================================================
cleanup_iam_roles() {
    log_info "=== Cleaning up orphaned IAM roles ==="

    for ROLE in "${TF_CLUSTER_NAME}-cluster-role" "${TF_CLUSTER_NAME}-node-role"; do
        log_info "Processing role: $ROLE"

        # Check if role exists
        if ! aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
            log_info "  Role $ROLE does not exist, skipping"
            continue
        fi

        # Detach managed policies
        log_info "  Detaching managed policies..."
        for ARN in $(aws iam list-attached-role-policies --role-name "$ROLE" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
            if [ -n "$ARN" ]; then
                log_info "    Detaching: $ARN"
                aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$ARN" 2>/dev/null && log_info "    ✓ Detached" || log_warn "    ⚠ Could not detach"
            fi
        done

        # Delete inline policies
        log_info "  Deleting inline policies..."
        for P in $(aws iam list-role-policies --role-name "$ROLE" --query 'PolicyNames[]' --output text 2>/dev/null); do
            if [ -n "$P" ]; then
                log_info "    Deleting: $P"
                aws iam delete-role-policy --role-name "$ROLE" --policy-name "$P" 2>/dev/null && log_info "    ✓ Deleted" || log_warn "    ⚠ Could not delete"
            fi
        done

        # Delete the role
        log_info "  Deleting role: $ROLE"
        aws iam delete-role --role-name "$ROLE" 2>/dev/null && log_info "  ✓ Role deleted" || log_warn "  ⚠ Could not delete (may have dependencies)"
    done
}

# ============================================================================
# STEP 3: Delete Orphaned VPC Resources
# ============================================================================
cleanup_vpc_resources() {
    log_info "=== Finding and cleaning orphaned VPC resources ==="

    # Find VPC by our naming pattern
    VPC_ID=$(aws ec2 describe-vpcs --region "$TF_STATE_REGION" \
        --filters "Name=tag:Name,Values=${TF_CLUSTER_NAME}-vpc" \
        --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")

    if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
        log_info "No VPC found with tag Name=${TF_CLUSTER_NAME}-vpc"
        return 0
    fi

    log_info "Found VPC to clean: $VPC_ID"

    # 1. Delete NAT Gateway
    NAT_GW=$(aws ec2 describe-nat-gateways --region "$TF_STATE_REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${TF_CLUSTER_NAME}-nat" \
        --query "NatGateways[0].NatGatewayId" --output text 2>/dev/null || echo "")

    if [ -n "$NAT_GW" ] && [ "$NAT_GW" != "None" ]; then
        log_info "Deleting NAT Gateway: $NAT_GW"
        aws ec2 delete-nat-gateway --region "$TF_STATE_REGION" --nat-gateway-id "$NAT_GW" 2>/dev/null || true
        # Wait for deletion
        log_info "  Waiting for NAT Gateway deletion..."
        aws ec2 wait nat-gateway-deleted --region "$TF_STATE_REGION" --nat-gateway-ids "$NAT_GW" 2>/dev/null || true
        log_info "  ✓ NAT Gateway deleted"
    fi

    # 2. Release EIP (if any)
    EIP_ALLOC=$(aws ec2 describe-addresses --region "$TF_STATE_REGION" \
        --filters "Name=tag:Name,Values=${TF_CLUSTER_NAME}-nat-eip" \
        --query "Addresses[0].AllocationId" --output text 2>/dev/null || echo "")

    if [ -n "$EIP_ALLOC" ] && [ "$EIP_ALLOC" != "None" ]; then
        log_info "Releasing Elastic IP: $EIP_ALLOC"
        aws ec2 release-address --region "$TF_STATE_REGION" --allocation-id "$EIP_ALLOC" 2>/dev/null && log_info "  ✓ Released" || log_warn "  ⚠ Could not release"
    fi

    # 3. Delete subnets
    SUBNETS=$(aws ec2 describe-subnets --region "$TF_STATE_REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query "Subnets[*].SubnetId" --output text 2>/dev/null || echo "")

    for SUBNET in $SUBNETS; do
        log_info "Deleting subnet: $SUBNET"
        aws ec2 delete-subnet --region "$TF_STATE_REGION" --subnet-id "$SUBNET" 2>/dev/null && log_info "  ✓ Deleted" || log_warn "  ⚠ Could not delete"
    done

    # 4. Delete route tables (except main)
    RTABLES=$(aws ec2 describe-route-tables --region "$TF_STATE_REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text 2>/dev/null || echo "")

    for RT in $RTABLES; do
        log_info "Deleting route table: $RT"
        aws ec2 delete-route-table --region "$TF_STATE_REGION" --route-table-id "$RT" 2>/dev/null && log_info "  ✓ Deleted" || log_warn "  ⚠ Could not delete"
    done

    # 5. Delete security groups (except default)
    SGS=$(aws ec2 describe-security-groups --region "$TF_STATE_REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=${TF_CLUSTER_NAME}-*" \
        --query "SecurityGroups[*].GroupId" --output text 2>/dev/null || echo "")

    for SG in $SGS; do
        log_info "Deleting security group: $SG"
        aws ec2 delete-security-group --region "$TF_STATE_REGION" --group-id "$SG" 2>/dev/null && log_info "  ✓ Deleted" || log_warn "  ⚠ Could not delete"
    done

    # 6. Detach and delete Internet Gateway
    IGW=$(aws ec2 describe-internet-gateways --region "$TF_STATE_REGION" \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${TF_CLUSTER_NAME}-igw" \
        --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || echo "")

    if [ -n "$IGW" ] && [ "$IGW" != "None" ]; then
        log_info "Detaching and deleting Internet Gateway: $IGW"
        aws ec2 detach-internet-gateway --region "$TF_STATE_REGION" --internet-gateway-id "$IGW" --vpc-id "$VPC_ID" 2>/dev/null
        aws ec2 delete-internet-gateway --region "$TF_STATE_REGION" --internet-gateway-id "$IGW" 2>/dev/null && log_info "  ✓ Deleted" || log_warn "  ⚠ Could not delete"
    fi

    # 7. Delete VPC
    log_info "Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --region "$TF_STATE_REGION" --vpc-id "$VPC_ID" 2>/dev/null && log_info "  ✓ VPC Deleted" || log_error "  ✗ VPC delete failed (check for remaining dependencies)"
}

# ============================================================================
# STEP 4: Clean Terraform State from S3
# ============================================================================
cleanup_terraform_state() {
    log_info "=== Cleaning Terraform state from S3 ==="

    # Check if state exists
    if aws s3 ls "s3://${TF_STATE_BUCKET}/${TF_STATE_KEY}" >/dev/null 2>&1; then
        log_warn "Found existing Terraform state at s3://${TF_STATE_BUCKET}/${TF_STATE_KEY}"
        log_warn "This state may be corrupted from failed applies. Deleting..."
        aws s3 rm "s3://${TF_STATE_BUCKET}/${TF_STATE_KEY}"
        log_info "  ✓ State deleted"
    else
        log_info "No existing state found"
    fi

    # Also clean lock table
    log_info "Checking DynamoDB lock table..."
    if aws dynamodb describe-table --table-name "$TF_LOCK_TABLE" --region "$TF_STATE_REGION" >/dev/null 2>&1; then
        log_info "Deleting lock entries..."
        aws dynamodb scan --table-name "$TF_LOCK_TABLE" --region "$TF_STATE_REGION" \
            --query "Items[].LockID" --output text | while read LOCK_ID; do
            if [ -n "$LOCK_ID" ]; then
                aws dynamodb delete-item --table-name "$TF_LOCK_TABLE" \
                    --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" --region "$TF_STATE_REGION" 2>/dev/null || true
            fi
        done
        log_info "  ✓ Lock entries cleared"
    fi
}

# ============================================================================
# STEP 5: Verify Cleanup
# ============================================================================
verify_cleanup() {
    log_info "=== Verification ==="

    # Check VPCs
    check_vpcs

    # Check IAM roles
    for ROLE in "${TF_CLUSTER_NAME}-cluster-role" "${TF_CLUSTER_NAME}-node-role"; do
        if aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
            log_warn "Role $ROLE still exists"
        else
            log_info "Role $ROLE cleaned up"
        fi
    done

    # Check state
    if aws s3 ls "s3://${TF_STATE_BUCKET}/${TF_STATE_KEY}" >/dev/null 2>&1; then
        log_warn "State still exists in S3"
    else
        log_info "S3 state cleaned"
    fi
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    log_info "Starting cleanup for cluster: $TF_CLUSTER_NAME"
    log_info "Region: $TF_STATE_REGION"
    log_info "State bucket: $TF_STATE_BUCKET"
    log_info ""

    # Run cleanup steps
    cleanup_iam_roles
    cleanup_vpc_resources
    cleanup_terraform_state
    verify_cleanup

    log_info ""
    log_info "=== Cleanup Complete ==="
    log_info "Next steps:"
    log_info "  1. Run 'terraform init' to re-initialize with clean state"
    log_info "  2. Run 'terraform plan' to generate fresh plan"
    log_info "  3. Run 'terraform apply' to create resources"
    log_info "  4. Commit and push changes to trigger pipeline"
}

# Run main
main "$@"