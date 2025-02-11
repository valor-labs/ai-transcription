from fastapi import FastAPI, UploadFile, File
from pyannote.audio.pipelines.speaker_diarization import SpeakerDiarization
from pyannote.core import Segment
import torch

app = FastAPI()
pipeline = SpeakerDiarization.from_pretrained("pyannote/speaker-diarization-3.0")
pipeline.to(torch.device("cuda" if torch.cuda.is_available() else "cpu"))

@app.post("/diarize")
async def diarize_audio(file: UploadFile = File(...)):
    audio_path = f"./{file.filename}"
    with open(audio_path, "wb") as buffer:
        buffer.write(await file.read())

    diarization = pipeline({"uri": "meeting", "audio": audio_path})
    results = [{"speaker": speaker, "start": turn.start, "end": turn.end}
               for turn, _, speaker in diarization.itertracks(yield_label=True)]
    return results

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)