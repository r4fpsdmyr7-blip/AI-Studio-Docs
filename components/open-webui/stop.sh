#!/bin/bash

# ============================================================================
# AI Studio - Open WebUI Stop Script
# File: components/open-webui/stop.sh
# 
# Handles the graceful shutdown of the Open WebUI background daemon.
# It utilizes the centralized process management library for safe termination.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Stop Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  $(msgf BANNER_STOP "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    # Pre-flight check: Verify if the component is actually running
    if ! is_daemon_running "$COMPONENT_NAME"; then
        log_info "$(msgf STOP_NOT_RUNNING "$COMPONENT_NAME")"
        # Clean up any potential stale PID files just in case
        _clear_pid "$COMPONENT_NAME"
        echo ""
        print_separator
        exit 0
    fi

    # Execute graceful stop via the process library
    # stop_daemon handles:
    # 1. Sending SIGTERM for graceful shutdown (saving state, closing DB connections)
    # 2. Waiting up to 15 seconds for the process to exit
    # 3. Sending SIGKILL if it fails to respond (preventing zombie processes)
    # 4. Cleaning up the PID file
    if stop_daemon "$COMPONENT_NAME" 15; then
        echo ""
        print_separator
        log_success "$(msgf STOP_SUCCESS_COMPONENT "$COMPONENT_NAME")"
        log_info "$(msgf STOP_PORT_RELEASED "$COMPONENT_PORT")"
        echo ""
        echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
        echo "  $(msgf STOP_HINT_RESTART "$COMPONENT_NAME")"
        echo "  $(msgf STOP_HINT_STATUS "$COMPONENT_NAME")"
        print_separator
        exit 0
    else
        echo ""
        print_separator
        log_error "$(msgf STOP_FAILED_CLEAN "$COMPONENT_NAME")"
        log_info "$(msg STOP_STUCK_HINT)"
        log_info "$(msgf STOP_STUCK_LOG "$AI_STUDIO_ROOT" "$COMPONENT_NAME")"
        log_info "$(msgf STOP_STUCK_KILL "$COMPONENT_PORT")"
        log_info "$(msgf STOP_STUCK_DIAGNOSE "$COMPONENT_NAME")"
        print_separator
        exit 1
    fi
}

# Execute main function
main "$@"
