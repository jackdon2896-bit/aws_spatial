#!/bin/bash

# AWS HealthOmics ECR Setup Script
# This script helps you upload your container to ECR for use with HealthOmics

set -e

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-1"}
ECR_REPOSITORY_NAME=${ECR_REPOSITORY_NAME:-"aws-spatial-pipeline"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}

echo "🚀 Setting up AWS HealthOmics ECR Repository"
echo "Region: $AWS_REGION"
echo "Repository: $ECR_REPOSITORY_NAME"
echo "Tag: $IMAGE_TAG"

# Step 1: Create ECR repository if it doesn't exist
echo "📦 Creating ECR repository..."
aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $AWS_REGION 2>/dev/null || \
aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $AWS_REGION

# Step 2: Get ECR login token
echo "🔐 Getting ECR login token..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com

# Step 3: Build the Docker image
echo "🔨 Building Docker image..."
docker build -t $ECR_REPOSITORY_NAME:$IMAGE_TAG .

# Step 4: Tag the image for ECR
ECR_URI=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:$IMAGE_TAG
echo "🏷️  Tagging image as $ECR_URI"
docker tag $ECR_REPOSITORY_NAME:$IMAGE_TAG $ECR_URI

# Step 5: Push to ECR
echo "⬆️  Pushing image to ECR..."
docker push $ECR_URI

echo "✅ Container successfully uploaded to ECR!"
echo "📋 ECR URI: $ECR_URI"
echo ""
echo "🔧 Next steps:"
echo "1. Use this ECR URI in your HealthOmics workflow definition"
echo "2. Update your nextflow.config to use: container = '$ECR_URI'"
echo "3. Create your HealthOmics workflow using the AWS CLI or Console"