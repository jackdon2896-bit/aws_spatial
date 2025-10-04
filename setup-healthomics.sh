#!/bin/bash

# AWS HealthOmics Complete Setup Script
# This script automates the entire setup process for AWS HealthOmics

set -e

echo "🚀 AWS HealthOmics Complete Setup"
echo "=================================="

# Configuration
export AWS_REGION=${AWS_REGION:-"us-east-1"}
export ECR_REPOSITORY_NAME=${ECR_REPOSITORY_NAME:-"aws-spatial-pipeline"}
export S3_WORKFLOW_BUCKET=${S3_WORKFLOW_BUCKET:-"aws-spatial-workflow-$(date +%s)"}
export WORKFLOW_NAME=${WORKFLOW_NAME:-"aws-spatial-transcriptomics"}

echo "📋 Configuration:"
echo "  AWS Region: $AWS_REGION"
echo "  ECR Repository: $ECR_REPOSITORY_NAME"
echo "  S3 Workflow Bucket: $S3_WORKFLOW_BUCKET"
echo "  Workflow Name: $WORKFLOW_NAME"
echo ""

read -p "Continue with setup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
fi

# Step 1: Create S3 bucket for workflows
echo "📦 Step 1: Creating S3 bucket for workflows..."
aws s3 mb s3://$S3_WORKFLOW_BUCKET --region $AWS_REGION || echo "Bucket may already exist"

# Step 2: Set up ECR and build container
echo "🐳 Step 2: Setting up ECR and building container..."
./ecr-setup.sh

# Step 3: Create IAM role
echo "🔐 Step 3: Creating IAM role..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_NAME="HealthOmicsWorkflowRole"

# Create role if it doesn't exist
aws iam get-role --role-name $ROLE_NAME 2>/dev/null || \
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://healthomics/iam-role-policy.json

# Update and attach permissions policy
sed "s/your-data-bucket/your-data-bucket-$ACCOUNT_ID/g; s/your-results-bucket/your-results-bucket-$ACCOUNT_ID/g; s/your-workflow-bucket/$S3_WORKFLOW_BUCKET/g" \
    healthomics/iam-permissions-policy.json > /tmp/iam-permissions-policy.json

aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name HealthOmicsWorkflowPolicy \
    --policy-document file:///tmp/iam-permissions-policy.json

export ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
echo "✅ IAM Role created: $ROLE_ARN"

# Step 4: Create HealthOmics workflow
echo "🔧 Step 4: Creating HealthOmics workflow..."
cd healthomics
export S3_WORKFLOW_BUCKET
./create-workflow.sh

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "📋 Summary:"
echo "  ✅ ECR Repository: $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME"
echo "  ✅ S3 Workflow Bucket: s3://$S3_WORKFLOW_BUCKET"
echo "  ✅ IAM Role: $ROLE_ARN"
echo "  ✅ HealthOmics Workflow: Created (check output above for Workflow ID)"
echo ""
echo "🚀 Next Steps:"
echo "1. Update S3 bucket paths in healthomics/run-parameters-*.json"
echo "2. Upload your data to S3"
echo "3. Start a run:"
echo "   export WORKFLOW_ID='your-workflow-id'"
echo "   ./start-run.sh sra"
echo ""
echo "📖 For detailed instructions, see HEALTHOMICS_SETUP.md"