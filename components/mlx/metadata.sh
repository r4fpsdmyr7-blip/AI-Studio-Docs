#!/bin/bash

# ============================================================================
# AI Studio - MLX Component Metadata
# File: components/mlx/metadata.sh
# 
# This file defines the static properties and requirements for the MLX 
# component (Apple's machine learning framework for Apple Silicon). 
# It should be sourced by other component scripts and the main registry.
# Note: MLX is a foundational framework/library, not a standalone web server.
# ============================================================================

# 1. Basic Identification
readonly COMPONENT_NAME="mlx"
readonly COMPONENT_DESCRIPTION="Apple's machine learning framework optimized for Apple Silicon"
readonly COMPONENT_TYPE="python" # Deployment type: python, node, docker, binary, framework

# 2. Network Configuration
# MLX is a computational framework and library. It does not expose a standalone 
# network port. Components that use MLX (like mlx-lm or mlx-vlm) will manage their own ports.
readonly COMPONENT_PORT=""

# 3. Source & Versioning
readonly COMPONENT_REPO="https://github.com/ml-explore/mlx.git"
readonly COMPONENT_BRANCH="main" # Track the main branch for the latest Apple Silicon optimizations

# 4. System & Environment Dependencies
# Space-separated list of commands/tools required to install and run this component.
# Building or installing MLX often requires CMake and a C++ compiler (provided by Xcode CLI).
readonly COMPONENT_REQUIRED_DEPS="python3 git cmake"

# 5. Runtime Configuration Paths
# MLX itself does not have a persistent user data directory like a Web UI.
# However, models downloaded via MLX examples or related tools are often cached.
# We point to the standard macOS cache directory for MLX.
readonly COMPONENT_DATA_DIR="$HOME/.cache/mlx"
readonly COMPONENT_LOG_FILE="${AI_STUDIO_ROOT:-.}/logs/mlx.log"

# 6. Update Strategy
# Since MLX is a foundational library, updates primarily involve upgrading the 
# Python package or rebuilding from source to get the latest hardware optimizations.
# Valid options: architecture (core library/dependencies), all
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
export COMPONENT_DATA_DIR
export COMPONENT_LOG_FILE
export COMPONENT_UPDATE_TARGETS
