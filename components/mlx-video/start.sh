#!/bin/bash

# ============================================================================
# AI Studio - MLX-Video Start Script (library-type component)
# File: components/mlx-video/start.sh
#
# mlx-video is a Python library/CLI with no daemon to start. This script
# verifies the environment and prints usage guidance.
# Always exits 0 on success so batch operations (start all) stay green.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$COMPONENT_DIR/metadata.sh"

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_VERIFY "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    if [[ ! -x "$venv_python" ]] || ! "$venv_python" -m pip show mlx-video >/dev/null 2>&1; then
        log_error "$(msgf START_NOT_INSTALLED "$COMPONENT_NAME")"
        log_info "$(msgf HINT_RUN_INSTALL_FIRST "$COMPONENT_NAME")"
        print_separator
        exit 1
    fi

    local mlxv_version
    mlxv_version=$("$venv_python" -m pip show mlx-video 2>/dev/null | awk '/^Version:/ {print $2}')
    log_success "$(msgf MLXV_START_READY "${mlxv_version:-unknown}")"
    echo ""

    echo -e "${COLOR_CYAN}$(msg MLXV_USAGE_INTRO)${COLOR_RESET}"
    echo -e "  ${COLOR_BOLD}$(msg MLXV_USAGE_STEP1)${COLOR_RESET}"
    echo "     ${COLOR_GRAY}source ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_BOLD}$(msg MLXV_USAGE_STEP2)${COLOR_RESET}"
    echo ""

    print_separator
    log_success "$(msg MLXV_START_NO_SERVICE)"
    echo ""
    print_separator

    # Always exit 0 to keep batch operations like './ai-studio.sh start all' green
    exit 0
}

# Execute main function
main "$@"
