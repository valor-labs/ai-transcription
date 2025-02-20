#!/bin/bash

# Prompt for Hugging Face token
read -p "Enter Hugging Face token: " HUGGINGFACE_TOKEN

# Read config file
CONFIG_FILE="env.tfvars"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found."
  exit 1
fi

# Terraform commands
cd terraform
terraform init
terraform apply -var="huggingface_token=$HUGGINGFACE_TOKEN" -var-file="../$CONFIG_FILE"

# # Output results (example)
# echo "Cloud Run service URL: $(terraform output cloud_run_url)" # Assuming you have this output in Terraform