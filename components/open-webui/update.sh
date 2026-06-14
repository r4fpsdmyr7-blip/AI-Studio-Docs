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
            log_error "Unknown update argument: $1"
            log_info "Usage: ./ai-studio.sh update ${COMPONENT_NAME} [--target <frontend|backend|architecture|models|all>]"
            exit 1
            ;;
    esac
done

# Validate target against metadata definition
if [[ ! " ${COMPONENT_UPDATE_TARGETS} " =~ " ${TARGET} " ]]; then
    log_error "Invalid update target: '${TARGET}'"
    log_info "Supported targets for ${COMPONENT_NAME} are: ${COMPONENT_UPDATE_TARGETS// /, }"
    exit 1
fi

# ============================================================================
# 4. Pre-flight Checks
# ============================================================================

check_installation() {
    if [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]] || [[ ! -f "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python" ]]; then
        log_error "${COMPONENT_NAME} is not installed."
        log_info "Please run './ai-studio.sh install ${COMPONENT_NAME}' first."
        return 1
    fi
    return 0
}

# ============================================================================
# 5. Core Update Logic
# ============================================================================

update_source_code() {
    log_info "Fetching latest source code from ${COMPONENT_REPO}..."
    
    # Ensure we are on the correct branch
    git checkout "$COMPONENT_BRANCH" >/dev/null 2>&1
    
    # Pull latest changes
    if git pull origin "$COMPONENT_BRANCH"; then
        log_success "Source code updated successfully."
        return 0
    else
        log_warn "No new updates to pull, or git pull failed. Proceeding with dependency check..."
        return 0
    fi
}

update_architecture_backend() {
    log_info "Updating Python dependencies (backend/architecture)..."
    
    # Activate virtual environment
    # shellcheck disable=SC1091
    source "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    
    # Upgrade pip first
    python3 -m pip install --upgrade pip --quiet
    
    # Upgrade requirements
    if [[ -f "${COMPONENT_DIR}/requirements.txt" ]]; then
        if python3 -m pip install --upgrade -r "${COMPONENT_DIR}/requirements.txt"; then
            log_success "Python dependencies updated successfully."
        else
            log_error "Failed to update Python dependencies."
            return 1
        fi
    else
        log_warn "requirements.txt not found. Attempting to upgrade 'open-webui' package directly..."
        if python3 -m pip install --upgrade open-webui; then
            log_success "Open WebUI package upgraded successfully."
        else
            log_error "Failed to upgrade open-webui package."
            return 1
        fi
    fi
    
    return 0
}

update_frontend() {
    log_info "Checking for frontend updates..."
    
    # Open WebUI typically bundles its frontend, but if a package.json exists, we can update Node deps
    if [[ -f "${COMPONENT_DIR}/package.json" ]]; then
        if command_exists "npm"; then
            log_info "Updating Node.js dependencies..."
            if npm install --prefix "${COMPONENT_DIR}" >/dev/null 2>&1; then
                log_success "Frontend dependencies updated."
            else
                log_warn "Failed to update frontend dependencies. This may not be critical if the backend is bundled."
            fi
        else
            log_warn "Node.js (npm) not found. Skipping frontend dependency update."
        fi
    else
        log_info "No separate frontend build directory found. Frontend is likely bundled with the backend update."
    fi
    return 0
}

update_models() {
    log_info "Handling model updates..."
    log_info "Note: Open WebUI manages model connections via its Web UI or through Ollama."
    log_info "To update local models, please use: ${COLOR_CYAN}ollama pull <model_name>${COLOR_RESET}"
    log_info "Or manage connections in the Open WebUI Admin Settings."
    return 0
}

# ============================================================================
# 6. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Updating: ${COMPONENT_NAME} (Target: ${TARGET})${COLOR_RESET}"
    print_separator
    echo ""

    check_installation || exit 1

    # Check if running, and if so, stop it temporarily
    local was_running=false
    if is_daemon_running "$COMPONENT_NAME"; then
        log_info "${COMPONENT_NAME} is currently running. Stopping it for a clean update..."
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
        log_info "Restarting ${COMPONENT_NAME}..."
        # We call the start script logic indirectly or just use the main script command
        # For modularity, we can just invoke the start script directly
        "${COMPONENT_DIR}/start.sh" >/dev/null 2>&1 &
        sleep 3 # Give it a moment to start
    fi

    echo ""
    print_separator

    if [[ "$update_failed" == true ]]; then
        log_error "Update completed with errors. Please check the logs."
        log_info "You may need to run: ./ai-studio.sh diagnose ${COMPONENT_NAME} --deep --fix"
        exit 1
    else
        log_success "${COMPONENT_NAME} has been successfully updated to the latest version!"
        if [[ "$was_running" == true ]]; then
            log_info "The service has been automatically restarted."
        else
            log_info "You can start the service with: ./ai-studio.sh start ${COMPONENT_NAME}"
        fi
    fi
    
    print_separator
    exit 0
}

# Execute main function
main "$@"
