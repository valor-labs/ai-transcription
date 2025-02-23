import argparse
import os
from lib.core import TranscriptionCore
from google.cloud import storage
import base64
import json

bucket1_name = os.environ.get("BUCKET1_NAME")
bucket2_name = os.environ.get("BUCKET2_NAME")


def is_cloud_run_env():
    """Detects if the code is running in a Cloud Run environment."""
    return os.getenv('K_SERVICE') is not None


def get_file_path_from_pubsub(event):
    """
    Reads file name from a Pub/Sub event triggered by file creation on a GCS bucket
    and generates its file path, considering the bucket was mounted with gcsfuse.
    """
    try:
        if 'data' in event:
            # Decode the Pub/Sub message data
            data = base64.b64decode(event['data']).decode('utf-8')
            # Parse the data as JSON
            data = json.loads(data)
            # Extract the bucket and file name
            bucket_name = data['bucket']
            file_name = data['name']
            # Construct the file path
            file_path = os.path.join('/mnt/gcs-buckets', bucket_name, file_name)
            return file_path
        else:
            print("No data found in the Pub/Sub event.")
            return None
    except Exception as e:
        print(f"Error processing Pub/Sub event: {e}")
        return None


if __name__ == "__main__":


    parser = argparse.ArgumentParser(description="Run speaker diarization and Whisper transcription.")
    parser.add_argument("--skip-whisper", action="store_true", help="Skip Whisperx transcription and load from YAML.")
    parser.add_argument("--skip-alignment", action="store_true", help="Skip alignment and load from YAML.")
    parser.add_argument("--skip-diarization", action="store_true", help="Skip diarization and load from YAML.")
    parser.add_argument("--audio_file", type=str, default="./input/input.wav", help="Path to the audio file.") # Added audio file argument
    args = parser.parse_args()

    if is_cloud_run_env():
        # Read the file path from the Pub/Sub event
        audiofile = get_file_path_from_pubsub(os.environ)  # Assuming the event data is in environment variables
    else:
        audiofile = args.audio_file

    hf_token = os.getenv("HUGGINGFACE_TOKEN")
    core = TranscriptionCore(hf_token=hf_token)
    core.load_models()

    transcription_results, audio = core.transcribe(audiofile, skip_whisper=args.skip_whisper)
    alignment_results = core.align(transcription_results, audio, skip_alignment=args.skip_alignment)
    diarization_results = core.diarize(audio, skip_diarization=args.skip_diarization)
    result = core.assign_speakers(diarization_results, alignment_results)
    core.format_output(result)
