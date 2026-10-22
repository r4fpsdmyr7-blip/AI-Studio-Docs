#!/bin/bash

# ============================================================================
# AI Studio - MLX Framework Update Script
# File: components/mlx/update.sh
# 
# Handles the update process for the MLX framework and its core extensions.
# Since MLX is a Python library, updating primarily involves upgrading the 
# packages within the component's isolated virtual environment.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/env-install.sh"
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
            log_info "$(msgf MLX_UPDATE_USAGE "$COMPONENT_NAME")"
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
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    
    if [[ ! -x "$venv_python" ]]; then
        log_error "$(msg MLX_VENV_NOT_FOUND)"
        log_info "$(msgf UPDATE_HINT_INSTALL_FIRST "$COMPONENT_NAME")"
        return 1
    fi
    
    if ! "$venv_python" -c "import mlx" >/dev/null 2>&1; then
        log_error "$(msg MLX_UPDATE_CORRUPTED)"
        log_info "$(msgf MLX_UPDATE_HINT_REPAIR "$COMPONENT_NAME")"
        return 1
    fi
    
    return 0
}

# ============================================================================
# 5. Core Update Logic
# ============================================================================

update_architecture() {
    log_info "$(msg MLX_UPDATE_START)"
    
    # Ensure system-level build dependencies are up to date (idempotent)
    log_info "$(msg MLX_UPDATE_VERIFY_DEPS)"
    install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS >/dev/null 2>&1

    # Activate the virtual environment
    # shellcheck disable=SC1091
    source "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    
    # 1. Upgrade core build tools
    log_info "$(msg MLX_UPDATE_UPGRADE_TOOLS)"
    if ! python3 -m pip install --upgrade --quiet pip setuptools wheel; then
        log_warn "$(msg MLX_UPDATE_TOOLS_FAILED)"
    fi

    # 2. Define packages to upgrade
    local packages_to_upgrade=(
        "mlx"
        "mlx-lm"
        "mlx-vlm"
        "huggingface-hub"
        "numpy"
    )

    log_info "$(msgf MLX_UPDATE_UPGRADE_PKGS "${packages_to_upgrade[*]}")"
    
    # Execute upgrade
    if python3 -m pip install --upgrade "${packages_to_upgrade[@]}"; then
        log_success "$(msg MLX_UPDATE_PKGS_OK)"
        
        # Verify the new version
        local new_version
        new_version=$(python3 -c "import mlx; print(mlx.__version__)" 2>/dev/null)
        if [[ -n "$new_version" ]]; then
            log_info "$(msgf MLX_UPDATE_VERSION "$new_version")"
        fi
        return 0
    else
        log_error "$(msg MLX_UPDATE_PKGS_FAILED)"
        log_info "$(msg MLX_UPDATE_FAIL_REASON)"
        return 1
    fi
}

# ============================================================================
# 6. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_UPDATE "$COMPONENT_NAME" "$TARGET")${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight check
    if ! check_installation; then
        print_separator
        exit 1
    fi

    local update_failed=0

    # Step 2: Execute updates based on target
    case "$TARGET" in
        all|architecture)
            # For MLX, 'all' and 'architecture' effectively do the same thing 
            # (upgrading the core library and its dependencies)
            update_architecture || ((update_failed++))
            ;;
    esac

    echo ""
    print_separator

    if [[ $update_failed -gt 0 ]]; then
        log_error "$(msg UPDATE_ERRORS)"
        log_info "$(msg MLX_UPDATE_HINT_MANUAL)"
        exit 1
    else
        log_success "$(msgf UPDATE_SUCCESS_COMPONENT "$COMPONENT_NAME")"
        echo ""
        echo -e "${COLOR_CYAN}$(msg LBL_NOTE):${COLOR_RESET}"
        echo "  $(msg MLX_UPDATE_NOTE_RESTART_1)"
        echo "  $(msg MLX_UPDATE_NOTE_RESTART_2)"
        echo "  $(msgf MLX_UPDATE_ACTIVATE "${COLOR_GRAY}source ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate${COLOR_RESET}")"
        echo ""
    fi
    
    print_separator
    exit 0
}

# Execute main function
main "$@"
