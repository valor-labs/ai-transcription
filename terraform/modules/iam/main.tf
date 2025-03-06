variable "project_id" {}
variable "topic_new_file_name" {}

resource "google_project_iam_custom_role" "cloud_run_transcriptor_role" {
  role_id     = "cloudRunTranscriptorRole"
  title       = "Cloud Run Transcriptor Role"
  description = "Role for Cloud Run service account to read input bucket and write to output bucket."
  permissions = [
    "storage.buckets.list",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.create",
  ]
}


resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
}

/* Bind the custom role to the Cloud Run service account */
resource "google_project_iam_member" "cloud_run_sa_storage_binding" {
  project = var.project_id
  role    = "projects/${var.project_id}/roles/cloudRunTranscriptorRole"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

/* Additional permissions for Pub/Sub access (if the service pulls messages) */
resource "google_project_iam_member" "cloud_run_sa_pubsub_binding" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "binding" {
  project = var.project_id
  role    = "roles/run.invoker"
  member = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}


/* Grant Logging access */
resource "google_project_iam_member" "cloud_run_sa_logging_binding" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "cloud_run_sa_artifact_registry_binding" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}



output "cloud_run_service_account_email" {
  value       = google_service_account.cloud_run_sa.email
  description = "The email of the service account used for Cloud Run"
}
