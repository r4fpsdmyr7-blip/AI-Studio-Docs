#!/bin/bash

# ============================================================================
# AI Studio - Open WebUI Installation Script
# File: components/open-webui/install.sh
# 
# Handles the initial deployment of Open WebUI, including dependency checks,
# repository cloning, virtual environment setup, and package installation.
# ============================================================================

set -e # Exit immediately if a command exits with a non-zero status

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Installation Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_INSTALL "$COMPONENT_NAME")${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  ${COMPONENT_DESCRIPTION}${COLOR_RESET}"
    print_separator
    echo ""

    # --- Step 1: Idempotency Check ---
    if [[ -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]] && [[ -f "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate" ]]; then
        log_info "$(msgf INSTALL_ALREADY "$COMPONENT_NAME")"
        log_info "$(msgf INSTALL_SKIP_HINT "$COMPONENT_NAME")"
        echo ""
        print_separator
        exit 0
    fi

    # --- Step 2: Dependency Verification & Installation ---
    log_info "$(msg INSTALL_STEP_VERIFY_DEPS)"
    # install_component_deps is defined in lib/env-install.sh
    if ! install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
        log_error "$(msg INSTALL_FAILED_DEPS)"
        exit 1
    fi

    # --- Step 3: Source Code Retrieval ---
    log_info "$(msgf INSTALL_STEP_CLONE "$COMPONENT_REPO")"
    if [[ ! -d "${COMPONENT_DIR}/.git" ]]; then
        # Clean directory if it exists but is not a git repo
        if [[ -n "$(ls -A "${COMPONENT_DIR}" 2>/dev/null | grep -v 'install.sh\|metadata.sh\|start.sh\|stop.sh\|status.sh\|update.sh\|diagnose.sh\|uninstall.sh')" ]]; then
            log_warn "$(msg INSTALL_DIR_NOT_GIT)"
            find "${COMPONENT_DIR}" -mindepth 1 -maxdepth 1 ! -name '*.sh' -exec rm -rf {} +
        fi
        
        git clone --branch "$COMPONENT_BRANCH" "$COMPONENT_REPO" "${COMPONENT_DIR}/.tmp_clone"
        # Move contents to root, preserving standard scripts
        shopt -s dotglob nullglob
        mv "${COMPONENT_DIR}/.tmp_clone"/* "${COMPONENT_DIR}/"
        rm -rf "${COMPONENT_DIR}/.tmp_clone"
        shopt -u dotglob nullglob
        
        log_success "$(msg INSTALL_CLONE_OK)"
    else
        log_info "$(msg INSTALL_SRC_EXISTS)"
        git checkout "$COMPONENT_BRANCH"
        git pull origin "$COMPONENT_BRANCH"
        log_success "$(msg INSTALL_SRC_UPDATED)"
    fi

    # --- Step 4: Virtual Environment Setup ---
    log_info "$(msg INSTALL_STEP_VENV)"
    # Use the python3 that was verified/installed by env-install.sh
    if ! python3 -m venv "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}"; then
        log_error "$(msg INSTALL_FAILED_VENV)"
        exit 1
    fi
    
    # Activate the virtual environment for the current shell session
    # shellcheck disable=SC1091
    source "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    log_success "$(msg INSTALL_VENV_OK)"

    # --- Step 5: Python Dependencies Installation ---
    log_info "$(msg INSTALL_STEP_PYDEPS)"
    
    # Upgrade pip first
    python3 -m pip install --upgrade pip --quiet
    
    # Install requirements. Open WebUI uses requirements.txt for source installations.
    if [[ -f "${COMPONENT_DIR}/requirements.txt" ]]; then
        if ! python3 -m pip install -r "${COMPONENT_DIR}/requirements.txt"; then
            log_error "$(msg INSTALL_FAILED_PYDEPS)"
            exit 1
        fi
    else
        # Fallback: install the package directly if requirements.txt is missing (newer versions might change structure)
        log_warn "$(msg INSTALL_NO_REQUIREMENTS)"
        if ! python3 -m pip install open-webui; then
            log_error "$(msg INSTALL_FAILED_PACKAGE)"
            exit 1
        fi
    fi
    
    log_success "$(msg INSTALL_PYDEPS_OK)"

    # --- Step 6: Initialize Data Directories ---
    log_info "$(msg INSTALL_INIT_DATA_DIR)"
    ensure_dir "${COMPONENT_DIR}/${COMPONENT_DATA_DIR}"
    log_success "$(msgf INSTALL_DATA_DIR_READY "$COMPONENT_DATA_DIR")"

    # --- Completion ---
    echo ""
    print_separator
    log_success "$(msgf INSTALL_SUCCESS_COMPONENT "$COMPONENT_NAME")"
    echo ""
    echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
    echo "  $(msg INSTALL_NEXT_START)"
    echo "  $(msgf INSTALL_NEXT_START_CMD "$COMPONENT_NAME")"
    echo "  $(msg INSTALL_NEXT_STATUS)"
    echo "  $(msgf INSTALL_NEXT_STATUS_CMD "$COMPONENT_NAME")"
    echo ""
    print_separator
}

# Execute main function
main "$@"
