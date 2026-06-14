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
            log_error "Unknown update argument: $1"
            log_info "Usage: ./ai-studio.sh update ${COMPONENT_NAME} [--target <architecture|all>]"
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
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    
    if [[ ! -x "$venv_python" ]]; then
        log_error "MLX virtual environment not found."
        log_info "Please run './ai-studio.sh install ${COMPONENT_NAME}' first."
        return 1
    fi
    
    if ! "$venv_python" -c "import mlx" >/dev/null 2>&1; then
        log_error "MLX is installed but cannot be imported. The environment is corrupted."
        log_info "Please run './ai-studio.sh install ${COMPONENT_NAME}' to repair it."
        return 1
    fi
    
    return 0
}

# ============================================================================
# 5. Core Update Logic
# ============================================================================

update_architecture() {
    log_info "Updating MLX framework and core dependencies..."
    
    # Ensure system-level build dependencies are up to date (idempotent)
    log_info "Verifying system build dependencies (cmake, etc.)..."
    install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS >/dev/null 2>&1

    # Activate the virtual environment
    # shellcheck disable=SC1091
    source "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    
    # 1. Upgrade core build tools
    log_info "Upgrading pip, setuptools, and wheel..."
    if ! python3 -m pip install --upgrade --quiet pip setuptools wheel; then
        log_warn "Failed to upgrade core build tools. Proceeding with caution..."
    fi

    # 2. Define packages to upgrade
    local packages_to_upgrade=(
        "mlx"
        "mlx-lm"
        "mlx-vlm"
        "huggingface-hub"
        "numpy"
    )

    log_info "Upgrading Python packages: ${packages_to_upgrade[*]} ..."
    
    # Execute upgrade
    if python3 -m pip install --upgrade "${packages_to_upgrade[@]}"; then
        log_success "MLX packages upgraded successfully."
        
        # Verify the new version
        local new_version
        new_version=$(python3 -c "import mlx; print(mlx.__version__)" 2>/dev/null)
        if [[ -n "$new_version" ]]; then
            log_info "Current MLX version: v${new_version}"
        fi
        return 0
    else
        log_error "Failed to upgrade MLX packages."
        log_info "This may be due to network issues or conflicting dependencies."
        return 1
    fi
}

# ============================================================================
# 6. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Updating: ${COMPONENT_NAME} (Target: ${TARGET})${COLOR_RESET}"
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
        log_error "Update completed with errors."
        log_info "Please check the logs above. You may need to manually activate the venv and run 'pip install --upgrade mlx'."
        exit 1
    else
        log_success "${COMPONENT_NAME} has been successfully updated!"
        echo ""
        echo -e "${COLOR_CYAN}Note:${COLOR_RESET}"
        echo "  Any Python scripts or terminal sessions currently using MLX should be restarted"
        echo "  to load the newly updated library into memory."
        echo "  Activate the environment with: ${COLOR_GRAY}source ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate${COLOR_RESET}"
        echo ""
    fi
    
    print_separator
    exit 0
}

# Execute main function
main "$@"
