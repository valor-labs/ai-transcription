import argparse
import os
from lib.core import TranscriptionCore
import base64
import json
from flask import Flask, request, jsonify

app = Flask(__name__)

counter = 0

class TranscriptionService:

    def __init__(self):

        self.hf_token = os.getenv("HUGGINGFACE_TOKEN")
        self.bucket1_name = os.environ.get("BUCKET1_NAME")
        self.bucket2_name = os.environ.get("BUCKET2_NAME")
        self.bucket_model_name = os.environ.get("BUCKET_MODEL")

        self.core = TranscriptionCore(hf_token=self.hf_token)
        self.core.load_models()
        
    def get_file_path_from_pubsub(self, event):
        try:
            if 'data' in event:
                data = base64.b64decode(event['data']).decode('utf-8')
                data = json.loads(data)
                bucket_name = data['bucket']
                file_name = data['name']
                file_path = os.path.join('/mnt/gcs-buckets', bucket_name, file_name)
                return file_path
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
        self.core.format_output(result)  # Assuming this saves the result somewhere accessible
        return "Processing complete" # or return a more meaningful result if needed

    def run(self, args=None, pubsub_event=None):  # Modified to accept pubsub_event
        if pubsub_event:  # Check if called from Cloud Run with Pub/Sub event
            audiofile = self.get_file_path_from_pubsub(pubsub_event)
            if audiofile is None:
                raise ValueError("Could not retrieve file path from Pub/Sub event.")
        elif args: #Check for local execution with args
            audiofile = args.audio_file
        else:
            raise ValueError("No input provided (neither Pub/Sub event nor audio file path).")


        return self.process_audio(audiofile, args.skip_whisper if args else False, args.skip_alignment if args else False, args.skip_diarization if args else False)








@app.route('/', methods=['GET'])
def health_check():
    return "OK {counter}", 200

@app.route('/', methods=['POST'])
def process_pubsub():
    counter += 1
    event = request.get_json()
    
    service = TranscriptionService()
    try:
        result = service.run(pubsub_event=event)
        counter -= 1
        return jsonify({"message": result}), 200
    except Exception as e:
        counter -= 1
        print(f"An error occurred: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":

    ############################################ CLI mode
    if os.getenv('K_SERVICE') is None:
        parser = argparse.ArgumentParser(description="Run speaker diarization and Whisper transcription.")
        parser.add_argument("--skip-whisper", action="store_true", help="Skip Whisperx transcription and load from YAML.")
        parser.add_argument("--skip-alignment", action="store_true", help="Skip alignment and load from YAML.")
        parser.add_argument("--skip-diarization", action="store_true", help="Skip diarization and load from YAML.")
        parser.add_argument("--audio_file", type=str, default="./input/input.wav", help="Path to the audio file.")
        args = parser.parse_args()

        service = TranscriptionService()
        try:
          service.run(args=args) #run with args if running locally
        except Exception as e:
          print(f"An error occurred: {e}") #catch and print any errors during run.

    ############################################ Web server mode
    else:
        app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080))) #start flask if running in cloud run