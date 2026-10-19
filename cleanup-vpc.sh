#!/usr/bin/env bash
# ============================================================================
# VPC Cleanup Script for Terraform EKS Lab
# ============================================================================
# Deletes all resources associated with a VPC identified by the tag
#   Name: <cluster_name>-vpc
# This includes:
#   - EKS cluster and node groups (if they exist and are in this VPC)
#   - ENIs (Elastic Network Interfaces)
#   - Load balancers (ALB/NLB)
#   - NAT Gateways
#   - Internet Gateways
#   - Security Groups (non-default)
#   - Subnets
#   - Route Tables (non-main)
#   - VPC itself
#
# Usage:
#   chmod +x cleanup-vpc.sh
#   ./cleanup-vpc.sh
#
# Prerequisites:
#   - AWS CLI configured with permissions for EKS, EC2, IAM, ELBv2
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION — EDIT THESE VALUES
# ============================================================================
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
CLUSTER_NAME="${CLUSTER_NAME:-saud-eks-lab}"
VPC_TAG_NAME="${CLUSTER_NAME}-vpc"

echo "============================================================"
echo "  VPC Cleanup Script"
echo "============================================================"
echo "Region:        $AWS_REGION"
echo "Cluster name:  $CLUSTER_NAME"
echo "VPC tag name:  $VPC_TAG_NAME"
echo "============================================================"
echo ""

# ============================================================================
# STEP 0: Verify AWS connectivity
# ============================================================================
aws sts get-caller-identity --region "$AWS_REGION" --query Account --output text >/dev/null 2>&1 || {
    echo "Error: AWS CLI not configured or no credentials"
    exit 1
}
echo "[INFO] AWS credentials verified"

# ============================================================================
# STEP 1: Find the VPC ID by tag
# ============================================================================
echo "[INFO] Finding VPC with tag Name=$VPC_TAG_NAME..."
VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=$VPC_TAG_NAME" "Name=is-default,Values=false" \
    --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "[WARN] No VPC found with tag Name=$VPC_TAG_NAME (is-default=false)."
    echo "[INFO] Checking for any VPC with this tag (including default)..."
    VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=$VPC_TAG_NAME" \
        --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
fi

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "[WARN] No VPC found with tag Name=$VPC_TAG_NAME. Nothing to clean."
    exit 0
fi

echo "[INFO] Found VPC ID: $VPC_ID"

# ============================================================================
# STEP 2: Delete EKS cluster and node groups (if any) in this VPC
# ============================================================================
echo "[INFO] Checking for EKS clusters in VPC $VPC_ID..."
EKS_CLUSTERS=$(aws eks list-clusters --region "$AWS_REGION" --query 'clusters[]' --output text 2>/dev/null || echo "")

for CLUSTER in $EKS_CLUSTERS; do
    # Describe the cluster to see which VPC it's in
    CLUSTER_INFO=$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
    if [ "$CLUSTER_INFO" = "$VPC_ID" ]; then
        echo "[WARN] Found EKS cluster $CLUSTER in VPC $VPC_ID — deleting node group(s) and cluster..."
        # Delete node groups first
        NODEGROUPS=$(aws eks list-nodegroups --region "$AWS_REGION" --cluster-name "$CLUSTER" --query 'nodegroups[]' --output text 2>/dev/null || echo "")
        for NG in $NODEGROUPS; do
            echo "  Deleting node group: $NG"
            aws eks delete-nodegroup --region "$AWS_REGION" --cluster-name "$CLUSTER" --nodegroup-name "$NG" --wait || true
        done
        # Delete the cluster
        echo "  Deleting EKS cluster: $CLUSTER"
        aws eks delete-cluster --region "$AWS_REGION" --name "$CLUSTER" --wait || true
    else
        echo "[INFO] EKS cluster $CLUSTER is in VPC $CLUSTER_INFO (not target VPC $VPC_ID) — skipping"
    fi
