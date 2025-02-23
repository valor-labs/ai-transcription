variable "project_id" {}
variable "cloud_run_service_name" {}
variable "local_region" {}
variable "global_region" {}
variable "image_tag" {}
variable "container_image_name" {}
variable "repository_name" {}

variable "input_bucket_name" {}
variable "output_bucket_name" {}

variable "cloud_run_template_service_account_email" {}


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
  name     = var.cloud_run_service_name
  location = var.global_region

  depends_on = [null_resource.build_and_push_image, google_artifact_registry_repository.repo ]

  template {
    service_account = var.cloud_run_template_service_account_email

    containers {

      image = "${google_artifact_registry_repository.repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.name}/${var.container_image_name}:${var.image_tag}"

      env {
        name  = "BUCKET1_NAME"
        value = var.input_bucket_name # Pass the output from the storage module
      }
      env {
        name  = "BUCKET2_NAME"
        value = var.output_bucket_name # Pass the output from the storage module
      }
    }

    volumes {
      name = "gcs-mount"
    }
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
