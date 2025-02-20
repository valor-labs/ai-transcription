terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  config = yamldecode(file("config.yaml"))
}

module "storage" {
  source = "./modules/storage"
  region               = var.region
  bucket_name_prefix = local.config.bucket_name_prefix
}

module "iam" {
  source = "./modules/iam"
  project_id = var.project_id
}


module "secrets" {
  source = "./modules/secrets"
  cloud_run_service_account_email = module.iam.cloud_run_service_account_email
  huggingface_token = var.huggingface_token
}



# Cloud Run module
module "cloud_run" {
  source = "./modules/cloud_run"
  project_id = var.project_id
  container_image_name = var.container_image_name
  cloud_run_service_name = var.cloud_run_service_name
  region     = var.region
  image_tag = var.image_tag
  repository_id = var.repository_id

  cloud_run_template_service_account_email = module.iam.cloud_run_service_account_email
  
  input_bucket_name = module.storage.input_bucket_name
  output_bucket_name = module.storage.output_bucket_name

  depends_on = [ module.storage ]
}





####### NOTIFICATIONS ##########

data "google_storage_project_service_account" "gcs_account" {
}

resource "google_storage_notification" "notification" {
  bucket        = module.storage.input_bucket_name
  payload_format = "JSON_API_V1"

  topic          = google_pubsub_topic.input_file_topic.id

  event_types = ["OBJECT_FINALIZE"] # Trigger on file upload completion
}

resource "google_pubsub_topic_iam_binding" "binding" {
  topic   = google_pubsub_topic.input_file_topic.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}


resource "google_pubsub_topic" "input_file_topic" {
  name = "input_file_uploaded"
}

resource "google_cloud_run_v2_service_iam_member" "run_invoker" {
  name     = var.run_invoker_name
  location = var.region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_pubsub_topic.input_file_topic.id}"
}