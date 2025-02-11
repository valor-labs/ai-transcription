import whisperx
import gc
import os
import csv
import yaml
import time
import pprint
from datetime import timedelta
import argparse
import numpy as np
import pickle

import torch
torch.backends.cuda.matmul.allow_tf32 = True


start_time = time.time()

def elapsed():
    return str(timedelta(seconds=int(time.time() - start_time)))

device = "cuda"
audio_file = "./input/input.wav"
batch_size = 2
compute_type = "float32" # "int8" # "float32"
HF_TOKEN = os.getenv("HUGGINGFACE_TOKEN")

diarization_path = "./output/diarization_results.bin"
whisper_path = "./output/whisper_results.yaml"
alignment_path = "./output/whisperx_alignment.yaml"
final_output_path = "./output/transcription.csv"



# Set up CLI argument parsing
parser = argparse.ArgumentParser(description="Run speaker diarization and Whisper transcription.")
parser.add_argument("--skip-whisper", action="store_true", help="Skip Whisperx transcription and load from YAML.")
parser.add_argument("--skip-alignment", action="store_true", help="Skip alignment and load from YAML.")
parser.add_argument("--skip-diarization", action="store_true", help="Skip diarization and load from YAML.")
args = parser.parse_args()


def convert_numpy(obj):
    """ Recursively convert NumPy types to native Python types """
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    elif isinstance(obj, np.generic):
        return obj.item()
    elif isinstance(obj, list):
        return [convert_numpy(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: convert_numpy(v) for k, v in obj.items()}
    return obj



print(f"{elapsed()} 1. Loading model and audio")

model_dir = "./model/"
model = whisperx.load_model("turbo", device, compute_type=compute_type, download_root=model_dir)
audio = whisperx.load_audio(audio_file)


print(f"{elapsed()} 2. Load Whisper model and transcribe")

if args.skip_whisper and os.path.exists(whisper_path):
    print("Skipping Whisper transcription, loading from YAML...")
    with open(whisper_path, "r") as f:
        transcription_results = yaml.safe_load(f)
    
    print(f"{elapsed()} Whisper transcription loaded.")
else:
    transcription_results = model.transcribe(audio, batch_size=batch_size)

    print("Serialize Whisper results")

    with open(whisper_path, "w") as f:
        yaml.dump(transcription_results, f, default_flow_style=False, sort_keys=False)

    print(f"{elapsed()} Whisper transcription saved.")




print(f"{elapsed()} 3. Align transcription")

if args.skip_alignment and os.path.exists(alignment_path):
    print("Skipping alignment, loading from YAML...")
    with open(alignment_path, "r") as f:
        alignment_results = yaml.safe_load(f)
    print(f"{elapsed()} Alignment loaded.")
else:
    model_a, metadata = whisperx.load_align_model(language_code=transcription_results["language"], device=device)
    alignment_results = whisperx.align(transcription_results["segments"], model_a, metadata, audio, device, return_char_alignments=False)

    # pprint.pprint(alignment_results["segments"][:10], depth=2)
    # pprint.pprint(alignment_results["word_segments"][:10], depth=2)

    print("Serialize alignment results")

    alignment_results = convert_numpy(alignment_results)

    with open(alignment_path, "w") as f:
        yaml.dump(alignment_results, f, default_flow_style=False, sort_keys=False)

    print(f"{elapsed()} Alignment serialized")



print(f"{elapsed()} 4. Speaker diarization")

if args.skip_diarization and os.path.exists(diarization_path):
    print("Skipping diarization, loading from YAML...")
    
    with open(diarization_path, "rb") as f:
        diarization_results = pickle.load(f)
    # with open(diarization_path, "r") as f:
    #     diarization_results = yaml.safe_load(f)

    print(f"{elapsed()} Diarization loaded")
else:

    diarize_model = whisperx.DiarizationPipeline(use_auth_token=HF_TOKEN, device=device)
    diarization_results = diarize_model(audio)

    print("Segments diarized")


    with open(diarization_path, "wb") as f:
        pickle.dump(diarization_results, f)
    # with open(diarization_path, "w") as f:
    #     yaml.dump(diarization_results, f, default_flow_style=False, sort_keys=False)

    print(f"{elapsed()} Diarization serialized")


print(f"{elapsed()} 5. Assigning words to speakers")

result = whisperx.assign_word_speakers(diarization_results, alignment_results)

print(f"{elapsed()} Assigning words done.")

pprint.pprint(result["segments"][:4], depth=2)


structured_output = []
current_speaker = None
current_start = None
current_end = None
current_text = []

def format_time(seconds):
    return str(timedelta(seconds=int(seconds)))

print(f"{elapsed()} 6. Process and format the output")
for segment in result["segments"]:

    
    speaker = segment.get("speaker", "UNKNOWN_SPEAKER")
    start = segment.get("start", "unknown")
    end = segment.get("end", "unknown")
    text = segment.get("text", "")

    if speaker != current_speaker:
        if current_speaker is not None:
            structured_output.append([current_speaker, format_time(current_start), format_time(current_end), " ".join(current_text)])

        current_speaker = speaker
        current_start = start
        current_text = [text]
    else:
        current_text.append(text)

    current_end = end

if current_speaker is not None:
    structured_output.append([current_speaker, format_time(current_start), format_time(current_end), " ".join(current_text)])

print(f"{elapsed()} 7. Save to CSV")

with open(final_output_path, mode="w", newline="", encoding="utf-8") as file:
    writer = csv.writer(file)
    writer.writerow(["Speaker", "Start", "End", "Speech"])
    writer.writerows(structured_output)

print(f"{elapsed()} Transcription saved to {final_output_path}")
