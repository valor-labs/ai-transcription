#!/bin/bash

# Read config file
CONFIG_FILE=".env"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found."
  exit 1
fi

# Check for parameters
if [ "$1" == "apply" ]; then
  cd terraform
  terraform init
  terraform apply -var-file="../$CONFIG_FILE"
elif [ "$1" == "destroy" ]; then
  cd terraform
  terraform init
  terraform destroy -var-file="../$CONFIG_FILE"
elif [ "$1" == "rebuild" ]; then
  cd terraform
  terraform init
  terraform taint module.cloud_run.google_cloud_run_v2_service.main
  terraform taint module.cloud_run.null_resource.build_and_push_image
  terraform apply -var-file="../$CONFIG_FILE"
else
  echo "Usage: $0 {apply|destroy|rebuild}"
  exit 1
fi

# Output results
if [ "$1" == "apply" ] || [ "$1" == "rebuild" ]; then
  echo "Cloud Run service URL: $(terraform output console_url_input_bucket)"
fi

