#!/bin/bash

set -e

echo "📂 Mounting GCS bucket..."
if ! gcsfuse /app/buckets; then
  echo "❌ Failed to mount GCS bucket. Exiting."
  exit 1
fi

echo "🚀 Starting Python application..."
exec python /app/main.py --server