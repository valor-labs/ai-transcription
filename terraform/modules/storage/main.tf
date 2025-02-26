variable "global_region" {}
variable "bucket_name_prefix" {}

resource "google_storage_bucket" "input_bucket" {
  # name                        = "${var.bucket_name_prefix}-${random_id.suffix.hex}"
  name                        = "${var.bucket_name_prefix}-input-${random_id.suffix.hex}"
  location                    = var.global_region
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket" "output_bucket" {
  name                        = "${var.bucket_name_prefix}-output-${random_id.suffix.hex}"
  location                    = var.global_region
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket" "model_bucket" {
  name                        = "${var.bucket_name_prefix}-model-${random_id.suffix.hex}"
  location                    = var.global_region
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "random_id" "suffix" {
  byte_length = 8
}

output "bucket_name_input" {
  value = google_storage_bucket.input_bucket.name
  description = "Bucket name for audio files"
}

output "bucket_name_output" {
  value = google_storage_bucket.output_bucket.name
  description = "Bucket name for transcriptions"
}

output "bucket_name_model" {
  value = google_storage_bucket.model_bucket.name
  description = "Bucket name for keeping the model file"
}
