#!/bin/bash

# AWS HealthOmics Run Starter Script
# This script starts a workflow run in AWS HealthOmics

set -e

# Configuration
RUN_TYPE=${1:-"sra"}  # sra or h5
WORKFLOW_ID=${WORKFLOW_ID:-""}
RUN_GROUP_ID=${RUN_GROUP_ID:-""}
AWS_REGION=${AWS_REGION:-"us-east-1"}

if [ -z "$WORKFLOW_ID" ]; then
    echo "❌ Error: WORKFLOW_ID environment variable is required"
    echo "Usage: WORKFLOW_ID=your-workflow-id ./start-run.sh [sra|h5]"
    exit 1
fi

echo "🚀 Starting AWS HealthOmics Run"
echo "Run Type: $RUN_TYPE"
echo "Workflow ID: $WORKFLOW_ID"
echo "Region: $AWS_REGION"

# Select parameter file based on run type
if [ "$RUN_TYPE" = "sra" ]; then
    PARAM_FILE="run-parameters-sra.json"
    echo "📊 Using SRA data source"
elif [ "$RUN_TYPE" = "h5" ]; then
    PARAM_FILE="run-parameters-h5.json"
    echo "📊 Using H5 data source"
else
    echo "❌ Error: Invalid run type. Use 'sra' or 'h5'"
    exit 1
fi

# Check if parameter file exists
if [ ! -f "$PARAM_FILE" ]; then
    echo "❌ Error: Parameter file $PARAM_FILE not found"
    exit 1
fi

# Start the run
echo "▶️  Starting workflow run..."
RUN_ID=$(aws omics start-run \
    --cli-input-json file://$PARAM_FILE \
    --region $AWS_REGION \
    --query 'id' \
    --output text)

echo "✅ Run started successfully!"
echo "📋 Run ID: $RUN_ID"
echo "🔗 Run ARN: arn:aws:omics:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):run/$RUN_ID"

echo ""
echo "📊 Monitor your run:"
echo "aws omics get-run --id $RUN_ID --region $AWS_REGION"
echo ""
echo "📋 List all runs:"
echo "aws omics list-runs --region $AWS_REGION"
echo ""
echo "🛑 Cancel run (if needed):"
echo "aws omics cancel-run --id $RUN_ID --region $AWS_REGION"