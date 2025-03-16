import whisperx
import os
import csv
import yaml
import numpy as np
import pickle
import torch
from datetime import timedelta

from lib.logger import logger

class TranscriptionCore:
    def __init__(self, device="cuda", compute_type="float32", hf_token=None, model_dir="./model/", gpu_memory="6"):

        self.device = device
        self.compute_type = compute_type

        logger.info(f"TranscriptionCore initialized with device={device}, compute_type={compute_type}, hf_token length is {len(hf_token)} (should be 37), model_dir={model_dir}")
        
        self.hf_token = hf_token

        self.model_dir = model_dir
        self.model = None
        
        self.diarize_model = None

        # Verify CUDA is accessible
        if not torch.cuda.is_available():
            logger.error("CUDA is not available! Ensure the container has GPU access.")
            exit()

        logger.info(f"Setting GPU memory limit to {gpu_memory}GB")
        if int(gpu_memory) > 6:
            self.model_name = "large-v2"
            self.batch_size = 8
            self.threads = 4
            torch.backends.cuda.matmul.allow_tf32 = True
            torch.backends.cudnn.allow_tf32 = True
            torch.cuda.set_per_process_memory_fraction(1.0, 0)
        else:
            self.model_name = "turbo"
            self.batch_size = 1
            self.threads = 4
            torch.cuda.set_per_process_memory_fraction(0.75, 0)
            


        logger.info(f"Model will be {self.model_name}, batch size {self.batch_size}")


    def load_models(self):
        logger.info(f"Loading models {self.model_name}, {self.device}, compute_type={self.compute_type}, download_root={self.model_dir}")
        self.model = whisperx.load_model(self.model_name, self.device, compute_type=self.compute_type, download_root=self.model_dir, threads=self.threads)
        
        logger.info("Starting DiarizationPipeline to assign speaker labels")
        try:
            
            self.diarize_model = whisperx.DiarizationPipeline(use_auth_token=self.hf_token, device=self.device)
        except Exception as e:
            logger.error(f"Error loading diarization model: {e}")
            logger.error("Check if the Hugging Face token is valid and has access to the model.")
            raise

    def transcribe(self, audio_file, skip_whisper=False, whisper_path="./output/whisper_results.yaml"):
        logger.info(f"Loading audio: {audio_file}")
        audio = whisperx.load_audio(audio_file)

        if skip_whisper and os.path.exists(whisper_path):
            logger.info("Skipping Whisper transcription, loading from YAML...")
            with open(whisper_path, "r") as f:
                transcription_results = yaml.safe_load(f)
        else:
            logger.info("Starting Transcribe...")
            transcription_results = self.model.transcribe(audio, batch_size=self.batch_size)
            with open(whisper_path, "w") as f:
                yaml.dump(transcription_results, f, default_flow_style=False, sort_keys=False)
            logger.info(f"Whisper transcription saved to {whisper_path}")

        return transcription_results, audio

    def align(self, transcription_results, audio, skip_alignment=False, alignment_path="./output/whisperx_alignment.yaml"):
        if skip_alignment and os.path.exists(alignment_path):
            logger.info(f"Skipping alignment, loading from YAML...")
            with open(alignment_path, "r") as f:
                alignment_results = yaml.safe_load(f)
        else:
            model_a, metadata = whisperx.load_align_model(language_code=transcription_results["language"], device=self.device)
            alignment_results = whisperx.align(transcription_results["segments"], model_a, metadata, audio, self.device, return_char_alignments=False)
            alignment_results = self._convert_numpy(alignment_results) # Convert numpy arrays
            with open(alignment_path, "w") as f:
                yaml.dump(alignment_results, f, default_flow_style=False, sort_keys=False)
            logger.info(f"Alignment serialized to {alignment_path}")

        return alignment_results

    def diarize(self, audio, skip_diarization=False, diarization_path="./output/diarization_results.bin"):
        if skip_diarization and os.path.exists(diarization_path):
            logger.info(f"Skipping diarization, loading from pickle...")
            with open(diarization_path, "rb") as f:
                diarization_results = pickle.load(f)
        else:
            diarization_results = self.diarize_model(audio)
            with open(diarization_path, "wb") as f:
                pickle.dump(diarization_results, f)
            logger.info(f"Diarization serialized to {diarization_path}")
        return diarization_results

    def assign_speakers(self, diarization_results, alignment_results):
        return whisperx.assign_word_speakers(diarization_results, alignment_results)

    def format_output(self, result, final_output_path="./output/transcription.csv"):
        logger.info(f"Formatting output and saving to {final_output_path}")
        structured_output = []
        current_speaker = None
        current_start = None
        current_end = None
        current_text = []

        def format_time(seconds):
            return str(timedelta(seconds=int(seconds)))

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

        with open(final_output_path, mode="w", newline="", encoding="utf-8") as file:
            writer = csv.writer(file)
            writer.writerow(["Speaker", "Start", "End", "Speech"])
            writer.writerows(structured_output)

        logger.info(f"Transcription saved to {final_output_path}")

    def _convert_numpy(self, obj):
        """ Recursively convert NumPy types to native Python types """
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        elif isinstance(obj, np.generic):
            return obj.item()
        elif isinstance(obj, list):
            return [self._convert_numpy(i) for i in obj]
        elif isinstance(obj, dict):
            return {k: self._convert_numpy(v) for k, v in obj.items()}
        return obj
    
    def release_memory(self):
        """Release memory after processing"""
        if self.model:
            del self.model
        if self.diarize_model:
            del self.diarize_model
        torch.cuda.empty_cache()
        logger.info("Memory released.")
