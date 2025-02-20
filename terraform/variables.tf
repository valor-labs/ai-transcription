variable "project_id" {
  type = string
  description = "The ID of the Google Cloud Project"
  default = "transcriptionai"
}

variable "huggingface_token" {
  type = string
  description = "Secret HuggingFace token"
}


variable "region" {
  type = string
  description = "The region to deploy the resources to"
  default = "europe-west4-b"
}

variable "cloud_run_service_name" {
  type = string
  description = "Cloud run Service Account name"
  default = "main_acc"
}

variable "container_image_name" {
  type = string
  description = "Name of the container's image"
  default = "main_image"
}

variable "repository_id" {
  type = string
  description = "Container Repository ID"
  default = "main_rep"
}

variable "image_tag" {
  type = string
  description = "Image version, latest by default"
  default = "latest"
}

variable "run_invoker_name" {
  type = string
  description = "Run invoker name"
  default = "start_run_invoker"
}