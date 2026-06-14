#!/bin/bash

# ============================================================================
# AI Studio - Process Management Library (lib/process.sh)
# Handles background process lifecycle, PID tracking, and status monitoring.
# ============================================================================

# Ensure common functions are available
# This script expects to be sourced after lib/common.sh

# ============================================================================
# 1. Runtime Directories & Initialization
# ============================================================================
readonly AI_STUDIO_RUN_DIR="${AI_STUDIO_ROOT:-.}/run"
readonly AI_STUDIO_PID_DIR="${AI_STUDIO_RUN_DIR}/pids"
readonly AI_STUDIO_LOG_DIR="${AI_STUDIO_ROOT:-.}/logs"

# Initialize runtime directories on load
ensure_dir "$AI_STUDIO_RUN_DIR"
ensure_dir "$AI_STUDIO_PID_DIR"
ensure_dir "$AI_STUDIO_LOG_DIR"

# ============================================================================
# 2. PID File Management (Internal)
# ============================================================================

_get_pid_file() {
    echo "${AI_STUDIO_PID_DIR}/${1}.pid"
}

_save_pid() {
    local component="$1"
    local pid="$2"
    echo "$pid" > "$(_get_pid_file "$component")"
    log_debug "Saved PID $pid for $component"
}

_read_pid() {
    local component="$1"
    local pid_file
    pid_file="$(_get_pid_file "$component")"
    if [[ -f "$pid_file" ]]; then
        cat "$pid_file"
    else
        echo ""
    fi
}

_clear_pid() {
    local component="$1"
    rm -f "$(_get_pid_file "$component")"
    log_debug "Cleared PID file for $component"
}

# ============================================================================
# 3. Core Lifecycle Functions
# ============================================================================

# Start a component as a background daemon
# Usage: start_daemon "open-webui" python3 -m webui --port 3000
start_daemon() {
    local component="$1"
    shift
    local cmd=("$@")
    local log_file="${AI_STUDIO_LOG_DIR}/${component}.log"
    
    # Check if already running
    if is_daemon_running "$component"; then
        local existing_pid=$(_read_pid "$component")
        log_warn "$component is already running (PID: $existing_pid). Skipping start."
        return 0
    fi

    log_info "Starting $component in background..."
    log_debug "Command: ${cmd[*]}"

    # Start process, redirect output to log, run detached
    nohup "${cmd[@]}" >> "$log_file" 2>&1 &
    local pid=$!
    disown "$pid" 2>/dev/null || true
    
    # Persist PID immediately
    _save_pid "$component" "$pid"

    # Brief wait to verify startup
    sleep 1
    if _is_pid_alive "$pid"; then
        log_success "$component started successfully (PID: $pid)."
        log_info "Logs: ${COLOR_GRAY}${log_file}${COLOR_RESET}"
        return 0
    else
        log_error "$component failed to start. PID $pid exited immediately."
        log_info "Check logs for details: ${COLOR_GRAY}${log_file}${COLOR_RESET}"
        _clear_pid "$component"
        return 1
    fi
}

# Stop a component gracefully, with fallback to force kill
# Usage: stop_daemon "open-webui" [timeout_seconds]
stop_daemon() {
    local component="$1"
    local timeout="${2:-15}"
    local pid
    pid=$(_read_pid "$component")

    if [[ -z "$pid" ]] || ! _is_pid_alive "$pid"; then
        log_info "$component is not running."
        _clear_pid "$component"
        return 0
    fi

    log_info "Stopping $component (PID: $pid) gracefully..."
    kill -TERM "$pid" 2>/dev/null

    # Wait for graceful termination
    local elapsed=0
    while _is_pid_alive "$pid" && [[ $elapsed -lt $timeout ]]; do
        sleep 1
        ((elapsed++))
    done

    if _is_pid_alive "$pid"; then
        log_warn "$component did not respond to SIGTERM within ${timeout}s. Force killing..."
        kill -KILL "$pid" 2>/dev/null
        sleep 1
    fi

    _clear_pid "$component"
    log_success "$component stopped successfully."
    return 0
}

