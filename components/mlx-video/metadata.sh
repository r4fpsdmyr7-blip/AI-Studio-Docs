#!/bin/bash

# ============================================================================
# AI Studio - MLX-Video Component Metadata
# File: components/mlx-video/metadata.sh
# 
# This file defines the static properties and requirements for the MLX-Video 
# component (Efficient local video generation tool powered by MLX). 
# It should be sourced by other component scripts (install.sh, start.sh, etc.) 
# and the main registry. It contains NO execution logic.
# ============================================================================

# 1. Basic Identification
readonly COMPONENT_NAME="mlx-video"
readonly COMPONENT_DESCRIPTION="Efficient local video generation tool powered by MLX"
readonly COMPONENT_TYPE="python" # Deployment type: python, node, docker, binary

# 2. Network Configuration
# MLX-Video typically runs as a CLI script or a temporary local demo server.
# It does not expose a permanent, dedicated network port like a full Web UI.
readonly COMPONENT_PORT=""

# 3. Source & Versioning
# Note: This points to the official MLX examples repository or a dedicated mlx-video repo.
readonly COMPONENT_REPO="https://github.com/ml-explore/mlx-examples.git" 
readonly COMPONENT_BRANCH="main" # Track main for the latest video generation models and optimizations

# 4. System & Environment Dependencies
# Space-separated list of commands/tools required to install and run this component.
# ffmpeg is CRITICAL for video processing, encoding, and decoding on macOS.
# cmake is often required for building MLX C++ extensions.
readonly COMPONENT_REQUIRED_DEPS="python3 git cmake ffmpeg"

# 5. Runtime Configuration Paths (Relative to component directory)
readonly COMPONENT_VENV_DIR=".venv"
# Data directory is crucial for storing generated video outputs (.mp4, .gif) and downloaded model weights.
readonly COMPONENT_DATA_DIR="./outputs"
readonly COMPONENT_LOG_FILE="${AI_STUDIO_ROOT:-.}/logs/mlx-video.log"

# 6. Update Strategy
# Defines what targets are valid for the `--target` update flag for this specific component.
# Updates primarily involve fetching the latest generation scripts and upgrading underlying MLX dependencies.
# Valid options: architecture (core library/dependencies/scripts), all
readonly COMPONENT_UPDATE_TARGETS="architecture all"

# ============================================================================
# Export variables (Recommended for subshells)
# ============================================================================
export COMPONENT_NAME
export COMPONENT_DESCRIPTION
export COMPONENT_TYPE
export COMPONENT_PORT
export COMPONENT_REPO
export COMPONENT_BRANCH
export COMPONENT_REQUIRED_DEPS
export COMPONENT_VENV_DIR
export COMPONENT_DATA_DIR
export COMPONENT_LOG_FILE
export COMPONENT_UPDATE_TARGETS
