#!/bin/bash

# ============================================================================
# AI Studio - Browser Use Update Script
# File: components/browser-use/update.sh
#
# Upgrades the browser-use package and refreshes the Playwright Chromium
# browser. Targets: backend | architecture | all (all behave the same for a
# library component).
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$COMPONENT_DIR/metadata.sh"

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

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_UPDATE "$COMPONENT_NAME" "$TARGET")${COLOR_RESET}"
    print_separator
    echo ""

    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    if [[ ! -x "$venv_python" ]]; then
        log_error "$(msgf UPDATE_NOT_INSTALLED "$COMPONENT_NAME")"
        log_info "$(msgf HINT_RUN_INSTALL_FIRST "$COMPONENT_NAME")"
        exit 1
    fi

    local update_failed=false

    log_info "$(msg BU_PIP_INSTALLING)"
    if ! "$venv_python" -m pip install --upgrade browser-use; then
        log_error "$(msg BU_PIP_FAILED)"
        update_failed=true
    else
        log_success "$(msg UPDATE_PACKAGE_OK)"
    fi

    log_info "$(msg BU_PLAYWRIGHT_INSTALLING)"
    if ! "$venv_python" -m playwright install chromium --no-shell; then
        log_error "$(msg BU_PLAYWRIGHT_FAILED)"
        update_failed=true
    else
        log_success "$(msg BU_PLAYWRIGHT_OK)"
    fi

    echo ""
    print_separator
    if [[ "$update_failed" == true ]]; then
        log_error "$(msg UPDATE_ERRORS)"
        log_info "$(msgf UPDATE_HINT_DIAGNOSE "$COMPONENT_NAME")"
        exit 1
    else
        log_success "$(msgf UPDATE_SUCCESS_COMPONENT "$COMPONENT_NAME")"
    fi
    print_separator
}

# Execute main function
main "$@"
