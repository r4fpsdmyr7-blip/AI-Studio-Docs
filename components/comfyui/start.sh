#!/bin/bash

# ============================================================================
# AI Studio - ComfyUI Start Script
# File: components/comfyui/start.sh
#
# Starts ComfyUI (python main.py) as a background daemon.
# ComfyUI accepts --port, so the global DEFAULT_PORT_OFFSET applies.
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
    if [[ ! -f "${APP_DIR}/main.py" ]] || [[ ! -f "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python" ]]; then
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

    # Step 2: Calculate final port (base port + global offset)
    local port_offset
    port_offset=$(get_config "DEFAULT_PORT_OFFSET" "global")
    port_offset=${port_offset:-0}
    if ! [[ "$port_offset" =~ ^-?[0-9]+$ ]]; then
        log_warn "$(msg START_INVALID_PORT_OFFSET)"
        port_offset=0
    fi

    local final_port=$((COMPONENT_PORT + port_offset))

    if is_port_in_use "$final_port"; then
        log_error "$(msgf START_PORT_IN_USE "$final_port")"
        log_info "$(msg START_PORT_HINT)"
        exit 1
    fi

    # Step 3: Start as daemon (main.py must run from the repository root)
    local python_exe="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"

    log_info "$(msgf START_LAUNCHING "$final_port" "$COMPONENT_NAME")"
    if ! (cd "$APP_DIR" && start_daemon "$COMPONENT_NAME" "$python_exe" main.py --port "$final_port"); then
        log_error "$(msgf START_FAILED_DAEMON "$COMPONENT_NAME")"
        exit 1
    fi

    # Step 4: Wait for service readiness and open browser
    echo ""
    local url="http://localhost:${final_port}"
    # Model loading can take a while on first start; allow a longer wait
    if open_browser_when_ready "$url" "$final_port" 60; then
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
        log_error "$(msgf START_NOT_READY "$COMPONENT_NAME" "$final_port")"
        log_info "$(msg START_CHECK_LOGS)"
        log_info "${COLOR_GRAY}$(msgf START_LOG_PATH "$AI_STUDIO_ROOT" "$COMPONENT_NAME")${COLOR_RESET}"
        print_separator
        exit 1
    fi
}

# Execute main function
main "$@"
