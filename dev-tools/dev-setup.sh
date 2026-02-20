#!/usr/bin/env bash

# ----------------------------
# This installs:
# Dev stack
# AI stack
# Gaming stack
# Robotics tools
# System optimizations
# ----------------------------

set -e

echo "Pop!_OS Setup Starting..."

# =========================
# System update
# =========================
sudo apt update && sudo apt upgrade -y

# =========================
# Core development tools
# =========================
sudo apt install -y \
git curl wget build-essential cmake pkg-config \
python3-pip python3-venv python3-dev \
htop neovim tmux unzip zip

# =========================
# Python data science stack
# =========================
pip install --upgrade pip
pip install numpy pandas matplotlib seaborn jupyterlab

# =========================
# Your GUI stack (customtkinter projects)
# =========================
pip install customtkinter pillow

# =========================
# AI + ML stack
# =========================
pip install torch torchvision torchaudio \
transformers accelerate datasets sentencepiece

# =========================
# Computer vision (for robotics)
# =========================
pip install opencv-python ultralytics

# =========================
# Arduino + Embedded tools
# =========================
sudo apt install -y arduino arduino-cli platformio

# =========================
# Gaming stack
# =========================
sudo apt install -y steam gamemode mangohud

# =========================
# Vulkan tools
# =========================
sudo apt install -y vulkan-tools

# =========================
# NVIDIA tools
# =========================
sudo apt install -y nvidia-settings nvtop

# =========================
# Monitoring + thermals
# =========================
sudo apt install -y lm-sensors psensor

# =========================
# SSD health
# =========================
sudo systemctl enable fstrim.timer

# =========================
# zRAM (better multitasking)
# =========================
sudo apt install -y zram-tools

# =========================
# Power performance
# =========================
sudo system76-power profile performance

echo "DONE, Your machine is now fully loaded."