FROM nvidia/cuda:11.7.1-cudnn8-devel-ubuntu22.04

ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 python3-pip ffmpeg git wget \
    libffi-dev libstdc++6 libgomp1 libuuid1 \
    ncurses-bin readline-common tk tzdata zlib1g libjpeg-dev libpng-dev \
    fuse \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install lsb-core
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Americas/Los_Angeles \
    apt install -y curl lsb-core

RUN echo "deb https://packages.cloud.google.com/apt gcsfuse-$(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/gcsfuse.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN apt-get update
RUN yes | apt-get install fuse gcsfuse

RUN ln -s /usr/bin/python3 /usr/bin/python

RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu117

COPY requirements.txt /app/requirements.txt

RUN pip install --no-cache-dir --index-url https://pypi.org/simple -r /app/requirements.txt

WORKDIR /app

COPY src_job/*.py /app
COPY src_job/lib /app/lib
COPY config.yaml /app/config.yaml

RUN mkdir -p /app/buckets
# RUN chmod 777 /app/buckets

EXPOSE 8080

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]