variable "global_region" {}
variable "bucket_name_prefix" {}

resource "google_storage_bucket" "input_bucket" {
  # name                        = "${var.bucket_name_prefix}-${random_id.suffix.hex}"
  name                        = "${var.bucket_name_prefix}-input-${random_id.suffix.hex}"
  location                    = var.global_region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "output_bucket" {
  name                        = "${var.bucket_name_prefix}-output-${random_id.suffix.hex}"
  location                    = var.global_region
  uniform_bucket_level_access = true
}

resource "random_id" "suffix" {
  byte_length = 8
}

output "input_bucket_name" {
  value = google_storage_bucket.input_bucket.name
  description = "Bucket name for audio files"
}

output "output_bucket_name" {
  value = google_storage_bucket.output_bucket.name
  description = "Bucket name for transcriptions"
}
