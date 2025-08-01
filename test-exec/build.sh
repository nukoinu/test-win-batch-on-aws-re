#!/bin/bash

echo "Building countdown.exe using Docker on macOS/Linux..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH."
    echo "Please install Docker from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

echo ""
echo "Building Docker image with cross-compilation tools..."
docker build -f Dockerfile.build -t countdown-builder .

if [ $? -ne 0 ]; then
    echo ""
    echo "Docker build failed! Please check the error messages above."
    exit 1
fi

echo ""
echo "Extracting countdown.exe from Docker container..."

# Create a temporary container to extract the executable
docker create --name temp-countdown countdown-builder
docker cp temp-countdown:/build/countdown.exe .
docker rm temp-countdown

if [ -f "countdown.exe" ]; then
    echo ""
    echo "Build successful! countdown.exe extracted from Docker container."
    echo ""
    echo "The executable was built using cross-compilation and should work on Windows."
    echo ""
    echo "Usage examples:"
    echo "  countdown.exe 10    (10 second countdown with 1-second intervals)"
    echo "  countdown.exe 300   (300 second countdown with 30-second intervals)"
    echo ""
    echo "File info:"
    ls -la countdown.exe
    file countdown.exe
else
    echo ""
    echo "Failed to extract countdown.exe from Docker container."
    exit 1
fi

echo ""
echo "Docker build and extraction completed successfully!"
