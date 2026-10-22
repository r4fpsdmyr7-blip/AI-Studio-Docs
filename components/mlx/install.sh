#!/bin/bash

# ============================================================================
# AI Studio - MLX Framework Installation Script
# File: components/mlx/install.sh
# 
# Handles the initial deployment of the MLX framework and its core extensions 
# (mlx-lm, mlx-vlm). It sets up an isolated Python environment to prevent 
# dependency conflicts with other AI components.
# ============================================================================

set -u # Prevent unbound variable errors

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

    # Hardware Check (MLX is optimized for Apple Silicon)
    if ! is_apple_silicon; then
        log_warn "$(msgf MLX_NOT_APPLE_SILICON "$(uname -m)")"
        log_info "$(msg MLX_PERF_LIMITED)"
        echo ""
    fi

    # --- Step 1: Idempotency Check ---
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    if [[ -x "$venv_python" ]]; then
        if "$venv_python" -c "import mlx" >/dev/null 2>&1; then
            log_info "$(msgf MLX_INSTALL_ALREADY_OK "$COMPONENT_NAME")"
            log_info "$(msgf INSTALL_SKIP_HINT "$COMPONENT_NAME")"
            echo ""
            print_separator
            exit 0
        else
            log_warn "$(msg MLX_VENV_NOT_IMPORTABLE)"
        fi
    fi

    # --- Step 2: Dependency Verification & Installation ---
    log_info "$(msg INSTALL_STEP_VERIFY_DEPS)"
    if ! install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
        log_error "$(msg MLX_FAILED_DEPS)"
        exit 1
    fi

    # --- Step 3: Virtual Environment Setup ---
    log_info "$(msgf INSTALL_STEP_VENV_N "2")"
    if [[ -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        log_info "$(msg MLX_STEP_VENV_CLEAN)"
        rm -rf "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}"
    fi

    if ! python3 -m venv "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}"; then
        log_error "$(msg INSTALL_FAILED_VENV)"
        exit 1
    fi
    
    # Activate the virtual environment for the current shell session
    # shellcheck disable=SC1091
    source "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    log_success "$(msg INSTALL_VENV_OK)"

    # --- Step 4: Python Packages Installation ---
    log_info "$(msg MLX_STEP_FRAMEWORK)"
    
    # Upgrade pip first
    python3 -m pip install --upgrade pip --quiet
    
    # Install core MLX packages
    # We install them together to let pip resolve dependencies optimally
    local packages_to_install=(
        "mlx"
        "mlx-lm"      # Essential for running LLMs like Qwen
        "mlx-vlm"     # Essential for Vision-Language Models
        "huggingface-hub" # Required for downloading models
        "numpy"
    )

    log_info "$(msgf MLX_INSTALLING_PACKAGES "${packages_to_install[*]}")"
    if ! python3 -m pip install "${packages_to_install[@]}"; then
        log_error "$(msg MLX_FAILED_PACKAGES)"
        log_info "$(msg MLX_MISSING_HEADERS)"
        exit 1
    fi
    
    log_success "$(msg MLX_PACKAGES_OK)"

    # --- Step 5: Verification & Initialization ---
    log_info "$(msg MLX_STEP_VERIFY)"
    local mlx_version
    mlx_version=$(python3 -c "import mlx; print(mlx.__version__)" 2>/dev/null)
    
    if [[ -n "$mlx_version" ]]; then
        log_success "$(msgf MLX_VERIFY_OK "$mlx_version")"
    else
        log_error "$(msg MLX_VERIFY_FAILED)"
        exit 1
    fi

    # Initialize the global cache directory for MLX models
    ensure_dir "$COMPONENT_DATA_DIR"
    log_info "$(msgf MLX_CACHE_DIR_READY "$COMPONENT_DATA_DIR")"

    # --- Completion ---
    echo ""
    print_separator
    log_success "$(msgf INSTALL_SUCCESS_COMPONENT "$COMPONENT_NAME")"
    echo ""
    echo -e "${COLOR_CYAN}$(msg MLX_NEXT_TITLE):${COLOR_RESET}"
    echo "$(msg MLX_NEXT_NO_START)"
    echo "$(msg MLX_NEXT_USE_VIA)"
    echo "$(msg MLX_NEXT_1)"
    echo "$(msgf MLX_NEXT_2 "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}")"
    echo "$(msg MLX_NEXT_3)"
    echo ""
    print_separator
}

# Execute main function
main "$@"
