#!/bin/bash

# ============================================================================
# AI Studio - MLX Framework Start Script
# File: components/mlx/start.sh
# 
# Since MLX is a foundational Python framework/library and not a standalone 
# background service, this script gracefully handles the "start" command by 
# verifying the installation and providing actionable guidance on how to 
# actually use the framework (e.g., activating the venv, running mlx-lm).
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Logic
# ============================================================================

# Verify that MLX is actually installed and functional
check_installation() {
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    
    if [[ ! -x "$venv_python" ]]; then
        log_error "$(msg MLX_VENV_NOT_FOUND)"
        return 1
    fi
    
    if ! "$venv_python" -c "import mlx" >/dev/null 2>&1; then
        log_error "$(msg MLX_START_NOT_IMPORTABLE)"
        return 1
    fi
    
    return 0
}

# Provide actionable guidance on how to use MLX
provide_usage_guide() {
    local venv_activate="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    
    echo -e "${COLOR_BOLD}${COLOR_CYAN}$(msg MLX_USAGE_TITLE):${COLOR_RESET}"
    echo ""
    echo "$(msg MLX_USAGE_DESC1)"
    echo "$(msg MLX_USAGE_DESC2)"
    echo ""
    
    echo -e "  ${COLOR_BOLD}$(msg MLX_USAGE_STEP1)${COLOR_RESET}"
    echo "     ${COLOR_GRAY}$(msgf MLX_USAGE_STEP1_CMD "$venv_activate")${COLOR_RESET}"
    echo ""
    
    echo -e "  ${COLOR_BOLD}$(msg MLX_USAGE_STEP2)${COLOR_RESET}"
    echo "     ${COLOR_GRAY}$(msg MLX_USAGE_STEP2_CMD)${COLOR_RESET}"
    echo "$(msg MLX_USAGE_STEP2_EXPECT)"
    echo ""
    
    echo -e "  ${COLOR_BOLD}$(msg MLX_USAGE_STEP3)${COLOR_RESET}"
    echo "     ${COLOR_GRAY}$(msg MLX_USAGE_STEP3_CMD)${COLOR_RESET}"
    echo ""
    
    echo -e "  ${COLOR_BOLD}$(msg MLX_USAGE_STEP4)${COLOR_RESET}"
    echo "     ${COLOR_GRAY}$(msg MLX_USAGE_STEP4_CMD)${COLOR_RESET}"
    echo ""
}

# ============================================================================
# 4. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_VERIFY "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight check
    if ! check_installation; then
        echo ""
        print_separator
        log_error "$(msg MLX_START_NOT_PROPER)"
        log_info "$(msg MLX_START_SETUP_HINT)"
        log_info "${COLOR_CYAN}$(msgf MLX_START_INSTALL_CMD "$COMPONENT_NAME")${COLOR_RESET}"
        print_separator
        exit 1
    fi

    # Step 2: Show version info
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    local mlx_version
    mlx_version=$("$venv_python" -c "import mlx; print(mlx.__version__)" 2>/dev/null)
    
    log_success "$(msgf MLX_START_READY "$mlx_version")"
    echo ""

    # Step 3: Provide usage guide
    provide_usage_guide

    print_separator
    log_success "$(msg MLX_START_NO_SERVICE)"
    echo ""
    print_separator
    
    # Always exit 0 to ensure this doesn't break batch operations like `./ai-studio.sh start all`
    exit 0
}

# Execute main function
main "$@"
