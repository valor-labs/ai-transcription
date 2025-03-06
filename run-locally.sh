#!/bin/bash

# Default values
IMAGE_NAME="transcriptionai"
CONTAINER_NAME="my-container"
PORT_MAPPING="8080:8080"

# Parse command-line arguments
while getopts i:c:p: flag
do
    case "${flag}" in
        i) IMAGE_NAME=${OPTARG};;  # Custom image name
        c) CONTAINER_NAME=${OPTARG};;  # Custom container name
        p) PORT_MAPPING=${OPTARG};;  # Custom port mapping
    esac
done

echo "🚀 Rebuilding and rerunning Docker container..."
echo "🛠  Image Name: $IMAGE_NAME"
echo "📦 Container Name: $CONTAINER_NAME"
echo "🌐 Port Mapping: $PORT_MAPPING"


# Stop and remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "🛑 Stopping and removing existing container: $CONTAINER_NAME"
    docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME
else
    echo "ℹ️  No existing container found with name: $CONTAINER_NAME"
fi

# Rebuild the image
echo "🔨 Building Docker image..."
# docker build --no-cache -t $IMAGE_NAME .
docker build -t $IMAGE_NAME .


# Run the new container
echo "🚀 Running new container..."
docker run -d \
       -v ~/.config/gcloud:/root/.config/gcloud:ro \
       -p $PORT_MAPPING \
       --gpus all \
       --privileged --device /dev/fuse --cap-add SYS_ADMIN \
       --name $CONTAINER_NAME \
       $IMAGE_NAME


echo "✅ Container $CONTAINER_NAME is now running on port $PORT_MAPPING!"
