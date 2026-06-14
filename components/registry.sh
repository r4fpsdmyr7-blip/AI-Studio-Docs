#!/bin/bash

# ============================================================================
# AI Studio - Component Registry (components/registry.sh)
# Centralized metadata management for all supported AI components.
# Designed for maximum compatibility with macOS default Bash 3.2.
# ============================================================================

# Ensure common functions are available (in case this is sourced independently)
if [[ -z "${COLOR_RESET:-}" ]]; then
    # Fallback: try to source common.sh relative to this file
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    AI_STUDIO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    source "$AI_STUDIO_ROOT/lib/common.sh" 2>/dev/null || true
fi

# ============================================================================
# 1. Component List Definition
# ============================================================================
# Space-separated list of all supported components. 
# Keep this updated when adding new components.
readonly SUPPORTED_COMPONENTS="open-webui sillytavern continue-dev fazm browser-use mlx comfyui mlx-video qwen3"

# ============================================================================
# 2. Metadata Retrieval Functions (Bash 3.2 Compatible)
# ============================================================================

# Get the default network port for a specific component
# Usage: port=$(get_component_port "comfyui")
get_component_port() {
    local component="$1"
    case "$component" in
        open-webui)    echo "3000" ;;
        sillytavern)   echo "8000" ;;
        browser-use)   echo "7788" ;;
        comfyui)       echo "8188" ;;
        qwen3)         echo "11434" ;; # Ollama default port
        # Components without a standalone network port return empty string
        continue-dev|fazm|mlx|mlx-video) echo "" ;;
        *)             echo "" ;;
    esac
}

# Get a human-readable description of the component
# Usage: desc=$(get_component_description "open-webui")
get_component_description() {
    local component="$1"
    case "$component" in
        open-webui)    echo "Powerful local LLM Web UI" ;;
        sillytavern)   echo "Advanced LLM roleplay frontend" ;;
        continue-dev)  echo "AI coding assistant for VS Code/JetBrains" ;;
        fazm)          echo "Native macOS AI Desktop Agent" ;;
        browser-use)   echo "AI-driven browser automation tool" ;;
        mlx)           echo "Apple ML framework for Apple Silicon" ;;
        comfyui)       echo "Node-based image generation (SDXL/FLUX)" ;;
        mlx-video)     echo "Efficient local video generation via MLX" ;;
        qwen3)         echo "Uncensored QWen3 LLM via Ollama" ;;
        *)             echo "Unknown component" ;;
    esac
}

# Get the absolute path to the component's directory
# Usage: dir=$(get_component_dir "mlx")
get_component_dir() {
    local component="$1"
    local root="${AI_STUDIO_ROOT:-.}"
    echo "${root}/components/${component}"
}

# ============================================================================
# 3. Validation & State Functions
# ============================================================================

# Check if a given string is a valid, supported component name
# Usage: if is_valid_component "comfyui"; then ...
is_valid_component() {
    local component="$1"
    for valid_comp in $SUPPORTED_COMPONENTS; do
        if [[ "$component" == "$valid_comp" ]]; then
            return 0
        fi
    done
    return 1
}

# Get a newline-separated list of all supported components
# Usage: for comp in $(get_all_components); do ...
get_all_components() {
    echo "$SUPPORTED_COMPONENTS" | tr ' ' '\n'
}

# Check if a component is currently installed
# Logic: A component is considered "installed" if its directory exists 
# and contains the mandatory 'metadata.sh' or 'install.sh' script.
# Usage: if is_component_installed "open-webui"; then ...
is_component_installed() {
    local component="$1"
    local comp_dir
    comp_dir=$(get_component_dir "$component")
    
    if [[ -d "$comp_dir" ]] && [[ -f "${comp_dir}/install.sh" ]]; then
        return 0
    fi
    return 1
}

# Check if a component is currently running
# Logic: Delegates to lib/process.sh if available, otherwise falls back to port checking.
# Usage: if is_component_running "sillytavern"; then ...
is_component_running() {
    local component="$1"
    local port
    port=$(get_component_port "$component")
    
    # Prefer process.sh daemon check if the function exists
    if declare -f is_daemon_running >/dev/null 2>&1; then
        if is_daemon_running "$component"; then
            return 0
        fi
    fi
    
    # Fallback: Check if the designated port is in use
    if [[ -n "$port" ]]; then
        if declare -f is_port_in_use >/dev/null 2>&1; then
            if is_port_in_use "$port"; then
                return 0
            fi
        else
            # Ultimate fallback using native lsof
            if lsof -i ":$port" >/dev/null 2>&1; then
                return 0
            fi
        fi
    fi
    
    return 1
}

# ============================================================================
# 4. Component Discovery (Dynamic)
# ============================================================================

# Automatically discover components that have been added to the components/ directory
# This is useful for the `list` command to show both supported and custom components.
# Usage: discover_components
discover_components() {
    local root="${AI_STUDIO_ROOT:-.}/components"
    local found_components=()
    
    for dir in "$root"/*/; do
        if [[ -d "$dir" ]]; then
            local comp_name
            comp_name=$(basename "$dir")
            # Skip the registry file itself or non-component directories
            if [[ "$comp_name" != "registry.sh" ]] && [[ -f "${dir}install.sh" ]]; then
                found_components+=("$comp_name")
            fi
        fi
    done
    
    echo "${found_components[@]}"
}
