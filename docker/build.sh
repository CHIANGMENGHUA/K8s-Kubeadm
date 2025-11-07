#!/bin/bash

# Build script for batch-processing-demo Docker image

set -e

IMAGE_NAME="batch-processing-demo"
IMAGE_TAG="0.0.1-SNAPSHOT"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building Docker image: ${FULL_IMAGE_NAME}"

# Build the Docker image
sudo docker build -t "${FULL_IMAGE_NAME}" .

echo "✅ Docker image built successfully: ${FULL_IMAGE_NAME}"
echo ""
echo "To run the container:"
echo "  docker run -d -p 9191:9191 --name batch-processing-demo ${FULL_IMAGE_NAME}"
echo ""
echo "To view logs:"
echo "  docker logs -f batch-processing-demo"
echo ""
echo "To stop and remove:"
echo "  docker stop batch-processing-demo && docker rm batch-processing-demo"