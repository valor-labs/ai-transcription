
variable input_bucket_name {}
variable global_region {}
variable project_id {}
variable "topic_new_file_name" {}


data "google_project" "current" {
  project_id = var.project_id
}
data "google_storage_project_service_account" "gcs_account" {}


resource "google_pubsub_topic" "input_file_topic" {
  name = var.topic_new_file_name
}

resource "google_storage_notification" "notification" {
  bucket         = var.input_bucket_name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.input_file_topic.id
  event_types    = ["OBJECT_FINALIZE"] 

  depends_on = [ google_pubsub_topic.input_file_topic ]
}

resource "google_pubsub_topic_iam_binding" "binding" {
  topic   = google_pubsub_topic.input_file_topic.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}



output "input_file_topic" {
  value = google_pubsub_topic.input_file_topic
}