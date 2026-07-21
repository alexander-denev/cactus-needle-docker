FROM ubuntu:24.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    python3.12 \
    python3.12-venv \
    python3-pip \
    cmake \
    build-essential \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone repo
RUN git clone https://github.com/cactus-compute/cactus.git /app/cactus
WORKDIR /app/cactus

# Switch Docker shell from /bin/sh to /bin/bash so 'source' works
SHELL ["/bin/bash", "-c"]

# Initialize Cactus virtual environment
RUN source ./setup

# Persist virtualenv and binaries in PATH across all layers and runtime
ENV PATH="/app/cactus/venv/bin:/app/cactus:$PATH"

# Download model weights
RUN cactus download Cactus-Compute/needle --bits 4

EXPOSE 8080

CMD ["cactus", "serve", "Cactus-Compute/needle", "--host", "0.0.0.0", "--port", "8080", "--backend", "cpu"]