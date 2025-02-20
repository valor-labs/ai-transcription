variable "project_id" {}
variable "cloud_run_service_name" {}
variable "region" {}
variable "image_tag" {}
variable "container_image_name" {}
variable "repository_id" {}

variable "input_bucket_name" {}
variable "output_bucket_name" {}

variable "cloud_run_template_service_account_email" {}



resource "null_resource" "build_and_push_image" {
  provisioner "local-exec" {
    # Use the repository URL from the Artifact Registry resource
    command = <<EOT
      docker build -t ${google_artifact_registry_repository.repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.name}/${var.container_image_name}:${var.image_tag}../.  # Build from the parent directory
      docker push ${google_artifact_registry_repository.repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.name}/${var.container_image_name}:${var.image_tag}
    EOT
  }
}

resource "google_cloud_run_v2_service" "main" {
  name     = var.cloud_run_service_name
  location = var.region

  depends_on = [null_resource.build_and_push_image]

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
  location      = var.region
  repository_id = var.repository_id
  format        = "DOCKER"
  description  = "Docker repository for transcription service"
}


resource "google_service_account" "gcsfuse_sa" {
  account_id   = "gcsfuse-sa"
  display_name = "GCS Fuse Service Account"
}

output "gcsfuse_service_account_email" {
  value       = google_service_account.gcsfuse_sa.email
  description = "The email of the service account used for gcsfuse"
}