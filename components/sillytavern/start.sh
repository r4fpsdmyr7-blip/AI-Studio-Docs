#!/bin/bash

# ============================================================================
# AI Studio - SillyTavern Start Script
# File: components/sillytavern/start.sh
#
# Starts the SillyTavern server (node server.js) as a background daemon.
# SillyTavern listens on the port configured in app/config.yaml (default 8000).
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

APP_DIR="${COMPONENT_DIR}/app"

check_installation() {
    if [[ ! -f "${APP_DIR}/server.js" ]]; then
        log_error "$(msgf START_NOT_INSTALLED "$COMPONENT_NAME")"
        log_info "$(msgf HINT_RUN_INSTALL_FIRST "$COMPONENT_NAME")"
        return 1
    fi
    return 0
}

check_already_running() {
    if is_daemon_running "$COMPONENT_NAME"; then
        local pid
        pid=$(_read_pid "$COMPONENT_NAME")
        log_warn "$(msgf START_ALREADY_RUNNING "$COMPONENT_NAME" "$pid")"
        log_info "$(msgf HINT_STOP_FIRST "$COMPONENT_NAME")"
        return 1
    fi
    return 0
}

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_START "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight checks
    check_installation || exit 1
    check_already_running || exit 1

    # Step 2: Port handling
    # SillyTavern reads its port from app/config.yaml; the global
    # DEFAULT_PORT_OFFSET does not apply. Check the configured port instead.
    local port_offset
    port_offset=$(get_config "DEFAULT_PORT_OFFSET" "global")
    port_offset=${port_offset:-0}
    if [[ "$port_offset" != "0" ]]; then
        log_info "$(msgf PORT_CONFIG_NOTE "app/config.yaml")"
    fi

    if is_port_in_use "$COMPONENT_PORT"; then
        log_error "$(msgf START_PORT_IN_USE "$COMPONENT_PORT")"
        log_info "$(msg START_PORT_HINT)"
        exit 1
    fi

    # Step 3: Start as daemon (must run from the repository root)
    log_info "$(msgf START_LAUNCHING "$COMPONENT_PORT" "$COMPONENT_NAME")"
    if ! (cd "$APP_DIR" && start_daemon "$COMPONENT_NAME" node server.js); then
        log_error "$(msgf START_FAILED_DAEMON "$COMPONENT_NAME")"
        exit 1
    fi

    # Step 4: Wait for service readiness and open browser
    echo ""
    local url="http://localhost:${COMPONENT_PORT}"
    if open_browser_when_ready "$url" "$COMPONENT_PORT" 20; then
        echo ""
        print_separator
        log_success "$(msgf START_SUCCESS_COMPONENT "$COMPONENT_NAME")"
        log_info "$(msg START_ACCESS_URL) ${COLOR_CYAN}${url}${COLOR_RESET}"
        log_info "$(msgf START_HINT_STOP "$COMPONENT_NAME")"
        print_separator
        exit 0
    else
        echo ""
        print_separator
        log_error "$(msgf START_NOT_READY "$COMPONENT_NAME" "$COMPONENT_PORT")"
        log_info "$(msg START_CHECK_LOGS)"
        log_info "${COLOR_GRAY}$(msgf START_LOG_PATH "$AI_STUDIO_ROOT" "$COMPONENT_NAME")${COLOR_RESET}"
        print_separator
        exit 1
    fi
}

# Execute main function
main "$@"
