#!/bin/bash

# ============================================================================
# AI Studio - Browser Use Component Metadata
# File: components/browser-use/metadata.sh
# 
# This file defines the static properties and requirements for the Browser Use 
# component (AI-driven browser automation). It should be sourced by other 
# component scripts (install.sh, start.sh, etc.) and the main registry. 
# It contains NO execution logic.
# ============================================================================

# 1. Basic Identification
readonly COMPONENT_NAME="browser-use"
readonly COMPONENT_DESCRIPTION="AI-driven browser automation and web scraping tool"
readonly COMPONENT_TYPE="python" # Deployment type: python, node, docker, binary

# 2. Network Configuration
# The default port this service will attempt to bind to for its API/Web interface.
readonly COMPONENT_PORT="7788"

# 3. Source & Versioning
readonly COMPONENT_REPO="https://github.com/browser-use/browser-use.git" # Placeholder/Official repo
readonly COMPONENT_BRANCH="main" # Stable branch to track

# 4. System & Environment Dependencies
# Space-separated list of commands/tools required to install and run this component.
# Browser-use heavily relies on Python and Playwright (which will be installed via pip).
readonly COMPONENT_REQUIRED_DEPS="python3 git"

# 5. Runtime Configuration Paths (Relative to component directory)
readonly COMPONENT_VENV_DIR=".venv"
# Data directory is crucial for storing Playwright browser binaries, session cookies, and automation logs
readonly COMPONENT_DATA_DIR="./data"
readonly COMPONENT_LOG_FILE="${AI_STUDIO_ROOT:-.}/logs/browser-use.log"

# 6. Update Strategy
# Defines what targets are valid for the `--target` update flag for this specific component.
# Valid options: backend (core python logic), architecture (dependencies/playwright), models, all
readonly COMPONENT_UPDATE_TARGETS="backend architecture all"

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
