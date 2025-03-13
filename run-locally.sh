#!/bin/bash

set -e

# Default values
IMAGE_NAME="transcriptionai"
CONTAINER_NAME="my-container"
PORT="8080"
PORT_MAPPING="$PORT:$PORT"

# Parse command-line arguments
while getopts i:c:p: flag
do
    case "${flag}" in
        i) IMAGE_NAME=${OPTARG};;  # Custom image name
        c) CONTAINER_NAME=${OPTARG};;  # Custom container name
        p) PORT_MAPPING=${OPTARG};;  # Custom port mapping
    esac
done

# Apply Terraform to ensure storage buckets exist
echo "📦 Ensuring required storage buckets created via Terraform..."
cd ./terraform/
if terraform apply -target=module.storage -var-file="../env.tfvars" -auto-approve; then
    echo "✅ Terraform applied successfully."
else
    echo "❌ Terraform failed. Exiting."
    exit 1
fi
cd ..

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
docker build -t $IMAGE_NAME .

# Run the new container
echo "🚀 Running new container..."
docker run -d \
       -v ~/.config/gcloud:/root/.config/gcloud:ro \
       --env-file .env \
       -p $PORT_MAPPING \
       --cpus="2" \
       --cpu-shares=512 \
       --memory="16g" \
       --memory-swap="16g" \
       --gpus "device=0" \
       --device /dev/fuse \
       --cap-add SYS_ADMIN \
       --name $CONTAINER_NAME \
       $IMAGE_NAME

# Wait for container to be ready
echo "⏳ Waiting for container to be ready..."
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT | grep "200"; then
        echo "✅ Container $CONTAINER_NAME is now running here: http://localhost:$PORT"
        exit 0
    fi
    echo -n "🔄 Waiting... ($i/30)"
    sleep 2
    echo -ne "\r"
done

echo "❌ Container did not respond with HTTP 200 within the timeout period."
docker logs $CONTAINER_NAME
exit 1