# Restart a component
# Usage: restart_daemon "open-webui" [stop_timeout]
restart_daemon() {
    local component="$1"
    shift
    local stop_timeout="${1:-15}"
    shift
    local start_cmd=("$@")

    stop_daemon "$component" "$stop_timeout"
    sleep 1
    start_daemon "$component" "${start_cmd[@]}"
}

# ============================================================================
# 4. Status & Monitoring Functions
# ============================================================================

# Check if a daemon process is currently alive
# Usage: if is_daemon_running "comfyui"; then ...
is_daemon_running() {
    local component="$1"
    local pid
    pid=$(_read_pid "$component")
    [[ -n "$pid" ]] && _is_pid_alive "$pid"
}

# Get detailed process information (PID, Status, Uptime, CPU%, MEM%, Command)
# Usage: get_daemon_info "sillytavern"
get_daemon_info() {
    local component="$1"
    local pid
    pid=$(_read_pid "$component")

    if [[ -z "$pid" ]] || ! _is_pid_alive "$pid"; then
        echo "stopped"
        return 0
    fi

    # macOS ps formatting: remove headers, extract fields
    local info
    info=$(ps -p "$pid" -o pid=,etime=,%cpu=,%mem=,args= 2>/dev/null | tr -s ' ')
    
    if [[ -z "$info" ]]; then
        echo "zombie_or_orphaned"
        _clear_pid "$component"
        return 0
    fi

    echo "$info"
}

# Wait for a process to exit or timeout
# Usage: wait_for_daemon_exit "mlx" 30
wait_for_daemon_exit() {
    local component="$1"
    local timeout="${2:-10}"
    local pid
    pid=$(_read_pid "$component")

    if [[ -z "$pid" ]]; then return 0; fi

    local elapsed=0
    while _is_pid_alive "$pid" && [[ $elapsed -lt $timeout ]]; do
        sleep 1
        ((elapsed++))
    done
}

# ============================================================================
# 5. Maintenance & Utility Functions
# ============================================================================

# Clean up stale PID files (processes that crashed without cleaning up)
# Usage: clean_stale_pids
clean_stale_pids() {
    local cleaned=0
    for pid_file in "${AI_STUDIO_PID_DIR}"/*.pid; do
        [[ -f "$pid_file" ]] || continue
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        local component
        component=$(basename "$pid_file" .pid)

        if [[ -z "$pid" ]] || ! _is_pid_alive "$pid"; then
            _clear_pid "$component"
            log_debug "Cleaned stale PID for $component"
            ((cleaned++))
        fi
    done
    if [[ $cleaned -gt 0 ]]; then
        log_info "Cleaned $cleaned stale PID file(s)."
    fi
}

# Force kill any process occupying a specific port (advanced/debug use)
# Usage: kill_process_on_port 8188
kill_process_on_port() {
    local port="$1"
    if ! is_port_in_use "$port"; then
        log_info "Port $port is not in use."
        return 0
    fi

    log_warn "Force killing process on port $port..."
    # Find PID using lsof
    local pid
    pid=$(lsof -ti ":$port" 2>/dev/null | head -n 1)
    
    if [[ -n "$pid" ]]; then
        kill -KILL "$pid" 2>/dev/null
        sleep 1
        if ! is_port_in_use "$port"; then
            log_success "Process on port $port terminated."
        else
            log_error "Failed to free port $port. Manual intervention required."
            return 1
        fi
    else
        log_warn "Could not identify PID for port $port."
        return 1
    fi
}

# ============================================================================
# 6. Internal Helper Functions
# ============================================================================

# Safely check if a PID is alive without triggering errors
_is_pid_alive() {
    local pid="$1"
    # kill -0 sends signal 0 (checks existence), returns 0 if alive, 1 if dead
    kill -0 "$pid" 2>/dev/null
}

# ============================================================================
# 7. Auto-Initialization
# ============================================================================
# Automatically clean stale PIDs when the library is sourced
clean_stale_pids
