#!/bin/bash

# ============================================================================
# AI Studio - Configuration Library (lib/config.sh)
# Manages global and component-specific configurations.
# 
# CRITICAL FIX: Fully compatible with macOS default Bash 3.2.
# Removed associative arrays (declare -A) and Bash 4.0+ syntax (${var,,})
# to prevent "unbound variable" errors under 'set -u'.
# ============================================================================

# Ensure common functions are available
# This script expects to be sourced after lib/common.sh

# ============================================================================
# 1. Configuration Paths
# ============================================================================
readonly AI_STUDIO_CONFIG_DIR="${AI_STUDIO_ROOT:-.}/config"
readonly AI_STUDIO_GLOBAL_CONFIG="${AI_STUDIO_CONFIG_DIR}/global.conf"

# ============================================================================
# 2. Default Values Helper (Bash 3.2 Safe)
# ============================================================================
# Using a function instead of an associative array to guarantee compatibility
# and prevent unbound variable errors in strict mode (set -u).
get_default_config_value() {
    local key="$1"
    case "$key" in
        "AUTO_OPEN_BROWSER") echo "true" ;;
        "DEFAULT_PORT_OFFSET") echo "0" ;;
        "LOG_LEVEL") echo "info" ;;
        "MAX_DIAGNOSE_DEPTH") echo "1" ;;
        *) echo "" ;;
    esac
}

# ============================================================================
# 3. Initialization
# ============================================================================
init_config() {
    # Ensure directory exists safely
    if [[ -n "${AI_STUDIO_CONFIG_DIR:-}" ]]; then
        mkdir -p "$AI_STUDIO_CONFIG_DIR" 2>/dev/null || true
    fi
    
    # Create global config with defaults if it doesn't exist
    if [[ ! -f "$AI_STUDIO_GLOBAL_CONFIG" ]]; then
        # Using heredoc is the safest, fastest way to initialize without variable expansion risks
        cat > "$AI_STUDIO_GLOBAL_CONFIG" << 'EOF'
# AI Studio Global Configuration
# Generated automatically. Do not remove the quotes around values.
AUTO_OPEN_BROWSER="true"
DEFAULT_PORT_OFFSET="0"
LOG_LEVEL="info"
MAX_DIAGNOSE_DEPTH="1"
EOF
    fi
}

# ============================================================================
# 4. Core Configuration Operations
# ============================================================================

get_config() {
    local key="$1"
    local target="${2:-global}"
    local config_file

    if [[ "$target" == "global" ]]; then
        config_file="$AI_STUDIO_GLOBAL_CONFIG"
    else
        config_file="${AI_STUDIO_CONFIG_DIR}/${target}.conf"
    fi

    if [[ ! -f "$config_file" ]]; then
        get_default_config_value "$key"
        return 0
    fi

    # Safely extract value: match ^KEY=, remove KEY=, remove surrounding quotes
    local value
    value=$(grep -E "^${key}=" "$config_file" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//')
    
    # Fallback to default if value is empty
    if [[ -z "$value" ]]; then
        get_default_config_value "$key"
    else
        echo "$value"
    fi
}

set_config() {
    local key="$1"
    local value="$2"
    local target="${3:-global}"
    local config_file

    if [[ "$target" == "global" ]]; then
        config_file="$AI_STUDIO_GLOBAL_CONFIG"
    else
        config_file="${AI_STUDIO_CONFIG_DIR}/${target}.conf"
        mkdir -p "$(dirname "$config_file")" 2>/dev/null || true
        touch "$config_file" 2>/dev/null || true
    fi

    # Validate key (alphanumeric and underscores only)
    if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "Error: Invalid configuration key: $key" >&2
        return 1
    fi

    # Escape double quotes in value for safe storage
    local escaped_value="${value//\"/\\\"}"

    if grep -qE "^${key}=" "$config_file" 2>/dev/null; then
        # macOS (BSD) sed requires an empty string for -i ''
        sed -i '' "s|^${key}=.*|${key}=\"${escaped_value}\"|" "$config_file"
    else
        echo "${key}=\"${escaped_value}\"" >> "$config_file"
    fi
}

delete_config() {
    local key="$1"
    local target="${2:-global}"
    local config_file

    if [[ "$target" == "global" ]]; then
        config_file="$AI_STUDIO_GLOBAL_CONFIG"
    else
        config_file="${AI_STUDIO_CONFIG_DIR}/${target}.conf"
    fi

    if [[ -f "$config_file" ]]; then
        sed -i '' "/^${key}=/d" "$config_file"
    fi
}

# ============================================================================
# 5. Helper Functions
# ============================================================================

is_config_true() {
    local key="$1"
    local target="${2:-global}"
    local value
    value=$(get_config "$key" "$target")
    
    # Convert to lowercase for comparison (Bash 3.2 compatible using 'tr')
    # DO NOT use ${value,,} as it requires Bash 4.0+
    local lower_value
    lower_value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$lower_value" == "true" || "$lower_value" == "1" || "$lower_value" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# 6. Auto-initialization
# ============================================================================
init_config
