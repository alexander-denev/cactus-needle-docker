# syntax=docker/dockerfile:1
#
# Serves the Needle 26M model on x86-64 CPU.
#
# NOTE: We deploy the *needle* repo (pure JAX/Flax), NOT the *cactus* runtime.
# cactus's inference engine is ARM64-only — its kernels hardcode
# `-march=armv8.2-a` (ARM NEON) and will not compile on x86-64. needle is the
# Mac/PC implementation of the same model and runs on CPU JAX with no native
# build step.
FROM ubuntu:24.04

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive

# Make pip resilient on slow/unstable connections.
ENV PIP_DEFAULT_TIMEOUT=1000 \
    PIP_RETRIES=10 \
    PIP_NO_INPUT=1

# Install OS dependencies. apt caches are kept in BuildKit cache mounts so
# rebuilds don't re-download them (removing docker-clean lets apt keep the debs).
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-debs
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    python3.12 \
    python3.12-venv \
    python3-pip \
    build-essential

# Clone needle (shallow). Its own layer, so it stays cached unless this line changes.
RUN git clone --depth 1 https://github.com/cactus-compute/needle.git /app/needle
WORKDIR /app/needle

# Create the venv and put it on PATH.
RUN python3.12 -m venv /app/needle/venv
ENV VIRTUAL_ENV="/app/needle/venv" \
    PATH="/app/needle/venv/bin:$PATH"

# Install needle + its deps (jax/jaxlib resolve to the CPU build on x86-64, which
# is exactly what we want here). This replaces the repo's ./setup script, which
# is interactive (prompts for a W&B key) and does accelerator autodetection we
# don't need. The pip cache mount keeps wheels across builds so a failed build
# never re-downloads what already came down.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install -e .

EXPOSE 7860

# `needle playground` is a stdlib HTTP server; it auto-downloads the weights from
# HuggingFace (Cactus-Compute/needle) on start. Bind 0.0.0.0 so it's reachable
# from outside the container.
CMD ["needle", "playground", "--host", "0.0.0.0", "--port", "7860"]
