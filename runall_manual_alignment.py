from pyannote.audio.pipelines.speaker_diarization import SpeakerDiarization
from pyannote.core import Segment
from faster_whisper import WhisperModel, BatchedInferencePipeline
from pyannote.audio.pipelines.utils.hook import ProgressHook

import torch
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True

import torchaudio
import os
import gc
import yaml

import argparse

# Set up CLI argument parsing
parser = argparse.ArgumentParser(description="Run speaker diarization and Whisper transcription.")
parser.add_argument("--skip-diarization", action="store_true", help="Skip diarization and load from YAML.")
parser.add_argument("--skip-whisper", action="store_true", help="Skip Whisper transcription and load from YAML.")
args = parser.parse_args()

print("Cuda is available" if torch.cuda.is_available() else "Cuda is not available")
if not torch.cuda.is_available() :
    exit()

# Load Hugging Face token from environment (or paste it manually)
HF_TOKEN = os.getenv("HUGGINGFACE_TOKEN")

# Load the diarization pipeline with authentication
pipeline = SpeakerDiarization.from_pretrained(
    "pyannote/speaker-diarization-2.1", # "pyannote/speaker-diarization-3.0", 
    use_auth_token=HF_TOKEN
)


# pipeline.to(torch.device("cuda" if torch.cuda.is_available() else "cpu"))

pipeline.to(torch.device("cuda"))

diarization_path = "./output/diarization_results.yaml"
whisper_path = "./output/whisper_results.yaml"
final_output_path = "./output/final_output.yaml"



audio_file = "input.wav"


if args.skip_diarization and os.path.exists(diarization_path):
    print("Skipping diarization, loading from YAML...")
    with open(diarization_path, "r") as f:
        diarization_results = yaml.safe_load(f)
else:
    print("Run diarization")
    with ProgressHook() as hook:
        diarization = pipeline({"uri": "meeting", "audio": audio_file}, hook=hook)

    # diarization = pipeline({"uri": "meeting", "audio": audio_file})
    # for turn, _, speaker in diarization.itertracks(yield_label=True):
    #     print(f"Speaker {speaker}: {turn.start:.2f}s - {turn.end:.2f}s")


    print("Convert diarization output to a CPU-friendly format and saving it")
    diarization_results = [
        (turn.start, turn.end, speaker) for turn, _, speaker in diarization.itertracks(yield_label=True)
    ]

    diarization_yaml = [
        {"start": turn_start, "end": turn_end, "speaker": speaker}
        for turn_start, turn_end, speaker in diarization_results
    ]


    with open(diarization_path, "w") as f:
        yaml.dump(diarization_yaml, f, default_flow_style=False, sort_keys=False)
    print("Diarization results saved.")

    print("Free up the cache")
    del pipeline  
    del diarization  
    gc.collect()
    torch.cuda.empty_cache()




if args.skip_whisper and os.path.exists(whisper_path):
    print("Skipping Whisper transcription, loading from YAML...")
    with open(whisper_path, "r") as f:
        whisper_segments = yaml.safe_load(f)
else:
    print("Run whisper batches")
    whisper_model = WhisperModel("turbo", device="cuda", compute_type="float32")


    batched_model = BatchedInferencePipeline(model=whisper_model)
    whisper_segments, info = batched_model.transcribe(audio_file, batch_size=2, vad_filter=False, max_initial_timestamp=0.0, word_timestamps=True)


    print("Serialize Whisper results")
    whisper_yaml = [
        {"start": float(segment.start), "end": float(segment.end), "text": segment.text}
        for segment in whisper_segments
    ]

    with open(whisper_path, "w") as f:
        yaml.dump(whisper_yaml, f, default_flow_style=False, sort_keys=False)

    print("Whisper transcription saved.")

# for segment in whisper_segments:
#     for turn, _, speaker in diarization.itertracks(yield_label=True):
#         if turn.start <= segment.start and turn.end >= segment.end:
#             print(f"Speaker {speaker}: {segment.text}")

# for segment in whisper_segments:
#     for turn_start, turn_end, speaker in diarization_results:
#         if turn_start <= segment.start and turn_end >= segment.end:
#             print(f"Speaker {speaker}: {segment.text}")


print("Saving aligned results:")

aligned_results = [
    {
        "speaker": speaker,
        "start": float(segment.start),
        "end": float(segment.end),
        "text": segment.text
    }
    for segment in whisper_segments
    for turn_start, turn_end, speaker in diarization_results
    if turn_start <= segment.start and turn_end >= segment.end
]

print("Aligning speakers with text...")
aligned_results = [
    {
        "speaker": entry["speaker"],
        "start": segment["start"],
        "end": segment["end"],
        "text": segment["text"]
    }
    for segment in whisper_segments
    for entry in diarization_results
    if entry["start"] <= segment["start"] and entry["end"] >= segment["end"]
]

with open(final_output_path, "w") as f:
    yaml.dump(aligned_results, f, default_flow_style=False, sort_keys=False)


print("Done, printing...")
whisper_segments = list(whisper_segments)  # Convert generator to list

for i, seg in enumerate(whisper_segments[:5]):
    print(f"{i+1}. {seg.start:.2f}s - {seg.end:.2f}s: {seg.text}")