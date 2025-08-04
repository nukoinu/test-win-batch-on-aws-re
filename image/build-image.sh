#!/bin/bash

# Windows Docker Image Build Script (for Linux/macOS hosts with Docker Desktop)
# Builds Windows Server 2022 based countdown test image

set -e

echo "=========================================="
echo "Windows Countdown Test Image Builder"
echo "=========================================="

# Configuration
IMAGE_NAME="countdown-test-windows"
IMAGE_TAG="latest"
DOCKERFILE="Dockerfile"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    echo "Please install Docker Desktop"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    echo "Please start Docker Desktop"
    exit 1
fi

# Note: Windows containers require Docker Desktop on Windows
echo "Note: Building Windows containers requires Docker Desktop running on Windows"
echo "If you're on Linux/macOS, you'll need to use a Windows Docker host"

# Check if countdown.exe exists in execution directory
if [ ! -f "../execution/countdown.exe" ]; then
    echo "countdown.exe not found in execution directory"
    echo "Building from source using cross-compilation..."
    pushd ../execution
    ./build.sh
    if [ $? -ne 0 ]; then
        echo "Error: Failed to build countdown.exe"
        popd
        exit 1
    fi
    popd
fi

# Copy required files to current directory for Docker build context
echo "Copying files for Docker build context..."
cp "../execution/countdown.exe" .
cp "../execution/countdown.cpp" .

echo "Building Docker image..."
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo "Dockerfile: $DOCKERFILE"
echo

# Build the Docker image
docker build -f "$DOCKERFILE" -t "$IMAGE_NAME:$IMAGE_TAG" .

# Clean up copied files
cleanup() {
    rm -f countdown.exe countdown.cpp
}
trap cleanup EXIT

echo
echo "=========================================="
echo "Build completed successfully!"
echo "=========================================="
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo
echo "To test the image (requires Windows Docker host):"
echo "  docker run --rm $IMAGE_NAME:$IMAGE_TAG powershell -File C:\\app\\run.ps1 10"
echo
echo "To run interactively:"
echo "  docker run -it --rm $IMAGE_NAME:$IMAGE_TAG powershell"
echo
echo "To push to ECR:"
echo "  ./push-to-ecr.sh <aws-account-id> [region] [repository-name]"
echo "=========================================="
