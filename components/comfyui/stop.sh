#!/bin/bash

# ============================================================================
# AI Studio - ComfyUI Stop Script
# File: components/comfyui/stop.sh
#
# Handles the graceful shutdown of the ComfyUI background daemon via the
# centralized process management library.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$COMPONENT_DIR/metadata.sh"

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  $(msgf BANNER_STOP "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    if ! is_daemon_running "$COMPONENT_NAME"; then
        log_info "$(msgf STOP_NOT_RUNNING "$COMPONENT_NAME")"
        _clear_pid "$COMPONENT_NAME"
        echo ""
        print_separator
        exit 0
    fi

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
