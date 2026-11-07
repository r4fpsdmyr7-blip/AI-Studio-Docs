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

# Ensure the message layer is available (in case this is sourced independently)
if [[ -z "${AI_STUDIO_LANG_LOADED:-}" ]]; then
    _REG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$_REG_DIR/../lib/lang.sh" 2>/dev/null || true
    unset _REG_DIR
fi

# ============================================================================
# 1. Component List Definition
# ============================================================================
# Space-separated list of all supported components. 
# Keep this updated when adding new components.
readonly SUPPORTED_COMPONENTS="open-webui sillytavern continue-dev fazm browser-use mlx comfyui mlx-video qwen3 model"

# ============================================================================
# 2. Metadata Retrieval Functions (Bash 3.2 Compatible)
# ============================================================================

# Get the default network port for a specific component.
# Single source of truth: the COMPONENT_PORT field in components/<name>/metadata.sh
# (parsed textually — sourcing multiple metadata.sh files in one process would
# collide on their `readonly` declarations).
# Usage: port=$(get_component_port "comfyui")
get_component_port() {
    local component="$1"
    local meta value
    meta="$(get_component_dir "$component")/metadata.sh"
    if [[ -f "$meta" ]]; then
        value=$(sed -n 's/^readonly COMPONENT_PORT="\([^"]*\)".*/\1/p' "$meta" | head -1)
        printf '%s\n' "$value"
        return 0
    fi
    # Components without metadata.sh yet (e.g. qwen3 has no directory)
    case "$component" in
        qwen3)         printf '11434\n' ;; # Ollama default port
        *)             printf '\n' ;;
    esac
}

# Get a human-readable description of the component
# Usage: desc=$(get_component_description "open-webui")
get_component_description() {
    local component="$1"
    local key="DESC_UNKNOWN"
    case "$component" in
        open-webui)    key="DESC_OPEN_WEBUI" ;;
        sillytavern)   key="DESC_SILLYTAVERN" ;;
        continue-dev)  key="DESC_CONTINUE_DEV" ;;
        fazm)          key="DESC_FAZM" ;;
        browser-use)   key="DESC_BROWSER_USE" ;;
        mlx)           key="DESC_MLX" ;;
        comfyui)       key="DESC_COMFYUI" ;;
        mlx-video)     key="DESC_MLX_VIDEO" ;;
        model)         key="DESC_MODEL" ;;
        qwen3)         key="DESC_QWEN3" ;; # 仅有注册项，尚无 components/qwen3/ 目录
    esac
    # 描述文案与 components/<name>/metadata.sh 共用同一批词条，避免同一组件两套措辞。
    # 若消息层不可用（registry.sh 被独立 source 且 lib/lang.sh 缺失），退化为组件名本身。
    if declare -f msg >/dev/null 2>&1; then
        msg "$key"
    else
        printf '%s\n' "$component"
    fi
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
# Logic: A component counts as installed only when its install.sh completed
# successfully and left the marker file components/<name>/.installed
# (uninstall.sh removes it). Previously this checked for install.sh presence,
# which reflected "implemented" rather than "installed".
# Usage: if is_component_installed "open-webui"; then ...
is_component_installed() {
    local component="$1"
    local comp_dir
    comp_dir=$(get_component_dir "$component")

    [[ -f "${comp_dir}/.installed" ]]
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
