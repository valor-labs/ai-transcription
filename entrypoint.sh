#!/bin/bash
set -e

CONFIG_FILE="/app/config.yaml"

# Function to extract values from YAML
get_yaml_value() {
  grep "^$1:" "$CONFIG_FILE" | awk '{print $2}'
}

# Read bucket names from config.yaml
BUCKET_INPUT=$(get_yaml_value "bucket_name_input")
BUCKET_OUTPUT=$(get_yaml_value "bucket_name_output")
BUCKET_MODEL=$(get_yaml_value "bucket_name_model")

# Create mount points
mkdir -p "/app/buckets/$BUCKET_INPUT" "/app/buckets/$BUCKET_OUTPUT" "/app/buckets/$BUCKET_MODEL"

# Mount each bucket
mount_bucket() {
  local BUCKET_NAME=$1
  local MOUNT_POINT=$2
  echo "📂 Mounting GCS bucket: $BUCKET_NAME to $MOUNT_POINT..."
  if ! gcsfuse "$BUCKET_NAME" "$MOUNT_POINT"; then
    echo "❌ Failed to mount $BUCKET_NAME. Exiting."
    exit 1
  fi
}

mount_bucket "$BUCKET_INPUT" "/app/buckets/$BUCKET_INPUT"
mount_bucket "$BUCKET_OUTPUT" "/app/buckets/$BUCKET_OUTPUT"
mount_bucket "$BUCKET_MODEL" "/app/buckets/$BUCKET_MODEL"

echo "🚀 Starting Python application..."
exec python /app/main.py --server