done

# ============================================================================
# STEP 3: Delete Elastic Network Interfaces (ENIs) in the VPC
# ============================================================================
echo "[INFO] Deleting ENIs in VPC $VPC_ID..."
ENIS=$(aws ec2 describe-network-interfaces --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[].NetworkInterfaceId' --output text 2>/dev/null || echo "")

for ENI in $ENIS; do
    echo "  Deleting ENI: $ENI"
    aws ec2 delete-network-interface --region "$AWS_REGION" --network-interface-id "$ENI" || true
done

# ============================================================================
# STEP 4: Delete Load Balancers (ALB/NLB) in the VPC
# ============================================================================
echo "[INFO] Deleting load balancers in VPC $VPC_ID..."
LBS=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
    --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null || echo "")

for LB in $LBS; do
    echo "  Deleting load balancer: $LB"
    aws elbv2 delete-load-balancer --region "$AWS_REGION" --load-balancer-arn "$LB" || true
done

# ============================================================================
# STEP 5: Delete NAT Gateways
# ============================================================================
echo "[INFO] Deleting NAT Gateways in VPC $VPC_ID..."
NATS=$(aws ec2 describe-nat-gateways --region "$AWS_REGION" \
    --filter "Name=vpc-id,Values=$VPC_ID" \
    --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null || echo "")

for NAT in $NATS; do
    echo "  Deleting NAT Gateway: $NAT"
    aws ec2 delete-nat-gateway --region "$AWS_REGION" --nat-gateway-id "$NAT" || true
done

# ============================================================================
# STEP 6: Delete Internet Gateways
# ============================================================================
echo "[INFO] Deleting Internet Gateways attached to VPC $VPC_ID..."
IGWS=$(aws ec2 describe-internet-gateways --region "$AWS_REGION" \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null || echo "")

for IGW in $IGWS; do
    echo "  Detaching and deleting Internet Gateway: $IGW"
    aws ec2 detach-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$IGW" --vpc-id "$VPC_ID" || true
    aws ec2 delete-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$IGW" || true
done

# ============================================================================
# STEP 7: Delete Security Groups (non-default)
# ============================================================================
echo "[INFO] Deleting non-default security groups in VPC $VPC_ID..."
SGS=$(aws ec2 describe-security-groups --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values!=default" \
    --query 'SecurityGroups[].GroupId' --output text 2>/dev/null || echo "")

for SG in $SGS; do
    echo "  Deleting security group: $SG"
    aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$SG" || true
done

# ============================================================================
# STEP 8: Delete Route Tables (non-main)
# ============================================================================
echo "[INFO] Deleting non-main route tables in VPC $VPC_ID..."
RTABLES=$(aws ec2 describe-route-tables --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[?Associations[0].Main!=\`true\`].RouteTableId' --output text 2>/dev/null || echo "")

for RT in $RTABLES; do
    echo "  Deleting route table: $RT"
    aws ec2 delete-route-table --region "$AWS_REGION" --route-table-id "$RT" || true
done

# ============================================================================
# STEP 9: Delete Subnets
# ============================================================================
echo "[INFO] Deleting subnets in VPC $VPC_ID..."
SUBNETS=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")

for SUBNET in $SUBNETS; do
    echo "  Deleting subnet: $SUBNET"
    aws ec2 delete-subnet --region "$AWS_REGION" --subnet-id "$SUBNET" || true
done

# ============================================================================
# STEP 10: Delete the VPC
# ============================================================================
echo "[INFO] Deleting VPC: $VPC_ID"
aws ec2 delete-vpc --region "$AWS_REGION" --vpc-id "$VPC_ID" && echo "[SUCCESS] VPC deleted" || echo "[ERROR] VPC delete failed — check for remaining dependencies"

echo ""
echo "[INFO] VPC cleanup script completed."
echo "You may now re-run the Terraform workflow from scratch."