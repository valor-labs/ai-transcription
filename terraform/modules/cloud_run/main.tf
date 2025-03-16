variable "project_id" {}
variable "cloud_run_service_name" {}
variable "local_region" {}
variable "global_region" {}
variable "image_tag" {}
variable "container_image_name" {}
variable "repository_name" {}

variable "bucket_name_input" {}
variable "bucket_name_output" {}
variable "bucket_name_model" {}
variable "huggingface_secret_id" {} 
variable "cloud_run_template_service_account_email" {}
variable "gpu_type" {}
variable "gpu_memory" {}
  


data "google_project" "current" {
  project_id = var.project_id
}

resource "null_resource" "build_and_push_image" {
  provisioner "local-exec" {
    # like,
    # docker build -t europe-west4-docker.pkg.dev/transcriptionai/main-rep/main-image:latest ./
    command = <<EOT
      cd .. && \
      docker build -t ${google_artifact_registry_repository.repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.name}/${var.container_image_name}:${var.image_tag} ./ && \
      docker push ${google_artifact_registry_repository.repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.name}/${var.container_image_name}:${var.image_tag}
    EOT
  }

  depends_on = [ google_artifact_registry_repository.repo ]
}

resource "google_cloud_run_v2_service" "main" {
  provider = google-beta
  name     = var.cloud_run_service_name
  location = var.global_region
  launch_stage = "BETA"
  deletion_protection=false
  depends_on = [null_resource.build_and_push_image, google_artifact_registry_repository.repo ]


  template {
    service_account = var.cloud_run_template_service_account_email


    # (Optional) Sets the maximum number of requests that each serving instance can receive.
    # If not specified or 0, defaults to 80 when requested CPU >= 1 and defaults to 1 when requested CPU < 1.
    max_instance_request_concurrency = 1

    node_selector {
      accelerator = var.gpu_type
    }

    scaling {
      max_instance_count = 1
      min_instance_count = 0
    }        

    containers {

      image = "${google_artifact_registry_repository.repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.name}/${var.container_image_name}:${var.image_tag}"

      env {
        name  = "BUCKET1_NAME"
        value = var.bucket_name_input
      }
      env {
        name  = "BUCKET2_NAME"
        value = var.bucket_name_output
      }

      env {
        name  = "BUCKET_MODEL"
        value = var.bucket_name_model
      }

      env {
        name  = "GPU_MEMORY"
        value = var.gpu_memory
      }

      env {
        name = "HUGGINGFACE_TOKEN"
        value_source {
          secret_key_ref {
            secret = var.huggingface_secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          "cpu" = "4"
          "memory" = "16Gi"
          "nvidia.com/gpu" = "1"
        }

      }
    }

    # volumes {
    #   name = "gcs-mount"
    # }
  }
}


resource "google_artifact_registry_repository" "repo" {
  repository_id = var.repository_name
  project       = var.project_id
  location      = var.global_region
  format        = "DOCKER"
  description  = "Docker repository for transcription service"
}


output "service_uri" {
  value = google_cloud_run_v2_service.main.uri
}
