
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

### 1. Authorization

Init and authorize GCP CLI client
```
gcloud init
gcloud auth application-default login
```

### 2. Env file and HuggingFace token

Create `.env` from `.env.example`.

Specify HUGGINGFACE_TOKEN that needs to be created here https://huggingface.co/settings/tokens

The `.env` file is used for both Terraform and local environment.

When you select region, run this to authorize Docker to push image to the cloud:

```
gcloud auth configure-docker {your region}-docker.pkg.dev
```

### 3. Other variables (optional)

Check ./terraform/variables.tf file - it contains a lot of variables that influence you installation.

You can set values in `.env` file.

### Run the solution

#### Run at GCP environment

`./deploy.sh apply` - will apply Terraform configuration to selected GCP project.

`./deploy.sh destroy` - will remove all resources created

`./deploy.sh rebuild` - will redeploy CloudRun container

#### Run locally (still requires GCP buckets)

`./run-locally.sh`

Then,
- Upload file to the input bucket
- Open http://localhost:8080/test to generate curl command
- Run the command to imitate the Pub/Sub notification that triggers the processing

## LICENSE 

Creative Commons Attribution (CC BY 4.0)
Valor Labs Inc.
