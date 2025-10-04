#!/bin/bash

# AWS HealthOmics Workflow Creation Script
# This script creates a workflow in AWS HealthOmics

set -e

# Configuration
WORKFLOW_NAME=${WORKFLOW_NAME:-"aws-spatial-transcriptomics"}
WORKFLOW_DESCRIPTION=${WORKFLOW_DESCRIPTION:-"Spatial transcriptomics analysis pipeline with SRA download capability"}
S3_WORKFLOW_BUCKET=${S3_WORKFLOW_BUCKET:-"your-workflow-bucket"}
S3_WORKFLOW_PREFIX=${S3_WORKFLOW_PREFIX:-"aws-spatial-pipeline"}
AWS_REGION=${AWS_REGION:-"us-east-1"}
ROLE_ARN=${ROLE_ARN:-"arn:aws:iam::ACCOUNT_ID:role/HealthOmicsWorkflowRole"}

echo "🚀 Creating AWS HealthOmics Workflow"
echo "Name: $WORKFLOW_NAME"
echo "Region: $AWS_REGION"
echo "S3 Bucket: s3://$S3_WORKFLOW_BUCKET/$S3_WORKFLOW_PREFIX"

# Step 1: Create workflow bundle
echo "📦 Creating workflow bundle..."
cd ..
zip -r workflow.zip . -x "*.git*" "*.DS_Store*" "work/*" "results/*" "*.log"

# Step 2: Upload workflow to S3
echo "⬆️  Uploading workflow to S3..."
aws s3 cp workflow.zip s3://$S3_WORKFLOW_BUCKET/$S3_WORKFLOW_PREFIX/workflow.zip
aws s3 cp main.nf s3://$S3_WORKFLOW_BUCKET/$S3_WORKFLOW_PREFIX/main.nf
aws s3 cp nextflow-healthomics.config s3://$S3_WORKFLOW_BUCKET/$S3_WORKFLOW_PREFIX/nextflow.config

# Step 3: Create workflow in HealthOmics
echo "🔧 Creating HealthOmics workflow..."
WORKFLOW_ID=$(aws omics create-workflow \
    --name "$WORKFLOW_NAME" \
    --description "$WORKFLOW_DESCRIPTION" \
    --engine NEXTFLOW \
    --definition-zip s3://$S3_WORKFLOW_BUCKET/$S3_WORKFLOW_PREFIX/workflow.zip \
    --parameter-template file://healthomics/workflow-parameters.json \
    --storage-capacity 1200 \
    --accelerators GPU \
    --region $AWS_REGION \
    --query 'id' \
    --output text)

echo "✅ Workflow created successfully!"
echo "📋 Workflow ID: $WORKFLOW_ID"
echo "🔗 Workflow ARN: arn:aws:omics:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):workflow/$WORKFLOW_ID"

# Step 4: Update parameter templates with workflow ID
echo "📝 Updating parameter templates..."
cd healthomics
sed -i "s/WORKFLOW_ID_PLACEHOLDER/$WORKFLOW_ID/g" run-parameters-*.json
sed -i "s/ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)/g" run-parameters-*.json

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Update the ECR container URI in nextflow-healthomics.config"
echo "2. Update S3 bucket paths in run-parameters-*.json files"
echo "3. Create a run group (optional):"
echo "   aws omics create-run-group --name spatial-analysis-runs --max-cpus 100 --max-runs 10"
echo ""
echo "4. Start a run:"
echo "   aws omics start-run --cli-input-json file://run-parameters-sra.json"
echo ""
echo "🔧 Workflow ID for future reference: $WORKFLOW_ID"