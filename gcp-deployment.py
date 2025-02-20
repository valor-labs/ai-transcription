# ./gcp-deployment.py
import os
from google.cloud import storage
from lib.core import TranscriptionProcessor
import tempfile

# Initialize Cloud Storage client
storage_client = storage.Client()
bucket_name = os.environ.get("BUCKET_NAME")  # Get bucket name from environment variable
bucket = storage_client.bucket(bucket_name)

# Initialize Transcription Processor
device = "cuda"  # or "cpu" if running on a machine without GPU
compute_type = "float32"
hf_token = os.getenv("HUGGINGFACE_TOKEN")

processor = TranscriptionProcessor(device=device, compute_type=compute_type, hf_token=hf_token)
processor.load_models()


def process_audio(event, context):
    """Triggered from a change to a file in Cloud Storage.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    file_name = event['name']
    print(f"File: {file_name} uploaded/modified.")

    if not file_name.endswith(".wav"):  # Process only WAV files
        print("Skipping: Not a WAV file.")
        return

    try:
        # Download file to a temporary location
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            local_audio_path = tmp.name
            blob = bucket.blob(file_name)
            blob.download_to_filename(local_audio_path)
            print(f"File downloaded to {local_audio_path}")

        # Define output paths within the bucket
        base_name = os.path.splitext(file_name)[0]  # Filename without extension
        whisper_path_gcs = f"output/{base_name}_whisper_results.yaml"
        alignment_path_gcs = f"output/{base_name}_whisperx_alignment.yaml"
        diarization_path_gcs = f"output/{base_name}_diarization_results.bin"
        final_output_path_gcs = f"output/{base_name}_transcription.csv"

        # Local temporary paths
        whisper_path_local = f"/tmp/{base_name}_whisper_results.yaml"
        alignment_path_local = f"/tmp/{base_name}_whisperx_alignment.yaml"
        diarization_path_local = f"/tmp/{base_name}_diarization_results.bin"
        final_output_path_local = f"/tmp/{base_name}_transcription.csv"


        transcription_results, audio = processor.transcribe(local_audio_path, whisper_path_local)
        alignment_results = processor.align(transcription_results, audio, alignment_path_local)
        diarization_results = processor.diarize(audio, diarization_path_local)
        result = processor.assign_speakers(diarization_results, alignment_results)
        structured_output = processor.format_output(result)
        processor.save_to_csv(structured_output, final_output_path_local)

        # Upload results back to Cloud Storage
        bucket.blob(whisper_path_gcs).upload_from_filename(whisper_path_local)
        bucket.blob(alignment_path_gcs).upload_from_filename(alignment_path_local)
        bucket.blob(diarization_path_gcs).upload_from_filename(diarization_path_local)
        bucket.blob(final_output_path_gcs).upload_from_filename(final_output_path_local)

        print("Transcription and related files uploaded to Cloud Storage.")

    except Exception as e:
        print(f"Error processing file: {e}")
    finally:
        # Clean up temporary files
        try:
            os.remove(local_audio_path)
            os.remove(whisper_path_local)
            os.remove(alignment_path_local)
            os.remove(diarization_path_local)
            os.remove(final_output_path_local)
            print("Temporary files cleaned up.")
        except Exception as e:
            print(f"Error cleaning up temporary files: {e}")