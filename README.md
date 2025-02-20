
# Audio diarization project. Work in progress

Solution based on WhisperX, Python deployable on GCP using Terraform.

This repository accompanies the article
https://valor-software.com/articles/interview-question-transcription-with-speech-recognition-part-1

## Logic

- Uploaded audio appears in the Google Storage Bucket
- This triggers pub/sub event.
- On Pub/Sub event container is being run on Cloud Run. It uses GPU resources.
- When execution is finished, it places transcript file to the second Google Storage Bucket

## Project deployment

```
gcloud init

cd terraform
gcloud auth application-default login

terraform init

create env.tfvars

terraform plan -var-file="../env.tfvars"
```