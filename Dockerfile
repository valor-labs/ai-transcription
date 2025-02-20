FROM nvidia/cuda:11.7.1-cudnn8-devel-ubuntu22.04

ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 python3-pip ffmpeg git wget \
    libffi-dev libstdc++6 libgomp1 libuuid1 \
    ncurses-bin readline-common tk tzdata zlib1g libjpeg-dev libpng-dev \
    fuse gcsfuse \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu117

COPY requirements.txt /app/requirements.txt

RUN pip install --no-cache-dir --index-url https://pypi.org/simple -r /app/requirements.txt

WORKDIR /app

COPY cli.py /app/cli.py
COPY gcp-deployment.py /app/gcp-deployment.py
COPY lib /app/lib

# Make sure the directory for mounting exists
RUN mkdir -p /mnt/gcs-bucket

EXPOSE 8000

CMD ["gcsfuse", "/mnt/gcs-buckets" ] && \
    ["python", "cli.py", "--model-dir", "/mnt/gcs-bucket/model"]