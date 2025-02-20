import argparse
import os
from lib.core import TranscriptionCore

bucket1_name = os.environ.get("BUCKET1_NAME")
bucket2_name = os.environ.get("BUCKET2_NAME")

if __name__ == "__main__":



    parser = argparse.ArgumentParser(description="Run speaker diarization and Whisper transcription.")
    parser.add_argument("--skip-whisper", action="store_true", help="Skip Whisperx transcription and load from YAML.")
    parser.add_argument("--skip-alignment", action="store_true", help="Skip alignment and load from YAML.")
    parser.add_argument("--skip-diarization", action="store_true", help="Skip diarization and load from YAML.")
    parser.add_argument("--audio_file", type=str, default="./input/input.wav", help="Path to the audio file.") # Added audio file argument
    args = parser.parse_args()

    hf_token = os.getenv("HUGGINGFACE_TOKEN")
    core = TranscriptionCore(hf_token=hf_token)
    core.load_models()

    # for the future
    audiofile = args.audio_file or bucket1_name; 

    transcription_results, audio = core.transcribe(audiofile, skip_whisper=args.skip_whisper)
    alignment_results = core.align(transcription_results, audio, skip_alignment=args.skip_alignment)
    diarization_results = core.diarize(audio, skip_diarization=args.skip_diarization)
    result = core.assign_speakers(diarization_results, alignment_results)
    core.format_output(result)
