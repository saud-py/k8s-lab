#!/usr/bin/env bash
# ============================================================================
# IAM Cleanup Script for Terraform EKS Lab
# ============================================================================
# Deletes IAM roles and policies associated with the EKS cluster
# that are preventing clean Terraform runs due to "EntityAlreadyExists"
#
# Usage:
#   chmod +x cleanup-iam.sh
#   ./cleanup-iam.sh
#
# Prerequisites:
#   - AWS CLI configured with IAM permissions
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION — EDIT THESE VALUES
# ============================================================================
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
CLUSTER_NAME="${CLUSTER_NAME:-low-cost-dev-cluster}"

echo "============================================================"
echo "  IAM Cleanup Script for Terraform EKS Lab"
echo "============================================================"
echo "Region:        $AWS_REGION"
echo "Cluster name:  $CLUSTER_NAME"
echo "============================================================"
echo ""

# ============================================================================
# STEP 1: List and delete IAM roles with cluster name prefix
# ============================================================================
echo "[INFO] Finding and deleting IAM roles with prefix: $CLUSTER_NAME-*"
ROLES=$(aws iam list-roles --region "$AWS_REGION" \
    --query "Roles[?starts_with(RoleName, '\`$CLUSTER_NAME\`-')].RoleName" \
    --output text 2>/dev/null || echo "")

if [ -z "$ROLES" ]; then
    echo "[INFO] No IAM roles found with prefix $CLUSTER_NAME-*"
else
    echo "[INFO] Found roles: $ROLES"
    for ROLE in $ROLES; do
        echo "[WARN] Processing role: $ROLE"

        # Detach managed policies
        POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE" \
            --region "$AWS_REGION" \
            --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
        for POLICY in $POLICIES; do
            if [ -n "$POLICY" ]; then
                echo "    Detaching: $POLICY"
                aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$POLICY" \
                    --region "$AWS_REGION" 2>/dev/null || true
            fi
        done

        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies --role-name "$ROLE" \
            --region "$AWS_REGION" \
            --query 'PolicyNames[]' --output text 2>/dev/null || echo "")
        for POLICY in $INLINE_POLICIES; do
            if [ -n "$POLICY" ]; then
                echo "    Deleting inline policy: $POLICY"
                aws iam delete-role-policy --role-name "$ROLE" --policy-name "$POLICY" \
                    --region "$AWS_REGION" 2>/dev/null || true
            fi
        done

        # Delete the role itself
        echo "    Deleting role: $ROLE"
        aws iam delete-role --role-name "$ROLE" --region "$AWS_REGION" 2>/dev/null && \
            echo "    ✓ Role deleted: $ROLE" || \
            echo "    ✗ Failed to delete role: $ROLE (may have dependencies)"
    done
fi

# ============================================================================
# STEP 2: List and delete IAM instance profiles with cluster name prefix
# ============================================================================
echo ""
echo "[INFO] Finding and deleting IAM instance profiles with prefix: $CLUSTER_NAME-*"
PROFILES=$(aws iam list-instance-profiles --region "$AWS_REGION" \
    --query "InstanceProfiles[?starts_with(InstanceProfileName, '\`$CLUSTER_NAME\`-')].InstanceProfileName" \
    --output text 2>/dev/null || echo "")

if [ -z "$PROFILES" ]; then
    echo "[INFO] No IAM instance profiles found with prefix $CLUSTER_NAME-*"
else
    echo "[INFO] Found profiles: $PROFILES"
    for PROFILE in $PROFILES; do
        echo "[WARN] Processing instance profile: $PROFILE"
        # First remove any roles from the profile (required before deletion)
        ROLES_IN_PROFILE=$(aws iam get-instance-profile --instance-profile-name "$PROFILE" \
            --region "$AWS_REGION" \
            --query 'InstanceProfile.Roles[].RoleName' --output text 2>/dev/null || echo "")
        for ROLE in $ROLES_IN_PROFILE; do
            if [ -n "$ROLE" ]; then
                echo "    Removing role $ROLE from profile $PROFILE"
                aws iam remove-role-from-instance-profile --instance-profile-name "$PROFILE" \
                    --role-name "$ROLE" --region "$AWS_REGION" 2>/dev/null || true
            fi
        done

        # Now delete the profile
        echo "    Deleting instance profile: $PROFILE"
        aws iam delete-instance-profile --instance-profile-name "$PROFILE" \
            --region "$AWS_REGION" 2>/dev/null && \
            echo "    ✓ Instance profile deleted: $PROFILE" || \
            echo "    ✗ Failed to delete instance profile: $PROFILE"
    done
fi

# ============================================================================
# STEP 3: List and delete IAM policies with cluster name prefix
# ============================================================================
echo ""
echo "[INFO] Finding and deleting IAM policies with prefix: $CLUSTER_NAME-*"
POLICIES=$(aws iam list-policies --region "$AWS_REGION" \
    --scope Local \
    --query "Policies[?starts_with(PolicyName, '\`$CLUSTER_NAME\`-')].PolicyName" \
    --output text 2>/dev/null || echo "")

if [ -z "$POLICIES" ]; then
    echo "[INFO] No IAM policies found with prefix $CLUSTER_NAME-*"
else
    echo "[INFO] Found policies: $POLICIES"
    for POLICY in $POLICIES; do
        echo "[WARN] Processing policy: $POLICY"
        # First detach from any roles/users/groups (attempt)
        echo "    Attempting to detach policy from entities..."
        aws iam list-entities-for-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY" \
            --region "$AWS_REGION" \
            --query 'PolicyRoles[].RoleName' --output text 2>/dev/null | while read ROLE; do
            if [ -n "$ROLE" ]; then
                echo "      Detaching from role: $ROLE"
                aws iam detach-role-policy --role-name "$ROLE" --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY" \
                    --region "$AWS_REGION" 2>/dev/null || true
            fi
        done
        aws iam list-entities-for-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY" \
            --region "$AWS_REGION" \
            --query 'PolicyUsers[].UserName' --output text 2>/dev/null | while read USER; do
            if [ -n "$USER" ]; then
                echo "      Detaching from user: $USER"
                aws iam detach-user-policy --user-name "$USER" --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY" \
                    --region "$AWS_REGION" 2>/dev/null || true
            fi
        done

        # Now delete the policy
        echo "    Deleting policy: $POLICY"
        aws iam delete-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY" \
            --region "$AWS_REGION" 2>/dev/null && \
            echo "    ✓ Policy deleted: $POLICY" || \
            echo "    ✗ Failed to delete policy: $POLICY"
    done
fi

echo ""
echo "[INFO] IAM cleanup completed."
echo "You may now re-run the Terraform workflow from scratch."