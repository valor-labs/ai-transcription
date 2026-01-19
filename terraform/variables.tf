variable "project_id" {
  type = string
  description = "The ID of the Google Cloud Project"
  default = "transcriptionai"
}

variable "HUGGINGFACE_TOKEN" {
  type = string
  description = "Secret HuggingFace token"
}


variable "local_region" {
  type = string
  description = "The region to deploy the resources to"
  default = "europe-west4-b"
}

variable "global_region" {
  type = string
  description = "Region to create buckets. Must be same location as calc region"
  default = "europe-west4"
}


variable "gpu_type" {
  type = string
  description = "GPU type"
  default = "nvidia-l4"
}

variable "gpu_memory" {
  type = string
  description = "GPU memory"
  default = "16"
}

variable "cloud_run_service_name" {
  type = string
  description = "Cloud run Service Account name"
  default = "main-service"
}

variable "container_image_name" {
  type = string
  description = "Name of the container's image"
  default = "main-image"
}

variable "repository_name" {
  type = string
  description = "Container Repository Name"
  default = "main-rep"
}

variable "image_tag" {
  type = string
  description = "Image version, latest by default"
  default = "latest"
}

variable "topic_new_file_name" {
  type = string
  description = "Pub/Sub topic that new file just created in the Input Bucket"
  default = "input_file_uploaded"
}
