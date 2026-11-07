#!/bin/bash

# ============================================================================
# AI Studio - MLX-Video Install Script (library-type component)
# File: components/mlx-video/install.sh
#
# mlx-video (https://github.com/Blaizzy/mlx-video) is a Python library/CLI
# for local video generation powered by Apple's MLX framework. Per the
# official repo: install into a venv via pip from the GitHub source.
# It requires Apple Silicon (MLX does not run on Intel Macs).
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$COMPONENT_DIR/metadata.sh"

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_INSTALL "$COMPONENT_NAME")${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  ${COMPONENT_DESCRIPTION}${COLOR_RESET}"
    print_separator
    echo ""

    # --- Hardware Gate: MLX (and therefore mlx-video) needs Apple Silicon ---
    if ! is_apple_silicon; then
        log_error "$(msgf MLXV_SILICON_REQUIRED "$(uname -m)")"
        print_separator
        exit 1
    fi

    # --- Step 1: Idempotency Check ---
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    if [[ -x "$venv_python" ]] && "$venv_python" -m pip show mlx-video >/dev/null 2>&1; then
        touch "${COMPONENT_DIR}/.installed"
        log_info "$(msgf INSTALL_ALREADY "$COMPONENT_NAME")"
        log_info "$(msgf INSTALL_SKIP_HINT "$COMPONENT_NAME")"
        echo ""
        print_separator
        exit 0
    fi

    # --- Step 2: Dependency Verification & Installation ---
    log_info "$(msg INSTALL_STEP_VERIFY_DEPS)"
    if ! install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
        log_error "$(msg INSTALL_FAILED_DEPS)"
        exit 1
    fi

    # --- Step 3: Python Virtual Environment ---
    log_info "$(msg INSTALL_STEP_VENV)"
    if [[ ! -f "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate" ]]; then
        if ! python3 -m venv "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}"; then
            log_error "$(msg INSTALL_FAILED_VENV)"
            exit 1
        fi
    fi
    # shellcheck disable=SC1091
    source "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    log_success "$(msg INSTALL_VENV_OK)"

    # --- Step 4: Install mlx-video from the official GitHub source ---
    python3 -m pip install --upgrade pip --quiet
    log_info "$(msg MLXV_PIP_INSTALLING)"
    if ! python3 -m pip install "git+${COMPONENT_REPO}"; then
        log_error "$(msg MLXV_PIP_FAILED)"
        exit 1
    fi
    log_success "$(msg INSTALL_PYDEPS_OK)"

    # --- Step 5: Verification ---
    local mlxv_version
    mlxv_version=$(python3 -m pip show mlx-video 2>/dev/null | awk '/^Version:/ {print $2}')
    if [[ -z "$mlxv_version" ]]; then
        log_error "$(msg MLXV_PIP_FAILED)"
        exit 1
    fi
    log_success "$(msgf MLXV_VERIFY_OK "$mlxv_version")"

    # --- Step 6: Initialize Data Directory (generated videos, model weights) ---
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
    echo "  $(msg INSTALL_NEXT_STATUS)"
    echo "  $(msgf INSTALL_NEXT_STATUS_CMD "$COMPONENT_NAME")"
    echo ""
    print_separator
}

# Execute main function
main "$@"
