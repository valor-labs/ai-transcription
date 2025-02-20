# Configure the Google Cloud provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0" # Or your preferred version
    }
  }
}

provider "google" {
  project = "your-gcp-project-id" # Replace with your GCP project ID
  region  = "your-gcp-region"      # Replace with your preferred region (e.g., "us-central1")
}

# Create a Cloud Storage bucket (if you don't have one already)
resource "google_storage_bucket" "transcription_bucket" {
  name                        = "your-bucket-name" # Replace with a globally unique bucket name
  location                    = "your-gcp-region" # Must match region above
  uniform_bucket_level_access = true # Recommended for Cloud Run access

  # Optional: Add lifecycle rules, versioning, etc. as needed
}

# Create the Cloud Run service
resource "google_cloud_run_v2_service" "transcription_service" {
  name     = "transcription-service" # Replace with your service name
  location = "your-gcp-region"

  template {
    containers {
      image = "your-container-image" # Replace with your container image URL (e.g., from Artifact Registry or Container Registry)

      # Set environment variables
      env {
        name  = "BUCKET_NAME"
        value = google_storage_bucket.transcription_bucket.name
      }
      # Optional: set HUGGINGFACE_TOKEN if needed
      env {
        name = "HUGGINGFACE_TOKEN"
        value = "your_huggingface_token" # Store securely, don't hardcode!
      }

      # Resource limits (adjust as needed)
      resources {
        limits {
          cpu    = "2" # Example: 2 CPUs
          memory = "4Gi" # Example: 4 GB memory
        }
      }
    }

      # Scale settings
      scaling {
          min_instance_count = 0
          max_instance_count = 3 # Adjust as needed
      }

  }

  traffic {
    type = "TRAFFIC_ALL"
  }
}


# Grant Cloud Run service account access to the Cloud Storage bucket
resource "google_storage_bucket_iam_member" "cloud_run_access" {
  bucket = google_storage_bucket.transcription_bucket.name
  role   = "roles/storage.objectAdmin" # Or "roles/storage.objectCreator" if only write access is needed

  member = "serviceAccount:${google_cloud_run_v2_service.transcription_service.status[0].address.email}"
}

# Cloud Function trigger (optional, if you want direct Cloud Function trigger)
# resource "google_cloudfunctions2_function" "transcription_function" {
#   name        = "transcription-function"
#   location    = "your-gcp-region"
#   description = "Cloud Function for transcription"

#   build_config {
#     entry_point = "process_audio" # The name of your Cloud Function entry point
#     runtime     = "python311"      # Or your preferred runtime
#     source {
#       storage_source {
#         bucket = google_storage_bucket.transcription_bucket.name # Or your source code bucket
#         object = "function-source.zip"  # Your source code zip file
#       }
#     }
#   }

#   service_config {
#     max_instance_count = 3 # Adjust as needed
#     min_instance_count = 0
#     available_memory   = "256M" # Adjust as needed
#     timeout            = "60s" # Adjust as needed
#     # service_account_email = google_service_account.cloud_function_sa.email # If you use a dedicated service account

#     # Event trigger for Cloud Storage
#     event_trigger {
#       event_type = "google.cloud.storage.object.v1.finalized" # Trigger on file upload
#       bucket      = google_storage_bucket.transcription_bucket.name
#     }
#   }
# }

# # Grant Cloud Function service account access to the Cloud Storage bucket (if using Cloud Function)
# resource "google_storage_bucket_iam_member" "cloud_function_access" {
#   bucket = google_storage_bucket.transcription_bucket.name
#   role   = "roles/storage.objectAdmin" # Or roles/storage.objectCreator

#   member = "serviceAccount:${google_cloudfunctions2_function.transcription_function.service_account_email}"
# }