#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Component Metadata
# File: components/model/metadata.sh
# 
# This file defines the static properties for the centralized MLX model 
# management component. It handles large model weights (LLMs, SD, FLUX) 
# optimized for Apple Silicon. It contains NO execution logic.
# ============================================================================

# 1. Basic Identification
readonly COMPONENT_NAME="model"
readonly COMPONENT_DESCRIPTION="Centralized MLX model repository manager (LLMs, SD, FLUX)"
readonly COMPONENT_TYPE="model-repository" # Special type: not a standalone service

# 2. Network Configuration
# Model management does not expose a network port. It is a data/asset layer.
readonly COMPONENT_PORT=""

# 3. Source & Versioning
# Models are typically fetched from Hugging Face. This repo points to the 
# management scripts or a default organization for MLX-converted models.
readonly COMPONENT_REPO="https://huggingface.co/mlx-community" # Default target for MLX models
readonly COMPONENT_BRANCH="main"

# 4. System & Environment Dependencies
# Space-separated list of commands/tools required.
# huggingface-cli and hf-transfer are CRITICAL for fast, resumable downloads of large MLX models.
# git-lfs is required if fetching from Git repositories.
readonly COMPONENT_REQUIRED_DEPS="python3 git git-lfs huggingface-cli hf-transfer"

# 5. Runtime Configuration Paths
# CRITICAL: Centralize all MLX models in a single directory to save disk space.
# This allows ComfyUI, MLX-Video, and custom LLM scripts to share the same weights.
readonly COMPONENT_DATA_DIR="$HOME/.ai-studio/models/mlx"
readonly COMPONENT_LOG_FILE="${AI_STUDIO_ROOT:-.}/logs/model-manager.log"

# 6. Default MLX Model Definitions (For install/update scripts reference)
# These are example identifiers. The install.sh script will use these to fetch weights.
# Format: "HF_REPO_ID"
readonly DEFAULT_MLX_LLM="Qwen/Qwen3-35B-A3B-Uncensored-HauHauCS-Aggressive-MLX" # Example MLX converted repo
readonly DEFAULT_MLX_IMAGE_SD="stabilityai/stable-diffusion-3.5-large-mlx"
readonly DEFAULT_MLX_IMAGE_FLUX="black-forest-labs/FLUX.1-dev-mlx"

# 7. Update Strategy
# For a model repository, updates strictly mean downloading new model weights 
# or updating the management scripts. 
# Valid options: models (download/update weights), architecture (update management scripts), all
readonly COMPONENT_UPDATE_TARGETS="models architecture all"

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
export COMPONENT_DATA_DIR
export COMPONENT_LOG_FILE
export COMPONENT_UPDATE_TARGETS
export DEFAULT_MLX_LLM
export DEFAULT_MLX_IMAGE_SD
export DEFAULT_MLX_IMAGE_FLUX
