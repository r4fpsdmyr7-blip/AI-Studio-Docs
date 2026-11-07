#!/bin/bash

# ============================================================================
# AI Studio - ComfyUI Update Script
# File: components/comfyui/update.sh
#
# Updates ComfyUI per the official guide: git pull + pip install -r
# requirements.txt. Targets: frontend | backend | architecture | all.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$COMPONENT_DIR/metadata.sh"

APP_DIR="${COMPONENT_DIR}/app"

# ============================================================================
# 3. Argument Parsing & Validation
# ============================================================================

TARGET="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="$2"
            shift 2
            ;;
        *)
            log_error "$(msgf UPDATE_UNKNOWN_ARG "$1")"
            log_info "$(msgf UPDATE_USAGE "$COMPONENT_NAME")"
            exit 1
            ;;
    esac
done

if [[ ! " ${COMPONENT_UPDATE_TARGETS} " =~ " ${TARGET} " ]]; then
    log_error "$(msgf UPDATE_INVALID_TARGET "$TARGET")"
    log_info "$(msgf UPDATE_SUPPORTED_TARGETS "$COMPONENT_NAME" "${COMPONENT_UPDATE_TARGETS// /, }")"
    exit 1
fi

check_installation() {
    if [[ ! -f "${APP_DIR}/main.py" ]] || [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        log_error "$(msgf UPDATE_NOT_INSTALLED "$COMPONENT_NAME")"
        log_info "$(msgf HINT_RUN_INSTALL_FIRST "$COMPONENT_NAME")"
        return 1
    fi
    return 0
}

update_source_code() {
    log_info "$(msg UPDATE_FETCHING)"
    if git -C "$APP_DIR" fetch origin && git -C "$APP_DIR" pull origin "$COMPONENT_BRANCH"; then
        log_success "$(msg UPDATE_SRC_OK)"
        return 0
    fi
    log_error "$(msg UPDATE_FAILED)"
    return 1
}

update_python_deps() {
    log_info "$(msg UPDATE_PYDEPS)"
    # shellcheck disable=SC1091
    source "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    if python3 -m pip install -r "${APP_DIR}/requirements.txt"; then
        log_success "$(msg UPDATE_PYDEPS_OK)"
        return 0
    fi
    log_error "$(msg UPDATE_PYDEPS_FAILED)"
    return 1
}

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_UPDATE "$COMPONENT_NAME" "$TARGET")${COLOR_RESET}"
    print_separator
    echo ""

    check_installation || exit 1

    local was_running=false
    if is_daemon_running "$COMPONENT_NAME"; then
        log_info "$(msgf UPDATE_STOPPING_FOR_CLEAN "$COMPONENT_NAME")"
        stop_daemon "$COMPONENT_NAME" 15
        was_running=true
        sleep 2
    fi

    local update_failed=false

    # ComfyUI ships frontend and backend in one repository; every target
    # pulls source, then refreshes Python dependencies.
    case "$TARGET" in
        all|architecture|backend|frontend)
            update_source_code || update_failed=true
            update_python_deps || update_failed=true
            ;;
    esac

    if [[ "$was_running" == true ]]; then
        echo ""
        log_info "$(msgf UPDATE_RESTARTING "$COMPONENT_NAME")"
        "${COMPONENT_DIR}/start.sh" >/dev/null 2>&1 &
        sleep 3
    fi

    echo ""
    print_separator

    if [[ "$update_failed" == true ]]; then
        log_error "$(msg UPDATE_ERRORS)"
        log_info "$(msgf UPDATE_HINT_DIAGNOSE "$COMPONENT_NAME")"
        exit 1
    else
        log_success "$(msgf UPDATE_SUCCESS_COMPONENT "$COMPONENT_NAME")"
        if [[ "$was_running" == true ]]; then
            log_info "$(msg UPDATE_AUTO_RESTARTED)"
        fi
    fi
    print_separator
}

# Execute main function
main "$@"
