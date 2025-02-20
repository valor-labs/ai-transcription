variable "project_id" {}

# Get the Cloud Run service account email
data "google_project" "project" {
}


resource "google_project_iam_custom_role" "gcsfuse_role" {
  role_id     = "gcsfuse_role"
  title       = "GCS Fuse Role"
  description = "Allows using gcsfuse to mount buckets"
  permissions = [
    "storage.buckets.list",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.create" # Add this permission for writing
  ]
}

# Apply the gcsfuse role to the gcsfuse service account
resource "google_project_iam_member" "gcsfuse_sa_binding" {
  project = var.project_id
  role    = "projects/${var.project_id}/roles/gcsfuse_role"
  member  = "serviceAccount:${google_service_account.gcsfuse_sa.email}"
}


resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
}

resource "google_service_account" "gcsfuse_sa" {
  account_id   = "gcsfuse-sa"
  display_name = "GCS Fuse Service Account"
}

##### OUTPUTS

output "cloud_run_service_account_email" {
  value       = google_service_account.cloud_run_sa.email
  description = "The email of the service account used for Cloud Run"
}


output "gcsfuse_service_account_email" {
  value       = google_service_account.gcsfuse_sa.email
  description = "The email of the service account used for gcsfuse"
}