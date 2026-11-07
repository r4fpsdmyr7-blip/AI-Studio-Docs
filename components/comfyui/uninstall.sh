#!/bin/bash

# ============================================================================
# AI Studio - ComfyUI Uninstall Script
# File: components/comfyui/uninstall.sh
#
# Stops the service, removes the cloned source (app/) and the virtualenv,
# and optionally preserves downloaded models (--keep-data keeps app/models).
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$COMPONENT_DIR/metadata.sh"

APP_DIR="${COMPONENT_DIR}/app"

# ============================================================================
# 3. Argument Parsing
# ============================================================================

KEEP_DATA=false
FORCE_UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        --force)
            FORCE_UNINSTALL=true
            shift
            ;;
        *)
            log_error "$(msgf UNINSTALL_UNKNOWN_ARG "$1")"
            log_info "$(msgf UNINSTALL_USAGE "$COMPONENT_NAME")"
            exit 1
            ;;
    esac
done

# ============================================================================
# 4. Core Uninstall Logic
# ============================================================================

check_installation() {
    if [[ ! -d "$APP_DIR" ]] && [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        log_info "$(msgf UNINSTALL_NOT_INSTALLED "$COMPONENT_NAME")"
        return 1
    fi
    return 0
}

stop_service_safely() {
    if is_daemon_running "$COMPONENT_NAME"; then
        log_info "$(msgf UNINSTALL_STOPPING "$COMPONENT_NAME")"
        if ! stop_daemon "$COMPONENT_NAME" 15; then
            if [[ "$FORCE_UNINSTALL" == true ]]; then
                log_warn "$(msg UNINSTALL_FORCE_KILL)"
                kill_process_on_port "$COMPONENT_PORT" 2>/dev/null || true
            else
                log_error "$(msgf UNINSTALL_STOP_FAILED "$COMPONENT_NAME")"
                log_info "$(msg UNINSTALL_STOP_HINT)"
                return 1
            fi
        fi
    fi
    return 0
}

confirm_uninstall() {
    if [[ "$FORCE_UNINSTALL" == true ]]; then
        return 0
    fi

    local warning_msg="Are you sure you want to uninstall ${COMPONENT_NAME}?"
    if [[ "$KEEP_DATA" == false ]]; then
        warning_msg="${warning_msg} ${COLOR_RED}THIS WILL DELETE ALL USER DATA AND MODELS!${COLOR_RESET}"
    else
        warning_msg="${warning_msg} ${COLOR_YELLOW}(User data will be preserved)${COLOR_RESET}"
    fi

    if ! confirm_action "$warning_msg" "N"; then
        log_info "$(msg UNINSTALL_CANCELLED)"
        exit 0
    fi
}

cleanup_files() {
    log_info "$(msg UNINSTALL_CLEANING)"

    # Guard: only ever clean inside the exact expected component directory
    if [[ -z "${COMPONENT_DIR}" || "${COMPONENT_DIR}" != "${AI_STUDIO_ROOT}/components/${COMPONENT_NAME}" ]]; then
        log_error "$(msgf INSTALL_GUARD_BAD_DIR "${COMPONENT_DIR}")"
        exit 1
    fi

    # Remove the cloned source tree; with --keep-data, preserve app/models
    if [[ -d "$APP_DIR" ]]; then
        if [[ "$KEEP_DATA" == true ]]; then
            log_info "$(msgf UNINSTALL_KEEP_DATA "app/models")"
            find "$APP_DIR" -mindepth 1 -maxdepth 1 ! -name 'models' -exec rm -rf {} +
        else
            rm -rf "$APP_DIR"
        fi
    fi

    # Remove the virtualenv
    if [[ -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        rm -rf "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}"
    fi

    if [[ "$KEEP_DATA" == false ]]; then
        log_warn "$(msgf UNINSTALL_DELETE_DATA "app/models")"
    fi
    log_success "$(msg UNINSTALL_REMOVED_OK)"

    local log_file="${AI_STUDIO_ROOT}/logs/${COMPONENT_NAME}.log"
    if [[ -f "$log_file" ]]; then
        rm -f "$log_file"
        log_info "$(msg UNINSTALL_LOG_CLEARED)"
    fi
}

# ============================================================================
# 5. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_RED}  $(msgf BANNER_UNINSTALL "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    if ! check_installation; then
        print_separator
        exit 0
    fi

    if ! stop_service_safely; then
        print_separator
        exit 1
    fi

    confirm_uninstall

    echo ""
    cleanup_files

    echo ""
    print_separator
    log_success "$(msgf UNINSTALL_SUCCESS_COMPONENT "$COMPONENT_NAME")"
    echo ""

    if [[ "$KEEP_DATA" == true ]]; then
        log_info "$(msg UNINSTALL_DATA_PRESERVED) ${COLOR_CYAN}${APP_DIR}/models${COLOR_RESET}"
        log_info "$(msg UNINSTALL_REINSTALL_HINT)"
    else
        log_warn "$(msg UNINSTALL_DATA_DELETED)"
    fi

    echo ""
    echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
    echo "  $(msg UNINSTALL_HINT_LIST)"
    echo "  $(msg UNINSTALL_HINT_INSTALL_OTHER)"
    echo ""
    rm -f "${COMPONENT_DIR}/.installed"

    echo ""
    print_separator

    exit 0
}

# Execute main function
main "$@"
