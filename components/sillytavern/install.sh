#!/bin/bash

# ============================================================================
# AI Studio - SillyTavern Install Script
# File: components/sillytavern/install.sh
#
# Installs SillyTavern from the official repository (release branch):
# clone into app/ -> npm install -> ready. Per official docs:
# https://docs.sillytavern.app/installation/
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$COMPONENT_DIR/metadata.sh"

# The upstream source tree lives in app/ so it can never collide with the
# lifecycle scripts in this directory (upstream ships its own start.sh).
APP_DIR="${COMPONENT_DIR}/app"

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_INSTALL "$COMPONENT_NAME")${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  ${COMPONENT_DESCRIPTION}${COLOR_RESET}"
    print_separator
    echo ""

    # --- Step 1: Idempotency Check ---
    if [[ -f "${APP_DIR}/server.js" ]] && [[ -d "${APP_DIR}/node_modules" ]]; then
        touch "${COMPONENT_DIR}/.installed"
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
    if [[ ! -d "${APP_DIR}/.git" ]]; then
        # Only allow https:// repository URLs; shallow clone to save bandwidth
        case "$COMPONENT_REPO" in
            https://*) ;;
            *)
                log_error "$(msgf INSTALL_REPO_INVALID "$COMPONENT_REPO")"
                exit 1
                ;;
        esac
        rm -rf "${APP_DIR}.tmp"
        if ! git clone --depth 1 --branch "$COMPONENT_BRANCH" "$COMPONENT_REPO" "${APP_DIR}.tmp"; then
            log_error "$(msgf INSTALL_REPO_INVALID "$COMPONENT_REPO")"
            rm -rf "${APP_DIR}.tmp"
            exit 1
        fi
        rm -rf "$APP_DIR"
        mv "${APP_DIR}.tmp" "$APP_DIR"
        log_success "$(msg INSTALL_CLONE_OK)"
    else
        log_info "$(msg INSTALL_SRC_EXISTS)"
        git -C "$APP_DIR" checkout "$COMPONENT_BRANCH" 2>/dev/null || true
        git -C "$APP_DIR" pull origin "$COMPONENT_BRANCH" || true
    fi

    # --- Step 4: Node.js Dependencies ---
    log_info "$(msg INSTALL_NODE_DEPS)"
    if ! (cd "$APP_DIR" && npm install --no-audit --no-fund); then
        log_error "$(msg INSTALL_NODE_DEPS_FAILED)"
        exit 1
    fi
    log_success "$(msg INSTALL_NODE_DEPS_OK)"

    # --- Step 5: Initialize Data Directory ---
    log_info "$(msg INSTALL_INIT_DATA_DIR)"
    ensure_dir "${COMPONENT_DIR}/${COMPONENT_DATA_DIR}"
    log_success "$(msgf INSTALL_DATA_DIR_READY "$COMPONENT_DATA_DIR")"

    # --- Completion ---
    touch "${COMPONENT_DIR}/.installed"
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
