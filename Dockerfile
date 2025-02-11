# Use NVIDIA's official PyTorch image with CUDA support
FROM nvidia/cuda:11.5.2-cudnn8-devel-ubuntu20.04

# Set environment variables for CUDA
ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}
ENV PATH=/usr/local/cuda/bin:${PATH}

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 python3-pip ffmpeg git wget \
    libffi-dev libstdc++6 libgomp1 libuuid1 \
    ncurses-bin readline-common tk tzdata zlib1g \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set Python alias
RUN ln -s /usr/bin/python3 /usr/bin/python

# Upgrade pip
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch (compatible with CUDA 11.5)
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu115

# Install Python dependencies from requirements.txt
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Set working directory
WORKDIR /app

# Copy the Python script
COPY runall.py /app/runall.py

# Expose ports (if you want to use it as an API)
EXPOSE 8000

# Run the script
CMD ["python", "runall.py"]
