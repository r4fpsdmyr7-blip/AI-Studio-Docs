#!/bin/bash

# ============================================================================
# AI Studio - Open WebUI Start Script
# File: components/open-webui/start.sh
# 
# Handles the safe startup of the Open WebUI service as a background daemon,
# including environment setup, port conflict avoidance, and auto-opening the browser.
# ============================================================================

set -u # Prevent unbound variable errors (do not use set -e to allow graceful error handling)

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$AI_STUDIO_ROOT/lib/browser.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Pre-flight Checks
# ============================================================================

check_installation() {
    if [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]] || [[ ! -f "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python" ]]; then
        log_error "${COMPONENT_NAME} does not appear to be installed."
        log_info "Please run './ai-studio.sh install ${COMPONENT_NAME}' first."
        return 1
    fi
    return 0
}

check_already_running() {
    if is_daemon_running "$COMPONENT_NAME"; then
        local pid
        pid=$(_read_pid "$COMPONENT_NAME")
        log_warn "${COMPONENT_NAME} is already running (PID: $pid)."
        log_info "Use './ai-studio.sh stop ${COMPONENT_NAME}' to stop it first."
        return 1
    fi
    return 0
}

# ============================================================================
# 4. Core Startup Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Starting: ${COMPONENT_NAME}${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight checks
    check_installation || exit 1
    check_already_running || exit 1

    # Step 2: Calculate final port (Base port + Global offset)
    local port_offset
    port_offset=$(get_config "DEFAULT_PORT_OFFSET" "global")
    port_offset=${port_offset:-0} # Fallback to 0 if empty
    
    # Ensure port_offset is a valid number
    if ! [[ "$port_offset" =~ ^-?[0-9]+$ ]]; then
        log_warn "Invalid DEFAULT_PORT_OFFSET in config. Using 0."
        port_offset=0
    fi

    local final_port=$((COMPONENT_PORT + port_offset))
    
    # Check if the calculated port is already in use by another application
    if is_port_in_use "$final_port"; then
        log_error "Port ${final_port} is already in use by another application."
        log_info "Please change the DEFAULT_PORT_OFFSET in config/ai-studio.conf or free up the port."
        exit 1
    fi

    # Step 3: Prepare execution environment
    local python_exe="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    local data_dir="${COMPONENT_DIR}/${COMPONENT_DATA_DIR}"
    
    # Ensure data directory exists
    ensure_dir "$data_dir"

    # Step 4: Build the start command
    # Open WebUI respects PORT and DATA_DIR environment variables
    local start_cmd=(
        env 
        PORT="$final_port" 
        DATA_DIR="$data_dir" 
        "$python_exe" 
        -m open_webui
    )

    # Step 5: Start as daemon
    log_info "Launching ${COMPONENT_NAME} on port ${final_port}..."
    if ! start_daemon "$COMPONENT_NAME" "${start_cmd[@]}"; then
        log_error "Failed to start ${COMPONENT_NAME} daemon."
        exit 1
    fi

    # Step 6: Wait for service readiness and open browser
    echo ""
    local url="http://localhost:${final_port}"
    
    # open_browser_when_ready is defined in lib/browser.sh
    # It waits for the port to listen, then triggers the browser
    if open_browser_when_ready "$url" "$final_port" 20; then
        echo ""
        print_separator
        log_success "${COMPONENT_NAME} is running successfully!"
        log_info "You can access it at: ${COLOR_CYAN}${url}${COLOR_RESET}"
        log_info "To stop the service, run: ./ai-studio.sh stop ${COMPONENT_NAME}"
        print_separator
        exit 0
    else
        echo ""
        print_separator
        log_error "${COMPONENT_NAME} started but failed to become ready on port ${final_port}."
        log_info "Please check the logs for details:"
        log_info "  ${COLOR_GRAY}${AI_STUDIO_ROOT}/logs/${COMPONENT_NAME}.log${COLOR_RESET}"
        print_separator
        exit 1
    fi
}

# Execute main function
main "$@"
