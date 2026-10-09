# Terraform Remote State Backend Configuration
# =============================================
# BEFORE RUNNING TERRAFORM INIT:
#
# You MUST create the following first (outside Terraform):
#
# 1. S3 bucket for state storage:
#    aws s3api create-bucket --bucket YOUR-TFSTATE-BUCKET --region YOUR-REGION \
#      --create-bucket-configuration LocationConstraint=YOUR-REGION
#
#    Then enable versioning and encryption:
#    aws s3api put-bucket-versioning --bucket YOUR-TFSTATE-BUCKET \
#      --versioning-configuration Status=Enabled
#    aws s3api put-bucket-encryption --bucket YOUR-TFSTATE-BUCKET \
#      --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
# 2. DynamoDB table for state locking:
#    aws dynamodb create-table \
#      --table-name YOUR-LOCK-TABLE \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --billing-mode PAY_PER_REQUEST
#
# 3. Update the values below, then run:
#    terraform init

terraform {
  backend "s3" {
    # UPDATE THESE VALUES BEFORE RUNNING terraform init
    bucket         = "saud-tf-state" # e.g. "k8s-lab-tfstate"
    key            = "eks/low-cost-dev-cluster/terraform.tfstate"
    region         = "ap-southeast-2" # match your AWS region
    dynamodb_table = "terraform-lock" # e.g. "terraform-lock"
    encrypt        = true
  }
}

# ============================================================================
# IAM POLICY TO ATTACH TO CodeBuild SERVICE ROLE
# ============================================================================
# Create a JSON file with this policy and attach it to your CodeBuild service role:
#
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": [
#         "s3:GetObject",
#         "s3:PutObject",
#         "s3:DeleteObject",
#         "s3:ListBucket"
#       ],
#       "Resource": [
#         "arn:aws:s3:::YOUR-TFSTATE-BUCKET",
#         "arn:aws:s3:::YOUR-TFSTATE-BUCKET/*"
#       ]
#     },
#     {
#       "Effect": "Allow",
#       "Action": [
#         "dynamodb:GetItem",
#         "dynamodb:PutItem",
#         "dynamodb:DeleteItem",
#         "dynamodb:DescribeTable"
#       ],
#       "Resource": "arn:aws:dynamodb:YOUR-REGION:YOUR-ACCOUNT:table/YOUR-LOCK-TABLE"
#     }
#   ]
# }