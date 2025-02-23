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
  region  = var.local_region
}

locals {
  config = yamldecode(file("config.yaml"))
}

resource "google_project_service" "gcp_core_services" {
  for_each = toset([
    "containerregistry.googleapis.com",
    "cloudapis.googleapis.com",
  ])
  project = var.project_id
  service = each.key
  disable_dependent_services = true 
}

resource "google_project_service" "gcp_services" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com",
  ])
  project = var.project_id
  service = each.key
  disable_dependent_services = true 
  depends_on = [ google_project_service.gcp_core_services ]
}

resource "time_sleep" "wait_for_apis" {
  create_duration = "30s"
  depends_on = [ google_project_service.gcp_services ]
}



module "storage" {
  source             = "./modules/storage"
  global_region      = var.global_region
  bucket_name_prefix = local.config.bucket_name_prefix
  depends_on = [
    time_sleep.wait_for_apis, 
    module.iam
  ]
}

module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
  topic_new_file_name = var.topic_new_file_name
  depends_on = [ time_sleep.wait_for_apis ]
}

module "pub_sub" {
  source = "./modules/pub_sub"
  project_id = var.project_id
  input_bucket_name = module.storage.input_bucket_name
  global_region = var.global_region
  topic_new_file_name = var.topic_new_file_name

  depends_on = [ module.storage ]
}

module "secrets" {
  source                          = "./modules/secrets"
  cloud_run_service_account_email = module.iam.cloud_run_service_account_email
  huggingface_token               = var.huggingface_token
  depends_on                      = [ time_sleep.wait_for_apis ]
}

module "cloud_run" {
  source                                = "./modules/cloud_run"
  project_id                            = var.project_id
  container_image_name                  = var.container_image_name
  cloud_run_service_name                = var.cloud_run_service_name
  local_region                          = var.local_region
  global_region                         = var.global_region
  image_tag                             = var.image_tag
  repository_name                       = var.repository_name
  cloud_run_template_service_account_email = module.iam.cloud_run_service_account_email
  input_bucket_name                     = module.storage.input_bucket_name
  output_bucket_name                    = module.storage.output_bucket_name
  depends_on = [
    module.storage,
    module.iam,
    module.pub_sub,
    time_sleep.wait_for_apis,
  ]
}


resource "google_pubsub_subscription" "cloud_run_subscription" {
  name  = "cloud_run_subscription"
  topic = module.pub_sub.input_file_topic.id

  push_config {
    push_endpoint = module.cloud_run.service_uri
  }

  depends_on = [module.cloud_run, module.pub_sub, module.storage]
}


resource "google_pubsub_topic_iam_member" "gcs_notification_publisher" {
  topic = var.topic_new_file_name
  role = "roles/pubsub.publisher"
  member = "serviceAccount:${module.iam.cloud_run_service_account_email}"

  depends_on = [ module.iam, module.pub_sub ]
}


resource "google_cloud_run_v2_service_iam_member" "run_invoker" {
  name     = var.cloud_run_service_name
  location = var.global_region
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "serviceAccount:${module.iam.cloud_run_service_account_email}"

  depends_on = [ module.iam, module.pub_sub, module.cloud_run ]
}