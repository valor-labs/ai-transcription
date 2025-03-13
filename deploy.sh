#!/bin/bash


# Read config file
CONFIG_FILE="env.tfvars"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found."
  exit 1
fi

# Terraform commands
cd terraform
terraform init
terraform apply -var-file="../$CONFIG_FILE"

# Output results
echo "Cloud Run service URL: $(terraform output console_url_input_bucket)"