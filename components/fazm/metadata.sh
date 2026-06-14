#!/bin/bash

# ============================================================================
# AI Studio - Fazm Component Metadata
# File: components/fazm/metadata.sh
# 
# This file defines the static properties and requirements for the Fazm 
# component (macOS native AI Desktop Agent). 
# It should be sourced by other component scripts and the main registry.
# Note: Fazm operates as a local desktop agent, not a standalone web server.
# ============================================================================

# 1. Basic Identification
readonly COMPONENT_NAME="fazm"
readonly COMPONENT_DESCRIPTION="Native macOS AI Desktop Agent"
readonly COMPONENT_TYPE="desktop-agent" # Deployment type: python, node, docker, binary, desktop-agent

# 2. Network Configuration
# Fazm operates locally as a desktop agent and typically communicates via 
# local IPC (Inter-Process Communication) or specific macOS APIs, rather than 
# exposing a public HTTP port. Therefore, the port is intentionally left empty.
readonly COMPONENT_PORT=""

# 3. Source & Versioning
readonly COMPONENT_REPO="https://github.com/fazm-ai/fazm.git" # Placeholder repo
readonly COMPONENT_BRANCH="main"

# 4. System & Environment Dependencies
# Requires Git for fetching the agent scripts/configurations. 
# Additional dependencies (like specific Python versions or macOS frameworks) 
# will be handled by the component's specific install.sh script.
readonly COMPONENT_REQUIRED_DEPS="git"

# 5. Runtime Configuration Paths
# Desktop agents on macOS typically store their state, logs, and configurations 
# in the user's home directory or Library. We use a hidden directory in home 
# for cross-platform consistency within the AI Studio ecosystem.
readonly COMPONENT_DATA_DIR="$HOME/.fazm"
readonly COMPONENT_LOG_FILE="${AI_STUDIO_ROOT:-.}/logs/fazm.log"

# 6. Update Strategy
# Updates for a desktop agent primarily involve fetching the latest agent 
# scripts, binaries, or configuration templates.
# Valid options: architecture (binaries/scripts/configs), all
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
