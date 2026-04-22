#!/bin/bash
# AWS HealthOmics Workflow Creation Script - GitHub Repository Version
set -e

# Configuration
WORKFLOW_NAME=${WORKFLOW_NAME:-"aws-spatial-transcriptomics"}
WORKFLOW_DESCRIPTION=${WORKFLOW_DESCRIPTION:-"Spatial transcriptomics analysis pipeline with SRA download capability"}
AWS_REGION=${AWS_REGION:-"us-east-1"}
CONNECTION_ARN=${CONNECTION_ARN:-"arn:aws:codeconnections:us-east-1:644685128986:connection/d51f7a58-0fed-485e-b976-f82c1ba0f290"}
REPOSITORY_ID=${REPOSITORY_ID:-"jackdon2896-bit/aws_spatial"}

echo "🚀 Creating AWS HealthOmics Workflow from GitHub Repository"
echo "Name: $WORKFLOW_NAME"
echo "Region: $AWS_REGION"
echo "Repository: $REPOSITORY_ID"

# Create workflow in HealthOmics using GitHub repository
WORKFLOW_ID=$(aws omics create-workflow \
    --name "$WORKFLOW_NAME" \
    --description "$WORKFLOW_DESCRIPTION" \
    --engine NEXTFLOW \
    --definition-repository "{
        \"connectionArn\": \"$CONNECTION_ARN\",
        \"fullRepositoryId\": \"$REPOSITORY_ID\",
        \"sourceReference\": {
            \"type\": \"BRANCH\",
            \"value\": \"main\"
        }
    }" \
    --main "main.nf" \
    --parameter-template-path "nextflow_schema.json" \
    --storage-type "DYNAMIC" \
    --region $AWS_REGION \
    --query 'id' \
    --output text)

echo "✅ Workflow created successfully!"
echo "📋 Workflow ID: $WORKFLOW_ID"
echo "🔗 Workflow ARN: arn:aws:omics:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):workflow/$WORKFLOW_ID"

# Step 4: Update parameter templates with workflow ID
echo "📝 Updating parameter templates..."
sed -i "s/WORKFLOW_ID_PLACEHOLDER/$WORKFLOW_ID/g" run-parameters-*.json
sed -i "s/ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)/g" run-parameters-*.json

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Start a run using the workflow ID: $WORKFLOW_ID"
echo "2. Use the parameter template from nextflow_schema.json"
echo ""
echo "🔧 Workflow ID for future reference: $WORKFLOW_ID"
