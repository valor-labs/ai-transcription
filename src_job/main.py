import argparse
import os
import yaml
from lib.core import TranscriptionCore
import base64
import json
from flask import Flask, request, jsonify

app = Flask(__name__)

counter = 0

# Load configuration from config.yaml
CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config.yaml")
with open(CONFIG_PATH, "r") as config_file:
    config = yaml.safe_load(config_file)

BUCKET_INPUT = config["bucket_name_input"]
BUCKET_OUTPUT = config["bucket_name_output"]
BUCKET_MODEL = config["bucket_name_model"]

class TranscriptionService:

    def __init__(self):
        self.hf_token = os.getenv("HUGGINGFACE_TOKEN")
        self.bucket1_name = BUCKET_INPUT
        self.bucket2_name = BUCKET_OUTPUT
        self.bucket_model_name = BUCKET_MODEL

        self.core = TranscriptionCore(hf_token=self.hf_token, model_dir=f"/app/buckets/{self.bucket_model_name}")
        self.core.load_models()
        
    def get_file_path_from_pubsub(self, event):
        try:
            if 'data' in event:
                data = base64.b64decode(event['data']).decode('utf-8')
                data = json.loads(data)
                bucket_name = data['bucket']
                file_name = data['name']
                return os.path.join('/app/buckets', bucket_name, file_name)
            else:
                print("No data found in the Pub/Sub event.")
                return None
        except Exception as e:
            print(f"Error processing Pub/Sub event: {e}")
            return None

    def check_file_exists(self, file_path):
        return os.path.exists(file_path)

    def process_audio(self, audiofile, skip_whisper, skip_alignment, skip_diarization):
        if not self.check_file_exists(audiofile):
             raise FileNotFoundError(f"Audio file not found: {audiofile}")

        transcription_results, audio = self.core.transcribe(audiofile, skip_whisper=skip_whisper)
        alignment_results = self.core.align(transcription_results, audio, skip_alignment=skip_alignment)
        diarization_results = self.core.diarize(audio, skip_diarization=skip_diarization)
        result = self.core.assign_speakers(diarization_results, alignment_results)

        # Construct output path with .txt extension in output bucket
        filename = os.path.basename(audiofile)
        output_path = os.path.join("/app/buckets", self.bucket2_name, f"{os.path.splitext(filename)[0]}.txt")
        self.core.format_output(result, output_path)  # Save output in the correct bucket

        return "Processing complete"

    def run(self, args=None, pubsub_event=None):  
        if pubsub_event:  
            audiofile = self.get_file_path_from_pubsub(pubsub_event)
            if audiofile is None:
                raise ValueError("Could not retrieve file path from Pub/Sub event.")
        elif args:  
            audiofile = args.audio_file
        else:
            raise ValueError("No input provided (neither Pub/Sub event nor audio file path).")

        return self.process_audio(audiofile, args.skip_whisper if args else False, args.skip_alignment if args else False, args.skip_diarization if args else False)


@app.route('/', methods=['GET'])
def health_check():
    return f"OK {counter}", 200

@app.route('/', methods=['POST'])
def process_pubsub():
    global counter
    counter += 1
    event = request.get_json()
    
    service = TranscriptionService()
    try:
        print(event)
        result = service.run(pubsub_event=event)
        counter -= 1
        return jsonify({"message": result}), 200
    except Exception as e:
        counter -= 1
        print(f"An error occurred: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Run speaker diarization and Whisper transcription.")
    parser.add_argument("--server", action="store_true", help="Run in server mode.")
    parser.add_argument("--skip-whisper", action="store_true", help="Skip Whisperx transcription and load from YAML.")
    parser.add_argument("--skip-alignment", action="store_true", help="Skip alignment and load from YAML.")
    parser.add_argument("--skip-diarization", action="store_true", help="Skip diarization and load from YAML.")
    parser.add_argument("--audio_file", type=str, default="./input/input.wav", help="Path to the audio file.")
    args = parser.parse_args()
    
    if args.server:
        app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))  # Start flask if running in cloud run

    else:
        service = TranscriptionService()
        try:
          service.run(args=args)
        except Exception as e:
          print(f"An error occurred: {e}")  # Catch and print any errors during run.
