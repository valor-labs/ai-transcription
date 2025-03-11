import argparse
import os
import yaml
import base64
import json
import sys
from lib.core import TranscriptionCore
from lib.logger import logger
from flask import Flask, request, jsonify, render_template_string


app = Flask(__name__)

counter = 0

# Load configuration from config.yaml
CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config.yaml")
with open(CONFIG_PATH, "r") as config_file:
    config = yaml.safe_load(config_file)

BUCKET_INPUT = config["bucket_name_input"]
BUCKET_OUTPUT = config["bucket_name_output"]
BUCKET_MODEL = config["bucket_name_model"]

def check_bucket_existence(bucket_name):
    return os.path.exists(f"/app/buckets/{bucket_name}")


HTML_FORM = """
<!DOCTYPE html>
<html>
<head><title>Test Transcription</title></head>
<body>
    <h2>Test Transcription</h2>
    <p>To test the solution manually, without using Terraform and Cloud Run:</p>
    <ol>
        <li>Create the following buckets: 
            {{ input_bucket }} {{ input_check }}, 
            {{ output_bucket }} {{ output_check }}, 
            {{ model_bucket }} {{ model_check }}
        </li>
        <li>Upload the file to the input bucket</li>
        <li>Enter the file name here and press "Convert"</li>
    </ol>
    <form action="/test" method="get">
        <label for="filename">Filename:</label>
        <input type="text" id="filename" name="filename" required>
        <button type="submit">Convert</button>
    </form>
</body>
</html>
"""

class TranscriptionService:

    def __init__(self):
        self.hf_token = os.getenv("HUGGINGFACE_TOKEN")
        self.bucket1_name = BUCKET_INPUT
        self.bucket2_name = BUCKET_OUTPUT
        self.bucket_model_name = BUCKET_MODEL

        self.core = TranscriptionCore(hf_token=self.hf_token, model_dir=f"/app/buckets/{self.bucket_model_name}")
        
        
    def get_file_path_from_pubsub(self, event):
        try:
            data = base64.b64decode(event['message']['data']).decode('utf-8')
            data = json.loads(data)
            bucket_name = data['bucket']
            file_name = data['name']
            return os.path.join('/app/buckets', bucket_name, file_name), file_name
            
        except Exception as e:
            logger.error(f"Error processing Pub/Sub event: {e}")
            sys.exit(1)

    def check_file_exists(self, file_path):
        return os.path.exists(file_path)


    # Here is where everything starts
    def run(self, args=None, pubsub_event=None):  
        logger.info(f"Running processing, args: {args}, pubsub_event: {pubsub_event}")

        try:
            if pubsub_event:  
                audiofile, file_name = self.get_file_path_from_pubsub(pubsub_event)
                if audiofile is None:
                    raise ValueError("Could not retrieve file path from Pub/Sub event.")

                self.output_path = os.path.join('/app/buckets', self.bucket2_name, file_name)

            elif args:  
                audiofile = args.audio_file
            else:
                raise ValueError("No input provided (neither Pub/Sub event nor audio file path).")

            self.core.load_models()

            if not self.check_file_exists(audiofile):
                raise FileNotFoundError(f"Audio file not found: {audiofile}")

            transcription_results, audio = self.core.transcribe(audiofile, skip_whisper=args.skip_whisper if args else False, whisper_path=self.output_path+".transcr.yaml")
            alignment_results = self.core.align(transcription_results, audio, skip_alignment=args.skip_alignment if args else False, alignment_path=self.output_path+".align.yaml")
            diarization_results = self.core.diarize(audio, skip_diarization=args.skip_diarization if args else False, diarization_path=self.output_path+".diar.bin")
            result = self.core.assign_speakers(diarization_results, alignment_results)

            # filename = os.path.basename(audiofile)
            # output_path = os.path.join("/app/buckets", self.bucket2_name, f"{os.path.splitext(filename)[0]}.txt")
            # self.core.format_output(result, output_path)  # Save output in the correct bucket
            self.core.format_output(result, self.output_path+".txt")

        finally:
            self.core.release_memory()

@app.route('/', methods=['GET'])
def health_check():
    return f"OK {counter}", 200

@app.route('/', methods=['POST'])
def process_pubsub():
    global counter
    counter += 1
    event = request.get_json()
    logger.info(f"Received event: {event}")

    service = TranscriptionService()
    try:
        service.run(pubsub_event=event)
        counter -= 1
        return jsonify({"message": "Process complete"}), 200
    except Exception as e:
        counter -= 1
        logger.critical(f"An error occurred: {e}", exc_info=True)
        # sys.exit(1)
        return jsonify({"error": str(e)}), 500


#################################################
# Self-explaining endpoint for testing purposes #
# just enter localhost:8080/test                #
#################################################
@app.route('/test', methods=['GET'])
def test_endpoint():
    filename = request.args.get('filename')
    input_check = "✔️" if check_bucket_existence(BUCKET_INPUT) else "❌"
    output_check = "✔️" if check_bucket_existence(BUCKET_OUTPUT) else "❌"
    model_check = "✔️" if check_bucket_existence(BUCKET_MODEL) else "❌"

    if not filename:
        return render_template_string(HTML_FORM, 
                                input_bucket=BUCKET_INPUT, input_check=input_check,
                                output_bucket=BUCKET_OUTPUT, output_check=output_check,
                                model_bucket=BUCKET_MODEL, model_check=model_check)
    
    payload = {
        "bucket": BUCKET_INPUT,
        "name": filename
    }
    encoded_data = base64.b64encode(json.dumps(payload).encode()).decode()
    
    request_body = {
        "message": {
            "attributes": {
                "eventType": "OBJECT_FINALIZE",
                "bucketId": BUCKET_INPUT
            },
            "data": encoded_data,
            "messageId": "1234567890123456",
            "publishTime": "2025-03-06T12:00:00.000Z"
        },
        "subscription": "projects/my-project/subscriptions/my-subscription"
    }
    
    cli_command = f"curl -X POST http://localhost:8080/ -H 'Content-Type: application/json' -d '{json.dumps(request_body)}'"
    
    return f"<pre>{cli_command}</pre>"

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
            logger.critical(f"Critical server error: {e}", exc_info=True)
        finally:
            sys.exit(1)
