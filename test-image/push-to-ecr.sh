#!/bin/bash

# ECR Push Script for Windows Image
# Pushes Windows countdown test image to Amazon ECR

set -e

echo "=========================================="
echo "ECR Push Script - Windows Image"
echo "=========================================="

# Configuration - MODIFY THESE VALUES
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-123456789012}"
ECR_REPOSITORY="${ECR_REPOSITORY:-countdown-test-windows}"
LOCAL_IMAGE_NAME="countdown-test-windows"
LOCAL_IMAGE_TAG="latest"

# Parse command line arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <aws-account-id> [region] [repository-name]"
    echo
    echo "Example: $0 123456789012 us-east-1 countdown-test-windows"
    echo
    echo "Current configuration:"
    echo "  Account ID: $AWS_ACCOUNT_ID"
    echo "  Region: $AWS_REGION"
    echo "  Repository: $ECR_REPOSITORY"
    echo
    read -p "Continue with current configuration? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    AWS_ACCOUNT_ID="$1"
    [ $# -gt 1 ] && AWS_REGION="$2"
    [ $# -gt 2 ] && ECR_REPOSITORY="$3"
fi

ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE_NAME="${ECR_URI}/${ECR_REPOSITORY}:${LOCAL_IMAGE_TAG}"

echo "Configuration:"
echo "  AWS Account ID: $AWS_ACCOUNT_ID"
echo "  AWS Region: $AWS_REGION"
echo "  ECR Repository: $ECR_REPOSITORY"
echo "  Local Image: $LOCAL_IMAGE_NAME:$LOCAL_IMAGE_TAG"
echo "  Target ECR URI: $FULL_IMAGE_NAME"
echo

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed or not in PATH"
    echo "Please install AWS CLI v2 and configure credentials"
    exit 1
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check if local image exists
if ! docker image inspect "$LOCAL_IMAGE_NAME:$LOCAL_IMAGE_TAG" &> /dev/null; then
    echo "Error: Local image $LOCAL_IMAGE_NAME:$LOCAL_IMAGE_TAG not found"
    echo "Please build the image first using build-image.sh"
    exit 1
fi

echo "Step 1: Creating ECR repository if it doesn't exist..."
if ! aws ecr describe-repositories --repository-names "$ECR_REPOSITORY" --region "$AWS_REGION" &> /dev/null; then
    echo "Creating ECR repository: $ECR_REPOSITORY"
    aws ecr create-repository --repository-name "$ECR_REPOSITORY" --region "$AWS_REGION"
else
    echo "Repository $ECR_REPOSITORY already exists"
fi

echo
echo "Step 2: Getting ECR login token..."
ECR_TOKEN=$(aws ecr get-login-password --region "$AWS_REGION")
if [ -z "$ECR_TOKEN" ]; then
    echo "Error: Failed to get ECR login token"
    exit 1
fi

echo "Step 3: Logging into ECR..."
echo "$ECR_TOKEN" | docker login --username AWS --password-stdin "$ECR_URI"

echo
echo "Step 4: Tagging image for ECR..."
docker tag "$LOCAL_IMAGE_NAME:$LOCAL_IMAGE_TAG" "$FULL_IMAGE_NAME"

echo
echo "Step 5: Pushing image to ECR..."
echo "This may take several minutes for Windows images..."
docker push "$FULL_IMAGE_NAME"

echo
echo "=========================================="
echo "Push completed successfully!"
echo "=========================================="
echo "ECR Image URI: $FULL_IMAGE_NAME"
echo
echo "You can now use this image in:"
echo "  - AWS Batch job definitions"
echo "  - ECS task definitions"
echo "  - Other AWS services"
echo
echo "To pull the image:"
echo "  docker pull $FULL_IMAGE_NAME"
echo "=========================================="
