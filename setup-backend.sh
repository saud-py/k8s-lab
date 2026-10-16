#!/usr/bin/env bash
# ============================================================================
# AWS Resources Setup Script for Terraform Backend
# ============================================================================
# Creates S3 bucket (state storage) + DynamoDB table (state locking)
# Required before running `terraform init` with the remote backend config
#
# Usage:
#   chmod +x setup-backend.sh
#   ./setup-backend.sh
#
# Prerequisites:
#   - AWS CLI installed and configured
#   - AWS credentials with S3/DynamoDB/IAM permissions
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION — EDIT THESE VALUES
# ============================================================================
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-saud-tf-state}"
TF_LOCK_TABLE="${TF_LOCK_TABLE:-terraform-lock}"
STATE_KEY_PREFIX="${STATE_KEY_PREFIX:-eks/low-cost-dev-cluster}"

echo "============================================================"
echo "  AWS Backend Resources Setup"
echo "============================================================"
echo "Region:        $AWS_REGION"
echo "S3 Bucket:     $TF_STATE_BUCKET"
echo "DynamoDB:      $TF_LOCK_TABLE"
echo "State Key:     $STATE_KEY_PREFIX/terraform.tfstate"
echo "============================================================"
echo ""

# ============================================================================
# STEP 1: Create S3 Bucket for Terraform State
# ============================================================================
echo ">>> Step 1: Creating S3 bucket..."

# Check if bucket already exists
if aws s3api head-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
    echo "   [SKIP] Bucket '$TF_STATE_BUCKET' already exists"
else
    # Create bucket (us-east-1 doesn't need LocationConstraint)
    if [ "$AWS_REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION"
    else
        aws s3api create-bucket \
            --bucket "$TF_STATE_BUCKET" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    echo "   [DONE] Bucket '$TF_STATE_BUCKET' created"
fi

# Enable versioning (critical for state recovery)
aws s3api put-bucket-versioning \
    --bucket "$TF_STATE_BUCKET" \
    --versioning-configuration Status=Enabled
echo "   [DONE] Versioning enabled"

# Enable server-side encryption (AES-256)
aws s3api put-bucket-encryption \
    --bucket "$TF_STATE_BUCKET" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
echo "   [DONE] Encryption enabled (AES-256)"

echo ""

# ============================================================================
# STEP 2: Create DynamoDB Table for State Locking
# ============================================================================
echo ">>> Step 2: Creating DynamoDB lock table..."

if aws dynamodb describe-table --table-name "$TF_LOCK_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "   [SKIP] Table '$TF_LOCK_TABLE' already exists"
else
    aws dynamodb create-table \
        --table-name "$TF_LOCK_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION"

    # Wait for table to become ACTIVE
    echo "   Waiting for table to become ACTIVE..."
    aws dynamodb wait table-exists --table-name "$TF_LOCK_TABLE" --region "$AWS_REGION"
    echo "   [DONE] Table '$TF_LOCK_TABLE' created (PAY_PER_REQUEST billing)"
fi

echo ""

# ============================================================================
# STEP 3: Verify Resources
# ============================================================================
echo ">>> Step 3: Verifying resources..."

echo "S3 Bucket:"
aws s3api get-bucket-versioning --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION"
aws s3api get-bucket-encryption --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text

echo ""
echo "DynamoDB Table Status:"
aws dynamodb describe-table --table-name "$TF_LOCK_TABLE" --region "$AWS_REGION" --query 'Table.TableStatus' --output text

echo ""

# ============================================================================
# STEP 4: Create IAM Policy for CodeBuild Service Role
# ============================================================================
echo ">>> Step 4: IAM Policy for CodeBuild Service Role..."
cat > /tmp/codebuild-tf-backend-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${TF_STATE_BUCKET}",
        "arn:aws:s3:::${TF_STATE_BUCKET}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):table/${TF_LOCK_TABLE}"
    }
  ]
}
EOF

echo "   Policy saved to: /tmp/codebuild-tf-backend-policy.json"
echo ""
echo "   To attach this policy to your CodeBuild service role:"
echo "   aws iam put-role-policy \\"
echo "     --role-name <your-codebuild-role-name> \\"
echo "     --policy-name TerraformBackendAccess \\"
echo "     --policy-document file:///tmp/codebuild-tf-backend-policy.json"

echo ""
echo "============================================================"
echo "  NEXT STEPS — Update backend.tf"
echo "============================================================"
echo ""
echo "1. Edit backend.tf with your real values:"
echo "   bucket         = \"$TF_STATE_BUCKET\""
echo "   dynamodb_table = \"$TF_LOCK_TABLE\""
echo "   region         = \"$AWS_REGION\""
echo ""
echo "2. Run: terraform init"
echo ""
echo "3. Run: terraform plan"
echo ""
echo "============================================================"