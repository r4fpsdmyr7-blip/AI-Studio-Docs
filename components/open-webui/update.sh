#!/bin/bash

# ============================================================================
# AI Studio - Open WebUI Update Script
# File: components/open-webui/update.sh
# 
# Handles granular updates for Open WebUI, supporting targeted updates for
# frontend, backend/architecture, or a full system update.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$COMPONENT_DIR/metadata.sh"

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

# ============================================================================
# 4. Pre-flight Checks
# ============================================================================

check_installation() {
    if [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]] || [[ ! -f "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python" ]]; then
        log_error "$(msgf UPDATE_NOT_INSTALLED "$COMPONENT_NAME")"
        log_info "$(msgf HINT_RUN_INSTALL_FIRST "$COMPONENT_NAME")"
        return 1
    fi
    return 0
}

# ============================================================================
# 5. Core Update Logic
# ============================================================================

update_source_code() {
    log_info "$(msgf UPDATE_FETCHING "$COMPONENT_REPO")"
    
    # Ensure we are on the correct branch
    git checkout "$COMPONENT_BRANCH" >/dev/null 2>&1
    
    # Pull latest changes
    if git pull origin "$COMPONENT_BRANCH"; then
        log_success "$(msg UPDATE_SRC_OK)"
        return 0
    else
        log_warn "$(msg UPDATE_NO_UPDATES)"
        return 0
    fi
}

update_architecture_backend() {
    log_info "$(msg UPDATE_PYDEPS)"
    
    # Activate virtual environment
    # shellcheck disable=SC1091
    source "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    
    # Upgrade pip first
    python3 -m pip install --upgrade pip --quiet
    
    # Upgrade requirements
    if [[ -f "${COMPONENT_DIR}/requirements.txt" ]]; then
        if python3 -m pip install --upgrade -r "${COMPONENT_DIR}/requirements.txt"; then
            log_success "$(msg UPDATE_PYDEPS_OK)"
        else
            log_error "$(msg UPDATE_PYDEPS_FAILED)"
            return 1
        fi
    else
        log_warn "$(msg UPDATE_NO_REQUIREMENTS)"
        if python3 -m pip install --upgrade open-webui; then
            log_success "$(msg UPDATE_PACKAGE_OK)"
        else
            log_error "$(msg UPDATE_PACKAGE_FAILED)"
            return 1
        fi
    fi
    
    return 0
}

update_frontend() {
    log_info "$(msg UPDATE_FRONTEND_CHECK)"
    
    # Open WebUI typically bundles its frontend, but if a package.json exists, we can update Node deps
    if [[ -f "${COMPONENT_DIR}/package.json" ]]; then
        if command_exists "npm"; then
            log_info "$(msg UPDATE_NODE_DEPS)"
            if npm install --prefix "${COMPONENT_DIR}" >/dev/null 2>&1; then
                log_success "$(msg UPDATE_NODE_DEPS_OK)"
            else
                log_warn "$(msg UPDATE_NODE_DEPS_FAILED)"
            fi
        else
            log_warn "$(msg UPDATE_NO_NODE)"
        fi
    else
        log_info "$(msg UPDATE_NO_FRONTEND_DIR)"
    fi
    return 0
}

update_models() {
    log_info "$(msg UPDATE_MODELS)"
    log_info "$(msg UPDATE_MODELS_NOTE)"
    log_info "$(msg UPDATE_MODELS_CMD)"
    log_info "$(msg UPDATE_MODELS_ADMIN)"
    return 0
}

# ============================================================================
# 6. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_UPDATE "$COMPONENT_NAME" "$TARGET")${COLOR_RESET}"
    print_separator
    echo ""

    check_installation || exit 1

    # Check if running, and if so, stop it temporarily
    local was_running=false
    if is_daemon_running "$COMPONENT_NAME"; then
        log_info "$(msgf UPDATE_STOPPING_FOR_CLEAN "$COMPONENT_NAME")"
        stop_daemon "$COMPONENT_NAME" 15
        was_running=true
        sleep 2
    fi

    local update_failed=false

    # Execute updates based on target
    case "$TARGET" in
        all)
            update_source_code || update_failed=true
            update_architecture_backend || update_failed=true
            update_frontend || update_failed=true
            ;;
        architecture|backend)
            update_source_code || update_failed=true
            update_architecture_backend || update_failed=true
            ;;
        frontend)
            update_source_code || update_failed=true
            update_frontend || update_failed=true
            ;;
        models)
            update_models
            ;;
    esac

    # Restart if it was running before and update succeeded (or even if it partially failed, to restore service)
    if [[ "$was_running" == true ]]; then
        echo ""
        log_info "$(msgf UPDATE_RESTARTING "$COMPONENT_NAME")"
        # We call the start script logic indirectly or just use the main script command
        # For modularity, we can just invoke the start script directly
        "${COMPONENT_DIR}/start.sh" >/dev/null 2>&1 &
        sleep 3 # Give it a moment to start
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
        else
            log_info "$(msgf UPDATE_HINT_START "$COMPONENT_NAME")"
        fi
    fi
    
    print_separator
    exit 0
}

# Execute main function
main "$@"
