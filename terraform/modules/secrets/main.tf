variable "huggingface_token" {}
variable "cloud_run_service_account_email" {}

resource "google_secret_manager_secret" "huggingface_secret" {
  secret_id = "huggingface-token"

  replication {
    auto { }
  }
}

resource "google_secret_manager_secret_iam_member" "secret_iam_member" {
  secret_id = google_secret_manager_secret.huggingface_secret.id
  role       = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${var.cloud_run_service_account_email}"
}

resource "google_secret_manager_secret_version" "huggingface_secret_version" {
  secret = google_secret_manager_secret.huggingface_secret.id
  secret_data = var.huggingface_token
}
