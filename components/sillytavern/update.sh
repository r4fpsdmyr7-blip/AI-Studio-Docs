#!/bin/bash

# ============================================================================
# AI Studio - SillyTavern Update Script
# File: components/sillytavern/update.sh
#
# Updates SillyTavern: git pull (release branch) + npm install.
# Targets: frontend | architecture | all (see metadata.sh UPDATE_TARGETS).
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

TARGET="all" # Default update target

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

# Validate target against metadata definition
if [[ ! " ${COMPONENT_UPDATE_TARGETS} " =~ " ${TARGET} " ]]; then
    log_error "$(msgf UPDATE_INVALID_TARGET "$TARGET")"
    log_info "$(msgf UPDATE_SUPPORTED_TARGETS "$COMPONENT_NAME" "${COMPONENT_UPDATE_TARGETS// /, }")"
    exit 1
fi

check_installation() {
    if [[ ! -f "${APP_DIR}/server.js" ]]; then
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

update_node_deps() {
    log_info "$(msg UPDATE_NODE_DEPS)"
    if (cd "$APP_DIR" && npm install --no-audit --no-fund); then
        log_success "$(msg UPDATE_NODE_DEPS_OK)"
        return 0
    fi
    log_error "$(msg UPDATE_NODE_DEPS_FAILED)"
    return 1
}

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_UPDATE "$COMPONENT_NAME" "$TARGET")${COLOR_RESET}"
    print_separator
    echo ""

    check_installation || exit 1

    # Stop temporarily if running
    local was_running=false
    if is_daemon_running "$COMPONENT_NAME"; then
        log_info "$(msgf UPDATE_STOPPING_FOR_CLEAN "$COMPONENT_NAME")"
        stop_daemon "$COMPONENT_NAME" 15
        was_running=true
        sleep 2
    fi

    local update_failed=false

    # SillyTavern is a Node.js app: every target pulls source and refreshes
    # node dependencies (frontend assets ship inside the same package).
    case "$TARGET" in
        all|architecture|frontend)
            update_source_code || update_failed=true
            update_node_deps || update_failed=true
            ;;
    esac

    # Restart if it was running before
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
