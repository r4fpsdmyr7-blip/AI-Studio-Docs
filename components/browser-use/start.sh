#!/bin/bash

# ============================================================================
# AI Studio - Browser Use Start Script (library-type component)
# File: components/browser-use/start.sh
#
# browser-use is a Python library with no daemon to start. This script
# verifies the environment and prints the official usage example.
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
    if [[ ! -x "$venv_python" ]] || ! "$venv_python" -c "import browser_use" >/dev/null 2>&1; then
        log_error "$(msgf START_NOT_INSTALLED "$COMPONENT_NAME")"
        log_info "$(msgf HINT_RUN_INSTALL_FIRST "$COMPONENT_NAME")"
        print_separator
        exit 1
    fi

    local bu_version
    bu_version=$("$venv_python" -c "import importlib.metadata; print(importlib.metadata.version('browser-use'))" 2>/dev/null)
    log_success "$(msgf BU_START_READY "${bu_version:-unknown}")"
    echo ""

    echo -e "${COLOR_CYAN}$(msg BU_USAGE_INTRO)${COLOR_RESET}"
    echo -e "  ${COLOR_BOLD}$(msg BU_USAGE_STEP1)${COLOR_RESET}"
    echo "     ${COLOR_GRAY}source ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_BOLD}$(msg BU_USAGE_STEP2)${COLOR_RESET}"
    echo "     ${COLOR_GRAY}https://docs.browser-use.com/quickstart${COLOR_RESET}"
    echo ""

    print_separator
    log_success "$(msg BU_START_NO_SERVICE)"
    echo ""
    print_separator

    # Always exit 0 to keep batch operations like './ai-studio.sh start all' green
    exit 0
}

# Execute main function
main "$@"
