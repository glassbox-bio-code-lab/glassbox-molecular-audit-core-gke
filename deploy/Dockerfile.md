FROM nvidia/cuda:12.2.0-devel-ubuntu22.04

# Structural/MD runtime covering OpenMM, AlphaFold integration stubs, NMA, ProLIF, ProDy, Biopython, RDKit.

ENV DEBIAN_FRONTEND=noninteractive \
 PYTHONDONTWRITEBYTECODE=1 \
 PYTHONUNBUFFERED=1 \
 PIP_DISABLE_PIP_VERSION_CHECK=1 \
 PIP_NO_CACHE_DIR=1 \
 NVIDIA_VISIBLE_DEVICES=all \
 NVIDIA_DRIVER_CAPABILITIES=compute,utility

RUN apt-get update && \
 apt-get install -y --no-install-recommends \
 python3 python3-pip python3-venv python3-dev \
 build-essential cmake git wget curl ca-certificates \
 libxrender1 libsm6 libxext6 libgl1 \
 ffmpeg && \
 rm -rf /var/lib/apt/lists/\*

RUN python3 -m pip install --upgrade pip

# Core scientific stack for MD / NMA / interaction stability / evolutionary trace

RUN python3 -m pip install --no-cache-dir \
 openmm mdtraj \
 mdanalysis prolif \
 prody \
 biopython \
 rdkit-pypi \
 jax[cpu] \
 numpy scipy pandas networkx \
 matplotlib seaborn

# pdbfixer from GitHub (PyPI missing wheels)

RUN python3 -m pip install --no-cache-dir git+https://github.com/openmm/pdbfixer.git

WORKDIR /workspace

# Default shell; orchestrator entrypoints supplied via docker-compose/run

CMD ["/bin/bash"]
